-- Global coding time tracker
-- Works across all Neovim sessions/tabs - only one instance "owns" the clock at a time
-- When you switch between sessions, time tracking seamlessly transfers

-- Instance identification
local instance_id = vim.fn.getpid() .. "-" .. vim.loop.hrtime()
local INACTIVE_THRESHOLD_SEC = 30 -- seconds of inactivity before going idle
local HEARTBEAT_INTERVAL_MS = 5000 -- update heartbeat every 5 seconds
local CLAIM_TIMEOUT_SEC = 10 -- if owner hasn't updated in 10 seconds, claim ownership

-- State
local is_active = false
local last_local_activity = os.time()
local save_count = 0

-- Data storage - GLOBAL, not per-project
local data_dir = vim.fn.stdpath("data") .. "/global-coding-timer"
vim.fn.mkdir(data_dir, "p")

local function get_data_file()
  return data_dir .. "/data.json"
end

local function get_state_file()
  return data_dir .. "/state.json"
end

-- Load JSON file with error handling
local function load_json(file_path, default)
  local file = io.open(file_path, "r")
  if not file then
    return default
  end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then
    return default
  end

  local success, data = pcall(vim.json.decode, content)
  if not success or type(data) ~= "table" then
    local backup = file_path .. ".backup." .. os.date("%Y%m%d_%H%M%S")
    vim.fn.rename(file_path, backup)
    return default
  end

  return data
end

-- Save JSON file atomically
local function save_json(file_path, data)
  local temp_path = file_path .. ".tmp." .. instance_id
  local success, json = pcall(vim.json.encode, data)
  if not success then return false end

  local file = io.open(temp_path, "w")
  if not file then return false end

  file:write(json)
  file:close()

  if vim.fn.rename(temp_path, file_path) ~= 0 then
    vim.fn.delete(temp_path)
    return false
  end

  return true
end

-- Load time data
local function load_data()
  local data = load_json(get_data_file(), { daily = {}, weekly = {}, monthly = {}, total = 0 })
  data.daily = data.daily or {}
  data.weekly = data.weekly or {}
  data.monthly = data.monthly or {}
  data.total = data.total or 0
  return data
end

-- Load global state (who owns the clock)
local function load_state()
  return load_json(get_state_file(), {
    owner = nil,
    last_update = 0,
    last_activity = 0
  })
end

-- Try to claim ownership of the global clock
-- Returns true if we are (or became) the owner
local function claim_ownership()
  local state = load_state()
  local now = os.time()

  -- We're already the owner
  if state.owner == instance_id then
    return true
  end

  -- Previous owner timed out, or no owner
  if not state.owner or (now - state.last_update) > CLAIM_TIMEOUT_SEC then
    state.owner = instance_id
    state.last_update = now
    state.last_activity = now
    save_json(get_state_file(), state)
    return true
  end

  return false
end

-- Update the global clock (add elapsed time since last update)
-- Only the owner can do this
local function update_global_clock()
  local state = load_state()
  local now = os.time()

  -- Only the owner updates the clock
  if state.owner ~= instance_id then
    return false
  end

  local elapsed = now - state.last_activity

  -- Sanity check: don't add huge amounts of time (e.g., if clock was stuck)
  if elapsed > 0 and elapsed < 3600 then -- max 1 hour per update
    local data = load_data()
    local today = os.date("%Y-%m-%d")
    local week = os.date("%Y-W%U")
    local month = os.date("%Y-%m")

    data.daily[today] = (data.daily[today] or 0) + elapsed
    data.weekly[week] = (data.weekly[week] or 0) + elapsed
    data.monthly[month] = (data.monthly[month] or 0) + elapsed
    data.total = data.total + elapsed

    save_json(get_data_file(), data)
  end

  -- Update state
  state.last_update = now
  state.last_activity = now
  save_json(get_state_file(), state)

  return true
end

-- Release ownership (when going inactive)
local function release_ownership()
  local state = load_state()
  if state.owner == instance_id then
    -- Final clock update before releasing
    update_global_clock()
    state.owner = nil
    state.last_update = os.time()
    save_json(get_state_file(), state)
  end
end

-- Heartbeat: maintain ownership and update clock while active
local function heartbeat()
  if not is_active then return end

  local now = os.time()

  -- Check if we've gone inactive locally
  if (now - last_local_activity) > INACTIVE_THRESHOLD_SEC then
    is_active = false
    release_ownership()
    vim.notify("[Timer] Paused (inactive)", vim.log.levels.INFO)
    return
  end

  -- Try to claim/maintain ownership and update clock
  if claim_ownership() then
    update_global_clock()
  end
