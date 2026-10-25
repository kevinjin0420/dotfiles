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

-- 2 matches markdownlint MD007 and prettier list indentation; code fences get 4
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function(args)
    local function apply_indent_for_cursor()
      local ok, parser = pcall(vim.treesitter.get_parser, args.buf)
      local lang = "markdown"
      if ok and parser then
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        lang = parser:language_for_range({ row - 1, col, row - 1, col }):lang()
      end
      local in_fence = lang ~= "markdown" and lang ~= "markdown_inline"
      vim.b[args.buf].fence_lang = in_fence and lang or nil
      local width = in_fence and 4 or 2
      vim.bo[args.buf].shiftwidth = width
      vim.bo[args.buf].tabstop = width
      vim.bo[args.buf].softtabstop = width
      -- treesitter indent misplaces lines while injected C/C++ is still incomplete
      local c_like = lang == "c" or lang == "cpp"
      vim.bo[args.buf].cindent = c_like
      vim.bo[args.buf].indentexpr = c_like and "" or "v:lua.LazyVim.treesitter.indentexpr()"
    end
    apply_indent_for_cursor()
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter" }, {
      group = vim.api.nvim_create_augroup("markdown_fence_indent_" .. args.buf, { clear = true }),
      buffer = args.buf,
      callback = apply_indent_for_cursor,
    })
  end,
})