return {
    "willothy/flatten.nvim",
    lazy = false,
    priority = 1001,
    opts = {
        window = {
            open = function(opts)
                local files = opts.files
                if #files == 0 then return end

                local focus = files[1]

                -- Find the terminal window in the current tabpage and open there
                local tabpage = vim.api.nvim_get_current_tabpage()
                for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
                    local buf = vim.api.nvim_win_get_buf(win)
                    if vim.bo[buf].buftype == "terminal" then
                        vim.api.nvim_win_set_buf(win, focus.bufnr)
                        vim.api.nvim_set_current_win(win)
                        return focus.bufnr, win
                    end
                end

                -- Fallback: open in current window
                vim.api.nvim_set_current_buf(focus.bufnr)
                return focus.bufnr, vim.api.nvim_get_current_win()
            end,
        },
        hooks = {
            should_block = function(argv)
                -- Block for git commit messages
                return vim.tbl_contains(argv, "-c") or vim.tbl_contains(argv, "commit")
            end,
            pipe_path = function()
                return vim.env.NVIM
            end,
            post_open = function(opts)
                local bufname = vim.api.nvim_buf_get_name(opts.bufnr)
                if bufname ~= "" and vim.fn.isdirectory(bufname) == 1 then
                    vim.cmd("cd " .. vim.fn.fnameescape(bufname))
                    vim.api.nvim_buf_delete(opts.bufnr, { force = true })
                    vim.cmd("enew")
                end
            end,
        },
    },
}
