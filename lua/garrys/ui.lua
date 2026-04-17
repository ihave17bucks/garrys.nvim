local M   = {}
local api = vim.api

-- State
M._buf      = nil
M._win      = nil
M._timer    = nil
M._statuses = {}
M._log      = {}
M._tab      = "install"  -- "install" | "updates" | "log"
M._total    = 0
M._done     = 0
M._start    = nil
M._elapsed  = nil
M._footer   = "working..."

local W       = 60
local TOP     = "┌" .. string.rep("─", W) .. "┐"
local BOTTOM  = "└" .. string.rep("─", W) .. "┘"
local SIDE    = "│"
local DIVIDER = "├" .. string.rep("─", W) .. "┤"

local BAR_W = 30
local function make_bar(done, total)
  if total == 0 then return string.rep("░", BAR_W) end
  local f = math.floor((done / total) * BAR_W)
  return string.rep("█", f) .. string.rep("░", BAR_W - f)
end

local function pct(done, total)
  if total == 0 then return "  0%" end
  return string.format("%3d%%", math.floor((done / total) * 100))
end

local function pad(str, width)
  local len = vim.fn.strdisplaywidth(str)
  if len >= width then return str:sub(1, width) end
  return str .. string.rep(" ", width - len)
end

local function center(str, width)
  local len = vim.fn.strdisplaywidth(str)
  local p   = width - len
  local l   = math.floor(p / 2)
  return string.rep(" ", l) .. str .. string.rep(" ", p - l)
end

local function row(content)
  return SIDE .. " " .. pad(content, W - 2) .. " " .. SIDE
end

local ICONS = {
  installing = "▶", updating = "▶",
  done       = "✔", failed   = "✘",
  installed  = "■", missing  = "□",
  healthy    = "✔", info     = "·",
}

local TICK = 0

-- ── Tabs ───────────────────────────────────────────────────────────────────

local function tab_bar()
  local tabs = {
    { id = "install", label = "  Installed  " },
    { id = "updates", label = "  Updates    " },
    { id = "log",     label = "  Log        " },
  }

  local parts = {}
  for _, t in ipairs(tabs) do
    if t.id == M._tab then
      table.insert(parts, "▌" .. t.label .. "▐")
    else
      table.insert(parts, " " .. t.label .. " ")
    end
  end

  return center(table.concat(parts, ""), W)
end

-- ── Render ─────────────────────────────────────────────────────────────────

local function render_install()
  local lines = {}
  if vim.tbl_count(M._statuses) == 0 then
    table.insert(lines, row(""))
    table.insert(lines, row(center("no plugins registered", W - 2)))
    table.insert(lines, row(""))
    return lines
  end

  table.insert(lines, row(""))
  for name, entry in pairs(M._statuses) do
    local icon = ICONS[entry.state] or "·"
    if entry.state == "installing" or entry.state == "updating" then
      icon = (TICK % 2 == 0) and "▶" or "▷"
    end
    local name_col = pad(name, 30)
    local msg_col  = pad(entry.msg or "", 24)
    table.insert(lines, row(icon .. " " .. name_col .. msg_col))
  end
  table.insert(lines, row(""))
  return lines
end

local function render_updates()
  local lines = {}
  local garrys = require("garrys")
  local u      = require("garrys.util")
  local git    = require("garrys.git")

  table.insert(lines, row(""))
  local any = false
  for _, plugin in pairs(garrys._plugins) do
    if u.is_installed(plugin.path) then
      any = true
      local pinned = plugin.pin and " [pinned]" or ""
      table.insert(lines, row("■ " .. pad(plugin.name, 30) .. "installed" .. pinned))
    end
  end
  if not any then
    table.insert(lines, row(center("no plugins installed", W - 2)))
  end
  table.insert(lines, row(""))
  return lines
end

