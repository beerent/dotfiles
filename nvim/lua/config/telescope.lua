-- File path: /Users/thedevdad/.config/nvim/lua/config/telescope.lua
local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  return
end

-- [[ Configure Telescope ]]
-- See `:help telescope` and `:help telescope.setup()`
telescope.setup({
  defaults = {
    layout_strategy = "vertical",
    mappings = {
      i = {
        ["<C-u>"] = false,
        ["<C-d>"] = false,
      },
    },
  },
  pickers = {
    quickfix = {
      initial_mode = "normal", -- This will make it start in normal mode
      previewer = require("telescope.config").values.qflist_previewer({}),
      preview = {
        hide_on_startup = false
      },
      mappings = {
        n = {
          ["dd"] = function(prompt_bufnr)
            local action_state = require("telescope.actions.state")
            local picker = action_state.get_current_picker(prompt_bufnr)
            local selection = picker:get_selection()
            local qf_list = vim.fn.getqflist()

            -- Remove the selected item from the quickfix list
            table.remove(qf_list, selection.index)

            -- Set the updated quickfix list
            vim.fn.setqflist(qf_list)

            -- Close windows manually to avoid errors
            vim.api.nvim_win_close(picker.results_win, true)
            vim.api.nvim_win_close(picker.prompt_win, true)

            -- Open refreshed quickfix view with preview
            vim.defer_fn(function()
              require("telescope.builtin").quickfix({
                initial_mode = "normal", -- Also add it here for consistency
                previewer = require("telescope.config").values.qflist_previewer({}),
                preview = {
                  hide_on_startup = false
                }
              })
            end, 20)
          end,
        },
      },
    },
  },
})

-- Enable telescope fzf native, if installed
pcall(require("telescope").load_extension, "fzf")

-- Prevent quickfix from automatically opening after Ctrl-Q
vim.keymap.set('v', '<C-q>', function()
  -- Store the current view
  local view = vim.fn.winsaveview()

  -- Execute the normal Ctrl-Q behavior to populate quickfix
  vim.cmd('normal! gv"zy')
  vim.cmd('grep! -R ' .. vim.fn.shellescape(vim.fn.getreg('z')))

  -- Restore the view but don't open quickfix
  vim.fn.winrestview(view)
end, { desc = "Populate quickfix without opening it" })

-- LSP-related telescope keymaps
function _G.telescope_lsp_keymaps(client, bufnr)
  local nmap = function(keys, func, desc)
    if desc then
      desc = "LSP: " .. desc
    end

    vim.keymap.set("n", keys, func, { buffer = bufnr, desc = desc })
  end

  -- Telescope LSP keymaps
  nmap("gd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
  nmap("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
  nmap("gI", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
  nmap("<leader>D", require("telescope.builtin").lsp_type_definitions, "Type [D]efinition")
  nmap("<leader>ds", require("telescope.builtin").lsp_document_symbols, "[D]ocument [S]ymbols")
  nmap("<leader>ws", require("telescope.builtin").lsp_dynamic_workspace_symbols, "[W]orkspace [S]ymbols")

  nmap("fq", function()
    require("telescope.builtin").quickfix({
      initial_mode = "normal",
      previewer = require("telescope.config").values.qflist_previewer({}),
      preview = {
        hide_on_startup = false
      }
    })
  end, "Show quickfix list in Telescope")

  nmap("fa", function()
    vim.cmd("caddexpr expand('%') . ':' . line('.') . ':' . getline('.')")
  end, "Add line to quickfix")
end
