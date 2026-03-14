local M = {}
local u = require("garrys.util")

-- Inject a plugin into rtp and run its config
function M.inject(plugin)
	if not u.is_installed(plugin.path) then
		return
	end

	vim.opt.rtp:prepend(plugin.path)

	local after = plugin.path .. "/after"
	if u.is_installed(after) then
		vim.opt.rtp:append(after)
	end

	-- Source any plugin/ vim files
	local plugin_dir = plugin.path .. "/plugin"
	if u.is_installed(plugin_dir) then
		local files = vim.fn.glob(plugin_dir .. "/*.{vim,lua}", false, true)
		for _, f in ipairs(files) do
			vim.cmd("source " .. f)
		end
	end

	-- Run config
	if plugin.config then
		local ok, err = pcall(plugin.config, plugin.opts)
		if not ok then
			u.err("config failed for " .. plugin.name .. ": " .. err)
		end
	elseif next(plugin.opts or {}) ~= nil then
		local ok, mod = pcall(require, plugin.name)
		if ok and type(mod) == "table" and mod.setup then
			local setup_ok, err = pcall(mod.setup, plugin.opts)
			if not setup_ok then
				u.err("setup() failed for " .. plugin.name .. ": " .. err)
			end
		end
	end

	plugin._loaded = true
end

-- Register lazy loading triggers for a plugin
function M.register(plugin)
	local function load_once()
		if plugin._loaded then
			return
		end
		M.inject(plugin)
		u.debug(plugin.name .. " lazy-loaded")
	end

	-- Lazy by event
	if plugin.event then
		local events = type(plugin.event) == "string" and { plugin.event } or plugin.event

		vim.api.nvim_create_autocmd(events, {
			once = true,
			callback = load_once,
		})
	end

	-- Lazy by command
	if plugin.cmd then
		local cmds = type(plugin.cmd) == "string" and { plugin.cmd } or plugin.cmd

		for _, cmd in ipairs(cmds) do
			vim.api.nvim_create_user_command(cmd, function(args)
				vim.api.nvim_del_user_command(cmd)
				load_once()
				-- Re-run the command now that the plugin is loaded
				vim.cmd(cmd .. " " .. (args.args or ""))
			end, { nargs = "*", desc = "garrys: lazy load " .. plugin.name })
		end
	end

	-- Lazy by filetype
	if plugin.ft then
		local fts = type(plugin.ft) == "string" and { plugin.ft } or plugin.ft

		vim.api.nvim_create_autocmd("FileType", {
			pattern = fts,
			once = true,
			callback = load_once,
		})
	end

	-- Lazy by keymap
	if plugin.keys then
		local keys = type(plugin.keys) == "string" and { plugin.keys } or plugin.keys

		for _, key in ipairs(keys) do
			vim.keymap.set("n", key, function()
				vim.keymap.del("n", key)
				load_once()
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), "n", false)
			end, { desc = "garrys: lazy load " .. plugin.name })
		end
	end
end

-- Load all plugins respecting lazy flags
function M.load_all(plugins)
	-- Enable Neovim's built-in bytecode cache — free startup speedup
	vim.loader.enable()

	local sorted = u.sort_by_deps(plugins)

	for _, plugin in ipairs(sorted) do
		local is_lazy = plugin.lazy or plugin.event or plugin.cmd or plugin.ft or plugin.keys

		if is_lazy then
			M.register(plugin)
		else
			M.inject(plugin)
		end
	end
end

return M
