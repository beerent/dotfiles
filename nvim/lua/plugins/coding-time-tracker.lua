-- Global coding time tracker
-- Works across all Neovim sessions/tabs - only one instance "owns" the clock at a time
-- When you switch between sessions, time tracking seamlessly transfers

-- ============================================================================
-- Constants
-- ============================================================================
local instance_id = vim.fn.getpid() .. "-" .. vim.loop.hrtime()
local INACTIVE_THRESHOLD_SEC = 10 -- seconds of inactivity before going idle (TESTING: set to 10)
local HEARTBEAT_INTERVAL_MS = 5000 -- update heartbeat every 5 seconds
local CLAIM_TIMEOUT_SEC = 10 -- if owner hasn't updated in 10 seconds, claim ownership
local MAX_ELAPSED_SEC = 15 -- max time to add per update (3x heartbeat for safety margin)
local ACTIVITY_DEBOUNCE_SEC = 1 -- debounce rapid activity events
local STATE_CACHE_TTL = 2 -- seconds to cache state file
local HUD_UPDATE_INTERVAL_MS = 1000 -- update HUD every second

-- ============================================================================
-- State Variables
-- ============================================================================
local is_active = false
local last_local_activity = os.time()
local last_heartbeat_time = os.time()
local active_seconds_since_notification = 0

-- State caching to reduce file I/O
local cached_state = nil
local cached_state_time = 0

-- HUD state (per-tab: keyed by tab page ID)
local hud_tabs = {} -- { [tabpage_id] = { win = ..., buf = ... } }
local hud_timer = nil

-- ============================================================================
-- Data Storage
-- ============================================================================
local data_dir = vim.fn.stdpath("data") .. "/global-coding-timer"
vim.fn.mkdir(data_dir, "p")

local function get_data_file()
  return data_dir .. "/data.json"
end

local function get_state_file()
  return data_dir .. "/state.json"
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

-- Safe number conversion - returns 0 for non-numbers
local function safe_number(val)
  return type(val) == "number" and val or 0
end

-- Get date keys for today, this week, and this month
local function get_date_keys()
  return {
    today = os.date("%Y-%m-%d"),
    week = os.date("%Y-W%U"),
    month = os.date("%Y-%m")
  }
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

-- ============================================================================
-- Data Loading (with caching for state)
-- ============================================================================

-- Load time data (no caching - data changes frequently)
local function load_data()
  local data = load_json(get_data_file(), { daily = {}, weekly = {}, monthly = {}, total = 0 })
  data.daily = data.daily or {}
  data.weekly = data.weekly or {}
  data.monthly = data.monthly or {}
  data.total = safe_number(data.total)
  return data
end

-- Load global state with caching
local function load_state()
  local now = os.time()
  if cached_state and (now - cached_state_time) < STATE_CACHE_TTL then
    return cached_state
  end

  cached_state = load_json(get_state_file(), {
    owner = nil,
    last_update = 0,
    last_activity = 0
  })
  cached_state_time = now
  return cached_state
end

-- Save state and invalidate cache
local function save_state(state)
  cached_state = nil
  return save_json(get_state_file(), state)
end

-- ============================================================================
-- Core Logic
-- ============================================================================

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
    save_state(state)
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

  -- Sanity check: only add time within expected range
  -- MAX_ELAPSED_SEC is 15 seconds (3x heartbeat interval for safety)
  if elapsed > 0 and elapsed <= MAX_ELAPSED_SEC then
    local data = load_data()
    local dates = get_date_keys()

    -- Use safe_number to handle any corrupted data
    data.daily[dates.today] = safe_number(data.daily[dates.today]) + elapsed
    data.weekly[dates.week] = safe_number(data.weekly[dates.week]) + elapsed
    data.monthly[dates.month] = safe_number(data.monthly[dates.month]) + elapsed
    data.total = safe_number(data.total) + elapsed

    save_json(get_data_file(), data)

    -- Track active time for notifications
    active_seconds_since_notification = active_seconds_since_notification + elapsed
  end

  -- Update state
  state.last_update = now
  state.last_activity = now
  save_state(state)

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
    save_state(state)
  end
end

-- Heartbeat: maintain ownership and update clock while active
local function heartbeat()
  if not is_active then return end

  local now = os.time()
  local since_last_heartbeat = now - last_heartbeat_time
  last_heartbeat_time = now

  -- Detect sleep/wake: if >30 seconds since last heartbeat, system likely slept
  if since_last_heartbeat > 30 then
    is_active = false
    release_ownership()
    vim.notify("[Timer] Paused (system was asleep)", vim.log.levels.INFO)
    return
  end

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

-- ============================================================================
-- Activity Handling
-- ============================================================================

-- Record local activity (single entry point for all activity events)
local function on_activity()
  local now = os.time()

  -- Debounce: skip if last activity was within 1 second
  if (now - last_local_activity) < ACTIVITY_DEBOUNCE_SEC then
    return
  end

  local was_active = is_active
  last_local_activity = now
  is_active = true

  -- Try to claim ownership when becoming active
  if not was_active then
    if claim_ownership() then
      vim.notify("[Timer] Resumed", vim.log.levels.INFO)
    end
  end
