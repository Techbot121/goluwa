local profile_start_time = os.clock()

os.setlocale("")
io.stdout:setvbuf("no")

_G[jit.os:upper()] = true
_G[jit.arch:upper()] = true

do
	-- force lookup modules in current directory rather than system
	if WINDOWS then
		package.cpath = "./?.dll"
	elseif OSX then
		package.cpath = "./?.dylib;./?.so"
	else
		package.cpath = "./?.so"
	end

	package.path = "./?.lua"

	table.insert(package.loaders, function(name)
		return loadfile("../../../src/lua/build/" .. name .. "/" .. name .. ".lua")
	end)

	table.insert(package.loaders, function(name)
		name = name:gsub("%.", "/")
		return loadfile("../../../src/lua/build/" .. name .. ".lua")
	end)

	-- force current directory
	local path = debug.getinfo(1).source

	if path:sub(1, 1) == "@" and pcall(require, ffi) then
		local ffi = require("ffi")

		path = path:gsub("\\", "/")

		local dir = path:match("@(.+/)src/lua/init.lua$")

		if dir then
			dir = dir .. "data/bin/" .. ffi.os .. "_" .. ffi.arch .. "/"
			dir = dir:lower()

			if WINDOWS then
				ffi.cdef("int SetCurrentDirectoryA(const char *);")
				ffi.C.SetCurrentDirectoryA(dir)
			else
				ffi.cdef("int chdir(const char *);")
				ffi.C.chdir(dir)
			end
		end
	end
end

do -- constants
	local env_vars = {
		SERVER = false,
		CLIENT = true,
		GRAPHICS = true,
		SOUND = true,
		DEBUG = false,
		CURSES = true,
		SOCKETS = true,
		SRGB = true,
		LOOP = true,
		WINDOW = true,
		NULL_OPENGL = false,
		PHYSICS = false,
		DISABLE_CULLING = false,
		DEBUG_OPENGL = false,
		BUILD_SHADER_OUTPUT = false,
		CLI = false,
		TMUX = false,
		VERBOSE_STARTUP = true,

		OPENGL = true,
		VULKAN = false,
	}

	for key, default in pairs(env_vars) do
		if _G[key] == nil then
			local val = os.getenv("GOLUWA_" .. key)
			if val == "0" then
				_G[key] = false
			elseif val == "1" then
				_G[key] = true
			elseif default then
				_G[key] = default
			end
		end
	end

	if os.getenv("CODEXL") == "1" or os.getenv("MESA_DEBUG") == "1" then
		EXTERNAL_DEBUGGER = true
	end

	if LINUX then
		WINDOWS = false
	end

	if WINDOWS then
		LINUX = false
	end

	for k in pairs(env_vars) do
		if _G[k] == nil then
			_G[k] = false
		end
	end

	if EXTERNAL_DEBUGGER == nil then
		EXTERNAL_DEBUGGER = false
	end

	RELOAD = false
	CREATED_ENV = false

	if CLI or TMUX then
		GRAPHICS = false
		WINDOW = false
		CLIENT = false
		SERVER = false
		SOUND = false
		PHYSICS = false
	end

	if CLI then
		LOOP = false
		CURSES = false
		VERBOSE_STARTUP = false
	end

	if TMUX then
		_G.USERNAME = "tmux"
	end

	if LINUX and (GRAPHICS or WINDOW) and not os.getenv("DISPLAY") then
		GRAPHICS = false
		WINDOW = false
		io.write("os.getenv('DISPLAY') is nil.\nsetting GRAPHICS and WINDOW to false.\n")
	end

	-- enums table
	e = e or {}

	e.USERNAME = _G.USERNAME or tostring(os.getenv("USERNAME") or os.getenv("USER")):gsub(" ", "_"):gsub("%p", "")
	_G[e.USERNAME:upper()] = true

	--[[
	--uncomment to check _G lookups
	setmetatable(_G, {
		__index = function(s,k)
			io.write("__index: _G.", k, ": ", debug.getinfo(2).source:sub(2), ":", debug.getinfo(2).currentline,"\n")
		end,
		__newindex = function(s,k,v)
			if k:upper() ~= k then
				io.write("__newindex _G.", k, " = ", type(v) ,": ", debug.getinfo(2).source:sub(2), ":", debug.getinfo(2).currentline,"\n")
			end
			rawset(s,k,v)
		end,
	})
	--]]
end

-- put all c functions in a table so we can override them if needed
-- without doing the local oldfunc = print thing over and over again
do
	-- this will be replaced with utility.GetOldGLibrary() later on
	_OLD_G = {}
	local done = {[_G] = true}

	local function scan(tbl, store)
		for key, val in pairs(tbl) do
			local t = type(val)

			if t == "table" and not done[val] and val ~= store then
				store[key] = store[key] or {}
				done[val] = true
				scan(val, store[key])
			else
				store[key] = val
			end
		end
	end
	if pcall(require, "ffi") then
		_G.ffi = require("ffi")
	end
	scan(_G, _OLD_G)
	_G.ffi = nil
