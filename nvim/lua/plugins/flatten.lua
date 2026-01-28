return {
    "willothy/flatten.nvim",
    lazy = false,
    priority = 1001,
    opts = {
        window = {
            open = "current",
        },
        hooks = {
            should_block = function(argv)
                -- Block for git commit messages
                return vim.tbl_contains(argv, "-c") or vim.tbl_contains(argv, "commit")
            end,
            pipe_path = function()
                return vim.env.NVIM
            end,
        },
    },
}
