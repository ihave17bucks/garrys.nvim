local M = {}

local u = require("garrys.util")
local profile = require("garrys.profile")

local uv = vim.uv or vim.loop

-- Normalize single values into tables for consistent iteration
local function listify(value)
  if not value then
    return nil
  end
  return type(value) == "table" and value or { value }
end

-- Prepend path only if not already present
local function prepend_unique(field, value)
  if not field:find(value, 1, true) then
    return value .. ";" .. field
  end
  return field
end

-- Extend Lua search paths for plugin modules
local function sync_paths(path)
  package.path = prepend_unique(package.path, path .. "/lua/?/init.lua")
  package.path = prepend_unique(package.path, path .. "/lua/?.lua")
  package.cpath = prepend_unique(package.cpath, path .. "/lua/?.so")
end

-- Source plugin startup files inside plugin/
local function source_plugin_files(plugin)
  local dir = plugin.path .. "/plugin"

  if not u.is_installed(dir) then
    return
  end

  local files = vim.fn.glob(dir .. "/*.{vim,lua}", false, true)

  for _, file in ipairs(files) do
    local ok, err = pcall(vim.cmd.source, file)

    if not ok then
      u.err(("source failed for %s (%s): %s"):format(plugin.name, file, err))
    end
  end
end

-- Fully load plugin into runtime
function M.inject(plugin)
  if plugin._loaded or not u.is_installed(plugin.path) then
    return
  end

  -- Early hook before runtimepath load
  if plugin.init then
    pcall(plugin.init)
  end

  vim.opt.rtp:prepend(plugin.path)

  -- after/ should run after main runtime files
  local after = plugin.path .. "/after"
  if u.is_installed(after) then
    vim.opt.rtp:append(after)
  end

  sync_paths(plugin.path)
  source_plugin_files(plugin)

  -- Main config/setup callback
  if plugin.on then
    local ok, err = pcall(plugin.on, plugin.opts)

    if not ok then
      u.err(("config failed for %s: %s"):format(plugin.name, err))
    end
  end

  plugin._loaded = true
  profile.stop(plugin.name)
end

-- Ensure plugin only loads once
local function load_once(plugin)
  return function()
    M.inject(plugin)
    u.debug(plugin.name .. " loaded")
  end
end

-- Lazy-load on events
local function register_events(plugin, cb)
  local events = listify(plugin.event)
  if not events then
    return
  end

  vim.api.nvim_create_autocmd(events, {
    once = true,
    callback = cb,
  })
end

-- Lazy-load on filetype
local function register_filetypes(plugin, cb)
  local fts = listify(plugin.ft)
  if not fts then
    return
  end

  vim.api.nvim_create_autocmd("FileType", {
    pattern = fts,
    once = true,
    callback = cb,
  })
end

-- Lazy-load on command execution
local function register_commands(plugin, cb)
  for _, cmd in ipairs(listify(plugin.cmd) or {}) do
    vim.api.nvim_create_user_command(cmd, function(args)
      vim.api.nvim_del_user_command(cmd)

      cb()

      -- Replay original command after loading
      vim.cmd({
        cmd = cmd,
        args = { args.args },
      })
    end, { nargs = "*" })
  end
end

-- Lazy-load on keypress
local function register_keys(plugin, cb)
  for _, key in ipairs(listify(plugin.keys) or {}) do
    vim.keymap.set("n", key, function()
      vim.keymap.del("n", key)

      cb()

      -- Replay original keypress
      vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes(key, true, false, true),
        "n",
        false
      )
    end)
  end
end

-- Register all lazy triggers
function M.register(plugin)
  local cb = load_once(plugin)

  register_events(plugin, cb)
  register_filetypes(plugin, cb)
  register_commands(plugin, cb)
  register_keys(plugin, cb)
end

-- Load startup plugins + register lazy plugins
function M.load_all(plugins)
  vim.loader.enable()

  for _, plugin in ipairs(u.sort_by_deps(plugins)) do
    local lazy = plugin.lazy
      or plugin.event
      or plugin.cmd
      or plugin.ft
      or plugin.keys

    if lazy then
      M.register(plugin)
    else
      M.inject(plugin)
    end
  end
end

return M
