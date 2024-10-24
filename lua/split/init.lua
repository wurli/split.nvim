local M = {}

function M.user_mapping(x)
    local opts = require("split.config"):get().keymaps[x]
    return function(type)
        require("split.splitters").split(type, opts)
    end
end

function M.setup(config)
    local cfg = require("split.config"):set(config or {}):get()

    if cfg.keymaps then
        -- local api = require("split.api")
        -- local vvar = vim.api.nvim_get_vvar

        for keymap, opts in pairs(cfg.keymaps) do
            if opts.operator_pending then
                vim.keymap.set(
                    { "n", "x" }, keymap,
                    function()
                        vim.opt.operatorfunc = ("v:lua.require'split.init'.user_mapping'%s'"):format(keymap)
                        return "g@"
                    end,
                    { expr = true, desc = "Split text on " .. opts.pattern }
                )
            else
                vim.keymap.set(
                    "n", keymap, M.user_mapping(keymap),
                    { desc = "Split text on " .. opts.pattern }
                )
            end
        end

    end

end

return M
