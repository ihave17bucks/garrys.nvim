local M = {}

M._plugins    = {}
M._load_times = {}  -- name -> ms, populated by loader

M.config = {
  path        = vim.fn.stdpath("data") .. "/garrys/plugins",
  lockfile    = vim.fn.stdpath("config") .. "/garrys.lock",
  concurrency = 8,
  autoinstall = true,
  strict_deps = true,
  plugin_dir  = vim.fn.stdpath("config") .. "/lua/plugins",
}

-- ── Simpler API ────────────────────────────────────────────────────────────

-- g.plug "user/repo"
-- g.plug { "user/repo", build = ":TSUpdate", dep = { "plenary" } }
function M.plug(spec)
  if type(spec) == "string" then
    spec = { spec }
  end
  local plugin = M._normalize(spec)
  if plugin then
    M._plugins[plugin.name] = plugin
  end
  return M  -- chainable
end

-- g.load() — finalize and start loading
function M.load(opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end

  vim.fn.mkdir(M.config.path, "p")

  -- Auto-discover plugin modules from plugin_dir
  M._discover()

  if M.config.strict_deps then
    M._validate_deps()
  end

  require("garrys.loader").load_all(M._plugins)

  if M.config.autoinstall then
    M._autoinstall()
  end
end

-- Legacy: keep setup() working for anyone already using it
function M.setup(specs, opts)
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
  for _, spec in ipairs(specs or {}) do
    M.plug(spec)
  end
  M.load()
end

-- ── Internal ───────────────────────────────────────────────────────────────

function M._normalize(spec)
  if type(spec) == "string" then spec = { spec } end

  local source = spec[1]
  if not source then return nil end

  local name = spec.name or source:match("[^/]+$")
  local u    = require("garrys.util")

  -- cond check — skip plugin entirely if false
  if spec.cond ~= nil then
    local result = type(spec.cond) == "function" and spec.cond() or spec.cond
    if not result then return nil end
  end

  return {
    name    = name,
    source  = source,
    url     = "https://github.com/" .. source .. ".git",
    path    = u.plugin_path(M.config.path, name),
    lazy    = spec.lazy    or false,
    event   = spec.event   or nil,
    cmd     = spec.cmd     or nil,
    ft      = spec.ft      or nil,
    keys    = spec.keys    or nil,
    cond    = spec.cond    or nil,
    pin     = spec.pin     or false,
    -- short aliases
    dep     = spec.dep     or spec.depends or {},
    on      = spec.on      or spec.config  or nil,
    make    = spec.make    or spec.build   or nil,
    opts    = spec.opts    or {},
    _loaded = false,
  }
end

function M._discover()
  local dir = M.config.plugin_dir
  if not vim.loop.fs_stat(dir) then return end

  local handle = vim.loop.fs_scandir(dir)
  if not handle then return end

  while true do
    local name, ftype = vim.loop.fs_scandir_next(handle)
    if not name then break end
    if ftype == "file" and name:match("%.lua$") then
      local mod = "plugins." .. name:gsub("%.lua$", "")
      local ok, result = pcall(require, mod)
      if ok and type(result) == "table" then
        for _, spec in ipairs(result) do
          local plugin = M._normalize(spec)
          if plugin and not M._plugins[plugin.name] then
            M._plugins[plugin.name] = plugin
          end
        end
      elseif not ok then
        require("garrys.util").warn("failed to load " .. mod .. ": " .. result)
      end
    end
  end
end

function M._validate_deps()
  local errors = {}
  for _, plugin in pairs(M._plugins) do
    for _, dep in ipairs(plugin.dep or {}) do
      local dep_name = dep:match("[^/]+$")
      if not M._plugins[dep_name] then
        table.insert(errors, string.format(
          "'%s' needs '%s' — not in spec", plugin.name, dep
        ))
      end
    end
  end
  if #errors > 0 then
    for _, e in ipairs(errors) do
      require("garrys.util").err(e)
    end
    require("garrys.util").err(
      #errors .. " dep error(s) — fix spec or set strict_deps = false"
    )
  end
end

function M._autoinstall()
  local u       = require("garrys.util")
  local missing = {}
  for _, plugin in pairs(M._plugins) do
    if not u.is_installed(plugin.path) then
      table.insert(missing, plugin)
    end
  end
  if #missing == 0 then return end

  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      local git    = require("garrys.git")
      local ui     = require("garrys.ui")
      local loader = require("garrys.loader")

      ui.open()
      ui.set_total(#missing)

      local done = 0
      local active = 0
      local i = 1

      local function dispatch()
        while active < M.config.concurrency and i <= #missing do
          local plugin = missing[i]
          i = i + 1
          active = active + 1
          ui.set_status(plugin.name, "installing...")
          git.clone(plugin.url, plugin.path, function(ok, err)
            active = active - 1
            done   = done + 1
            vim.schedule(function()
              if ok then
                ui.set_status(plugin.name, "✔ installed")
                loader.inject(plugin)
                if plugin.make then u.run_build(plugin) end
              else
                ui.set_status(plugin.name, "✘ " .. (err or ""):gsub("\n", " "))
              end
              if done == #missing then ui.finish()
              else dispatch() end
            end)
          end)
        end
      end

      dispatch()
    end,
  })
end

function M.has_missing()
  local u = require("garrys.util")
  for _, plugin in pairs(M._plugins) do
    if not u.is_installed(plugin.path) then return true end
  end
  return false
end

return M
