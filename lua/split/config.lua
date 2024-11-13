local utils = require("split.utils")

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@mod split.config Configuration
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---Plugin configuration
---@class SplitOpts
---
---The lua pattern to split on. Defaults to `","`.
---@field pattern? string | string[]
---
---Where to place the linebreak in relation to the separator. By
---default the linebreak will be inserted after the separator, i.e.
---split pattern.
---@field break_placement? BreakPlacement
---
---Whether to enter operator-pending mode when the mapping is called
---@field operator_pending? boolean
---
---A function to be applied to each separator before the split text is
---recombined
---@field transform_separators? fun(x: string, opts: SplitOpts): string
---
---A function to be applied to each segment before the split text is
---recombined
---@field transform_segments? fun(x: string, opts: SplitOpts): string
---
---A function to reindent the text after it has been split. This will
---be passed the marks `"["` and `"]"`. Can be `nil` if no indentation
---is desired. The default is to reindent using `=`, but you can set
---this to indent using the active LSP's formatter by setting
---`indenter = require("split.indent").indent_lsp`
---@field indenter? fun(m1: string, m2: string)
---
---A string that can be used to collapse lines into a single string
---before splitting. This can be helpful, e.g. if you want to
---transform multiple lines of text so that each line contains a
---single sentence.
---@field unsplitter? string | nil
---
---Whether to enter interactive mode when calling the mapping.
---Defaults to `false`.
---@field interactive? boolean
---
---If the selected region contains both commented and uncommented
---code, this option controls which portions should be split. Note
---that this only takes effect if the selected region contains a mix
---of commented and uncommented code; if the selected region is
---completely commented, the split will still be applied even if
---`smart_ignore = "commments"`. It's so smart!
---See |split.config.SmartIgnore| for available options.
---@field smart_ignore? SmartIgnore
---
---Characters used to delimit quoted regions, within which
---linebreaks will not be inserted. By default, this applies to
---double-quotes, single-quotes, and backticks.
---@field brace_characters? { left: string[], right: string[] }
---
---Characters used to delimit embraced regions, within which
---linebreaks will not be inserted. By default, recognised brace pairs
---are `[]`, `()`, and `{}`.
---@field quote_characters? { left: string[], right: string[] }

---Options for `break_placement`
---@alias BreakPlacement
---| '"after_separator"' # Place the linbreak before the split pattern
---| '"before_separator"' # Place the linebreak after the split pattern
---| '"on_separator"' # Replace the split pattern with a linebreak

---Options for `smart_ignore`. These options only take effect if the
---region being split contains a mix of commented and uncommented
---code.
---@alias SmartIgnore
---| '"comments"' # Only split commented regions
---| '"code"' # Only split uncommented regions
---| '"none"' # Split everything
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@class SplitConfigInput
---
---A table of keymappings. Table keys should give a keymapping to set,
---table values should be a subset of |split.config.SplitOpts|.
---@field keymaps? table<string, SplitOpts>
---
---A table of aliases to use in interactive mode. Table keys give the
---alias, which should be a single character, and table values give
---the pattern to use when that character is entered by the user.
---Alternatively you can specify a table of |split.config.SplitOpts|
---to further customise the behaviour of each alias.
---See |split.interactivity.default_aliases| for the default aliases.
---@field pattern_aliases table<string, string | SplitOpts>
---
---Options to use by default when setting keymaps.
---@field keymap_defaults? SplitOpts
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@class SplitConfig
---@field keymaps table<string, SplitOpts>
---@field pattern_aliases table<string, string | SplitOpts>
---@field keymap_defaults SplitOpts
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

---@param tb { trim_l: BreakPlacement[], trim_r: BreakPlacement[], pad_l: BreakPlacement[], pad_r: BreakPlacement[] }
local make_transformation = function(tb)
    ---@param s string
    ---@param opts SplitOpts
    ---@return string
    return function(s, opts)
        if utils.match(opts.break_placement, tb.trim_l or {}) ~= -1 then
            s = s:gsub("^%s+", "")
        end
        if utils.match(opts.break_placement, tb.trim_r or {}) ~= -1 then
            s = s:gsub("%s*$", "")
        end
        if utils.match(opts.break_placement, tb.pad_l or {}) ~= -1 then
            s = " " .. s
        end
        if utils.match(opts.break_placement, tb.pad_r or {}) ~= -1 then
            s = s .. " "
        end
        return s
    end
end

local Config = {
    state = {},
    ---@type SplitConfig
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
            ["<"] = {
                pattern = { "<[^=]", "<=", "==", ">[^=]", ">=" },
                break_placement = "before_separator"
            },
            ["."] = {
                pattern = "[%.?!]%s+",
                unsplitter = " ",
                smart_ignore = "code",
                quote_characters = {},
                brace_characters = {}
            }
        },
        keymap_defaults = {
            pattern = ",",
            break_placement = "after_separator",
            operator_pending = false,
            transform_segments = make_transformation({
                trim_l = { "before_separator", "on_separator", "after_separator" },
                trim_r = { "before_separator", "on_separator", "after_separator" },
            }),
            transform_separators = make_transformation({
                trim_l = { "before_separator" },
                trim_r = { "before_separator", "after_separator" },
                pad_r = { "before_separator" }
            }),
            indenter = require("split.indent").indent_equalprg,
            unsplitter = nil,
            interactive = false,
            smart_ignore = "comments",
            quote_characters = { left = { "'", '"', "`" }, right = { "'", '"', "`" } },
            brace_characters = { left = { "(", "{", "[" }, right = { ")", "}", "]" } }
        },
    },
}

---@package
---@param cfg SplitConfigInput
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

---@return SplitConfig
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
