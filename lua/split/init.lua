--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@brief [[
---*split-nvim-txt*
---
---                ___       __                                         
---               /\_ \   __/\ \__                    __                
---     ____  ____\//\ \ /\_\ \ ,_\      ___   __  __/\_\    ___ ___    
---    /',__\/\ '__ \ \ \\/\ \ \ \/    /' _  \/\ \/\ \/\ \ /' __  __ \  
---   /\__,  \ \ \L\ \_\ \\ \ \ \ \_ __/\ \/\ \ \ \_/ \ \ \/\ \/\ \/\ \ 
---   \/\____/\ \ ,__/\____\ \_\ \__/\_\ \_\ \_\ \___/ \ \_\ \_\ \_\ \_\
---    \/___/  \ \ \/\/____/\/_/\/__\/_/\/_/\/_/\/__/   \/_/\/_/\/_/\/_/
---             \ \_\                                                   
---              \/_/                                                   
---
---       ·  A simple, powerful Neovim plugin for adding linebreaks ·    
---
---@brief ]]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@toc split.contents
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@mod split-nvim Introduction
---@brief [[
---split.nvim is a Neovim plugin for inserting linebreaks when lines of code
---start to get too long. Usually I use it for stuff like this:
---
--->lua
---    -- Initial text:
---    local foo = { 123, "4,5,6", { 7, 8, 9 } }
---
---    -- Text after splitting (I use `gs` to enter operator-pending mode,
---    -- then `iB` to split within the outermost curly braces)
---    local foo = {
---        123,
---        "4,5,6",
---        { 7, 8, 9 }
---    }
---<
---@brief ]]
---@tag split.features
---@brief [[
---*  Interactivity: split.nvim supports an interactive mode which allows
---   you to use shortcuts for complex split patterns. For example, you might
---   press `<` in interactive mode to split text by any of `<`, `<=`, `>`,
---   `>=`, and `==`. See |split.interactivity| for more information.
---
---*  Comments: split.nvim is aware of comments and supports tree-sitter.
---   If you try to split a region with both commented and uncommented code,
---   only the uncommented code will be affected.
---
---*  braces/quotes: split.nvim is aware of braces and quotes, and
---   generally will not insert linebreaks in these regions unless you want it
---   to. If you want to break up text within a set of quotes or brackets, use
---   one of vim's built-in text objects, e.g. `gsib` to split within `()`,
---   `gsiB` to split within `{}`, `gsi"` to split within `""`, etc.
---
---*  Indentation: split.nvim will by default reapply indentation after
---   splitting text. By default this is done using the default indenter (see
---   |=|), but this is configurable :)
---@brief ]]
---@tag split.setup
---@brief [[
---To use split.nvim you need to first call `setup()` to create the default
---mappings: `gs` to split by `,` in operator-pending mode, and `gS` to split
---in interactive mode, which allows you to choose from a wider variety of
---split patterns. You can easily change the default behaviour by passing a
---table of options to `setup()`. See |split.config.SplitConfigInput| for
---the full set of configuration options.
---@brief ]]
---@tag split.operator_pending_mode
---@brief [[
---split.nvim differs from most other plugins in that it is designed to be
---primarily used in |operator-pending| mode. E.g. if your mappings are
---`gs`/`gss` and you want to split arguments within some code like `do_stuff(a
---= 1, b = 2, c = 3)`, you can first hit `gs` to enter operator-pending mode,
---then the text-object `ib` (think 'in braces') to apply the split within the
---pair of parentheses `()`. This is particularly handy because this will work
---even if your cursor is before the parentheses themselves! ✨
---
---You can also use `gss` to split an entire line, but since split.nvim will
---by default not insert linebreaks within parentheses or quotes which lie within
---the selected text, this will not do the same thing as `gsib`.
---
---To learn more about operator-pending mode, see |operator-pending| and
---|text-objects|.
---@brief ]]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

local M = {}

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---Configure the behaviour of split.nvim
---@param config? SplitConfigInput User configuration
---@see split.config
---@usage [[
----- Use the default configuration
---require("split").setup()
---
----- Some custom config, in this case a super simple setup that splits 
----- on commas or semicolons and doesn't use operator-pending mode.
---require("split").setup({
---    keymaps = {
---        ["<leader>s"] = {
---            pattern = "[,;]",
---            operator_pending = false
---        }
---    }
---})
---@usage ]]
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
                    { expr = true, desc = "Split text on " .. opts.pattern .. " (operator-pending)"}
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

---Create a mapping using the user's config
---
---Unfortunately you can't pass inputs to a lua function
---when it gets executed by an operator-pending mapping.
---Instead, we need to create a specialised function when
---the mapping is created.
---@private
---@param x string One of the keymaps set by the user
---@return fun(type: string) # A wrapper for `splitters.split`
function M.user_mapping(x)
    local opts = require("split.config"):get().keymaps[x]
    return function(type)
        require("split.algorithm").split_in_buffer(type, opts)
    end
end


return M
