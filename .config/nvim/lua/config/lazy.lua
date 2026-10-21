local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  -- bootstrap lazy.nvim
  -- stylua: ignore
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
    lazypath })
end
vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

require("lazy").setup({
  {
    "stevearc/dressing.nvim",
    opts = {},
  },
  spec = {
    -- add LazyVim and import its plugins
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- extras : seulement ce qui sert aux dotfiles (Lua, QML, bash, Python, TOML, JSON, YAML, Markdown,
    -- Hyprlang, rasi) — le web, Go, Java, Docker, les tests et le débogueur sont retirés (sauvegarde :
    -- ~/.config/nvim.bak-20261020). Les langages eux-mêmes : lua/plugins/lang.lua
    { import = "lazyvim.plugins.extras.ai.claudecode" },   -- Claude Code dans nvim (<leader>a…), voir plugins/claude.lua
    { import = "lazyvim.plugins.extras.ai.codeium" },      -- suggestions IA pendant la frappe (compte Windsurf, :Codeium Auth)
    { import = "lazyvim.plugins.extras.editor.fzf" },
    { import = "lazyvim.plugins.extras.editor.navic" },
    { import = "lazyvim.plugins.extras.formatting.prettier" },   -- JSON, YAML, Markdown, CSS
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.markdown" },
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.toml" },
    { import = "lazyvim.plugins.extras.lang.yaml" },
    { import = "lazyvim.plugins.extras.ui.treesitter-context" },
    { import = "lazyvim.plugins.extras.util.dot" },               -- Hyprlang, bash, rasi, kitty, fichiers de conf
    { import = "lazyvim.plugins.extras.util.mini-hipatterns" },   -- couleurs #rrggbb affichées dans le texte
    -- import/override with your plugins
    { import = "plugins" },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = { colorscheme = { "wallust", "habamax" } },
  checker = { enabled = true }, -- automatically check for plugin updates
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        "gzip",
        "matchit",
        "matchparen",
        "netrwPlugin",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

