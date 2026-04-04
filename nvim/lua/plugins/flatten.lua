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

        -- Global QuitPre: when quitting a buffer in a tab that has a hidden
        -- terminal (replaced by flatten), restore the terminal instead of
        -- closing the tab / exiting Neovim.
        vim.api.nvim_create_autocmd("QuitPre", {
            callback = function()
                local term_buf = vim.t._flatten_term_buf
                if not term_buf or not vim.api.nvim_buf_is_valid(term_buf) then
                    return
                end
                if vim.bo.modified then
                    return
                end
                -- Don't duplicate if terminal is already visible in this tab
                for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                    if vim.api.nvim_win_get_buf(w) == term_buf then
                        return
                    end
                end
                vim.api.nvim_open_win(term_buf, false, { split = "below" })
                vim.schedule(function()
                    if vim.api.nvim_buf_is_valid(term_buf) then
                        vim.cmd("startinsert")
                    end
                end)
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

                            -- Save terminal buffer on the tab so it survives buffer replacements
                            vim.t._flatten_term_buf = buf

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
