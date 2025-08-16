local top_term_buf = 0
local top_term_win = 0
local top_current_height = 0

function TopTermToggle()
    if vim.fn.win_gotoid(top_term_win) > 0 then
        if top_current_height == 12 then
            -- At size 12, Ctrl+, closes
            vim.cmd("hide")
            top_current_height = 0
        elseif top_current_height == 24 then
            -- At size 24, Ctrl+, goes to 12
            vim.cmd("resize 12")
            top_current_height = 12
            vim.cmd("startinsert!")
        end
    else
        -- Open new terminal at size 12 from top
        vim.cmd("topleft new")
        vim.cmd("resize 12")
        local success, _ = pcall(vim.cmd, "buffer " .. top_term_buf)
        if not success then
            vim.fn.termopen(vim.env.SHELL, { detach = 0 })
            top_term_buf = vim.fn.bufnr("")
            vim.cmd("set nonumber")
            vim.cmd("set norelativenumber")
            vim.cmd("set signcolumn=no")
        end
        vim.cmd("startinsert!")
        top_term_win = vim.fn.win_getid()
        top_current_height = 12
    end
end

function TopTermToggleLarge()
    if vim.fn.win_gotoid(top_term_win) > 0 then
        if top_current_height == 12 then
            -- At size 12, go to 24
            vim.cmd("resize 24")
            top_current_height = 24
            vim.cmd("startinsert!")
        elseif top_current_height == 24 then
            -- At size 24, close
            vim.cmd("hide")
            top_current_height = 0
        end
    else
        -- Open new terminal directly at size 24 from top
        vim.cmd("topleft new")
        vim.cmd("resize 24")
        local success, _ = pcall(vim.cmd, "buffer " .. top_term_buf)
        if not success then
            vim.fn.termopen(vim.env.SHELL, { detach = 0 })
            top_term_buf = vim.fn.bufnr("")
            vim.cmd("set nonumber")
            vim.cmd("set norelativenumber")
            vim.cmd("set signcolumn=no")
        end
        vim.cmd("startinsert!")
        top_term_win = vim.fn.win_getid()
        top_current_height = 24
    end
end

return {
    vim.keymap.set("n", "<C-,>", ":lua TopTermToggle()<CR>", { noremap = true, silent = true }),
    vim.keymap.set("i", "<C-,>", "<Esc>:lua TopTermToggle()<CR>", { noremap = true, silent = true }),
    vim.keymap.set("t", "<C-,>", "<C-\\><C-n>:lua TopTermToggle()<CR>", { noremap = true, silent = true }),

    vim.keymap.set("n", "<C-S-,>", ":lua TopTermToggleLarge()<CR>", { noremap = true, silent = true }),
    vim.keymap.set("i", "<C-S-,>", "<Esc>:lua TopTermToggleLarge()<CR>", { noremap = true, silent = true }),
    vim.keymap.set("t", "<C-S-,>", "<C-\\><C-n>:lua TopTermToggleLarge()<CR>", { noremap = true, silent = true }),

    -- Terminal go back to normal mode
    vim.keymap.set("t", "<C-\\><C-n>", "<C-\\><C-n>", { noremap = true, silent = true }),
    vim.keymap.set("t", "<C-\\><C-n>:q!", "<C-\\><C-n>:q!<CR>", { noremap = true, silent = true }),
}