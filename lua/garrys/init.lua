local M = {}

M._plugins = {}

M.config = {
	path = vim.fn.stdpath("data") .. "/garrys/plugins",
	concurrency = 8,
}

function M.setup(specs, opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Make sure install dir exists
	vim.fn.mkdir(M.config.path, "p")

	for _, spec in ipairs(specs) do
		local plugin = M._normalize(spec)
		M._plugins[plugin.name] = plugin
	end

	-- Load anything already on disk
	for _, plugin in pairs(M._plugins) do
		M._inject(plugin)
	end
end

function M._normalize(spec)
	if type(spec) == "string" then
		spec = { spec }
	end

	local source = spec[1]
	local name = source:match("[^/]+$")

	return {
		name = spec.name or name,
		source = source,
		url = "https://github.com/" .. source .. ".git",
		path = M.config.path .. "/" .. (spec.name or name),
		opts = spec.opts or {},
		config = spec.config or nil,
		build = spec.build or nil,
	}
end

function M._inject(plugin)
	if not vim.loop.fs_stat(plugin.path) then
		return
	end

	vim.opt.rtp:prepend(plugin.path)

	local after = plugin.path .. "/after"
	if vim.loop.fs_stat(after) then
		vim.opt.rtp:append(after)
	end

	if plugin.config then
		plugin.config(plugin.opts)
	elseif next(plugin.opts) ~= nil then
		local ok, mod = pcall(require, plugin.name)
		if ok and mod.setup then
			mod.setup(plugin.opts)
		end
	end
end

return M
