local M = {}

function M.match(x, list)
    for i, el in ipairs(list) do
        if x == el then return i end
    end
    return -1
end

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

function M.table_keep(x, f)
    local index = 1

    while true do
        if index > #x then break end
        local res = f(x[index])
        if res == false then
            table.remove(x, index)
        else
            index = index + 1
        end
    end
end

function M.table_discard(x, f)
    M.table_keep(x, function(xi) return not f(xi) end)
end

return M

