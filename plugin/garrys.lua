local function G() return require("garrys") end

-- Install
vim.api.nvim_create_user_command("GarryInstall", function()
  local garrys  = G()
  local git     = require("garrys.git")
  local ui      = require("garrys.ui")
  local u       = require("garrys.util")
  local loader  = require("garrys.loader")
  local pending = {}

  for _, plugin in pairs(garrys._plugins) do
    if not u.is_installed(plugin.path) then
      table.insert(pending, plugin)
    end
  end

  if #pending == 0 then
    u.info("everything is already installed")
    return
  end

  ui.open()
  ui.set_total(#pending)

  local done = 0
  local active = 0
  local i = 1

  local function dispatch()
    while active < garrys.config.concurrency and i <= #pending do
      local plugin = pending[i]; i = i + 1; active = active + 1
      ui.set_status(plugin.name, "installing...")
      git.clone(plugin.url, plugin.path, function(ok, err)
        active = active - 1; done = done + 1
        vim.schedule(function()
          if ok then
            ui.set_status(plugin.name, "✔ installed")
            loader.inject(plugin)
            if plugin.make then u.run_build(plugin) end
          else
            ui.set_status(plugin.name, "✘ " .. (err or ""):gsub("\n", " "))
          end
          if done == #pending then ui.finish() else dispatch() end
        end)
      end)
    end
  end

  dispatch()
end, { desc = "Install missing plugins" })

-- Update
vim.api.nvim_create_user_command("GarryUpdate", function()
  local garrys  = G()
  local git     = require("garrys.git")
  local ui      = require("garrys.ui")
  local u       = require("garrys.util")
  local plugins = {}

  for _, p in pairs(garrys._plugins) do
    if git.is_repo(p.path) and not p.pin then
      table.insert(plugins, p)
    end
  end

  if #plugins == 0 then u.info("nothing to update"); return end

  ui.open()
  ui.set_total(#plugins)

  local done = 0
  local active = 0
  local i = 1

  local function dispatch()
    while active < garrys.config.concurrency and i <= #plugins do
      local plugin = plugins[i]; i = i + 1; active = active + 1
      ui.set_status(plugin.name, "updating...")
      git.pull(plugin.path, function(ok, err)
        active = active - 1; done = done + 1
        vim.schedule(function()
          if ok then ui.set_status(plugin.name, "✔ updated")
          else       ui.set_status(plugin.name, "✘ " .. (err or ""):gsub("\n", " ")) end
          if done == #plugins then ui.finish() else dispatch() end
        end)
      end)
    end
  end

  dispatch()
end, { desc = "Update all plugins" })

-- Clean
vim.api.nvim_create_user_command("GarryClean", function()
  local garrys    = G()
  local u         = require("garrys.util")
  local installed = u.list_installed(garrys.config.path)
  local removed   = 0

  for _, name in ipairs(installed) do
    if not garrys._plugins[name] then
      vim.fn.delete(garrys.config.path .. "/" .. name, "rf")
      u.info("removed " .. name)
      removed = removed + 1
    end
  end

  u.info(removed == 0 and "nothing to clean" or ("cleaned " .. removed .. " plugin(s)"))
end, { desc = "Remove unlisted plugins" })

-- Lock
vim.api.nvim_create_user_command("GarryLock", function()
  require("garrys.lockfile").write(G()._plugins)
end, { desc = "Write garrys.lock" })

vim.api.nvim_create_user_command("GarryRestore", function()
  require("garrys.lockfile").restore(G()._plugins)
end, { desc = "Restore plugins to locked commits" })

-- Status
vim.api.nvim_create_user_command("GarryStatus", function()
  require("garrys.ui").open_status(G()._plugins)
end, { desc = "Show plugin status" })

vim.api.nvim_create_user_command("GarryList", function()
  local u = require("garrys.util")
  for name, plugin in pairs(G()._plugins) do
    local status = u.is_installed(plugin.path) and "✔" or "✘"
    local loaded = plugin._loaded and "[loaded]" or "[not loaded]"
    print(status .. " " .. name .. " " .. loaded)
  end
end, { desc = "List all plugins" })

-- Health
vim.api.nvim_create_user_command("GarryHealth", function()
  local garrys  = G()
  local git     = require("garrys.git")
  local u       = require("garrys.util")
  local ui      = require("garrys.ui")
  local plugins = garrys._plugins
  local total   = vim.tbl_count(plugins)

  if total == 0 then u.warn("no plugins registered"); return end

  ui.open()
  ui.set_total(total)

  local count = 0

  for _, plugin in pairs(plugins) do
    local issues = {}

    if not u.is_installed(plugin.path) then
      table.insert(issues, "not installed")
    else
      if not git.is_repo(plugin.path) then
        table.insert(issues, "broken git repo")
      end
      local has_lua    = u.is_installed(plugin.path .. "/lua")
      local has_plugin = u.is_installed(plugin.path .. "/plugin")
      local has_after  = u.is_installed(plugin.path .. "/after")
      if not has_lua and not has_plugin and not has_after then
        table.insert(issues, "no lua/ or plugin/ dir")
      end
      if has_lua then
        local ok = pcall(require, plugin.name)
        if not ok then table.insert(issues, "require() failed") end
      end
    end

    count = count + 1
    vim.schedule(function()
      if #issues == 0 then
        ui.set_status(plugin.name, "✔ healthy")
      else
        ui.set_status(plugin.name, "✘ " .. table.concat(issues, ", "))
      end
      if count == total then ui.finish() end
    end)
  end
end, { desc = "Check plugin health" })

-- Profile
vim.api.nvim_create_user_command("GarryProfile", function()
  require("garrys.profile").report()
end, { desc = "Show startup time per plugin" })

-- Diff
vim.api.nvim_create_user_command("GarryDiff", function()
  require("garrys.diff").show(G()._plugins)
end, { desc = "Show what changed since last update" })

-- Search
vim.api.nvim_create_user_command("GarrySearch", function(args)
  require("garrys.search").pick(args.args)
end, { nargs = "+", desc = "Search GitHub for plugins" })

-- Migrate
vim.api.nvim_create_user_command("GarryMigrate", function(args)
  local input = args.args ~= "" and args.args or nil

  if not input then
    local candidates = {
      vim.fn.stdpath("config") .. "/lua/plugins/init.lua",
      vim.fn.stdpath("config") .. "/lua/plugins.lua",
      vim.fn.stdpath("config") .. "/init.lua",
    }
    for _, path in ipairs(candidates) do
      if vim.loop.fs_stat(path) then input = path; break end
    end
  end

  if not input then
    require("garrys.util").err("no file found usage: :GarryMigrate path/to/lazy/spec.lua")
    return
  end

  local migrate  = require("garrys.migrate")
  local out_path = migrate.convert(input)
  if not out_path then return end

  vim.schedule(function()
    require("garrys.util").info(
      "next steps:\n"
      .. "  1. review " .. out_path .. "\n"
      .. "  2. replace your lazy spec with the garrys.nvim equivalent\n"
      .. "  3. open Neovim it'll fine missing plugins and install automatically"
    )
  end)
end, { nargs = "?", complete = "file", desc = "Migrate lazy.nvim spec to garrys.nvim" })

vim.api.nvim_create_user_command("GarryValidate", function()
  require("garrys.migrate").validate()
end, { desc = "Validate plugin dependency declarations" })
