local M = {}

function M.clone(url, path, callback)
	vim.system({ "git", "clone", "--depth=1", "--filter=blob:none", url, path }, { text = true }, function(result)
		callback(result.code == 0, result.stderr)
	end)
end

function M.pull(path, callback)
	vim.system({ "git", "-C", path, "pull", "--rebase", "--autostash" }, { text = true }, function(result)
		callback(result.code == 0, result.stderr)
	end)
end

function M.is_repo(path)
	return vim.loop.fs_stat(path .. "/.git") ~= nil
end

return M
