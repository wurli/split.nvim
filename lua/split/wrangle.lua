local M = {}

local utils = require("split.utils")

function M.split_text(text, sep, keep_sep)
    if keep_sep == nil then keep_sep = true end

    local unsplittable_runs = M.get_unsplittable_runs(text)

end

-- ---@param text string The text to split
-- ---@param sep string The pattern to split on
-- ---@param keep_sep boolean Whether or not to remove the separator from the 
-- ---  output text
-- ---@return table 
-- function M.split_text(text, sep, keep_sep)
--     if keep_sep == nil then keep_sep = true end
--
--     -- Detect and (temporarily) remove any indentation
--     local _, indent_end, indent = text:find("^(%s*)")
--     indent = indent or ""
--     text = text:sub(indent_end + 1)
--
--     -- Replace separator with line breaks
--     if keep_sep then
--         text = string.gsub(text, "(" .. sep .. ")", "%1\n")
--     else
--         text = string.gsub(text, "(" .. sep .. ")", "\n")
--     end
--
--     -- Perform the split
--     local text_split = vim.fn.split(text, "\n", false)
--
--     for i, l in ipairs(text_split) do
--         l = string.gsub(l, "^%s*", "") -- Remove leading whitespace
--         l = string.gsub(l, "%s*$", "") -- Remove trailing whitespace
--         text_split[i] = indent .. l    -- (Re)apply any indentation
--     end
--
--     return text_split
-- end

function M.get_unsplittable_runs(text)
    local quote_runs = M.get_enclosed_runs(text,
        { "'", '"', "`" },
        { "'", '"', "`" }
    )
    local brace_runs = M.get_enclosed_runs(text,
        { "(", "{", "[" },
        { ")", "}", "]" }
    )

    if #quote_runs == 0 then return utils.merge_ranges(brace_runs) end
    if #brace_runs == 0 then return utils.merge_ranges(quote_runs) end

    local all_runs = {}

    for _, brace_run in pairs(brace_runs) do
        for _, quote_run in pairs(quote_runs) do
            local brace_is_within_quotes = false
            for _, brace_pos in pairs(brace_run) do
                if quote_run[1] < brace_pos and brace_pos < quote_run[2] then
                    brace_is_within_quotes = true
                    break
                end
            end
            if not brace_is_within_quotes then table.insert(all_runs, brace_run) end
        end
    end

    for _, run in pairs(quote_runs) do table.insert(all_runs, run) end

    return utils.merge_ranges(all_runs)
end


---@param text string 
---@param left_braces table Left brace characters
---@param right_braces table Right brace characters
---@return table table
function M.get_enclosed_runs(text, left_braces, right_braces)
    local brace_chars = {}
    local brace_indices = {}

    for i = 1, #text do
        local char = text:sub(i, i)
        if vim.list_contains(left_braces, char) or vim.list_contains(right_braces, char) then
            table.insert(brace_chars, char)
            table.insert(brace_indices, i)
        end
    end

    local brace_pairs = {}

    while true do
        if #brace_chars < 2 then break end

        local has_brace_pair = false

        for i = 1, #brace_chars - 1 do
            local left = brace_chars[i]
            local right = brace_chars[i + 1]

            if utils.match(left, left_braces) == utils.match(right, right_braces) then
                has_brace_pair = true
                table.insert(brace_pairs, {
                    brace_indices[i],
                    brace_indices[i + 1]
                })
                table.remove(brace_chars, i)
                table.remove(brace_chars, i)
                table.remove(brace_indices, i)
                table.remove(brace_indices, i)
                break
            end
        end

        if not has_brace_pair then return brace_pairs end
    end

    return brace_pairs
end

-- Split a line into mutliple lines based on a delimiter
-- function M.split_current_line(sep, keep_sep)
--     if keep_sep == nil then keep_sep = true end
--     local line = vim.api.nvim_get_current_line()
--
--     -- Detect and (temporarily) remove any indentation
--     local _, indent_end, indent = line:find("^(%s*)")
--     indent = indent or ""
--     line = line:sub(indent_end + 1)
--
--     -- Replace separator with line breaks
--     if keep_sep then
--         line = string.gsub(line, "(" .. sep .. ")", "%1\n")
--     else
--         line = string.gsub(line, "(" .. sep .. ")", "\n")
--     end
--
--     -- Perform the split
--     local line_split = vim.fn.split(line, "\n", false)
--
--     for i, l in ipairs(line_split) do
--         l = string.gsub(l, "^%s*", "") -- Remove leading whitespace
--         l = string.gsub(l, "%s*$", "") -- Remove trailing whitespace
--         line_split[i] = indent .. l    -- (Re)apply any indentation
--     end
--
--     -- Replace lines in the buffer
--     local line_no = vim.api.nvim_win_get_cursor(0)[1] - 1
--     vim.api.nvim_buf_set_lines(0, line_no, line_no + 1, true, line_split)
-- end
function M.split_ask()
    local esc_keycode = "\27"
    local keep_sep = true
    local pattern = ""
    local keep_prompting = true
    local was_cancelled = false

    while pattern == "" and keep_prompting do
        -- Detect if user enters Esc (in which case pattern will be "")
        vim.on_key(function(k) was_cancelled = k == esc_keycode end)

        if keep_sep then
            keep_prompting, pattern = pcall(vim.fn.input, "Enter a split pattern (keeping separator): ")
        else
            keep_prompting, pattern = pcall(vim.fn.input, "Enter a split pattern (removing separator): ")
        end

        if pattern == "" then keep_sep = not keep_sep end
        if not keep_prompting or was_cancelled then return end
    end

    M.split_current_line(pattern, keep_sep)
end

return M
