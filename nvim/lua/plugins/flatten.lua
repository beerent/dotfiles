return {
    "willothy/flatten.nvim",
    lazy = false,
    priority = 1001,
    config = function()
        require("flatten").setup({
            window = {
                open = "current",
            },
            callbacks = {
                should_block = function(argv)
                    -- Block for git commit messages
                    return vim.tbl_contains(argv, "-c") or vim.tbl_contains(argv, "commit")
                end,
                post_open = function(bufnr, winnr, ft, is_blocking)
                    if is_blocking then
                        -- Hide the terminal while editing
                        require("flatten").config.saved_terminal = vim.api.nvim_get_current_win()
                    end
                end,
                block_end = function()
                    -- Restore terminal after blocking edit
                    local saved = require("flatten").config.saved_terminal
                    if saved and vim.api.nvim_win_is_valid(saved) then
                        vim.api.nvim_set_current_win(saved)
                    end
                end,
            },
        })
    end,
}
