local utils = require("split.utils")
local config = require("split.config"):get()

local M = {}

function M.get_opts_interactive(opts)
    local flatten = function(x) return vim.iter(x):flatten():totable() end

    local key_options = vim.tbl_extend("force", config.pattern_aliases, {
        [vim.keycode("<C-x>")] = "custom_pattern",
        [vim.keycode("<CR>")] = "cycle_break_placement"
    })

    local prompt_parts = {
        { { "Split Text", "ModeMsg" } },
        { { "", "Normal" } },
        { { "", "Normal" } },
        { { ": ", "Normal" } }
    }

    local selection = M.user_input_char(flatten(prompt_parts), key_options)

    local break_placement_opts = {
        after_separator  = "before_separator",
        before_separator = "on_separator",
        on_separator     = "after_separator",
    }
    local cycle_break_placement = function(x) return break_placement_opts[x] end

    while true do
        if selection == "cycle_break_placement" then
            opts.break_placement = cycle_break_placement(opts.break_placement)
            prompt_parts[2] = {
                { " ", "Normal" },
                { "[", "TabLine" },
                { opts.break_placement, "Normal" },
                { "]", "TabLine" },
            }
            selection = M.user_input_char(flatten(prompt_parts), key_options)

        elseif selection == "custom_pattern" then
            opts.pattern = M.user_input_text("Enter split pattern: ")
            break

        else
            opts.pattern = selection
            break
        end
    end

    if not selection then
        return nil
    end


    return opts
end

M.namespace = {
    user_input = vim.api.nvim_create_namespace("split_user_input")
}

--- Prompt for user input
---
---@param prompt string The prompt to show the user
---@param placeholder string? Placeholder text
---@param special_keys table? A table of special keys which can be used to
---  exit the user input. E.g. `special_keys={ ["foofy"] = "<C-x>" }` will
---  result in the function returning `"foofy"` if the user presses `<C-x>` 
---  at any point while the dialogue is shown. `"escape"` is always included.
---
---@return string value Will either be the text entered by the user or the name
---  of one of the `special_keys`.
---@return string type Will either be `"special_key"` or `"text"`
function M.user_input_text(prompt, placeholder, special_keys)
    local on_key = vim.on_key or vim.register_keystroke_callback
    special_keys = special_keys or {}
    special_keys["escape"] = "<Esc>"
    local selected_special_key = nil

    -- Translate vim key notation to decimal keycodes, e.g. <Esc> to \27, etc
    for k, v in pairs(special_keys) do
        special_keys[k] = vim.keycode(v)
    end

    -- While the user is entering text, on each keystroke we want to check 
    -- whether they've input one of the special characters. If so, we need
    -- to exit the user input.
    on_key(
        function(key)
            for keyname, keycode in pairs(special_keys) do
                if key == keycode then
                    selected_special_key = keyname
                    if keyname ~= "escape" then
                        -- Simulate hitting 'enter' and ending the user input
                        vim.fn.feedkeys("\r", "L")
                    end
                    return
                end
            end
        end,
        M.namespace.user_input
    )

    vim.cmd('echohl Question')

    -- pcall used because vim.fn.input() might fail, e.g. if the user hits 
    -- <C-c>. In such cases, we treat it as if they hit <Esc>.
    local input_obtained, input = pcall(vim.fn.input, {
        prompt = prompt,
        default = placeholder or ''
    })

    vim.cmd('echohl None | redraw')

    -- Stop watching keypresses
    on_key(nil, M.namespace.user_input)

    if selected_special_key or not input_obtained then
        return selected_special_key or "escape", "special_key"
    end

    return input, "text"
end

---@param prompt table The prompt to show ahead of the input.
---@param expected table Allows the user to specify special keys and their 
---  meanings, e.g. passing `{ ["a"] = "foo", [vim.keycode("<BS>")] = "bar" }`
---  would result in only `"a"` and `"<BS>"` being valid input characters.
---@return string | nil # One of the values from `table`, or `nil` if the user 
---  cancels the operation.
function M.user_input_char(prompt, expected)
    local placeholder    = { "_", "Question" }
    local escape_keycode = "\27"
    local echo           = function(x) vim.api.nvim_echo(x, false, {}) end
    local invalid        = function(k)
        local template   = string.find(k, "^[%a%d%p%s]$") and ' (Invalid key "%s") ' or ""
        return { template:format(k) }
    end

    vim.cmd([[echo '' | redraw]])
    echo(utils.tbl_concat(prompt, { placeholder }))
    local success, char = pcall(vim.fn.getcharstr)

    while success and not expected[char] do
        if char == escape_keycode then
            return nil
        end
        vim.cmd([[redraw]])
        echo(utils.tbl_concat(prompt, { invalid(char), placeholder }))
        success, char = pcall(vim.fn.getcharstr)
    end

    if not success then
        vim.cmd([[echo '' | redraw]])
        return nil
    end

    return expected[char]
end

return M
