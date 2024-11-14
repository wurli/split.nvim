local M = {}

-- Theoretically does the same thing as running `=` between marks m1 and m2.
function M.indent_equalprg(m1, m2)
    -- NB in theory this whole function could be as simple as just executing
    -- the following line, but it breaks dot-repeat and I'm not sure why.
    -- Something to do with marks getting borked I think.
    -- vim.cmd((":lockmarks silent normal! g'%s=g'%s"):format(m1, m2))

    local start_line = vim.api.nvim_buf_get_mark(0, m1)[1]
    local end_line   = vim.api.nvim_buf_get_mark(0, m2)[1]
    local indentexpr = vim.opt.indentexpr:get()
    local lines      = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, true)

    for lnum, line in ipairs(lines) do
        vim.v.lnum = lnum + start_line - 1
        local indent = tonumber(vim.fn.execute("echo " .. indentexpr))

        if line:match("^%s*$") then
            lines[lnum] = ""
        elseif indent then
            lines[lnum] = string.rep(" ", indent) .. line:gsub("^%s+", "")
        end
    end

    vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, true, lines)
end


-- vim.v.lnum = 15
-- print({
--     vim.api.nvim_command("echo nvim_treesitter#indent()")
-- })

-- vim.v.lnum = 20
-- print({
--     vim.api.nvim_command("echo GetLuaIndent()")
-- })

function M.indent_lsp(m1, m2)
    vim.lsp.buf.format({
        range = {
            ["start"] = vim.api.nvim_buf_get_mark(0, m1),
            ["end"] = vim.api.nvim_buf_get_mark(0, m2),
        }
    })
end

return M
