return {
  "ibhagwan/fzf-lua",
  -- optional for icon support
  dependencies = { "nvim-tree/nvim-web-devicons" },
  -- or if using mini.icons/mini.nvim
  -- dependencies = { "nvim-mini/mini.icons" },
  ---@module "fzf-lua"
  ---@type fzf-lua.Config|{}
  ---
  config = function()
    require("fzf-lua").setup()

    local fzfLua = require("fzf-lua")

    vim.keymap.set("n", "<C-\\>", fzfLua.buffers)
    vim.keymap.set("n", "<C-f>", fzfLua.files)
    vim.keymap.set("n", "<C-g>", fzfLua.live_grep_native)
    vim.keymap.set("n", "<C-b>", fzfLua.builtin)
    vim.keymap.set("n", "<leader>r", fzfLua.resume)
  end,
}
