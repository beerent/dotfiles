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
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local arg = vim.fn.argv(0)
    if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
      vim.cmd("bdelete")
      vim.cmd("enew")
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
      -- Ensure copilot is enabled for this buffer
      if vim.b.copilot_enabled == false then
        vim.b.copilot_enabled = nil
      end
    end
  end,
})

