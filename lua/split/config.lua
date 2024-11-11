--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@mod split.config Configuration
---@tag split.config.defaults
---@brief [[
---split.nvim does stuff
---@brief ]]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---Plugin configuration
---@class SplitOpts
---
---The lua pattern to split on. Defaults to `","`.
---@field pattern? string
---
---Where to place the linebreak in relation to the
---separator. By default the linebreak will be inserted
---after the separator, i.e. split pattern.
---@field break_placement? BreakPlacement
---
---Whether to enter operator-pending mode when the mapping
---is called
---@field operator_pending? boolean
---
---A function to be applied to each separator before the
---split text is recombined
---@field transform_separators? fun(x: string, opts: SplitOpts): string | nil
---
---A function to be applied to each segment before the split
---text is recombined
---@field transform_segments? fun(x: string, opts: SplitOpts): string | nil
---
---A function to reindent the text after it has been split.
---This will be passed the marks `"["` and `"]"`. Can be
---`nil` if no indentation is desired. The default is to
---reindent using `=`, but you can set this to indent using
---the active LSP's formatter by setting
---`indenter = require("split.indent").indent_lsp`
---@field indenter? fun(m1: string, m2: string)
---
---A string that can be used to collapse lines into a single
---string before splitting. This can be helpful, e.g. if you
---want to transform multiple lines of text so that each
---line contains a single sentence.
---@field unsplitter? string | nil
---
---Whether to enter interactive mode when calling the
---mapping. Defaults to `false`.
---@field interactive? boolean
---
---Characters used to delimit quoted regions, within which
---no linebreaks will be inserted. By default, recognised
---quote characters are ", ', and `.
---@field brace_characters? { left: string[], right: string[] }
---
---Characters used to delimit embraced regions, within which
---no linebreaks will be inserted. By default, recognised
---brace pairs are `[]`, `()`, and `{}`.
---@field quote_characters? { left: string[], right: string[] }

---Options for break placement
---@alias BreakPlacement
---| '"after_separator"' # Place the linbreak before the split pattern
---| '"before_separator"' # Place the linebreak after the split pattern
---| '"on_separator"' # Replace the split pattern with a linebreak
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@class SplitConfig
---A table of keymappings. Table keys should give a keymapping to set, table
---values should be a subset of |split.config.SplitOpts|.
---@field keymaps? table<string, SplitOpts>
---A table of aliases to use in interactive mode. Table keys give the alias,
---which should be a single character, and table values give the pattern to use
---when that character is entered by the user. Alternatively you can specify a
---table of |split.config.SplitOpts| to further customise the behaviour of each
---alias. The default aliases are:
---* `","`: Split on commas.
---* `";"`: Split on semicolons.
---* `" "`: Split on one or more whitespace characters.
---* `"+"`: Split on `+`, `-`, `/`, and `%`, provided these are surrounded by
---one or more whitespace characters.
---* `"."`: Split by sentence.
---@field pattern_aliases? table<string, string | SplitOpts>
---These are the settings which will be used unless the keymap in question
---specifies otherwise.
---@field keymap_defaults? SplitOpts
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@class SplitConfigComplete
---@field keymaps table<string, SplitOpts>
---@field pattern_aliases table<string, string | SplitOpts>
---@field keymap_defaults SplitOpts
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


local default_transformation = function(type, use_leading_space)
    ---@param s string
    ---@param opts SplitOpts
    return function(s, opts)
        s = vim.trim(s)
        if type == "separators" and
            use_leading_space and
            opts.break_placement == "before_separator" then
            s = s .. " "
        end
        return s
    end
end

local Config = {
    state = {},
    ---@type SplitConfigComplete
    config = {
        keymaps = {
            ["gs"]  = { operator_pending = true, pattern = "," },
            ["gss"] = { operator_pending = false, pattern = "," },
            ["gS"]  = { operator_pending = true, interactive = true },
            ["gSS"] = { operator_pending = false, interactive = true },
        },
        pattern_aliases = {
            [","] = ",",
            [";"] = ";",
            [" "] = "%s+",
            ["+"] = " [+-/%] ",
            ["<"] = "  ",
            ["."] = {
                pattern = "[%.?!]%s+",
                unsplitter = " ",
                quote_characters = {},
                brace_characters = {}
            }
        },
        keymap_defaults = {
            pattern = ",",
            break_placement = "after_separator",
            operator_pending = false,
            transform_separators = default_transformation("separators", true),
            transform_segments = default_transformation("segments", false),
            transform_lines = nil,
            indenter = require("split.indent").indent_equalprg,
            unsplitter = nil,
            interactive = false,
            quote_characters = { left = { "'", '"', "`" }, right = { "'", '"', "`" } },
            brace_characters = { left = { "(", "{", "[" }, right = { ")", "}", "]" } }
        },
    },
}

---@package
---@param cfg SplitConfig
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

---@return SplitConfigComplete
function Config:get()
    return self.config
end

---@export Config
return setmetatable(Config, {
    __index = function(this, k)
        return this.state[k]
    end,
    __newindex = function(this, k, v)
        this.state[k] = v
    end,
})