end

-- ============================================================================
-- Display Functions
-- ============================================================================

-- Format time display
local function format_time(seconds)
  seconds = math.floor(safe_number(seconds))
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

-- Format time compact (for HUD)
local function format_time_compact(seconds)
  seconds = math.floor(safe_number(seconds))
  local hours = math.floor(seconds / 3600)
  local minutes = math.floor((seconds % 3600) / 60)
  local secs = seconds % 60

  if hours > 0 then
    return string.format("%d:%02d:%02d", hours, minutes, secs)
  else
    return string.format("%d:%02d", minutes, secs)
  end
end

-- Send progress notification
local function send_progress_notification(data)
  local dates = get_date_keys()

  local message = string.format(
    "Today: %s\nWeek: %s\nMonth: %s\nTotal: %s",
    format_time(data.daily[dates.today] or 0),
    format_time(data.weekly[dates.week] or 0),
    format_time(data.monthly[dates.month] or 0),
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

-- ============================================================================
-- HUD (Heads-Up Display) - Per-Tab Independent
-- ============================================================================

-- Get HUD content lines
local function get_hud_content()
  local data = load_data()
  local state = load_state()
  local dates = get_date_keys()
  local now = os.time()

  -- Status indicator
  local status_icon = is_active and "●" or "○"

  -- Ownership
  local owner_icon
  if state.owner == instance_id then
    owner_icon = "★"
  elseif state.owner then
    owner_icon = "◇"
  else
    owner_icon = "−"
  end

  -- Countdown timer until inactive
  local idle_time = now - last_local_activity
  local remaining = math.max(0, INACTIVE_THRESHOLD_SEC - idle_time)
  local countdown_str
  if is_active then
    countdown_str = string.format("[%ds]", remaining)
  else
    countdown_str = "[--]"
  end

  -- Today's time
  local today_time = format_time_compact(data.daily[dates.today] or 0)

  return {
    string.format(" %s %s %s ", status_icon, owner_icon, countdown_str),
    string.format(" Today: %s ", today_time),
  }
end

-- Update HUD content for a specific tab
local function update_tab_hud(tabpage, hud)
  if not hud or not hud.win or not vim.api.nvim_win_is_valid(hud.win) then
    return
  end

  local lines = get_hud_content()

  -- Calculate width based on content
  local max_width = 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, #line)
  end

  -- Update buffer content
  pcall(function()
    vim.api.nvim_buf_set_option(hud.buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(hud.buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(hud.buf, "modifiable", false)

    -- Reposition window (top right)
    vim.api.nvim_win_set_config(hud.win, {
      relative = "editor",
      width = max_width,
      height = #lines,
      row = 0,
      col = vim.o.columns - max_width - 2,
    })
  end)
end

-- Update all HUDs across all tabs
local function update_all_huds()
  for tabpage, hud in pairs(hud_tabs) do
    if vim.api.nvim_tabpage_is_valid(tabpage) then
      update_tab_hud(tabpage, hud)
    else
      -- Clean up invalid tabs
      hud_tabs[tabpage] = nil
    end
  end
end

-- Create HUD for current tab
local function create_hud_for_tab()
  local tabpage = vim.api.nvim_get_current_tabpage()

  -- Already has HUD
  if hud_tabs[tabpage] and hud_tabs[tabpage].win and vim.api.nvim_win_is_valid(hud_tabs[tabpage].win) then
    return
  end

  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", "CodingTimeHUD")

  -- Initial content
  local lines = get_hud_content()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Calculate position (top right)
  local width = 20
  local height = 2
  local col = vim.o.columns - width - 2

  -- Create floating window
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = width,
    height = height,
    row = 0,
    col = col,
    style = "minimal",
    border = "rounded",
    focusable = false,
    zindex = 50,
  })

  -- Set window options
  vim.api.nvim_win_set_option(win, "winblend", 20)

  -- Store in per-tab table
  hud_tabs[tabpage] = { win = win, buf = buf }

  -- Start global update timer if not running
  if not hud_timer then
    hud_timer = vim.fn.timer_start(HUD_UPDATE_INTERVAL_MS, function()
      vim.schedule(function()
        pcall(update_all_huds)
      end)
    end, { ["repeat"] = -1 })
  end
end

-- Destroy HUD for current tab
local function destroy_hud_for_tab()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local hud = hud_tabs[tabpage]

  if hud then
    if hud.win and vim.api.nvim_win_is_valid(hud.win) then
      pcall(vim.api.nvim_win_close, hud.win, true)
    end
    hud_tabs[tabpage] = nil
  end

  -- Stop timer if no HUDs left
  if next(hud_tabs) == nil and hud_timer then
    vim.fn.timer_stop(hud_timer)
    hud_timer = nil
  end
end

-- Check if current tab has HUD
local function current_tab_has_hud()
  local tabpage = vim.api.nvim_get_current_tabpage()
  local hud = hud_tabs[tabpage]
  return hud and hud.win and vim.api.nvim_win_is_valid(hud.win)
end

-- Toggle HUD for current tab only
local function toggle_hud()
  if current_tab_has_hud() then
    destroy_hud_for_tab()
    vim.notify("[Timer] HUD hidden (this tab)", vim.log.levels.INFO)
  else
    create_hud_for_tab()
    vim.notify("[Timer] HUD shown (this tab)", vim.log.levels.INFO)
  end
end

-- Cleanup all HUDs (called on exit)
local function cleanup_all_huds()
  if hud_timer then
    vim.fn.timer_stop(hud_timer)
    hud_timer = nil
  end

  for tabpage, hud in pairs(hud_tabs) do
    if hud.win and vim.api.nvim_win_is_valid(hud.win) then
      pcall(vim.api.nvim_win_close, hud.win, true)
    end
  end
  hud_tabs = {}
end

-- Show stats popup
local function show_stats()
  local data = load_data()
  local state = load_state()
  local dates = get_date_keys()

  local today_total = safe_number(data.daily[dates.today])
  local week_total = safe_number(data.weekly[dates.week])
  local month_total = safe_number(data.monthly[dates.month])

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
    "Date: " .. dates.today,
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

-- ============================================================================
-- Reset Functions
-- ============================================================================

local function reset_today()
  local data = load_data()
  local dates = get_date_keys()
  local today_time = safe_number(data.daily[dates.today])

  if today_time == 0 then
    vim.notify("No data to reset for today", vim.log.levels.INFO)
    return
  end

  local choice = vim.fn.confirm(
    string.format("Reset today's time (%s)?", format_time(today_time)),
    "&Yes\n&No", 2
  )

  if choice ~= 1 then return end

  data.daily[dates.today] = nil
  data.weekly[dates.week] = math.max(0, safe_number(data.weekly[dates.week]) - today_time)
  data.monthly[dates.month] = math.max(0, safe_number(data.monthly[dates.month]) - today_time)
  data.total = math.max(0, safe_number(data.total) - today_time)

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

-- ============================================================================
-- Autocmd Setup (simplified - fewer handlers)
-- ============================================================================

local group = vim.api.nvim_create_augroup("GlobalTimeTracker", { clear = true })

-- Track activity on common coding events
vim.api.nvim_create_autocmd({
  "InsertEnter", "InsertLeave", "TextChanged", "TextChangedI",
  "CursorMoved", "CursorMovedI"
}, {
  group = group,
  callback = on_activity
})

-- Track activity in terminal mode using global key handler
-- Standard autocmds don't fire in terminal mode, so we use vim.on_key()
vim.on_key(function(key)
  -- Only trigger for terminal mode
  if vim.fn.mode() == "t" then
    -- Schedule to avoid issues with recursive callbacks
    vim.schedule(function()
      on_activity()
    end)
  end
end)

-- Track window/tab focus changes
vim.api.nvim_create_autocmd("FocusGained", {
  group = group,
  callback = on_activity
})

-- Track buffer/window/tab enter
vim.api.nvim_create_autocmd({"BufEnter", "WinEnter", "TabEnter"}, {
  group = group,
  callback = on_activity
})

-- Track mode changes (catches terminal mode transitions)
vim.api.nvim_create_autocmd("ModeChanged", {
  group = group,
  callback = on_activity
})

-- Release ownership on exit
vim.api.nvim_create_autocmd("VimLeavePre", {
  group = group,
  callback = function()
    pcall(release_ownership)
    pcall(cleanup_all_huds)
  end
})

-- Update HUDs on resize
vim.api.nvim_create_autocmd("VimResized", {
  group = group,
  callback = function()
    vim.schedule(function()
      pcall(update_all_huds)
    end)
  end
})

-- ============================================================================
-- Timers
-- ============================================================================

-- Heartbeat timer - updates clock and checks for inactivity
vim.fn.timer_start(HEARTBEAT_INTERVAL_MS, function()
  vim.schedule(function()
    pcall(heartbeat)
  end)
end, { ["repeat"] = -1 })

-- Progress notification timer - check every 5 minutes
vim.fn.timer_start(300000, function()
  vim.schedule(function()
    if is_active and active_seconds_since_notification >= 900 then
      local data = load_data()
      send_progress_notification(data)
      active_seconds_since_notification = 0
    end
  end)
end, { ["repeat"] = -1 })

-- ============================================================================
-- Commands and Keymaps
-- ============================================================================

vim.api.nvim_create_user_command("CodingTime", function(opts)
  if opts.args == "reset" then
    reset_all()
  elseif opts.args == "reset-today" then
    reset_today()
  elseif opts.args == "hud" then
    toggle_hud()
  else
    show_stats()
  end
end, {
  nargs = "?",
  complete = function() return { "reset", "reset-today", "hud" } end
})

vim.keymap.set("n", "fpt", show_stats, { desc = "Show coding time" })
vim.keymap.set("n", "fph", toggle_hud, { desc = "Toggle coding time HUD" })

-- Start tracking immediately if we can claim ownership
vim.schedule(function()
  on_activity()
end)

return {}
