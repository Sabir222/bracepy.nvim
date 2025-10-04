# bracepy.nvim

A Neovim plugin that shows virtual braces for Python code blocks, making Python code more visually structured similar to languages like JavaScript, C, or Java.

## Features

- Shows virtual braces for Python functions, classes, loops, conditionals, and exception handling
- Customizable brace styles (curly, square, round)
- Configurable colors and positioning
- Toggle on/off functionality
- Automatic updates when editing Python files

## Requirements

- Neovim >= 0.5
- `nvim-treesitter` with Python parser installed

## Installation

### Using lazy.nvim

```lua
{
  'your-username/bracepy.nvim',  -- Replace with your actual repository
  ft = 'python',
  opts = {
    -- Optional: custom configuration
    enabled = true,
    show_function_braces = true,
    show_class_braces = true,
    show_loop_braces = true,
    show_conditional_braces = true,
    show_try_braces = true,
    brace_style = 'curly',  -- 'curly', 'square', 'round'
    highlight_group = 'Comment',
    position = 'end_of_line',  -- 'end_of_line', 'below_line', 'inline'
  },
}
```

**Alternative installation method (if adding directly to your config)**:
If you want to install the plugin directly in your Neovim config, place the `lua/bracepy` folder in your Neovim config directory (typically `~/.config/nvim/lua/bracepy/`).

### Using packer.nvim

```lua
use {
  'your-username/bracepy.nvim',
  ft = 'python',
  config = function()
    require('bracepy').setup({
      -- Configuration options here
    })
  end
}
```

## Usage

The plugin will automatically show virtual braces when visiting Python files.
You can also use these commands:

- `:BracePyUpdate` - Manually update the virtual braces
- `:BracePyToggle` - Toggle the plugin on/off

## Configuration

All configuration options with their defaults:

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
  icons = {                               -- Custom icons for different code blocks
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
  }
})
```

## Contributing

Feel free to submit issues and pull requests to improve the plugin.