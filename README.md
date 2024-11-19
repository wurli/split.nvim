<h1 align="center">split.nvim</h1>
<p align="center">⚡️ A simple, powerful Neovim plugin for adding linebreaks ⚡️</p>

<!-- TODO: add a demo gif -->

``` sql
-- hello, there, jacob
select foo, bar, baz
from tb
```

split.nvim is a plugin which adds linebreaks to your code based on one or more
Lua patterns. Patterns may be simple like `","` to split text by commas, or
more complicated like `"[%.?!]%s+"` to split text so each sentence ends up on
its own line.

Why not use a simple find-and-replace? Great question! split.nvim offers several
enhancements over this approach:

*   split.nvim won't insert breaks within common text objects like `()`, `{}`,
    `""`, etc. This means your code is _much_ less likely to get completely
    borked by the operation.

*   split.nvim is aware of comments. If the region you're splitting over
    contains both commented and uncommented code, splits won't get added within
    the comments (this is configurable). This also significantly decreases the
    bork-factor during splitting.

*   split.nvim will (by default) automatically apply indentation to the split
    region after inserting linebreaks. This is the same indentation used by
    your normal `==`, so spacing should end up the way _you_ like it.

*   split.nvim makes it very easy to insert the linebreaks either before,
    after, or on the split pattern. Nice if you write SQL the right way.

*   split.nvim intelligently inserts leading and trailing blank lines to the
    split region. It sounds annoying but it's honestly really good.

*   split.nvim supports (and encourages!) operator-pending mode and dot-repeat.

*   split.nvim supports an [interactive mode](link here) so you don't need
    to set a million keymaps to get fine-grained control.

These features all combine to give a simple, powerful tool which integrates
very nicely with Neovim's existing set of text manipulation keymappings. Not
convinced? Give it a try! It's a classic green eggs and ham plugin.

## Installation

split.nvim is easy to install using your favourite plugin manager. Here's how
you can install it using Lazy:

``` Lua
{
    "wurli/split.nvim",
    opts = {
        keymaps = {
            -- Other keymaps are available :) these ones will be used
            -- by default.
            ["gs"]  = {
                pattern = ",",
                operator_pending = true,
                interactive = false,
            },
            ["gss"] = {
                pattern = ",",
                operator_pending = false,
                interactive = false,
            },
            ["gS"]  = {
                pattern = ",",
                operator_pending = true,
                interactive = true,
            },
            ["gSS"] = {
                pattern = ",",
                operator_pending = false,
                interactive = true,
            },
        },
    },
},
```

## Configuration

split.nvim supports a plethora of configuration options, although the defaults
should (hopefully) be suitable for the majority of users. For a complete
list of options, please see the [documentation](doc/split.txt). Here's
a quick example to whet your appetite:

``` lua
{
    keymaps = {
        ["gs"]  = {
            pattern = ",",
            operator_pending = true,
            interactive = false,
        },
        ["gss"] = {
            pattern = ",",
            operator_pending = false,
            interactive = false,
        },
        ["gS"]  = {
            pattern = ",",
            operator_pending = true,
            interactive = true,
        },
        ["gSS"] = {
            pattern = ",",
            operator_pending = false,
            interactive = true,
        },
    },
    pattern_aliases = {
        [","] = ",",
        [";"] = ";",
        [" "] = "%s+",
        ["+"] = " [+-/%] ",
        ["<"] = {
            pattern = { "<[^=]", "<=", "==", ">[^=]", ">=" },
            break_placement = "before_pattern"
        },
        ["."] = {
            pattern = "[%.?!]%s+",
            unsplitter = " ",
            smart_ignore = "code",
            quote_characters = {},
            brace_characters = {}
        },
        ["|"] = {
            pattern = { "|>", "%%>%%" },
            break_placement = function(ft, cmt)
                if ft == "ml" and not cmt then
                    return "before_pattern"
                end
                return "after_pattern"
            end
        }
    },
    keymap_defaults = {
        pattern = ",",
        break_placement = {
            "after_pattern",
            sql = "before_pattern"
        },
        operator_pending = false,
        transform_segments = make_transformer({
            trim_l = { "before_pattern", "on_pattern", "after_pattern" },
            trim_r = { "before_pattern", "on_pattern", "after_pattern" },
        }),
        transform_separators = make_transformer({
            trim_l = { "before_pattern" },
            trim_r = { "before_pattern", "after_pattern" },
            pad_r = { "before_pattern" }
        }),
        indenter = require("split.indent").indent_equalprg,
        unsplitter = nil,
        interactive = false,
        smart_ignore = "comments",
        quote_characters = { left = { "'", '"', "`" }, right = { "'", '"', "`" } },
        brace_characters = { left = { "(", "{", "[" }, right = { ")", "}", "]" } }
    },
}
```


## Interactive mode

## Similar work

*   [splitjoin.nvim](https://github.com/bennypowers/splitjoin.nvim)

*   [splitjoin.vim](https://github.com/AndrewRadev/splitjoin.vim)

*   [TreeSJ](https://github.com/Wansmer/treesj)

## Limitations

You can't use new-line characters like `\r` or `\n` in your split patterns,
e.g. as a way of adding an extra linebreak between paragraphs.

## 
