return {
    {
        "jmbuhr/otter.nvim",
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        ft = "markdown",
        opts = { lsp = { diagnostic_update_events = { "BufWritePost", "InsertLeave", "TextChanged" } } },
        config = function(_, opts)
            local otter = require("otter")
            otter.setup(opts)
            vim.api.nvim_create_autocmd("FileType", {
                pattern = "markdown",
                callback = function()
                    otter.activate({ "c", "cpp" })
                end,
            })
            if vim.bo.filetype == "markdown" then
                otter.activate({ "c", "cpp" })
            end
        end,
    },
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                clangd = {
                    handlers = {
                        -- markdown snippets are fragments, so compile errors are noise; keep lint and warnings
                        ["textDocument/publishDiagnostics"] = function(err, result, ctx)
                            if result and result.uri:match("%.otter%.[%a+]+$") then
                                result.diagnostics = vim.tbl_filter(function(diagnostic)
                                    return not (diagnostic.source == "clang" and diagnostic.severity == 1)
                                end, result.diagnostics)
                            end
                            vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
                        end,
                    },
                },
            },
        },
    },
    {
        "mason-org/mason.nvim",
        opts = { ensure_installed = { "clang-format" } },
    },
    {
        "stevearc/conform.nvim",
        optional = true,
        opts = function(_, opts)
            opts.formatters_by_ft = opts.formatters_by_ft or {}
            local markdown_formatters = opts.formatters_by_ft.markdown or {}
            table.insert(markdown_formatters, "injected")
            opts.formatters_by_ft.markdown = markdown_formatters
            opts.formatters = opts.formatters or {}
            opts.formatters.injected = {
                options = { lang_to_formatters = { c = { "clang-format" }, cpp = { "clang-format" } } },
            }
        end,
    },
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
