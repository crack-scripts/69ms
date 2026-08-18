-- hai.lua
--
-- "hookOp" pass: reads a file from hook_op/file_cache/<name>, parses it with
-- the Prometheus front-end and writes the unparsed (re-formatted) result back.
-- With PrettyPrint enabled this turns a single-line obfuscated blob into
-- readable, indented Lua.

-- Configure package.path so the prometheus submodules can be required.
local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	-- Fall back to "./" when invoked without a path separator (e.g. `lua hai.lua`).
	return str:match("(.*[/%\\])") or "./"
end
package.path = script_path() .. "?.lua;" .. package.path

local logger   = require("logger")
local parser   = require("prometheus.parser"):new{ LuaVersion = "LuaU" }
local unparser = require("prometheus.unparser"):new{ LuaVersion = "LuaU", PrettyPrint = true }

-- Heavily obfuscated inputs legitimately reuse variable names across scopes,
-- which makes the parser emit a flood of "variable already defined" warnings.
-- Silence just those, but keep info/error logging so we can see progress.
logger.logLevel     = logger.LogLevel.Info
logger.warnCallback = function() end

-- Read the whole file (nil-safe, unlike io.lines which errors on a missing file).
local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		logger:error(string.format("The file \"%s\" was not found!", path))
	end
	local content = f:read("*a")
	f:close()
	return content
end

local name = arg[1]
if not name then
	logger:error("Usage: lua hai.lua <filename in hook_op/file_cache/>")
end

local filename = "hook_op/file_cache/" .. name

logger:info(string.format("Reading \"%s\" ...", filename))
local source = read_file(filename)

logger:info("Parsing ...")
local ast = parser:parse(source)

logger:info("Unparsing ...")
local result = unparser:unparse(ast)

local handle = io.open(filename, "w")
handle:write(result)
handle:close()

logger:info(string.format("Done. Wrote %d bytes to \"%s\"", #result, filename))
