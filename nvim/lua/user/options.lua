vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set tabs to 2 spaces
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.expandtab = true

-- Enable auto indenting and set it to spaces
vim.opt.smartindent = true
vim.opt.shiftwidth = 2
vim.opt.breakindent = true

vim.g.copilot_no_tab_map = true

-- [[ Setting options ]]
-- See `:help vim.o`
-- NOTE: You can change these options as you wish!

-- Set highlight on search
vim.o.hlsearch = true

-- Make line numbers default
vim.wo.number = true

-- Enable mouse mode
vim.o.mouse = "a"

-- Sync clipboard between OS and Neovim.
--  Remove this option if you want your OS clipboard to remain independent.
--  See `:help 'clipboard'`
vim.o.clipboard = "unnamedplus"

-- Check if the OS is macOS
local is_mac = vim.fn.has("mac") == 1

-- Define the clipboard commands based on the OS
local clipboard_copy_cmd = is_mac and "pbcopy" or "win32yank.exe -i --crlf"
local clipboard_paste_cmd = is_mac and "pbpaste" or "win32yank.exe -o --lf"

-- Set the clipboard config
vim.g.clipboard = {
  name = is_mac and "pbcopy" or "win32yank-wsl",
  copy = {
    ["+"] = clipboard_copy_cmd,
    ["*"] = clipboard_copy_cmd,
  },
  paste = {
    ["+"] = clipboard_paste_cmd,
    ["*"] = clipboard_paste_cmd,
  },
  cache_enabled = 0,
}

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.wo.signcolumn = "yes"

-- Decrease update time
vim.o.updatetime = 250
vim.o.timeoutlen = 300

-- Set completeopt to have a better completion experience
vim.o.completeopt = "menuone,noselect"

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

-- custom vim settings
vim.o.relativenumber = true
