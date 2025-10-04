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
        
        -- Determine if this is a valid structure to visualize
        local structure_type = nil
        if capture_name == 'function.name' and M.config.show_function_braces then
            structure_type = 'function'
        elseif capture_name == 'class.name' and M.config.show_class_braces then
            structure_type = 'class'
        elseif (capture_name == 'loop') and M.config.show_loop_braces then
            structure_type = 'loop'
        elseif (capture_name == 'conditional') and M.config.show_conditional_braces then
            structure_type = 'conditional'
        elseif (capture_name == 'exception') and M.config.show_try_braces then
            structure_type = 'exception'
        end
        
        if structure_type then
            table.insert(structures, {
                type = structure_type,
                start_row = start_row,
                start_col = start_col,
                end_row = end_row,
                end_col = end_col,
                node = node
            })
        end
    end

    return structures
end

-- Convert treesitter structures to virtual text format
local function structures_to_virtual_text(structures)
    local virt_text_items = {}

    for _, struct in ipairs(structures) do
        local start_brace, end_brace = nil, nil
        local highlight = M.config.highlight_group
        local open_char, close_char = get_brace_chars()

        -- Add opening brace at the start of the structure
        start_brace = { { ' ' .. open_char, highlight } }
        
        -- Add closing brace at the end of the structure
        end_brace = { { close_char .. ' ', highlight } }

        -- Add opening brace
        table.insert(virt_text_items, {
            row = struct.start_row,
            col = struct.start_col,
            virt_text = start_brace,
            pos = 'eol'
        })

        -- Add closing brace
        table.insert(virt_text_items, {
            row = struct.end_row,
            col = 0,
            virt_text = end_brace,
            pos = 'eol'
        })
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