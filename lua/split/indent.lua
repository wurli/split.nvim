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

    local start_line = range[1]
    local end_line   = range[3]
    local lines      = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, true)

    for lnum, line in ipairs(lines) do
        vim.v.lnum = lnum + start_line - 1
        local indent = tonumber(vim.fn.execute("echo " .. indentexpr))

        if line:match("^%s*$") then
            lines[lnum] = ""
        -- indent = -1 means 'keep the current indent'
        elseif indent and indent ~= -1 then
            lines[lnum] = string.rep(" ", indent) .. line:gsub("^%s+", "")
        end
    end

    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, true, lines)
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
