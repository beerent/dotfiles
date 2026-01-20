-- Tab session persistence
-- Saves and restores tab state (type, directory, name) across nvim restarts
local M = {}

-- Session storage directory
local session_dir = vim.fn.stdpath("data") .. "/tab-sessions"

-- Get a safe filename for the current project
local function get_project_name()
    local cwd = vim.fn.getcwd()
    -- Use the directory name, replacing path separators with dashes
    local name = cwd:gsub("^" .. vim.env.HOME, "~")
    name = name:gsub("/", "-"):gsub("^-", "")
    return name
end

-- Get the session file path for current project
local function get_session_path()
    return session_dir .. "/" .. get_project_name() .. ".json"
end

-- Determine tab type by checking if primary buffer is a terminal
local function get_tab_type(tabnr)
    -- First check for explicit tab_type variable
    local explicit_type = vim.fn.gettabvar(tabnr, "tab_type")
    if explicit_type ~= "" then
        return explicit_type
    end

    -- Fall back to detecting from buffer type
    local winnr = vim.fn.tabpagewinnr(tabnr)
    local buflist = vim.fn.tabpagebuflist(tabnr)
    local bufnr = buflist[winnr]
    local buftype = vim.fn.getbufvar(bufnr, "&buftype")

    return buftype == "terminal" and "terminal" or "editor"
end

-- Get the state of all tabs
function M.get_tab_state()
    local tabs = {}
    local num_tabs = vim.fn.tabpagenr("$")

    for tabnr = 1, num_tabs do
        local tab_type = get_tab_type(tabnr)
        local directory = vim.fn.getcwd(-1, tabnr) -- Tab-local cwd
        local name = vim.fn.gettabvar(tabnr, "tab_name")
        if name == "" then
            name = nil
        end

        table.insert(tabs, {
            type = tab_type,
            directory = directory,
            name = name,
        })
    end

    return {
        tabs = tabs,
        current_tab = vim.fn.tabpagenr(),
    }
end

-- Encode table to JSON
local function encode_json(data)
    return vim.fn.json_encode(data)
end

-- Decode JSON to table
local function decode_json(str)
    local ok, result = pcall(vim.fn.json_decode, str)
    if ok then
        return result
    end
    return nil
end

-- Save session to file (atomic write)
function M.save_session()
    -- Don't save if we're in a special buffer or only have empty tabs
    local state = M.get_tab_state()
    if #state.tabs == 0 then
        return
    end

    -- Ensure directory exists
    vim.fn.mkdir(session_dir, "p")

    local session_path = get_session_path()
    local tmp_path = session_path .. ".tmp"

    local json = encode_json(state)
    if not json then
        vim.notify("Failed to encode session", vim.log.levels.ERROR)
        return
    end

    -- Write to temp file first, then rename (atomic)
    local file = io.open(tmp_path, "w")
    if not file then
        vim.notify("Failed to write session file", vim.log.levels.ERROR)
        return
    end

    file:write(json)
    file:close()

    os.rename(tmp_path, session_path)
end

-- Load session from file
local function load_session_file()
    local session_path = get_session_path()
    local file = io.open(session_path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()

    return decode_json(content)
end

-- Restore session
function M.restore_session()
    -- Skip if nvim was opened with file arguments
    if vim.fn.argc() > 0 then
        return false
    end

    -- Skip if current buffer has content (file opened via stdin or other means)
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= "" then
        return false
    end

    local state = load_session_file()
    if not state or not state.tabs or #state.tabs == 0 then
        return false
    end

    -- Track the initial empty tab/buffer to close later
    local initial_buf = vim.api.nvim_get_current_buf()

    -- Create tabs from saved state
    for i, tab in ipairs(state.tabs) do
        if i == 1 then
            -- Use the current tab for the first one
        else
            vim.cmd("tabnew")
        end

        local tabnr = vim.fn.tabpagenr()

        -- Set tab-local directory
        if tab.directory and tab.directory ~= "" then
            vim.cmd("tcd " .. vim.fn.fnameescape(tab.directory))
        end

        -- Set tab type
        vim.fn.settabvar(tabnr, "tab_type", tab.type or "editor")

        -- Set tab name
        if tab.name then
            vim.fn.settabvar(tabnr, "tab_name", tab.name)
        end

        -- Open terminal if needed
        if tab.type == "terminal" then
            vim.cmd("terminal")
            vim.cmd("startinsert")
        end
    end

    -- Go to the saved current tab
    if state.current_tab and state.current_tab >= 1 and state.current_tab <= #state.tabs then
        vim.cmd("tabnext " .. state.current_tab)
    end

    -- Clean up the initial empty buffer if it still exists and is empty
    if vim.api.nvim_buf_is_valid(initial_buf) then
        local lines = vim.api.nvim_buf_get_lines(initial_buf, 0, -1, false)
        local is_empty = #lines == 0 or (#lines == 1 and lines[1] == "")
        local buf_name = vim.api.nvim_buf_get_name(initial_buf)
        if is_empty and buf_name == "" then
            -- Only delete if not displayed in any window
            local wins = vim.fn.win_findbuf(initial_buf)
            if #wins == 0 then
                vim.api.nvim_buf_delete(initial_buf, { force = true })
            end
        end
    end

    vim.notify("Restored " .. #state.tabs .. " tab(s)", vim.log.levels.INFO)
    return true
end

-- Clear session file for current project
function M.clear_session()
    local session_path = get_session_path()
    os.remove(session_path)
    vim.notify("Session cleared", vim.log.levels.INFO)
end

-- Setup autocmds and commands
function M.setup()
    local group = vim.api.nvim_create_augroup("TabSession", { clear = true })

    -- Save session on exit
    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = function()
            M.save_session()
        end,
    })

    -- Restore session on startup (with delay to let plugins load)
    vim.api.nvim_create_autocmd("VimEnter", {
        group = group,
        callback = function()
            vim.schedule(function()
                M.restore_session()
            end)
        end,
    })

    -- Save session on tab changes
    vim.api.nvim_create_autocmd({ "TabNew", "TabClosed" }, {
        group = group,
        callback = function()
            -- Delay slightly to ensure tab state is settled
            vim.defer_fn(function()
                M.save_session()
            end, 100)
        end,
    })

    -- User commands
    vim.api.nvim_create_user_command("TabSessionSave", function()
        M.save_session()
        vim.notify("Session saved", vim.log.levels.INFO)
    end, { desc = "Save tab session" })

    vim.api.nvim_create_user_command("TabSessionRestore", function()
        if not M.restore_session() then
            vim.notify("No session to restore", vim.log.levels.WARN)
        end
    end, { desc = "Restore tab session" })

    vim.api.nvim_create_user_command("TabSessionClear", function()
        M.clear_session()
    end, { desc = "Clear tab session" })
end

return M
