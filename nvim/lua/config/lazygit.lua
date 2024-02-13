local has_lazygit, lazygit = pcall(require, "lazygit")

if not has_lazygit then
  return
end

-- Configure LazyGit
lazygit.setup({

  -- Here you can put your LazyGit configuration options
})
