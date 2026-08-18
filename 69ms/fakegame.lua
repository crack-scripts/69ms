-- Ported from 69ms/fakegame.lua. Pure Lua, no requires.
local task = {
    wait = function(t)
        return t or 0
    end,
    spawn = function(func)
        func()
    end,
    defer = function(func)
        func()
    end,
    delay = function(t, func)
        func()
    end
}

local _tbl
_tbl = setmetatable({}, {
    __index = function()
        return _tbl
    end,
    __call = function()
        return _tbl
    end,
    __newindex = function() end,
    -- Make _tbl survive being used in arithmetic / comparison / concat / # so a
    -- fake value reaching one of those ops doesn't crash the dump.
    __add = function() return _tbl end,
    __sub = function() return _tbl end,
    __mul = function() return _tbl end,
    __div = function() return _tbl end,
    __mod = function() return _tbl end,
    __pow = function() return _tbl end,
    __unm = function() return _tbl end,
    __concat = function(a, b) return type(a) == "string" and a or (type(b) == "string" and b or "") end,
    __len = function() return 0 end,
    __lt = function() return false end,
    __le = function() return false end,
    __eq = function() return false end,
})

local RunService = setmetatable({
    IsStudio = function() return false end,
    IsClient = function() return true end,
    IsServer = function() return false end,
    IsRunning = function() return true end,
    Heartbeat = {
        Connect = function() return _tbl end,
        Wait = function() return 0 end
    },
    RenderStepped = {
        Connect = function() return _tbl end,
        Wait = function() return 0 end
    }
}, {
    __index = function()
        return _tbl
    end
})

local Players = setmetatable({
    LocalPlayer = setmetatable({
        Name = "Player",
        UserId = 1,
        Character = _tbl,
        PlayerGui = _tbl
    }, {
        __index = function()
            return _tbl
        end
    })
}, {
    __index = function()
        return _tbl
    end
})

local Workspace = setmetatable({
    CurrentCamera = _tbl
}, {
    __index = function()
        return _tbl
    end
})

local game = setmetatable({
    GetService = function(_, service)
        if service == "RunService" then
            return RunService
        elseif service == "Players" then
            return Players
        elseif service == "Workspace" then
            return Workspace
        end
        return _tbl
    end,
    IsLoaded = function() return true end,
    PlaceId = 0,
    JobId = "",
    Workspace = Workspace,
    Players = Players
}, {
    __index = function(_, key)
        if key == "Workspace" then
            return Workspace
        elseif key == "Players" then
            return Players
        end
        return _tbl
    end
})

local env
env = {
    task = task,
    game = game,
    workspace = Workspace,
    Game = game,
    Workspace = Workspace,
    script = _tbl,
    owner = Players.LocalPlayer,
    shared = {},
    _G = {},
    wait = task.wait,
    spawn = task.spawn,
    delay = task.delay,

    -- Standard Lua globals
    print = print,
    warn = warn or print,
    error = error,
    assert = assert,
    type = type,
    typeof = type,
    tonumber = tonumber,
    tostring = tostring,
    select = select,
    next = next,
    pairs = pairs,
    ipairs = ipairs,
    pcall = pcall,
    xpcall = xpcall,
    getmetatable = getmetatable,
    setmetatable = setmetatable,
    rawget = rawget,
    rawset = rawset,
    rawequal = rawequal,

    -- Tables
    table = table,
    string = string,
    math = math,
    bit32 = bit32,
    coroutine = coroutine,
    debug = debug or {},
    utf8 = utf8 or {},

    -- Functions that return _tbl
    getfenv = function() return env end,
    setfenv = function() end,
    loadstring = function() return function() return _tbl end end,
    require = function() return _tbl end,
}

-- Lune's require returns only the first value, so expose _tbl on env too
-- (luraphdump.lua reads it as env._tbl).
env._tbl = _tbl
return env, _tbl
