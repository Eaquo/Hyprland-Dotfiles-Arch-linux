return {
  "oncomouse/lushwal.nvim",
  lazy = false,
  priority = 1001,
  cmd = { "LushwalCompile" },
  dependencies = {
    { "rktjmp/lush.nvim" },
    { "rktjmp/shipwright.nvim" },
  },
  {
    "LazyVim/LazyVim",
    opt = {
      colorscheme = "lushwal",
    },
  },
}
