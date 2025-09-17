return {
  "rcarriga/nvim-notify",
  config = function()
    local notify = require("notify")

    notify.setup({
      background_colour = "#000000",
      fps = 60,
      level = 2,
      minimum_width = 50,
      render = "compact",
      stages = "slide",
      timeout = 3000,
      top_down = false,
    })

    -- Set as default notify function
    vim.notify = notify
  end,
}