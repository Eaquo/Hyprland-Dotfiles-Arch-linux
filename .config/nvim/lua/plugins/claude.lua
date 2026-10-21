-- Claude Code dans nvim (coder/claudecode.nvim, extra LazyVim ai.codeium/claudecode) : remplace
-- « :hsplit | terminal claude » — mais BRANCHÉ sur nvim (comme l'extension Windsurf/VS Code) :
-- Claude voit le fichier et la sélection, propose ses modifications en diff.
--
-- <leader>ac  l'espace de travail : Claude en bas, à sa droite un petit terminal (tests, débogage…),
--             dans le dossier du projet ; refaire <leader>ac referme les deux (les sessions restent)
-- <leader>at  seulement le petit terminal          <leader>af  aller dans Claude
-- <leader>as  envoyer la sélection                 <leader>ab  ajouter le fichier courant
-- <leader>aa / <leader>ad  accepter / refuser le diff         <leader>ar  reprendre une session
-- :Claude     pareil que <leader>ac
-- Alt+h/j/k/l passer d'une fenêtre à l'autre, même depuis un terminal (config/keymaps.lua)

local M = { buf = nil, win = nil }   -- le petit terminal de droite (gardé entre deux ouvertures)

local function claude_win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].buftype == "terminal" and vim.api.nvim_buf_get_name(b):match("claude") and b ~= M.buf then
      return w
    end
  end
end

-- ouvre le petit terminal à droite de la fenêtre de Claude (ou en bas s'il n'y a pas Claude)
local function open_side()
  if M.win and vim.api.nvim_win_is_valid(M.win) then return end
  local cw = claude_win()
  if cw then vim.api.nvim_set_current_win(cw); vim.cmd("rightbelow vsplit") else vim.cmd("botright split") end
  M.win = vim.api.nvim_get_current_win()
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    vim.api.nvim_win_set_buf(M.win, M.buf)
  else
    vim.cmd.lcd(LazyVim.root())                        -- le terminal démarre à la racine du projet
    vim.cmd("terminal " .. (vim.fn.executable("fish") == 1 and "fish" or "bash"))   -- fish : suggestions + Tab
    M.buf = vim.api.nvim_get_current_buf()
    vim.bo[M.buf].bufhidden = "hide"
    vim.b[M.buf].qb_side = true
    vim.api.nvim_buf_set_name(M.buf, "tests")
  end
  vim.wo[M.win].winfixwidth = true
  vim.api.nvim_win_set_width(M.win, math.floor(vim.o.columns * 0.34))
  vim.wo[M.win].number = false
  vim.wo[M.win].relativenumber = false
  if cw then vim.api.nvim_set_current_win(cw) end     -- on reste dans Claude
  vim.cmd("startinsert")
end

local function close_side()
  if M.win and vim.api.nvim_win_is_valid(M.win) then vim.api.nvim_win_close(M.win, true) end
  M.win = nil
end

local function workspace()
  require("lazy").load({ plugins = { "claudecode.nvim" } })   -- :Claude avant le 1er raccourci
  if claude_win() then                                  -- ouvert : on range tout
    close_side()
    vim.cmd("ClaudeCode")
    return
  end
  vim.cmd("ClaudeCode")
  vim.defer_fn(open_side, 150)                          -- laisse Claude créer sa fenêtre
end

return {
  "coder/claudecode.nvim",
  opts = {
    terminal = {
      provider = "snacks",
      snacks_win_opts = { position = "bottom", height = 0.35 },
      cwd_provider = function() return LazyVim.root() end,   -- Claude démarre à la racine du projet
    },
    diff_opts = { vertical_split = true, open_in_current_tab = true },
  },
  keys = {
    { "<leader>ac", workspace, desc = "Claude + terminal (espace de travail)" },
    { "<leader>at", function() if M.win and vim.api.nvim_win_is_valid(M.win) then close_side() else open_side() end end,
      desc = "Petit terminal (tests)" },
  },
  init = function()
    vim.api.nvim_create_user_command("Claude", workspace, { desc = "Claude en bas + terminal à droite" })
  end,
}
