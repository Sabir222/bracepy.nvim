# BracePy Plugin Documentation

## Commands

- `:BracePyUpdate` - Manually update the virtual braces in the current buffer
- `:BracePyToggle` - Toggle the plugin on/off globally

## Configuration

The plugin can be configured with the following options:

```lua
require('bracepy').setup({
  enabled = true,                          -- Enable the plugin
  show_function_braces = true,             -- Show braces for functions
  show_class_braces = true,                -- Show braces for classes
  show_loop_braces = true,                 -- Show braces for loops (for, while)
  show_conditional_braces = true,          -- Show braces for conditionals (if, elif, else)
  show_try_braces = true,                  -- Show braces for try/except blocks
  show_indent_braces = false,              -- Show braces for general indentation blocks
  brace_style = 'curly',                   -- 'curly', 'square', 'round'
  highlight_group = 'Comment',             -- Highlight group for the braces
  position = 'end_of_line',                -- Position: 'end_of_line', 'below_line', 'inline'
})
```

## How It Works

The plugin uses Tree-sitter to parse Python code and identify code blocks like functions, classes, loops, and conditionals. It then adds virtual text at the start and end of these blocks to simulate braces similar to languages like JavaScript or C.

For example, with the default configuration:
- A function definition will show `{ func` at the start and `func }` at the end
- A class definition will show `{ class` at the start and `class }` at the end
- A for loop will show `{ loop` at the start and `loop }` at the end

This makes Python code more visually structured, helping developers who are used to brace-delimited languages.