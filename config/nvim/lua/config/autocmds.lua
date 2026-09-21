-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local latex_compile_group = vim.api.nvim_create_augroup("latex_compile_on_save", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
  group = latex_compile_group,
  pattern = "*.tex",
  callback = function()
    vim.fn.jobstart({ "latexmk", "-pdf", "-interaction=nonstopmode", vim.fn.expand("%") }, {
      cwd = vim.fn.expand("%:p:h"),
    })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = latex_compile_group,
  pattern = "tex",
  callback = function(args)
    vim.api.nvim_buf_create_user_command(args.buf, "TexView", function()
      local pdf = vim.fn.expand("%:p:r") .. ".pdf"
      local line = vim.fn.line(".")
      vim.fn.jobstart({ "zathura", "--synctex-forward", line .. ":1:" .. vim.fn.expand("%:p"), pdf }, {
        detach = true,
      })
    end, { desc = "Open PDF in Zathura (synctex forward)" })
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "tex" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})
