-- nvim-cmp source: fuzzy-complete citation keys inside \cite{...} by key, title,
-- authors, year, venue or abstract, from .bib files in the current file's folder
-- and its parents. Multi-word queries work: \cite{cross entropy 1999
--
-- External .bib files (a Zotero export, another project's bib) are searched too, from
-- `source = path` lines in the nearest .bibcite above the current file and then in
-- ~/.config/bibcite/config. Confirming a key that only an external source has copies
-- its entry into the project's bib: `target = path` in .bibcite, else the nearest .bib.

local M = {}

local GLOBAL_CONFIG = vim.fn.expand("~/.config/bibcite/config")
local PROJECT_CONFIG = ".bibcite"
local MAX_PARENT_LEVELS = 4
-- standard BibTeX fields kept when an external entry is copied into a project bib; reference
-- manager fields (file, keywords, urldate, shorttitle, langid, copyright, ...) stay in the source
local COPY_FIELDS = {
  author = true, title = true, year = true, month = true, abstract = true,
  journal = true, booktitle = true, editor = true, edition = true, series = true, chapter = true,
  volume = true, number = true, pages = true, type = true, note = true, howpublished = true,
  publisher = true, address = true, organization = true, institution = true, school = true,
  isbn = true, issn = true, doi = true, url = true, eprint = true, archiveprefix = true, primaryclass = true,
}
local MAX_ITEMS = 200
local FIELD_WEIGHTS = {
  key = 1.0, title = 1.0, authors = 1.0, acronym = 0.9, year = 0.8, venue = 0.5, abstract = 0.4,
}

local cache = {}

local function clean(s)
  s = s:gsub("%$([^$]*)%$", function(m)
    return (m:gsub("\\(%a+)%s*", "%1"):gsub("[_^{}]", ""))
  end)
  s = s:gsub("\\[`'^\"~=.]%s*{?(%a)}?", "%1")
  s = s:gsub("\\([&%%_$#])", "%1")
  s = s:gsub("\\%a+%s*", "")
  s = s:gsub("[{}]", "")
  s = s:gsub("%s+", " ")
  return vim.trim(s)
end

local function scan_delimited(text, i, close)
  local depth, j = 0, i + 1
  while j <= #text do
    local ch = text:sub(j, j)
    if ch == "\\" then
      j = j + 1
    elseif ch == "{" then
      depth = depth + 1
    elseif ch == "}" then
      if close == "}" and depth == 0 then break end
      depth = depth - 1
    elseif ch == close and depth == 0 then
      break
    end
    j = j + 1
  end
  return text:sub(i + 1, j - 1), j + 1
end

-- a field value: {...}, "..." or a bare word, possibly joined with #
local function parse_value(text, i)
  local parts = {}
  while true do
    i = text:find("%S", i) or #text + 1
    local c = text:sub(i, i)
    local part
    if c == "{" then
      part, i = scan_delimited(text, i, "}")
    elseif c == '"' then
      part, i = scan_delimited(text, i, '"')
    else
      part = text:match("^[^,%s#}]+", i)
      if not part then break end
      i = i + #part
    end
    parts[#parts + 1] = part
    i = text:find("%S", i) or #text + 1
    if text:sub(i, i) ~= "#" then break end
    i = i + 1
  end
  return table.concat(parts), i
end

local function parse_bib(text)
  local entries, pos = {}, 1
  while true do
    local s, e, typ = text:find("@(%a+)%s*[{(]", pos)
    if not e then break end
    pos = e + 1
    typ = typ:lower()
    local key, after = text:match("^%s*([^,%s{}]+)%s*,()", pos)
    if key and typ ~= "comment" and typ ~= "string" and typ ~= "preamble" then
      local entry, i = { key = key, type = typ }, after
      local kept = {}
      while true do
        local fstart = i
        local name, vstart = text:match("^%s*([%w_%-%.:]+)%s*=%s*()", i)
        if not name then break end
        local value
        value, i = parse_value(text, vstart)
        entry[name:lower()] = clean(value)
        if COPY_FIELDS[name:lower()] then kept[#kept + 1] = (text:sub(fstart, i - 1):gsub("%s+$", "")) end
        local nxt = text:match("^%s*,()", i)
        if not nxt then break end
        i = nxt
      end
      -- the entry as it gets copied into a project bib: original formatting, COPY_FIELDS only
      entry.raw = text:sub(s, after - 1) .. table.concat(kept, ",") .. "\n}"
      entries[#entries + 1] = entry
      pos = i
    end
  end
  return entries
end

local function split_authors(s)
  local names = {}
  for name in (s .. " and "):gmatch("(.-)%s+and%s+") do
    local last, first = name:match("^(.-),%s*(.+)$")
    names[#names + 1] = last and (first .. " " .. last) or name
  end
  return names
end

local function truncate(s, n)
  if vim.fn.strchars(s) <= n then return s end
  return vim.fn.strcharpart(s, 0, n - 1) .. "…"
end

local function decorate(entry, file)
  local authors = entry.author and split_authors(entry.author) or {}
  local year = entry.year or (entry.date and entry.date:match("%d%d%d%d")) or ""
  local venue = entry.journal or entry.journaltitle or entry.booktitle or entry.publisher or entry.howpublished or ""
  local title = entry.title or ""

  local acronym = {}
  for word in title:gmatch("%w+") do acronym[#acronym + 1] = word:sub(1, 1) end

  local first_last = authors[1] and authors[1]:match("(%S+)$") or "?"
  local short_author = first_last .. (#authors > 1 and " et al." or "")

  entry.search = {
    key = entry.key:lower(),
    title = title:lower(),
    authors = table.concat(authors, ", "):lower(),
    acronym = table.concat(acronym):lower(),
    year = year,
    venue = venue:lower(),
    abstract = (entry.abstract or ""):lower(),
  }
  entry.short = truncate(string.format("%s %s · %s", short_author, year, title), 60)

  local doc = { "**" .. (title ~= "" and title or entry.key) .. "**", "" }
  if #authors > 0 then doc[#doc + 1] = table.concat(authors, ", ") .. "  " end
  local meta = {}
  if venue ~= "" then meta[#meta + 1] = "*" .. venue .. "*" end
  if year ~= "" then meta[#meta + 1] = year end
  if #meta > 0 then doc[#doc + 1] = table.concat(meta, ", ") .. "  " end
  doc[#doc + 1] = "`" .. entry.key .. "` · " .. vim.fn.fnamemodify(file, ":t")
  if entry.abstract then
    vim.list_extend(doc, { "", "---", "", truncate(entry.abstract, 800) })
  end
  entry.doc = table.concat(doc, "\n")
  return entry
end

local function load_bib(path)
  local st = vim.uv.fs_stat(path)
  if not st then return {} end
  local c = cache[path]
  if c and c.sec == st.mtime.sec and c.nsec == st.mtime.nsec and c.size == st.size then
    return c.entries
  end
  local f = io.open(path, "r")
  if not f then return {} end
  local text = f:read("*a")
  f:close()
  local entries = parse_bib(text)
  for _, e in ipairs(entries) do decorate(e, path) end
  cache[path] = { sec = st.mtime.sec, nsec = st.mtime.nsec, size = st.size, entries = entries }
  return entries
end

function M.find_bibs(file)
  local dir = file ~= "" and vim.fs.dirname(vim.fn.fnamemodify(file, ":p")) or vim.fn.getcwd()
  local home = vim.uv.os_homedir()
  local bibs = {}
  for _ = 1, MAX_PARENT_LEVELS do
    local here = {}
    for name, t in vim.fs.dir(dir) do
      if (t == "file" or t == "link") and name:match("%.bib$") then here[#here + 1] = dir .. "/" .. name end
    end
    table.sort(here)
    vim.list_extend(bibs, here)
    local parent = vim.fs.dirname(dir)
    if parent == dir or dir == home then break end
    dir = parent
  end
  return bibs
end

-- `key = value` lines; `source` may repeat, relative paths resolve against the config's folder
function M.read_config(path)
  local cfg = { sources = {} }
  local f = path and io.open(path, "r")
  if not f then return cfg end
  local dir = vim.fs.dirname(path)
  for line in f:lines() do
    local name, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if name and value ~= "" then
      value = vim.fs.normalize(value)
      if value:sub(1, 1) ~= "/" then value = vim.fn.simplify(dir .. "/" .. value) end
      if name == "source" then
        cfg.sources[#cfg.sources + 1] = value
      elseif name == "target" then
        cfg.target = value
      end
    end
  end
  f:close()
  return cfg
end

-- project bibs first, then .bibcite sources, then global sources; returns the bibs to search,
-- which of them are external, and the bib that external entries get copied into
function M.sources_for(file)
  local dir = file ~= "" and vim.fs.dirname(vim.fn.fnamemodify(file, ":p")) or vim.fn.getcwd()
  local project = vim.fs.find(PROJECT_CONFIG, { upward = true, path = dir, stop = vim.uv.os_homedir(), type = "file" })[1]
  local pcfg, gcfg = M.read_config(project), M.read_config(GLOBAL_CONFIG)
  local bibs, external, seen = {}, {}, {}
  local function add(path, is_external)
    if seen[path] then return end
    seen[path] = true
    bibs[#bibs + 1] = path
    external[path] = is_external or nil
  end
  local project_bibs = M.find_bibs(file)
  for _, path in ipairs(project_bibs) do add(path, false) end
  for _, path in ipairs(pcfg.sources) do add(path, true) end
  for _, path in ipairs(gcfg.sources) do add(path, true) end
  return bibs, external, pcfg.target or project_bibs[1]
end

-- earliest source wins when the same key appears in several files; `origin` maps each
-- external entry to the file it came from
function M.entries_for(file)
  local bibs, external, target = M.sources_for(file)
  local seen, entries, origin = {}, {}, {}
  for _, path in ipairs(bibs) do
    for _, e in ipairs(load_bib(path)) do
      if not seen[e.key] then
        seen[e.key] = true
        entries[#entries + 1] = e
        if external[path] then origin[e] = path end
      end
    end
  end
  return entries, origin, target
end

local function has_key(text, key)
  return text:find("@%a+%s*[{(]%s*" .. vim.pesc(key) .. "%s*,") ~= nil
end

-- append an entry's text to the target bib unless the key is already there; an open buffer
-- gets the entry instead of the file, and is only saved if it had no unsaved changes
function M.add_to_bib(target, key, raw)
  local name = vim.fn.fnamemodify(target, ":t")
  local buf = vim.fn.bufnr(target)
  if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    if has_key(table.concat(lines, "\n"), key) then return end
    local was_modified = vim.bo[buf].modified
    local new = vim.split(raw, "\n")
    if #lines == 1 and lines[1] == "" then
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, new)
    else
      if lines[#lines] ~= "" then table.insert(new, 1, "") end
      vim.api.nvim_buf_set_lines(buf, -1, -1, false, new)
    end
    if not was_modified then vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end) end
  else
    local f = io.open(target, "r")
    local text = f and f:read("*a") or ""
    if f then f:close() end
    if has_key(text, key) then return end
    local sep = (text == "" or text:sub(-2) == "\n\n") and "" or (text:sub(-1) == "\n" and "\n" or "\n\n")
    local out = io.open(target, "a")
    if not out then
      vim.notify("bibcite: can't write " .. target, vim.log.levels.ERROR)
      return
    end
    out:write(sep .. raw .. "\n")
    out:close()
  end
  vim.notify("bibcite: added " .. key .. " to " .. name)
end

local function is_word_start(s, i)
  local prev = s:sub(i - 1, i - 1)
  return i == 1 or not prev:match("%w") or (prev:match("%d") and s:sub(i, i):match("%a")) ~= nil
end

local function substring_score(tok, field)
  local best, init = 0, 1
  while true do
    local i = field:find(tok, init, true)
    if not i then return best end
    if is_word_start(field, i) then return 10 end
    best, init = 6, i + 1
  end
end

-- characters of tok in order, starting at a word start, not spread too thin
local function subsequence_score(tok, field)
  if #tok < 3 then return 0 end
  local best, first = 0, tok:sub(1, 1)
  local start = field:find(first, 1, true)
  while start do
    if is_word_start(field, start) then
      local j = start
      for k = 2, #tok do
        j = field:find(tok:sub(k, k), j + 1, true)
        if not j then break end
      end
      if j then
        local span = j - start + 1
        if span <= 3 * #tok then best = math.max(best, 4 * #tok / span) end
      end
    end
    start = field:find(first, start + 1, true)
  end
  return best
end

local function score_entry(entry, tokens)
  local total = 0
  for _, tok in ipairs(tokens) do
    local best = 0
    for field, weight in pairs(FIELD_WEIGHTS) do
      local text = entry.search[field]
      if text ~= "" then
        local s = substring_score(tok, text)
        if s == 0 and field ~= "abstract" then s = subsequence_score(tok, text) end
        best = math.max(best, s * weight)
      end
    end
    if best == 0 then return 0 end
    total = total + best
  end
  return total
end

function M.search(entries, query)
  local tokens = vim.split(vim.trim(query:lower()), "%s+", { trimempty = true })
  local results = {}
  for i, e in ipairs(entries) do
    local score = #tokens == 0 and 1 or score_entry(e, tokens)
    if score > 0 then results[#results + 1] = { entry = e, score = score, index = i } end
  end
  table.sort(results, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    return a.index < b.index
  end)
  return vim.list_slice(results, 1, MAX_ITEMS)
end

local CITE_PATTERN = "\\%a*[cC]ite%a*%*?[^{}]*{[^{}]*$"

local source = {}

function M.new()
  return setmetatable({}, { __index = source })
end

function source:get_debug_name()
  return "bibcite"
end

function source:is_available()
  return vim.bo.filetype == "tex" or vim.bo.filetype == "plaintex"
end

function source:get_trigger_characters()
  return { "{", "," }
end

-- spaces allowed so the whole multi-word query is the completion input
function source:get_keyword_pattern()
  return [=[[^{}, ][^{},]*]=]
end

function source:complete(params, callback)
  local before = params.context.cursor_before_line
  if not before:match(CITE_PATTERN) then
    return callback({ items = {}, isIncomplete = false })
  end
  local query = before:sub(params.offset)
  local kind = require("cmp").lsp.CompletionItemKind.Reference
  local entries, origin, target = M.entries_for(vim.api.nvim_buf_get_name(0))
  local items = {}
  for rank, r in ipairs(M.search(entries, query)) do
    local e = r.entry
    local from = origin[e]
    items[#items + 1] = {
      label = e.key,
      insertText = e.key,
      -- cmp's own matcher would re-filter on the key; hand it the query so every result passes
      filterText = query ~= "" and query or e.key,
      sortText = string.format("%05d", rank),
      kind = kind,
      labelDetails = { description = from and ("[" .. vim.fn.fnamemodify(from, ":t:r") .. "] " .. e.short) or e.short },
      documentation = { kind = "markdown", value = e.doc },
      data = from and { key = e.key, raw = e.raw, target = target } or nil,
    }
  end
  callback({ items = items, isIncomplete = true })
end

-- runs when an item is confirmed: external entries get copied into the project's bib
function source:execute(item, callback)
  local d = item.data
  if d and d.raw then
    if d.target then
      M.add_to_bib(d.target, d.key, d.raw)
    else
      vim.notify("bibcite: no .bib to add " .. d.key .. " to; set target in .bibcite", vim.log.levels.WARN)
    end
  end
  callback()
end

return M
