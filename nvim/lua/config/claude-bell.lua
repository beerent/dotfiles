-- Claude Code bell notification for terminal tabs
-- Three visual states for non-current tabs:
--   🧠 Running: Claude is actively working (set on PreToolUse, cleared on Stop)
--   🔔 Bell: tab needs your attention (Stop finished, or tool awaiting permission)
--   (nothing): idle
local M = {}

-- Play a macOS system sound (non-blocking)
local function play_sound(name)
    vim.fn.jobstart({ "afplay", "/System/Library/Sounds/" .. name .. ".aiff" })
end

-- Check if any non-current tab has a given variable set
local function any_non_current_tab_has(var_name)
    local current_tab = vim.fn.tabpagenr()
    for t = 1, vim.fn.tabpagenr("$") do
        if t ~= current_tab and vim.fn.gettabvar(t, var_name) == 1 then
            return true
        end
    end
    return false
end

-- Cache the TTY for a terminal buffer
local function cache_tty(bufnr)
    local job_id = vim.b[bufnr].terminal_job_id
    if not job_id then return end

    local ok, pid = pcall(vim.fn.jobpid, job_id)
    if not ok or not pid or pid <= 0 then return end

    local result = vim.fn.system("ps -o tty= -p " .. pid)
    local tty = result:gsub("%s+", "")
    if tty ~= "" and tty ~= "??" then
        vim.b[bufnr].terminal_tty = tty
    end
end

-- Find the tab number that contains a given buffer
local function find_tab_for_buffer(target_bufnr)
    for tabnr = 1, vim.fn.tabpagenr("$") do
        for _, bufnr in ipairs(vim.fn.tabpagebuflist(tabnr)) do
            if bufnr == target_bufnr then
                return tabnr
            end
        end
    end
    -- Fallback: buffer may be temporarily swapped out of its window
    -- (TermRedrawFix in autocmds.lua) but still belongs to a tab
    local tabpage = vim.b[target_bufnr].hidden_in_tabpage
    if tabpage and vim.api.nvim_tabpage_is_valid(tabpage) then
        return vim.api.nvim_tabpage_get_number(tabpage)
    end
    -- Fallback: buffer may be hidden by flatten (replaced with a file/directory)
    for tabnr = 1, vim.fn.tabpagenr("$") do
        local flatten_buf = vim.fn.gettabvar(tabnr, "_flatten_term_buf")
        if type(flatten_buf) == "number" and flatten_buf == target_bufnr then
            return tabnr
        end
    end
    return nil
end

-- Find tab number by matching TTY to a terminal buffer
local function find_tab_by_tty(tty)
    if not tty or tty == "" or tty == "??" then return nil end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
            if not vim.b[buf].terminal_tty then
                cache_tty(buf)
            end
            if vim.b[buf].terminal_tty == tty then
                return find_tab_for_buffer(buf)
            end
        end
    end
    return nil
end

-- Set a tab variable on the terminal tab matching the given TTY
local function set_tab_var(tty, var_name, value)
    tty = tty and tty:gsub("%s+", "") or nil

    local tabnr = find_tab_by_tty(tty)
    if tabnr then
        vim.fn.settabvar(tabnr, var_name, value)
        vim.cmd("redrawtabline")
        return
    end

    -- Fallback: apply to all terminal tabs
    for t = 1, vim.fn.tabpagenr("$") do
        for _, bufnr in ipairs(vim.fn.tabpagebuflist(t)) do
            if vim.fn.getbufvar(bufnr, "&buftype") == "terminal" then
                vim.fn.settabvar(t, var_name, value)
                break
            end
        end
    end
    vim.cmd("redrawtabline")
end

