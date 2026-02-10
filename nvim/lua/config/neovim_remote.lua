-- Handles file opening from nested terminal nvim invocations.
-- Called via `nvim --server $NVIM --remote-expr` from the shell wrapper.
local M = {}

function M.open(file, cwd, lockfile, shell_pid)
    local target_win = nil
    shell_pid = tonumber(shell_pid)

    -- Find the exact terminal window by matching the shell's PID.
    -- $$ in the shell == b:terminal_job_pid — always a direct match.
    if shell_pid then
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "terminal" and vim.b[buf].terminal_job_pid == shell_pid then
                target_win = win
                break
            end
        end
    end

    -- Fallback to TermEnter tracking
    if not target_win then
        local w = vim.g._last_term_win
        if w and vim.api.nvim_win_is_valid(w) then
            local buf = vim.api.nvim_win_get_buf(w)
            if vim.bo[buf].buftype == "terminal" then
                target_win = w
            end
        end
    end

    -- Ensure the terminal buffer stays alive when we switch away from it
    if target_win then
        local term_buf = vim.api.nvim_win_get_buf(target_win)
        vim.bo[term_buf].bufhidden = "hide"
        vim.api.nvim_set_current_win(target_win)
    end

    if vim.fn.isdirectory(file) == 1 then
        -- Directory: set tab cwd and show a blank buffer
        local new_buf = vim.api.nvim_create_buf(true, false)
        if target_win then
            vim.api.nvim_win_set_buf(target_win, new_buf)
        end
        vim.cmd("tcd " .. vim.fn.fnameescape(file))
    else
        -- File: create/find buffer and place it in the window directly
        -- (avoids :edit which can fail on modified terminal buffers)
        local bufnr = vim.fn.bufadd(file)
        vim.fn.bufload(bufnr)
        vim.bo[bufnr].buflisted = true
        if target_win then
            vim.api.nvim_win_set_buf(target_win, bufnr)
        else
            vim.api.nvim_set_current_buf(bufnr)
        end
        if cwd and cwd ~= "" then
            vim.cmd("tcd " .. vim.fn.fnameescape(cwd))
        end
    end

    -- For blocking calls (git commit etc.), watch for buffer close to release the lock
    if lockfile and lockfile ~= "" then
        local cur_buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_create_autocmd({ "BufUnload", "BufDelete" }, {
            buffer = cur_buf,
            once = true,
            callback = function()
                os.remove(lockfile)
            end,
        })
    end

    return ""
end

return M
