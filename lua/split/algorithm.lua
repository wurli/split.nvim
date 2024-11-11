local utils         = require("split.utils")
local interactivity = require("split.interactivity")
local comment       = require("split.comment")

local M = {}

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@alias SplitType
---| '"current_line"' # split.nvim is being called for the line the cursor is on
---| '"line"' # split.nvim is being called in operator-pending 'line' mode
---| '"block"' # Currently just an alias for `"line"`
---| '"char"' # split.nvim is being called in operator-pending 'char' mode

---Split text by a pattern
---
---@param type SplitType | nil 
---The mode in which the function is called.
---@param opts SplitOpts | nil 
---Additional options; see |split.config.SplitOpts| for more information.
function M.split(type, opts)
    type           = type or "current_line"
    -- 'block' selections not implemented (yet), so fall back to "line"
    type           = type == "block" and "line" or type
    opts           = utils.tbl_copy(opts)
    local linewise = type == "current_line" or type == "line"

    if opts.interactive then
        opts = interactivity.get_opts_interactive(opts)
    end

    if not opts then
        return
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


    --------------------------------------------------------------------------
    -- Uncomment any commented lines, and make functions to re-comment them --
    --------------------------------------------------------------------------
    local lines_uncommented, commented, commenters = M.uncomment_lines(lines, range)

    -----------------------
    -- Perform the split --
    -----------------------
    local lines_split = M.split_lines(
        lines_uncommented,
        opts.pattern,
        opts.quote_characters,
        opts.brace_characters,
        range[1]
    )

    -----------------------------------------------
    -- Apply any transformations to split pieces --
    -----------------------------------------------
    local parts_transformed = M.transform(
        lines_split,
        opts.transform_segments,
        opts.transform_separators,
        opts
    )

    ----------------------------
    -- Recombine split pieces --
    ----------------------------
    local lines_recombined = M.recombine(parts_transformed, opts.break_placement)

    ---------------------------------------------------------
    -- 'Unsplit' each chunk of commented/uncommented lines --
    ---------------------------------------------------------
    if opts.unsplitter then
        lines_recombined, commenters = M.unsplit_lines(
            lines_recombined, commented, commenters, opts
        )
    end

    ---------------------------------------------------------
    -- Insert trailing blank line if split is not linewise --
    ---------------------------------------------------------
    if not linewise then
        table.insert(lines_recombined[#lines_recombined], "")
    end

    -----------------------------------
    -- Apply commenting to new lines --
    -----------------------------------
    for lnum, commenter in ipairs(commenters) do
        lines_recombined[lnum] = vim.tbl_map(commenter, lines_recombined[lnum])
    end

    --------------------------------------------------------
    -- Insert leading blank line if split is not linewise --
    --------------------------------------------------------
    if not linewise then
        table.insert(lines_recombined, 1, { "" })
    end

    ---------------------------------------
    -- Insert the new text in the buffer --
    ---------------------------------------
    local lines_flat = vim.iter(lines_recombined):flatten(1):totable()
    utils.set_range_text(range, lines_flat, linewise)

    -----------------------
    -- Apply indentation --
    -----------------------
    if opts.indenter then
        opts.indenter("[", "]")
    end
end

function M.uncomment_lines(lines, range)
    local commented = {}
    local commenters = {}
    for lnum, line in ipairs(lines) do
        if lnum == 1 then
            -- Need to make sure the first line contains the whole text as this
            -- is (usually) how we determine whether or not the line is a comment
            line = vim.api.nvim_buf_get_lines(0, range[1], range[1] + 1, true)[1]
        end

        local comment_parts = comment.get_comment_parts({ lnum + range[1], 0 }, line)
        local _, line_is_commented = comment.get_line_info(line, comment_parts)
        local commenter = function(x) return x end

        if line_is_commented then
            local uncommenter = comment.make_uncomment_function(comment_parts)
            commenter = comment.make_comment_function(comment_parts, "")
            lines[lnum] = uncommenter(lines[lnum])
        end

        table.insert(commented, line_is_commented)
        table.insert(commenters, commenter)
    end

    return lines, commented, commenters
end

function M.split_lines(lines, pattern, quote_characters, brace_characters, start_line)

    pattern    = pattern or ",%s*"
    start_line = start_line or 1

    local sep_positions = vim.tbl_map(
        function(line) return utils.gfind(line, pattern) end,
        lines
    )

    local any_matches = vim.iter(sep_positions):any(function(x) return #x > 0 end)

    if not any_matches then
        return vim.tbl_map(function(l) return { { l, "" } } end, lines)
    end

    local unsplittable_chunks = M.get_ignored_chunks(lines, quote_characters, brace_characters)

    local is_in_braces = function(split_pos)
        for _, chunk in pairs(unsplittable_chunks) do
            -- Check if either the start or end of the separator falls within 
            -- a pair of brackets (or quotes)
            if utils.position_within(split_pos[1], chunk[1], chunk[2]) then return true end
            if utils.position_within(split_pos[2], chunk[1], chunk[2]) then return true end
        end
        return false
    end

    local is_commented = function(split_pos)

        -- local abs_pos_start = { start_line + split_pos[1][1], split_pos[1][2] }
        -- local abs_pos_end = { start_line + split_pos[2][1], split_pos[2][2] }
        -- print(vim.inspect({ abs_pos_start, abs_pos_end }))
        -- print(vim.inspect(comment.ts_is_comment(0, unpack(abs_pos_start))))
        -- print(vim.inspect(comment.ts_is_comment(0, unpack(abs_pos_end))))

        return comment.ts_is_comment(0, start_line + split_pos[1][1], split_pos[1][2]) or
            comment.ts_is_comment(0, start_line + split_pos[2][1], split_pos[2][2])
    end

    -- Ignore any separators which fall within brackets, quotes, etc
    -- Output like this:
    -- {
    --      -- Column start/end positions for separators on line 1, and whether
    --      -- they're commented
    --      { { 1, 2, true }, { 9, 10, true } },
    --      -- Column start/end position for separator on line 2, and whether
    --      -- they're commented
    --      { { 6, 7, false } },
    -- }
    sep_positions = vim.iter(sep_positions):
        enumerate():
        map(function(lnum, cnums)
            local out = {}
            for _, cnum_pair in pairs(cnums) do
                local pos = { { lnum, cnum_pair[1] }, { lnum, cnum_pair[2] } }
                if not is_in_braces(pos) then
                    table.insert(out, { cnum_pair[1], cnum_pair[2], is_commented(pos) })
                end
            end
            return out
        end):
        totable()

    local all_commented = vim.iter(sep_positions):flatten(1):all(function(x) return x[3] end)

    -- If only some of the separators are commented, then discard them
    -- (otherwise, i.e. if they're all commented, they should all be kept)
    if not all_commented then
        sep_positions = vim.iter(sep_positions):
            map(function(x) return vim.tbl_filter(function(xi) return not xi[3] end, x) end):
            totable()
    end


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

            local segment = line:sub(segment_start, segment_stop)
            local sep     = line:sub(sep_start,     sep_stop)

            table.insert(segment_sep_pairs, { segment, sep })
        end

        table.insert(out, segment_sep_pairs)
    end

    return out
end

--- Apply transformations to segments/separators before recombining
---
---@param text_split table<integer, string[]>
---@param transform_segments fun(segment: string, otps: SplitOpts): string
---@param transform_separators fun(separator: string, otps: SplitOpts): string
---@param opts SplitOpts
---@return table<integer, string[]>
function M.transform(text_split, transform_segments, transform_separators, opts)
    if transform_segments == nil and transform_separators == nil then
        return text_split
    end

    local check = function(s)
        if type(s) ~= "string" then
            error(("Transformer should return a string, not a %s. Actual value returned: `%s`"):format(
                type(s),
                vim.inspect(s)
            ))
        end
        return s
    end

    local transform = function(segment_and_separator)
        if transform_segments ~= nil then
            segment_and_separator[1] = check(transform_segments(segment_and_separator[1], opts))
        end
        if transform_separators ~= nil then
            segment_and_separator[2] = check(transform_separators(segment_and_separator[2], opts))
        end
        return segment_and_separator
    end

    return vim.tbl_map(
        function(line_parts) return vim.tbl_map(transform, line_parts) end,
        text_split
    )
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

function M.unsplit_lines(lines_recombined, commented, commenters, opts)
    local lines_unsplit = { { } }
    local commenters_unsplit = { commenters[1] }

    -- Collapse each chunk of commented/uncommented lines into single lines.
    local prev_line_commented = commented[1]
    for lnum, line_parts in ipairs(lines_recombined) do
        local curr_line_commented = commented[lnum]
        if prev_line_commented == curr_line_commented then
            local line = lines_unsplit[#lines_unsplit]
            if #line == 0 then
                table.insert(line, line_parts[1])
            else
                local unsplit_line = line[#line] .. opts.unsplitter .. line_parts[1]
                if string.match(unsplit_line, opts.pattern) then
                    table.insert(line, line_parts[1])
                else
                    line[#line] = unsplit_line
                end
            end
            for i = 2, #line_parts do table.insert(line, line_parts[i]) end
        else
            table.insert(lines_unsplit, line_parts)
            table.insert(commenters_unsplit, commenters[lnum])
        end
        prev_line_commented = curr_line_commented
    end

    return lines_unsplit, commenters_unsplit
end

---@param lines string[]
---@param quote_chars  table
---@param brace_chars  table
---@return table
function M.get_ignored_chunks(lines, quote_chars, brace_chars)
    local quotes_ok = quote_chars.left and quote_chars.right
    local braces_ok = brace_chars.left and brace_chars.right

    if not quotes_ok and not braces_ok then
        return {}
    end

    local quote_runs, brace_runs

    if not quotes_ok then
        quote_runs = M.get_enclosed_chunks(
            lines,
            quote_chars.left,
            quote_chars.right
        )
    end

    if not braces_ok then
        brace_runs = M.get_enclosed_chunks(
            lines,
            brace_chars.left,
            brace_chars.right,
            quote_runs
        )
    end

    return utils.merge_ranges(utils.tbl_concat(quote_runs or {}, brace_runs or {}))
end


---@param lines table A table of lines 
---@param left_braces table Left brace characters
---@param right_braces table Right brace characters
---@param ignore_ranges? table Ranges to ignore when looking for brace characters
---@return table table
function M.get_enclosed_chunks(lines, left_braces, right_braces, ignore_ranges)

    local is_ignored = function(pos)
        if not ignore_ranges then return false end
        for _, r in pairs(ignore_ranges) do
            if utils.position_within(pos, r[1], r[2]) then
                return true
            end
        end
        return false
    end

    local braces = {}
    local brace_positions = {}

    for lnum, line in pairs(lines) do
        for cnum = 1, #line do
            if not is_ignored({ lnum, cnum }) then
                local char = line:sub(cnum, cnum)
                if vim.list_contains(left_braces, char) or vim.list_contains(right_braces, char) then
                    table.insert(braces, char)
                    table.insert(brace_positions, { lnum, cnum })
                end
            end
        end
    end

    -- Algorithm basically does this after removing everything except braces:
    -- Step 1: "({}[()])[)]" Step 2: "(  [  ])[)]"
    -- Step 2: "(      )[)]"
    -- Step 3: "(      )[)]"
    -- Step 4: "        [)]"
    --           ^^^^^^-- Returns this whole chunk of 'enclosed' text
    -- NB, Lua supports something like this using patterns like "%b()", but
    -- this doesn't take account of mixed brace types.
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
