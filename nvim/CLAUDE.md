# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a personal Neovim configuration using Lua, built on the Lazy.nvim plugin manager. The configuration is based on the Kickstart.nvim template but extensively customized with additional plugins and personal keybindings.

## Configuration Structure

The configuration follows a modular Lua-based structure:

- `init.lua` - Entry point that loads user modules
- `lua/user/` - Core user configuration modules
  - `init.lua` - Loads all user modules in order
  - `options.lua` - Neovim options and settings
  - `lazy.lua` - Plugin manager setup and plugin definitions
  - `lsp.lua` - LSP configuration with Mason, completion, and server setup
  - `keymaps.lua` - All custom keybindings and shortcuts
  - `autocmds.lua` - Auto-commands and event handlers
- `lua/plugins/` - Individual plugin configurations
- `lua/config/` - Additional configuration modules for specific features
- `lazy-lock.json` - Plugin version lockfile (similar to package-lock.json)

## Key Plugins and Tools

### Plugin Manager
- **Lazy.nvim** - Modern plugin manager with lazy loading

### Core Development Tools
- **LSP**: Mason + nvim-lspconfig for language server management
- **Completion**: nvim-cmp with LuaSnip for autocompletion
- **Formatting**: conform.nvim for code formatting
- **Git**: vim-fugitive, gitsigns.nvim, and lazygit.nvim integration
- **File Management**: neo-tree.nvim (positioned on right side)
- **Search**: telescope.nvim for fuzzy finding
- **AI Assistance**: copilot.lua for code completion

### Development Workflow
- **Harpoon** for quick file navigation
- **Database UI** via vim-dadbod-ui
- **Debug Adapter Protocol** support
- **Treesitter** for syntax highlighting

## Custom Keybindings

The configuration uses Space as the leader key with extensive custom mappings:

### File Operations
- `ff` - Find files (Telescope)
- `fd` - Live grep search
- `fs` - Switch to last buffer
- `fo` - Close all windows except current

### LSP and Code
- `gr` - Go to references
- `gd` - Go to definitions
- `fr` - Function rename
- `ca` - Code actions
- `<leader>p` - Format code with conform.nvim
- `<leader>o` - Restart LSP

### Navigation
- All navigation commands center the cursor (`zz`)
- `fe`/`fE` - Next/previous error diagnostic
- `]d`/`[d` - Next/previous diagnostic

### Tools
- `<leader>lg` - Open LazyGit
- `<leader>db` - Toggle database UI
- `<leader>h` - Harpoon quick menu
- `<leader>m` - Mark file in Harpoon
- `<leader>n`/`<leader>nn` - Neo-tree focus/close

### Configuration Management
- `<leader>ce` - Edit init.lua
- `<leader>cr` - Reload configuration
- `<leader>rf` - Reload configuration with notification

## Development Commands

Since this is a Neovim configuration, development involves:

1. **Edit configuration files** - Modify Lua files in the appropriate directories
2. **Reload configuration** - Use `<leader>rf` or restart Neovim
3. **Plugin management** - Lazy.nvim handles installation/updates automatically
4. **LSP management** - Mason handles language server installation

## Architecture Notes

- The configuration is designed to be modular and easily extensible
- Plugin configurations are separated into individual files where complex
- LSP setup focuses on Lua development but can be extended for other languages
- Custom keybindings prioritize efficiency with single-key combinations for common operations
- The setup integrates Copilot for AI-powered code completion
- Neo-tree is configured to not hijack netrw and positioned on the right side