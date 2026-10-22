-- lualine component: "956 words | 3.8 min reading time" for prose buffers.
-- tex goes through texcount (prose only, follows \input/\include from this file down);
-- markdown and plain text are counted here with code, links and markup stripped.

local M = {}

local WORDS_PER_MINUTE = 250
local DEBOUNCE_MS = 400
local FILETYPES = { markdown = true, tex = true, plaintex = true, text = true }

local timers = {}

local function count_words(text)
  local n = 0
  for token in text:gmatch("%S+") do
    if token:find("[%w\128-\255]") then n = n + 1 end
  end
  return n
end

local function strip_markdown(text)
  text = text:gsub("^%-%-%-\n.-\n%-%-%-\n", "")
  text = text:gsub("\n```.-\n```", "\n")
  text = text:gsub("^```.-\n```", "")
  text = text:gsub("`[^`\n]*`", "")
  text = text:gsub("<!%-%-.-%-%->", "")
  text = text:gsub("!%[[^%]]*%]%b()", "")
  text = text:gsub("%[([^%]]*)%]%b()", "%1")
  text = text:gsub("%[%[([^%]|]*)|?([^%]]*)%]%]", function(target, alias)
    return alias ~= "" and alias or target
  end)
  text = text:gsub("<[^>\n]+>", "")
  text = text:gsub("https?://%S+", "")
  return text
end

-- rough fallback for machines without texcount
local function strip_tex(text)
  text = text:gsub("\\%%", "")
  text = text:gsub("%%[^\n]*", "")
  text = text:gsub("\\begin{(%a+%*?)}.-\\end{%1}", function(env)
    return (env:match("^equation") or env:match("^align") or env:match("^figure") or env:match("^table")) and "" or nil
  end)
  text = text:gsub("%$%$.-%$%$", "")
  text = text:gsub("%$.-%$", "")
  text = text:gsub("\\%a+%*?%b[]", "")
  text = text:gsub("\\(%a+)%*?%b{}", function(cmd)
    return (cmd:match("cite") or cmd:match("ref") or cmd == "label" or cmd == "begin" or cmd == "end"
      or cmd == "input" or cmd == "include" or cmd:match("^use") or cmd == "documentclass") and "" or nil
  end)
  text = text:gsub("\\%a+%*?", "")
  text = text:gsub("[{}]", " ")
  return text
end

local function set_count(buf, words)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.b[buf].prose_word_count = words
  require("lualine").refresh({ place = { "statusline" } })
end

local function update(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local ft = vim.bo[buf].filetype
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")

  if ft == "markdown" then
    set_count(buf, count_words(strip_markdown(text)))
  elseif ft == "tex" or ft == "plaintex" then
    if vim.fn.executable("texcount") == 0 then
      set_count(buf, count_words(strip_tex(text)))
      return
    end
    local dir = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
    if not dir or dir == "" or dir == "." then dir = vim.fn.getcwd() end
    vim.system(
      { "texcount", "-inc", "-sum", "-1", "-q", "-dir=" .. dir .. "/", "-" },
      { stdin = text, text = true },
      function(out)
        local words = tonumber((out.stdout or ""):match("^%s*(%d+)"))
        if words then vim.schedule(function() set_count(buf, words) end) end
      end
    )
  else
    set_count(buf, count_words(text))
  end
end

local function schedule_update(buf)
  if timers[buf] then timers[buf]:stop() end
  timers[buf] = vim.defer_fn(function()
    timers[buf] = nil
    update(buf)
  end, DEBOUNCE_MS)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("prose_stats", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FileType" }, {
    group = group,
    callback = function(args)
      if FILETYPES[vim.bo[args.buf].filetype] then update(args.buf) end
    end,
  })
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    callback = function(args)
      if FILETYPES[vim.bo[args.buf].filetype] then schedule_update(args.buf) end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      if timers[args.buf] then timers[args.buf]:stop() end
      timers[args.buf] = nil
    end,
  })
end

M.component = {
  function()
    local words = vim.b.prose_word_count
    if not words then return "" end
    return string.format("%d words | %.1f min reading time", words, words / WORDS_PER_MINUTE)
  end,
  cond = function()
    return FILETYPES[vim.bo.filetype] == true
  end,
}

return M
