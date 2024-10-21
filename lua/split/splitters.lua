local utils = require("split.utils")
local config = require("split.config"):get()
local interactivity =  require("split.interactivity")

local M = {}

function M.split_prompt(type, opts)

    M.split_current_line(type, opts)
end

function M.split(type, opts)
    type = type or "current_line"
    local linewise = type == "current_line" or type == "line"
    opts = utils.tbl_copy(opts)

    if opts.interactive then
        opts = interactivity.get_opts_interactive(opts)
        if not opts then
            return nil
        end
    end

    ---------------------------
    -- Get the text to split --
    ---------------------------
    local range, text
    if type == "current_line" then
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        range = { row, 0, row, -1 }
        text = vim.api.nvim_get_current_line()
    else
        range = utils.get_marks_range("[", "]")
        text = utils.get_range_text(range, linewise)
    end

    -----------------------
    -- Perform the split --
    -----------------------
    local text_split = M.split_text(text, opts.pattern)

    -----------------------------------------------
    -- Apply any transformations to split pieces --
    -----------------------------------------------
    local text_transformed = M.transform(
        text_split,
        opts.transform_segments,
        opts.transform_separators
    )

    ----------------------------
    -- Recombine split pieces --
    ----------------------------
    local text_recombined = M.recombine(text_transformed, opts.break_placement)

    ------------------------------------------------------------
    -- Insert leading/trailing lines if split is not linewise --
    ------------------------------------------------------------
    if not linewise then
        table.insert(text_recombined, 1, "")
        table.insert(text_recombined, "")
    end

    -------------------------
    -- Insert the new text --
    -------------------------
    utils.set_range_text(range, text_recombined, linewise)

    -----------------------
    -- Apply indentation --
    -----------------------
    vim.api.nvim_cmd({ cmd = 'normal', args = { "`[=`]" }, mods = { silent = true }  }, {})
end

function M.recombine(text_split, retain_separator)
    local lines = { "" }

    for _, l in pairs(text_split) do
        lines[#lines] = lines[#lines] .. l[1]

        if retain_separator == "after_separator" then
            lines[#lines] = lines[#lines] .. l[2]
            table.insert(lines, "")

        elseif retain_separator == "before_separator" then
            table.insert(lines, l[2])

        elseif retain_separator == "on_separator" then
            table.insert(lines, "")

        end
    end

    if lines[1]      == "" then table.remove(lines, 1)      end
    if lines[#lines] == "" then table.remove(lines, #lines) end

    -- Some elements may still contain newline characters, so need to break
    -- these into multiple elements where this is the case.
    local out = {}
    for _, l in pairs(lines) do
        local split = vim.split(l, "\n", { plain = true, trimempty = false })
        for _, s in pairs(split) do
            table.insert(out, s)
        end
    end

    return out
end

function M.transform(text_split, transform_segments, transform_separators)
    if transform_segments == nil and transform_separators == nil then
        return text_split
    end

    return vim.tbl_map(
        function(segment_and_separator)
            if transform_segments ~= nil then
                segment_and_separator[1] = transform_segments(segment_and_separator[1])
            end
            if transform_separators ~= nil then
                segment_and_separator[2] = transform_separators(segment_and_separator[2])
            end
            return segment_and_separator
        end,
        text_split
    )
end

function M.split_text(text, pattern)

    pattern = pattern or ",%s*"

    local sep_positions = utils.gfind(text, pattern, false)

    if #sep_positions == 0 then
        return { { text, "" } }
    end

    local unsplittable_runs = M.get_unsplittable_runs(text)

    -- Ignore any separators which fall within brackets, quotes, etc
    sep_positions = vim.tbl_filter(
        function(m)
            for _, run in pairs(unsplittable_runs) do
                if run[1] <= m[1] and m[1] <= run[2] then return false end
                if run[1] <= m[2] and m[2] <= run[2] then return false end
            end
            return true
        end,
        sep_positions
    )

    -- `splits` Will be a table of tables. Each subtable will have the
    -- form { a, b, c, d }, where
    -- a: The start position of a run of characters in `text` which does not
    --    match `pattern`
    -- b: The end position of the run started by `a`
    -- c: The start position of a run of characters in `text` which matches
    --    `pattern`. Will be equal to `b + 1`
    -- d: The end position of the run started by `c`
    local splits = { { 1 } }
    for _, pos in pairs(sep_positions) do
        table.insert(splits[#splits], pos[1] - 1) -- End of the section before the separator
        table.insert(splits[#splits], pos[1])     -- Start of the separator
        if pos[2] == #text then break end
        table.insert(splits[#splits], pos[2])     -- End of the separator
        table.insert(splits, { pos[2] + 1 })      -- Start of the section after the separator
    end
    table.insert(splits[#splits], #text)          -- End of the last section, separator or otherwise

    local out = {}
    for _, m in pairs(splits) do
        local line_start = m[1]
        local line_stop  = m[2]
        local sep_start  = m[3] or (line_stop + 1)
        local sep_stop   = m[4] or (line_stop + 1)

        local line     = string.sub(text, line_start, line_stop)
        local line_sep = string.sub(text, sep_start, sep_stop)

        table.insert(out, { line, line_sep })
    end

    return out
end

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
    local braces = {}
    local brace_indices = {}

    for i = 1, #text do
        local char = text:sub(i, i)
        if vim.list_contains(left_braces, char) or vim.list_contains(right_braces, char) then
            table.insert(braces, char)
            table.insert(brace_indices, i)
        end
    end

    local brace_pairs = {}

    while true do
        if #braces < 2 then break end

        local has_brace_pair = false

        for i = 1, #braces - 1 do
            local left_brace_type = utils.match(braces[i], left_braces)
            local right_brace_type = utils.match(braces[i + 1], right_braces)

            if left_brace_type ~= -1 and right_brace_type ~= -1 and left_brace_type == right_brace_type then
                has_brace_pair = true
                table.insert(brace_pairs, {
                    brace_indices[i],
                    brace_indices[i + 1]
                })
                table.remove(braces, i)
                table.remove(braces, i)
                table.remove(brace_indices, i)
                table.remove(brace_indices, i)
                break
            end
        end

        if not has_brace_pair then return brace_pairs end
    end

    return brace_pairs
end

return M
