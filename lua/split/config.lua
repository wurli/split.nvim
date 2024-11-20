local utils = require("split.utils")

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@mod split.config Configuration
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
---@field interactive_options? table<string, string | SplitOpts>
---
---Options to use by default when setting keymaps.
---@field keymap_defaults? SplitOpts
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---Plugin configuration
---@class SplitOpts
---
---The lua pattern to split on. Defaults to `","`. Multiple patterns
---can also be provided in a table if a single string doesn't give
---enough flexibility.
---@field pattern? string | string[]
---
---Where to place the linebreak in relation to the split pattern. By
---default the linebreak will be inserted after the pattern. For
---fine-grained control you can pass a function which
---accepts |split.algorithm.LineInfo| and |split.config.SplitOpts|.
---This function should return one of |split.config.BreakPlacement|.
---@field break_placement? BreakPlacement | fun(line_info: LineInfo, opts: SplitOpts): BreakPlacement
---
---Whether to enter operator-pending mode when the mapping is called
---@field operator_pending? boolean
---
---A function to be applied to each separator before the split text is
---recombined. This function will be passed the element being
---transformed, the configuration for the current keymapping
---(see |split.config.SplitOpts|), and information about the current
---line (see |split.algorithm.LineInfo|)
---@field transform_separators? fun(x: string, opts: SplitOpts, info: LineInfo): string
---
---A function to be applied to each segment before the split text is
---recombined. This function will be passed the element being
---transformed, the configuration for the current keymapping
---(see |split.config.SplitOpts|), and information about the current
---line (see |split.algorithm.LineInfo|)
---@field transform_segments? fun(x: string, opts: SplitOpts, info: LineInfo): string
---
---The type of indentation to apply. This can be one of the following
---options:
--- - `"equalprg"` to use the same indentation as <=>. This is the 
---   default option.
--- - `"lsp"` to use your LSP server's indentation, if applicable
---   (note that some LSP servers will indent the whole file if this
---   option is set)
--- - A function that will be passed the range over which to apply the
---   indentation. This range will be in the form 
---   `{start_row, start_col, end_row, end_col}`. Rows/cols are
---   (1, 0)-indexed.
--- - `"none"` to not apply indentation.
---@field indenter? '"equalprg"' | '"lsp"' | '"none"' | fun(range: integer[])
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
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---Options for `break_placement`
---@alias BreakPlacement
---| '"after_pattern"' # Place the linbreak before the split pattern
---| '"before_pattern"' # Place the linebreak after the split pattern
---| '"on_pattern"' # Replace the split pattern with a linebreak
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---Options for `smart_ignore`. These options only take effect if the
---region being split contains a mix of commented and uncommented
---code.
---@alias SmartIgnore
---| '"comments"' # Only split commented regions
---| '"code"' # Only split uncommented regions
---| '"none"' # Split everything
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@tag split.config.defaults
---@brief [[
---The following gives the full default configuration for `split.nvim`:
--->lua
---    {
---        keymaps = {
---            ["gs"]  = {
---                pattern = ",",
---                operator_pending = true,
---                interactive = false,
---            },
---            ["gss"] = {
---                pattern = ",",
---                operator_pending = false,
---                interactive = false,
---            },
---            ["gS"]  = {
---                pattern = ",",
---                operator_pending = true,
---                interactive = true,
---            },
---            ["gSS"] = {
---                pattern = ",",
---                operator_pending = false,
---                interactive = true,
---            },
---        },
---        interactive_options = {
---            [","] = ",",
---            [";"] = ";",
---            [" "] = "%s+",
---            ["+"] = " [+-/%] ",
---            ["<"] = {
---                pattern = "[<>=]=?",,
---                break_placement = "before_pattern"
---            },
---            ["."] = {
---                pattern = "[%.?!]%s+",
---                unsplitter = " ",
---                smart_ignore = "code",
---                quote_characters = {},
---                brace_characters = {}
---            }
---        },
---        keymap_defaults = {
---            pattern = ",",
---            break_placement = "after_pattern",
---            operator_pending = false,
---            transform_segments = require("split.utils").make_transformer({
---                trim_l = { "before_pattern", "on_pattern", "after_pattern" },
---                trim_r = { "before_pattern", "on_pattern", "after_pattern" },
---            }),
---            transform_separators = require("split.utils").make_transformer({
---                trim_l = { "before_pattern" },
---                trim_r = { "before_pattern", "on_pattern", "after_pattern" },
---                pad_r = { "before_pattern" }
---            }),
---            indenter = "equalprg",
---            unsplitter = nil,
---            interactive = false,
---            smart_ignore = "comments",
---            quote_characters = { left = { "'", '"', "`" }, right = { "'", '"', "`" } },
---            brace_characters = { left = { "(", "{", "[" }, right = { ")", "}", "]" } }
---        },
---    }
---<
---
---See also |split.utils.make_transformer|.
---@brief ]]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@class SplitConfig
---@field keymaps table<string, SplitOpts>
---@field interactive_options table<string, string | SplitOpts>
---@field keymap_defaults SplitOpts
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
local Config = {
    state = {},
    ---@type SplitConfig
    config = {
        keymaps = {
            ["gs"]  = {
                pattern = ",",
                operator_pending = true,
                interactive = false,
            },
            ["gss"] = {
                pattern = ",",
                operator_pending = false,
                interactive = false,
            },
            ["gS"]  = {
                pattern = ",",
                operator_pending = true,
                interactive = true,
            },
            ["gSS"] = {
                pattern = ",",
                operator_pending = false,
                interactive = true,
            },
        },
        interactive_options = {
            [","] = ",",
            [";"] = ";",
            [" "] = "%s+",
            ["+"] = " [+-/%] ",
            ["<"] = {
                pattern = "[<>=]=?",
                break_placement = "before_pattern"
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
            break_placement = "after_pattern",
            operator_pending = false,
            transform_segments = utils.make_transformer({
                trim_l = { "before_pattern", "on_pattern", "after_pattern" },
                trim_r = { "before_pattern", "on_pattern", "after_pattern" },
            }),
            transform_separators = utils.make_transformer({
                trim_l = { "before_pattern" },
                trim_r = { "before_pattern", "on_pattern", "after_pattern" },
                pad_r = { "before_pattern" }
            }),
            indenter = "equalprg",
            unsplitter = nil,
            interactive = false,
            smart_ignore = "comments",
            quote_characters = { left = { "'", '"', "`" }, right = { "'", '"', "`" } },
            brace_characters = { left = { "(", "{", "[" }, right = { ")", "}", "]" } }
        },
    },
}

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
