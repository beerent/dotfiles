return {
	{
		"dmmulroy/tsc.nvim",
		lazy = true,
		ft = {
			"typescript",
			"typescriptreact",
		},
		config = function()
			require("tsc").setup()
			local notify = require("notify")
			vim.notify = function(message, level, opts)
				return notify(message, level, opts)
			end
		end,
		dependencies = {
			"rcarriga/nvim-notify",
		},
	},
}