end

-- Format time display
local function format_time(seconds)
  seconds = math.floor(seconds or 0)
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60

  if hours > 0 then
    return string.format("%dh %dm %ds", hours, minutes, secs)
  elseif minutes > 0 then
    return string.format("%dm %ds", minutes, secs)
  else
    return string.format("%ds", secs)
  end
end

-- Record local activity
local function on_activity()
  local was_active = is_active
  last_local_activity = os.time()
  is_active = true

  -- Try to claim ownership when becoming active
  if not was_active then
    if claim_ownership() then
      vim.notify("[Timer] Resumed", vim.log.levels.INFO)
    end
  end
end

-- Send progress notification
local function send_progress_notification(data)
  local today = os.date("%Y-%m-%d")
  local week = os.date("%Y-W%U")
  local month = os.date("%Y-%m")

  local message = string.format(
    "Today: %s\nWeek: %s\nMonth: %s\nTotal: %s",
    format_time(data.daily[today] or 0),
    format_time(data.weekly[week] or 0),
    format_time(data.monthly[month] or 0),
    format_time(data.total)
  )

  local ok, notify = pcall(require, "notify")
  if ok then
    notify("Progress Update!\n\n" .. message, "info", {
      title = "Coding Time",
      timeout = 3000
    })
  else
    vim.notify("Coding Time: " .. message, vim.log.levels.INFO)
  end
end

-- Show stats
local function show_stats()
  local data = load_data()
  local state = load_state()

  local today = os.date("%Y-%m-%d")
  local week = os.date("%Y-W%U")
  local month = os.date("%Y-%m")

  local today_total = data.daily[today] or 0
  local week_total = data.weekly[week] or 0
  local month_total = data.monthly[month] or 0

  local status = is_active and "Active" or "Paused"
  local owner_status = state.owner == instance_id and "(this session)" or
                       state.owner and "(another session)" or "(no active session)"

  local lines = {
    "",
    "Status: " .. status .. " " .. owner_status,
    "",
    "Today:      " .. format_time(today_total),
    "This Week:  " .. format_time(week_total),
    "This Month: " .. format_time(month_total),
    "All Time:   " .. format_time(data.total),
    "",
    "Date: " .. today,
    ""
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 42
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
    title = " Global Coding Time ",
    title_pos = "center"
  })

  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

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

  save_json(get_data_file(), data)
  vim.notify("Today's data reset", vim.log.levels.INFO)
end

local function reset_all()
  local data = load_data()
  local choice = vim.fn.confirm(
    string.format("Reset ALL data? Total: %s", format_time(data.total)),
    "&Yes\n&No", 2
  )

  if choice ~= 1 then return end

  save_json(get_data_file(), { daily = {}, weekly = {}, monthly = {}, total = 0 })
  vim.notify("All data reset", vim.log.levels.INFO)
end

-- Setup activity tracking
local group = vim.api.nvim_create_augroup("GlobalTimeTracker", { clear = true })

-- Track activity on common coding events
vim.api.nvim_create_autocmd({
  "InsertEnter", "InsertLeave", "TextChanged", "TextChangedI",
  "CursorMoved", "CursorMovedI"
}, {
  group = group,
  callback = on_activity
})

-- Also track terminal activity
vim.api.nvim_create_autocmd({"TermEnter", "TermLeave"}, {
  group = group,
  callback = on_activity
})

-- Track window/tab focus changes
vim.api.nvim_create_autocmd({"FocusGained", "BufEnter", "WinEnter", "TabEnter"}, {
  group = group,
  callback = on_activity
})

-- Heartbeat timer - updates clock and checks for inactivity
vim.fn.timer_start(HEARTBEAT_INTERVAL_MS, function()
  vim.schedule(function()
    local success, err = pcall(heartbeat)
    if not success then
      -- Silent fail - don't spam errors
    end
  end)
end, { ["repeat"] = -1 })

-- Periodic notification (every ~15 minutes of active time)
vim.fn.timer_start(300000, function()
  vim.schedule(function()
    if is_active then
      save_count = save_count + 1
      if save_count % 3 == 0 then
        local data = load_data()
        send_progress_notification(data)
      end
    end
  end)
end, { ["repeat"] = -1 })

-- Release ownership on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    pcall(release_ownership)
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

-- Start tracking immediately if we can claim ownership
vim.schedule(function()
  on_activity()
end)

return {}