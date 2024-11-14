local M = {}

---@param x any A value to search for
---@param list table A table of values to match against
---@return integer | nil # The index of the found item, or `nil` if not found
function M.match(x, list)
    for i, el in ipairs(list) do
        if x == el then return i end
    end
end

-- Range a is smaller than range b if a starts on an earlier row,
-- OR if it a starts on the same row, but an earlier column
function M.position_less_than(a, b)
    return (a[1] < b[1]) or (a[1] == b[1] and a[2] < b[2])
end

function M.position_less_than_equal_to(a, b)
    return (a[1] < b[1]) or (a[1] == b[1] and a[2] <= b[2])
end

function M.position_within(x, left, right, boundary_ok)
    boundary_ok = boundary_ok or { true, true }
    boundary_ok = type(boundary_ok) == "table" and boundary_ok or { boundary_ok, boundary_ok }

    local check_left = boundary_ok[1] and M.position_less_than or M.position_less_than_equal_to
    local check_right = boundary_ok[2] and M.position_less_than or M.position_less_than_equal_to

    return check_left(left, x) and check_right(x, right)
end

---@param x table A table containing tables to merge, e.g.:
--- ``` lua
--- {
---     { {rx1, cx1}, {rx2, cx2} }, -- first range
---     { {ry1, cy1}, {ry2, cy2} }, -- second range
---     { {rz1, cz1}, {rz2, cz2} }, -- third range
--- }
--- ```
---@return table result The input table with any overlapping ranges merged
function M.merge_ranges(x)

    -- Sort ranges based on opening delimiter position
    table.sort(x, function(a, b) return M.position_less_than(a[1], b[1]) end)

    local merged = { x[1] }
    table.remove(x, 1)

    for _, rng in pairs(x) do
        local prev = merged[#merged]
        -- If the start of the current range falls within the bounds of the previous
        -- one, then perform the merge by simply widening the previous range
        -- if the current one has a greater ending position.
        if M.position_less_than_equal_to(rng[1], prev[2]) then
            merged[#merged][2] = M.position_less_than_equal_to(rng[2], prev[2]) and prev[2] or rng[2]
        else
            table.insert(merged, rng)
        end
    end

    return merged
end

---@param x string The string to split
---@param pattern string | table Either a pattern to split on or a table of
---  patterns to split on
---@param plain? boolean Whether to 
function M.gfind(x, pattern, plain)
    if type(pattern) == "table" then
        local out = {}
        for _, p in pairs(pattern) do
            for _, pos in pairs(M.gfind(x, p, plain)) do
                table.insert(out, pos)
            end
        end
        return out
    end

    if plain == nil then plain = false end

    local out = {}

    local init = 1

    while true do
        local start, stop = x:find(pattern, init, plain)
        if start == nil then break end
        table.insert(out, { start, stop })
        init = stop + 1
    end

    return out
end

function M.get_marks_range(m1, m2)
    local text_start = vim.api.nvim_buf_get_mark(0, m1 or "[")
    local text_end = vim.api.nvim_buf_get_mark(0, m2 or "]")
    return { text_start[1] - 1, text_start[2], text_end[1] - 1, text_end[2] + 1 }
end

function M.get_range_text(range, linewise)
    range = range or M.get_marks_range()
    return linewise
        and vim.api.nvim_buf_get_lines(0, range[1], range[3] + 1, true)
        or vim.api.nvim_buf_get_text(0, range[1], range[2], range[3], range[4], {})
end

function M.set_range_text(range, lines, linewise)
    range = range or M.get_marks_range()

    if linewise then
        vim.api.nvim_buf_set_lines(0, range[1], range[3] + 1, true, lines)
    else
        vim.api.nvim_buf_set_text(0, range[1], range[2], range[3], range[4], lines)
    end

    -- Need to adjust the positions for the new marks based on how many new
    -- lines have been inserted. Unfortuntely, because we run `=` later to 
    -- reindent the code, it's highly impractical to work out where the final
    -- column should be, so we just set it to 0.
    range[1] = range[1] + 1 -- (lines[1] == "" and 2 or 1)
    range[3] = range[1] + #lines - 1 -- - (lines[#lines] == "" and 2 or 0)

    vim.api.nvim_buf_set_mark(0, "[", range[1], 0, {})
    vim.api.nvim_buf_set_mark(0, "]", range[3], 0, {})
end

function M.tbl_concat(...)
    return vim.iter({...}):flatten():totable()
end

function M.tbl_copy(x)
    local out = {}
    for k, v in pairs(x) do
        out[k] = type(v) == "table" and M.tbl_copy(v) or v
    end
    return out
end

return M

