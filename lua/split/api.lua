local splitters = require("split.splitters")

local M = {}

M.split_linewise = splitters.split_linewise
M.split_charwise = splitters.split_charwise

function M.user_mapping(x)
    local opts = require("split.config"):get().keymaps[x]
    return function(type)
        require("split.splitters").split(type, opts)
    end
end

function M.split_using_config(keymap, operator)
    return function()
        vim.opt.operatorfunc = ("v:lua.require'split.api'.user_mapping'%s'"):format(keymap)
        return operator
    end
end

return M
