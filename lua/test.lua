-- this, is, some; text; with, different; separators
-- this, is, some; text; with, different; separators

    -- print(vim.inspect( { 123, utils.match("hello, there, jacob", " ") }))

-- This is a small sentence? There will be another one. In a minute! The end.

------------------------------------
--- test get_unsplittable_runs() ---
------------------------------------

local test = {"x, [y,] (y", "z,y), a"}
print(vim.inspect(require( "split.algorithm").split_lines(test, ",%s")))
-- local out = require("split.splitters").split_text(test, ",")
-- print(vim.inspect(out))

-- vim.api.nvim_buf_set_text(0, 4, 2, 4, 5, { "some new, text" })

-- local wrangle = require("split.splitters")
-- local utils = require("split.utils")
--
-- require("split.api").split_linewise()

-- print(vim.inspect(
--     split.get_unsplittable_runs("{ ()' } ' '")
-- ))

-- print(vim.inspect(utils.gfind("hi, there,,,, jacob", ",+")))

-- local tb = { "hi", "there", "harry"}
-- utils.table_discard(tb, function(x) return string.sub(x, 1, 1) == "h" end)
-- print(vim.inspect(tb))

-- print(vim.inspect(wrangle.split_text(
--     "some, (te,'xt)',  ,her'e",
--     ",",
--     false
-- )))

-- require("split.splitters").split_linewise() --, sdlkfjds , slkjdf , slkfjklasdj
-- require("split.api").split_linewise() -- , some , more, text
-- require("split.api").call("split_linewise", "g@")


-- print(vim.inspect(vim.api.nvim_buf_get_mark(0, "[")))
-- print(vim.inspect(vim.api.nvim_buf_get_mark(0, "]")))

-- vim.keymap.set(
--     "n",
--     "gm",
--     function()
--         print("here")
--         vim.opt.opfunc = "v:lua.print"
--         -- vim.cmd[[set opfunc=v:lua.print]]
--         vim.api.nvim_feedkeys("g@", "n", false)
--         -- vim.cmd[[g@]]
--     end
-- )

-- local t = { {3, 5 }, {8, 8} }
--
-- local t2 = vim.iter(t):
--     fold({{ 1 }}, function(acc, m)
--         table.insert(acc[#acc], m[1] - 1)
--         table.insert(acc, { m[2] + 1 })
--         return acc
--     end)
--
-- print(vim.inspect(t2))
