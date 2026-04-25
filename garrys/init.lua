local M = {}

M._plugins = {}
M._load_times = {}

M.config = {
	path = vim.fn.stdpath("data") .. "/garrys/plugins",
	lockfile = vim.fn.stdpath("config") .. "/garrys.lock",
	concurrency = 8,
	autoinstall = true,
	strict_deps = false, -- off by default so copy-pasted lazy configs just work
	plugin_dir = vim.fn.stdpath("config") .. "/lua/plugins",
}

-- Public API

-- Drop-in replacement: require("garrys").setup({ ... }) works like lazy.nvim
function M.setup(specs, opts)
	local ok, err = pcall(function()
		if opts then
			M.config = vim.tbl_deep_extend("force", M.config, opts)
		end

		vim.fn.mkdir(M.config.path, "p")

		for _, spec in ipairs(specs or {}) do
			local plugin = M._normalize(spec)
			if plugin then
				M._plugins[plugin.name] = plugin
			end
		end

		-- Auto-discover lua/plugins/*.lua without requiring file structure changes
		M._discover()

		if M.config.strict_deps then
			M._validate_deps()
		end

		require("garrys.loader").load_all(M._plugins)

		if M.config.autoinstall then
			M._autoinstall()
		end
	end)

	if not ok then
		-- Warn but never crash Neovim
		vim.notify("[garrys] setup error: " .. tostring(err), vim.log.levels.ERROR)
	end
end

-- Chainable API: g.plug("x").plug("y").load()
function M.plug(spec)
	local ok, err = pcall(function()
		if type(spec) == "string" then
			spec = { spec }
		end
		local plugin = M._normalize(spec)
		if plugin then
			M._plugins[plugin.name] = plugin
		end
	end)
	if not ok then
		vim.notify("[garrys] invalid spec, skipping: " .. tostring(err), vim.log.levels.WARN)
	end
	return M -- chainable
end

function M.load(opts)
	M.setup(nil, opts)
end

-- Normalize
-- Accepts lazy.nvim specs 1:1 — user can copy-paste without changing anything

function M._normalize(spec)
	-- Handle invalid specs gracefully — warn and skip, never crash
	if spec == nil then
		return nil
	end

	if type(spec) ~= "table" and type(spec) ~= "string" then
		vim.notify("[garrys] skipping invalid spec type: " .. type(spec), vim.log.levels.WARN)
		return nil
	end

	if type(spec) == "string" then
		spec = { spec }
	end

	local source = spec[1]

	-- Handle lazy.nvim url = "..." specs
	if not source and spec.url then
		source = spec.url:match("([^/]+/[^/%.]+)%.git$") or spec.url
	end

	-- Handle local dir = "..." specs just add to rtp, no install needed
	if not source and spec.dir then
		local ok = pcall(function()
			if vim.loop.fs_stat(spec.dir) then
				vim.opt.rtp:prepend(spec.dir)
				local after = spec.dir .. "/after"
				if vim.loop.fs_stat(after) then
					vim.opt.rtp:append(after)
				end
				-- Run init if provided (lazy.nvim compat)
				if spec.init then
					pcall(spec.init)
				end
				vim.notify("[garrys] loaded local plugin: " .. spec.dir, vim.log.levels.INFO)
			else
				vim.notify("[garrys] local dir not found: " .. spec.dir, vim.log.levels.WARN)
			end
		end)
		if not ok then
			vim.notify("[garrys] error loading local plugin: " .. tostring(spec.dir), vim.log.levels.WARN)
		end
		return nil -- handled inline, no install needed
	end

	if not source then
		vim.notify("[garrys] skipping spec with no source", vim.log.levels.WARN)
		return nil
	end

	-- cond skip plugin if condition is false (lazy.nvim compat)
	if spec.cond ~= nil then
		local cond_ok, result = pcall(function()
			return type(spec.cond) == "function" and spec.cond() or spec.cond
		end)
		if not cond_ok or not result then
			return nil
		end
	end

	local name = spec.name or source:match("[^/]+$")
	if not name or name == "" then
		vim.notify("[garrys] could not determine name for " .. tostring(source), vim.log.levels.WARN)
		return nil
	end

	local u = require("garrys.util")

	-- Accept dependencies (lazy.nvim), depends, AND dep (garrys short form)
	local raw_deps = spec.dependencies or spec.depends or spec.dep or {}

	-- Normalize deps lazy.nvim allows full specs inside dependencies
	local dep_clean = {}
	for _, d in ipairs(raw_deps) do
		if type(d) == "string" then
			table.insert(dep_clean, d)
		elseif type(d) == "table" and d[1] then
			table.insert(dep_clean, d[1])
			-- Also register sub-spec as its own plugin
			local dep_name = d[1]:match("[^/]+$")
			if dep_name and not M._plugins[dep_name] then
				local sub = M._normalize(d)
				if sub then
					M._plugins[sub.name] = sub
				end
			end
		end
	end

	return {
		name = name,
		source = source,
		url = spec.url or ("https://github.com/" .. source .. ".git"),
		path = u.plugin_path(M.config.path, name),

		-- Lazy loading — identical to lazy.nvim
		lazy = spec.lazy or false,
		event = spec.event or nil,
		cmd = spec.cmd or nil,
		ft = spec.ft or nil,
		keys = spec.keys or nil,
		cond = spec.cond or nil,
		pin = spec.pin or false,

		dep = dep_clean,

		-- config / on both accepted (lazy.nvim compat)
		on = spec.on or spec.config or nil,
		-- init runs before load (lazy.nvim compat)
		init = spec.init or nil,
		-- build / make both accepted (lazy.nvim compat)
		make = spec.make or spec.build or nil,

		opts = spec.opts or {},

		-- These lazy.nvim fields are silently accepted but not used
		-- priority, dev, version, module no errors, no warnings
		_loaded = false,
	}
end

-- Discovery

function M._discover()
	local dir = M.config.plugin_dir
	if not vim.loop.fs_stat(dir) then
		return
	end

	local handle = vim.loop.fs_scandir(dir)
	if not handle then
		return
	end

	while true do
		local fname, ftype = vim.loop.fs_scandir_next(handle)
		if not fname then
			break
		end
		if ftype == "file" and fname:match("%.lua$") then
			local mod = "plugins." .. fname:gsub("%.lua$", "")
			local ok, result = pcall(require, mod)
			if ok and type(result) == "table" then
				for _, spec in ipairs(result) do
					local plugin = M._normalize(spec)
					if plugin and not M._plugins[plugin.name] then
						M._plugins[plugin.name] = plugin
					end
				end
			elseif not ok then
				vim.notify("[garrys] skipping " .. mod .. ": " .. tostring(result), vim.log.levels.WARN)
			end
		end
	end
end

-- Dep validation (opt-in)

function M._validate_deps()
	local warnings = {}
	for _, plugin in pairs(M._plugins) do
		for _, dep in ipairs(plugin.dep or {}) do
			local dep_name = dep:match("[^/]+$")
			if dep_name and not M._plugins[dep_name] then
				table.insert(warnings, string.format("'%s' needs '%s' not in spec", plugin.name, dep))
			end
		end
	end
	if #warnings > 0 then
		vim.notify("[garrys] dep warnings:\n  " .. table.concat(warnings, "\n  "), vim.log.levels.WARN)
	end
end

-- Autoinstall

function M._autoinstall()
	local u = require("garrys.util")
	local missing = {}

	for _, plugin in pairs(M._plugins) do
		if not u.is_installed(plugin.path) then
			table.insert(missing, plugin)
		end
	end

	if #missing == 0 then
		return
	end

	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			local ok, err = pcall(function()
				local git = require("garrys.git")
				local ui = require("garrys.ui")
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

						git.clone(plugin.url, plugin.path, function(clone_ok, clone_err)
							active = active - 1
							done = done + 1
							vim.schedule(function()
								if clone_ok then
									ui.set_status(plugin.name, "✔ installed")
									-- Safely inject warn on failure, never crash
									local inject_ok, inject_err = pcall(loader.inject, plugin)
									if not inject_ok then
										vim.notify(
											"[garrys] inject failed for " .. plugin.name .. ": " .. tostring(inject_err),
											vim.log.levels.WARN
										)
									end
									if plugin.make then
										local build_ok, build_err = pcall(u.run_build, plugin)
										if not build_ok then
											vim.notify(
												"[garrys] build failed for "
													.. plugin.name
													.. ": "
													.. tostring(build_err),
												vim.log.levels.WARN
											)
										end
									end
								else
									-- Retry once before giving up
									ui.set_status(plugin.name, "⟳ retrying...")
									git.clone(plugin.url, plugin.path, function(retry_ok, retry_err)
										vim.schedule(function()
											if retry_ok then
												ui.set_status(plugin.name, "✔ installed (retry)")
												pcall(loader.inject, plugin)
											else
												ui.set_status(
													plugin.name,
													"✘ " .. (retry_err or clone_err or "failed"):gsub("\n", " ")
												)
												vim.notify(
													"[garrys] " .. plugin.name .. " failed after retry skipping",
													vim.log.levels.WARN
												)
											end
										end)
									end)
								end
								if done == #missing then
									ui.finish()
								else
									dispatch()
								end
							end)
						end)
					end
				end

				dispatch()
			end)

			if not ok then
				vim.notify("[garrys] autoinstall error: " .. tostring(err), vim.log.levels.ERROR)
			end
		end,
	})
end

-- Helpers

function M.has_missing()
	local u = require("garrys.util")
	for _, plugin in pairs(M._plugins) do
		if not u.is_installed(plugin.path) then
			return true
		end
	end
	return false
end

function M.get(name)
	return M._plugins[name]
end

return M
