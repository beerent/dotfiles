-- user/config/treesitter.lua

require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"c",
		"cpp",
		"go",
		"lua",
		"python",
		"rust",
		"tsx",
		"javascript",
		"typescript",
		"vimdoc",
		"vim",
		"bash",
	},
	highlight = {
		enable = true,
	},
	textobjects = {
		select = {
			enable = true,
			lookahead = true,
			keymaps = {
				["aa"] = "@parameter.outer",
				["ia"] = "@parameter.inner",
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ac"] = "@class.outer",
				["ic"] = "@class.inner",
			},
		},
		move = {
			enable = true,
			set_jumps = true,
			goto_next_start = {
				["]m"] = "@function.outer",
				["]]"] = "@class.outer",
			},
			goto_next_end = {
				["]M"] = "@function.outer",
				["]["] = "@class.outer",
			},
			goto_previous_start = {
				["[m"] = "@function.outer",
				["[["] = "@class.outer",
			},
			goto_previous_end = {
				["[M"] = "@function.outer",
				["[]"] = "@class.outer",
			},
		},
		swap = {
			enable = true,
			swap_next = {
				["<leader>a"] = "@parameter.inner",
			},
			swap_previous = {
				["<leader>A"] = "@parameter.inner",
			},
		},
	},
})

-- Incremental selection keymaps
vim.keymap.set("n", "<C-space>", function()
	require("nvim-treesitter.incremental_selection").init_selection()
end, { desc = "Init treesitter selection" })

vim.keymap.set("v", "<C-space>", function()
	require("nvim-treesitter.incremental_selection").node_incremental()
end, { desc = "Increment treesitter selection" })

vim.keymap.set("v", "<C-s>", function()
	require("nvim-treesitter.incremental_selection").scope_incremental()
end, { desc = "Increment treesitter scope" })

vim.keymap.set("v", "<M-space>", function()
	require("nvim-treesitter.incremental_selection").node_decremental()
end, { desc = "Decrement treesitter selection" })
