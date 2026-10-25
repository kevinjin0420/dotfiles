return {
  "gaoDean/autolist.nvim",
  ft = "markdown",
  opts = {},
  keys = {
    {
      "<CR>",
      function()
        -- fence_lang is set by the markdown indent autocmd; mini.pairs splits {} pairs in code
        if vim.b.fence_lang then
          return _G.MiniPairs and _G.MiniPairs.cr() or vim.keycode("<CR>")
        end
        return vim.keycode("<CR><cmd>AutolistNewBullet<cr>")
      end,
      mode = "i",
      ft = "markdown",
      expr = true,
      replace_keycodes = false,
    },
    { "o", "o<cmd>AutolistNewBullet<cr>", ft = "markdown" },
    { "O", "O<cmd>AutolistNewBulletBefore<cr>", ft = "markdown" },
    { ">>", ">><cmd>AutolistRecalculate<cr>", ft = "markdown" },
    { "<<", "<<<cmd>AutolistRecalculate<cr>", ft = "markdown" },
    { "dd", "dd<cmd>AutolistRecalculate<cr>", ft = "markdown" },
    { "d", "d<cmd>AutolistRecalculate<cr>", mode = "x", ft = "markdown" },
  },
}
