local function shift_markdown_list_item(indent_key)
  return function()
    if vim.bo.filetype ~= "markdown" then
      return false
    end
    local line = vim.api.nvim_get_current_line()
    if not (line:match("^%s*[-*+]%s") or line:match("^%s*%d+[.)]%s")) then
      return false
    end
    vim.api.nvim_feedkeys(vim.keycode(indent_key), "ni", false)
    vim.schedule(function()
      require("autolist.auto").recalculate()
    end)
    return true
  end
end

return {
  "saghen/blink.cmp",
  opts = function(_, opts)
    -- LazyVim only builds its super-tab <Tab> chain when <Tab> is unset, so it is rebuilt here
    opts.keymap = vim.tbl_extend("force", opts.keymap or {}, {
      preset = "super-tab",
      ["<Tab>"] = {
        require("blink.cmp.keymap.presets").get("super-tab")["<Tab>"][1],
        LazyVim.cmp.map({ "snippet_forward", "ai_nes", "ai_accept" }),
        shift_markdown_list_item("<C-t>"),
        "fallback",
      },
      ["<S-Tab>"] = { "snippet_backward", shift_markdown_list_item("<C-d>"), "fallback" },
    })
  end,
}
