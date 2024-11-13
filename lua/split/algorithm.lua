local utils         = require("split.utils")
local interactivity = require("split.interactivity")
local comment       = require("split.comment")
--
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@mod split.algorithm Algorithm
---@brief [[
---The algorithm for splitting lines broadly consists of the following
---stages:
---
---1. Each line is split into sub-lines based on the provided
---   pattern(s):
---   - Unless the user specifies otherwise, a split will not occur if
---     the pattern falls within a special range, e.g. a pair of quotes
---     or a pair of brackets.
---   - If some of the lines to be split are comments, none of these
---     lines will be split. If all of the lines are commments, they will
---     be split as usual.
---   - Lines are uncommented so that the comment strings don't appear
---     in the wrong places later.
---2. Line parts are transformed using the given transformation
---   functions. The default transformations involve removing
---   leading/trailing whitespace, and possibly adding some padding to
---   the portions of the line matched by the provided pattern.
---3. The 'separator' and 'segment' portions of the original lines are
---   recombined pairwise to give the new lines.
---4. The newly constructed lines are 'unsplit', in effect replacing
---   the original linebreaks with a string provided by the user. Note
---   that here, linebreaks are only replaced within contiguous chunks
---   of commented/uncommented lines.
---5. Commenting is reapplied to the new lines.
---6. If the user called split.nvim within a line, leading and
---   new lines are added to the results.
---7. The new lines are inserted into the buffer.
---@brief ]]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

local M = {}

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
---@alias SplitType
---| '"current_line"' # Call is for the current line
---| '"line"' # Call is in operator-pending `"line"` mode
---| '"block"' # Currently just an alias for `"line"`
---| '"char"' # Call is in operator-pending `"char"` mode

---@private
---Split text by a pattern
---
---@param type SplitType | nil 
---The mode in which the function is called.
---@param opts SplitOpts | nil 
---Additional options; see |split.config.SplitOpts| for more
---information.
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
    local lines_split = M.split_lines(lines_uncommented, opts, range[1])

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

---@private
---@param lines string[]
---@param range integer[]
---@return string[]
---@return boolean[]
---@return function[]
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

---When a line is split, the result is an array where each element
---conforms to this pattern.
---@class SegSepPair
---
---A portion of the line which wasn't matched by the pattern.
---@field seg string
---
---A portion of the line which was matched by the provided pattern.
---@field sep? string

