return {
    {
        "mfussenegger/nvim-lint",
        optional = true,
        opts = {
            linters = {
                ["markdownlint-cli2"] = {
                    args = { "--config", vim.fn.stdpath("config") .. "/.markdownlint-cli2.yaml", "-" },
                },
            },
        },
    },
    -- {
    --     "MeanderingProgrammer/render-markdown.nvim",
    --     optional = true,
    --     opts = {
    --         code = { border = "none", language = false, conceal_delimiters = false },
    --         win_options = { conceallevel = { rendered = 0 } },
    --     },
    -- },
}
