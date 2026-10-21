-- Autocmds (chargés par LazyVim à l'événement VeryLazy)

-- kitty : pas de pluie matrix derrière le code. À l'ouverture de nvim (et au retour de Ctrl+Z), son kitty
-- ne garde que la traînée du curseur ; à la sortie (ou Ctrl+Z), kitty relit sa config → shader rétabli.
-- (allow_remote_control yes dans kitty.conf ; seul le kitty de ce nvim est touché)
if vim.env.KITTY_WINDOW_ID and vim.fn.executable("kitty") == 1 then
  local function kitty(args) vim.system(vim.list_extend({ "kitty", "@" }, args), { text = true }) end
  local calm = function() kitty({ "load-config", "--override", "custom_shaders=cursor-trail-wallust" }) end
  local restore = function() kitty({ "load-config" }) end
  local g = vim.api.nvim_create_augroup("kitty_shader", { clear = true })
  vim.api.nvim_create_autocmd("VimResume", { group = g, callback = calm })
  vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, { group = g, callback = restore })
  calm()                                   -- ce fichier est chargé juste après l'ouverture (VeryLazy)
end
