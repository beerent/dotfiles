local term_buf = 0
local term_win = 0
local current_height = 0

function TermToggle()
    if vim.fn.win_gotoid(term_win) > 0 then
        if current_height == 12 then
            -- At size 12, Ctrl+T closes
            vim.cmd("hide")
            current_height = 0
        elseif current_height == 24 then
            -- At size 24, Ctrl+T goes to 12
            vim.cmd("resize 12")
            current_height = 12
            vim.cmd("startinsert!")
        end
    else
        -- Open new terminal at size 12
        vim.cmd("botright new")
        vim.cmd("resize 12")
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
        current_height = 12
    end
end

function TermToggleLarge()
    if vim.fn.win_gotoid(term_win) > 0 then
        if current_height == 12 then
            -- At size 12, go to 24
            vim.cmd("resize 24")
            current_height = 24
            vim.cmd("startinsert!")
        elseif current_height == 24 then
            -- At size 24, close
            vim.cmd("hide")
            current_height = 0
        end
    else
        -- Open new terminal directly at size 24
        vim.cmd("botright new")
        vim.cmd("resize 24")
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
        current_height = 24
    end
end

return {
    vim.keymap.set("n", "<C-t>", ":lua TermToggle()<CR>", { noremap = true, silent = true }),
    vim.keymap.set("i", "<C-t>", "<Esc>:lua TermToggle()<CR>", { noremap = true, silent = true }),
    vim.keymap.set("t", "<C-t>", "<C-\\><C-n>:lua TermToggle()<CR>", { noremap = true, silent = true }),

    vim.keymap.set("n", "<C-S-t>", ":lua TermToggleLarge()<CR>", { noremap = true, silent = true }),
    vim.keymap.set("i", "<C-S-t>", "<Esc>:lua TermToggleLarge()<CR>", { noremap = true, silent = true }),
    vim.keymap.set("t", "<C-S-t>", "<C-\\><C-n>:lua TermToggleLarge()<CR>", { noremap = true, silent = true }),

    -- Terminal go back to normal mode
    vim.keymap.set("t", "<C-\\><C-n>", "<C-\\><C-n>", { noremap = true, silent = true }),
    vim.keymap.set("t", "<C-\\><C-n>:q!", "<C-\\><C-n>:q!<CR>", { noremap = true, silent = true }),
}
