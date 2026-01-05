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
      n = {
        ["<C-a>"] = function(prompt_bufnr)
          local action_state = require("telescope.actions.state")
          local picker = action_state.get_current_picker(prompt_bufnr)
          local manager = picker.manager
          
          local qf_list = {}
          for entry in manager:iter() do
            if entry.filename or entry.bufnr then
              table.insert(qf_list, {
                filename = entry.filename or vim.api.nvim_buf_get_name(entry.bufnr),
                lnum = entry.lnum or 1,
                col = entry.col or 1,
                text = entry.text or entry.display or "",
              })
            end
          end
          
          vim.fn.setqflist(qf_list)
          require("telescope.actions").close(prompt_bufnr)
          
          -- Display popup notification
          require("notify")("Added " .. #qf_list .. " items to quickfix", "info", {
            title = "Telescope → Quickfix",
            timeout = 3000,
            stages = "fade_in_slide_out",
          })
        end,
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
      mappings = {
        n = {
          ["dd"] = function(prompt_bufnr)
            local action_state = require("telescope.actions.state")
            local selection = action_state.get_selected_entry()
            local picker = action_state.get_current_picker(prompt_bufnr)

            if selection then
              local qflist = vim.fn.getqflist()
              table.remove(qflist, selection.index)
              vim.fn.setqflist(qflist)

              -- Refresh the picker
              require("telescope.actions").close(prompt_bufnr)
              require("telescope.builtin").quickfix({
                initial_mode = "normal",
                previewer = require("telescope.config").values.qflist_previewer({}),
              })

              require("notify")("Removed item from quickfix", "info", {
                title = "Quickfix",
                timeout = 2000,
              })
            end
          end,
        },
      },
    },
    marks = {
      initial_mode = "normal",
      attach_mappings = function(prompt_bufnr, map)
        local action_state = require("telescope.actions.state")
        local actions = require("telescope.actions")

        map("n", "dd", function()
          local selection = action_state.get_selected_entry()
          if selection then
            local mark = selection.value:match("^(%S+)")

            -- Only allow deletion of user-defined marks (a-z, A-Z)
            if mark:match("^[a-zA-Z]$") then
              actions.close(prompt_bufnr)

              -- For lowercase marks (buffer-local), we need to be in the correct buffer
              if mark:match("^[a-z]$") and selection.filename then
                -- Open the file and delete the mark there
                vim.cmd("edit " .. vim.fn.fnameescape(selection.filename))
              end

              vim.cmd("delmarks " .. mark)

              -- Reopen marks picker
              require("telescope.builtin").marks({ initial_mode = "normal" })
              require("notify")("Deleted mark '" .. mark .. "'", "info", {
                title = "Marks",
                timeout = 2000,
              })
            else
              require("notify")("Cannot delete automatic mark '" .. mark .. "'", "warn", {
                title = "Marks",
                timeout = 2000,
              })
            end
          end
        end)

        return true
      end,
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
end