end

do
	-- this is required because fs needs winapi and syscall
	table.insert(package.loaders, function(name) name = name:gsub("%.", "/") return loadfile("../../../src/lua/modules/" .. name .. ".lua") end)
	table.insert(package.loaders, function(name) name = name:gsub("%.", "/") return loadfile("../../../src/lua/modules/" .. name .. "/init.lua") end)
	local fs = dofile("../../../src/lua/libraries/fs.lua")
	package.loaded.fs = fs
	-- remove the temporary added loaders from top because we do it properly later on
	table.remove(package.loaders)
	table.remove(package.loaders)

	-- create constants

	e.BIN_FOLDER = fs.getcd():gsub("\\", "/") .. "/"
	e.ROOT_FOLDER = e.BIN_FOLDER:match("(.+/)" .. (".-/"):rep(3)) -- the root folder is always 3 directories up (data/bin/os_arch)
	e.SRC_FOLDER = e.ROOT_FOLDER .. "src/"
	e.DATA_FOLDER = e.ROOT_FOLDER .. "data/"
	e.USERDATA_FOLDER = e.DATA_FOLDER .. "users/" .. e.USERNAME:lower() .. "/"

	fs.createdir(e.DATA_FOLDER)
	fs.createdir(e.DATA_FOLDER .. "users/")
	fs.createdir(e.USERDATA_FOLDER)
end

-- some of the lua files ran below use check and include which don't exist yet
_G.check = function() end
_G.runfile = function() end
_G.system = false
_G.event = false

local commands_add_buffer = {}
_G.commands = {Add = function(...) table.insert(commands_add_buffer, {...}) end}

local temp_runfile = function(path) return dofile(e.SRC_FOLDER .. path) end

-- standard library extensions
temp_runfile("lua/libraries/extensions/jit.lua")
temp_runfile("lua/libraries/extensions/globals.lua")
temp_runfile("lua/libraries/extensions/debug.lua")
temp_runfile("lua/libraries/extensions/string.lua")
temp_runfile("lua/libraries/extensions/table.lua")
temp_runfile("lua/libraries/extensions/os.lua")
temp_runfile("lua/libraries/extensions/ffi.lua")
temp_runfile("lua/libraries/extensions/math.lua")


-- include some of prototype as required by vfs
utility = {CreateWeakTable = function() return setmetatable({}, {__mode = "kv"}) end}

prototype = temp_runfile("lua/libraries/prototype/prototype.lua")
temp_runfile("lua/libraries/prototype/get_is_set.lua")
temp_runfile("lua/libraries/prototype/base_object.lua")
temp_runfile("lua/libraries/prototype/null.lua")


-- include some of vfs so we can setup and mount the filesystem
vfs = temp_runfile("lua/libraries/filesystem/vfs.lua")
temp_runfile("lua/libraries/filesystem/path_utilities.lua")
temp_runfile("lua/libraries/filesystem/base_file.lua")
temp_runfile("lua/libraries/filesystem/find.lua")
temp_runfile("lua/libraries/filesystem/helpers.lua")
temp_runfile("lua/libraries/filesystem/lua_utilities.lua")
temp_runfile("lua/libraries/filesystem/addons.lua")
temp_runfile("lua/libraries/filesystem/files/os.lua")

vfs.Mount("os:" .. e.USERDATA_FOLDER, "data") -- mount "ROOT/data/users/*username*/" to "/data/"
vfs.Mount("os:" .. e.BIN_FOLDER, "bin") -- mount "ROOT/data/bin" to "/bin/"
vfs.MountAddon("os:" .. e.SRC_FOLDER) -- mount "ROOT/src" to "/"
vfs.GetAddonInfo("src").startup = nil -- prevent init.lua from running later on again

-- this will just make require("bit32") will have an early exit
package.preload.bit32 = function() error("we're luajit") end

vfs.AddModuleDirectory("lua/modules/")
vfs.AddModuleDirectory("lua/libraries/")

do -- full path
	vfs.AddPackageLoader(function(path)
		return vfs.LoadFile(path)
	end)

	vfs.AddPackageLoader(function(path)
		return vfs.LoadFile(path .. ".lua")
	end)

	vfs.AddPackageLoader(function(path)
		path = path:gsub("(.)%.(.)", "%1/%2")
		return vfs.LoadFile(path .. ".lua")
	end)

	vfs.AddPackageLoader(function(path)
		path = path:gsub("(.+/)(.+)", function(a, str) return a .. str:gsub("(.)%.(.)", "%1/%2") end)
		return vfs.LoadFile(path .. ".lua")
	end)
end

_G.runfile = function(...) local ret = {vfs.RunFile(...)} if not ret[1] and ret[2] then wlog(ret[2], 2) end return unpack(ret) end
_G.R = vfs.GetAbsolutePath -- a nice global for loading resources externally from current dir
_G.require = runfile("lua/libraries/require.lua") -- replace require with the pure lua version
_G.module = _G.require.module

