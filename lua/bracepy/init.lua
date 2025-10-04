-- bracepy - Virtual braces for Python code in Neovim
-- Author: bracepy
-- Description: Shows virtual braces for Python code blocks to make it more similar to languages like JavaScript

local M = {}

-- Create namespaces for different types of virtual text
local namespace = vim.api.nvim_create_namespace('bracepy')

-- Store extmark IDs by buffer for management
local extmark_store = setmetatable({}, {
    __index = function(t, k)
        t[k] = {}
        return t[k]
    end
})

-- Default configuration
M.config = {
    enabled = true,
    show_function_braces = true,
    show_class_braces = true,
    show_loop_braces = true,
    show_conditional_braces = true,
    show_try_braces = true,
    show_indent_braces = false,  -- Show braces for general indentation blocks
    brace_style = 'curly',  -- 'curly', 'square', 'round'
    highlight_group = 'Comment',
    position = 'end_of_line',  -- 'end_of_line', 'below_line', 'inline'
    icons = {
        function_start = '{ func',
        function_end = 'func }',
        class_start = '{ class',
        class_end = 'class }',
        loop_start = '{ loop',
        loop_end = 'loop }',
        conditional_start = '{ if',
        conditional_end = 'if }',
        try_start = '{ try',
        try_end = 'try }',
        except_start = '{ except',  -- For except blocks
        except_end = 'except }',
        else_start = '{ else',      -- For else blocks
        else_end = 'else }',
        elif_start = '{ elif',      -- For elif blocks
        elif_end = 'elif }',
    }
}

-- Function to get the appropriate brace characters based on config
local function get_brace_chars()
    local config = M.config
    if config.brace_style == 'curly' then
        return '{', '}'
    elseif config.brace_style == 'square' then
        return '[', ']'
    elseif config.brace_style == 'round' then
        return '(', ')'
    end
    return '{', '}'
end

-- Function to clear extmarks for a specific buffer
local function clear_buffer_extmarks(bufnr)
    if not extmark_store[bufnr] then
        return
    end

    for i = #extmark_store[bufnr], 1, -1 do
        local id = extmark_store[bufnr][i]
        local success = pcall(vim.api.nvim_buf_del_extmark, bufnr, namespace, id)
        if success then
            table.remove(extmark_store[bufnr], i)
        end
    end
end

-- Safe extmark creation with error handling
local function safe_set_extmark(bufnr, row, col, opts)
    local ok, result = pcall(vim.api.nvim_buf_set_extmark, bufnr, namespace, row, col, opts)
    if ok and result then
        table.insert(extmark_store[bufnr], result)
        return result
    else
        vim.notify("BracePy: Failed to create extmark: " .. (result or "unknown error"), vim.log.levels.WARN)
        return nil
    end
end

-- Function to identify Python code blocks using treesitter
local function get_python_structures(bufnr)
    local structures = {}
    
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, 'python')
    if not ok or not parser then
        vim.notify("BracePy: Could not get treesitter parser for Python", vim.log.levels.WARN)
        return structures
    end

    local lang_tree = parser:parse()
    if not lang_tree or not lang_tree[1] then
        return structures
    end

    local root = lang_tree[1]:root()
    local query = vim.treesitter.query.parse('python', [[
        [
            (function_definition 
                name: (identifier) @function.name
                body: (block) @function.body)
            (class_definition 
                name: (identifier) @class.name
                body: (block) @class.body)
            (for_statement) @loop
            (while_statement) @loop
            (if_statement) @conditional
            (elif_clause) @conditional
            (else_clause) @conditional
            (try_statement) @exception
            (except_clause) @exception
            (with_statement) @context
        ]
    ]])

    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local capture_name = query.captures[id]
        local start_row, start_col, end_row, end_col = node:range()
        
        table.insert(structures, {
            type = capture_name,
            start_row = start_row,
            start_col = start_col,
            end_row = end_row,
            end_col = end_col,
            node = node
        })
    end

    return structures
end

