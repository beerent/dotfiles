-- State variables
local last_activity_time = vim.loop.hrtime()
local session_start_time = vim.loop.hrtime()
local current_session_time = 0
local last_saved_session_time = 0  -- Track what's already been saved
local daily_time = 0
local project_total_time = 0
local is_tracking = true
local inactive_threshold = 30 * 1000000000 -- 30 seconds in nanoseconds
local last_notification_time = 0 -- Track when we last sent a notification (in seconds)

-- Data storage path
local data_dir = vim.fn.stdpath("data") .. "/coding-time-tracker"
vim.fn.mkdir(data_dir, "p")

-- Helper function to get current project root
local function get_project_root()
  local cwd = vim.fn.getcwd()
  local git_root = vim.fn.system("cd " .. vim.fn.shellescape(cwd) .. " && git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  if vim.v.shell_error == 0 and git_root ~= "" then
    return git_root
  end
  return cwd
end

-- Helper function to get current date string
local function get_date_string()
  return os.date("%Y-%m-%d")
end

-- Helper function to get current week string
local function get_week_string()
  return os.date("%Y-W%U")
end

-- Helper function to get current month string
local function get_month_string()
  return os.date("%Y-%m")
end

-- Helper function to get data file path
local function get_data_file_path()
  local project_root = get_project_root()
  local project_name = project_root:match("([^/]+)$") or "unknown"
  return data_dir .. "/" .. project_name:gsub("[^%w%-_.]", "_") .. ".json"
end

-- Load existing data
local function load_data()
  local file_path = get_data_file_path()
  local file = io.open(file_path, "r")
  if not file then
    return {
      daily = {},
      weekly = {},
      monthly = {},
      total = 0,
      session_data = {}
    }
  end
  
  local content = file:read("*all")
  file:close()
  
  local success, data = pcall(vim.json.decode, content)
  if not success or not data then
    return {
      daily = {},
      weekly = {},
      monthly = {},
      total = 0,
      session_data = {}
    }
  end
  
  -- Ensure all required fields exist
  data.daily = data.daily or {}
  data.weekly = data.weekly or {}
  data.monthly = data.monthly or {}
  data.total = data.total or 0
  data.session_data = data.session_data or {}
  
  return data
end

-- Save data to file
local function save_data(data)
  local file_path = get_data_file_path()
  local file = io.open(file_path, "w")
  if not file then
    vim.notify("Failed to save coding time data", vim.log.levels.ERROR)
    return
  end
  
  file:write(vim.json.encode(data))
  file:close()
end

-- Update tracking state
local function update_tracking()
  local current_time = vim.loop.hrtime()
  local time_since_activity = current_time - last_activity_time
  
  if time_since_activity > inactive_threshold then
    if is_tracking then
      -- Just became inactive, save the session time
      current_session_time = current_session_time + (last_activity_time - session_start_time) / 1000000000
      is_tracking = false
    end
  else
    if not is_tracking then
      -- Just became active again
      session_start_time = current_time
      is_tracking = true
    end
  end
end

-- Format time in hours, minutes, seconds
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

-- Send coding time notification with current stats
local function send_coding_notification()
  update_tracking()
  
  -- Calculate current total session time
  local total_session_time = current_session_time
  if is_tracking then
    total_session_time = total_session_time + (vim.loop.hrtime() - session_start_time) / 1000000000
  end
  
  -- Load data for notification
  local data = load_data()
  local today = get_date_string()
  local this_week = get_week_string()
  local this_month = get_month_string()
  
  local today_total = (data.daily[today] or 0) + total_session_time
  local week_total = (data.weekly[this_week] or 0) + total_session_time
  local month_total = (data.monthly[this_month] or 0) + total_session_time
  local project_total = data.total + total_session_time
  
  local current_hour = math.floor(total_session_time / 3600)
  
  -- Create notification message
  local title = "💻 Coding Time Update!"
  local message = string.format(
    "Session: %s\nToday: %s\nWeek: %s\nMonth: %s\nProject: %s",
    format_time(total_session_time),
    format_time(today_total),
    format_time(week_total), 
    format_time(month_total),
    format_time(project_total)
  )
  
  -- Use nvim-notify for fancy notification
  local notify = require("notify")
  notify(message, "info", {
    title = title,
    timeout = 4000,
    icon = "💻"
  })
end

-- Check for 25-minute intervals and send notifications
local function check_notification_intervals()
  -- Calculate current total session time
  local total_session_time = current_session_time
  if is_tracking then
    total_session_time = total_session_time + (vim.loop.hrtime() - session_start_time) / 1000000000
  end
  
  -- Check if we've hit a new 25-minute interval (1500 seconds)
  local minutes_25_intervals = math.floor(total_session_time / 1500)
  
  if minutes_25_intervals > last_notification_time and minutes_25_intervals > 0 then
    send_coding_notification()
    last_notification_time = minutes_25_intervals
  end
end

-- Activity handler
local function on_activity()
  last_activity_time = vim.loop.hrtime()
  update_tracking()
  check_notification_intervals()
end

-- Show programming time statistics
local function show_programming_time()
  update_tracking()
  
  -- Calculate current session time
  local current_session_total = current_session_time
  if is_tracking then
    current_session_total = current_session_total + (vim.loop.hrtime() - session_start_time) / 1000000000
  end
  
  -- Load data and calculate daily/weekly/monthly/project totals
  local data = load_data()
  local today = get_date_string()
  local this_week = get_week_string()
  local this_month = get_month_string()
  
  local today_total = (data.daily[today] or 0) + current_session_total
  local week_total = (data.weekly[this_week] or 0) + current_session_total
  local month_total = (data.monthly[this_month] or 0) + current_session_total
  local project_total = data.total + current_session_total
  
  -- Create display
  local lines = {
    "",
    "🔥 Current Session:  " .. format_time(current_session_total),
    "📅 Today's Total:    " .. format_time(today_total),
    "📊 This Week:        " .. format_time(week_total),
    "📈 This Month:       " .. format_time(month_total),
    "📁 Project Total:    " .. format_time(project_total),
    "",
    "📂 Project: " .. get_project_root():match("([^/]+)$"),
    "📆 Date: " .. today,
    ""
  }
  
  -- Create floating window
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
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  
  -- Close on any key press
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<CR>", ":close<CR>", { noremap = true, silent = true })
end

-- Save session data periodically
local function save_session_data(is_exit)
  update_tracking()
  
  local data = load_data()
  local today = get_date_string()
  local this_week = get_week_string()
  local this_month = get_month_string()
  
  -- Calculate total session time
  local total_session_time = current_session_time
  if is_tracking then
    total_session_time = total_session_time + (vim.loop.hrtime() - session_start_time) / 1000000000
  end
  
  -- Calculate only the new time to save (what hasn't been saved yet)
  local new_time_to_save = total_session_time - last_saved_session_time
  
  if new_time_to_save > 0 then
    data.daily[today] = (data.daily[today] or 0) + new_time_to_save
    data.weekly[this_week] = (data.weekly[this_week] or 0) + new_time_to_save
    data.monthly[this_month] = (data.monthly[this_month] or 0) + new_time_to_save
    data.total = data.total + new_time_to_save
    
    -- Update last saved time (don't reset current session)
    last_saved_session_time = total_session_time
    
    -- Only reset session on exit or explicit reset
    if is_exit then
      current_session_time = 0
      last_saved_session_time = 0
      data.session_data = {}
      session_start_time = vim.loop.hrtime()
    elseif is_tracking then
      -- If still tracking, update session time and reset the timer
      current_session_time = total_session_time
      session_start_time = vim.loop.hrtime()
    end
  end
  
  -- Always save session state for persistence across sleep/wake
  if not is_exit then
    data.session_data = {
      current_session_time = total_session_time,
      last_saved_session_time = last_saved_session_time,
      last_notification_time = last_notification_time,
      session_start_timestamp = os.time()
    }
  end
  
  save_data(data)
end

-- Setup autocommands for activity detection
local group = vim.api.nvim_create_augroup("CodingTimeTracker", { clear = true })

-- Track any key press as activity
vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave", "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI" }, {
  group = group,
  callback = on_activity
})

-- Save data periodically (every 5 minutes)
vim.fn.timer_start(300000, save_session_data, { ["repeat"] = -1 })

-- Save data on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function() save_session_data(true) end
})

