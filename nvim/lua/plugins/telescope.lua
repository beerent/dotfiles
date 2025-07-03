-- File path: /Users/thedevdad/.config/nvim/lua/plugins/telescope.lua
return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-telescope/telescope-fzf-native.nvim",    build = "make" },
      { "nvim-telescope/telescope-live-grep-args.nvim" },
      --{ "nvim-telescope/telescope-ui-select.nvim" }, -- Added ui-select dependency

    },
    config = function()
      require("config.telescope") -- Load the config file
    end,
  },
}
