-- bracepy - Virtual braces for Python code in Neovim
-- Author: bracepy
-- Description: Shows virtual braces for Python code blocks to make it more similar to languages like JavaScript

local M = {}

-- Create namespace for virtual text
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
        except_start = '{ except',
        except_end = 'except }',
        else_start = '{ else',  
        else_end = 'else }',
        elif_start = '{ elif',
        elif_end = 'elif }',
    }
}

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

-- Function to identify Python code blocks and their relationships using treesitter
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
    
    -- Query to capture all code constructs with detailed information
    local query = vim.treesitter.query.parse('python', [[
        (function_definition
            name: (identifier) @function.name
            body: (block) @function.body) @function.definition

        (class_definition
            name: (identifier) @class.name
            body: (block) @class.body) @class.definition

        (for_statement
            body: (block) @loop.body) @loop.statement

        (while_statement
            body: (block) @loop.body) @loop.statement

        (if_statement
            condition: (_) @if.condition
            consequence: (block) @if.body) @if.statement

        (elif_clause
            condition: (_) @elif.condition
            (block) @elif.body) @elif.statement

        (else_clause
            (block) @else.body) @else.statement

        (try_statement
            body: (block) @try.body) @try.statement

        (except_clause
            body: (block) @except.body) @except.statement
    ]])

    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local capture_name = query.captures[id]
        
        if capture_name == 'function.definition' and M.config.show_function_braces then
            local start_row, start_col = node:start()
            -- Find the function name and body
            local name = nil
            local body_node = nil
            for child in node:iter_children() do
                if child:type() == 'identifier' then
                    name = vim.treesitter.get_node_text(child, bufnr)
                elseif child:type() == 'block' then
                    body_node = child
                end
            end
            
            if body_node then
                local _, _, _, _ = body_node:range()
                local actual_end_row, actual_end_col = body_node:end_()
                
                table.insert(structures, {
                    type = 'function',
                    subtype = nil,
                    name = name,
                    start_row = start_row,
                    start_col = start_col,
                    end_row = actual_end_row,
                    end_col = actual_end_col,
                    node = node
                })
            end
        elseif capture_name == 'class.definition' and M.config.show_class_braces then
            local start_row, start_col = node:start()
            -- Find the class name and body
            local name = nil
            local body_node = nil
            for child in node:iter_children() do
                if child:type() == 'identifier' then
                    name = vim.treesitter.get_node_text(child, bufnr)
                elseif child:type() == 'block' then
                    body_node = child
                end
            end
            
            if body_node then
                local _, _, _, _ = body_node:range()
                local actual_end_row, actual_end_col = body_node:end_()
                
                table.insert(structures, {
                    type = 'class',
                    subtype = nil,
                    name = name,
                    start_row = start_row,
                    start_col = start_col,
                    end_row = actual_end_row,
                    end_col = actual_end_col,
                    node = node
                })
            end
        elseif capture_name == 'loop.statement' and M.config.show_loop_braces then
            local start_row, start_col = node:start()
            -- Find the loop body
            local body_node = nil
            for child in node:iter_children() do
                if child:type() == 'block' then
                    body_node = child
                    break
                end
            end
            
            if body_node then
                local _, _, _, _ = body_node:range()
                local actual_end_row, actual_end_col = body_node:end_()
                
                table.insert(structures, {
                    type = 'loop',
                    subtype = nil,
                    name = nil,
                    start_row = start_row,
                    start_col = start_col,
                    end_row = actual_end_row,
                    end_col = actual_end_col,
                    node = node
                })
            end
        elseif capture_name == 'if.statement' and M.config.show_conditional_braces then
            -- For if statements, we need to handle the whole if/elif/else chain
            local start_row, start_col = node:start()
            
            -- Get all the main if body
            local body_node = nil
            for child in node:iter_children() do
                if child:type() == 'block' or child:type() == 'consequence' then
                    body_node = child
                    break
                end
            end
            
            if body_node then
                local _, _, _, _ = body_node:range()
                local actual_end_row, actual_end_col = body_node:end_()
                
                table.insert(structures, {
                    type = 'conditional',
                    subtype = 'if',
                    name = nil,
                    start_row = start_row,
                    start_col = start_col,
                    end_row = actual_end_row,
                    end_col = actual_end_col,
                    node = node,
                    chain_end_row = actual_end_row  -- The end of the entire if/elif/else chain
                })
            end
        elseif capture_name == 'elif.statement' and M.config.show_conditional_braces then
            local start_row, start_col = node:start()
            
            -- Find the elif body
            local body_node = nil
            for child in node:iter_children() do
                if child:type() == 'block' then
                    body_node = child
                    break
                end
            end
            
            if body_node then
                local _, _, _, _ = body_node:range()
                
                -- For elif, we need to find the end of the whole if chain
                -- For now, just use the body end, but later we'll need to handle chains properly
                local actual_end_row, actual_end_col = body_node:end_()
                
                table.insert(structures, {
                    type = 'conditional',
                    subtype = 'elif',
                    name = nil,
                    start_row = start_row,
                    start_col = start_col,
                    end_row = actual_end_row,
                    end_col = actual_end_col,
                    node = node
                })
            end
        elseif capture_name == 'else.statement' and M.config.show_conditional_braces then
            local start_row, start_col = node:start()
            
            -- Find the else body
            local body_node = nil
            for child in node:iter_children() do
                if child:type() == 'block' then
                    body_node = child
                    break
                end
            end
            
            if body_node then
                local _, _, _, _ = body_node:range()
                
                -- For else, we need to find the end of the whole if chain
                local actual_end_row, actual_end_col = body_node:end_()
                
                table.insert(structures, {
                    type = 'conditional',
                    subtype = 'else',
                    name = nil,
                    start_row = start_row,
                    start_col = start_col,
                    end_row = actual_end_row,
                    end_col = actual_end_col,
                    node = node
                })
            end
        elseif capture_name == 'try.statement' and M.config.show_try_braces then
            local start_row, start_col = node:start()
            -- Find the try body
            local body_node = nil
            for child in node:iter_children() do
                if child:type() == 'block' then
                    body_node = child
                end
            end
            
            if body_node then
                local _, _, _, _ = body_node:range()
                local actual_end_row, actual_end_col = body_node:end_()
                
                table.insert(structures, {
                    type = 'exception',
                    subtype = 'try',
                    name = nil,
                    start_row = start_row,
                    start_col = start_col,
                    end_row = actual_end_row,
                    end_col = actual_end_col,
                    node = node,
                    chain_end_row = actual_end_row
                })
            end
        elseif capture_name == 'except.statement' and M.config.show_try_braces then
            local start_row, start_col = node:start()
            -- Find the except body
            local body_node = nil
            for child in node:iter_children() do
                if child:type() == 'block' then
                    body_node = child
                    break
                end
            end
            
            if body_node then
                local _, _, _, _ = body_node:range()
                local actual_end_row, actual_end_col = body_node:end_()
                
                -- For except, all excepts in a try statement end at the same line
                table.insert(structures, {
                    type = 'exception',
                    subtype = 'except',
                    name = nil,
                    start_row = start_row,
                    start_col = start_col,
                    end_row = actual_end_row,
                    end_col = actual_end_col,
                    node = node
                })
            end
        end
    end

    -- Now we need to identify linked if/elif/else statements to make them end at the same line
    -- Find the end of the if statement chain
    local if_structures = {}
    local all_conditional_structures = {}
    
    for _, struct in ipairs(structures) do
        if struct.type == 'conditional' then
            table.insert(all_conditional_structures, struct)
        end
    end
    
    -- Group related conditionals (if/elif/else that form a chain)
    -- This requires a more complex analysis of the treesitter tree structure
    -- For now, we'll use a simple heuristic: conditionals that have overlapping or consecutive end positions
    -- A better approach would be to analyze parent-child relationships in the AST
    local conditional_groups = {}
    local processed = {}
    
    for i, struct in ipairs(all_conditional_structures) do
        if not processed[i] then
            local group = {struct}
            processed[i] = true
            
            -- Find related conditionals that might be part of the same chain
            local potential_end = struct.end_row
            
            for j = i + 1, #all_conditional_structures do
                if not processed[j] and all_conditional_structures[j].end_row >= potential_end - 2 then
                    -- Check if they're close together (heuristic)
                    table.insert(group, all_conditional_structures[j])
                    processed[j] = true
                    potential_end = math.max(potential_end, all_conditional_structures[j].end_row)
                end
            end
            
            table.insert(conditional_groups, group)
        end
    end
    
    -- For each group, update the end position to be the maximum for all members
    for _, group in ipairs(conditional_groups) do
        if #group > 1 then
            local max_end_row = 0
            for _, struct in ipairs(group) do
                max_end_row = math.max(max_end_row, struct.end_row)
            end
            
            for _, struct in ipairs(group) do
                struct.end_row = max_end_row
                struct.chain_end_row = max_end_row
            end
        end
    end

    return structures
