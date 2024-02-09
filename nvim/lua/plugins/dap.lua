return {
	{
		"mfussenegger/nvim-dap",

		-- lazy = true,
		dependencies = {
			{
				"rcarriga/nvim-dap-ui",
				config = function()
					require("dapui").setup()
				end,
			},
			{
				"mxsdev/nvim-dap-vscode-js",
				dependencies = { "mfussenegger/nvim-dap" },
				config = function() end,
			},

			{
				"microsoft/vscode-js-debug",
				build = "npm install --legacy-peer-deps && npx gulp vsDebugServerBundle && mv dist out",
			},
		},
		config = function()
			local dap_ui = require("dapui")
			dap_ui.setup()

			require("dap-vscode-js").setup({
				debugger_path = vim.fn.stdpath("data") .. "/lazy/vscode-js-debug",
				adapters = { "pwa-node", "pwa-chrome", "pwa-msedge", "node-terminal", "pwa-extensionHost" },
			})

			local dap = require("dap")

			dap.listeners.before.attach.dap_ui_config = function()
				dap_ui.open()
			end
			dap.listeners.before.launch.dap_ui_config = function()
				dap_ui.open()
			end
			dap.listeners.before.event_terminated.dap_ui_config = function()
				dap_ui.close()
			end
			dap.listeners.before.event_exited.dap_ui_config = function()
				dap_ui.close()
			end

			vim.keymap.set("n", "<Leader>dt", ":DapToggleBreakpoint<CR>")
			vim.keymap.set("n", "<Leader>dc", ":DapContinue<CR>")
			vim.keymap.set("n", "<Leader>dx", ":DapTerminate<CR>")
			vim.keymap.set("n", "<Leader>do", ":DapStepOver<CR>")

			local dap_vscode_js_extensions = {
				"javascript",
				"typescript",
				"javascriptreact",
				"typescriptreact",
			}

			for _idx, extension in ipairs(dap_vscode_js_extensions) do
				dap.configurations[extension] = {
					{
						type = "pwa-node",
						request = "launch",
						name = "run",
						cwd = "${workspaceFolder}",
						runtimeArgs = { "ts-node", "src/server.ts" },
						runtimeExecutable = "npx",
						sourceMaps = true,
						protocol = "inspector",
						skipFiles = { "<node_internals>/**", "node_modules/**" },
						resolveSourceMapLocations = {
							"${workspaceFolder}/**",
							"!**/node_modules/**",
						},
					},
				}
			end
		end,
	},
}
