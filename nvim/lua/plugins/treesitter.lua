-- user/plugins/treesitter.lua
return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		dependencies = {
			"nvim-treesitter/nvim-treesitter-textobjects", -- For textobjects functionality
		},
		config = function()
			require("config.treesitter") -- Load the config file
		end,
	},
}
