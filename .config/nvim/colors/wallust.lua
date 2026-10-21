-- colors/wallust.lua — thème nvim qui suit le fond d'écran, comme Quick-Bar, kitty, rofi…
-- Palette : ~/.cache/wallust/nvim-palette.lua (modèle ~/.config/wallust/templates/nvim-palette.lua).
-- Accent = color11 (comme Quick-Bar) ; fond transparent ; une couleur trop sombre pour le fond est
-- éclaircie jusqu'à rester lisible (même règle que la barre). Rechargé tout seul : plugins/wallust.lua.

local path = vim.fn.expand("~/.cache/wallust/nvim-palette.lua")
local ok, p = pcall(dofile, path)
if not ok or type(p) ~= "table" then
  vim.notify("wallust : palette introuvable (" .. path .. ") — lance wallust une fois", vim.log.levels.WARN)
  vim.cmd.colorscheme("habamax")
  return
end

-- ── outils de couleur ───────────────────────────────────────────────────────
local function rgb(h) return tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16) end
local function hex(r, g, b) return string.format("#%02x%02x%02x", r, g, b) end
local function mix(a, b, t)            -- a vers b, t ∈ [0, 1]
  local r1, g1, b1 = rgb(a); local r2, g2, b2 = rgb(b)
  return hex(math.floor(r1 + (r2 - r1) * t + 0.5), math.floor(g1 + (g2 - g1) * t + 0.5), math.floor(b1 + (b2 - b1) * t + 0.5))
end
local function lum(h)
  local function c(v) v = v / 255; return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
  local r, g, b = rgb(h); return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b)
end
local function contrast(a, b) local x, y = lum(a), lum(b); if x < y then x, y = y, x end; return (x + 0.05) / (y + 0.05) end
local bg = p.background
local function vis(h, min)             -- éclaircit h jusqu'au contraste voulu sur le fond
  min = min or 4.0
  local t = 0
  while contrast(h, bg) < min and t < 1 do t = t + 0.08; h = mix(h, "#ffffff", 0.08) end
  return h
end

-- ── rôles ───────────────────────────────────────────────────────────────────
local c = {
  bg = bg, fg = vis(p.foreground, 7),
  dim = vis(p.color8, 3), faint = mix(bg, p.foreground, 0.12), line = mix(bg, p.foreground, 0.06),
  accent = vis(p.color11, 4.5),
  red = vis(p.color9), orange = vis(p.color3), yellow = vis(p.color11), green = vis(p.color10),
  cyan = vis(p.color14), blue = vis(p.color12), purple = vis(p.color13), pink = vis(p.color5),
}
c.sel = mix(bg, c.accent, 0.28)
c.float = mix(bg, "#000000", 0.25)

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
vim.o.termguicolors = true
vim.o.background = lum(bg) < 0.4 and "dark" or "light"
vim.g.colors_name = "wallust"
vim.g.wallust = c                       -- pour lualine & co.

local function hl(group, spec) vim.api.nvim_set_hl(0, group, spec) end
local NONE = "NONE"

-- ── interface ───────────────────────────────────────────────────────────────
hl("Normal", { fg = c.fg, bg = NONE })
hl("NormalNC", { fg = c.fg, bg = NONE })
hl("NormalFloat", { fg = c.fg, bg = c.float })
hl("FloatBorder", { fg = c.accent, bg = c.float })
hl("FloatTitle", { fg = c.bg, bg = c.accent, bold = true })
hl("SignColumn", { bg = NONE })
hl("LineNr", { fg = c.faint })
hl("CursorLineNr", { fg = c.accent, bold = true })
hl("CursorLine", { bg = c.line })
hl("ColorColumn", { bg = c.line })
hl("Visual", { bg = c.sel })
hl("Search", { fg = c.bg, bg = c.yellow })
hl("IncSearch", { fg = c.bg, bg = c.accent, bold = true })
hl("CurSearch", { link = "IncSearch" })
hl("MatchParen", { fg = c.accent, bold = true, underline = true })
hl("Pmenu", { fg = c.fg, bg = c.float })
hl("PmenuSel", { fg = c.bg, bg = c.accent, bold = true })
hl("PmenuSbar", { bg = c.float })
hl("PmenuThumb", { bg = c.accent })
hl("StatusLine", { fg = c.fg, bg = NONE })
hl("StatusLineNC", { fg = c.dim, bg = NONE })
hl("WinSeparator", { fg = c.faint })
hl("VertSplit", { link = "WinSeparator" })
hl("TabLine", { fg = c.dim, bg = NONE })
hl("TabLineSel", { fg = c.bg, bg = c.accent, bold = true })
hl("TabLineFill", { bg = NONE })
hl("Folded", { fg = c.dim, bg = c.line })
hl("NonText", { fg = c.faint })
hl("Whitespace", { fg = c.faint })
hl("EndOfBuffer", { fg = bg })
hl("Directory", { fg = c.blue })
hl("Title", { fg = c.accent, bold = true })
hl("ErrorMsg", { fg = c.red, bold = true })
hl("WarningMsg", { fg = c.orange })
hl("MoreMsg", { fg = c.green })
hl("Question", { fg = c.cyan })
hl("WildMenu", { link = "PmenuSel" })

