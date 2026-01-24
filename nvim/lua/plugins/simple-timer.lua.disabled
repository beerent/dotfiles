-- Dead simple coding timer
-- Notifies when you start typing and when you stop for 1 minute

local is_active = false
local stop_timer = nil
local session_start_time = nil

-- Data storage
local data_dir = vim.fn.stdpath("data") .. "/simple-timer"
vim.fn.mkdir(data_dir, "p")

local function get_project_name()
  local cwd = vim.fn.getcwd()
  local git_root = vim.fn.system("cd " .. vim.fn.shellescape(cwd) .. " && git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  local project = (vim.v.shell_error == 0 and git_root ~= "") and git_root or cwd
  return project:match("([^/]+)$") or "unknown"
end

local function get_data_file(type_key)
  local today = os.date("%Y-%m-%d")
  local week = os.date("%Y-W%U")
  local month = os.date("%Y-%m")
  local project = get_project_name()

  if type_key == "day" then
    return data_dir .. "/day_" .. today .. ".txt"
  elseif type_key == "week" then
    return data_dir .. "/week_" .. week .. ".txt"
  elseif type_key == "month" then
    return data_dir .. "/month_" .. month .. ".txt"
  elseif type_key == "project" then
    return data_dir .. "/project_" .. project:gsub("[^%w%-_.]", "_") .. ".txt"
  end
end

local function load_total(type_key)
  local file = io.open(get_data_file(type_key), "r")
  if not file then
    return 0
  end

  local content = file:read("*all")
  file:close()

  return tonumber(content) or 0
end

local function save_total(type_key, total_seconds)
  local file = io.open(get_data_file(type_key), "w")
  if file then
    file:write(tostring(total_seconds))
    file:close()
  end
end

local function notify(message)
  vim.notify("[Timer] " .. message, vim.log.levels.INFO)
end

local function format_duration(seconds)
  local days = math.floor(seconds / 86400)
  local hours = math.floor((seconds % 86400) / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60

  local parts = {}

  if days > 0 then
    table.insert(parts, string.format("%dd", days))
  end

  if hours > 0 then
    table.insert(parts, string.format("%dh", hours))
  end

  if minutes > 0 then
    table.insert(parts, string.format("%dm", minutes))
  end

  if secs > 0 or #parts == 0 then
    table.insert(parts, string.format("%ds", secs))
  end

  return table.concat(parts, " ")
end

local function start_session()
  if not is_active then
    is_active = true
    session_start_time = os.time()
    notify("🟢 Started coding")
  end

  -- Cancel any existing stop timer
  if stop_timer then
    vim.fn.timer_stop(stop_timer)
    stop_timer = nil
  end

  -- Start a new 1-minute timer to detect when you stop
  stop_timer = vim.fn.timer_start(60000, function()
    if is_active then
      is_active = false
      local duration = os.time() - session_start_time

      -- Add this session to all totals
      for _, type_key in ipairs({"day", "week", "month", "project"}) do
        local total = load_total(type_key)
        save_total(type_key, total + duration)
      end

      local daily_total = load_total("day")
      notify("🔴 Stopped coding (1m idle) - Session: " .. format_duration(duration) .. " | Today: " .. format_duration(daily_total))
    end
    stop_timer = nil
  end)
end

local function show_stats()
  local current_duration = 0

  if is_active and session_start_time then
    current_duration = os.time() - session_start_time
  end

  local status = is_active and "🟢 Active" or "🔴 Inactive"
  local session_text = format_duration(current_duration)

  local daily_total = load_total("day") + current_duration
  local weekly_total = load_total("week") + current_duration
  local monthly_total = load_total("month") + current_duration
  local project_total = load_total("project") + current_duration

  local lines = {
    "",
    "⏱️  Coding Timer",
    "",
    "Status: " .. status,
    "Current Session: " .. session_text,
    "",
    "📅 Today: " .. format_duration(daily_total),
    "📊 This Week: " .. format_duration(weekly_total),
    "📈 This Month: " .. format_duration(monthly_total),
    "📁 Project: " .. format_duration(project_total),
    "",
    "Press q or ESC to close",
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
    title = " Coding Timer ",
    title_pos = "center"
  })

  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")

  for _, key in ipairs({"<Esc>", "q", "<CR>"}) do
    vim.api.nvim_buf_set_keymap(buf, "n", key, ":close<CR>", { noremap = true, silent = true })
  end
end

-- Track activity on these events
vim.api.nvim_create_autocmd({
  "InsertEnter", "TextChanged", "TextChangedI", "CursorMoved"
}, {
  callback = start_session
})

-- Keep timer active when entering terminal mode but still have a timeout
vim.api.nvim_create_autocmd({"TermEnter", "BufEnter"}, {
  callback = function()
    if vim.bo.buftype == "terminal" then
      if not is_active then
        -- Start session when entering terminal
        start_session()
      elseif is_active then
        -- Reset the stop timer with a longer timeout for terminal work
        if stop_timer then
          vim.fn.timer_stop(stop_timer)
        end

        -- Set a 5-minute timeout while in terminal
        stop_timer = vim.fn.timer_start(300000, function() -- 300 seconds (5 minutes)
          if is_active then
            is_active = false
            local duration = os.time() - session_start_time

            for _, type_key in ipairs({"day", "week", "month", "project"}) do
              local total = load_total(type_key)
              save_total(type_key, total + duration)
            end

            local daily_total = load_total("day")
            notify("🔴 Stopped coding (5m idle in terminal) - Session: " .. format_duration(duration) .. " | Today: " .. format_duration(daily_total))
          end
          stop_timer = nil
        end)
      end
    end
  end
})

-- Resume normal timer when leaving terminal
vim.api.nvim_create_autocmd({"BufLeave"}, {
  callback = function()
    if vim.bo.buftype == "terminal" and is_active then
      -- Restart normal 1-minute timer when leaving terminal
      start_session()
    end
  end
})

-- Track terminal activity (when typing in terminal)
vim.api.nvim_create_autocmd("TermChanged", {
  callback = function()
    if is_active then
      -- Reset the 5-minute timer on terminal activity
      if stop_timer then
        vim.fn.timer_stop(stop_timer)
      end

      stop_timer = vim.fn.timer_start(300000, function() -- 300 seconds (5 minutes)
        if is_active then
          is_active = false
          local duration = os.time() - session_start_time

          for _, type_key in ipairs({"day", "week", "month", "project"}) do
            local total = load_total(type_key)
            save_total(type_key, total + duration)
          end

          local daily_total = load_total("day")
          notify("🔴 Stopped coding (3m idle in terminal) - Session: " .. format_duration(duration) .. " | Today: " .. format_duration(daily_total))
        end
        stop_timer = nil
      end)
    end
  end
})


-- Manual pause/resume function
local function toggle_pause()
  if is_active then
    -- Pause: save current session and stop
    is_active = false
    if stop_timer then
      vim.fn.timer_stop(stop_timer)
      stop_timer = nil
    end

    local duration = os.time() - session_start_time
    for _, type_key in ipairs({"day", "week", "month", "project"}) do
      local total = load_total(type_key)
      save_total(type_key, total + duration)
    end

    notify("⏸️  Timer paused - Session saved: " .. format_duration(duration))
  else
    -- Resume: start new session
    start_session()
    notify("▶️  Timer resumed")
  end
end

-- Add the fpt keymap for stats
vim.keymap.set("n", "fpt", show_stats, { desc = "Show coding timer stats" })

-- Add fps keymap for pause/resume
vim.keymap.set("n", "fps", toggle_pause, { desc = "Pause/resume coding timer" })

return {}