---Split text by inserting linebreaks
---
---This is a low-level helper which may be of use to users with a
---particularly adventurous spirit.
---
---@param lines string[] An array of lines to split
---@param opts SplitOpts Additional options to use when performting the
---  split. See |split.config.SplitOpts| for more information.
---@param linenr? integer Optionally the start line number, 1-indexed. If
---  supplied, this is used with tree-sitter to detect which of the
---  matches for `pattern` are commented. If not supplied it is assumed
---  that no lines are commented.
---@param bufnr? integer Optionally the buffer the text is taken from;
---  used with tree-sitter to detect which of the matches for `pattern`
---  are commented. Defaults to the current buffer.
---@return SegSepPair[][]
function M.split_lines(lines, opts, linenr, bufnr)
    linenr  = linenr or 1
    bufnr   = bufnr or 0

    local sep_positions = vim.tbl_map(
        function(line) return utils.gfind(line, opts.pattern) end,
        lines
    )

    local any_matches = vim.iter(sep_positions):any(function(x) return #x > 0 end)

    if not any_matches then
        return vim.tbl_map(function(l) return { { seg = l } } end, lines)
    end

    local unsplittable_chunks = M.get_ignored_chunks(lines, opts.quote_characters, opts.brace_characters)

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
        if not linenr then
            return false
        end
        return comment.ts_is_comment(bufnr, linenr + split_pos[1][1], split_pos[1][2]) or
            comment.ts_is_comment(bufnr, linenr + split_pos[2][1], split_pos[2][2])
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

    local comments_found = vim.iter(sep_positions):flatten(1):any(function(x) return x[3] end)
    local code_found     = vim.iter(sep_positions):flatten(1):any(function(x) return not x[3] end)

    -- Discard separators based on 'smart_ignore'
    if comments_found and code_found and opts.smart_ignore ~= "none" then
        sep_positions = vim.tbl_map(
            function(x)
                return vim.tbl_filter(
                    function(xi)
                        if opts.smart_ignore == "comments" then return not xi[3] end
                        if opts.smart_ignore == "code"     then return xi[3] end
                        error(("Unrecognised configuration `smart_ignore = %s`"):format(
                                vim.inspect(opts.smart_ignore)
                        ))
                    end,
                    x
                )
            end,
            sep_positions
        )
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
            table.insert(segment_sep_pairs, {
                seg = m[1] and m[2] and line:sub(m[1], m[2]),
                sep = m[3] and m[4] and line:sub(m[3], m[4])
            })
        end

        table.insert(out, segment_sep_pairs)
    end

    return out
end

--- Apply transformations to segments/separators before recombining
---
---@private
---@param text_split SegSepPair[][]
---@param transform_segments fun(segment: string, otps: SplitOpts): string
---@param transform_separators fun(separator: string, otps: SplitOpts): string
---@param opts SplitOpts
---@return SegSepPair[][]
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

    ---@param segsep SegSepPair
    ---@return SegSepPair
    local transform = function(segsep)
        if transform_segments ~= nil and segsep.seg then
            segsep.seg = check(transform_segments(segsep.seg, opts))
        end
        if transform_separators ~= nil and segsep.sep then
            segsep.sep = check(transform_separators(segsep.sep, opts))
        end
        return segsep
    end

    return vim.tbl_map(
        function(line_parts) return vim.tbl_map(transform, line_parts) end,
        text_split
    )
end




---@private
---@param text_split SegSepPair[][]
---@param break_placement BreakPlacement
---@return string[][]
function M.recombine(text_split, break_placement)
    local out = {}

    for _, line_parts in pairs(text_split) do
        local lines = { }

        for lnum, segsep in pairs(line_parts) do
            lines[lnum] = (lines[lnum] or "") .. (segsep.seg or "")

            if break_placement == "after_separator" then
                lines[lnum] = (lines[lnum] or "") .. (segsep.sep or "")

            elseif break_placement == "before_separator" then
                lines[lnum + 1] = segsep.sep
            end
        end

        table.insert(out, lines)
    end

    return out
end

---Remove preexisting linebreaks from the result
---
---This has to happen at this stage for reasons. Preexisting linebreaks are
---only removed within contigous chunks of commented or uncommented code.
---
---@private
---@param lines_recombined string[][] Each element corresponds to one
---  of the original lines. Each sub-element corresponds to one of the new
---  lines.
---@param commented boolean[] Whether any of `lines_recombined` were originally
---  commented
---@param commenters function[] A table of functions which can be used to 
---  restore the commented status of the lines
---@param opts SplitOpts
---@return string[][]
---@return function[] # Functions which be used to comment the results later on
function M.unsplit_lines(lines_recombined, commented, commenters, opts)
    local lines_unsplit = { { } }
    local commenters_unsplit = { commenters[1] }
    -- If the unsplitter matches the split pattern, it's safe to assume the
    -- user always wants the unsplitter to take precedence, i.e. they want the
    -- line to get unsplit, but not re-split again afterwards.
    local pattern = type(opts.pattern) == "table" and opts.pattern or { opts.pattern }
    local always_unsplit = vim.iter(pattern):any(function(p) return opts.unsplitter:match(p) end)
    local comments_found = vim.iter(commented):any(function(x) return x end)
    local code_found = vim.iter(commented):any(function(x) return not x end)

    -- Collapse each chunk of commented/uncommented lines into single lines.
    local prev_line_commented = commented[1]
    for lnum, line_parts in ipairs(lines_recombined) do
        local curr_line_commented = commented[lnum]

        -- Only unsplit if:
        -- * Current line is a comment and prev line isn't
        -- * Current line isn't a comment and previous line is
        -- * If lines are a mix of comments and code, then use 'smart_ignore'
        local is_smart_ignore = (comments_found and code_found) and (
            (opts.smart_ignore == "comments" and curr_line_commented)
            or (opts.smart_ignore == "code" and not curr_line_commented)
            or (opts.smart_ignore == "none" and false)
        )
        if curr_line_commented ~= prev_line_commented or is_smart_ignore then
            table.insert(lines_unsplit, line_parts)
            table.insert(commenters_unsplit, commenters[lnum])
        else
            local line = lines_unsplit[#lines_unsplit]

            if #line == 0 then
                table.insert(line, line_parts[1])
            else
                local unsplit_line = line[#line] .. opts.unsplitter .. line_parts[1]

                -- If the unsplit line matches the original split pattern, then
                -- conceptually we would want it to seem like the line then
                -- gets split by the pattern again, i.e. that the split pattern
                -- takes precedence. So in such cases we just don't unsplit
                -- in the first place.
                if unsplit_line:match(opts.pattern) and not always_unsplit then
                    table.insert(line, line_parts[1])
                else
                    line[#line] = unsplit_line
                end
            end

            for i = 2, #line_parts do table.insert(line, line_parts[i]) end
        end
        prev_line_commented = commented[lnum]
    end

    return lines_unsplit, commenters_unsplit
end

---@private
---@param lines string[]
---@param quote_chars { left: string[], right: string[] }
---@param brace_chars { left: string[], right: string[] }
---@return table
function M.get_ignored_chunks(lines, quote_chars, brace_chars)
    local quotes_ok = quote_chars.left and quote_chars.right
    local braces_ok = brace_chars.left and brace_chars.right

    if not quotes_ok and not braces_ok then
        return {}
    end

    local quote_runs, brace_runs

    if quotes_ok then
        quote_runs = M.get_enclosed_chunks(
            lines,
            quote_chars.left,
            quote_chars.right
        )
    end

    if braces_ok then
        brace_runs = M.get_enclosed_chunks(
            lines,
            brace_chars.left,
            brace_chars.right,
            quote_runs
        )
    end

    return utils.merge_ranges(utils.tbl_concat(quote_runs or {}, brace_runs or {}))
end


---@private
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
