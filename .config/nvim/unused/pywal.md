return {
  {
    "AlphaTechnolog/pywal.nvim",
    name = "pywal",
    priority = 1000,
    config = function()
      local colors_file = "/home/florian/.cache/wal/colors-wal.vim"
      vim.api.nvim_command("source " .. colors_file)

      -- Force les couleurs
      vim.o.termguicolors = true
      vim.g.syntax_on = true

      -- Fonction pour réappliquer les couleurs
      local function reload_highlights()
        local highlights = {
          Normal = { fg = vim.g.foreground, bg = vim.g.background },
          Comment = { fg = vim.g.color8 },
          ColorColumn = { bg = vim.g.color8 },
          Added = { fg = vim.g.color11 },
          String = { fg = vim.g.color2 },
          Identifier = { fg = vim.g.color4 },
          Function = { fg = vim.g.color5 },
          Special = { fg = vim.g.color6 },
          Constant = { fg = vim.g.color1 },
          Statement = { fg = vim.g.color3 },
          PreProc = { fg = vim.g.color4 },
          Type = { fg = vim.g.color5 },
          LineNr = { fg = vim.g.color8 },
          Visual = { bg = vim.g.color8 },
          SpecialKey = { fg = vim.g.color7 },
          Directory = { fg = vim.g.color4 },
          MsgArea = { fg = vim.g.color11 },
          Cmdline = { fg = vim.g.color4 },
          CmdPrompt = { fg = vim.g.color11 },
          WildMenu = { fg = vim.g.color12 },
          QuickFixLine = { fg = vim.g.color11 },
          StatusLine = { fg = vim.g.color11 },
          TabLine = { fg = vim.g.color11 },
          WinBar = { fg = vim.g.color11 },
          WinBarNC = { fg = vim.g.color11 },
          Title = { fg = vim.g.color11 },
        }

        for group, colors in pairs(highlights) do
          vim.api.nvim_set_hl(0, group, colors)
        end
      end

      -- Réappliquer les couleurs après le chargement du thème
      require("pywal").setup({
        enable_wal = true,
        syntax_highlighting = true,
        use_cterm = true,
      })
      vim.cmd("colorscheme pywal")
      reload_highlights() -- Réappliquer les highlights ici
      vim.cmd("syntax on")
    end,
    lazy = false,
  },
}
