return {
  "gaoDean/autolist.nvim",
  ft = "markdown",
  opts = {},
  keys = {
    { "<CR>", "<CR><cmd>AutolistNewBullet<cr>", mode = "i", ft = "markdown" },
    { "o", "o<cmd>AutolistNewBullet<cr>", ft = "markdown" },
    { "O", "O<cmd>AutolistNewBulletBefore<cr>", ft = "markdown" },
    { ">>", ">><cmd>AutolistRecalculate<cr>", ft = "markdown" },
    { "<<", "<<<cmd>AutolistRecalculate<cr>", ft = "markdown" },
    { "dd", "dd<cmd>AutolistRecalculate<cr>", ft = "markdown" },
    { "d", "d<cmd>AutolistRecalculate<cr>", mode = "x", ft = "markdown" },
  },
}
