-- place any commands you want to run after startup here

-- iTerm2 Tab Color based on filename
-- Uses iTerm2 proprietary escape sequences to change tab color dynamically

local function set_iterm_tab_color(r, g, b)
  local escape = string.format(
    "\027]6;1;bg;red;brightness;%d\a\027]6;1;bg;green;brightness;%d\a\027]6;1;bg;blue;brightness;%d\a",
    r, g, b
  )
  io.write(escape)
  io.flush()
end

local function reset_iterm_tab_color()
  io.write("\027]6;1;bg;*;default\a")
  io.flush()
end

local function is_env_file(filename)
  return filename:match("^%.env$")
    or filename:match("^%.env%.")
    or filename:match("%.env$")
end

local tab_color_group = vim.api.nvim_create_augroup("ITermTabColor", { clear = true })

-- Set red for .env files
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
  group = tab_color_group,
  pattern = { ".env", ".env.*", "*.env" },
  callback = function()
    set_iterm_tab_color(200, 50, 50)
  end,
})

-- Reset to default for non-.env files
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
  group = tab_color_group,
  pattern = "*",
  callback = function()
    local filename = vim.fn.expand("%:t")
    if filename ~= "" and not is_env_file(filename) then
      reset_iterm_tab_color()
    end
  end,
})

-- Reset color when leaving Neovim
vim.api.nvim_create_autocmd("VimLeave", {
  group = tab_color_group,
  callback = reset_iterm_tab_color,
})

-- Open blank buffer when opening a directory (instead of netrw)
-- Open terminal when launched with no arguments
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local arg = vim.fn.argv(0)
    if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
      vim.cmd("cd " .. vim.fn.fnameescape(vim.fn.fnamemodify(arg, ":p")))
      vim.cmd("bdelete")
      vim.cmd("enew")
    elseif vim.fn.argc() == 0 then
      vim.cmd("terminal")
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.keymap.set("t", "<C-Esc>", "<C-\\><C-n>", { buffer = true, desc = "Exit terminal mode" })
      vim.keymap.set("n", "q", function() vim.cmd("bd!") end, { buffer = true, desc = "Close terminal" })
      vim.cmd("startinsert")
    end
  end,
})

-- Terminal keymaps for all terminal buffers
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    local hostname = vim.fn.hostname()
    if hostname == "vps147-cus20" then
      vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { buffer = true, desc = "Exit terminal mode" })
    else
      vim.keymap.set("t", "<C-Esc>", "<C-\\><C-n>", { buffer = true, desc = "Exit terminal mode" })
    end
    vim.keymap.set("n", "q", function() vim.cmd("bd!") end, { buffer = true, desc = "Close terminal" })
  end,
})

-- Auto-scroll to bottom when entering a terminal window
vim.api.nvim_create_autocmd("WinEnter", {
  callback = function()
    if vim.bo.buftype == "terminal" then
      local line_count = vim.api.nvim_buf_line_count(0)
      vim.api.nvim_win_set_cursor(0, { line_count, 0 })
    end
  end,
})

-- Fix large paste in terminal mode by sending clipboard directly to terminal channel
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    vim.keymap.set("t", "<D-v>", function()
      local clipboard = vim.fn.getreg("+")
      local channel = vim.bo.channel
      if channel and clipboard then
        vim.fn.chansend(channel, clipboard)
      end
    end, { buffer = true, desc = "Paste clipboard directly to terminal" })
  end,
})

-- Prevent terminal output in background tabs from disrupting visual mode.
-- When leaving a terminal tab, temporarily swap terminal buffers out of their
-- windows so output doesn't trigger screen redraws. Restore on re-entry.
local swapped_terminals = {}
local term_redraw_group = vim.api.nvim_create_augroup("TermRedrawFix", { clear = true })

vim.api.nvim_create_autocmd("TabLeave", {
    group = term_redraw_group,
    callback = function()
        local tabpage = vim.api.nvim_get_current_tabpage()
        local saved = {}
        for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
            local bufnr = vim.api.nvim_win_get_buf(winid)
            if vim.bo[bufnr].buftype == "terminal" then
                local scratch = vim.api.nvim_create_buf(false, true)
                vim.bo[scratch].bufhidden = "wipe"
                table.insert(saved, { win = winid, termbuf = bufnr, scratch = scratch })
                vim.b[bufnr].hidden_in_tabpage = tabpage
                vim.api.nvim_win_set_buf(winid, scratch)
            end
        end
        if #saved > 0 then
            swapped_terminals[tabpage] = saved
        end
    end,
})

vim.api.nvim_create_autocmd("TabEnter", {
    group = term_redraw_group,
    callback = function()
        local tabpage = vim.api.nvim_get_current_tabpage()
        local saved = swapped_terminals[tabpage]
        if saved then
            for _, entry in ipairs(saved) do
                if vim.api.nvim_win_is_valid(entry.win) and vim.api.nvim_buf_is_valid(entry.termbuf) then
                    vim.api.nvim_win_set_buf(entry.win, entry.termbuf)
                    vim.b[entry.termbuf].hidden_in_tabpage = nil
                end
                if vim.api.nvim_buf_is_valid(entry.scratch) then
                    vim.api.nvim_buf_delete(entry.scratch, { force = true })
                end
            end
            swapped_terminals[tabpage] = nil
        end
    end,
})

-- Prevent Copilot from breaking when terminal buffers are opened
-- Explicitly detach Copilot from terminal buffers
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    vim.b.copilot_enabled = false
  end,
})

-- Re-enable Copilot when leaving terminal and entering a normal buffer
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = function()
    local buftype = vim.bo.buftype
    local filetype = vim.bo.filetype
    -- Only for normal file buffers (not terminal, quickfix, etc.)
    if buftype == "" and filetype ~= "" then
      vim.b.copilot_enabled = nil
      -- Re-attach Copilot LSP client if it got detached (e.g., after opening a file from a terminal tab)
      vim.schedule(function()
        local bufnr = vim.api.nvim_get_current_buf()
        local attached = vim.lsp.get_clients({ bufnr = bufnr, name = "copilot" })
        if #attached == 0 then
          local copilot_clients = vim.lsp.get_clients({ name = "copilot" })
          if #copilot_clients > 0 then
            vim.lsp.buf_attach_client(bufnr, copilot_clients[1].id)
          end
        end
      end)
    end
  end,
})

