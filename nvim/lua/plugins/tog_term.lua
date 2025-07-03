local term_buf = 0
local term_win = 0

function TermToggle(height)
	if vim.fn.win_gotoid(term_win) > 0 then
		vim.cmd("hide")
	else
		vim.cmd("botright new")
		vim.cmd("resize " .. height)
		local success, _ = pcall(vim.cmd, "buffer " .. term_buf)
		if not success then
			vim.fn.termopen(vim.env.SHELL, { detach = 0 })
			term_buf = vim.fn.bufnr("")
			vim.cmd("set nonumber")
			vim.cmd("set norelativenumber")
			vim.cmd("set signcolumn=no")
		end
		vim.cmd("startinsert!")
		term_win = vim.fn.win_getid()
	end
end

function TermOpen(height)
	-- If terminal is already visible, close it first to resize
	if vim.fn.win_gotoid(term_win) > 0 then
		vim.cmd("hide")
	end

	-- Always open the terminal at the specified height
	vim.cmd("botright new")
	vim.cmd("resize " .. height)
	local success, _ = pcall(vim.cmd, "buffer " .. term_buf)
	if not success then
		vim.fn.termopen(vim.env.SHELL, { detach = 0 })
		term_buf = vim.fn.bufnr("")
		vim.cmd("set nonumber")
		vim.cmd("set norelativenumber")
		vim.cmd("set signcolumn=no")
	end
	vim.cmd("startinsert!")
	term_win = vim.fn.win_getid()
end

return {
	-- Original Ctrl+T functionality (toggles at height 12)
	vim.keymap.set("n", "<C-t>", ":lua TermToggle(12)<CR>"),
	vim.keymap.set("i", "<C-t>", "<Esc>:lua TermToggle(12)<CR>"),
	vim.keymap.set("t", "<C-t>", "<C-\\><C-n>:lua TermToggle(12)<CR>"),

	-- New Ctrl+Shift+T functionality (always opens at double height 24)
	vim.keymap.set("n", "<C-S-t>", ":lua TermOpen(24)<CR>"),
	vim.keymap.set("i", "<C-S-t>", "<Esc>:lua TermOpen(24)<CR>"),
	vim.keymap.set("t", "<C-S-t>", "<C-\\><C-n>:lua TermOpen(24)<CR>"),

	-- Terminal go back to normal mode
	vim.keymap.set("t", "<C-\\><C-n>", "<C-\\><C-n>", { noremap = true, silent = true }),
	vim.keymap.set("t", "<C-\\><C-n>:q!", "<C-\\><C-n>:q!<CR>", { noremap = true, silent = true }),
}
