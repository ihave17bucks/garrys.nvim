local git = require("garrys.git")

vim.api.nvim_create_user_command("GarryInstall", function()
	local garrys = require("garrys")
	local plugins = garrys._plugins
	local pending = {}

	for _, plugin in pairs(plugins) do
		if not vim.loop.fs_stat(plugin.path) then
			table.insert(pending, plugin)
		end
	end

	if #pending == 0 then
		vim.notify("[garrys] Nothing to install.", vim.log.levels.INFO)
		return
	end

	local done = 0
	local config = garrys.config
	local active = 0
	local i = 1

	local function dispatch()
		while active < config.concurrency and i <= #pending do
			local plugin = pending[i]
			i = i + 1
			active = active + 1

			vim.notify("[garrys] Installing " .. plugin.name .. "...", vim.log.levels.INFO)

			git.clone(plugin.url, plugin.path, function(ok, err)
				active = active - 1
				done = done + 1

				vim.schedule(function()
					if ok then
						vim.notify("[garrys] ✓ " .. plugin.name, vim.log.levels.INFO)
						garrys._inject(plugin)
					else
						vim.notify(
							"[garrys] ✗ " .. plugin.name .. ": " .. (err or "unknown error"),
							vim.log.levels.ERROR
						)
					end

					if done == #pending then
						vim.notify("[garrys] Done. " .. done .. " plugin(s) installed.", vim.log.levels.INFO)
					else
						dispatch()
					end
				end)
			end)
		end
	end

	dispatch()
end, { desc = "Install missing plugins" })

vim.api.nvim_create_user_command("GarryUpdate", function()
	local plugins = require("garrys")._plugins
	local count = 0
	local total = vim.tbl_count(plugins)

	for _, plugin in pairs(plugins) do
		if git.is_repo(plugin.path) then
			vim.notify("[garrys] Updating " .. plugin.name .. "...", vim.log.levels.INFO)

			git.pull(plugin.path, function(ok, err)
				count = count + 1

				vim.schedule(function()
					if ok then
						vim.notify("[garrys] ✓ " .. plugin.name .. " updated", vim.log.levels.INFO)
					else
						vim.notify(
							"[garrys] ✗ " .. plugin.name .. ": " .. (err or "unknown error"),
							vim.log.levels.ERROR
						)
					end

					if count == total then
						vim.notify("[garrys] All plugins updated.", vim.log.levels.INFO)
					end
				end)
			end)
		else
			total = total - 1
		end
	end
end, { desc = "Update all plugins" })

vim.api.nvim_create_user_command("GarryList", function()
	local plugins = require("garrys")._plugins

	for name, plugin in pairs(plugins) do
		local installed = vim.loop.fs_stat(plugin.path) and "✓" or "✗"
		print(installed .. " " .. name .. "  →  " .. plugin.path)
	end
end, { desc = "List all plugins and their status" })
