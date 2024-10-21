local M = {}

local user_mapping = require("split.api").user_mapping

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
                        vim.opt.operatorfunc = (
                            "v:lua.require'split.api'.user_mapping'%s'"
                        ):format(keymap)
                        return "g@"
                    end,
                    { expr = true, desc = "Split text on " .. opts.pattern }
                )
            else
                vim.keymap.set(
                    "n", keymap, user_mapping(keymap),
                    { desc = "Split text on " .. opts.pattern }
                )
            end
        end

    end

end

return M
