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
  Plug 'ray-x/lsp_signature.nvim'
  Plug 'glepnir/lspsaga.nvim'
  Plug 'echasnovski/mini.icons'
  Plug 'MeanderingProgrammer/render-markdown.nvim'
  Plug 'lervag/vimtex'
  Plug 'nvim-lualine/lualine.nvim'
  Plug 'justinhj/battery.nvim'
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
vim.opt.showmode = false
vim.opt.cmdheight = 0

-- TERMINAL MODE ESC MAPPING
vim.keymap.set("t", "<S-Esc>", [[<C-\><C-n>]])

-- SPLIT NAVIGATION: Shift+Arrow moves focus between windows
vim.keymap.set("n", "<S-Up>",    "<C-w>k", {})
vim.keymap.set("n", "<S-Down>",  "<C-w>j", {})
vim.keymap.set("n", "<S-Left>",  "<C-w>h", {})
vim.keymap.set("n", "<S-Right>", "<C-w>l", {})
vim.keymap.set("t", "<S-Up>",    [[<C-\><C-n><C-w>k]], {})
vim.keymap.set("t", "<S-Down>",  [[<C-\><C-n><C-w>j]], {})
vim.keymap.set("t", "<S-Left>",  [[<C-\><C-n><C-w>h]], {})
vim.keymap.set("t", "<S-Right>", [[<C-\><C-n><C-w>l]], {})

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
    bg = "#000000",             
    bg_alt = "#000000",
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
  ensure_installed = { "cpp", "python", "markdown", "markdown_inline" },
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

require('render-markdown').setup({})
require('render-markdown').enable()

-- statusline

require('battery').setup({})
require('lualine').setup({
  options = {
    theme = 'cyberdream',
    globalstatus = true,
    section_separators = '',
    component_separators = '',
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff' },
    lualine_c = { 'filename' },
    lualine_x = { 'filetype' },
    lualine_y = { { require('battery').get_status_line } },
    lualine_z = { { function() return os.date('%H:%M') end } },
  },
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

-- LSP setup
local lspconfig = require('lspconfig')

-- Python LSP (pyright)
lspconfig.pyright.setup({
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "off",  -- or "off" to disable completely
        diagnosticSeverityOverrides = {
          reportGeneralTypeIssues = "none",
        },
      },
    },
  },
  on_attach = function(client, bufnr)
    -- Signature help while typing
    require('lsp_signature').on_attach({
      bind = true,
      floating_window = true,
      hint_enable = false,
    }, bufnr)
  end,
  capabilities = require('cmp_nvim_lsp').default_capabilities(),
})

vim.keymap.set('n', 'K', vim.lsp.buf.hover, {})
vim.keymap.set('n', 'gd', vim.lsp.buf.definition, {})
vim.keymap.set('n', 'vc', '<cmd>VimtexCompile<CR>', {})

for i = 1, 9 do
  vim.keymap.set('n', tostring(i), i .. 'gt', {})
end

-- vimtex
vim.g.vimtex_view_method = 'general'
vim.g.vimtex_view_general_viewer = 'true'
vim.api.nvim_create_autocmd('User', {
  pattern = 'VimtexEventView',
  callback = function() vim.cmd('Open ' .. vim.fn.expand('%:p:r') .. '.pdf') end,
})

-- CUSTOM COMMANDS
vim.api.nvim_create_user_command('Open', function(opts)
  local path = vim.fn.fnamemodify(opts.args ~= '' and opts.args or vim.fn.expand('%:p'), ':p')
  if vim.fn.has('mac') == 1 then
    local url = 'file://' .. path
    local b64 = vim.fn.system("printf '%s' " .. vim.fn.shellescape(url) .. " | base64 | tr -d '\\n'")
    io.write("\027]1337;OpenURL=:" .. b64 .. "\027\\")
    io.flush()
  else
    vim.fn.jobstart({ 'xdg-open', path }, { detach = true })
  end
end, { nargs = '?', complete = 'file' })


-- Claude
vim.api.nvim_create_user_command("Claude", function()
  vim.cmd("terminal")
  vim.cmd("TabooRename Claude")
  vim.fn.chansend(vim.b.terminal_job_id, "claude\n")
end, {})

-- startup command
vim.api.nvim_create_user_command("Start", function()
  -- Tab 1: editor with NERDTree
  vim.cmd("silent! TabooRename Editor")

  -- Tab 2: empty terminal "TR", no NERDTree
  vim.cmd("silent! tabnew")
  vim.cmd("silent! NERDTreeClose")
  vim.cmd("silent! terminal")
  vim.cmd("silent! TabooRename TR")

  -- Tab 3: claude, no NERDTree
  vim.cmd("silent! tabnew")
  vim.cmd("silent! NERDTreeClose")
  vim.cmd("silent! terminal")
  vim.cmd("silent! TabooRename Claude")
  vim.fn.chansend(vim.b.terminal_job_id, "claude\n")

  -- Tab 4: lazygit, no NERDTree
  vim.cmd("silent! tabnew")
  vim.cmd("silent! NERDTreeClose")
  vim.cmd("silent! terminal")
  vim.cmd("silent! TabooRename lazygit")
  vim.fn.chansend(vim.b.terminal_job_id, "lazygit\n")

  vim.cmd("silent! tabfirst")
  vim.cmd("redraw")
end, {})

--close everything command
vim.api.nvim_create_user_command('Nuke', function()
  vim.cmd('wa')
  vim.cmd([[silent! bufdo if &buftype == 'terminal' | bd! | endif]])
  vim.cmd('NERDTreeClose')
  vim.cmd('xa')
end, {})

-- lowercase aliases for :Start and :Nuke
vim.cmd([[cnoreabbrev <expr> start (getcmdtype() == ':' && getcmdline() ==# 'start') ? 'Start' : 'start']])
vim.cmd([[cnoreabbrev <expr> nuke  (getcmdtype() == ':' && getcmdline() ==# 'nuke')  ? 'Nuke'  : 'nuke']])
