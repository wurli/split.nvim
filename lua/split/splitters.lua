local utils         = require("split.utils")
local interactivity = require("split.interactivity")
local comment       = require("split.comment")

local M = {}

function M.split(type, opts)
    type           = type or "current_line"
    -- 'block' selections not implemented (yet) so fall back to "line"
    type           = type == "block" and "line" or type
    opts           = utils.tbl_copy(opts)
    local linewise = type == "current_line" or type == "line"

    if opts.interactive then
        opts = interactivity.get_opts_interactive(opts)
        if not opts then
            return nil
        end
    end

    ---------------------------
    -- Get the text to split --
    ---------------------------
    local range, lines
    if type == "current_line" then
        local row = vim.api.nvim_win_get_cursor(0)[1] - 1
        range = { row, 0, row, -1 }
        lines = { vim.api.nvim_get_current_line() }
    else
        range = utils.get_marks_range("[", "]")
        lines = utils.get_range_text(range, linewise)
    end

    if opts.unsplitter then
        lines = { table.concat(lines, opts.unsplitter) }
    end

    -----------------------
    -- Perform the split --
    -----------------------
    local lines_split = M.split_lines(lines, opts.pattern)

    -----------------------------------------------
    -- Apply any transformations to split pieces --
    -----------------------------------------------
    local parts_transformed = M.transform(
        lines_split,
        opts.transform_segments,
        opts.transform_separators
    )

    ----------------------------
    -- Recombine split pieces --
    ----------------------------
    local lines_recombined = M.recombine(parts_transformed, opts.break_placement)

    ------------------------------------------------------------
    -- Insert leading/trailing lines if split is not linewise --
    ------------------------------------------------------------
    if not linewise then
        table.insert(lines_recombined[1], 1, "")
        table.insert(lines_recombined[#lines_recombined], "")
    end

    -----------------------------------
    -- Apply commenting to new lines --
    -----------------------------------
    -- First need to make sure the first line contains the whole text. This 
    -- is (usually) how we determine whether or not the line is a comment
    lines[1] = vim.api.nvim_buf_get_lines(0, range[1], range[1] + 1, true)[1]
    local lines_commented = M.comment_lines(lines_recombined, lines, range[1])

    -------------------------
    -- Insert the new text --
    -------------------------
    local lines_flat = vim.iter(lines_commented):flatten(1):totable()
    utils.set_range_text(range, lines_flat, linewise)


    -----------------------
    -- Apply indentation --
    -----------------------
    if opts.indenter == nil then
        return
    end

    if opts.indenter then
        opts.indenter("[", "]")
    end
end

function M.comment_lines(new_lines, original_lines, first_lnum)
    for lnum, lines in ipairs(new_lines) do
        local comment_parts      = comment.get_comment_parts({ first_lnum + lnum, 0 })
        local indent, is_comment = comment.get_lines_info(original_lines[lnum], comment_parts)

        if is_comment then
            local make_comment = comment.make_comment_function(comment_parts, "")
            for i, line in ipairs(lines) do
                if i == 1 then
                    if line ~= "" then
                        lines[i] = indent .. line
                    end
                else
                    lines[i] = indent .. make_comment(line)
                end
            end
        end
    end

    return new_lines
end


function M.recombine(text_split, break_placement)
    local out = {}

    for _, line_parts in pairs(text_split) do
        local lines = { }

        for lnum, parts in pairs(line_parts) do
            local segment = parts[1]
            local separator = parts[2]

            lines[lnum] = (lines[lnum] or "") .. segment

            if break_placement == "after_separator" then
                lines[lnum] = (lines[lnum] or "") .. separator

            elseif break_placement == "before_separator" then
                lines[lnum + 1] = separator
            end
        end

        table.insert(out, lines)
    end

    return out
end

function M.transform(text_split, transform_segments, transform_separators)
    if transform_segments == nil and transform_separators == nil then
        return text_split
    end

    local apply_transformations = function(segment_and_separator)
        if transform_segments ~= nil then
            segment_and_separator[1] = transform_segments(segment_and_separator[1])
        end
        if transform_separators ~= nil then
            segment_and_separator[2] = transform_separators(segment_and_separator[2])
        end
        return segment_and_separator
    end

    return vim.tbl_map(
        function(line_parts) return vim.tbl_map(apply_transformations, line_parts) end,
        text_split
    )
end

function M.split_lines(lines, pattern)

    pattern = pattern or ",%s*"

    local sep_positions = vim.tbl_map(
        function(line) return utils.gfind(line, pattern, false) end,
        lines
    )

    local any_matches = vim.iter(sep_positions):any(function(x) return #x > 0 end)

    if not any_matches then
        return vim.tbl_map(function(l) return { { l, "" } } end, lines)
    end

    local unsplittable_chunks = M.get_unsplittable_runs(lines)

    local should_split = function(split_pos)
        for _, chunk in pairs(unsplittable_chunks) do
            if utils.position_within(split_pos[1], chunk[1], chunk[2]) then return false end
            if utils.position_within(split_pos[2], chunk[1], chunk[2]) then return false end
        end
        return true
    end

    -- Ignore any separators which fall within brackets, quotes, etc
    sep_positions = vim.iter(sep_positions):
        enumerate():
        map(function(lnum, cnums)
            local out = {}
            for _, cnum_pair in pairs(cnums) do
                if should_split({ { lnum, cnum_pair[1] }, { lnum, cnum_pair[2] } }) then
                    table.insert(out, cnum_pair)
                end
            end
            return out
        end):
        totable()

    -- `segments` will be a table of tables. Each subtable will have the
    -- form { a, b, c, d }, where
    -- a: The start position of a run of characters in `text` which does not
    --    match `pattern`
    -- b: The end position of the run started by `a`
    -- c: The start position of a run of characters in `text` which matches
    --    `pattern`. Will be equal to `b + 1`
    -- d: The end position of the run started by `c`
    local out = {}
    for lnum, cnums in ipairs(sep_positions) do
        local line = lines[lnum]
        local segments = { { 1 } }

        for _, pos in pairs(cnums) do
            table.insert(segments[#segments], pos[1] - 1) -- End of the segment before the separator
            table.insert(segments[#segments], pos[1])     -- Start of the separator
            if pos[2] == #line then break end
            table.insert(segments[#segments], pos[2])     -- End of the separator
            table.insert(segments, { pos[2] + 1 })        -- Start of the segment after the separator
        end
        table.insert(segments[#segments], #line)          -- End of the last segment or separator

        local segment_sep_pairs = {}
        for _, m in pairs(segments) do
            local segment_start = m[1]
            local segment_stop  = m[2]
            local sep_start     = m[3] or (segment_stop + 1)
            local sep_stop      = m[4] or (segment_stop + 1)

            local segment = string.sub(line, segment_start, segment_stop)
            local sep     = string.sub(line, sep_start,     sep_stop)

            table.insert(segment_sep_pairs, { segment, sep })
        end

        table.insert(out, segment_sep_pairs)
    end

    -- return vim.iter(out):flatten(1):totable()
    return out
end

function M.get_unsplittable_runs(lines, quote_chars, brace_chars, across_lines)
    quote_chars = quote_chars or {
        { "'", '"', "`" },
        { "'", '"', "`" }
    }
    brace_chars = brace_chars or {
        { "(", "{", "[" },
        { ")", "}", "]" }
    }
    local quote_runs = M.get_enclosed_runs(lines, quote_chars[1], quote_chars[2], across_lines)
    local brace_runs = M.get_enclosed_runs(lines, brace_chars[1], brace_chars[2], across_lines)

    if #quote_runs == 0 then return utils.merge_ranges(brace_runs) end
    if #brace_runs == 0 then return utils.merge_ranges(quote_runs) end

    local all_runs = {}

    for _, braces in pairs(brace_runs) do
        for _, quotes in pairs(quote_runs) do
            local brace_is_within_quotes = false
            for _, brace_pos in pairs(braces) do
                if utils.position_within(brace_pos, quotes[1], quotes[2], false) then
                    brace_is_within_quotes = true
                    break
                end
            end
            if not brace_is_within_quotes then table.insert(all_runs, braces) end
        end
    end

    for _, quotes in pairs(quote_runs) do table.insert(all_runs, quotes) end

    return utils.merge_ranges(all_runs)
end


---@param lines table A table of lines 
---@param left_braces table Left brace characters
---@param right_braces table Right brace characters
---@return table table
function M.get_enclosed_runs(lines, left_braces, right_braces, across_lines)
    if across_lines == nil then across_lines = true end

    if not across_lines then
        local out = {}
        for lnum, line in ipairs(lines) do
            local runs = M.get_enclosed_runs({ [lnum] = line }, left_braces, right_braces, true)
            for _, r in pairs(runs) do table.insert(out, r) end
        end
        return out
    end

    local braces = {}
    local brace_positions = {}

    for lnum, line in pairs(lines) do
        for cnum = 1, #line do
            local char = line:sub(cnum, cnum)
            if vim.list_contains(left_braces, char) or vim.list_contains(right_braces, char) then
                table.insert(braces, char)
                table.insert(brace_positions, { lnum, cnum })
            end
        end
    end

    local brace_pairs = {}

    -- Algorithm basically does this after removing everything except braces:
    -- Step 1: "({}[()])[)]"
    -- Step 2: "(  [  ])[)]"
    -- Step 2: "(      )[)]"
    -- Step 3: "(      )[)]"
    -- Step 4: "        [)]"
    --           ^^^^^^-- Returns this whole chunk of 'enclosed' text
    while true do
        if #braces < 2 then break end

        local has_brace_pair = false

        for i = 1, #braces - 1 do
            local left_brace_type = utils.match(braces[i], left_braces)
            local right_brace_type = utils.match(braces[i + 1], right_braces)

            if left_brace_type ~= -1 and right_brace_type ~= -1 and left_brace_type == right_brace_type then
                has_brace_pair = true
                table.insert(brace_pairs, {
                    brace_positions[i],
                    brace_positions[i + 1]
                })
                table.remove(braces, i)
                table.remove(braces, i)
                table.remove(brace_positions, i)
                table.remove(brace_positions, i)
                break
            end
        end

        if not has_brace_pair then return brace_pairs end
    end

    return brace_pairs
end

return M
