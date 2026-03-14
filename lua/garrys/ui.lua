local M = {}
local api = vim.api

M._buf = nil
M._win = nil
M._lines = {}

local function get_dimensions()
	local width = math.floor(vim.o.columns * 0.5)
	local height = math.floor(vim.o.lines * 0.6)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	return width, height, row, col
end

function M.open()
	if M._win and api.nvim_win_is_valid(M._win) then
		return
	end

	M._buf = api.nvim_create_buf(false, true)
	M._lines = {}

	local width, height, row, col = get_dimensions()

	vim.bo[M._buf].filetype = "garrys"
	vim.bo[M._buf].modifiable = false
	vim.bo[M._buf].bufhidden = "wipe"

	M._win = api.nvim_open_win(M._buf, false, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " garrys.nvim ",
		title_pos = "center",
	})

	vim.wo[M._win].wrap = false
	vim.wo[M._win].cursorline = true

	-- Header
	M._write_raw({
		"  Plugin Manager",
		"  " .. string.rep("─", 40),
		"",
	})

	-- Close on q or <Esc>
	for _, key in ipairs({ "q", "<Esc>" }) do
		vim.keymap.set("n", key, function()
			M.close()
		end, {
			buffer = M._buf,
			silent = true,
			nowait = true,
		})
	end
end

function M._write_raw(lines)
	if not M._buf or not api.nvim_buf_is_valid(M._buf) then
		return
	end

	vim.bo[M._buf].modifiable = true

	for _, line in ipairs(lines) do
		table.insert(M._lines, line)
	end

	api.nvim_buf_set_lines(M._buf, 0, -1, false, M._lines)
	vim.bo[M._buf].modifiable = false

	-- Auto-scroll to bottom
	if M._win and api.nvim_win_is_valid(M._win) then
		api.nvim_win_set_cursor(M._win, { #M._lines, 0 })
	end
end

-- Update or append a plugin's status line
function M.set_status(name, status)
	if not M._buf or not api.nvim_buf_is_valid(M._buf) then
		return
	end

	local line = "  " .. name .. string.rep(" ", math.max(1, 32 - #name)) .. status

	-- Check if this plugin already has a line
	for i, existing in ipairs(M._lines) do
		if existing:find(name, 1, true) then
			vim.bo[M._buf].modifiable = true
			api.nvim_buf_set_lines(M._buf, i - 1, i, false, { line })
			vim.bo[M._buf].modifiable = false
			return
		end
	end

	-- Otherwise append
	M._write_raw({ line })
end

function M.finish()
	M._write_raw({
		"",
		"  " .. string.rep("─", 40),
		"  Done. Press q to close.",
	})
end

function M.close()
	if M._win and api.nvim_win_is_valid(M._win) then
		api.nvim_win_close(M._win, true)
	end
	M._win = nil
	M._buf = nil
	M._lines = {}
end

-- Show a read-only status overview (for :GarryList)
function M.open_status(plugins)
	M.open()

	for _, plugin in pairs(plugins) do
		local installed = vim.loop.fs_stat(plugin.path) and "✓ installed" or "✗ missing"
		local lazy_flag = (plugin.lazy or plugin.event or plugin.cmd or plugin.ft) and " [lazy]" or ""
		M.set_status(plugin.name, installed .. lazy_flag)
	end

	M.finish()
end

return M
