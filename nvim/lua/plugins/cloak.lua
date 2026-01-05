return {
  "laytan/cloak.nvim",
  opts = {
    enabled = true,
    cloak_character = "*",
    highlight_group = "Comment",
    patterns = {
      {
        file_pattern = { ".env*", "wrangler.toml", "*.env" },
        cloak_pattern = "=.+",
        replace = nil,
      },
    },
  },
  keys = {
    { "<leader>ct", "<cmd>CloakToggle<cr>", desc = "Toggle Cloak" },
  },
}
