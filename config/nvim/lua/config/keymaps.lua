-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Disable arrow keys to force hjkl usage
local disabled_modes = { "n", "v" }
local arrow_keys = { "<Up>", "<Down>", "<Left>", "<Right>" }
for _, mode in ipairs(disabled_modes) do
  for _, key in ipairs(arrow_keys) do
    vim.keymap.set(mode, key, "<Nop>", { desc = "Disabled arrow key" })
  end
end
