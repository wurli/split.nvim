-- See https://github.com/neovim/neovim/blob/master/runtime/lua/vim/_comment.lua

local M = {}

--- Get 'commentstring' at cursor
---@param ref_position integer[]
---@return string
function M.get_commentstring(ref_position)
    local buf_cs = vim.bo.commentstring

    local ts_parser = vim.treesitter.get_parser(0, '', { error = false })
    if not ts_parser then
        return buf_cs
    end

    -- Try to get 'commentstring' associated with local tree-sitter language.
    -- This is useful for injected languages (like markdown with code blocks).
    local row, col = ref_position[1] - 1, ref_position[2]
    local ref_range = { row, col, row, col + 1 }

    -- - Get 'commentstring' from the deepest LanguageTree which both contains
    --   reference range and has valid 'commentstring' (meaning it has at least
    --   one associated 'filetype' with valid 'commentstring').
    --   In simple cases using `parser:language_for_range()` would be enough, but
    --   it fails for languages without valid 'commentstring' (like 'comment').
    local ts_cs, res_level = nil, 0

    ---@param lang_tree vim.treesitter.LanguageTree
    local function traverse(lang_tree, level)
        if not lang_tree:contains(ref_range) then
            return
        end

        local lang = lang_tree:lang()
        local filetypes = vim.treesitter.language.get_filetypes(lang)
        for _, ft in ipairs(filetypes) do
            local cur_cs = vim.filetype.get_option(ft, 'commentstring')
            if cur_cs ~= '' and level > res_level then
                ts_cs = cur_cs
            end
        end

        for _, child_lang_tree in pairs(lang_tree:children()) do
            traverse(child_lang_tree, level + 1)
        end
    end
    traverse(ts_parser, 1)

    return ts_cs or buf_cs
end

---@param ref_position table
---@param line string
---@return { left: string, indent: string, right: string }
function M.get_comment_parts(ref_position, line)
    line = line or vim.api.nvim_buf_get_lines(0, ref_position[1] - 1, ref_position[1], true)[1]

    local cs = M.get_commentstring(ref_position)

    if cs == nil or cs == '' then
        vim.api.nvim_echo({ { "Option 'commentstring' is empty.", 'WarningMsg' } }, true, {})
        return { left = '', right = '' }
    end

    if not (type(cs) == 'string' and cs:find('%%s') ~= nil) then
        error(vim.inspect(cs) .. " is not a valid 'commentstring'.")
    end

    -- Structure of 'commentstring': <left part> <%s> <right part>
    local left, right = cs:match('^(.-)%%s(.-)$')
    left, right = vim.trim(left), vim.trim(right)
    local indent = line:match("^%s*" .. vim.pesc(left) .. "(%s*)") or ""

    return { left = left, indent = indent, right = right }
end

--- Make a function that checks if a line is commented
---@param parts vim._comment.Parts
---@return fun(line: string): integer | nil
function M.make_comment_check(parts)
    local l_esc, r_esc = vim.pesc(parts.left), vim.pesc(parts.right)

    -- Commented line has the following structure:
    -- <whitespace> <trimmed left> <anything> <trimmed right> <whitespace>
    local regex = "^%s*" .. vim.trim(l_esc) .. '.*' .. vim.trim(r_esc)

    return function(line)
        return line:find(regex)
    end
end

--- Compute comment-related information about lines
---@param line string
---@param parts vim._comment.Parts
---@return string indent
---@return boolean is_commented
function M.get_line_info(line, parts)
    local comment_check = M.make_comment_check(parts)

    local is_commented = true
    local indent_width = math.huge
    ---@type string
    local indent

    -- Update lines indent: minimum of all indents except blank lines
    local _, indent_width_cur, indent_cur = line:find('^(%s*)')

    -- Ignore blank lines completely when making a decision
    if indent_width_cur < line:len() then
        -- NOTE: Copying actual indent instead of recreating it with `indent_width`
        -- allows to handle both tabs and spaces
        if indent_width_cur < indent_width then
            ---@diagnostic disable-next-line:cast-local-type
            indent_width, indent = indent_width_cur, indent_cur
        end

        -- Update comment info: commented if every non-blank line is commented
        if is_commented then
            is_commented = comment_check(line) ~= nil
        end
    end

    -- `indent` can still be `nil` in case all `lines` are empty
    return indent or '', is_commented
end

function M.make_comment_function(parts, indent)
    local prefix          = indent .. parts.left
    local comment_indent  = parts.indent
    local nonindent_start = indent:len() + 1
    local suffix          = parts.right

    return function(line)
        return prefix .. comment_indent .. line:sub(nonindent_start) .. suffix
    end
end

function M.make_uncomment_function(parts)
    local l_esc         = vim.pesc(parts.left)
    local r_esc         = vim.pesc(parts.right)
    local regex         = '^(%s*)' .. l_esc           .. parts.indent .. '(.*)' .. r_esc           .. '(%s-)$'
    local regex_trimmed = '^(%s*)' .. vim.trim(l_esc) .. parts.indent .. '(.*)' .. vim.trim(r_esc) .. '(%s-)$'

    return function(line)
        -- Try regex with exact comment parts first, fall back to trimmed parts
        local indent, new_line, trail = line:match(regex)
        if new_line == nil then
            indent, new_line, trail = line:match(regex_trimmed)
        end

        -- Return original if line is not commented
        if new_line == nil then
            return line
        end

        return indent .. new_line .. trail
    end
end

---@return boolean | nil
function M.ts_is_comment(bufnr, row, col)
    local comment_nodes = {
        -- Some TS parsers call comment nodes 'comment', others use names
        -- like 'line_comment', 'block_comment', etc.
        "comment",
        -- SQL block comments
        "^marginalia$"
    }

    local node = vim.treesitter.get_node({
        bufnr = bufnr,
        pos = { row - 1, col - 1 },
        ignore_injections = false
    })

    local parents_checked = 0

    local function check_tree(n)
        -- Failsafe to stop vim ever getting stuck in an infinite loop. In
        -- theory this should never happen though.
        if parents_checked > 100 then
            vim.notify(
                "Failed to ascend tree searching for a comment node. Over 1000 parents nodes checked.",
                vim.log.levels.WARN
            )
            return nil
        end
        parents_checked = parents_checked + 1

        if not n then
            return false
            end

        for _, comment_node in pairs(comment_nodes) do
            if n:type():match(comment_node) then
                return true
            end
        end

        return check_tree(n:parent())
    end

    return check_tree(node)
end
return M
