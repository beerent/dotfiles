-- [[ Basic Keymaps ]]
--
vim.api.nvim_set_keymap("i", "<C-J>", 'copilot#Accept("<CR>")', { silent = true, expr = true })

-- Keymaps for better default experience
-- See `:help vim.keymap.set()`
vim.keymap.set({ "n", "v" }, "<Space>", "<Nop>", { silent = true })

-- Remap for dealing with word wrap
vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })
vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })

-- MY CUSTOM KEYMAPPINGS
--
-- Keybinding to open init.lua
vim.api.nvim_set_keymap("n", "<Leader>ce", ":edit ~/.config/nvim/init.lua<CR>", { noremap = true, silent = true })

-- Keybinding to reload Lua configuration
vim.api.nvim_set_keymap("n", "<Leader>cr", ":luafile ~/.config/nvim/init.lua<CR>", { noremap = true, silent = true })

vim.keymap.set("n", "<leader>lg", ":LazyGit<return>")
vim.keymap.set("n", "<leader>db", ":DBUIToggle<return>")
vim.keymap.set("n", "ff", function() require("telescope.builtin").find_files() end)
vim.keymap.set("n", "fd", function() require("telescope.builtin").live_grep() end)
vim.keymap.set("n", "gr", function() require("telescope.builtin").lsp_references() end)
vim.keymap.set("n", "gd", function() require("telescope.builtin").lsp_definitions() end)
vim.keymap.set("n", "fr", vim.lsp.buf.rename, { desc = "[F]unction [R]ename" })
vim.keymap.set("n", "ca", vim.lsp.buf.code_action, { desc = "[C]ode [A]ction" })

vim.keymap.set("n", "fq", function()
    if vim.fn.exists(":Neotree") == 2 then
        vim.cmd("Neotree close")
    end
    vim.cmd("qa")
end, { desc = "Close NeoTree and Quit" })

vim.keymap.set("n", "fs", "<C-^>")

-- open quickfix list
vim.keymap.set("n", "<leader>q", function()
    local is_open = vim.fn.getqflist({ winid = 0 }).winid ~= 0
    if is_open then
        vim.cmd("cclose")
    else
        vim.cmd("copen")
    end
end, { desc = "Toggle Quickfix List" })

vim.keymap.set("n", "fo", ":only<return>")
vim.keymap.set("n", "tt", "gt")
vim.keymap.set("n", "<esc>", ":noh<cr>")

vim.keymap.set("n", "<leader>h", ':lua require("harpoon.ui").toggle_quick_menu()<cr>')
vim.keymap.set("n", "<leader>m", ':lua require("harpoon.mark").add_file()<cr>')
vim.keymap.set("v", "<C-r>", "\"hy:%s/<C-r>h//g<left><left>")

vim.keymap.set("n", "<leader>?", require("telescope.builtin").oldfiles, { desc = "[?] Find recently opened files" })
vim.keymap.set("n", "<leader><space>", require("telescope.builtin").buffers, { desc = "[ ] Find existing buffers" })
vim.keymap.set("n", "<leader>/", function()
    -- You can pass additional configuration to telescope to change theme, layout, etc.
    require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
        winblend = 10,
        previewer = false,
    }))
end, { desc = "[/] Fuzzily search in current buffer" })

vim.keymap.set("n", "<leader>gf", require("telescope.builtin").git_files, { desc = "Search [G]it [F]iles" })
vim.keymap.set("n", "<leader>sf", require("telescope.builtin").find_files, { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>sh", require("telescope.builtin").help_tags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sw", require("telescope.builtin").grep_string, { desc = "[S]earch current [W]ord" })
vim.keymap.set("n", "<leader>sg", require("telescope.builtin").live_grep, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sd", require("telescope.builtin").diagnostics, { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>sr", require("telescope.builtin").resume, { desc = "[S]earch [R]esume" })

-- mapping to open quickfix list in telescope:
vim.keymap.set("n", "<leader>q", require("telescope.builtin").quickfix, { desc = "[Q]uickfix" })

-- Diagnostic keymaps
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Go to previous diagnostic message" })
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Go to next diagnostic message" })
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Open floating diagnostic message" })
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostics list" })

-- Open the diagnostic under the cursor in a float window
vim.keymap.set("n", "<leader>d", function()
    vim.diagnostic.open_float({
        border = "rounded",
    })
end)

-- NeoTree
vim.keymap.set("n", "<leader>nf", ":Neotree reveal<CR>", { desc = "find in neotree" })
vim.keymap.set("n", "<leader>n", ":Neotree focus<CR>", { desc = "toggle neotree" })
vim.keymap.set("n", "<leader>nn", ":Neotree close<CR>", { desc = "toggle neotree" })

-- [[ Configure LSP ]]
--  This function gets run when an LSP connects to a particular buffer.

-- Center buffer while navigating
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "{", "{zz")
vim.keymap.set("n", "}", "}zz")
vim.keymap.set("n", "{(", "{(zz")
vim.keymap.set("n", "})", "})zz")
vim.keymap.set("n", "N", "Nzz")
vim.keymap.set("n", "n", "nzz")
vim.keymap.set("n", "G", "Gzz")
vim.keymap.set("n", "gg", "ggzz")
vim.keymap.set("n", "<C-i>", "<C-i>zz")
vim.keymap.set("n", "<C-o>", "<C-o>zz")
vim.keymap.set("n", "%", "%zz")
vim.keymap.set("n", "*", "*zz")
vim.keymap.set("n", "#", "#zz")
vim.keymap.set("n", "u", "uzz")
vim.keymap.set("n", "<C-r>", "<C-r>zz")



-- Diagnostics

-- Goto next diagnostic of any severity
vim.keymap.set("n", "]d", function()
    vim.diagnostic.goto_next({})
    vim.api.nvim_feedkeys("zz", "n", false)
end)

-- Goto previous diagnostic of any severity
vim.keymap.set("n", "[d", function()
    vim.diagnostic.goto_prev({})
    vim.api.nvim_feedkeys("zz", "n", false)
end)

-- Goto next error diagnostic
vim.keymap.set("n", "fe", function()
    vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
    vim.api.nvim_feedkeys("zz", "n", false)
end)

-- Goto previous error diagnostic
vim.keymap.set("n", "fE", function()
    vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
    vim.api.nvim_feedkeys("zz", "n", false)
end)

-- Goto next warning diagnostic
vim.keymap.set("n", "]w", function()
    vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.WARN })
    vim.api.nvim_feedkeys("zz", "n", false)
end)

-- Goto previous warning diagnostic
vim.keymap.set("n", "[w", function()
    vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.WARN })
    vim.api.nvim_feedkeys("zz", "n", false)
end)

vim.keymap.set("n", "<leader>p", function()
    require("conform").format({ async = true, lsp_fallback = true })
end)
