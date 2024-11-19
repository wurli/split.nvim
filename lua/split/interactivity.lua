local utils = require("split.utils")
local config = require("split.config"):get()

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@mod split.interactivity Interactivity
---@brief [[
---When split.nvim is called in interactive mode, the user will be
---prompted to enter options to perform the split. In this mode,
---special keys are used to enter non-standard options:
---
---* <C-x> can be used to enter a non-standard split pattern
---* <CR> can be used to cycle through the options for where
---  linebreaks are placed relative to the split pattern
---* <C-s> can be used to toggle whether the original line
---  breaks should be retained in addition to the new ones.
---
---To execute the split in interactive mode, use one of the options
---set during configuration - see |split.config.SplitConfigInput|.
---E.g. by default you can use `.` to split lines by sentence, `;` to split
---lines by semicolon, etc.
---@brief ]]
---@tag split.interactivity.default_aliases
---@brief [[
---When using split.nvim in interactive mode, the default pattern aliases
---are as follows:
---
---* `","`: Split on commas.
---
---* `";"`: Split on semicolons.
---
---* `" "`: Split on one or more whitespace characters.
---
---* `"+"`: Split on `+`, `-`, `/`, and `%`, provided these are
---       surrounded by one or more whitespace characters.
---
---* `"<"`: Split by `<`, `<=`, `==`, `>`, or `>=`.
---
---* `"."`: Split text so that each sentence occupies a single line.
---@brief ]]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

local M = {}

---@private
---Prompt the user for split options
---
---@param opts? SplitOpts
---@return SplitOpts | nil
---@see split.config.SplitOpts
function M.get_opts_interactive(opts)
    opts = opts or config.keymap_defaults

    local key_options = vim.tbl_extend("force", config.interactive_options, {
        [vim.keycode("<C-x>")] = "custom_pattern",
        [vim.keycode("<CR>")] = "cycle_break_placement",
        [vim.keycode("<C-s>")] = "toggle_unsplitter"
    })

    local prompt = function(parts)
        local out = M.user_input_char(
            vim.iter(parts):flatten():totable(),
            key_options
        )
        if out == "cancel" then return end
        return out
    end

    local prompt_parts = {
        { { "Split Text", "ModeMsg" } },
        -- Placeholder for custom pattern text
        { { "", "Normal" } },
        -- Placeholder for break placement text
        { { "", "Normal" } },
        -- Placeholder for unsplitter text
        { { "", "Normal" } },
        { { ": ", "Normal" } }
    }

    local selection = prompt(prompt_parts)

    local break_placement_opts = {
        after_pattern  = "before_pattern",
        before_pattern = "on_pattern",
        on_pattern     = "after_pattern",
    }

    local cycle_break_placement = function(x)
        return break_placement_opts[x]
    end

    ---@type SplitOpts
    local opts2 = {}

    while selection do
        if selection == "cycle_break_placement" then
            opts2.break_placement = cycle_break_placement(
                opts2.break_placement
                    or (type(opts.break_placement) == "string" and opts.break_placement)
                    or "after_pattern"
            )
            prompt_parts[2] = {
                { " ", "Normal" },
                { "[", "TabLine" },
                { ('break_placement="%s"'):format(opts2.break_placement), "Normal" },
                { "]", "TabLine" },
            }
            selection = prompt(prompt_parts)

        elseif selection == "custom_pattern" then
            opts2.pattern = M.user_input_text("Enter split pattern: ")
            break

        elseif selection == "toggle_unsplitter" then
            local input_type
            opts2.unsplitter, input_type = M.user_input_text(
                "Enter unsplitter text: ",
                opts2.unsplitter or opts.unsplitter or ""
            )
            if input_type == "special_key" then
                opts2.unsplitter = opts.unsplitter
                prompt_parts[3] = { { "", "Normal" } }
            else
                prompt_parts[3] = {
                    { " ", "Normal" },
                    { "[", "TabLine" },
                    { ('unsplitter="%s"'):format(opts2.unsplitter), "Normal" },
                    { "]", "TabLine" },
                }
            end
            selection = prompt(prompt_parts)

        elseif type(selection) == "string" then
            opts2.pattern = selection
            break

        elseif type(selection) == "table" then
            for k, v in pairs(selection) do
                opts[k] = v
            end
            break
        end

    end

    if not selection then
        return nil
    end

    opts2 = vim.tbl_deep_extend("keep", opts2, opts)

    return opts2
end

M.namespace = {
    user_input = vim.api.nvim_create_namespace("split_user_input")
}

---@private
---Prompt for user input
---
---This function ended up more feature-rich than it needs to be, but I'm not 
---going to change it because I might need those features again one day.
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

---@private
---@param prompt table The prompt to show ahead of the input.
---@param expected table Allows the user to specify special keys and their 
---  meanings, e.g. passing `{ ["a"] = "foo", [vim.keycode("<BS>")] = "bar" }`
---  would result in only `"a"` and `"<BS>"` being valid input characters.
---@return string | nil # One of the values from `table`, or `nil` if the user 
---  cancels the operation.
function M.user_input_char(prompt, expected)
    local placeholder    = { "_", "Question" }
    local escape_keycode = "\27"

    local echo = function(x)
        vim.api.nvim_echo(x, false, {})
    end

    local invalid = function(k)
        local template = k:find("^[%a%d%p%s]$") and ' (Invalid key "%s") ' or ""
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
