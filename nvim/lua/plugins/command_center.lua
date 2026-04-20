local cc_buf = nil
local cc_win = nil

function CCToggle()
    -- If window is visible, hide it
    if cc_win and vim.api.nvim_win_is_valid(cc_win) then
        vim.api.nvim_win_hide(cc_win)
        cc_win = nil
        return
    end

    -- Create buffer and start terminal if needed
    local need_term = false
    if not cc_buf or not vim.api.nvim_buf_is_valid(cc_buf) then
        cc_buf = vim.api.nvim_create_buf(false, true)
        need_term = true
    end

    -- Full-screen floating window
    cc_win = vim.api.nvim_open_win(cc_buf, true, {
        relative = "editor",
        width = vim.o.columns,
        height = vim.o.lines - 1,
        col = 0,
        row = 0,
        style = "minimal",
        border = "none",
    })

    if need_term then
        vim.fn.termopen(vim.fn.expand("~/Documents/command_center/cc"), {
            detach = 0,
            on_exit = function()
                vim.schedule(function()
                    if cc_win and vim.api.nvim_win_is_valid(cc_win) then
                        vim.api.nvim_win_hide(cc_win)
                    end
                    cc_win = nil
                    cc_buf = nil
                end)
            end,
        })
        vim.wo[cc_win].number = false
        vim.wo[cc_win].relativenumber = false
        vim.wo[cc_win].signcolumn = "no"

        -- Buffer-local Ctrl+C in terminal mode (only closes cc, not other terminals)
        vim.keymap.set("t", "<C-c>", "<C-\\><C-n>:lua CCToggle()<CR>", {
            buffer = cc_buf,
            noremap = true,
            silent = true,
        })
    end

    vim.cmd("startinsert!")
end

-- Keep floating window full-screen on resize
vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
        if cc_win and vim.api.nvim_win_is_valid(cc_win) then
            vim.api.nvim_win_set_config(cc_win, {
                relative = "editor",
                width = vim.o.columns,
                height = vim.o.lines - 1,
                col = 0,
                row = 0,
            })
        end
    end,
})

return {
    vim.keymap.set("n", "<C-c>", ":lua CCToggle()<CR>", { noremap = true, silent = true }),
    vim.keymap.set("i", "<C-c>", "<Esc>:lua CCToggle()<CR>", { noremap = true, silent = true }),
}
