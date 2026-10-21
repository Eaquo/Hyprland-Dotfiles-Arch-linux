-- lang.lua — les langages des dotfiles : Lua (Hyprland), QML (Quickshell), bash/zsh, Python, TOML,
-- JSON/YAML, Markdown, Hyprlang. Un seul endroit pour les serveurs (LSP), Mason, treesitter et le formatage.

return {
  -- ── Serveurs de langage ────────────────────────────────────────────────────
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        lua_ls = {
          settings = {
            Lua = {
              -- hl = l'API Lua de Hyprland (hl.bind, hl.dsp…) : plus de « undefined global »
              diagnostics = { globals = { "vim", "hl" } },
              workspace = { checkThirdParty = false },
              telemetry = { enable = false },
            },
          },
        },
        -- QML : qmlls de Qt 6. Quickshell remplit lui-même les chemins de ses types dans le
        -- .qmlls.ini (vide au départ) placé à la racine de la config (Quick-Bar/.qmlls.ini)
        qmlls = { cmd = { "qmlls6" }, mason = false },
        bashls = { filetypes = { "sh", "bash", "zsh" } },   -- shellcheck utilisé tout seul s'il est installé
        hyprls = {},                                         -- hyprland.conf, hyprlock.conf, hypridle.conf…
      },
    },
  },

  -- ── Outils installés par Mason (:Mason) ─────────────────────────────────────
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "lua-language-server", "stylua",
        "bash-language-server", "shellcheck", "shfmt",
        "pyright", "ruff",
        "taplo", "json-lsp", "yaml-language-server",
        "marksman", "markdownlint-cli2", "prettier",
        "hyprls",
      },
    },
  },

  -- ── Coloration syntaxique ───────────────────────────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "lua", "luadoc", "bash", "python", "qmljs", "toml", "json", "jsonc", "yaml",
        "markdown", "markdown_inline", "hyprlang", "rasi", "css", "regex", "vim", "vimdoc", "query",
      },
    },
  },

  -- ── Formatage : à la main (<leader>mp), jamais à la sauvegarde ──────────────
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        lua = { "stylua" },
        sh = { "shfmt" }, bash = { "shfmt" }, zsh = { "shfmt" },
        python = { "ruff_fix", "ruff_format" },
        toml = { "taplo" },
        json = { "prettier" }, jsonc = { "prettier" }, yaml = { "prettier" },
        markdown = { "prettier" }, css = { "prettier" },
      },
      formatters = {
        shfmt = { prepend_args = { "-i", "4", "-ci" } },   -- 4 espaces, comme les scripts Quick-Bar
      },
    },
    keys = {
      { "<leader>mp", function() require("conform").format({ lsp_format = "fallback" }) end,
        mode = { "n", "v" }, desc = "Formater le fichier (ou la sélection)" },
    },
  },
}
