local M = {}

function M.indent_equalprg(m1, m2)
    vim.api.nvim_cmd({
        cmd = 'normal',
        bang = true,
        args = { ("g'%s=g'%s"):format(m1, m2) },
        mods = { silent = true }
    }, {})
end

function M.indent_lsp(m1, m2)
    vim.lsp.buf.format({
        range = {
            ["start"] = vim.api.nvim_buf_get_mark(0, m1),
            ["end"] = vim.api.nvim_buf_get_mark(0, m2),
        }
    })
end

return M
