return {
  'catppuccin/nvim',
  name = 'catppuccin',
  priority = 1000, -- Ensure it loads early among plugins
  config = function()
    require('catppuccin').setup({
      -- Your Catppuccin config here, e.g.:
      flavour = 'mocha', -- latte, frappe, macchiato, mocha
      background = { light = 'latte', dark = 'mocha' },
      transparent_background = false,
      -- ... other options ...
    })
    vim.cmd.colorscheme('catppuccin')
  end,
}
