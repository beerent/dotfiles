-- Simple, bulletproof coding time tracker
-- Core principle: Single source of truth with minimal state

-- Simple state - only what we absolutely need
local session_start = vim.loop.hrtime()
local last_activity = vim.loop.hrtime()
local is_active = true
local save_count = 0 -- Track auto-saves for notifications
local INACTIVE_THRESHOLD = 30 * 1000000000 -- 30 seconds

-- Data storage
local data_dir = vim.fn.stdpath("data") .. "/coding-time-tracker"
vim.fn.mkdir(data_dir, "p")

-- Get project-specific data file path
local function get_data_file()
  local cwd = vim.fn.getcwd()
  local git_root = vim.fn.system("cd " .. vim.fn.shellescape(cwd) .. " && git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  local project = (vim.v.shell_error == 0 and git_root ~= "") and git_root or cwd
  local name = project:match("([^/]+)$") or "unknown"
  return data_dir .. "/" .. name:gsub("[^%w%-_.]", "_") .. ".json"
end

-- Load data with bulletproof error handling
local function load_data()
  local file_path = get_data_file()
  local file = io.open(file_path, "r")

  if not file then
    return { daily = {}, weekly = {}, monthly = {}, total = 0 }
  end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then
    return { daily = {}, weekly = {}, monthly = {}, total = 0 }
  end

  local success, data = pcall(vim.json.decode, content)
  if not success or type(data) ~= "table" then
    -- Backup corrupted file
    local backup = file_path .. ".backup." .. os.date("%Y%m%d_%H%M%S")
    vim.fn.rename(file_path, backup)
    vim.notify("Corrupted data backed up to: " .. backup, vim.log.levels.WARN)
    return { daily = {}, weekly = {}, monthly = {}, total = 0 }
  end

  -- Ensure structure
  data.daily = data.daily or {}
  data.weekly = data.weekly or {}
  data.monthly = data.monthly or {}
  data.total = data.total or 0

  return data
end

-- Save data atomically
local function save_data(data)
  local file_path = get_data_file()
  local temp_path = file_path .. ".tmp"

  local success, json = pcall(vim.json.encode, data)
  if not success then
    vim.notify("Failed to encode data: " .. json, vim.log.levels.ERROR)
    return false
  end

  local file = io.open(temp_path, "w")
  if not file then
    vim.notify("Failed to create temp file", vim.log.levels.ERROR)
    return false
  end

  file:write(json)
  file:close()

  -- Atomic move
  if vim.fn.rename(temp_path, file_path) ~= 0 then
    vim.fn.delete(temp_path)
    vim.notify("Failed to save data", vim.log.levels.ERROR)
    return false
  end

  return true
end

-- Get current session time in seconds
local function get_session_time()
  if not is_active then return 0 end
  return (vim.loop.hrtime() - session_start) / 1000000000
end

-- Update activity state
local function update_activity()
  local now = vim.loop.hrtime()
  local inactive_time = now - last_activity

  if inactive_time > INACTIVE_THRESHOLD then
    if is_active then
      is_active = false
    end
  else
    if not is_active then
      -- Resume tracking
      session_start = now
      is_active = true
    end
  end
end

-- Send progress notification on save milestones
local function send_progress_notification(data)
  local session_time = get_session_time()
  local today = os.date("%Y-%m-%d")
  local week = os.date("%Y-W%U")
  local month = os.date("%Y-%m")

  local today_total = data.daily[today] or 0
  local week_total = data.weekly[week] or 0
  local month_total = data.monthly[month] or 0
  local project_total = data.total

  local message = string.format(
    "Today: %s\nWeek: %s\nMonth: %s\nProject: %s",
    format_time(today_total),
    format_time(week_total),
    format_time(month_total),
    format_time(project_total)
  )

  require("notify")("💻 Progress Update!\n\n" .. message, "info", {
    title = "Coding Time Saved",
    timeout = 3000,
    icon = "💾"
  })
end

-- Record activity
local function on_activity()
  last_activity = vim.loop.hrtime()
  update_activity()
end

-- Format time display
local function format_time(seconds)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = math.floor(seconds % 60)

  if hours > 0 then
    return string.format("%dh %dm %ds", hours, minutes, secs)
  elseif minutes > 0 then
    return string.format("%dm %ds", minutes, secs)
  else
    return string.format("%ds", secs)
  end
end

-- Save current session to persistent storage
local function save_session()
  update_activity()
  local session_time = get_session_time()

  -- Only save if we have meaningful time (>= 1 second)
  if session_time < 1 then return true end

  local data = load_data()
  local today = os.date("%Y-%m-%d")
  local week = os.date("%Y-W%U")
  local month = os.date("%Y-%m")

  -- Add session time to totals
  data.daily[today] = (data.daily[today] or 0) + session_time
  data.weekly[week] = (data.weekly[week] or 0) + session_time
  data.monthly[month] = (data.monthly[month] or 0) + session_time
  data.total = data.total + session_time

  local success = save_data(data)
  if success then
    -- Send notification every 3rd auto-save (roughly every 15 minutes)
    save_count = save_count + 1
    if save_count % 3 == 0 then
      send_progress_notification(data)
    end

    -- Reset session after successful save
    session_start = vim.loop.hrtime()
  end

  return success
end

-- Show stats
local function show_stats()
  update_activity()
  local session_time = get_session_time()
  local data = load_data()

  local today = os.date("%Y-%m-%d")
  local week = os.date("%Y-W%U")
  local month = os.date("%Y-%m")

  local today_total = (data.daily[today] or 0) + session_time
  local week_total = (data.weekly[week] or 0) + session_time
  local month_total = (data.monthly[month] or 0) + session_time
  local project_total = data.total + session_time

  local lines = {
    "",
    "🔥 Current Session:  " .. format_time(session_time),
    "📅 Today's Total:    " .. format_time(today_total),
    "📊 This Week:        " .. format_time(week_total),
    "📈 This Month:       " .. format_time(month_total),
    "📁 Project Total:    " .. format_time(project_total),
    "",
    "📂 Project: " .. get_data_file():match("([^/]+)%.json$"),
    "📆 Date: " .. today,
    ""
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 40
  local height = #lines
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Coding Time ",
    title_pos = "center"
  })

  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  -- Close on any key
  for _, key in ipairs({"<Esc>", "q", "<CR>"}) do
    vim.api.nvim_buf_set_keymap(buf, "n", key, ":close<CR>", { noremap = true, silent = true })
  end
