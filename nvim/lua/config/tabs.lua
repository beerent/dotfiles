-- Tab management with Telescope integration
local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local entry_display = require("telescope.pickers.entry_display")

-- Custom tabline function
function M.tabline()
    local s = ""
    local num_tabs = vim.fn.tabpagenr("$")
    local current_tab = vim.fn.tabpagenr()

    for tabnr = 1, num_tabs do
        -- Highlight for current vs other tabs
        if tabnr == current_tab then
            s = s .. "%#TabLineSel#"
        else
            s = s .. "%#TabLine#"
        end

        -- Tab number for click handling
        s = s .. "%" .. tabnr .. "T"

        -- Get tab name
        local name = vim.fn.gettabvar(tabnr, "tab_name")
        if name == "" then
            -- Fall back to buffer name
            local winnr = vim.fn.tabpagewinnr(tabnr)
            local buflist = vim.fn.tabpagebuflist(tabnr)
            local bufnr = buflist[winnr]
            local bufname = vim.fn.bufname(bufnr)
            local buftype = vim.fn.getbufvar(bufnr, "&buftype")

            if buftype == "terminal" then
                name = "[term]"
            elseif bufname == "" then
                name = "[No Name]"
            else
                name = vim.fn.fnamemodify(bufname, ":t")
            end
        end

        s = s .. " " .. tabnr .. ":" .. name .. " "
    end

    -- Fill the rest and reset tab page nr
    s = s .. "%#TabLineFill#%T"

    return s
end

-- Get custom tab name if set
local function get_tab_custom_name(tabnr)
    local name = vim.fn.gettabvar(tabnr, "tab_name")
    if name ~= "" then
        return name
    end
    return nil
end

-- Get the main buffer name for a tab
local function get_tab_display_name(tabnr)
    -- Check for custom name first
    local custom_name = get_tab_custom_name(tabnr)
    if custom_name then
        return custom_name
    end

    local winnr = vim.fn.tabpagewinnr(tabnr)
    local buflist = vim.fn.tabpagebuflist(tabnr)
    local bufnr = buflist[winnr]
    local name = vim.api.nvim_buf_get_name(bufnr)
    local buftype = vim.bo[bufnr].buftype

    if buftype == "terminal" then
        local term_title = vim.b[bufnr].term_title or "terminal"
        return "[term] " .. vim.fn.fnamemodify(term_title, ":t")
    elseif name == "" then
        return "[No Name]"
    else
        return vim.fn.fnamemodify(name, ":t")
    end
end

-- Build entries for all tabs
local function get_tab_entries()
    local tabs = {}
    local current_tab = vim.fn.tabpagenr()
    local num_tabs = vim.fn.tabpagenr("$")

    for tabnr = 1, num_tabs do
        local display_name = get_tab_display_name(tabnr)
        local is_current = tabnr == current_tab
        local buffer_count = #vim.fn.tabpagebuflist(tabnr)

        table.insert(tabs, {
            tabnr = tabnr,
            display_name = display_name,
            is_current = is_current,
            buffer_count = buffer_count,
        })
    end

    return tabs
end

-- Create the entry display format
local function make_display(entry)
    local displayer = entry_display.create({
        separator = " ",
        items = {
            { width = 3 },
            { width = 2 },
            { width = 30 },
            { remaining = true },
        },
    })

    local current_indicator = entry.is_current and "*" or " "
    local other_buffers = ""

    if entry.buffer_count > 1 then
        other_buffers = "(+" .. (entry.buffer_count - 1) .. " buffers)"
    end

    return displayer({
        { tostring(entry.tabnr), "TelescopeResultsNumber" },
        { current_indicator, "TelescopeResultsIdentifier" },
        { entry.display_name, entry.is_current and "TelescopeResultsIdentifier" or "TelescopeResultsNormal" },
        { other_buffers, "TelescopeResultsComment" },
    })
end

-- Tab picker function
function M.tab_picker(opts)
    opts = opts or {}

    local tabs = get_tab_entries()

    if #tabs == 0 then
        vim.notify("No tabs open", vim.log.levels.INFO)
        return
    end

    pickers.new(opts, {
        prompt_title = "Tabs",
        finder = finders.new_table({
            results = tabs,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = make_display,
                    ordinal = entry.tabnr .. " " .. entry.display_name,
                    tabnr = entry.tabnr,
                    is_current = entry.is_current,
                    display_name = entry.display_name,
                    buffer_count = entry.buffer_count,
                }
            end,
        }),
        sorter = conf.generic_sorter(opts),
        attach_mappings = function(prompt_bufnr, map)
            -- Select tab on Enter
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if selection then
                    vim.cmd("tabnext " .. selection.tabnr)
                end
            end)

            -- Helper to close a tab safely
            local function close_tab_from_picker(selection)
                if not selection then return end

                local num_tabs = vim.fn.tabpagenr("$")
                if num_tabs == 1 then
                    vim.notify("Cannot close the last tab", vim.log.levels.WARN)
                    return
                end

                local tab_to_close = selection.tabnr

                -- Close picker first, then close tab and reopen picker
                actions.close(prompt_bufnr)
                vim.schedule(function()
                    vim.cmd("tabclose " .. tab_to_close)
                    -- Only reopen if more than 1 tab remains
                    if vim.fn.tabpagenr("$") > 0 then
                        M.tab_picker(opts)
                    end
                end)
            end

            -- Close tab with dd in normal mode
            map("n", "dd", function()
                close_tab_from_picker(action_state.get_selected_entry())
            end)

            -- Close tab with <C-d> in insert mode
            map("i", "<C-d>", function()
                close_tab_from_picker(action_state.get_selected_entry())
            end)

            return true
        end,
        initial_mode = "normal",
    }):find()
