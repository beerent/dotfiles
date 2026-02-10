-- Handles file opening from nested terminal nvim invocations.
-- Called via `nvim --server $NVIM --remote-expr` from the shell wrapper.
local M = {}

function M.open(file, cwd, lockfile)
    -- Switch to the most recently focused terminal window
    local win = vim.g._last_term_win
    if win and vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].buftype == "terminal" then
            vim.api.nvim_set_current_win(win)
        end
    end

    if vim.fn.isdirectory(file) == 1 then
        vim.cmd("tcd " .. vim.fn.fnameescape(file))
        vim.cmd("enew")
    else
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        if cwd and cwd ~= "" then
            vim.cmd("tcd " .. vim.fn.fnameescape(cwd))
        end
    end

    -- For blocking calls (git commit etc.), watch for buffer close to release the lock
    if lockfile and lockfile ~= "" then
        local bufnr = vim.api.nvim_get_current_buf()
        vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
            buffer = bufnr,
            once = true,
            callback = function()
                os.remove(lockfile)
            end,
        })
    end

    return ""
end

return M
