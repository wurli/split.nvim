
-- bla, bla, bla
-- a, b, c,
-- 1, 2, 3

print(vim.inspect(require("split.split").get_unsplittable_runs("{ ()' } ' '")))

-- print(vim.inspect(utils.gfind("hi, there,,,, jacob", ",+")))

local x = {
    1, 2, 3,
    4, 5, 6,
    7, 8 ,9
}

local tb = { "hi", "there", "harry"}
utils.table_discard(tb, function(x) return string.sub(x, 1, 1) == "h" end)
print(vim.inspect(tb))

