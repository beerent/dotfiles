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

return {
	vim.keymap.set("n", "<C-t>", ":lua TermToggle(12)<CR>"),
	vim.keymap.set("i", "<C-t>", "<Esc>:lua TermToggle(12)<CR>"),
	vim.keymap.set("t", "<C-t>", "<C-\\><C-n>:lua TermToggle(12)<CR>"),

	-- Terminal go back to normal mode
	vim.keymap.set("t", "<C-\\><C-n>", "<C-\\><C-n>", { noremap = true, silent = true }),
	vim.keymap.set("t", "<C-\\><C-n>:q!", "<C-\\><C-n>:q!<CR>", { noremap = true, silent = true }),
}