-- now we can use runfile properly

--require("strung").install() -- this shaves off 5 seconds off of loading gm_construct

-- libraries
pvars = runfile("lua/libraries/pvars.lua") -- like cvars
prototype = runfile("lua/libraries/prototype/prototype.lua") -- handles classes, objects, etc

if GRAPHICS then
	math3d = runfile("lua/libraries/graphics/math3d.lua") -- 3d math functions
	math2d = runfile("lua/libraries/graphics/math2d.lua") -- 2d math functions
end

crypto = runfile("lua/libraries/crypto.lua") -- base64 and other hash functions
serializer = runfile("lua/libraries/serializer.lua") -- for serializing lua data in different formats
structs = runfile("lua/libraries/structs.lua") -- Vec3(x,y,z), Vec2(x,y), Ang3(p,y,r),  etc

commands = runfile("lua/libraries/commands.lua") -- console command type interface for running in repl, chat, etc
-- add all commands that were added before the commands library was available
for i, args in ipairs(commands_add_buffer) do commands.Add(unpack(args)) end

if CURSES then
	repl = runfile("lua/libraries/repl.lua") -- read eval print loop using curses
	if not repl then
		CURSES = false
	end
end

system = runfile("lua/libraries/system.lua") -- os and luajit related functions like creating windows or changing jit options
utility = runfile("lua/libraries/utilities/utility.lua") -- misc functions i don't know where to put

event = runfile("lua/libraries/event.lua") -- event handler
_G.goluwa = event.CreateRealm("goluwa")

input = runfile("lua/libraries/input.lua") -- keyboard and mouse input
utf8 = runfile("lua/libraries/utf8.lua") -- utf8 string library, also extends to string as utf8.len > string.ulen
tasks = runfile("lua/libraries/tasks.lua") -- high level abstraction around coroutines
vfs = runfile("lua/libraries/filesystem/vfs.lua") -- include the filesystem again so it will include all the details such as zip file reading
expression = runfile("lua/libraries/expression.lua") -- used by chat and editor to run small and safe lua expressions

if CURSES or WINDOW then
	autocomplete = runfile("lua/libraries/autocomplete.lua") -- mainly used in console and chatsounds
end

profiler = runfile("lua/libraries/profiler.lua") -- for profiling
_G.P = profiler.ToggleTimer
_G.I = profiler.ToggleInstrumental
_G.S = profiler.ToggleStatistical

if PHYSICS then
	physics = runfile("lua/libraries/physics/physics.lua") -- bullet physics
	if not physics then
		PHYSICS = false
	end
end

steam = runfile("lua/libraries/steam/steam.lua") -- utilities for dealing with steam, the source engine and steamworks

if SOCKETS then
	sockets = runfile("lua/libraries/sockets/sockets.lua") -- luasocket wrapper mostly for web stuff

	if not sockets then
		SOCKETS = false
	end
end

resource = runfile("lua/libraries/sockets/resource.lua") -- used for downloading resources with resource.Download("http://...", function(path) end)

if SERVER or CLIENT then
	enet = runfile("lua/libraries/network/enet.lua") -- low level udp library

	if enet then
		network = runfile("lua/libraries/network/network.lua") -- high level implementation of enet
		packet = runfile("lua/libraries/network/packet.lua") -- medium (?) level communication between server and client
		message = runfile("lua/libraries/network/message.lua") -- high level communication between server and client

		nvars = runfile("lua/libraries/network/nvars.lua") -- variable synchronization between server and client
		clients = runfile("lua/libraries/network/clients.lua") -- high level wrapper for a connected client

		NETWORK = true
	else
		NETWORK = false
		CLIENT = false
		SERVER = false
	end
end

if GRAPHICS then
	camera = runfile("lua/libraries/graphics/camera.lua") -- 2d and 3d camera used for rendering
	render = runfile("lua/libraries/graphics/render/render.lua") -- OpenGL abstraction

	if render then
		render2d = runfile("lua/libraries/graphics/render2d/render2d.lua") -- low level 2d rendering based on the render library
		fonts = runfile("lua/libraries/graphics/fonts/fonts.lua") -- font rendering
		gfx = runfile("lua/libraries/graphics/gfx/gfx.lua") -- high level 2d and 3d functions based on render2d, fonts and render
		render3d = runfile("lua/libraries/graphics/render3d/render3d.lua")
		window = runfile("lua/libraries/graphics/window.lua") -- window implementation
	end
end

if not render or not window then
	GRAPHICS = false
	WINDOW = false
end

if SOUND then
	audio = runfile("lua/libraries/audio/audio.lua") -- high level implementation of OpenAl

	if not audio then
		SOUND = false
	end
end


entities = runfile("lua/libraries/entities/entities.lua") -- entity component system

if VERBOSE_STARTUP then
	llog("including libraries took %s seconds", os.clock() - profile_start_time)
end

profiler.startup_time = profile_start_time

runfile("lua/main.lua")
