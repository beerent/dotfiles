return {
    "willothy/flatten.nvim",
    lazy = false,
    priority = 1001,
    config = function()
        -- Track the most recently focused terminal window.
        -- TermEnter fires when entering terminal mode, which is exactly when
        -- the user is typing commands — so this always points to the right window.
        vim.api.nvim_create_autocmd("TermEnter", {
            callback = function()
                vim.g._flatten_last_term_win = vim.api.nvim_get_current_win()
            end,
        })

        require("flatten").setup({
            window = {
                open = function(opts)
                    local files = opts.files
                    if #files == 0 then return end

                    local focus = files[1]

                    -- Use the most recently focused terminal window
                    local win = vim.g._flatten_last_term_win
                    if win and vim.api.nvim_win_is_valid(win) then
                        local buf = vim.api.nvim_win_get_buf(win)
                        if vim.bo[buf].buftype == "terminal" then
                            vim.api.nvim_win_set_buf(win, focus.bufnr)
                            vim.api.nvim_set_current_win(win)
                            if opts.guest_cwd and opts.guest_cwd ~= "" then
                                vim.cmd("tcd " .. opts.guest_cwd)
                            end
                            return focus.bufnr, win
                        end
                    end

                    -- Fallback: open in current window
                    vim.api.nvim_set_current_buf(focus.bufnr)
                    if opts.guest_cwd and opts.guest_cwd ~= "" then
                        vim.cmd("tcd " .. opts.guest_cwd)
                    end
                    return focus.bufnr, vim.api.nvim_get_current_win()
                end,
            },
            hooks = {
                should_block = function(argv)
                    return vim.tbl_contains(argv, "-c") or vim.tbl_contains(argv, "commit")
                end,
                pipe_path = function()
                    return vim.env.NVIM
                end,
                post_open = function(opts)
                    local bufname = vim.api.nvim_buf_get_name(opts.bufnr)
                    if bufname ~= "" and vim.fn.isdirectory(bufname) == 1 then
                        if opts.winnr and vim.api.nvim_win_is_valid(opts.winnr) then
                            vim.api.nvim_set_current_win(opts.winnr)
                        end
                        vim.cmd("tcd " .. vim.fn.fnameescape(bufname))
                        vim.api.nvim_buf_delete(opts.bufnr, { force = true })
                        vim.cmd("enew")
                    end
                end,
            },
        })
    end,
}
