<h1 align="center">split.nvim</h1>
<p align="center"><sup>⚡️ A simple, powerful Neovim plugin for adding linebreaks ⚡️</sup></p>

<!-- TODO: add a demo gif -->

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
    ater, or on the split pattern. Nice if you write SQL like a sane person.

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
            -- Other keymaps are available :)
            ["gs"] = { pattern = ",", operator_pending = true },
            ["gss"] = { pattern = ",", operator_pending = false },
        },
    },
},
```

## Configuration

split.nvim supports a 

## Interactive mode

## Similar work

*   [splitjoin.nvim](https://github.com/bennypowers/splitjoin.nvim)

*   [splitjoin.vim](https://github.com/AndrewRadev/splitjoin.vim)

*   [treesj](https://github.com/Wansmer/treesj)

## Limitations

You can't use new-line characters like `\r` or `\n` in your split patterns,
e.g. as a way of adding an extra linebreak between paragraphs.

## 
