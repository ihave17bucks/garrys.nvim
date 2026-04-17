local M = {}
local u = require("garrys.util")

-- The core problem: vim.opt.rtp:prepend() updates Neovim's rtp
-- but does NOT update Lua's package.path. Plugins with nested
-- require() calls (like nvim-notify) can't find their submodules.
-- Fix: manually sync package.path every time we inject a plugin.
local function sync_package_path(path)
  local lua_path  = path .. "/lua/?.lua"
  local lua_init  = path .. "/lua/?/init.lua"
  if not package.path:find(lua_path, 1, true) then
    package.path = lua_path .. ";" .. lua_init .. ";" .. package.path
  end
end

-- Also sync package.cpath for compiled .so modules (fzf-native etc.)
local function sync_package_cpath(path)
  local cpath = path .. "/lua/?.so"
  if not package.cpath:find(cpath, 1, true) then
    package.cpath = cpath .. ";" .. package.cpath
  end
end

function M.inject(plugin)
  -- Run init before anything else (lazy.nvim compat)
  if plugin.init then
    local ok, err = pcall(plugin.init)
    if not ok then
      require("garrys.util").warn("init failed for " .. plugin.name .. ": " .. tostring(err))
    end
  end
  if not u.is_installed(plugin.path) then return end

  -- 1. Add to Neovim rtp
  vim.opt.rtp:prepend(plugin.path)

  local after = plugin.path .. "/after"
  if u.is_installed(after) then
    vim.opt.rtp:append(after)
  end

  -- 2. Sync Lua package.path so nested requires work
  sync_package_path(plugin.path)
  sync_package_cpath(plugin.path)

  -- 3. Source plugin/ runtime files
  local plugin_dir = plugin.path .. "/plugin"
  if u.is_installed(plugin_dir) then
    local files = vim.fn.glob(plugin_dir .. "/*.{vim,lua}", false, true)
    for _, f in ipairs(files) do
      local ok, err = pcall(vim.cmd, "source " .. vim.fn.fnameescape(f))
      if not ok then
        u.err("source failed for " .. plugin.name .. " (" .. f .. "): " .. err)
      end
    end
  end

  -- 4. Run config if explicitly provided
  -- Never auto-require(plugin.name) -- module names rarely match repo names
  if plugin.on then
    local ok, err = pcall(plugin.on, plugin.opts)
    if not ok then
      u.err("config failed for " .. plugin.name .. ": " .. err)
    end
  end

  plugin._loaded = true
  local prof = require("garrys.profile")
  prof.stop(plugin.name)
end

function M.register(plugin)
  local function load_once()
    if plugin._loaded then return end
    M.inject(plugin)
    u.debug(plugin.name .. " lazy-loaded")
  end

  -- Lazy by event
  if plugin.event then
    local events = type(plugin.event) == "string"
      and { plugin.event }
      or plugin.event

    -- Validate events — unknown events crash nvim_create_autocmd
    local valid = {}
    for _, ev in ipairs(events) do
      local ok = pcall(vim.api.nvim_create_autocmd, ev, {
        once     = true,
        callback = function() end,
      })
      if ok then
        table.insert(valid, ev)
      else
        u.warn("unknown event '" .. ev .. "' for " .. plugin.name .. " — skipping lazy trigger")
      end
    end

    if #valid > 0 then
      vim.api.nvim_create_autocmd(valid, {
        once     = true,
        callback = load_once,
      })
    end
  end

  -- Lazy by command
  if plugin.cmd then
    local cmds = type(plugin.cmd) == "string"
      and { plugin.cmd }
      or plugin.cmd

    for _, cmd in ipairs(cmds) do
      vim.api.nvim_create_user_command(cmd, function(args)
        vim.api.nvim_del_user_command(cmd)
        load_once()
        vim.cmd(cmd .. " " .. (args.args or ""))
      end, { nargs = "*", desc = "garrys: lazy load " .. plugin.name })
    end
  end

  -- Lazy by filetype
  if plugin.ft then
    local fts = type(plugin.ft) == "string"
      and { plugin.ft }
      or plugin.ft

    vim.api.nvim_create_autocmd("FileType", {
      pattern  = fts,
      once     = true,
      callback = load_once,
    })
  end

  -- Lazy by keymap
  if plugin.keys then
    local keys = type(plugin.keys) == "string"
      and { plugin.keys }
      or plugin.keys

    for _, key in ipairs(keys) do
      vim.keymap.set("n", key, function()
        vim.keymap.del("n", key)
        load_once()
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes(key, true, false, true),
          "n", false
        )
      end, { desc = "garrys: lazy load " .. plugin.name })
    end
  end
end

function M.load_all(plugins)
  vim.loader.enable()

  local sorted = u.sort_by_deps(plugins)

  for _, plugin in ipairs(sorted) do
    local is_lazy = plugin.lazy
      or plugin.event
      or plugin.cmd
      or plugin.ft
      or plugin.keys

    if is_lazy then
      M.register(plugin)
    else
      M.inject(plugin)
    end
  end
end

return M