-- Set a tab variable only on non-current tabs (for background tab indicators)
local function set_tab_var_non_current(tty, var_name)
    local current_tab = vim.fn.tabpagenr()
    tty = tty and tty:gsub("%s+", "") or nil

    local tabnr = find_tab_by_tty(tty)
    if tabnr then
        if tabnr ~= current_tab then
            vim.fn.settabvar(tabnr, var_name, 1)
        end
        vim.cmd("redrawtabline")
        return
    end

    -- Fallback: apply to all terminal tabs
    for t = 1, vim.fn.tabpagenr("$") do
        if t ~= current_tab then
            for _, bufnr in ipairs(vim.fn.tabpagebuflist(t)) do
                if vim.fn.getbufvar(bufnr, "&buftype") == "terminal" then
                    vim.fn.settabvar(t, var_name, 1)
                    break
                end
            end
        end
    end
    vim.cmd("redrawtabline")
end

-- Called by the Claude Code Stop hook
-- Claude finished: clear running/compacting, show waiting, play sound
function M.ring(tty)
    if permission_timer then
        vim.fn.timer_stop(permission_timer)
        permission_timer = nil
    end

    set_tab_var(tty, "claude_running", 0)
    set_tab_var(tty, "claude_compacting", 0)
    set_tab_var_non_current(tty, "claude_waiting")

    if any_non_current_tab_has("claude_waiting") then
        play_sound("Glass")
    end

    return "ok"
end

-- Called by the Claude Code PreToolUse hook
-- Claude is working: show running indicator, clear compacting/waiting.
-- Also starts a 2s timer: if the tool is still pending (needs permission),
-- the bell rings. Auto-approved tools complete before the timer fires.
function M.ring_waiting(tty)
    set_tab_var(tty, "claude_running", 1)
    set_tab_var(tty, "claude_compacting", 0)
    set_tab_var(tty, "claude_waiting", 0)

    if not permission_timer then
        permission_timer = vim.fn.timer_start(2000, function()
            vim.schedule(function()
                permission_timer = nil
                set_tab_var_non_current(tty, "claude_bell")
                if any_non_current_tab_has("claude_bell") then
                    play_sound("Glass")
                end
            end)
        end)
    end
    return "ok"
end

-- Called by the Claude Code PostToolUse hook
-- Tool completed: cancel permission timer, clear bell (Claude is working again)
function M.clear_waiting(tty)
    if permission_timer then
        vim.fn.timer_stop(permission_timer)
        permission_timer = nil
    end
    set_tab_var(tty, "claude_bell", 0)
    return "ok"
end

-- Called by the Claude Code PreCompact hook
-- Context is being compacted: show compacting indicator
function M.compact(tty)
    set_tab_var(tty, "claude_compacting", 1)
    set_tab_var(tty, "claude_running", 0)
    return "ok"
end

function M.setup()
    local group = vim.api.nvim_create_augroup("ClaudeBell", { clear = true })

    -- Clear bell when entering a tab (running stays - it clears itself on Stop)
    vim.api.nvim_create_autocmd("TabEnter", {
        group = group,
        callback = function()
            local tabnr = vim.fn.tabpagenr()
            local needs_redraw = false
            for _, var in ipairs({ "claude_bell", "claude_waiting", "claude_compacting" }) do
                if vim.fn.gettabvar(tabnr, var) == 1 then
                    vim.fn.settabvar(tabnr, var, 0)
                    needs_redraw = true
                end
            end
            if needs_redraw then
                vim.cmd("redrawtabline")
            end
            if permission_timer then
                vim.fn.timer_stop(permission_timer)
                permission_timer = nil
            end
        end,
    })

    -- Cache TTY for new terminal buffers
    vim.api.nvim_create_autocmd("TermOpen", {
        group = group,
        callback = function(args)
            vim.defer_fn(function()
                if vim.api.nvim_buf_is_valid(args.buf) then
                    cache_tty(args.buf)
                end
            end, 1000)
        end,
    })

    -- Cache TTYs for any terminal buffers that already exist
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "terminal" then
            cache_tty(buf)
        end
    end
end

M.setup()

return M