-- Convert treesitter structures to virtual text format
local function structures_to_virtual_text(structures)
    local virt_text_items = {}
    local line_has_marker = {} -- Track which lines already have markers to avoid duplicates

    for _, struct in ipairs(structures) do
        local start_virt_text = nil
        local end_virt_text = nil
        local highlight = M.config.highlight_group

        -- Determine the type of structure and appropriate braces
        if struct.type == 'function.name' and M.config.show_function_braces then
            start_virt_text = { { ' ' .. M.config.icons.function_start, highlight } }
            end_virt_text = { { M.config.icons.function_end .. ' ', highlight } }
        elseif struct.type == 'class.name' and M.config.show_class_braces then
            start_virt_text = { { ' ' .. M.config.icons.class_start, highlight } }
            end_virt_text = { { M.config.icons.class_end .. ' ', highlight } }
        elseif struct.type == 'loop' and M.config.show_loop_braces then
            start_virt_text = { { ' ' .. M.config.icons.loop_start, highlight } }
            end_virt_text = { { M.config.icons.loop_end .. ' ', highlight } }
        elseif struct.type == 'conditional' and M.config.show_conditional_braces then
            -- For conditionals, use appropriate labels based on the node type
            local start_icon = M.config.icons.conditional_start
            local end_icon = M.config.icons.conditional_end
            
            -- Check if it's elif or else to use specific icons
            local node_text = vim.treesitter.get_node_text(struct.node, vim.api.nvim_get_current_buf())
            if string.find(node_text, '^elif') then
                start_icon = M.config.icons.elif_start
                end_icon = M.config.icons.elif_end
            elseif string.find(node_text, '^else') then
                start_icon = M.config.icons.else_start
                end_icon = M.config.icons.else_end
            end
            
            start_virt_text = { { ' ' .. start_icon, highlight } }
            end_virt_text = { { end_icon .. ' ', highlight } }
        elseif struct.type == 'exception' and M.config.show_try_braces then
            start_virt_text = { { ' ' .. M.config.icons.try_start, highlight } }
            end_virt_text = { { M.config.icons.try_end .. ' ', highlight } }
        end

        -- Add opening brace if we have one and the line doesn't already have a marker
        if start_virt_text and not line_has_marker[struct.start_row] then
            table.insert(virt_text_items, {
                row = struct.start_row,
                col = struct.start_col,
                virt_text = start_virt_text,
                pos = 'eol'
            })
            line_has_marker[struct.start_row] = true
        end

        -- Add closing brace if we have one and the line doesn't already have a marker
        if end_virt_text and not line_has_marker[struct.end_row] then
            table.insert(virt_text_items, {
                row = struct.end_row,
                col = 0,
                virt_text = end_virt_text,
                pos = 'eol'
            })
            line_has_marker[struct.end_row] = true
        end
    end

    return virt_text_items
end

-- Add virtual text for Python structures
local function add_structural_virt_text(bufnr)
    local structures = get_python_structures(bufnr)
    local virt_text_items = structures_to_virtual_text(structures)

    -- Clear existing extmarks for this buffer
    clear_buffer_extmarks(bufnr)

    -- Add new virtual text for each structure
    for _, item in ipairs(virt_text_items) do
        safe_set_extmark(bufnr, item.row, item.col, {
            virt_text = item.virt_text,
            virt_text_pos = item.pos,
            hl_mode = 'combine',
            priority = 1000,
        })
    end
end

-- Main update function
function M.update_braces(bufnr)
    if not M.config.enabled then
        return
    end

    -- Validate buffer
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    -- Check if it's a Python file
    local buftype = vim.api.nvim_buf_get_option(bufnr, 'buftype')
    local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')

    if buftype ~= '' or filetype ~= 'python' then
        -- If it's not a Python file, clean up stored extmarks
        clear_buffer_extmarks(bufnr)
        return
    end

    -- Add structural visualizations
    add_structural_virt_text(bufnr)
end

-- Setup function to be called when plugin is loaded
function M.setup(user_config)
    -- Merge user config with default config
    if user_config then
        for k, v in pairs(user_config) do
            M.config[k] = v
        end
    end

    -- Setup autocmds for Python files
    vim.api.nvim_create_autocmd(
        { "BufEnter", "FileType" },
        {
            pattern = { "*.py", "*.pyi" },
            callback = function(args)
                M.update_braces(args.buf)
            end,
        }
    )

    -- Update on buffer changes
    vim.api.nvim_create_autocmd(
        { "TextChanged", "TextChangedI", "TextChangedP", "BufWritePost" },
        {
            pattern = { "*.py", "*.pyi" },
            callback = function(args)
                M.update_braces(args.buf)
            end,
        }
    )

    -- Clean up on buffer unload
    vim.api.nvim_create_autocmd(
        { "BufUnload" },
        {
            pattern = { "*.py", "*.pyi" },
            callback = function(args)
                clear_buffer_extmarks(args.buf)
            end,
        }
    )
end

-- Command to manually trigger update
function M.manual_update()
    M.update_braces(vim.api.nvim_get_current_buf())
end

-- Cleanup function
function M.cleanup()
    for bufnr, _ in pairs(extmark_store) do
        if vim.api.nvim_buf_is_valid(bufnr) then
            clear_buffer_extmarks(bufnr)
        end
    end
    extmark_store = setmetatable({}, {
        __index = function(t, k)
            t[k] = {}
            return t[k]
        end
    })
end

return M