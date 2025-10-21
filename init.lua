vim.cmd [[
  call plug#begin()
  Plug 'scrooloose/nerdtree'
  Plug 'gcmt/taboo.vim'
  Plug 'hrsh7th/nvim-cmp'
  Plug 'hrsh7th/cmp-buffer'
  Plug 'hrsh7th/cmp-path'
  Plug 'hrsh7th/cmp-nvim-lsp'
  Plug 'hrsh7th/cmp-cmdline'
  Plug 'neovim/nvim-lspconfig'
  Plug 'nvim-treesitter/nvim-treesitter'
  Plug 'nvimtools/none-ls.nvim'
  Plug 'nvim-lua/plenary.nvim'
  Plug 'scottmckendry/cyberdream.nvim'
  call plug#end()
]]

vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  command = "NERDTree | wincmd p"
})

vim.api.nvim_create_autocmd("TabNew", {
  pattern = "*",
  command = "NERDTree | wincmd p"
})

vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  command = [[if tabpagenr('$') == 1 && winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree() | quit | endif]]
})

vim.g.NERDTreeDirArrowExpandable = '▸'
vim.g.NERDTreeDirArrowCollapsible = '▾'

-- GENERAL EDITOR SETTINGS

vim.o.termguicolors = true
vim.cmd("syntax enable")
vim.cmd("filetype plugin indent on")
vim.opt.mouse = 'a'
vim.opt.clipboard:append { 'unnamed', 'unnamedplus' }
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.number = true
vim.opt.hlsearch = false

-- TERMINAL MODE ESC MAPPING
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])

require("cyberdream").setup({
    transparent = false,

    -- Reduce the overall saturation of colours for a more muted look
    saturation = 0.6, -- accepts a value between 0 and 1. 0 will be fully desaturated (greyscale) and 1 will be the full color (default)

    -- Enable italics comments
    italic_comments = true,

    -- Replace all fillchars with ' ' for the ultimate clean look
    hide_fillchars = false,

    -- Apply a modern borderless look to pickers like Telescope, Snacks Picker & Fzf-Lua
    borderless_pickers = false,

    -- Set terminal colors used in `:terminal`
    terminal_colors = true,

    -- Disable or enable colorscheme extensions
    extensions = {
        telescope = true,
        notify = true,
        mini = true,
    },

colors = {
    bg = "#171421",             
    bg_alt = "#171421",
    bg_highlight = "#586e75",
    bg_solid = "#000000",
    fg = "#e6ffe6",
    grey = "#839496",
    blue = "#268bd2",
    green = "#82f042",
    cyan = "#2aa198",
    red = "#99ffcc",
    yellow = "#EFA110",
    magenta = "#99ffcc",
    pink = "#99ffcc",
    orange = "#EFA110",
    purple = "#EFA110",
}
})


vim.cmd("colorscheme cyberdream")


vim.api.nvim_set_hl(0, "@type",         { fg = "#EFA110", italic = true })
vim.api.nvim_set_hl(0, "@type.builtin", { fg = "#EFA110", italic = true })
vim.api.nvim_set_hl(0, "Constant", { fg = "#EFA110" })
vim.api.nvim_set_hl(0, "String", { fg = "#EFA110" })

-- syntax highlighting

require'nvim-treesitter.configs'.setup {
  ensure_installed = { "cpp", "python" },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = false,
  },
}

-- formatting

local null_ls = require("null-ls")

null_ls.setup({
  sources = {
    null_ls.builtins.formatting.clang_format,
    null_ls.builtins.formatting.black.with({
      extra_args = { "--fast" }  -- optional, makes black faster
    }),
  },
  on_attach = function(client, bufnr)
    if client:supports_method("textDocument/formatting") then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({ bufnr = bufnr, async = false })
        end,
      })
    end
  end,
})

-- autocomplete

local cmp = require('cmp')

cmp.setup({
  mapping = {
    ['<Tab>'] = function(fallback)
      if cmp.visible() then
        cmp.select_next_item({ behavior = cmp.SelectBehavior.Insert })
      else
        fallback()
      end
    end,

    ['<S-Tab>'] = function(fallback)
      if cmp.visible() then
        cmp.select_prev_item({ behavior = cmp.SelectBehavior.Insert })
      else
        fallback()
      end
    end,

    ['<CR>'] = cmp.mapping.confirm({ select = true }),
  },

  sources = {
    { name = 'nvim_lsp' },
    { name = 'buffer' },
    { name = 'path' },
  }
})

-- CUSTOM COMMANDS
-- Claude
vim.api.nvim_create_user_command("Claude", function()
  vim.cmd("terminal")
  vim.cmd("TabooRename Claude")
  vim.fn.chansend(vim.b.terminal_job_id, "claude\n")
end, {})

-- startup command
vim.api.nvim_create_user_command("Start", function()
  vim.cmd("TabooRename Editor")
  vim.cmd("tabnew")
  vim.cmd("Claude")
  vim.cmd("tabnew")
  vim.cmd("TabooRename notes")
end, {})

--close everything command
vim.api.nvim_create_user_command('Nuke', function()
  vim.cmd('wa')
  vim.cmd([[silent! bufdo if &buftype == 'terminal' | bd! | endif]])
  vim.cmd('NERDTreeClose')
  vim.cmd('xa')
end, {})
