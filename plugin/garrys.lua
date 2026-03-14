local function get_garrys()
	return require("garrys")
end

-- Install missing plugins
vim.api.nvim_create_user_command("GarryInstall", function()
	local garrys = get_garrys()
	local git = require("garrys.git")
	local ui = require("garrys.ui")
	local u = require("garrys.util")
	local loader = require("garrys.loader")
	local plugins = garrys._plugins
	local pending = {}

	for _, plugin in pairs(plugins) do
		if not u.is_installed(plugin.path) then
			table.insert(pending, plugin)
		end
	end

	if #pending == 0 then
		u.info("everything is already installed...")
		return
	end

	ui.open()

	local done = 0
	local active = 0
	local i = 1

	local function dispatch()
		while active < garrys.config.concurrency and i <= #pending do
			local plugin = pending[i]
			i = i + 1
			active = active + 1

			ui.set_status(plugin.name, "⟳ installing...")

			git.clone(plugin.url, plugin.path, function(ok, err)
				active = active - 1
				done = done + 1

				vim.schedule(function()
					if ok then
						ui.set_status(plugin.name, "✓ installed")
						loader.inject(plugin)
						u.run_build(plugin)
					else
						ui.set_status(plugin.name, "✗ " .. (err or "failed"):gsub("\n", " "))
					end

					if done == #pending then
						ui.finish()
					else
						dispatch()
					end
				end)
			end)
		end
	end

	dispatch()
end, { desc = "Install missing plugins" })

-- Update all plugins
vim.api.nvim_create_user_command("GarryUpdate", function()
	local garrys = get_garrys()
	local git = require("garrys.git")
	local ui = require("garrys.ui")
	local u = require("garrys.util")
	local plugins = garrys._plugins
	local updatable = {}

	for _, plugin in pairs(plugins) do
		if git.is_repo(plugin.path) and not plugin.pin then
			table.insert(updatable, plugin)
		end
	end

	if #updatable == 0 then
		u.info("nothing to update")
		return
	end

	ui.open()

	local done = 0
	local active = 0
	local i = 1

	local function dispatch()
		while active < garrys.config.concurrency and i <= #updatable do
			local plugin = updatable[i]
			i = i + 1
			active = active + 1

			ui.set_status(plugin.name, "⟳ updating...")

			git.pull(plugin.path, function(ok, err)
				active = active - 1
				done = done + 1

				vim.schedule(function()
					if ok then
						ui.set_status(plugin.name, "✓ updated")
					else
						ui.set_status(plugin.name, "✗ " .. (err or "failed"):gsub("\n", " "))
					end

					if done == #updatable then
						ui.finish()
					else
						dispatch()
					end
				end)
			end)
		end
	end

	dispatch()
end, { desc = "Update all plugins" })

-- Remove plugins not in the spec
vim.api.nvim_create_user_command("GarryClean", function()
	local garrys = get_garrys()
	local u = require("garrys.util")
	local installed = u.list_installed(garrys.config.path)
	local removed = 0

	for _, name in ipairs(installed) do
		if not garrys._plugins[name] then
			local path = garrys.config.path .. "/" .. name
			vim.fn.delete(path, "rf")
			u.info("removed " .. name)
			removed = removed + 1
		end
	end

	if removed == 0 then
		u.info("nothing to clean")
	else
		u.info("cleaned " .. removed .. " plugin(s)")
	end
end, { desc = "Remove plugins not in spec" })

-- Write lockfile
vim.api.nvim_create_user_command("GarryLock", function()
	require("garrys.lockfile").write(get_garrys()._plugins)
end, { desc = "Write garrys.lock" })

-- Restore plugins to locked commits
vim.api.nvim_create_user_command("GarryRestore", function()
	require("garrys.lockfile").restore(get_garrys()._plugins)
end, { desc = "Restore plugins to garrys.lock commits" })

-- Show status window
vim.api.nvim_create_user_command("GarryStatus", function()
	require("garrys.ui").open_status(get_garrys()._plugins)
end, { desc = "Show plugin status" })

-- List plugins in cmdline (quick)
vim.api.nvim_create_user_command("GarryList", function()
	local garrys = get_garrys()
	local u = require("garrys.util")

	for name, plugin in pairs(garrys._plugins) do
		local status = u.is_installed(plugin.path) and "✓" or "✗"
		local loaded = plugin._loaded and "[loaded]" or "[not loaded]"
		print(status .. " " .. name .. " " .. loaded)
	end
end, { desc = "List all plugins" })