local function render_log()
  local lines = {}
  table.insert(lines, row(""))
  if #M._log == 0 then
    table.insert(lines, row(center("no log entries yet", W - 2)))
  else
    -- show last 12 log entries
    local start = math.max(1, #M._log - 11)
    for i = start, #M._log do
      table.insert(lines, row("  " .. pad(M._log[i], W - 4)))
    end
  end
  table.insert(lines, row(""))
  return lines
end

local function render()
  if not M._buf or not api.nvim_buf_is_valid(M._buf) then return end
  TICK = TICK + 1

  local elapsed = ""
  if M._elapsed then
    elapsed = string.format("  %.2fs", M._elapsed)
  elseif M._start then
    elapsed = string.format("  %.2fs", (vim.loop.hrtime() - M._start) / 1e9)
  end

  local lines = {}

  -- Header
  table.insert(lines, TOP)
  table.insert(lines, SIDE .. center("  garrys.nvim", W) .. SIDE)
  table.insert(lines, SIDE .. center(M._total .. " plugins" .. elapsed, W) .. SIDE)
  table.insert(lines, DIVIDER)

  -- Tab bar
  table.insert(lines, SIDE .. tab_bar() .. SIDE)
  table.insert(lines, DIVIDER)

  -- Tab content
  local content = {}
  if M._tab == "install" then
    content = render_install()
  elseif M._tab == "updates" then
    content = render_updates()
  else
    content = render_log()
  end

  for _, l in ipairs(content) do
    table.insert(lines, l)
  end

  table.insert(lines, DIVIDER)

  -- Progress bar (only on install tab)
  if M._tab == "install" then
    local bar  = make_bar(M._done, M._total)
    local perc = pct(M._done, M._total)
    table.insert(lines, row(bar .. " " .. perc))
  end

  -- Stats + footer
  local done_ct, fail_ct = 0, 0
  for _, e in pairs(M._statuses) do
    if e.state == "done"   then done_ct = done_ct + 1 end
    if e.state == "failed" then fail_ct = fail_ct + 1 end
  end

  local stats = "plugins: " .. M._total
  if done_ct > 0 then stats = stats .. "  ok: " .. done_ct end
  if fail_ct > 0 then stats = stats .. "  fail: " .. fail_ct end
  table.insert(lines, row(stats))
  table.insert(lines, row(M._footer))
  table.insert(lines, BOTTOM)

  vim.bo[M._buf].modifiable = true
  api.nvim_buf_set_lines(M._buf, 0, -1, false, lines)
  vim.bo[M._buf].modifiable = false

  M._apply_hl(lines)

  if M._win and api.nvim_win_is_valid(M._win) then
    local h = math.min(#lines, math.floor(vim.o.lines * 0.85))
    api.nvim_win_set_height(M._win, h)
  end
end

-- ── Highlights ─────────────────────────────────────────────────────────────

function M._apply_hl(lines)
  if not M._buf or not api.nvim_buf_is_valid(M._buf) then return end
  api.nvim_buf_clear_namespace(M._buf, -1, 0, -1)

  local function hl(line, group, s, e)
    pcall(api.nvim_buf_add_highlight, M._buf, -1, group, line, s, e or -1)
  end

  for i, line in ipairs(lines) do
    local li = i - 1

    if line:sub(1,1) == "┌" or line:sub(1,1) == "└" or line:sub(1,1) == "├" then
      hl(li, "GarrysBox", 0)

    elseif line:sub(1,1) == "│" then
      hl(li, "GarrysBox", 0, 2)
      hl(li, "GarrysBox", #line - 1)

      local content = line:sub(3)

      -- Title
      if content:find("garrys.nvim") then
        hl(li, "GarrysTitle", 2)

      -- Tab bar
      elseif content:find("Installed") or content:find("Updates") or content:find("Log") then
        -- Active tab
        local s = line:find("▌")
        local e = line:find("▐")
        if s and e then
          hl(li, "GarrysTabActive", s - 1, e)
        end
        hl(li, "GarrysDim", 2)

      -- Progress bar
      elseif content:find("[█░]") then
        local bs = line:find("[█░]")
        local fe = line:find("░") or #line
        hl(li, "GarrysBar",   bs - 1, fe - 1)
        hl(li, "GarrysEmpty", fe - 1, line:find("%d+%%") and (line:find("%d+%%") - 2) or -1)
        local ps = line:find("%d+%%")
        if ps then hl(li, "GarrysPct", ps - 1) end

      -- Subheader / stats / footer
      elseif content:match("^%s*%d+ plugins") or content:match("^%s*plugins:") then
        hl(li, "GarrysSub", 2)
      elseif content:match("done") or content:match("q to close") or content:match("working") then
        hl(li, "GarrysFooter", 2)

      -- Plugin rows
      else
        local ip = line:find("[▶▷✔✘■□·]")
        if ip then
          local icon = line:sub(ip, ip)
          local g = "GarrysDim"
          if icon == "✔" or icon == "■" then g = "GarrysOk"
          elseif icon == "✘"             then g = "GarrysErr"
          elseif icon == "▶" or icon == "▷" then g = "GarrysActive"
          end
          hl(li, g,           ip - 1, ip)
          hl(li, "GarrysName", ip,     ip + 31)
          hl(li, "GarrysMsg",  ip + 31)
        end
      end
    end
  end
end

-- ── Timer ──────────────────────────────────────────────────────────────────

local function start_tick()
  if M._timer then return end
  M._timer = vim.loop.new_timer()
  M._timer:start(0, 120, vim.schedule_wrap(render))
end

local function stop_tick()
  if M._timer then
    M._timer:stop()
    M._timer:close()
    M._timer = nil
  end
end

-- ── Public API ─────────────────────────────────────────────────────────────

function M.open()
  if M._win and api.nvim_win_is_valid(M._win) then return end

  M._buf      = api.nvim_create_buf(false, true)
  M._statuses = {}
  M._log      = {}
  M._footer   = "working..."
  M._done     = 0
  M._total    = 0
  M._start    = vim.loop.hrtime()
  M._elapsed  = nil
  M._tab      = "install"

  local width = W + 2
  local r     = math.floor((vim.o.lines - 20) / 2)
  local col   = math.floor((vim.o.columns - width) / 2)

  vim.bo[M._buf].filetype   = "garrys"
  vim.bo[M._buf].modifiable = false
  vim.bo[M._buf].bufhidden  = "hide"

  M._win = api.nvim_open_win(M._buf, false, {
    relative = "editor",
    width    = width,
    height   = 10,
    row      = r,
    col      = col,
    style    = "minimal",
    border   = "none",
    zindex   = 50,
  })

  vim.wo[M._win].wrap       = false
  vim.wo[M._win].cursorline = false
  vim.wo[M._win].number     = false
  vim.wo[M._win].signcolumn  = "no"

  -- Catppuccin Mocha highlights
  vim.api.nvim_set_hl(0, "GarrysBox",       { fg = "#45475a" })
  vim.api.nvim_set_hl(0, "GarrysTitle",     { fg = "#cba6f7", bold = true })
  vim.api.nvim_set_hl(0, "GarrysSub",       { fg = "#7f849c" })
  vim.api.nvim_set_hl(0, "GarrysTabActive", { fg = "#cba6f7", bold = true })
  vim.api.nvim_set_hl(0, "GarrysDim",       { fg = "#585b70" })
  vim.api.nvim_set_hl(0, "GarrysOk",        { fg = "#a6e3a1", bold = true })
  vim.api.nvim_set_hl(0, "GarrysErr",       { fg = "#f38ba8", bold = true })
  vim.api.nvim_set_hl(0, "GarrysActive",    { fg = "#89b4fa", bold = true })
  vim.api.nvim_set_hl(0, "GarrysBar",       { fg = "#cba6f7" })
  vim.api.nvim_set_hl(0, "GarrysEmpty",     { fg = "#313244" })
  vim.api.nvim_set_hl(0, "GarrysPct",       { fg = "#f5c2e7", bold = true })
  vim.api.nvim_set_hl(0, "GarrysName",      { fg = "#cdd6f4" })
  vim.api.nvim_set_hl(0, "GarrysMsg",       { fg = "#6c7086" })
  vim.api.nvim_set_hl(0, "GarrysFooter",    { fg = "#585b70", italic = true })

  -- Keymaps
  local function map(key, fn)
    vim.keymap.set("n", key, fn, { buffer = M._buf, silent = true, nowait = true })
  end

  -- Tab switching
  map("1", function() M._tab = "install"; render() end)
  map("2", function() M._tab = "updates"; render() end)
  map("3", function() M._tab = "log";     render() end)
  map("<Tab>", function()
    local tabs = { "install", "updates", "log" }
    for i, t in ipairs(tabs) do
      if t == M._tab then
        M._tab = tabs[(i % #tabs) + 1]
        break
      end
    end
    render()
  end)

  map("q", function()
    if #api.nvim_list_wins() <= 1 then
      if M._win and api.nvim_win_is_valid(M._win) then
        api.nvim_win_hide(M._win)
      end
    else
      M.close()
    end
  end)
  map("<Esc>", function()
    if #api.nvim_list_wins() <= 1 then
      api.nvim_win_hide(M._win)
    else
      M.close()
    end
  end)

  render()
  start_tick()
end

function M.set_total(n)
  M._total = n
end

function M.set_status(name, status)
  local state, msg

  if status:find("installing") then state, msg = "installing", "installing"
  elseif status:find("updating")  then state, msg = "updating",   "updating"
  elseif status:find("✔") or status:find("✓") then
    state = "done"
    msg   = status:gsub("[✔✓]%s*", "")
    M._done = M._done + 1
    table.insert(M._log, os.date("%H:%M:%S") .. "  ✔ " .. name .. "  " .. msg)
  elseif status:find("✘") or status:find("✗") then
    state = "failed"
    msg   = status:gsub("[✘✗]%s*", "")
    M._done = M._done + 1
    table.insert(M._log, os.date("%H:%M:%S") .. "  ✘ " .. name .. "  " .. msg)
  else
    state, msg = "info", status
  end

  M._statuses[name] = { state = state, msg = msg }
  render()
end

function M.finish()
  if M._start then
    M._elapsed = (vim.loop.hrtime() - M._start) / 1e9
  end
  M._footer = "done  —  1/2/3 switch tabs  —  q close"
  stop_tick()
  render()
end

function M.close()
  stop_tick()
  if M._win and api.nvim_win_is_valid(M._win) then
    api.nvim_win_close(M._win, true)
  end
  M._win     = nil
  M._buf     = nil
  M._statuses = {}
end

function M.open_status(plugins)
  M.open()
  M._footer = "1/2/3 switch tabs  —  q to close"
  M._total  = vim.tbl_count(plugins)
  M._done   = 0

  for _, plugin in pairs(plugins) do
    local installed = vim.loop.fs_stat(plugin.path) ~= nil
    local lazy_flag = plugin.lazy or plugin.event or plugin.cmd or plugin.ft or plugin.keys
    if installed then M._done = M._done + 1 end
    M._statuses[plugin.name] = {
      state = installed and "installed" or "missing",
      msg   = lazy_flag and "lazy" or "eager",
    }
  end

  M._elapsed = vim.loop.hrtime() / 1e9
  stop_tick()
  render()
end

return M