end

-- Create a new tab
function M.new_tab()
    vim.cmd("tabnew")
    local tabnr = vim.fn.tabpagenr()
    vim.notify("Created tab " .. tabnr, vim.log.levels.INFO)
end

-- Close current tab with safety checks
function M.close_tab()
    local num_tabs = vim.fn.tabpagenr("$")
    local current_tab = vim.fn.tabpagenr()

    if num_tabs == 1 then
        -- Last tab - use original quit behavior
        if vim.fn.exists(":Neotree") == 2 then
            vim.cmd("Neotree close")
        end
        vim.cmd("qa")
        return
    end

    -- Check for unsaved buffers in this tab
    local buflist = vim.fn.tabpagebuflist(current_tab)
    local has_unsaved = false

    for _, bufnr in ipairs(buflist) do
        if vim.bo[bufnr].modified then
            has_unsaved = true
            break
        end
    end

    if has_unsaved then
        local choice = vim.fn.confirm("Tab has unsaved changes. Close anyway?", "&Yes\n&No", 2)
        if choice ~= 1 then
            return
        end
    end

    -- Check for running terminal processes
    for _, bufnr in ipairs(buflist) do
        if vim.bo[bufnr].buftype == "terminal" then
            local job_id = vim.b[bufnr].terminal_job_id
            if job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1 then
                local choice = vim.fn.confirm("Tab has running terminal. Close anyway?", "&Yes\n&No", 2)
                if choice ~= 1 then
                    return
                end
                break
            end
        end
    end

    vim.cmd("tabclose")
    vim.notify("Closed tab " .. current_tab, vim.log.levels.INFO)
end

-- Rename the current tab with centered floating window
function M.rename_tab()
    local current_tabnr = vim.fn.tabpagenr()
    local current_name = vim.fn.gettabvar(current_tabnr, "tab_name") or ""

    -- Create centered floating window
    local width = 40
    local height = 1
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = width,
        height = height,
        col = math.floor((vim.o.columns - width) / 2),
        row = math.floor((vim.o.lines - height) / 2) - 1,
        style = "minimal",
        border = "rounded",
        title = " Rename Tab ",
        title_pos = "center",
    })

    -- Set initial content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { current_name })
    vim.cmd("startinsert!")
    vim.api.nvim_win_set_cursor(win, { 1, #current_name })

    -- Confirm with Enter
    vim.keymap.set("i", "<CR>", function()
        local input = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
        vim.api.nvim_win_close(win, true)
        vim.cmd("stopinsert")

        vim.fn.settabvar(current_tabnr, "tab_name", input)
        if input == "" then
            vim.notify("Tab name cleared", vim.log.levels.INFO)
        else
            vim.notify("Tab renamed to: " .. input, vim.log.levels.INFO)
        end
    end, { buffer = buf })

    -- Cancel with Escape
    vim.keymap.set({ "i", "n" }, "<Esc>", function()
        vim.api.nvim_win_close(win, true)
        vim.cmd("stopinsert")
    end, { buffer = buf })
end

-- Setup the custom tabline
function M.setup()
    vim.o.tabline = "%!v:lua.require('config.tabs').tabline()"
    vim.o.showtabline = 2 -- Always show tabline

    -- Terminal keymaps
    vim.api.nvim_create_autocmd("TermOpen", {
        callback = function()
            -- On local Mac: Shift+Escape exits terminal mode (plain Escape passes to nested nvim/claude)
            -- On remote server: regular Escape exits terminal mode (no nesting issue)
            local hostname = vim.fn.hostname()
            local is_remote = hostname == "vps147-cus20"
            if is_remote then
                vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { buffer = true, desc = "Exit terminal mode" })
            else
                vim.keymap.set("t", "<C-Esc>", "<C-\\><C-n>", { buffer = true, desc = "Exit terminal mode" })
            end
            -- q in normal mode closes terminal
            vim.keymap.set("n", "q", function()
                vim.cmd("bd!")
            end, { buffer = true, desc = "Close terminal" })
        end,
    })
end

-- Auto-setup when module loads
M.setup()

return M
