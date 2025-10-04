-- bracepy plugin entry point
-- This file is required to make it a proper Neovim plugin

local ok, bracepy = pcall(require, 'bracepy')
if not ok then
  vim.api.nvim_err_writeln("Could not load bracepy module")
  return
end

-- Create a command for users to manually update the braces
vim.api.nvim_create_user_command('BracePyUpdate', function()
  bracepy.manual_update()
end, { desc = 'Update Python virtual braces' })

-- Create a command to toggle the plugin
vim.api.nvim_create_user_command('BracePyToggle', function()
  bracepy.config.enabled = not bracepy.config.enabled
  if bracepy.config.enabled then
    vim.notify('BracePy enabled', vim.log.levels.INFO)
    bracepy.update_braces(vim.api.nvim_get_current_buf())
  else
    vim.notify('BracePy disabled', vim.log.levels.INFO)
    bracepy.cleanup()
  end
end, { desc = 'Toggle BracePy on/off' })

return bracepy