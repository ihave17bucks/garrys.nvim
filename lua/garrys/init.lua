local M = {}

M._plugins = {}

M.config = {
	path = vim.fn.stdpath("data") .. "/garrys/plugins",
	lockfile = vim.fn.stdpath("config") .. "/garrys.lock",
	concurrency = 8,
}

function M.setup(specs, opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	vim.fn.mkdir(M.config.path, "p")

	for _, spec in ipairs(specs) do
		local plugin = M._normalize(spec)
		M._plugins[plugin.name] = plugin
	end

	require("garrys.loader").load_all(M._plugins)
end

function M._normalize(spec)
	if type(spec) == "string" then
		spec = { spec }
	end

	local source = spec[1]
	local name = source:match("[^/]+$")
	local u = require("garrys.util")

	return {
		name = spec.name or name,
		source = source,
		url = "https://github.com/" .. source .. ".git",
		path = u.plugin_path(M.config.path, spec.name or name),
		lazy = spec.lazy or false,
		event = spec.event or nil,
		cmd = spec.cmd or nil,
		ft = spec.ft or nil,
		keys = spec.keys or nil,
		depends = spec.depends or {},
		opts = spec.opts or {},
		config = spec.config or nil,
		build = spec.build or nil,
		pin = spec.pin or nil,
		_loaded = false,
	}
end

return M
