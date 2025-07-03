-- File path: /Users/thedevdad/.G
local has_telescope, telescope = pcall(require, "telescope")
if not has_telescope then
  return
end

-- [[ Configure Telescope ]]
-- See `:help telescope` and `:help telescope.setup()`
telescope.setup({
  defaults = {
    file_sorter = require("telescope.sorters").get_fzy_sorter,
    generic_sorter = require("telescope.sorters").get_fzy_sorter,
    vimgrep_arguments = {
      "rg",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case",
      "--hidden",
      "--glob=!.git/*",
      "--glob=!node_modules/*",
      "--glob=!public/*",
      "--glob=!.yarn/*",
      "--glob=!.next/*",
      "--glob=!dist/*",
      "--glob=!build/*",
      "--glob=!.cache/*",
      "--glob=!vendor/*",
      "--glob=!*.DS_Store",
      "--glob=!*.lock",
      "--max-filesize=1M", -- Skip files >1MB
    },

    path_display = { "truncate" },
    dynamic_preview_title = true,
    cache_picker = {
      num_pickers = 10,
    },
    preview = {
      check_mime_type = false,
      previewer = require("telescope.previewers").new_termopen_previewer({
        get_command = function(entry)
          return { "bat", "--style=plain", "--color=always", entry.path }
        end,
      }),
    },
    sorting_strategy = "ascending",
    layout_strategy = "vertical",

    file_ignore_patterns = {
      "%.git/.*",
      "node_modules/.*",
      "public/.*",
      "%.yarn/.*",
      "%.next/.*",
      "dist/.*",
      "build/.*",
      "%.DS_Store",
      "%.cache/.*",
      "vendor/.*",
      "%.lock",
      "%.log",
      "%.bak",
      "%.tmp",
      "%.swp",
      "%.venv/.*",
      "%.npm/.*",
      "%.docker/.*",
      "%.png",
      "%.jpg",
      "%.jpeg",
      "%.gif",
      "%.svg",
      "%.pdf",
      "%.zip",
      "%.tar%.gz",
    },

    mappings = {
      i = {
        ["<C-u>"] = false,
        ["<C-d>"] = false,
      },
    },
  },
  pickers = {
    live_grep = {
      -- No additional_args needed; exclusions are in vimgrep_arguments
    },
    find_files = {
      find_command = {
        "rg",
        "--files",
        "--hidden",
        "--glob", "!.git/*",
        "--glob", "!node_modules/*",
        "--glob", "!public/*",
        "--glob", "!.yarn/*",
        "--glob", "!.next/*",
        "--glob", "!dist/*",
        "--glob", "!build/*",
        "--glob", "!.cache/*",
        "--glob", "!vendor/*",
        "--glob", "!*.DS_Store",
        "--glob", "!*.lock",
      },
    },
    quickfix = {
      initial_mode = "normal",
      previewer = require("telescope.config").values.qflist_previewer({}),
      preview = {
        hide_on_startup = false,
      },
    },
  },
  extensions = {
    live_grep_args = {
      auto_quoting = true, -- Enable auto-quoting for >src syntax
    },
  },
})

-- Enable telescope extensions
pcall(require("telescope").load_extension, "fzf")
pcall(require("telescope").load_extension, "live_grep_args")
pcall(require("telescope").load_extension, "ui-select")

-- Debounced live_grep for performance
local debounce = require("plenary.async").debounce
local function debounced_live_grep()
  local search = ""
  local debounced_search = debounce(function()
    require("telescope.builtin").live_grep({
      default_text = search,
      on_input = function(prompt)
        search = prompt
      end,
    })
  end, 200) -- 200ms debounce
  debounced_search()
end

-- Keymaps
vim.keymap.set("n", "<leader>fg", debounced_live_grep, { desc = "Debounced live grep" })
vim.keymap.set("n", "<leader>fs",
  ":lua require('telescope').extensions.live_grep_args.live_grep_args({ default_text = '>src ' })<CR>",
  { desc = "Live grep in src" })

-- Prevent quickfix from automatically opening after Ctrl-Q
vim.keymap.set("v", "<C-q>", function()
  local view = vim.fn.winsaveview()
  vim.cmd('normal! gv"zy')
  vim.cmd("grep! -R " .. vim.fn.shellescape(vim.fn.getreg("z")))
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
        hide_on_startup = false,
      },
    })
  end, "Show quickfix list in Telescope")
  nmap("fa", function()
    vim.cmd("caddexpr expand('%') .. ':' .. line('.') .. ':' .. getline('.')")
  end, "Add line to quickfix")
end
