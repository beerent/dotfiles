-- user/plugins/minimap.lua
return {
  {
    "wfxr/minimap.vim",
    init = function()
      vim.g.minimap_width = 10
      vim.g.minimap_auto_start = 0 -- Manual toggle with :MinimapToggle
      vim.g.minimap_highlight_search = 1
    end,
  },
}
