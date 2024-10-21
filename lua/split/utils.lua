local M = {}

---@param x any A value to search for
---@param list table A table of values to match against
---@return integer position The index of the found item, or -1 if not found
function M.match(x, list)
    for i, el in ipairs(list) do
        if x == el then return i end
    end
    return -1
end

---@param x table A table containing tables to merge
---@return table result The input table with any overlapping ranges merged
function M.merge_ranges(x)
    table.sort(x, function(a, b) return a[1] < b[1] end)

    local out = { x[1] }
    table.remove(x, 1)

    for _, e in pairs(x) do
        if e[1] <= out[#out][2] then
            out[#out][2] = math.max(e[2], out[#out][2])
        else
            table.insert(out, e)
        end
    end

    return out
end

function M.gfind(x, pattern, plain)
    if plain == nil then plain = false end

    local out = {}

    local init = 1

    while true do
        local start, stop = string.find(x, pattern, init, plain)
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
    local text = linewise
        and vim.api.nvim_buf_get_lines(0, range[1], range[3] + 1, true)
        or vim.api.nvim_buf_get_text(0, range[1], range[2], range[3], range[4], {})
    return table.concat(text, "\n")
end

function M.set_range_text(range, lines, linewise)
    range = range or M.get_marks_range()

    if linewise then
        vim.api.nvim_buf_set_lines(0, range[1], range[3] + 1, true, lines)
    else
        vim.api.nvim_buf_set_text(0, range[1], range[2], range[3], range[4], lines)
    end

    -- FIXME: set column properly
    vim.api.nvim_buf_set_mark(0, "[", range[1] + 1,          range[2], {})
    vim.api.nvim_buf_set_mark(0, "]", range[3] + #lines + 1, 0, {})
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

