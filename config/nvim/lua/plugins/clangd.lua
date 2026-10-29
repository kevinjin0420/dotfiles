return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=iwyu",
          "--completion-style=detailed",
          "--function-arg-placeholders",
          "--fallback-style=llvm",
          -- lets clangd ask cross compilers for their libstdc++ and newlib include paths
          "--query-driver=/opt/st/**/arm-none-eabi-*",
        },
      },
    },
  },
}