end

-- Reset functions
local function reset_today()
  local data = load_data()
  local today = os.date("%Y-%m-%d")
  local today_time = data.daily[today] or 0

  if today_time == 0 then
    vim.notify("No data to reset for today", vim.log.levels.INFO)
    return
  end

  local choice = vim.fn.confirm(
    string.format("Reset today's time (%s)?", format_time(today_time)),
    "&Yes\n&No", 2
  )

  if choice ~= 1 then return end

  local week = os.date("%Y-W%U")
  local month = os.date("%Y-%m")

  data.daily[today] = nil
  data.weekly[week] = math.max(0, (data.weekly[week] or 0) - today_time)
  data.monthly[month] = math.max(0, (data.monthly[month] or 0) - today_time)
  data.total = math.max(0, data.total - today_time)

  save_data(data)
  session_start = vim.loop.hrtime() -- Reset session
  save_count = 0 -- Reset notification counter

  vim.notify("Today's data reset", vim.log.levels.INFO)
end

local function reset_all()
  local data = load_data()
  local choice = vim.fn.confirm(
    string.format("Reset ALL data? Total: %s", format_time(data.total)),
    "&Yes\n&No", 2
  )

  if choice ~= 1 then return end

  save_data({ daily = {}, weekly = {}, monthly = {}, total = 0 })
  session_start = vim.loop.hrtime()
  save_count = 0

  vim.notify("All data reset", vim.log.levels.INFO)
end

-- Setup activity tracking
local group = vim.api.nvim_create_augroup("SimpleTimeTracker", { clear = true })

vim.api.nvim_create_autocmd({
  "InsertEnter", "InsertLeave", "TextChanged", "TextChangedI",
  "CursorMoved", "CursorMovedI"
}, {
  group = group,
  callback = on_activity
})

-- Auto-save every 5 minutes
vim.fn.timer_start(300000, function()
  local success, err = pcall(save_session)
  if not success then
    vim.notify("Auto-save error: " .. err, vim.log.levels.ERROR)
  end
end, { ["repeat"] = -1 })

-- Save on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    local success, err = pcall(save_session)
    if not success then
      vim.notify("Exit save error: " .. err, vim.log.levels.ERROR)
    end
  end
})

-- Commands
vim.api.nvim_create_user_command("CodingTime", function(opts)
  if opts.args == "reset" then
    reset_all()
  elseif opts.args == "reset-today" then
    reset_today()
  else
    show_stats()
  end
end, {
  nargs = "?",
  complete = function() return { "reset", "reset-today" } end
})

-- Keymap
vim.keymap.set("n", "fpt", show_stats, { desc = "Show coding time" })

return {}