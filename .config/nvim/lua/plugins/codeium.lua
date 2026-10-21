-- Codeium / Windsurf (extra LazyVim ai.codeium) : suggestions IA pendant la frappe, compte Windsurf.
-- codeium.com renvoie désormais vers Devin : la connexion passe par windsurf.com (:Codeium Auth)
return {
  "Exafunction/codeium.nvim",
  opts = { api = { portal_url = "windsurf.com" } },
}
