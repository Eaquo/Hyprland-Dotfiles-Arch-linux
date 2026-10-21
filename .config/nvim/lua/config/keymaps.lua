-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local keymap = vim.keymap
local opts = { noremap = true, silent = true }
local Util = require("lazyvim.util")

-- Borderless terminal
vim.keymap.set("n", "<C-/>", function()
  Util.terminal(nil, { border = "none" })
end, { desc = "Term with border" })

-- Borderless lazygit
vim.keymap.set("n", "<leader>gg", function()
  Util.terminal({ "lazygit" }, { cwd = Util.root(), esc_esc = false, ctrl_hjkl = false, border = "none" })
end, { desc = "Lazygit (root dir)" })

keymap.del({ "n", "i", "v" }, "<A-j>")
keymap.del({ "n", "i", "v" }, "<A-k>")
keymap.del("n", "<C-Left>")
keymap.del("n", "<C-Down>")
keymap.del("n", "<C-Up>")
keymap.del("n", "<C-Right>")

-- Passer d'une fenêtre à l'autre avec Alt+h/j/k/l, partout — même depuis un terminal (Claude, lazygit…)
-- où Ctrl+h/j/k/l sont gardés par le programme. (Ctrl+h/j/k/l restent actifs en mode normal, LazyVim.)
for key, dir in pairs({ h = "h", j = "j", k = "k", l = "l" }) do
  keymap.set({ "n", "t" }, "<M-" .. key .. ">", "<Cmd>wincmd " .. dir .. "<CR>", { desc = "Fenêtre " .. dir })
  keymap.set("i", "<M-" .. key .. ">", "<Esc><Cmd>wincmd " .. dir .. "<CR>", { desc = "Fenêtre " .. dir })
end

local set_keymap = vim.api.nvim_set_keymap

-- Split windows
keymap.set("n", "ss", ":vsplit<Return>", opts)
keymap.set("n", "sv", ":split<Return>", opts)

-- Tabs
keymap.set("n", "te", ":tabedit", opts)
keymap.set("n", "<tab>", ":tabnext<Return>", opts)
keymap.set("n", "<s-tab>", ":tabprev<Return>", opts)
