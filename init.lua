vim.cmd [[
  call plug#begin()
  Plug 'nvim-neo-tree/neo-tree.nvim', { 'branch': 'v3.x' }
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
  Plug 'HakonHarnes/img-clip.nvim'
  Plug '~/notes/nvim'
  Plug 'lervag/vimtex'
  Plug 'nvim-lualine/lualine.nvim'
  Plug 'justinhj/battery.nvim'
  Plug 'MunifTanjim/nui.nvim'
  Plug 'rcarriga/nvim-notify'
  Plug 'folke/noice.nvim'
  call plug#end()
]]


require('mini.icons').setup()
MiniIcons.mock_nvim_web_devicons()

local function copy_node_path(state)
  local node = state.tree:get_node()
  if node.type ~= "file" and node.type ~= "directory" then return end
  local path = node:get_id()
  vim.fn.setreg("+", path)
  vim.notify("Copied " .. path)
end

local binary_exts = {
  pdf = true, png = true, jpg = true, jpeg = true, gif = true, webp = true, avif = true,
  heic = true, bmp = true, tiff = true, ico = true, mp4 = true, mov = true, mkv = true,
  webm = true, mp3 = true, wav = true, flac = true, m4a = true, zip = true, docx = true,
  xlsx = true, pptx = true, key = true, pages = true, numbers = true,
}

-- known binary extension, or a NUL byte in the first 8KB (the same sniff git uses)
local function is_binary_file(path)
  if binary_exts[vim.fn.fnamemodify(path, ":e"):lower()] then return true end
  local f = io.open(path, "rb")
  if not f then return false end
  local head = f:read(8000) or ""
  f:close()
  return head:find("\0", 1, true) ~= nil
end

-- :Tree trees are position=current, which neo-tree opens files into in place;
-- send their files to the last editor window instead, like the sidebar does
local function open_node(state)
  local node = state.tree:get_node()
  if node.type ~= "file" or state.current_position ~= "current" then
    require("neo-tree.sources.filesystem.commands").open(state)
    return
  end
  local winid, is_neo_tree = require("neo-tree.utils").get_appropriate_window(state)
  if is_neo_tree then
    vim.cmd("botright vnew")
  else
    vim.api.nvim_set_current_win(winid)
  end
  vim.cmd.edit(vim.fn.fnameescape(node:get_id()))
end

local function go_to_dir(state)
  vim.ui.input({ prompt = "Go to folder: ", default = state.path .. "/", completion = "dir" }, function(input)
    if not input or input == "" then return end
    local path = vim.fn.fnamemodify(vim.fn.expand(input), ":p"):gsub("/$", "")
    if vim.fn.isdirectory(path) == 0 then
      vim.notify("Not a folder: " .. path, vim.log.levels.WARN)
      return
    end
    require("neo-tree.sources.filesystem").navigate(state, path)
  end)
end

