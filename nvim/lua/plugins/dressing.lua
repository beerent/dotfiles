return {
    'stevearc/dressing.nvim',
    config = function()
        require('dressing').setup({
            input = {
                enabled = true,
                default_prompt = "➤ ",
                insert_only = false, -- This allows normal mode in the input
                start_in_insert = true,
                border = "rounded",
                relative = "cursor",
                prefer_width = 40,
                width = nil,
                max_width = { 140, 0.9 },
                min_width = { 20, 0.2 },
                get_config = function(opts)
                    if opts.prompt and opts.prompt:find("New Name") then
                        return {
                            insert_only = false,
                            start_in_insert = false, -- Start in normal mode for rename
                        }
                    end
                end,
            },
        })
    end,
}