-- ── syntaxe ─────────────────────────────────────────────────────────────────
hl("Comment", { fg = c.dim, italic = true })
hl("Constant", { fg = c.orange })
hl("String", { fg = c.green })
hl("Character", { fg = c.green })
hl("Number", { fg = c.orange })
hl("Boolean", { fg = c.orange, bold = true })
hl("Identifier", { fg = c.fg })
hl("Function", { fg = c.blue })
hl("Statement", { fg = c.purple })
hl("Keyword", { fg = c.purple, italic = true })
hl("Conditional", { fg = c.purple })
hl("Repeat", { fg = c.purple })
hl("Operator", { fg = c.cyan })
hl("PreProc", { fg = c.pink })
hl("Type", { fg = c.yellow })
hl("Special", { fg = c.cyan })
hl("Delimiter", { fg = c.dim })
hl("Todo", { fg = c.bg, bg = c.accent, bold = true })
hl("Error", { fg = c.red })
hl("Underlined", { underline = true })

-- treesitter → groupes ci-dessus
for k, v in pairs({
  ["@variable"] = "Identifier", ["@variable.builtin"] = "Special", ["@variable.parameter"] = "Identifier",
  ["@variable.member"] = "Identifier", ["@property"] = "Identifier", ["@field"] = "Identifier",
  ["@constant"] = "Constant", ["@constant.builtin"] = "Constant", ["@string"] = "String",
  ["@string.escape"] = "Special", ["@number"] = "Number", ["@boolean"] = "Boolean",
  ["@function"] = "Function", ["@function.call"] = "Function", ["@function.builtin"] = "Special",
  ["@function.method"] = "Function", ["@function.method.call"] = "Function", ["@constructor"] = "Type",
  ["@keyword"] = "Keyword", ["@keyword.function"] = "Keyword", ["@keyword.return"] = "Keyword",
  ["@keyword.import"] = "PreProc", ["@conditional"] = "Conditional", ["@repeat"] = "Repeat",
  ["@operator"] = "Operator", ["@punctuation"] = "Delimiter", ["@punctuation.bracket"] = "Delimiter",
  ["@type"] = "Type", ["@type.builtin"] = "Type", ["@module"] = "PreProc", ["@attribute"] = "PreProc",
  ["@tag"] = "Keyword", ["@tag.attribute"] = "Identifier", ["@comment"] = "Comment",
  ["@markup.heading"] = "Title", ["@markup.link"] = "Underlined", ["@markup.raw"] = "String",
}) do hl(k, { link = v }) end

-- ── diagnostics, diff, git ──────────────────────────────────────────────────
hl("DiagnosticError", { fg = c.red })
hl("DiagnosticWarn", { fg = c.orange })
hl("DiagnosticInfo", { fg = c.blue })
hl("DiagnosticHint", { fg = c.cyan })
hl("DiagnosticOk", { fg = c.green })
for _, k in ipairs({ "Error", "Warn", "Info", "Hint" }) do
  local col = ({ Error = c.red, Warn = c.orange, Info = c.blue, Hint = c.cyan })[k]
  hl("DiagnosticUnderline" .. k, { undercurl = true, sp = col })
  hl("DiagnosticVirtualText" .. k, { fg = col, bg = mix(bg, col, 0.10), italic = true })
end
hl("DiffAdd", { bg = mix(bg, c.green, 0.18) })
hl("DiffChange", { bg = mix(bg, c.blue, 0.14) })
hl("DiffDelete", { bg = mix(bg, c.red, 0.18) })
hl("DiffText", { bg = mix(bg, c.blue, 0.30) })
hl("GitSignsAdd", { fg = c.green })
hl("GitSignsChange", { fg = c.blue })
hl("GitSignsDelete", { fg = c.red })
hl("LspReferenceText", { bg = c.line })
hl("LspReferenceRead", { bg = c.line })
hl("LspReferenceWrite", { bg = c.line, underline = true })
hl("LspInlayHint", { fg = c.faint, italic = true })

-- ── plugins (neo-tree, which-key, blink, snacks, noice, fzf) ────────────────
hl("NeoTreeNormal", { fg = c.fg, bg = NONE })
hl("NeoTreeNormalNC", { fg = c.fg, bg = NONE })
hl("NeoTreeDirectoryIcon", { fg = c.accent })
hl("NeoTreeDirectoryName", { fg = c.blue })
hl("NeoTreeRootName", { fg = c.accent, bold = true })
hl("NeoTreeGitModified", { fg = c.orange })
hl("NeoTreeGitAdded", { fg = c.green })
hl("WhichKey", { fg = c.accent })
hl("WhichKeyGroup", { fg = c.blue })
hl("WhichKeyDesc", { fg = c.fg })
hl("WhichKeyBorder", { link = "FloatBorder" })
hl("BlinkCmpMenu", { link = "Pmenu" })
hl("BlinkCmpMenuBorder", { link = "FloatBorder" })
hl("BlinkCmpMenuSelection", { link = "PmenuSel" })
hl("BlinkCmpDocBorder", { link = "FloatBorder" })
hl("BlinkCmpLabelMatch", { fg = c.accent, bold = true })
hl("SnacksPickerMatch", { fg = c.accent, bold = true })
hl("SnacksPickerBorder", { link = "FloatBorder" })
hl("SnacksDashboardHeader", { fg = c.accent })
hl("SnacksDashboardKey", { fg = c.accent, bold = true })
hl("NoiceCmdlinePopupBorder", { link = "FloatBorder" })
hl("NoiceCmdlineIcon", { fg = c.accent })
hl("FzfLuaBorder", { link = "FloatBorder" })
hl("FzfLuaTitle", { link = "FloatTitle" })
hl("MiniIndentscopeSymbol", { fg = c.accent })
hl("TreesitterContext", { bg = c.line })
