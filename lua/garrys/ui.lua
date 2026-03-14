local M   = {}
local api = vim.api

M._buf      = nil
M._win      = nil
M._timer    = nil
M._statuses = {}
M._footer   = "working..."
M._total    = 0
M._done     = 0

-- Progress bar
local BAR_WIDTH = 28
local function make_bar(done, total)
  if total == 0 then return string.rep("░", BAR_WIDTH) end
  local filled = math.floor((done / total) * BAR_WIDTH)
  local empty  = BAR_WIDTH - filled
  return string.rep("█", filled) .. string.rep("░", empty)
end

local function pct(done, total)
  if total == 0 then return "  0%" end
  return string.format("%3d%%", math.floor((done / total) * 100))
end

-- Box chars
local W        = 50
local TOP      = "┌" .. string.rep("─", W) .. "┐"
local BOTTOM   = "└" .. string.rep("─", W) .. "┘"
local SIDE     = "│"
local DIVIDER  = "├" .. string.rep("─", W) .. "┤"

local function pad(str, width)
  local len = vim.fn.strdisplaywidth(str)
  if len >= width then return str:sub(1, width) end
  return str .. string.rep(" ", width - len)
end

local function center(str, width)
  local len   = vim.fn.strdisplaywidth(str)
  local total = width - len
  local l     = math.floor(total / 2)
  local r     = total - l
  return string.rep(" ", l) .. str .. string.rep(" ", r)
end

local function row(content)
  return SIDE .. " " .. pad(content, W - 2) .. " " .. SIDE
end

-- State icons
local ICONS = {
  installing = "▶",
  updating   = "▶",
  done       = "✔",
  failed     = "✘",
  installed  = "■",
  missing    = "□",
  info       = "·",
}

local TICK = 0

local function render()
  if not M._buf or not api.nvim_buf_is_valid(M._buf) then return end

  TICK = TICK + 1

  local lines = {}

  -- Header
  table.insert(lines, TOP)
  table.insert(lines, SIDE .. center("[ GARRYS.NVIM ]", W) .. SIDE)
  table.insert(lines, SIDE .. center("workshop mod manager", W) .. SIDE)
  table.insert(lines, DIVIDER)
  table.insert(lines, row(""))

  -- Plugin list
  if vim.tbl_count(M._statuses) == 0 then
    table.insert(lines, row(center("no plugins registered", W - 2)))
  else
    for name, entry in pairs(M._statuses) do
      local icon = ICONS[entry.state] or "·"

      -- Pulse the active icon
      if entry.state == "installing" or entry.state == "updating" then
        icon = (TICK % 2 == 0) and "▶" or "▷"
      end

      local name_col = pad(name, 26)
      local msg_col  = pad(entry.msg or "", 18)
      table.insert(lines, row(icon .. " " .. name_col .. msg_col))
    end
  end

  table.insert(lines, row(""))
  table.insert(lines, DIVIDER)

  -- Progress bar
  local bar  = make_bar(M._done, M._total)
  local perc = pct(M._done, M._total)
  table.insert(lines, row(bar .. " " .. perc))

  -- Stats
  local done_ct = 0
  local fail_ct = 0
  for _, e in pairs(M._statuses) do
    if e.state == "done"   then done_ct = done_ct + 1 end
    if e.state == "failed" then fail_ct = fail_ct + 1 end
  end

  local stats = "plugins: " .. M._total
  if done_ct > 0 then stats = stats .. "  ok: "   .. done_ct end
  if fail_ct > 0 then stats = stats .. "  fail: " .. fail_ct end
  table.insert(lines, row(stats))
  table.insert(lines, row(M._footer))
  table.insert(lines, BOTTOM)

  vim.bo[M._buf].modifiable = true
  api.nvim_buf_set_lines(M._buf, 0, -1, false, lines)
  vim.bo[M._buf].modifiable = false

  if M._win and api.nvim_win_is_valid(M._win) then
    local h = math.min(#lines, math.floor(vim.o.lines * 0.85))
    api.nvim_win_set_height(M._win, h)
  end
end

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

function M.open()
  if M._win and api.nvim_win_is_valid(M._win) then return end

  M._buf      = api.nvim_create_buf(false, true)
  M._statuses = {}
  M._footer   = "installing..."
  M._done     = 0
  M._total    = 0

  local width = W + 2
  local row_  = math.floor((vim.o.lines - 18) / 2)
  local col   = math.floor((vim.o.columns - width) / 2)

  vim.bo[M._buf].filetype   = "garrys"
  vim.bo[M._buf].modifiable = false
  vim.bo[M._buf].bufhidden  = "hide"

  M._win = api.nvim_open_win(M._buf, false, {
    relative = "editor",
    width    = width,
    height   = 8,
    row      = row_,
    col      = col,
    style    = "minimal",
    border   = "none",
    zindex   = 50,
  })

  vim.wo[M._win].wrap       = false
  vim.wo[M._win].cursorline = false
  vim.wo[M._win].number     = false
  vim.wo[M._win].signcolumn  = "no"

  -- Catppuccin Mocha colors
  vim.api.nvim_set_hl(0, "GarrysBox",     { fg = "#45475a" })
  vim.api.nvim_set_hl(0, "GarrysTitle",   { fg = "#cba6f7", bold = true })
  vim.api.nvim_set_hl(0, "GarrysOk",      { fg = "#a6e3a1", bold = true })
  vim.api.nvim_set_hl(0, "GarrysErr",     { fg = "#f38ba8", bold = true })
  vim.api.nvim_set_hl(0, "GarrysActive",  { fg = "#89b4fa" })
  vim.api.nvim_set_hl(0, "GarrysBar",     { fg = "#cba6f7" })
  vim.api.nvim_set_hl(0, "GarrysText",    { fg = "#cdd6f4" })
  vim.api.nvim_set_hl(0, "GarrysDim",     { fg = "#585b70" })

  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, function()
      -- Never close the last window — just hide the float
      if #api.nvim_list_wins() <= 1 then
        if M._win and api.nvim_win_is_valid(M._win) then
          api.nvim_win_hide(M._win)
        end
      else
        M.close()
      end
    end, {
      buffer = M._buf,
      silent = true,
      nowait = true,
    })
  end

  render()
  start_tick()
end

function M.set_total(n)
  M._total = n
end

function M.set_status(name, status)
  local state, msg

  if status:find("installing") then
    state, msg = "installing", "installing"
  elseif status:find("updating") then
    state, msg = "updating",   "updating"
  elseif status:find("✓") or status:find("✔") then
    state = "done"
    msg   = status:gsub("[✓✔]%s*", "")
    M._done = M._done + 1
  elseif status:find("✗") or status:find("✘") then
    state = "failed"
    msg   = status:gsub("[✗✘]%s*", "")
    M._done = M._done + 1
  else
    state, msg = "info", status
  end

  M._statuses[name] = { state = state, msg = msg }
  render()
end

function M.finish()
  M._footer = "done  —  q to close"
  stop_tick()
  render()
end

function M.close()
  stop_tick()
  if M._win and api.nvim_win_is_valid(M._win) then
    api.nvim_win_close(M._win, true)
  end
  M._win      = nil
  M._buf      = nil
  M._statuses = {}
end

function M.open_status(plugins)
  M.open()
  M._footer = "q to close"
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

  stop_tick()
  render()
end

return M
