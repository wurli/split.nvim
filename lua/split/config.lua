local Config = {
    state = {},
    config = {
        keymaps = {
            ["gs"]  = { operator_pending = true, pattern = "," },
            ["gss"] = { operator_pending = false, pattern = "," },
            ["gS"]  = { operator_pending = true, interactive = true },
            ["gSS"] = { operator_pending = false, interactive = true },
        },
        keymap_defaults = {
            pattern = ",",
            break_placement = "after_separator",
            operator_pending = false,
            hook_pre_split = nil,
            hook_post_split = nil,
            transform_separators = vim.fn.trim,
            transform_segments   = vim.fn.trim,
            interactive = false
        },
        pattern_aliases = {
            [","] = ",",
            [" "] = "%s+",
            [";"] = ";",
            ["+"] = " [+-/%] ",
            ["."] = "[%.?!]%s+",
        }
    },
}

function Config:set(cfg)
    if cfg then
        self.config = vim.tbl_deep_extend("force", self.config, cfg)

        for key, opts in pairs(self.config.keymaps) do
            self.config.keymaps[key] = vim.tbl_deep_extend(
                "force",
                self.config.keymap_defaults,
                opts
            )
        end
    end

    return self
end

function Config:get()
    return self.config
end

return setmetatable(Config, {
    __index = function(this, k)
        return this.state[k]
    end,
    __newindex = function(this, k, v)
        this.state[k] = v
    end,
})