require('neo-tree').setup({
  close_if_last_window = true,
  open_files_do_not_replace_types = { "terminal", "Trouble", "qf", "edgy", "notestree" },
  window = {
    mappings = {
      -- NERDTree-style `m` menu: press m, a popup lists the actions, press a letter to pick
      ["m"] = { "show_help", nowait = false, config = { title = "Menu", prefix_key = "m" } },
      ["ma"] = { "add", desc = "add file (end with / for a folder)", config = { show_path = "absolute" } },
      ["mA"] = { "add_directory", desc = "add folder", config = { show_path = "absolute" } },
      ["mm"] = { "move", desc = "move", config = { show_path = "absolute" } },
      ["mr"] = { "rename", desc = "rename" },
      ["mc"] = { "copy", desc = "copy", config = { show_path = "absolute" } },
      ["md"] = { "delete", desc = "delete" },
      ["my"] = { "copy_to_clipboard", desc = "yank (copy) to clipboard" },
      ["mx"] = { "cut_to_clipboard", desc = "cut to clipboard" },
      ["mp"] = { "paste_from_clipboard", desc = "paste from clipboard" },
      ["mi"] = { "show_file_details", desc = "file info" },
      ["Y"] = { copy_node_path, desc = "copy path to clipboard" },
      ["mY"] = { copy_node_path, desc = "copy path to clipboard" },
      -- file-changing actions only live in the `m` menu, so a stray keypress can't touch files
      ["a"] = "none",
      ["A"] = "none",
      ["d"] = "none",
      ["T"] = "none",
      ["U"] = "none",
      ["r"] = "none",
      ["y"] = "none",
      ["x"] = "none",
      ["p"] = "none",
      ["c"] = "none",
    },
  },
  filesystem = {
    -- refresh the tree when files change outside nvim (terminal, lazygit, claude)
    use_libuv_file_watcher = true,
    window = {
      mappings = {
        ["u"] = "navigate_up",
        ["mh"] = { "toggle_hidden", desc = "show/hide hidden files" },
        ["mg"] = { go_to_dir, desc = "go to folder (type a path)" },
        ["b"] = "none",
        ["<cr>"] = { open_node, desc = "open" },
        -- double-clicking the root folder goes up to its parent
        ["<2-LeftMouse>"] = { function(state)
          local node = state.tree:get_node()
          if node:get_depth() == 1 then
            require("neo-tree.sources.filesystem.commands").navigate_up(state)
          elseif node.type == "file" and is_binary_file(node:get_id()) then
            vim.cmd({ cmd = "Open", args = { node:get_id() } })
          else
            open_node(state)
          end
        end, desc = "open (binaries via :Open), or go up if on the root folder" },
      },
    },
  },
  default_component_configs = {
    indent = {
      expander_collapsed = '▸',
      expander_expanded = '▾',
    },
  },
})

-- neo-tree takes typed paths literally, so ~/foo would create a folder named "~"; expand it first
do
  local inputs = require("neo-tree.ui.inputs")
  local neo_input = inputs.input
  inputs.input = function(prompt, default_value, callback, ...)
    return neo_input(prompt, default_value, function(value)
      if type(value) == "string" and (value == "~" or value:sub(1, 2) == "~/") then
        value = vim.env.HOME .. value:sub(2)
      end
      callback(value)
    end, ...)
  end
end

-- :Tree [dir] stacks another independent tree under the lowest one in the sidebar
vim.api.nvim_create_user_command("Tree", function(opts)
  local dir = vim.fn.fnamemodify(vim.fn.expand(opts.args ~= "" and opts.args or vim.fn.getcwd()), ":p")
  local last
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree" then last = w end
  end
  if not last then
    vim.cmd("Neotree show dir=" .. vim.fn.fnameescape(dir))
    return
  end
  vim.api.nvim_set_current_win(last)
  -- neo-tree pins its window height, so unpin it or the split steals lines from the notes panel
  vim.wo[last].winfixheight = false
  vim.cmd(("belowright %dnew"):format(math.max(math.floor(vim.api.nvim_win_get_height(last) / 2), 1)))
  vim.wo[last].winfixheight = true
  vim.cmd("Neotree position=current dir=" .. vim.fn.fnameescape(dir))
end, { nargs = "?", complete = "dir" })

vim.api.nvim_create_autocmd("VimEnter", {
  pattern = "*",
  command = "Neotree show"
})

vim.api.nvim_create_autocmd("TabNew", {
  pattern = "*",
  command = "Neotree show"
})

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

-- Let a bell from a :terminal job through to the outer terminal, while keeping
-- every editing bell (end of buffer, bad command, completion, ...) silent.
-- Neovim defaults to belloff=all, which swallows terminal bells too; this is
-- that default list minus "term" and "shell".
vim.opt.belloff = "backspace,cursor,complete,copy,ctrlg,error,esc,hangul,lang,mess,showmatch,operator,register,spell,wildmode"

-- TERMINAL MODE ESC MAPPING
vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]])

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