-- Reset today's data only
local function reset_today_data()
  local data = load_data()
  local today = get_date_string()
  local today_time = data.daily[today] or 0
  
  if today_time == 0 then
    vim.notify("No data to reset for today", vim.log.levels.INFO)
    return
  end
  
  -- Ask for confirmation
  local choice = vim.fn.confirm(
    string.format("Reset today's coding time (%s)?\nThis will remove today's data from all totals.", format_time(today_time)),
    "&Yes\n&No",
    2
  )
  
  if choice ~= 1 then
    vim.notify("Reset cancelled", vim.log.levels.INFO)
    return
  end
  
  local this_week = get_week_string()
  local this_month = get_month_string()
  
  -- Remove today's time from all totals
  data.daily[today] = nil
  data.weekly[this_week] = (data.weekly[this_week] or 0) - today_time
  data.monthly[this_month] = (data.monthly[this_month] or 0) - today_time
  data.total = data.total - today_time
  
  -- Clean up negative values (shouldn't happen but just in case)
  if data.weekly[this_week] < 0 then data.weekly[this_week] = 0 end
  if data.monthly[this_month] < 0 then data.monthly[this_month] = 0 end
  if data.total < 0 then data.total = 0 end
  
  save_data(data)
  
  -- Reset current session
  current_session_time = 0
  last_saved_session_time = 0
  last_hour_notified = 0
  session_start_time = vim.loop.hrtime()
  
  vim.notify("Today's coding time data reset for project: " .. get_project_root():match("([^/]+)$"), vim.log.levels.INFO)
end

-- Reset all data for current project
local function reset_project_data()
  local data = load_data()
  local project_name = get_project_root():match("([^/]+)$")
  
  -- Ask for confirmation
  local choice = vim.fn.confirm(
    string.format("Reset ALL coding time data for project '%s'?\nTotal project time: %s\nThis action cannot be undone.", project_name, format_time(data.total)),
    "&Yes\n&No",
    2
  )
  
  if choice ~= 1 then
    vim.notify("Reset cancelled", vim.log.levels.INFO)
    return
  end
  
  local file_path = get_data_file_path()
  local file = io.open(file_path, "w")
  if file then
    file:write(vim.json.encode({
      daily = {},
      weekly = {},
      monthly = {},
      total = 0,
      session_data = {}
    }))
    file:close()
    
    -- Reset session variables
    current_session_time = 0
    last_saved_session_time = 0
    last_notification_time = 0
    session_start_time = vim.loop.hrtime()
    daily_time = 0
    project_total_time = 0
    
    vim.notify("Coding time data reset for project: " .. project_name, vim.log.levels.INFO)
  else
    vim.notify("Failed to reset coding time data", vim.log.levels.ERROR)
  end
end

-- Create commands
vim.api.nvim_create_user_command("ShowProgrammingTime", show_programming_time, {})
vim.api.nvim_create_user_command("CodingTime", function(opts)
  if opts.args == "reset" then
    reset_project_data()
  elseif opts.args == "reset-today" then
    reset_today_data()
  elseif opts.args == "notify" then
    send_coding_notification()
  else
    show_programming_time()
  end
end, {
  nargs = "?",
  complete = function()
    return { "reset", "reset-today", "notify" }
  end
})

-- Setup keymap
vim.keymap.set("n", "fpt", show_programming_time, { desc = "Show programming time" })

-- Initialize and restore session if needed
local data = load_data()
daily_time = data.daily[get_date_string()] or 0
project_total_time = data.total or 0

-- Restore session state if it exists and is recent (within 24 hours)
if data.session_data and data.session_data.session_start_timestamp then
  local time_since_last_session = os.time() - data.session_data.session_start_timestamp
  
  -- Only restore if the last session was within the last 24 hours
  if time_since_last_session < 86400 then  -- 24 hours in seconds
    current_session_time = data.session_data.current_session_time or 0
    last_saved_session_time = data.session_data.last_saved_session_time or 0
    last_notification_time = data.session_data.last_notification_time or 0
    
    -- Reset the session start time to now since we're resuming
    session_start_time = vim.loop.hrtime()
    
    vim.notify(string.format("Restored coding session: %s", format_time(current_session_time)), vim.log.levels.INFO)
  else
    -- Session is too old, clear it
    data.session_data = {}
    save_data(data)
  end
end

return {}