<h1 align="center">split.nvim</h1>
<p align="center">⚡️ A simple, powerful Neovim plugin for adding linebreaks ⚡️</p>

![](demo.gif)

split.nvim is a plugin which adds linebreaks to your code based on one or more
Lua patterns. Patterns may be simple like `","` to split text by commas, or
more complicated like `"[%.?!]%s+"` to split text so each sentence ends up on
its own line.

### Features:

*   **Automatic indentation** applied to the split region. This is the same
    indentation used by your normal `==`, so spacing should end up the way
    _you_ like it.

*   **Awareness of common text objects** like `()`, `{}`, `""`, etc. This means
    your code is _much_ less likely to get completely borked by the operation.

*   **Comment awareness**. If the region you're splitting over contains both
    commented and uncommented code, splits won't get added within the comments
    (this is configurable). This also significantly decreases the bork-factor
    during splitting.

*   split.nvim makes it very easy to **insert the linebreaks either before,
    after, or on the split pattern**. Nice if you write SQL the right way.

*   **Operator-pending mode and dot-repeat**.

*   An [**interactive mode**](#-interactive-mode) so you don't need to set a
    million keymaps to get fine-grained control.

These features all combine to give a simple, powerful tool which integrates
very nicely with Neovim's existing set of text manipulation keymappings
(especially `J` and `gJ`). Not convinced? Give it a try! It's a classic green
eggs and ham plugin.

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
        -- Here, gs and gss give a mapping to split lines by commas and
        -- semicolons. This doesn't enter interactive mode.
        ["gs"]  = {
            pattern = "[,;]",
            operator_pending = true,
        },
        ["gss"] = {
            pattern = "[,;]",
            operator_pending = false,
        },
        -- Here, gS and gSS give a mapping to enter interactive split mode...
        ["gS"] = {
            interactive = true,
            operator_pending = true,
        },
        ["gSS"] = {
            interactive = true,
            operator_pending = false,
        },
    },
    interactive_options = {
        -- In interactive mode, the user can press ',' to split by commas
        -- and semicolons, or '|' to split by the pipe operator. The
        -- pipe operator pattern also checks if the current line is an
        -- uncommented OCaml line, and if so, puts the pipe at the
        -- start of the line.
        [","] = "[,;]",
        ["|"] = {
            pattern = { "|>", "%%>%%" },
            break_placement = function(line_info, opts)
                if line_info.filetype == "ocaml" and not line_info.comment then
                    return "before_pattern"
                end
                return "after_pattern"
            end
        }
    },
    keymap_defaults = {
        -- We can also override the plugin defaults for mappings. For
        -- example, this option specifies that if we're writing SQL,
        -- we should put the split pattern at the start of each line
        -- unless we're writing a comment, e.g. for those who style
        -- their SQL like this (the right way):
        --
        --     -- Before splitting
        --     select foo, bar, baz
        --     from table
        --
        --     -- After splitting
        --     select foo
        --     , bar
        --     , baz
        --     from table
        break_placement = function(line_info, opts)
            if line_info.filetype == "sql" and not line_info.comment then
                return "before_pattern"
            end
            return "after_pattern"
        end
    },
}
```

## Interactive mode

When split.nvim is called in interactive mode, the user will be prompted to
enter options to perform the split. In this mode, special keys are used to
enter non-standard options:

*   `<C-x>` can be used to enter a non-standard split pattern

*   `<Enter>` can be used to cycle through the options for where linebreaks are
    placed relative to the split pattern

*   `<C-s>` can be used to toggle whether the original line breaks should be
    retained in addition to the new ones.

To perform the split and exit interactive mode you should use one of the
keys specified by `config.interactive_options`. These are the options
you get out of the box:

*    `","`: Split on commas.

*    `";"`: Split on semicolons.

*    `" "`: Split on one or more whitespace characters.

*    `"+"`: Split on `+`, `-`, `/`, and `%`, provided these are surrounded by
            one or more whitespace characters.

*    `"<"`: Split by `<`, `<=`, `==`, `>`, or `>=`.

*    `"."`: Split text so that each sentence occupies a single line.

## Similar work

There are a few other plugins that offer similar functionality, although the
implementations are very different. From what I can tell, split.nvim is unique
in allowing you to specify generic _patterns_ to split on rather than text
objects for a given language.

*   [splitjoin.nvim](https://github.com/bennypowers/splitjoin.nvim)

*   [splitjoin.vim](https://github.com/AndrewRadev/splitjoin.vim)

*   [TreeSJ](https://github.com/Wansmer/treesj)