-- Compat shim: nvim-treesitter's `master` branch is frozen for Neovim <=0.11
-- and its query_predicates.lua (set-lang-from-info-string!, downcase!, etc.)
-- assumes match[id] is a single TSNode. Neovim 0.12 dropped the old `all=false`
-- opt that used to collapse captures for it, so match[id] is now always a
-- TSNode[] list, which crashes those handlers (e.g. on markdown code fences).
-- Unwrap list captures back to a single node before handlers run.
do
  local tsquery = vim.treesitter.query
  local function unwrap_match(match)
    return setmetatable({}, {
      __index = function(_, id)
        local v = match[id]
        if type(v) == "table" then
          return v[#v]
        end
        return v
      end,
    })
  end

  local add_predicate = tsquery.add_predicate
  tsquery.add_predicate = function(name, handler, opts)
    add_predicate(name, function(match, ...)
      return handler(unwrap_match(match), ...)
    end, opts)
  end

  local add_directive = tsquery.add_directive
  tsquery.add_directive = function(name, handler, opts)
    add_directive(name, function(match, ...)
      return handler(unwrap_match(match), ...)
    end, opts)
  end
end

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

-- notes vault: Obsidian-style image paste + `notes` CLI wrapper

require('img-clip').setup({
  default = {
    dir_path = "media",
    relative_to_current_file = true,
    use_absolute_path = false,
    file_name = "%Y-%m-%d-%H-%M-%S",
    prompt_for_file_name = false,
  },
})
vim.keymap.set("n", "<leader>v", "<cmd>PasteImage<CR>", { desc = "paste image" })

do
  local ok, notes = pcall(require, "notes")   -- only if ~/notes is cloned
  if ok then notes.setup({ cli = "notes", prefix = "<leader>n" }) end
end

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

-- cmdline / messages in floating UI so lualine sits flush at the bottom

require('notify').setup({ background_colour = "#000000" })
require('noice').setup({
  cmdline = {
    view = "cmdline_popup",
  },
  lsp = {
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true,
    },
  },
  presets = {
    bottom_search = false,
    long_message_to_split = true,
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
    vim.ui.open(path)
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
  -- Tab 1: editor with Neo-tree
  vim.cmd("silent! TabooRename Editor")

  -- Tab 2: empty terminal "TR", no Neo-tree
  vim.cmd("silent! tabnew")
  vim.cmd("silent! Neotree close")
  vim.cmd("silent! terminal")
  vim.cmd("silent! TabooRename TR")

  -- Tab 3: claude, no Neo-tree
  vim.cmd("silent! tabnew")
  vim.cmd("silent! Neotree close")
  vim.cmd("silent! terminal")
  vim.cmd("silent! TabooRename Claude")
  vim.fn.chansend(vim.b.terminal_job_id, "claude\n")

  -- Tab 4: lazygit, no Neo-tree
  vim.cmd("silent! tabnew")
  vim.cmd("silent! Neotree close")
  vim.cmd("silent! terminal")
  vim.cmd("silent! TabooRename lazygit")
  vim.fn.chansend(vim.b.terminal_job_id, "lazygit\n")

  vim.cmd("silent! tabfirst")
  vim.cmd("redraw")

  -- `-c Start` runs before VimEnter, so Neo-tree isn't open on tab 1 yet.
  -- Defer the notes panel until the event loop so it docks under Neo-tree.
  vim.schedule(function()
    vim.cmd("silent! tabfirst")
    pcall(vim.cmd, "NotesTree")
    pcall(vim.cmd, "wincmd l")
  end)
end, {})

--close everything command
vim.api.nvim_create_user_command('Nuke', function()
  vim.cmd('wa')
  vim.cmd([[silent! bufdo if &buftype == 'terminal' | bd! | endif]])
  vim.cmd('silent! Neotree close')
  vim.cmd('xa')
end, {})

-- lowercase aliases for :Start and :Nuke
vim.cmd([[cnoreabbrev <expr> start (getcmdtype() == ':' && getcmdline() ==# 'start') ? 'Start' : 'start']])
vim.cmd([[cnoreabbrev <expr> nuke  (getcmdtype() == ':' && getcmdline() ==# 'nuke')  ? 'Nuke'  : 'nuke']])
