local wrangle = require("split.wrangle")
local utils = require("split.utils")

-- print(vim.inspect(
--     split.get_unsplittable_runs("{ ()' } ' '")
-- ))

-- print(vim.inspect(utils.gfind("hi, there,,,, jacob", ",+")))

local tb = { "hi", "there", "harry"}
utils.table_discard(tb, function(x) return string.sub(x, 1, 1) == "h" end)
print(vim.inspect(tb))

