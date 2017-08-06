local require = {}

do -- loaders
	local function path_loader(name, paths, loader_func)
		local errors = {}
		local loader

		name = name or ""

		name = name:gsub("%.", "/")

		for path in paths:gmatch("[^;]+") do
			path = path:gsub("%?", name)

			local errmsg

			local val = loader_func(path)

			if type(val) == "function" then
				return val, path
			else
				errmsg = val
			end

			if errmsg then
				table.insert(errors, (errmsg:gsub("\\", "/")))
			else
				table.insert(errors, string.format("no file %q", path:gsub("\\", "/")))
			end
		end

		table.sort(errors, function(a, b) return #a > #b end)

		return table.concat(errors, "\n") .. "\n", paths
	end

	local function preload_loader(name)
		if package.preload[name] then
			return package.preload[name], name
		else
			return ("no field package.preload[%q]\n"):format(name), name
		end
	end

	local function lua_loader(name)
		return path_loader(name, package.path, function(path)
			local func, err = loadfile(path)
			if not func then
				return err, path
			end
			return func, path
		end)
	end

	local function c_loader(name)
		local init_func_name = "luaopen_" .. name:gsub("^.*%-", "", 1):gsub("%.", "_")

		return path_loader(name, package.cpath, function(path)
			local func, err = package.loadlib(path, init_func_name)
			if not func then
				return err, path
			end
			return func, path
		end)
	end

	-- XXX make sure that any added loaders are preserved (esp. luarocks)
	require.loaders = {
		preload_loader,
		lua_loader,
		c_loader,
	}
end

function require.load(name, hint, skip_error)
	local errors = {}

	for _, loaders in ipairs({require.loaders, package.loaders}) do
		for _, loader in ipairs(loaders) do
			local _, val, path = pcall(loader, name)

			if type(val) == "function" then
				if hint and ((type(hint) == "string" and not (path and path:lower():find(hint:lower(), nil, true))) or (type(hint) == "function" and not hint(path))) then
					table.insert(errors, ("hint %q was given but it was not found in the returned path %q\n"):format(hint, path))
				else
					return val, nil, path
				end
			else
				table.insert(errors, val)
			end
		end
	end

	if _G[name] then
		return _G[name], nil, name
	end

	if not errors[1] then
		errors[1] = string.format("module %q not found\n", name)
	end

	return nil, table.concat(errors, ""), name
end

function require.require(name)
	if package.loaded[name] == nil then
		local func, err, path = require.load(name)

		if not func then
			error(err, 2)
		end

		if path then
			path = path:match("(.+)[\\/]")
		end

		if vfs and vfs.PushToFileRunStack and path then
			vfs.PushToFileRunStack(path .. "/")
		end

		local res, err = require.require_function(name, func, path)

		if vfs and vfs.PopFromFileRunStack and path then
			vfs.PopFromFileRunStack()
		end

		if res == nil then
			error(err, 2)
		end

		return res
	end
	return package.loaded[name]
end

local MODULE_CALLED
local IN_MODULE

function module(name, ...)
	require.module_name = name

	if IN_MODULE then
		MODULE_CALLED = true
	end

	return _OLD_G.module(name, ...)
end

function require.require_function(name, func, path, arg_override)
	if package.loaded[name] == nil and package.loaded[path] == nil then
		local dir = path

		if dir then
			dir = dir:match("(.+)[\\/]")
		end

		IN_MODULE = name
		local ok, res = pcall(func, arg_override or dir)

		if ok == false then
			return nil, res
		end

		if MODULE_CALLED then
			res = res or package.loaded[path] or package.loaded[name]
			_G[require.module_name] = res
			MODULE_CALLED = false
		end

		if res and not package.loaded[path] and not package.loaded[name] then
			package.loaded[name] = res
		elseif not res and package.loaded[name] == nil and package.loaded[path] == nil then
			--wlog("module %s (%s) was required but nothing was returned", name, path)
			package.loaded[name] = true
		end
	end

	return package.loaded[path] or package.loaded[name]
end

setmetatable(require, {__call = function(_, name) return require.require(name) end})

return require