end

-- Process all structures and generate virtual text markers with proper handling for complex cases
local function generate_virtual_text(bufnr, structures)
    local markers = {}
    
    -- Create a comprehensive list of all markers (both start and end) for each structure
    local all_markers = {}
    
    for _, struct in ipairs(structures) do
        local highlight = M.config.highlight_group
        
        -- Determine labels based on structure type
        if struct.type == 'function' then
            table.insert(all_markers, { row = struct.start_row, col = struct.start_col, virt_text = { { ' ' .. M.config.icons.function_start, highlight } }, pos = 'eol', struct_type = 'start' })
            table.insert(all_markers, { row = struct.end_row, col = 0, virt_text = { { M.config.icons.function_end .. ' ', highlight } }, pos = 'eol', struct_type = 'end' })
        elseif struct.type == 'class' then
            table.insert(all_markers, { row = struct.start_row, col = struct.start_col, virt_text = { { ' ' .. M.config.icons.class_start, highlight } }, pos = 'eol', struct_type = 'start' })
            table.insert(all_markers, { row = struct.end_row, col = 0, virt_text = { { M.config.icons.class_end .. ' ', highlight } }, pos = 'eol', struct_type = 'end' })
        elseif struct.type == 'loop' then
            table.insert(all_markers, { row = struct.start_row, col = struct.start_col, virt_text = { { ' ' .. M.config.icons.loop_start, highlight } }, pos = 'eol', struct_type = 'start' })
            table.insert(all_markers, { row = struct.end_row, col = 0, virt_text = { { M.config.icons.loop_end .. ' ', highlight } }, pos = 'eol', struct_type = 'end' })
        elseif struct.type == 'conditional' then
            if struct.subtype == 'if' then
                table.insert(all_markers, { row = struct.start_row, col = struct.start_col, virt_text = { { ' ' .. M.config.icons.conditional_start, highlight } }, pos = 'eol', struct_type = 'start' })
                table.insert(all_markers, { row = struct.end_row, col = 0, virt_text = { { M.config.icons.conditional_end .. ' ', highlight } }, pos = 'eol', struct_type = 'end' })
            elseif struct.subtype == 'elif' then
                table.insert(all_markers, { row = struct.start_row, col = struct.start_col, virt_text = { { ' ' .. M.config.icons.elif_start, highlight } }, pos = 'eol', struct_type = 'start' })
                table.insert(all_markers, { row = struct.end_row, col = 0, virt_text = { { M.config.icons.elif_end .. ' ', highlight } }, pos = 'eol', struct_type = 'end' })
            elseif struct.subtype == 'else' then
                table.insert(all_markers, { row = struct.start_row, col = struct.start_col, virt_text = { { ' ' .. M.config.icons.else_start, highlight } }, pos = 'eol', struct_type = 'start' })
                table.insert(all_markers, { row = struct.end_row, col = 0, virt_text = { { M.config.icons.else_end .. ' ', highlight } }, pos = 'eol', struct_type = 'end' })
            end
        elseif struct.type == 'exception' then
            if struct.subtype == 'try' then
                table.insert(all_markers, { row = struct.start_row, col = struct.start_col, virt_text = { { ' ' .. M.config.icons.try_start, highlight } }, pos = 'eol', struct_type = 'start' })
                table.insert(all_markers, { row = struct.end_row, col = 0, virt_text = { { M.config.icons.try_end .. ' ', highlight } }, pos = 'eol', struct_type = 'end' })
            elseif struct.subtype == 'except' then
                table.insert(all_markers, { row = struct.start_row, col = struct.start_col, virt_text = { { ' ' .. M.config.icons.except_start, highlight } }, pos = 'eol', struct_type = 'start' })
                table.insert(all_markers, { row = struct.end_row, col = 0, virt_text = { { M.config.icons.except_end .. ' ', highlight } }, pos = 'eol', struct_type = 'end' })
            end
        end
    end
    
    -- Group all markers by row and process them
    local markers_by_row = {}
    for _, marker in ipairs(all_markers) do
        if not markers_by_row[marker.row] then
            markers_by_row[marker.row] = {}
        end
        table.insert(markers_by_row[marker.row], marker)
    end
    
    -- Process each row's markers
    for row, row_markers in pairs(markers_by_row) do
        -- For each row, determine the appropriate virtual text
        -- If there are multiple markers for the same row, we need special logic
        if #row_markers == 1 then
            -- Single marker, just add it
            table.insert(markers, row_markers[1])
        else
            -- Multiple markers, this is complex - handle if/elif/else and other cases
            -- For conditionals like "else: if } { else", we need to concatenate the virtual texts
            local combined_virt_text = {}
            local pos = 'eol'
            
            -- Sort markers by type to ensure proper order (end markers before start markers on same line)
            table.sort(row_markers, function(a, b)
                if a.struct_type == 'end' and b.struct_type == 'start' then
                    return true  -- end markers come first
                elseif a.struct_type == 'start' and b.struct_type == 'end' then
                    return false
                else
                    return a.col < b.col
                end
            end)
            
            -- Combine all virtual text segments for this line
            for _, marker in ipairs(row_markers) do
                for _, segment in ipairs(marker.virt_text) do
                    table.insert(combined_virt_text, segment)
                end
            end
            
            if #combined_virt_text > 0 then
                table.insert(markers, {
                    row = row,
                    col = 0,
                    virt_text = combined_virt_text,
                    pos = pos
                })
            end
        end
    end

    return markers
end

-- Add virtual text for Python structures
local function add_structural_virt_text(bufnr)
    local structures = get_python_structures(bufnr)
    local markers = generate_virtual_text(bufnr, structures)

    -- Clear existing extmarks for this buffer
    clear_buffer_extmarks(bufnr)

    -- Add new virtual text for each marker
    for _, marker in ipairs(markers) do
        safe_set_extmark(bufnr, marker.row, marker.col, {
            virt_text = marker.virt_text,
            virt_text_pos = marker.pos,
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