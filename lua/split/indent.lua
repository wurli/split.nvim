local M = {}

-- Theoretically does the same thing as running `=` between marks m1 and m2.
function M.equalprg(range)
    -- NB in theory this whole function could be as simple as just executing
    -- the following line, but it breaks dot-repeat and I'm not sure why.
    -- Something to do with marks getting borked I think.
    -- vim.cmd((":lockmarks silent normal! g'%s=g'%s"):format(m1, m2))
    local indentexpr = vim.opt.indentexpr:get()

    if indentexpr == "" then
        return
    end

    local start_line, end_line = range[1], range[3]
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, true)

    for lnum, line in ipairs(lines) do
        local lnum_abs = lnum + start_line - 1

        -- indentexpr needs both the cursor and v:lnum to be set
        vim.v.lnum = lnum_abs
        vim.api.nvim_win_set_cursor(0, { lnum_abs, 0 })

        local indent = tonumber(vim.fn.execute("echo " .. indentexpr))

        if line:match("^%s*$") then
            lines[lnum] = ""
        -- indent = -1 means 'keep the current indent'; see :help indentexpr
        elseif indent and indent ~= -1 then
            lines[lnum] = string.rep(" ", indent) .. line:gsub("^%s+", "")
        end

        -- Annoyingly, we need to incrementally insert the indented lines
        -- since indentexpr() needs line n to have the correct indentation
        -- in order to calculate the correct indentation for line n + 1 >:(
        vim.api.nvim_buf_set_lines(0, lnum_abs - 1, lnum_abs, true, { lines[lnum] })
    end

    -- Since we've been moving the cursor around we now need to put it back
    -- at the start.
    vim.api.nvim_win_set_cursor(0, { range[1], range[2] })
end


function M.lsp(range)
    vim.lsp.buf.format({
        range = {
            ["start"] = { range[1], range[2] },
            ["end"] = { range[3], range[4] }
        }
    })
end

return M
