-- Thème « wallust » (colors/wallust.lua) : les couleurs suivent le fond d'écran comme le reste du système.
-- wallust réécrit ~/.cache/wallust/nvim-palette.lua → chaque nvim ouvert se recolore tout seul.
-- (ancien thème : cyberdream, voir ~/.config/nvim.bak-20261020)

local palette = vim.fn.expand("~/.cache/wallust/nvim-palette.lua")

-- surveille le dossier (wallust remplace le fichier : surveiller le fichier seul perdrait la trace)
local function watch()
  local w = vim.uv.new_fs_event()
  if not w then return end
  local pending = false
  w:start(vim.fn.fnamemodify(palette, ":h"), {}, function(_, name)
    if name ~= "nvim-palette.lua" or pending then return end
    pending = true
    vim.defer_fn(function()             -- laisse wallust finir d'écrire
      pending = false
      if vim.g.colors_name == "wallust" then vim.cmd.colorscheme("wallust") end
    end, 300)
  end)
end

return {
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "wallust" },
    init = function() vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = watch }) end,
  },
  -- numéro de ligne coloré selon le mode (normal, insertion, visuel…)
  {
    "mawkler/modicator.nvim",
    init = function()
      vim.o.cursorline = false
      vim.o.number = true
      vim.o.termguicolors = true
    end,
    opts = {},
  },
}
