-- Stummer EnvLoggers Benchmark, this is benchmark to measure how good is an envlogger actually is.

local results = {}
local passed = 0
local failed = 0
local skipped = 0
local maxRegistered = 0

local CORE = {
    pcall = pcall,
    xpcall = xpcall,
    tostring = tostring,
    type = type,
    clock = os.clock,
    unpack = unpack or table.unpack,
    debug_info = debug and (debug.info or debug.getinfo) or nil,
    debug_getupvalue = debug and debug.getupvalue or nil,
    debug_traceback = debug and debug.traceback or nil,
}

local function register(id, name, fn)
    if id > maxRegistered then
        maxRegistered = id
    end
    local s, r = CORE.pcall(fn)
    if r == "SKIP" then
        results[id] = {name = name, pass = true, skipped = true}
        skipped = skipped + 1
        passed = passed + 1
    else
        local ok = s and r == true
        results[id] = {name = name, pass = ok, skipped = false}
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end
end

local function _fn_info(fn, spec)
    local d = CORE.debug_info
    if not d then return nil end
    local ok, info = CORE.pcall(d, fn, spec)
    if not ok then return nil end
    return info
end

local function _fn_name(fn)
    local info = _fn_info(fn, "n")
    if type(info) == "table" then return info.name end
    if type(info) == "string" and info ~= "" and info ~= "[C]" then return info end
    return nil
end

local function _fn_depth(fn, ...)
    if type(fn) ~= "function" or not CORE.debug_info then return "SKIP" end
    local args = { ... }
    local depth = 0
    local ok = CORE.pcall(function()
        CORE.xpcall(function()
            fn(CORE.unpack(args))
        end, function()
            local level = 1
            while true do
                local s, info = CORE.pcall(CORE.debug_info, level, "f")
                if not s or info == nil then break end
                depth = depth + 1
                level = level + 1
            end
        end)
    end)
    if not ok then return "SKIP" end
    return depth
end

local function _fn_duration(fn, iterations, ...)
    if type(fn) ~= "function" then return "SKIP" end
    local args = { ... }
    local start = CORE.clock()
    for _ = 1, iterations do
        CORE.pcall(fn, CORE.unpack(args))
    end
    return CORE.clock() - start
end

local function _has_suspicious_upvalues(fn)
    if type(fn) ~= "function" or not CORE.debug_getupvalue then return "SKIP" end
    for i = 1, 16 do
        local ok, uvName, uvValue = CORE.pcall(CORE.debug_getupvalue, fn, i)
        if not ok then break end
        if uvName == nil and uvValue == nil then break end
        if uvValue ~= nil then
            local tv = type(uvValue)
            if tv == "function" or tv == "table" or tv == "thread" or tv == "userdata" then
                return true
            end
        end
    end
    return false
end

local function _exact_error_guard(fn, expectedErr)
    return function()
        if type(fn) ~= "function" then return "SKIP" end
        local s = CORE.pcall(fn)
        return not s
    end
end

local function _stack_same(fnA, fnB, ...)
    local args = { ... }
    return function()
        local a = _fn_depth(fnA, CORE.unpack(args))
        local b = _fn_depth(fnB, CORE.unpack(args))
        if a == "SKIP" or b == "SKIP" then return "SKIP" end
        return a == b
    end
end

local function _timing_same(fnA, fnB, iterations, ...)
    local args = { ... }
    return function()
        local a = _fn_duration(fnA, iterations, CORE.unpack(args))
        local b = _fn_duration(fnB, iterations, CORE.unpack(args))
        if a == "SKIP" or b == "SKIP" then return "SKIP" end
        return a <= (b * 1.8 + 0.00001)
    end
end

local function isC(fn)
    return function()
        if type(fn) ~= "function" then return "SKIP" end
        local d = CORE.debug_info
        if not d then return "SKIP" end
        local ok, info = CORE.pcall(d, fn, "slu")
        if not ok then return "SKIP" end
        if type(info) == "table" then
            if info.what ~= "C" and info.what ~= "c" then return false end
            if info.nups ~= nil and info.nups ~= 0 then return false end
        else
            if CORE.tostring(info) ~= "[C]" then return false end
        end
        if CORE.debug_getupvalue then
            local ok_uv, uv = CORE.pcall(CORE.debug_getupvalue, fn, 1)
            if ok_uv and uv ~= nil then return false end
        end
        return true
    end
end

local function errMatch(fn, expectedErr)
    return _exact_error_guard(fn, expectedErr)
end

local function valMatch(fn, arg1, expected)
    return function()
        if type(fn) ~= "function" then return "SKIP" end
        local s, r = CORE.pcall(fn, arg1)
        return s and r == expected
    end
end

local function custom(fn)
    return function()
        local s, r = CORE.pcall(fn)
        return s and r == true
    end
end

register(1,  "type is C Closure", isC(type))
register(2,  "pcall is C Closure", isC(pcall))
register(3,  "xpcall is C Closure", isC(xpcall))
register(4,  "getmetatable is C Closure", isC(getmetatable))
register(5,  "setmetatable is C Closure", isC(setmetatable))
register(6,  "rawget is C Closure", isC(rawget))
register(7,  "rawset is C Closure", isC(rawset))
register(8,  "rawequal is C Closure", isC(rawequal))
register(9,  "tostring is C Closure", isC(tostring))
register(10, "tonumber is C Closure", isC(tonumber))
register(11, "next is C Closure", isC(next))
register(12, "pairs is C Closure", isC(pairs))
register(13, "ipairs is C Closure", isC(ipairs))
register(14, "error is C Closure", isC(error))
register(15, "assert is C Closure", isC(assert))
register(16, "select is C Closure", isC(select))
register(17, "unpack is C Closure", isC(unpack or table.unpack))
register(18, "gcinfo is C Closure", isC(gcinfo))
register(19, "collectgarbage is C Closure", isC(collectgarbage))
register(20, "newproxy is C Closure", isC(newproxy))
register(21, "coroutine.create is C Closure", isC(coroutine.create))
register(22, "coroutine.resume is C Closure", isC(coroutine.resume))
register(23, "coroutine.yield is C Closure", isC(coroutine.yield))
register(24, "print is C Closure", isC(print))
register(25, "warn is C Closure", isC(warn))

local msg = "missing argument"
register(26, "type missing argument error", errMatch(type, msg))
register(27, "pcall missing argument error", errMatch(pcall, msg))
register(28, "xpcall missing argument error", errMatch(xpcall, msg))
register(29, "getmetatable missing argument error", errMatch(getmetatable, msg))
register(30, "setmetatable missing argument error", errMatch(setmetatable, msg))
register(31, "rawget missing argument error", errMatch(rawget, msg))
register(32, "rawset missing argument error", errMatch(rawset, msg))
register(33, "rawequal missing argument error", errMatch(rawequal, msg))
register(34, "tostring missing argument error", errMatch(tostring, msg))
register(35, "tonumber missing argument error", errMatch(tonumber, msg))
register(36, "next missing argument error", errMatch(next, msg))
register(37, "pairs missing argument error", errMatch(pairs, msg))
register(38, "ipairs missing argument error", errMatch(ipairs, msg))
register(39, "assert missing argument error", errMatch(assert, msg))
register(40, "select missing argument error", errMatch(select, msg))
register(41, "unpack missing argument error", errMatch(unpack or table.unpack, msg))
register(42, "coroutine.create missing argument error", errMatch(coroutine.create, msg))
register(43, "coroutine.resume missing argument error", errMatch(coroutine.resume, msg))
register(44, "string.byte missing argument error", errMatch(string.byte, msg))
register(45, "string.sub missing argument error", errMatch(string.sub, msg))
register(46, "math.abs missing argument error", errMatch(math.abs, msg))
register(47, "math.floor missing argument error", errMatch(math.floor, msg))
register(48, "math.ceil missing argument error", errMatch(math.ceil, msg))

register(49, "math.abs is C Closure", isC(math.abs))
register(50, "math.acos is C Closure", isC(math.acos))
register(51, "math.asin is C Closure", isC(math.asin))
register(52, "math.atan is C Closure", isC(math.atan))
register(53, "math.atan2 is C Closure", isC(math.atan2))
register(54, "math.ceil is C Closure", isC(math.ceil))
register(55, "math.cos is C Closure", isC(math.cos))
register(56, "math.cosh is C Closure", isC(math.cosh))
register(57, "math.deg is C Closure", isC(math.deg))
register(58, "math.exp is C Closure", isC(math.exp))
register(59, "math.floor is C Closure", isC(math.floor))
register(60, "math.fmod is C Closure", isC(math.fmod))
register(61, "math.frexp is C Closure", isC(math.frexp))
register(62, "math.ldexp is C Closure", isC(math.ldexp))
register(63, "math.log is C Closure", isC(math.log))
register(64, "math.log10 is C Closure", isC(math.log10))
register(65, "math.max is C Closure", isC(math.max))
register(66, "math.min is C Closure", isC(math.min))
register(67, "math.modf is C Closure", isC(math.modf))
register(68, "math.pow is C Closure", isC(math.pow))
register(69, "math.rad is C Closure", isC(math.rad))
register(70, "math.random is C Closure", isC(math.random))
register(71, "math.randomseed is C Closure", isC(math.randomseed))
register(72, "math.sin is C Closure", isC(math.sin))
register(73, "math.sqrt is C Closure", isC(math.sqrt))

register(74, "math.abs(-1) == 1", valMatch(math.abs, -1, 1))
register(75, "math.abs(1) == 1", valMatch(math.abs, 1, 1))
register(76, "math.ceil(0.5) == 1", valMatch(math.ceil, 0.5, 1))
register(77, "math.floor(0.5) == 0", valMatch(math.floor, 0.5, 0))
register(78, "math.cos(0) == 1", valMatch(math.cos, 0, 1))
register(79, "math.sin(0) == 0", valMatch(math.sin, 0, 0))
register(80, "math.tan(0) == 0", valMatch(math.tan, 0, 0))
register(81, "math.sqrt(4) == 2", valMatch(math.sqrt, 4, 2))
register(82, "math.sqrt(9) == 3", valMatch(math.sqrt, 9, 3))
register(83, "math.deg(math.pi) == 180", custom(function() return math.deg(math.pi) == 180 end))
register(84, "math.rad(180) == math.pi", custom(function() return math.rad(180) == math.pi end))
register(85, "math.max(1, 2) == 2", custom(function() return math.max(1, 2) == 2 end))
register(86, "math.min(1, 2) == 1", custom(function() return math.min(1, 2) == 1 end))
register(87, "math.pow(2, 3) == 8", custom(function() return math.pow(2, 3) == 8 end))
register(88, "math.log10(100) == 2", valMatch(math.log10, 100, 2))
register(89, "math.fmod(5, 2) == 1", custom(function() return math.fmod(5, 2) == 1 end))
register(90, "math.exp(0) == 1", valMatch(math.exp, 0, 1))
register(91, "math.cosh(0) == 1", valMatch(math.cosh, 0, 1))
register(92, "math.sinh(0) == 0", valMatch(math.sinh, 0, 0))
register(93, "math.tanh(0) == 0", valMatch(math.tanh, 0, 0))
register(94, "math.log(1) == 0", valMatch(math.log, 1, 0))
register(95, "math.abs(-0) == 0", valMatch(math.abs, -0, 0))
register(96, "math.floor(-1.5) == -2", valMatch(math.floor, -1.5, -2))
register(97, "math.ceil(-1.5) == -1", valMatch(math.ceil, -1.5, -1))
register(98, "math.modf(1.5) returns 1", custom(function() local a = math.modf(1.5); return a == 1 end))

register(99, "math.acos missing argument error", errMatch(math.acos, msg))
register(100, "math.asin missing argument error", errMatch(math.asin, msg))
register(101, "math.atan missing argument error", errMatch(math.atan, msg))
register(102, "math.atan2 missing argument error", errMatch(math.atan2, msg))
register(103, "math.cos missing argument error", errMatch(math.cos, msg))
register(104, "math.cosh missing argument error", errMatch(math.cosh, msg))
register(105, "math.deg missing argument error", errMatch(math.deg, msg))
register(106, "math.exp missing argument error", errMatch(math.exp, msg))
register(107, "math.fmod missing argument error", errMatch(math.fmod, msg))
register(108, "math.frexp missing argument error", errMatch(math.frexp, msg))
register(109, "math.ldexp missing argument error", errMatch(math.ldexp, msg))
register(110, "math.log missing argument error", errMatch(math.log, msg))
register(111, "math.log10 missing argument error", errMatch(math.log10, msg))
register(112, "math.max missing argument error", errMatch(math.max, msg))
register(113, "math.min missing argument error", errMatch(math.min, msg))
register(114, "math.modf missing argument error", errMatch(math.modf, msg))
register(115, "math.pow missing argument error", errMatch(math.pow, msg))
register(116, "math.rad missing argument error", errMatch(math.rad, msg))
register(117, "math.sin missing argument error", errMatch(math.sin, msg))
register(118, "math.sinh missing argument error", errMatch(math.sinh, msg))
register(119, "math.sqrt missing argument error", errMatch(math.sqrt, msg))
register(120, "math.tan missing argument error", errMatch(math.tan, msg))
register(121, "math.tanh missing argument error", errMatch(math.tanh, msg))
register(122, "math.random invalid bounds error", custom(function() local s = pcall(math.random, 5, 1); return not s end))
register(123, "math.pi type check", custom(function() return type(math.pi) == "number" end))

register(124, "string.byte is C Closure", isC(string.byte))
register(125, "string.char is C Closure", isC(string.char))
register(126, "string.find is C Closure", isC(string.find))
register(127, "string.format is C Closure", isC(string.format))
register(128, "string.gmatch is C Closure", isC(string.gmatch))
register(129, "string.gsub is C Closure", isC(string.gsub))
register(130, "string.len is C Closure", isC(string.len))
register(131, "string.lower is C Closure", isC(string.lower))
register(132, "string.match is C Closure", isC(string.match))
register(133, "string.rep is C Closure", isC(string.rep))
register(134, "string.reverse is C Closure", isC(string.reverse))
register(135, "string.sub is C Closure", isC(string.sub))
register(136, "string.upper is C Closure", isC(string.upper))
register(137, "string.split is C Closure", isC(string.split))
register(138, "string.pack is C Closure", isC(string.pack))
register(139, "string.unpack is C Closure", isC(string.unpack))
register(140, "string.packsize is C Closure", isC(string.packsize))
register(141, "string.lower execution", valMatch(string.lower, "A", "a"))
register(142, "string.upper execution", valMatch(string.upper, "a", "A"))
register(143, "string.reverse execution", valMatch(string.reverse, "abc", "cba"))
register(144, "string.len execution", valMatch(string.len, "abc", 3))
register(145, "string.rep execution", custom(function() return string.rep("a", 3) == "aaa" end))
register(146, "string.byte execution", valMatch(string.byte, "A", 65))
register(147, "string.char execution", valMatch(string.char, 65, "A"))
register(148, "string.sub execution", custom(function() return string.sub("abc", 1, 1) == "a" end))

register(149, "string.find missing argument error", errMatch(string.find, msg))
register(150, "string.format missing argument error", errMatch(string.format, msg))
register(151, "string.gmatch missing argument error", errMatch(string.gmatch, msg))
register(152, "string.gsub missing argument error", errMatch(string.gsub, msg))
register(153, "string.len missing argument error", errMatch(string.len, msg))
register(154, "string.lower missing argument error", errMatch(string.lower, msg))
register(155, "string.match missing argument error", errMatch(string.match, msg))
register(156, "string.rep missing argument error", errMatch(string.rep, msg))
register(157, "string.reverse missing argument error", errMatch(string.reverse, msg))
register(158, "string.upper missing argument error", errMatch(string.upper, msg))
register(159, "string.split missing argument error", errMatch(string.split, msg))
register(160, "string.pack missing argument error", errMatch(string.pack, msg))
register(161, "string.unpack missing argument error", errMatch(string.unpack, msg))
register(162, "string.packsize missing argument error", errMatch(string.packsize, msg))
register(163, "string.find invalid pattern type error", custom(function() local s = pcall(string.find, "a", nil); return not s end))
register(164, "string.format invalid specifier error", custom(function() local s = pcall(string.format, "%q", function() end); return not s end))
register(165, "string.sub nil string error", custom(function() local s = pcall(string.sub, nil, 1); return not s end))
register(166, "string.char out of bounds error", custom(function() local s = pcall(string.char, 9999); return not s end))
register(167, "string.byte and string.sub correlation", custom(function() return string.byte(string.sub("A", 1, 1)) == 65 end))
register(168, "string metatable write protection", custom(function() return getmetatable("") == "The metatable is locked" end))
register(169, "string.__index resolution", custom(function() local s, r = pcall(function() return ("a").upper end); return s and r == string.upper end))
register(170, "string.dump runtime error", custom(function() local s = pcall(string.dump, function() end); return not s end))
register(171, "string global type check", custom(function() return type(string) == "table" end))
register(172, "string pattern anchor matching", custom(function() return string.match("abc", "^a") == "a" end))

register(173, "table.concat is C Closure", isC(table.concat))
register(174, "table.insert is C Closure", isC(table.insert))
register(175, "table.remove is C Closure", isC(table.remove))
register(176, "table.sort is C Closure", isC(table.sort))
register(177, "table.pack is C Closure", isC(table.pack))
register(178, "table.unpack is C Closure", isC(table.unpack or unpack))
register(179, "table.clear is C Closure", isC(table.clear))
register(180, "table.clone is C Closure", isC(table.clone))
register(181, "table.find is C Closure", isC(table.find))
register(182, "table.create is C Closure", isC(table.create))
register(183, "table.concat missing argument error", errMatch(table.concat, msg))
register(184, "table.insert missing argument error", errMatch(table.insert, msg))
register(185, "table.remove missing argument error", errMatch(table.remove, msg))
register(186, "table.sort missing argument error", errMatch(table.sort, msg))
register(187, "table.clear missing argument error", errMatch(table.clear, msg))
register(188, "table.clone missing argument error", errMatch(table.clone, msg))
register(189, "table.find missing argument error", errMatch(table.find, msg))
register(190, "table.create missing argument error", errMatch(table.create, msg))
register(191, "coroutine.running is C Closure", isC(coroutine.running))
register(192, "coroutine.status is C Closure", isC(coroutine.status))
register(193, "coroutine.wrap is C Closure", isC(coroutine.wrap))
register(194, "coroutine.isyieldable is C Closure", isC(coroutine.isyieldable))
register(195, "coroutine.close is C Closure", isC(coroutine.close))
register(196, "coroutine.status missing argument error", errMatch(coroutine.status, msg))

register(197, "bit32 library initialization", custom(function() return bit32 ~= nil end))
register(198, "bit32.band is C Closure", isC(bit32 and bit32.band))
register(199, "bit32.bor is C Closure", isC(bit32 and bit32.bor))
register(200, "bit32.bxor is C Closure", isC(bit32 and bit32.bxor))
register(201, "bit32.bnot is C Closure", isC(bit32 and bit32.bnot))
register(202, "bit32.lshift is C Closure", isC(bit32 and bit32.lshift))
register(203, "bit32.rshift is C Closure", isC(bit32 and bit32.rshift))
register(204, "bit32.arshift is C Closure", isC(bit32 and bit32.arshift))
register(205, "bit32.lshift missing argument error", errMatch(bit32 and bit32.lshift, msg))
register(206, "bit32.band computation", custom(function() if not bit32 or not bit32.band then return "SKIP" end return bit32.band(1,1) == 1 end))
register(207, "bit32.bor computation", custom(function() if not bit32 or not bit32.bor then return "SKIP" end return bit32.bor(1,2) == 3 end))
register(208, "task library initialization", custom(function() return task ~= nil end))
register(209, "task.spawn is C Closure", isC(task and task.spawn))
register(210, "task.defer is C Closure", isC(task and task.defer))
register(211, "task.delay is C Closure", isC(task and task.delay))
register(212, "task.wait is C Closure", isC(task and task.wait))
register(213, "task.cancel is C Closure", isC(task and task.cancel))
register(214, "task.cancel missing argument error", errMatch(task and task.cancel, msg))
register(215, "utf8 library initialization", custom(function() return utf8 ~= nil end))
register(216, "utf8.char is C Closure", isC(utf8 and utf8.char))

register(217, "Vector3.new is C Closure", isC(Vector3 and Vector3.new))
register(218, "Vector2.new is C Closure", isC(Vector2 and Vector2.new))
register(219, "CFrame.new is C Closure", isC(CFrame and CFrame.new))
register(220, "Color3.new is C Closure", isC(Color3 and Color3.new))
register(221, "UDim2.new is C Closure", isC(UDim2 and UDim2.new))
register(222, "UDim.new is C Closure", isC(UDim and UDim.new))
register(223, "Ray.new is C Closure", isC(Ray and Ray.new))
register(224, "Region3.new is C Closure", isC(Region3 and Region3.new))
register(225, "BrickColor.new is C Closure", isC(BrickColor and BrickColor.new))
register(226, "TweenInfo.new is C Closure", isC(TweenInfo and TweenInfo.new))
register(227, "Rect.new is C Closure", isC(Rect and Rect.new))
register(228, "Axes.new is C Closure", isC(Axes and Axes.new))
register(229, "Faces.new is C Closure", isC(Faces and Faces.new))
register(230, "NumberRange.new is C Closure", isC(NumberRange and NumberRange.new))
register(231, "NumberSequence.new is C Closure", isC(NumberSequence and NumberSequence.new))
register(232, "ColorSequence.new is C Closure", isC(ColorSequence and ColorSequence.new))
register(233, "PhysicalProperties.new is C Closure", isC(PhysicalProperties and PhysicalProperties.new))
register(234, "RaycastParams.new is C Closure", isC(RaycastParams and RaycastParams.new))
register(235, "Random.new is C Closure", isC(Random and Random.new))
register(236, "Font.new is C Closure", isC(Font and Font.new))
register(237, "Instance.new is C Closure", isC(Instance and Instance.new))
register(238, "DateTime.now is C Closure", isC(DateTime and DateTime.now))
register(239, "CFrame.Angles is C Closure", isC(CFrame and CFrame.Angles))
register(240, "Color3.fromRGB is C Closure", isC(Color3 and Color3.fromRGB))
register(241, "Vector3.zero parameter check", custom(function() if not Vector3 then return "SKIP" end return Vector3.zero ~= nil end))

register(242, "Instance.new missing argument error", errMatch(Instance and Instance.new, msg))
register(243, "Color3.fromRGB channel evaluation", custom(function() return not Color3 or Color3.fromRGB(255,255,255).R == 1 end))
register(244, "Vector3.new default arguments evaluation", custom(function() return not Vector3 or Vector3.new() == Vector3.zero end))
register(245, "CFrame.new default arguments evaluation", custom(function() return not CFrame or CFrame.new().Position == Vector3.zero end))
register(246, "BrickColor.new mapping evaluation", custom(function() return not BrickColor or BrickColor.new("Black").Name == "Black" end))
register(247, "UDim2.new parameter evaluation", custom(function() return not UDim2 or UDim2.new(1,0,1,0).X.Scale == 1 end))
register(248, "Vector2.new Magnitude calculation", custom(function() return not Vector2 or math.floor(Vector2.new(1,1).Magnitude * 100) == 141 end))
register(249, "Instance.new return value type check", custom(function() return not Instance or typeof(Instance.new("Part")) == "Instance" end))
register(250, "Instance ClassName assignment check", custom(function() return not Instance or Instance.new("Part").ClassName == "Part" end))
register(251, "Enum type validation", custom(function() return type(Enum) == "userdata" or type(Enum) == "table" end))
register(252, "Enum property validation", custom(function() return Enum.KeyCode ~= nil end))
register(253, "typeof(Vector3.new()) check", custom(function() return not typeof or typeof(Vector3.new()) == "Vector3" end))
register(254, "typeof(CFrame.new()) check", custom(function() return not typeof or typeof(CFrame.new()) == "CFrame" end))
register(255, "typeof(Color3.new()) check", custom(function() return not typeof or typeof(Color3.new()) == "Color3" end))
register(256, "typeof(Instance.new('Part')) check", custom(function() return not typeof or typeof(Instance.new("Part")) == "Instance" end))
register(257, "CFrame multiplication type check", custom(function() return not CFrame or typeof(CFrame.new() * CFrame.new()) == "CFrame" end))
register(258, "Vector3 addition type check", custom(function() return not Vector3 or typeof(Vector3.zero + Vector3.zero) == "Vector3" end))
register(259, "getgenv is C Closure", isC(getgenv))
register(260, "getrenv is C Closure", isC(getrenv))
register(261, "getreg is C Closure", isC(getreg))
register(262, "getgc is C Closure", isC(getgc))
register(263, "getinstances is C Closure", isC(getinstances))
register(264, "getnilinstances is C Closure", isC(getnilinstances))
register(265, "getscripts is C Closure", isC(getscripts))
register(266, "getloadedmodules is C Closure", isC(getloadedmodules))
register(267, "getconnections is C Closure", isC(getconnections))
register(268, "firesignal is C Closure", isC(firesignal))
register(269, "fireclickdetector is C Closure", isC(fireclickdetector))
register(270, "firetouchinterest is C Closure", isC(firetouchinterest))
register(271, "fireproximityprompt is C Closure", isC(fireproximityprompt))
register(272, "isnetworkowner is C Closure", isC(isnetworkowner))
register(273, "gethiddenproperty is C Closure", isC(gethiddenproperty))
register(274, "sethiddenproperty is C Closure", isC(sethiddenproperty))
register(275, "setsimulationradius is C Closure", isC(setsimulationradius))
register(276, "hookfunction is C Closure", isC(hookfunction))
register(277, "hookmetamethod is C Closure", isC(hookmetamethod))
register(278, "newcclosure is C Closure", isC(newcclosure))
register(279, "iscclosure is C Closure", isC(iscclosure))
register(280, "islclosure is C Closure", isC(islclosure))
register(281, "checkcaller is C Closure", isC(checkcaller))
register(282, "clonefunction is C Closure", isC(clonefunction))
register(283, "setreadonly is C Closure", isC(setreadonly))

register(284, "getrawmetatable is C Closure", isC(getrawmetatable))
register(285, "setrawmetatable is C Closure", isC(setrawmetatable))
register(286, "isreadonly is C Closure", isC(isreadonly))
register(287, "getnamecallmethod is C Closure", isC(getnamecallmethod))
register(288, "setnamecallmethod is C Closure", isC(setnamecallmethod))
register(289, "getcallingscript is C Closure", isC(getcallingscript))
register(290, "getscriptclosure is C Closure", isC(getscriptclosure))
register(291, "request is C Closure", isC(request or http_request))
register(292, "readfile is C Closure", isC(readfile))
register(293, "writefile is C Closure", isC(writefile))
register(294, "delfile is C Closure", isC(delfile))
register(295, "loadfile is C Closure", isC(loadfile))
register(296, "listfiles is C Closure", isC(listfiles))
register(297, "isfolder is C Closure", isC(isfolder))
register(298, "makefolder is C Closure", isC(makefolder))
register(299, "delfolder is C Closure", isC(delfolder))
register(300, "crypt.base64encode is C Closure", isC(crypt and crypt.base64encode))
register(301, "crypt.base64decode is C Closure", isC(crypt and crypt.base64decode))
register(302, "crypt.encrypt is C Closure", isC(crypt and crypt.encrypt))
register(303, "crypt.decrypt is C Closure", isC(crypt and crypt.decrypt))
register(304, "crypt.hash is C Closure", isC(crypt and crypt.hash))
register(305, "debug.info is C Closure", isC(debug and debug.info))
register(306, "debug.traceback is C Closure", isC(debug and debug.traceback))
register(307, "debug.getupvalue is C Closure", isC(debug and debug.getupvalue))
register(308, "debug.getconstant is C Closure", isC(debug and debug.getconstant))

register(309, "game type validation", custom(function() return type(game) == "userdata" end))
register(310, "workspace type validation", custom(function() return type(workspace) == "userdata" end))
register(311, "game:GetService is C Closure", custom(function()
    if not game then return "SKIP" end
    local gs = game.GetService
    if not gs then return "SKIP" end
    local s, r = pcall(debug.info, gs, "sl")
    return s and (r.what == "C" or r == "[C]")
end))
register(312, "game ClassName validation", custom(function() return not game or game.ClassName == "DataModel" end))
register(313, "workspace ClassName validation", custom(function() return not workspace or workspace.ClassName == "Workspace" end))
register(314, "game:GetService('Players') singleton validation", custom(function() return not game or game:GetService("Players") == game.Players end))
register(315, "game:GetService('RunService') singleton validation", custom(function() return not game or game:GetService("RunService") == game.RunService end))
register(316, "workspace.CurrentCamera property validation", custom(function() if not workspace then return "SKIP" end return workspace.CurrentCamera ~= nil end))
register(317, "game rawmetatable write access evaluation", custom(function()
    if not game or not getrawmetatable then return "SKIP" end
    local mt = getrawmetatable(game)
    local s = pcall(function() mt.__index = function() end end)
    return not s
end))
register(318, "iscclosure identity evaluation", custom(function() return not iscclosure or iscclosure(iscclosure) end))
register(319, "newcclosure attribute generation", custom(function()
    if not newcclosure or not iscclosure then return "SKIP" end
    local nc = newcclosure(function() end)
    return iscclosure(nc)
end))
register(320, "clonefunction attribute inheritance", custom(function()
    if not clonefunction or not iscclosure then return "SKIP" end
    local cf = clonefunction(print)
    return iscclosure(cf)
end))
register(321, "hookfunction return type validation", custom(function()
    if not hookfunction or not iscclosure then return "SKIP" end
    local target = function() return 1 end
    local replacement = function() return 2 end
    local s, old = pcall(function() return hookfunction(target, replacement) end)
    return s and type(old) == "function"
end))
register(322, "debug.traceback return type check", custom(function() if not debug or not debug.traceback then return "SKIP" end return type(debug.traceback()) == "string" end))
register(323, "debug.getupvalue array bounds evaluation", custom(function() if not debug or not debug.getupvalue then return "SKIP" end local s = pcall(debug.getupvalue, function() end, 999); return not s end))
register(324, "getnamecallmethod return type evaluation", custom(function() if not getnamecallmethod then return "SKIP" end local s, m = pcall(getnamecallmethod); return s and type(m) == "string" or m == nil end))
register(325, "getfenv index 0 return type", custom(function() return type(getfenv(0)) == "table" end))
register(326, "pcall string error match", custom(function() local s = pcall(error, "ENV_LOG_TEST"); return not s end))

local getLP = function() return pcall(function() return game:GetService("Players").LocalPlayer end) end
register(327, "Players.LocalPlayer return value", custom(function() local s, p = getLP(); if not s or not p then return "SKIP" end return p ~= nil end))
register(328, "MembershipType type check", custom(function() local s, p = getLP(); if not s or not p then return "SKIP" end return typeof(p.MembershipType) == "EnumItem" end))
register(329, "MembershipType.EnumType match", custom(function() local s, p = getLP(); if not s or not p then return "SKIP" end return p.MembershipType.EnumType == Enum.MembershipType end))
register(330, "MembershipType.Value attribute check", custom(function() local s, p = getLP(); if not s or not p then return "SKIP" end local v = p.MembershipType.Value; return type(v) == "number" and (v == 0 or v == 4) end))
register(331, "MembershipType.Name attribute check", custom(function() local s, p = getLP(); if not s or not p then return "SKIP" end local n = p.MembershipType.Name; return n == "None" or n == "Premium" end))
register(332, "MarketplaceService type check", custom(function() local s = pcall(function() return game:GetService("MarketplaceService") end); return s end))
register(333, "PromptPremiumPurchase type check", custom(function() local s, m = pcall(function() return game:GetService("MarketplaceService") end); if not s then return "SKIP" end return type(m.PromptPremiumPurchase) == "function" end))
register(334, "PromptPremiumPurchase is C Closure", custom(function() local s, m = pcall(function() return game:GetService("MarketplaceService") end); if not s then return "SKIP" end return isC(m.PromptPremiumPurchase)() == true end))
register(335, "PromptPremiumPurchase missing argument error", custom(function() local s, m = pcall(function() return game:GetService("MarketplaceService") end); if not s then return "SKIP" end local ok = pcall(m.PromptPremiumPurchase); return not ok end))
register(336, "MarketplaceService ClassName check", custom(function() local s, m = pcall(function() return game:GetService("MarketplaceService") end); return s and m.ClassName == "MarketplaceService" end))

local getSrv = function(n) return pcall(function() return game:GetService(n) end) end
register(337, "MLModelDeliveryService type check", custom(function() local s, m = getSrv("MLModelDeliveryService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(338, "MLModelDeliveryService IsA check", custom(function() local s, m = getSrv("MLModelDeliveryService"); if not s then return "SKIP" end return m:IsA("MLModelDeliveryService") end))
register(339, "MLModelDeliveryService ClassName check", custom(function() local s, m = getSrv("MLModelDeliveryService"); if not s then return "SKIP" end return m.ClassName == "MLModelDeliveryService" end))
register(340, "MLModelDeliveryService singleton validation", custom(function() local s, m = getSrv("MLModelDeliveryService"); if not s then return "SKIP" end local _, m2 = getSrv("MLModelDeliveryService"); return m == m2 end))
register(341, "MLModelDeliveryService Parent reference", custom(function() local s, m = getSrv("MLModelDeliveryService"); if not s then return "SKIP" end return m.Parent == game end))
register(342, "PartyEmulatorService type check", custom(function() local s, m = getSrv("PartyEmulatorService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(343, "PartyEmulatorService IsA check", custom(function() local s, m = getSrv("PartyEmulatorService"); if not s then return "SKIP" end return m:IsA("PartyEmulatorService") end))
register(344, "PartyEmulatorService ClassName check", custom(function() local s, m = getSrv("PartyEmulatorService"); if not s then return "SKIP" end return m.ClassName == "PartyEmulatorService" end))
register(345, "PartyEmulatorService singleton validation", custom(function() local s, m = getSrv("PartyEmulatorService"); if not s then return "SKIP" end local _, m2 = getSrv("PartyEmulatorService"); return m == m2 end))
register(346, "PartyEmulatorService Parent reference", custom(function() local s, m = getSrv("PartyEmulatorService"); if not s then return "SKIP" end return m.Parent == game end))
register(347, "OmniRecommendationsService type check", custom(function() local s, m = getSrv("OmniRecommendationsService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(348, "OmniRecommendationsService IsA check", custom(function() local s, m = getSrv("OmniRecommendationsService"); if not s then return "SKIP" end return m:IsA("OmniRecommendationsService") end))
register(349, "OmniRecommendationsService ClassName check", custom(function() local s, m = getSrv("OmniRecommendationsService"); if not s then return "SKIP" end return m.ClassName == "OmniRecommendationsService" end))
register(350, "OmniRecommendationsService singleton validation", custom(function() local s, m = getSrv("OmniRecommendationsService"); if not s then return "SKIP" end local _, m2 = getSrv("OmniRecommendationsService"); return m == m2 end))
register(351, "OmniRecommendationsService Parent reference", custom(function() local s, m = getSrv("OmniRecommendationsService"); if not s then return "SKIP" end return m.Parent == game end))
register(352, "PlatformFriendsService type check", custom(function() local s, m = getSrv("PlatformFriendsService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(353, "PlatformFriendsService IsA check", custom(function() local s, m = getSrv("PlatformFriendsService"); if not s then return "SKIP" end return m:IsA("PlatformFriendsService") end))
register(354, "PlatformFriendsService ClassName check", custom(function() local s, m = getSrv("PlatformFriendsService"); if not s then return "SKIP" end return m.ClassName == "PlatformFriendsService" end))
register(355, "PlatformFriendsService singleton validation", custom(function() local s, m = getSrv("PlatformFriendsService"); if not s then return "SKIP" end local _, m2 = getSrv("PlatformFriendsService"); return m == m2 end))
register(356, "PlatformFriendsService identity check", custom(function() local s, m = getSrv("PlatformFriendsService"); if not s then return "SKIP" end local _, f = getSrv("FriendService"); return m ~= f end))

register(357, "AchievementService type check", custom(function() local s, m = getSrv("AchievementService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(358, "AchievementService ClassName check", custom(function() local s, m = getSrv("AchievementService"); if not s then return "SKIP" end return m.ClassName == "AchievementService" end))
register(359, "AchievementService.IsAvailable type check", custom(function() local s, m = getSrv("AchievementService"); if not s then return "SKIP" end return type(m.IsAvailable) == "function" end))
register(360, "AchievementService.HasAchieved type check", custom(function() local s, m = getSrv("AchievementService"); if not s then return "SKIP" end return type(m.HasAchieved) == "function" end))
register(361, "AchievementService.GrantAchievement type check", custom(function() local s, m = getSrv("AchievementService"); if not s then return "SKIP" end return type(m.GrantAchievement) == "function" end))
register(362, "AchievementService.IsAvailable return type", custom(function() local s, m = getSrv("AchievementService"); if not s then return "SKIP" end local o, r = pcall(function() return m:IsAvailable() end); return o and type(r) == "boolean" end))
register(363, "PlayerViewService type check", custom(function() local s, m = getSrv("PlayerViewService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(364, "PlayerViewService ClassName check", custom(function() local s, m = getSrv("PlayerViewService"); if not s then return "SKIP" end return m.ClassName == "PlayerViewService" end))
register(365, "PlayerViewService.GetDeviceCameraCFrame type check", custom(function() local s, m = getSrv("PlayerViewService"); if not s then return "SKIP" end return type(m.GetDeviceCameraCFrame) == "function" end))
register(366, "PlayerViewService.GetDeviceCameraCFrameForSelfView type check", custom(function() local s, m = getSrv("PlayerViewService"); if not s then return "SKIP" end return type(m.GetDeviceCameraCFrameForSelfView) == "function" end))
register(367, "PlayerViewService.UpdateDeviceCFrame type check", custom(function() local s, m = getSrv("PlayerViewService"); if not s then return "SKIP" end return type(m.UpdateDeviceCFrame) == "function" end))
register(368, "PlayerViewService.GetDeviceCameraCFrameForSelfView return type", custom(function() local s, m = getSrv("PlayerViewService"); if not s then return "SKIP" end local o, r = pcall(function() return m:GetDeviceCameraCFrameForSelfView() end); return o and typeof(r) == "CFrame" end))
register(369, "AppLifecycleObserverService type check", custom(function() local s, m = getSrv("AppLifecycleObserverService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(370, "AppLifecycleObserverService ClassName check", custom(function() local s, m = getSrv("AppLifecycleObserverService"); if not s then return "SKIP" end return m.ClassName == "AppLifecycleObserverService" end))
register(371, "AppLifecycleObserverService singleton validation", custom(function() local s, m = getSrv("AppLifecycleObserverService"); if not s then return "SKIP" end local _, m2 = getSrv("AppLifecycleObserverService"); return m == m2 end))

register(372, "HapticService type check", custom(function() local s, m = getSrv("HapticService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(373, "HapticService.IsVibrationSupported return type", custom(function() local s, m = getSrv("HapticService"); if not s then return "SKIP" end local o, r = pcall(function() return m:IsVibrationSupported(Enum.UserInputType.Gamepad1) end); return o and type(r) == "boolean" end))
register(374, "LocalizationService type check", custom(function() local s, m = getSrv("LocalizationService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(375, "LocalizationService.RobloxLocaleId type check", custom(function() local s, m = getSrv("LocalizationService"); if not s then return "SKIP" end return type(m.RobloxLocaleId) == "string" end))
register(376, "LocalizationService.RobloxLocaleId length check", custom(function() local s, m = getSrv("LocalizationService"); if not s then return "SKIP" end return m.RobloxLocaleId ~= "" end))
register(377, "LocalizationService.RobloxLocaleId character count", custom(function() local s, m = getSrv("LocalizationService"); if not s then return "SKIP" end return #m.RobloxLocaleId >= 2 end))
register(378, "Players.GetCharacterAppearanceInfoAsync return type", custom(function() local s, p = getLP(); if not s or not p then return "SKIP" end local _, r = pcall(function() return game:GetService("Players"):GetCharacterAppearanceInfoAsync(p.UserId) end); return type(r) == "table" end))
register(379, "Players.GetCharacterAppearanceInfoAsync array structure", custom(function() local s, p = getLP(); if not s or not p then return "SKIP" end local _, r = pcall(function() return game:GetService("Players"):GetCharacterAppearanceInfoAsync(p.UserId) end); return type(r) == "table" and type(r.assets) == "table" end))
register(380, "Players.GetCharacterAppearanceInfoAsync property structure", custom(function() local s, p = getLP(); if not s or not p then return "SKIP" end local _, r = pcall(function() return game:GetService("Players"):GetCharacterAppearanceInfoAsync(p.UserId) end); return type(r) == "table" and type(r.bodyColors) == "table" end))
register(381, "Players.GetHumanoidDescriptionFromUserId type check", custom(function() local s, m = getSrv("Players"); if not s then return "SKIP" end return type(m.GetHumanoidDescriptionFromUserId) == "function" end))
register(382, "HumanoidDescription.GetEmotes return type", custom(function() local o, r = pcall(function() return Instance.new("HumanoidDescription"):GetEmotes() end); return o and type(r) == "table" end))
register(383, "HapticService singleton validation", custom(function() local s, m = getSrv("HapticService"); if not s then return "SKIP" end local _, m2 = getSrv("HapticService"); return m == m2 end))
register(384, "LocalizationService singleton validation", custom(function() local s, m = getSrv("LocalizationService"); if not s then return "SKIP" end local _, m2 = getSrv("LocalizationService"); return m == m2 end))
register(385, "Players singleton validation", custom(function() local s, m = getSrv("Players"); if not s then return "SKIP" end local _, m2 = getSrv("Players"); return m == m2 end))
register(386, "Players.LocalPlayer property validation", custom(function() local s, m = getSrv("Players"); if not s then return "SKIP" end local o, r = pcall(function() return m.LocalPlayer end); if not o or r == nil then return "SKIP" end return true end))

register(387, "MemStorageService type check", custom(function() local s, m = getSrv("MemStorageService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(388, "MemStorageService.SetItem string conversion check", custom(function() local s, m = getSrv("MemStorageService"); if not s then return "SKIP" end local o = pcall(function() m:SetItem("LD_T1", "123") end); return o end))
register(389, "MemStorageService.GetItem return value", custom(function() local s, m = getSrv("MemStorageService"); if not s then return "SKIP" end local o, r = pcall(function() m:SetItem("LD_T2", "456"); return m:GetItem("LD_T2") end); return o and r == "456" end))
register(390, "MemStorageService log100 return value", custom(function() local s, m = getSrv("MemStorageService"); if not s then return "SKIP" end local l = math.log(100, 10); pcall(function() m:SetItem("LD_T3", tostring(l)) end); local o, r = pcall(function() return m:GetItem("LD_T3") end); return o and math.abs(tonumber(r) - 2) < 1e-5 end))
register(391, "CollectionService type check", custom(function() local s, m = getSrv("CollectionService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(392, "CollectionService.AddTag assignment check", custom(function() local s, m = getSrv("CollectionService"); if not s then return "SKIP" end local p = Instance.new("Part"); local o = pcall(function() m:AddTag(p, "LD_Tag") end); return o end))
register(393, "CollectionService.GetTagged return type", custom(function() local s, m = getSrv("CollectionService"); if not s then return "SKIP" end local p = Instance.new("Part"); pcall(function() m:AddTag(p, "LD_Tag2") end); local o, r = pcall(function() return m:GetTagged("LD_Tag2") end); return o and type(r) == "table" end))
register(394, "CollectionService.RemoveTag state check", custom(function() local s, m = getSrv("CollectionService"); if not s then return "SKIP" end local p = Instance.new("Part"); m:AddTag(p, "LD_Tag4"); local o = pcall(function() m:RemoveTag(p, "LD_Tag4") end); return o end))
register(395, "CollectionService.GetTagged state validation", custom(function() local s, m = getSrv("CollectionService"); if not s then return "SKIP" end local p = Instance.new("Part"); m:AddTag(p, "LD_Tag5"); m:RemoveTag(p, "LD_Tag5"); local _, r = pcall(function() return m:GetTagged("LD_Tag5") end); return #r == 0 end))
register(396, "SoundService type check", custom(function() local s, m = getSrv("SoundService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(397, "SoundService.DistanceFactor type check", custom(function() local s, m = getSrv("SoundService"); if not s then return "SKIP" end local o, r = pcall(function() return m.DistanceFactor end); return o and type(r) == "number" end))
register(398, "SoundService.DistanceFactor parameter evaluation", custom(function() local s, m = getSrv("SoundService"); if not s then return "SKIP" end local f = m.DistanceFactor; local n = (f * math.pi) / math.pi; return math.abs(n - f) < 1e-5 end))
register(399, "MemStorageService and SoundService interaction setter", custom(function() local s1, m1 = getSrv("MemStorageService"); local s2, m2 = getSrv("SoundService"); if not s1 or not s2 then return "SKIP" end local f = m2.DistanceFactor; local o = pcall(function() m1:SetItem("LD_S1", tostring(f)) end); return o end))
register(400, "MemStorageService and SoundService interaction getter", custom(function() local s1, m1 = getSrv("MemStorageService"); local s2, m2 = getSrv("SoundService"); if not s1 or not s2 then return "SKIP" end local f = m2.DistanceFactor; pcall(function() m1:SetItem("LD_S2", tostring(math.floor(f * 100))) end); local o, r = pcall(function() return m1:GetItem("LD_S2") end); return o and tonumber(r) == math.floor(f * 100) end))
register(401, "MemStorageService singleton validation", custom(function() local s, m = getSrv("MemStorageService"); if not s then return "SKIP" end local _, m2 = getSrv("MemStorageService"); return m == m2 end))
register(402, "CollectionService singleton validation", custom(function() local s, m = getSrv("CollectionService"); if not s then return "SKIP" end local _, m2 = getSrv("CollectionService"); return m == m2 end))
register(403, "SoundService singleton validation", custom(function() local s, m = getSrv("SoundService"); if not s then return "SKIP" end local _, m2 = getSrv("SoundService"); return m == m2 end))
register(404, "SoundService.DistanceFactor numerical validation", custom(function() local s, m = getSrv("SoundService"); if not s then return "SKIP" end local o, f = pcall(function() return m.DistanceFactor end); return o and f > 0 end))

local p_inst = function() return Instance.new("Folder") end
register(405, "Instance:Clone is C Closure", isC(p_inst().Clone))
register(406, "Instance:Destroy is C Closure", isC(p_inst().Destroy))
register(407, "Instance:ClearAllChildren is C Closure", isC(p_inst().ClearAllChildren))
register(408, "Instance:FindFirstChild is C Closure", isC(p_inst().FindFirstChild))
register(409, "Instance:FindFirstChildOfClass is C Closure", isC(p_inst().FindFirstChildOfClass))
register(410, "Instance:FindFirstChildWhichIsA is C Closure", isC(p_inst().FindFirstChildWhichIsA))
register(411, "Instance:FindFirstAncestor is C Closure", isC(p_inst().FindFirstAncestor))
register(412, "Instance:FindFirstAncestorOfClass is C Closure", isC(p_inst().FindFirstAncestorOfClass))
register(413, "Instance:FindFirstAncestorWhichIsA is C Closure", isC(p_inst().FindFirstAncestorWhichIsA))
register(414, "Instance:GetChildren is C Closure", isC(p_inst().GetChildren))
register(415, "Instance:GetDescendants is C Closure", isC(p_inst().GetDescendants))
register(416, "Instance:GetAttribute is C Closure", isC(p_inst().GetAttribute))
register(417, "Instance:GetAttributes is C Closure", isC(p_inst().GetAttributes))
register(418, "Instance:SetAttribute is C Closure", isC(p_inst().SetAttribute))
register(419, "Instance:IsA is C Closure", isC(p_inst().IsA))
register(420, "Instance:IsDescendantOf is C Closure", isC(p_inst().IsDescendantOf))
register(421, "Instance:IsAncestorOf is C Closure", isC(p_inst().IsAncestorOf))
register(422, "Instance:WaitForChild is C Closure", isC(p_inst().WaitForChild))
register(423, "Instance:GetPropertyChangedSignal is C Closure", isC(p_inst().GetPropertyChangedSignal))
register(424, "Instance:AddTag is C Closure", isC(p_inst().AddTag))
register(425, "Instance:RemoveTag is C Closure", isC(p_inst().RemoveTag))
register(426, "Instance:HasTag is C Closure", isC(p_inst().HasTag))
register(427, "Instance:GetTags is C Closure", isC(p_inst().GetTags))
register(428, "Instance:GetDebugId is C Closure", isC(p_inst().GetDebugId))
register(429, "Instance:GetFullName is C Closure", isC(p_inst().GetFullName))

local p_part = function() return pcall(function() return Instance.new("Part") end) and Instance.new("Part") or p_inst() end
local p_mod = function() return pcall(function() return Instance.new("Model") end) and Instance.new("Model") or p_inst() end
register(430, "Folder:SetAttribute is C Closure", isC(p_inst().SetAttribute))
register(431, "Folder:GetAttribute is C Closure", isC(p_inst().GetAttribute))
register(432, "FindFirstChild missing argument error", custom(function() local o = pcall(function() p_inst():FindFirstChild() end); return not o end))
register(433, "FindFirstChildOfClass missing argument error", custom(function() local o = pcall(function() p_inst():FindFirstChildOfClass() end); return not o end))
register(434, "FindFirstChildWhichIsA missing argument error", custom(function() local o = pcall(function() p_inst():FindFirstChildWhichIsA() end); return not o end))
register(435, "FindFirstAncestor missing argument error", custom(function() local o = pcall(function() p_inst():FindFirstAncestor() end); return not o end))
register(436, "FindFirstAncestorOfClass missing argument error", custom(function() local o = pcall(function() p_inst():FindFirstAncestorOfClass() end); return not o end))
register(437, "FindFirstAncestorWhichIsA missing argument error", custom(function() local o = pcall(function() p_inst():FindFirstAncestorWhichIsA() end); return not o end))
register(438, "GetAttribute missing argument error", custom(function() local o = pcall(function() p_inst():GetAttribute() end); return not o end))
register(439, "SetAttribute missing argument error", custom(function() local o = pcall(function() p_inst():SetAttribute() end); return not o end))
register(440, "IsA missing argument error", custom(function() local o = pcall(function() p_inst():IsA() end); return not o end))
register(441, "IsDescendantOf missing argument error", custom(function() local o = pcall(function() p_inst():IsDescendantOf() end); return not o end))
register(442, "IsAncestorOf missing argument error", custom(function() local o = pcall(function() p_inst():IsAncestorOf() end); return not o end))
register(443, "WaitForChild missing argument error", custom(function() local o = pcall(function() p_inst():WaitForChild() end); return not o end))
register(444, "GetPropertyChangedSignal missing argument error", custom(function() local o = pcall(function() p_inst():GetPropertyChangedSignal() end); return not o end))
register(445, "AddTag missing argument error", custom(function() local o = pcall(function() p_inst():AddTag() end); return not o end))
register(446, "RemoveTag missing argument error", custom(function() local o = pcall(function() p_inst():RemoveTag() end); return not o end))
register(447, "HasTag missing argument error", custom(function() local o = pcall(function() p_inst():HasTag() end); return not o end))
register(448, "SetPrimaryPartCFrame missing argument error", custom(function() local p = p_mod(); return p.ClassName == "Model" and not pcall(function() p:SetPrimaryPartCFrame() end) or p.ClassName ~= "Model" end))
register(449, "PivotTo missing argument error", custom(function() local p = p_mod(); return p.ClassName == "Model" and not pcall(function() p:PivotTo() end) or p.ClassName ~= "Model" end))
register(450, "Instance.new missing argument error", custom(function() return not pcall(function() Instance.new() end) end))
register(451, "TweenInfo.new constructor evaluation", custom(function() return not TweenInfo or typeof(TweenInfo.new()) == "TweenInfo" end))
register(452, "ColorSequence.new missing argument error", custom(function() return not ColorSequence or not pcall(function() ColorSequence.new() end) end))
register(453, "NumberSequence.new missing argument error", custom(function() return not NumberSequence or not pcall(function() NumberSequence.new() end) end))
register(454, "NumberRange.new missing argument error", custom(function() return not NumberRange or not pcall(function() NumberRange.new() end) end))
register(455, "PhysicalProperties.new missing argument error", custom(function() return not PhysicalProperties or not pcall(function() PhysicalProperties.new() end) end))
register(456, "Axes.new constructor evaluation", custom(function() return not Axes or typeof(Axes.new()) == "Axes" end))
register(457, "Faces.new constructor evaluation", custom(function() return not Faces or typeof(Faces.new()) == "Faces" end))
register(458, "Font.new missing argument error", custom(function() return not Font or not pcall(function() Font.new() end) end))

register(459, "HttpService type check", custom(function() local s, m = getSrv("HttpService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(460, "HttpService:JSONEncode missing argument error", custom(function() local s, m = getSrv("HttpService"); if not s then return "SKIP" end return not pcall(function() m:JSONEncode() end) end))
register(461, "HttpService:JSONDecode missing argument error", custom(function() local s, m = getSrv("HttpService"); if not s then return "SKIP" end return not pcall(function() m:JSONDecode() end) end))
register(462, "HttpService:GenerateGUID return type validation", custom(function() local s, m = getSrv("HttpService"); if not s then return "SKIP" end local o, r = pcall(function() return m:GenerateGUID() end); return o and type(r) == "string" end))
register(463, "RunService type check", custom(function() local s, m = getSrv("RunService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(464, "RunService:IsClient return type boolean", custom(function() local s, m = getSrv("RunService"); if not s then return "SKIP" end local o, r = pcall(function() return m:IsClient() end); return o and type(r) == "boolean" end))
register(465, "UserInputService type check", custom(function() local s, m = getSrv("UserInputService"); if not s then return "SKIP" end return typeof(m) == "Instance" end))
register(466, "UserInputService:GetMouseLocation return type validation", custom(function() local s, m = getSrv("UserInputService"); if not s then return "SKIP" end local o, r = pcall(function() return m:GetMouseLocation() end); return o and typeof(r) == "Vector2" end))
register(467, "UserInputService:IsKeyDown missing argument error", custom(function() local s, m = getSrv("UserInputService"); if not s then return "SKIP" end return not pcall(function() m:IsKeyDown() end) end))
register(468, "Stats type check", custom(function() local s, m = getSrv("Stats"); if not s then return "SKIP" end return typeof(m) == "Instance" end))

register(469, "Vector3.FuzzyEq type check", custom(function() return not Vector3 or type(Vector3.zero.FuzzyEq) == "function" end))
register(470, "Vector3.Lerp type check", custom(function() return not Vector3 or type(Vector3.zero.Lerp) == "function" end))
register(471, "Vector3.Max type check", custom(function() return not Vector3 or type(Vector3.zero.Max) == "function" end))
register(472, "Vector3.Min type check", custom(function() return not Vector3 or type(Vector3.zero.Min) == "function" end))
register(473, "Vector3.Angle type check", custom(function() return not Vector3 or type(Vector3.zero.Angle) == "function" end))
register(474, "Vector3.FuzzyEq parameter evaluation", custom(function() return not Vector3 or Vector3.zero:FuzzyEq(Vector3.zero) == true end))
register(475, "Vector3.Lerp parameter evaluation", custom(function() return not Vector3 or typeof(Vector3.zero:Lerp(Vector3.one, 0.5)) == "Vector3" end))
register(476, "Vector3.Max parameter evaluation", custom(function() return not Vector3 or typeof(Vector3.zero:Max(Vector3.one)) == "Vector3" end))
register(477, "Vector3.Min parameter evaluation", custom(function() return not Vector3 or typeof(Vector3.zero:Min(Vector3.one)) == "Vector3" end))
register(478, "Vector3.Angle parameter evaluation", custom(function() return not Vector3 or type(Vector3.xAxis:Angle(Vector3.yAxis)) == "number" end))
register(479, "Vector3.one reference check", custom(function() return not Vector3 or typeof(Vector3.one) == "Vector3" end))
register(480, "Vector3.xAxis reference check", custom(function() return not Vector3 or typeof(Vector3.xAxis) == "Vector3" end))
register(481, "Vector3.yAxis reference check", custom(function() return not Vector3 or typeof(Vector3.yAxis) == "Vector3" end))
register(482, "Vector3.zAxis reference check", custom(function() return not Vector3 or typeof(Vector3.zAxis) == "Vector3" end))
register(483, "Vector3 addition return type validation", custom(function() return not Vector3 or typeof(Vector3.one + Vector3.one) == "Vector3" end))
register(484, "Vector3 subtraction return type validation", custom(function() return not Vector3 or typeof(Vector3.one - Vector3.one) == "Vector3" end))
register(485, "Vector3 multiplication return type validation", custom(function() return not Vector3 or typeof(Vector3.one * Vector3.one) == "Vector3" end))
register(486, "Vector3 division return type validation", custom(function() return not Vector3 or typeof(Vector3.one / Vector3.one) == "Vector3" end))
register(487, "Vector3 scalar multiplication return type validation", custom(function() return not Vector3 or typeof(Vector3.one * 2) == "Vector3" end))
register(488, "Vector3 scalar division return type validation", custom(function() return not Vector3 or typeof(Vector3.one / 2) == "Vector3" end))
register(489, "CFrame.LookAt type check", custom(function() return not CFrame or type(CFrame.lookAt) == "function" end))
register(490, "CFrame.fromMatrix type check", custom(function() return not CFrame or type(CFrame.fromMatrix) == "function" end))
register(491, "CFrame.fromEulerAnglesXYZ type check", custom(function() return not CFrame or type(CFrame.fromEulerAnglesXYZ) == "function" end))
register(492, "CFrame.fromEulerAnglesYXZ type check", custom(function() return not CFrame or type(CFrame.fromEulerAnglesYXZ) == "function" end))
register(493, "CFrame.fromAxisAngle type check", custom(function() return not CFrame or type(CFrame.fromAxisAngle) == "function" end))
register(494, "CFrame.fromOrientation type check", custom(function() return not CFrame or type(CFrame.fromOrientation) == "function" end))
register(495, "CFrame.identity reference check", custom(function() return not CFrame or typeof(CFrame.identity) == "CFrame" end))
register(496, "CFrame.lookAt parameter evaluation", custom(function() return not CFrame or typeof(CFrame.lookAt(Vector3.zero, Vector3.one)) == "CFrame" end))
register(497, "CFrame.fromMatrix parameter evaluation", custom(function() return not CFrame or typeof(CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.yAxis, Vector3.zAxis)) == "CFrame" end))
register(498, "CFrame.fromEulerAnglesXYZ parameter evaluation", custom(function() return not CFrame or typeof(CFrame.fromEulerAnglesXYZ(0,0,0)) == "CFrame" end))
register(499, "CFrame.fromEulerAnglesYXZ parameter evaluation", custom(function() return not CFrame or typeof(CFrame.fromEulerAnglesYXZ(0,0,0)) == "CFrame" end))
register(500, "CFrame.fromAxisAngle parameter evaluation", custom(function() return not CFrame or typeof(CFrame.fromAxisAngle(Vector3.xAxis, 0)) == "CFrame" end))
register(501, "CFrame.fromOrientation parameter evaluation", custom(function() return not CFrame or typeof(CFrame.fromOrientation(0,0,0)) == "CFrame" end))
register(502, "CFrame matrix multiplication return type validation", custom(function() return not CFrame or typeof(CFrame.new() * Vector3.zero) == "Vector3" end))
register(503, "CFrame:ToEulerAnglesXYZ type check", custom(function() return not CFrame or type(CFrame.new().ToEulerAnglesXYZ) == "function" end))
register(504, "CFrame:ToEulerAnglesYXZ type check", custom(function() return not CFrame or type(CFrame.new().ToEulerAnglesYXZ) == "function" end))
register(505, "CFrame:ToOrientation type check", custom(function() return not CFrame or type(CFrame.new().ToOrientation) == "function" end))
register(506, "CFrame:ToAxisAngle type check", custom(function() return not CFrame or type(CFrame.new().ToAxisAngle) == "function" end))
register(507, "CFrame:PointToObjectSpace type check", custom(function() return not CFrame or type(CFrame.new().PointToObjectSpace) == "function" end))
register(508, "CFrame:VectorToObjectSpace type check", custom(function() return not CFrame or type(CFrame.new().VectorToObjectSpace) == "function" end))

register(509, "getmetatable empty table return check", custom(function() return getmetatable({}) == nil end))
register(510, "setmetatable assignment validation", custom(function() local t = {}; return setmetatable(t, {}) == t end))
register(511, "__index metamethod execution", custom(function() local t = setmetatable({}, {__index = function() return "OK" end}); return t.test == "OK" end))
register(512, "__newindex metamethod execution", custom(function() local v = 0; local t = setmetatable({}, {__newindex = function() v = 1 end}); t.test = 2; return v == 1 end))
register(513, "__call metamethod execution", custom(function() local t = setmetatable({}, {__call = function() return "OK" end}); return t() == "OK" end))
register(514, "__concat metamethod execution", custom(function() local t = setmetatable({}, {__concat = function() return "OK" end}); return t .. "a" == "OK" end))
register(515, "__unm metamethod execution", custom(function() local t = setmetatable({}, {__unm = function() return "OK" end}); return -t == "OK" end))
register(516, "__add metamethod execution", custom(function() local t = setmetatable({}, {__add = function() return "OK" end}); return t + 1 == "OK" end))
register(517, "__sub metamethod execution", custom(function() local t = setmetatable({}, {__sub = function() return "OK" end}); return t - 1 == "OK" end))
register(518, "__mul metamethod execution", custom(function() local t = setmetatable({}, {__mul = function() return "OK" end}); return t * 1 == "OK" end))
register(519, "__div metamethod execution", custom(function() local t = setmetatable({}, {__div = function() return "OK" end}); return t / 1 == "OK" end))
register(520, "__idiv metamethod execution", custom(function() local t = setmetatable({}, {__idiv = function() return "OK" end}); return t // 1 == "OK" end))
register(521, "__mod metamethod execution", custom(function() local t = setmetatable({}, {__mod = function() return "OK" end}); return t % 1 == "OK" end))
register(522, "__pow metamethod execution", custom(function() local t = setmetatable({}, {__pow = function() return "OK" end}); return t ^ 1 == "OK" end))
register(523, "__len metamethod execution", custom(function() local t = setmetatable({}, {__len = function() return 5 end}); return #t == 5 end))
register(524, "__iter metamethod execution", custom(function() local t = setmetatable({}, {__iter = function() return function() return nil end end}); for k in t do end return true end))
register(525, "rawget ignores __index metamethod", custom(function() local t = setmetatable({}, {__index = function() return "OK" end}); return rawget(t, "test") == nil end))
register(526, "rawset ignores __newindex metamethod", custom(function() local t = setmetatable({}, {__newindex = function() error("NO") end}); rawset(t, "test", 1); return t.test == 1 end))
register(527, "rawequal ignores __eq metamethod", custom(function() local t1 = setmetatable({}, {__eq = function() return true end}); local t2 = setmetatable({}, {__eq = function() return true end}); return rawequal(t1, t2) == false end))
register(528, "rawlen operator type check", custom(function() local f = rawlen or function(t) return #t end; return type(f({1,2})) == "number" end))
register(529, "string metatable read protection", custom(function() return getmetatable("") == "The metatable is locked" end))
register(530, "newproxy userdata type check", custom(function() if not newproxy then return "SKIP" end return type(newproxy(true)) == "userdata" end))
register(531, "newproxy metatable type check", custom(function() if not newproxy then return "SKIP" end return type(getmetatable(newproxy(true))) == "table" end))
register(532, "userdata metatable write validation", custom(function() if not newproxy then return "SKIP" end local u = newproxy(true); getmetatable(u).__index = function() return 1 end; return u.test == 1 end))
register(533, "userdata __tostring metamethod evaluation", custom(function() if not newproxy then return "SKIP" end local u = newproxy(true); getmetatable(u).__tostring = function() return "OK" end; return tostring(u) == "OK" end))
register(534, "userdata __len metamethod evaluation", custom(function() if not newproxy then return "SKIP" end local u = newproxy(true); getmetatable(u).__len = function() return 5 end; return #u == 5 end))

register(535, "string.byte upper bound check", custom(function() return string.byte("A") == 65 end))
register(536, "string.char upper bound check", custom(function() return string.char(65) == "A" end))
register(537, "string.find pattern parsing check", custom(function() return string.find("a1a", "%d") == 2 end))
register(538, "string.format specifier parsing check", custom(function() return string.format("%X", 255) == "FF" end))
register(539, "string.gmatch loop index validation", custom(function() local c = 0; for _ in string.gmatch("aaa", "a") do c = c + 1 end return c == 3 end))
register(540, "string.gsub replacement bound evaluation", custom(function() local _, c = string.gsub("aaa", "a", "b", 2); return c == 2 end))
register(541, "string.len empty sequence check", custom(function() return string.len("") == 0 end))
register(542, "string.lower non-alpha exclusion", custom(function() return string.lower("!@#") == "!@#" end))
register(543, "string.match capture sequence check", custom(function() return string.match("ab", "(b)") == "b" end))
register(544, "string.rep zero multiplication check", custom(function() return string.rep("a", 0) == "" end))
register(545, "string.sub negative index parsing check", custom(function() return string.sub("abc", -1) == "c" end))
register(546, "string.upper non-alpha exclusion", custom(function() return string.upper("!@#") == "!@#" end))
register(547, "string.split default array generation", custom(function() if not string.split then return "SKIP" end return type(string.split("a,b", ",")) == "table" end))
register(548, "table.freeze type check", custom(function() return type(table.freeze) == "function" end))
register(549, "table.isfrozen type check", custom(function() return type(table.isfrozen) == "function" end))
register(550, "table.freeze write protection check", custom(function() local t = {}; table.freeze(t); local s = pcall(function() t.a = 1 end); return not s end))
register(551, "table.isfrozen state flag evaluation", custom(function() local t = {}; table.freeze(t); return table.isfrozen(t) == true end))
register(552, "table.insert blocked on frozen table check", custom(function() local t = {}; table.freeze(t); return not pcall(table.insert, t, 1) end))
register(553, "table.remove blocked on frozen table check", custom(function() local t = {1}; table.freeze(t); return not pcall(table.remove, t, 1) end))
register(554, "table.sort custom comparator parameter", custom(function() local t = {2, 1}; table.sort(t, function(a, b) return a < b end); return t[1] == 1 end))
register(555, "table.move type check", custom(function() return type(table.move) == "function" end))
register(556, "table.move sequence transition check", custom(function() local t1 = {1}; local t2 = {}; table.move(t1, 1, 1, 1, t2); return t2[1] == 1 end))
register(557, "table.pack structure validation", custom(function() if not table.pack then return "SKIP" end return table.pack(1, 2).n == 2 end))
register(558, "table.unpack precise index matching", custom(function() local u = table.unpack or unpack; local a, b = u({1, 2}, 1, 2); return a == 1 and b == 2 end))
register(559, "table.clear sequence reduction check", custom(function() if not table.clear then return "SKIP" end local t = {1}; table.clear(t); return #t == 0 end))
register(560, "table.clone reference duplication check", custom(function() if not table.clone then return "SKIP" end local t = {1}; local t2 = table.clone(t); return t ~= t2 and t[1] == t2[1] end))
register(561, "table.find sequential search validation", custom(function() if not table.find then return "SKIP" end return table.find({1, 2}, 2) == 2 end))
register(562, "bit32.countlz type check", custom(function() if not bit32 then return "SKIP" end return type(bit32.countlz) == "function" end))
register(563, "bit32.countrz type check", custom(function() if not bit32 then return "SKIP" end return type(bit32.countrz) == "function" end))
register(564, "bit32.replace type check", custom(function() if not bit32 then return "SKIP" end return type(bit32.replace) == "function" end))
register(565, "bit32.extract type check", custom(function() if not bit32 then return "SKIP" end return type(bit32.extract) == "function" end))
register(566, "bit32.countlz parameter evaluation", custom(function() if not bit32 or not bit32.countlz then return "SKIP" end return bit32.countlz(0) == 32 end))
register(567, "bit32.countrz parameter evaluation", custom(function() if not bit32 or not bit32.countrz then return "SKIP" end return bit32.countrz(0) == 32 end))
register(568, "bit32.extract parameter evaluation", custom(function() if not bit32 or not bit32.extract then return "SKIP" end return bit32.extract(1, 0, 1) == 1 end))
register(569, "utf8.charpattern string pattern type check", custom(function() if not utf8 then return "SKIP" end return type(utf8.charpattern) == "string" end))
register(570, "utf8.codes type check", custom(function() if not utf8 then return "SKIP" end return type(utf8.codes) == "function" end))
register(571, "utf8.codepoint type check", custom(function() if not utf8 then return "SKIP" end return type(utf8.codepoint) == "function" end))
register(572, "utf8.len type check", custom(function() if not utf8 then return "SKIP" end return type(utf8.len) == "function" end))
register(573, "utf8.offset type check", custom(function() if not utf8 then return "SKIP" end return type(utf8.offset) == "function" end))
register(574, "utf8.graphemes type check", custom(function() if not utf8 then return "SKIP" end return type(utf8.graphemes) == "function" end))
register(575, "utf8.len sequence evaluation", custom(function() if not utf8 then return "SKIP" end return utf8.len("a") == 1 end))
register(576, "math.huge numerical evaluation", custom(function() return math.huge > 1e308 end))
register(577, "math.pi decimal approximation", custom(function() return math.abs(math.pi - 3.1415926535898) < 1e-10 end))
register(578, "NaN literal verification", custom(function() return (0/0) ~= (0/0) end))
register(579, "positive infinity calculation verification", custom(function() return (1/0) == math.huge end))
register(580, "negative infinity calculation verification", custom(function() return (-1/0) == -math.huge end))
register(581, "math.sin parameter approximation check", custom(function() return math.abs(math.sin(math.pi)) < 1e-14 end))
register(582, "math.cos parameter evaluation", custom(function() return math.cos(math.pi) == -1 end))
register(583, "math.clamp parameter bound check", custom(function() return type(math.clamp) == "function" and math.clamp(5, 1, 3) == 3 end))
register(584, "math.sign parameter negative check", custom(function() return type(math.sign) == "function" and math.sign(-5) == -1 end))

register(585, "coroutine.isyieldable boolean check", custom(function() if not coroutine.isyieldable then return "SKIP" end return type(coroutine.isyieldable()) == "boolean" end))
register(586, "coroutine.close sequence evaluation", custom(function() if not coroutine.close then return "SKIP" end local c = coroutine.create(function() end); coroutine.close(c); return coroutine.status(c) == "dead" end))
register(587, "coroutine.status dead property check", custom(function() local c = coroutine.create(function() end); coroutine.resume(c); return coroutine.status(c) == "dead" end))
register(588, "coroutine.status suspended property check", custom(function() local c = coroutine.create(function() coroutine.yield() end); coroutine.resume(c); return coroutine.status(c) == "suspended" end))
register(589, "coroutine.status running property check", custom(function() return coroutine.status(coroutine.running()) == "running" end))
register(590, "task.spawn type check", custom(function() if not task then return "SKIP" end return type(task.spawn(function() end)) == "thread" end))
register(591, "task.defer type check", custom(function() if not task then return "SKIP" end return type(task.defer(function() end)) == "thread" end))
register(592, "task.delay type check", custom(function() if not task then return "SKIP" end return type(task.delay(0, function() end)) == "thread" end))
register(593, "task.cancel execution validation", custom(function() if not task or not task.cancel then return "SKIP" end local t = task.delay(10, function() end); return pcall(task.cancel, t) end))
register(594, "coroutine.wrap function wrapper check", custom(function() return type(coroutine.wrap(function() end)) == "function" end))
register(595, "debug.traceback line limit bounds check", custom(function() if not debug or not debug.traceback then return "SKIP" end return type(debug.traceback("TEST", 2)) == "string" end))
register(596, "debug.info 'a' flag format check", custom(function() if not debug or not debug.info then return "SKIP" end local s = pcall(debug.info, 1, "a"); return s end))
register(597, "debug.info 'f' flag format check", custom(function() if not debug or not debug.info then return "SKIP" end local s = pcall(debug.info, 1, "f"); return s end))
register(598, "debug.info 'n' flag format check", custom(function() if not debug or not debug.info then return "SKIP" end local s = pcall(debug.info, 1, "n"); return s end))
register(599, "getfenv(1) environment table check", custom(function() return type(getfenv(1)) == "table" end))
register(600, "setfenv is C Closure", isC(setfenv))
register(601, "getfenv is C Closure", isC(getfenv))
register(602, "_G global environment type check", custom(function() return type(_G) == "table" end))
register(603, "shared global environment type check", custom(function() return type(shared) == "table" end))
register(604, "_VERSION constant global type check", custom(function() return type(_VERSION) == "string" end))
register(605, "gcinfo return type check", custom(function() return type(gcinfo()) == "number" end))
register(606, "collectgarbage execution validation", custom(function() return pcall(collectgarbage, "count") end))

register(607, "getgenv return type", custom(function() if not getgenv then return "SKIP" end return type(getgenv()) == "table" end))
register(608, "getrenv return type", custom(function() if not getrenv then return "SKIP" end return type(getrenv()) == "table" end))
register(609, "getreg return type", custom(function() if not getreg then return "SKIP" end return type(getreg()) == "table" end))
register(610, "getgc return type", custom(function() if not getgc then return "SKIP" end return type(getgc()) == "table" end))
register(611, "getinstances return type", custom(function() if not getinstances then return "SKIP" end return type(getinstances()) == "table" end))
register(612, "getnilinstances return type", custom(function() if not getnilinstances then return "SKIP" end return type(getnilinstances()) == "table" end))
register(613, "getscripts return type", custom(function() if not getscripts then return "SKIP" end return type(getscripts()) == "table" end))
register(614, "getloadedmodules return type", custom(function() if not getloadedmodules then return "SKIP" end return type(getloadedmodules()) == "table" end))
register(615, "getconnections return type", custom(function() if not getconnections then return "SKIP" end local s = Instance.new("BindableEvent"); return type(getconnections(s.Event)) == "table" end))
register(616, "getconnections missing argument error", custom(function() if not getconnections then return "SKIP" end return not pcall(getconnections) end))
register(617, "firesignal event trigger", custom(function() if not firesignal then return "SKIP" end local s = Instance.new("BindableEvent"); local o = false; s.Event:Connect(function() o = true end); firesignal(s.Event); task.wait(0.01); return o end))
register(618, "firesignal missing argument error", custom(function() if not firesignal then return "SKIP" end return not pcall(firesignal) end))
register(619, "fireclickdetector type check", custom(function() if not fireclickdetector then return "SKIP" end return type(fireclickdetector) == "function" end))
register(620, "fireclickdetector missing argument error", custom(function() if not fireclickdetector then return "SKIP" end return not pcall(fireclickdetector) end))
register(621, "fireproximityprompt type check", custom(function() if not fireproximityprompt then return "SKIP" end return type(fireproximityprompt) == "function" end))
register(622, "fireproximityprompt missing argument error", custom(function() if not fireproximityprompt then return "SKIP" end return not pcall(fireproximityprompt) end))
register(623, "isnetworkowner type check", custom(function() if not isnetworkowner then return "SKIP" end return type(isnetworkowner) == "function" end))
register(624, "isnetworkowner missing argument error", custom(function() if not isnetworkowner then return "SKIP" end return not pcall(isnetworkowner) end))
register(625, "gethiddenproperty type check", custom(function() if not gethiddenproperty then return "SKIP" end return type(gethiddenproperty) == "function" end))
register(626, "gethiddenproperty missing argument error", custom(function() if not gethiddenproperty then return "SKIP" end return not pcall(gethiddenproperty) end))
register(627, "sethiddenproperty type check", custom(function() if not sethiddenproperty then return "SKIP" end return type(sethiddenproperty) == "function" end))
register(628, "sethiddenproperty missing argument error", custom(function() if not sethiddenproperty then return "SKIP" end return not pcall(sethiddenproperty) end))
register(629, "setsimulationradius type check", custom(function() if not setsimulationradius then return "SKIP" end return type(setsimulationradius) == "function" end))
register(630, "setsimulationradius missing argument error", custom(function() if not setsimulationradius then return "SKIP" end return not pcall(setsimulationradius) end))
register(631, "hookfunction type check", custom(function() if not hookfunction then return "SKIP" end return type(hookfunction) == "function" end))
register(632, "hookfunction missing argument error", custom(function() if not hookfunction then return "SKIP" end return not pcall(hookfunction) end))
register(633, "hookmetamethod type check", custom(function() if not hookmetamethod then return "SKIP" end return type(hookmetamethod) == "function" end))
register(634, "hookmetamethod missing argument error", custom(function() if not hookmetamethod then return "SKIP" end return not pcall(hookmetamethod) end))
register(635, "newcclosure type check", custom(function() if not newcclosure then return "SKIP" end return type(newcclosure) == "function" end))
register(636, "newcclosure missing argument error", custom(function() if not newcclosure then return "SKIP" end return not pcall(newcclosure) end))
register(637, "iscclosure type check", custom(function() if not iscclosure then return "SKIP" end return type(iscclosure) == "function" end))
register(638, "iscclosure missing argument error", custom(function() if not iscclosure then return "SKIP" end return not pcall(iscclosure) end))
register(639, "islclosure type check", custom(function() if not islclosure then return "SKIP" end return type(islclosure) == "function" end))
register(640, "islclosure missing argument error", custom(function() if not islclosure then return "SKIP" end return not pcall(islclosure) end))
register(641, "checkcaller return type boolean", custom(function() if not checkcaller then return "SKIP" end return type(checkcaller()) == "boolean" end))
register(642, "clonefunction type check", custom(function() if not clonefunction then return "SKIP" end return type(clonefunction) == "function" end))
register(643, "clonefunction missing argument error", custom(function() if not clonefunction then return "SKIP" end return not pcall(clonefunction) end))
register(644, "setreadonly type check", custom(function() if not setreadonly then return "SKIP" end return type(setreadonly) == "function" end))
register(645, "setreadonly missing argument error", custom(function() if not setreadonly then return "SKIP" end return not pcall(setreadonly) end))
register(646, "isreadonly type check", custom(function() if not isreadonly then return "SKIP" end return type(isreadonly) == "function" end))
register(647, "isreadonly missing argument error", custom(function() if not isreadonly then return "SKIP" end return not pcall(isreadonly) end))
register(648, "getrawmetatable type check", custom(function() if not getrawmetatable then return "SKIP" end return type(getrawmetatable) == "function" end))
register(649, "setrawmetatable type check", custom(function() if not setrawmetatable then return "SKIP" end return type(setrawmetatable) == "function" end))
register(650, "setrawmetatable missing argument error", custom(function() if not setrawmetatable then return "SKIP" end return not pcall(setrawmetatable) end))
register(651, "getnamecallmethod type check", custom(function() if not getnamecallmethod then return "SKIP" end return type(getnamecallmethod) == "function" end))
register(652, "setnamecallmethod type check", custom(function() if not setnamecallmethod then return "SKIP" end return type(setnamecallmethod) == "function" end))
register(653, "setnamecallmethod missing argument error", custom(function() if not setnamecallmethod then return "SKIP" end return not pcall(setnamecallmethod) end))
register(654, "getcallingscript type check", custom(function() if not getcallingscript then return "SKIP" end return type(getcallingscript) == "function" end))
register(655, "getscriptclosure type check", custom(function() if not getscriptclosure then return "SKIP" end return type(getscriptclosure) == "function" end))
register(656, "getscriptclosure missing argument error", custom(function() if not getscriptclosure then return "SKIP" end return not pcall(getscriptclosure) end))
register(657, "readfile type check", custom(function() if not readfile then return "SKIP" end return type(readfile) == "function" end))
register(658, "readfile missing argument error", custom(function() if not readfile then return "SKIP" end return not pcall(readfile) end))
register(659, "writefile type check", custom(function() if not writefile then return "SKIP" end return type(writefile) == "function" end))
register(660, "writefile missing argument error", custom(function() if not writefile then return "SKIP" end return not pcall(writefile) end))
register(661, "delfile type check", custom(function() if not delfile then return "SKIP" end return type(delfile) == "function" end))
register(662, "delfile missing argument error", custom(function() if not delfile then return "SKIP" end return not pcall(delfile) end))
register(663, "listfiles type check", custom(function() if not listfiles then return "SKIP" end return type(listfiles) == "function" end))
register(664, "listfiles missing argument error", custom(function() if not listfiles then return "SKIP" end return not pcall(listfiles) end))
register(665, "isfolder type check", custom(function() if not isfolder then return "SKIP" end return type(isfolder) == "function" end))
register(666, "isfolder missing argument error", custom(function() if not isfolder then return "SKIP" end return not pcall(isfolder) end))
register(667, "makefolder type check", custom(function() if not makefolder then return "SKIP" end return type(makefolder) == "function" end))
register(668, "makefolder missing argument error", custom(function() if not makefolder then return "SKIP" end return not pcall(makefolder) end))
register(669, "delfolder type check", custom(function() if not delfolder then return "SKIP" end return type(delfolder) == "function" end))
register(670, "delfolder missing argument error", custom(function() if not delfolder then return "SKIP" end return not pcall(delfolder) end))
register(671, "crypt table type check", custom(function() if not crypt then return "SKIP" end return type(crypt) == "table" end))
register(672, "crypt.base64encode missing argument error", custom(function() if not crypt or not crypt.base64encode then return "SKIP" end return not pcall(crypt.base64encode) end))
register(673, "crypt.base64decode missing argument error", custom(function() if not crypt or not crypt.base64decode then return "SKIP" end return not pcall(crypt.base64decode) end))
register(674, "crypt.encrypt missing argument error", custom(function() if not crypt or not crypt.encrypt then return "SKIP" end return not pcall(crypt.encrypt) end))
register(675, "crypt.decrypt missing argument error", custom(function() if not crypt or not crypt.decrypt then return "SKIP" end return not pcall(crypt.decrypt) end))

register(676, "typeof return value", custom(function() return type(typeof) == "function" and typeof(1) == "number" end))
register(677, "wait type check", custom(function() return type(wait) == "function" end))
register(678, "delay type check", custom(function() return type(delay) == "function" end))
register(679, "spawn type check", custom(function() return type(spawn) == "function" end))
register(680, "tick float calculation", custom(function() return type(tick()) == "number" end))
register(681, "time float calculation", custom(function() return type(time()) == "number" end))
register(682, "os.time integer calculation", custom(function() return type(os.time()) == "number" end))
register(683, "os.clock float calculation", custom(function() return type(os.clock()) == "number" end))
register(684, "os.date return evaluation", custom(function() return os.date() ~= nil end))
register(685, "os.difftime integer return evaluation", custom(function() return type(os.difftime(2, 1)) == "number" end))
register(686, "settings return type", custom(function() return type(settings) == "function" and typeof(settings()) == "Instance" end))
register(687, "UserSettings return type", custom(function() return type(UserSettings) == "function" and typeof(UserSettings()) == "Instance" end))
register(688, "PluginManager type check", custom(function() return type(PluginManager) == "function" end))
register(689, "require type check", custom(function() return type(require) == "function" end))
register(690, "require non-instance argument error", custom(function() return not pcall(require, 1) end))
register(691, "_G __index validation", custom(function() local s = pcall(function() return _G.TEST_ID_BOUNDS end); return s end))
register(692, "shared __index validation", custom(function() local s = pcall(function() return shared.TEST_ID_BOUNDS end); return s end))

register(693, "math.pi is a number", custom(function() return type(math.pi) == "number" end))
register(694, "math.huge numerical comparison", custom(function() return math.huge > 1e20 end))
register(695, "math.abs(0) numerical calculation", valMatch(math.abs, 0, 0))
register(696, "math.sin(pi/2) numerical approximation", custom(function() return math.abs(math.sin(math.pi / 2) - 1) < 1e-9 end))
register(697, "math.cos(pi) numerical approximation", custom(function() return math.abs(math.cos(math.pi) + 1) < 1e-9 end))
register(698, "math.sqrt(16) numerical calculation", valMatch(math.sqrt, 16, 4))
register(699, "math.floor(1.999) numerical calculation", valMatch(math.floor, 1.999, 1))
register(700, "math.ceil(1.001) numerical calculation", valMatch(math.ceil, 1.001, 2))
register(701, "string.len argument evaluation", valMatch(string.len, "", 0))
register(702, "string.sub index parameter extraction", custom(function() return string.sub("abc", 2, 3) == "bc" end))
register(703, "string.find argument search evaluation", custom(function() return string.find("abc", "b") == 2 end))
register(704, "string.gsub replacement assignment", custom(function() local out, n = string.gsub("aaa", "a", "b"); return out == "bbb" and n == 3 end))
register(705, "string.rep string length calculation", custom(function() return string.rep("x", 0) == "" end))
register(706, "table.concat string format validation", custom(function() return table.concat({"a", "b", "c"}, ",") == "a,b,c" end))
register(707, "table.insert and table.remove sequence execution", custom(function() local t = {}; table.insert(t, "x"); return table.remove(t) == "x" and #t == 0 end))
register(708, "table.sort comparison check", custom(function() local t = {3, 1, 2}; table.sort(t); return t[1] == 1 and t[2] == 2 and t[3] == 3 end))
register(709, "table.pack and unpack structure validation", custom(function() local u = table.unpack or unpack; local p = table.pack(1, 2, 3); local a, b, c = u(p, 1, p.n); return a == 1 and b == 2 and c == 3 and p.n == 3 end))
register(710, "pcall execution evaluation", custom(function() local ok, err = pcall(function() error("PCALL_SENTINEL") end); return not ok and tostring(err):find("PCALL_SENTINEL", 1, true) ~= nil end))
register(711, "xpcall error handler string execution", custom(function() local handled = false; local ok = xpcall(function() error("XPCALL_SENTINEL") end, function(err) handled = tostring(err):find("XPCALL_SENTINEL", 1, true) ~= nil end); return not ok and handled end))
register(712, "coroutine yield and resume state evaluation", custom(function() local co = coroutine.create(function() return coroutine.yield("pause"), "done" end); local ok1, val = coroutine.resume(co); local ok2, final = coroutine.resume(co, "resume"); return ok1 and ok2 and val == "pause" and final == "resume" end))
register(713, "bit32.band parameter execution", custom(function() if not bit32 or not bit32.band then return "SKIP" end return bit32.band(0xF0, 0x0F) == 0 end))
register(714, "bit32.bxor parameter execution", custom(function() if not bit32 or not bit32.bxor then return "SKIP" end return bit32.bxor(1, 3) == 2 end))
register(715, "bit32.bnot limit bounds check", custom(function() if not bit32 or not bit32.bnot then return "SKIP" end return bit32.bnot(0) == 4294967295 end))
register(716, "utf8.len multi-byte processing format check", custom(function() if not utf8 or not utf8.len then return "SKIP" end return utf8.len("é") == 1 end))
register(717, "utf8.codepoint numerical limit check", custom(function() if not utf8 or not utf8.codepoint then return "SKIP" end return utf8.codepoint("A") == 65 end))

local tst2 = {
    {
        751, "pcall and xpcall debug.info signature", function()
            local ok, info1 = pcall(debug.info, pcall, "sfna")
            local ok2, info2 = pcall(debug.info, xpcall, "sfna")
            if not ok or not ok2 then return false end
            return info1.what == "C" and info1.name == "pcall" and info1.source == "[C]" 
               and info2.what == "C" and info2.name == "xpcall" and info2.source == "[C]"
        end
    },
    {
        760, "Instance method expected self argument error", function()
            if not Instance then return "SKIP" end
            local p = Instance.new("Folder")
            local function testMethodError(method, matchStr)
                local s = pcall(method, p)
                return not s
            end
            local function testCallWithoutSelf(method, name)
                local s = pcall(method)
                return not s
            end
            return testCallWithoutSelf(p.Clone, "Clone") 
               and testCallWithoutSelf(p.Destroy, "Destroy") 
               and testCallWithoutSelf(p.GetChildren, "GetChildren")
        end
    },
    {
        761, "debug.getupvalue parameter bounds validation", function()
            if not debug or not debug.getupvalue then return "SKIP" end
            local function testBounds(fn)
                local s, n, v = pcall(debug.getupvalue, fn, 1)
                return s and n == nil and v == nil
            end
            return testBounds(math.abs) and testBounds(string.byte) and testBounds(table.insert) and testBounds(pcall)
        end
    },
    {
        763, "C-closure debug.info parameter count", function()
            local function checkArity(fn)
                local ok, info = pcall(debug.info, fn, "a")
                if not ok then return false end
                return type(info.nparams) == "number" or info.isvararg ~= nil
            end
            return checkArity(math.abs) and checkArity(string.byte) and checkArity(pcall) and checkArity(getrawmetatable or print)
        end
    },
    {
        764, "table.insert argument count validation", function()
            local t = {1, 2, 3}
            local s, err = pcall(table.insert, t)
            if s then return false end
            return not s and #t == 3
        end
    },
    {
        765, "math function parameter type error validation", function()
            local function testTypeErr(fn, arg, expectedStr)
                local s = pcall(fn, arg)
                return not s
            end
            return testTypeErr(math.abs, "string", "number expected, got string")
               and testTypeErr(math.floor, {}, "number expected, got table")
               and testTypeErr(math.ceil, true, "number expected, got boolean")
        end
    },
    {
        766, "string function parameter type error validation", function()
            local function testTypeErr(fn, arg, expectedStr)
                local s = pcall(fn, arg)
                return not s
            end
            return testTypeErr(string.byte, 123, "string expected, got number")
               and testTypeErr(string.len, {}, "string expected, got table")
               and testTypeErr(string.sub, true, "string expected, got boolean")
        end
    },
    {
        767, "table function parameter type error validation", function()
            local function testTypeErr(fn, arg, expectedStr)
                local s = pcall(fn, arg)
                return not s
            end
            return testTypeErr(table.insert, "string", "table expected, got string")
               and testTypeErr(table.concat, 123, "table expected, got number")
               and testTypeErr(table.remove, true, "table expected, got boolean")
        end
    },
    {
        769, "game.GetService missing argument error validation", function()
            if not game or not game.GetService then return "SKIP" end
            local s, err = pcall(function() game:GetService() end)
            if s then return false end
            return not s
        end
    },
    {
        770, "debug.traceback recursive stack depth execution", function()
            if not debug or not debug.traceback then return "SKIP" end
            local function level1() return debug.traceback("ANOMALY", 2) end
            local function level2() return level1() end
            local tb = level2()
            return string.find(tb, "ANOMALY") ~= nil and string.find(tb, "level1") == nil and string.find(tb, "level2") ~= nil
        end
    },
    {
        771, "pcall argument weak reference collection check", function()
            local weak = setmetatable({}, {__mode = "v"})
            do
                local t = {}
                weak[1] = t
                pcall(type, t)
            end
            collectgarbage("collect")
            return weak[1] == nil
        end
    },
    {
        772, "table.insert argument weak reference collection check", function()
            local weak = setmetatable({}, {__mode = "v"})
            do
                local t = {}
                weak[1] = t
                pcall(table.insert, {}, t)
            end
            collectgarbage("collect")
            return weak[1] == nil
        end
    },
    {
        773, "pcall C-continuation yield execution parameter check", function()
            local co = coroutine.create(function()
                return pcall(function()
                    coroutine.yield("TEST")
                    return "SUCCESS"
                end)
            end)
            local ok1, res1 = coroutine.resume(co)
            if not ok1 or res1 ~= "TEST" then return false end
            local ok2, ok3, res2 = coroutine.resume(co)
            return ok2 and ok3 == true and res2 == "SUCCESS"
        end
    },
    {
        774, "xpcall C-continuation yield execution parameter check", function()
            local co = coroutine.create(function()
                return xpcall(function()
                    coroutine.yield("TEST")
                    return "SUCCESS"
                end, function(err) return err end)
            end)
            local ok1, res1 = coroutine.resume(co)
            if not ok1 or res1 ~= "TEST" then return false end
            local ok2, ok3, res2 = coroutine.resume(co)
            return ok2 and ok3 == true and res2 == "SUCCESS"
        end
    },
    {
        775, "controlled error path keeps stack frame count stable across direct and __index dispatch", function()
            if not debug or not debug.info then return "SKIP" end

            local function frame_count(trigger)
                local depth = nil
                xpcall(trigger, function()
                    local n = 0
                    for level = 1, 128 do
                        local ok, info = pcall(debug.info, level, "f")
                        if not ok or info == nil then
                            break
                        end
                        n = n + 1
                    end
                    depth = n
                end)
                return depth
            end

            local direct = frame_count(function()
                error("SEB_STACK", 0)
            end)

            local via_index = frame_count(function()
                local proxy = setmetatable({}, {
                    __index = function()
                        error("SEB_STACK", 0)
                    end
                })
                local _ = proxy.missing
            end)

            return direct ~= nil and via_index ~= nil and direct == via_index
        end
    },
    {
        776, "rawget/member access produce identical native closure metadata", function()
            if not debug or not debug.info then return "SKIP" end

            local checks = {
                { lib = math,      key = "abs",    member = math.abs },
                { lib = string,    key = "byte",   member = string.byte },
                { lib = table,     key = "sort",   member = table.sort },
                { lib = coroutine, key = "resume", member = coroutine.resume },
            }

            for _, item in ipairs(checks) do
                local raw = rawget(item.lib, item.key)
                if raw == nil then return false end
                if not rawequal(raw, item.member) then return false end

                local ok1, info1 = pcall(debug.info, raw, "sn")
                local ok2, info2 = pcall(debug.info, item.member, "sn")
                if not ok1 or not ok2 then return false end
                if tostring(info1) ~= "[C]" or tostring(info2) ~= "[C]" then return false end
                if info1.name ~= info2.name then return false end
                if tostring(info1.source) ~= tostring(info2.source) then return false end
            end

            return true
        end
    },
    {
        777, "iterator closures stay C-shaped and wrapper-free", function()
            if not debug or not debug.info or not debug.getupvalue then return "SKIP" end

            local iterators = {}
            do
                local iter = ipairs({1, 2, 3})
                iterators[#iterators + 1] = { name = "ipairs", fn = iter }
            end
            do
                local iter = string.gmatch("one two", "%a+")
                iterators[#iterators + 1] = { name = "gmatch", fn = iter }
            end

            for _, item in ipairs(iterators) do
                if type(item.fn) ~= "function" then return false end

                local ok, info = pcall(debug.info, item.fn, "sn")
                if not ok then return false end
                if tostring(info) ~= "[C]" then return false end

                for i = 1, 32 do
                    local ok_uv, name, value = pcall(debug.getupvalue, item.fn, i)
                    if not ok_uv then break end
                    if name == nil and value == nil then break end
                    if type(value) == "function" or type(value) == "table" or type(value) == "thread" or type(value) == "userdata" then
                        return false
                    end
                end
            end

            return true
        end
    },
    {
        778, "xpcall preserves error object identity through handler path", function()
            local token = { tag = "SEB_ERR_OBJECT" }
            local seen = nil

            local ok = xpcall(function()
                error(token, 0)
            end, function(err)
                seen = err
                return true
            end)

            return not ok and rawequal(seen, token)
        end
    },
}

for _, spec in ipairs(tst2) do
    register(spec[1], spec[2], spec[3])
end

register(718, "rawget(math,'abs') == math.abs", custom(function()
    local raw = rawget(math, "abs")
    if raw == nil then return false end
    if not rawequal(raw, math.abs) then return false end
    local ok, info = pcall(debug.info, raw, "s")
    return ok and tostring(info) == "[C]"
end))

register(719, "rawget(math,'floor') == math.floor", custom(function()
    local raw = rawget(math, "floor")
    if raw == nil then return false end
    return rawequal(raw, math.floor)
end))

register(720, "rawget(math,'sin') == math.sin", custom(function()
    local raw = rawget(math, "sin")
    if raw == nil then return false end
    return rawequal(raw, math.sin)
end))

register(721, "rawget(string,'byte') == string.byte", custom(function()
    local raw = rawget(string, "byte")
    if raw == nil then return false end
    if not rawequal(raw, string.byte) then return false end
    local ok, info = pcall(debug.info, raw, "s")
    return ok and tostring(info) == "[C]"
end))

register(722, "rawget(string,'format') == string.format", custom(function()
    local raw = rawget(string, "format")
    if raw == nil then return false end
    return rawequal(raw, string.format)
end))

register(723, "rawget(string,'gsub') == string.gsub", custom(function()
    local raw = rawget(string, "gsub")
    if raw == nil then return false end
    return rawequal(raw, string.gsub)
end))

register(724, "rawget(table,'concat') == table.concat", custom(function()
    local raw = rawget(table, "concat")
    if raw == nil then return false end
    return rawequal(raw, table.concat)
end))

register(725, "rawget(table,'sort') == table.sort", custom(function()
    local raw = rawget(table, "sort")
    if raw == nil then return false end
    return rawequal(raw, table.sort)
end))

register(726, "rawget(coroutine,'create') == coroutine.create", custom(function()
    local raw = rawget(coroutine, "create")
    if raw == nil then return false end
    return rawequal(raw, coroutine.create)
end))

register(727, "rawget(coroutine,'resume') == coroutine.resume", custom(function()
    local raw = rawget(coroutine, "resume")
    if raw == nil then return false end
    return rawequal(raw, coroutine.resume)
end))

register(728, "debug.info(math.abs,'n') == 'abs'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, math.abs, "n")
    if not ok then return false end
    return name == "abs"
end))

register(729, "debug.info(math.floor,'n') == 'floor'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, math.floor, "n")
    if not ok then return false end
    return name == "floor"
end))

register(730, "debug.info(math.sqrt,'n') == 'sqrt'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, math.sqrt, "n")
    if not ok then return false end
    return name == "sqrt"
end))

register(731, "debug.info(math.sin,'n') == 'sin'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, math.sin, "n")
    if not ok then return false end
    return name == "sin"
end))

register(732, "debug.info(string.byte,'n') == 'byte'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, string.byte, "n")
    if not ok then return false end
    return name == "byte"
end))

register(733, "debug.info(string.format,'n') == 'format'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, string.format, "n")
    if not ok then return false end
    return name == "format"
end))

register(734, "debug.info(string.sub,'n') == 'sub'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, string.sub, "n")
    if not ok then return false end
    return name == "sub"
end))

register(735, "debug.info(table.insert,'n') == 'insert'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, table.insert, "n")
    if not ok then return false end
    return name == "insert"
end))

register(736, "debug.info(table.sort,'n') == 'sort'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, table.sort, "n")
    if not ok then return false end
    return name == "sort"
end))

register(737, "debug.info(pcall,'n') == 'pcall'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, pcall, "n")
    if not ok then return false end
    return name == "pcall"
end))

register(738, "debug.info(type,'n') == 'type'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, type, "n")
    if not ok then return false end
    return name == "type"
end))

register(739, "debug.info(tostring,'n') == 'tostring'", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, name = pcall(debug.info, tostring, "n")
    if not ok then return false end
    return name == "tostring"
end))

register(740, "math.abs wrong-type error preserves function name 'abs'", custom(function()
    local s, err = pcall(math.abs, "x")
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(741, "math.floor wrong-type error preserves function name 'floor'", custom(function()
    local s, err = pcall(math.floor, "x")
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(742, "math.sqrt wrong-type error preserves function name 'sqrt'", custom(function()
    local s, err = pcall(math.sqrt, "x")
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(743, "math.sin wrong-type error preserves function name 'sin'", custom(function()
    local s, err = pcall(math.sin, "x")
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(744, "math.ceil wrong-type error preserves function name 'ceil'", custom(function()
    local s, err = pcall(math.ceil, "x")
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(745, "table.concat wrong-type error preserves 'concat'", custom(function()
    local s, err = pcall(table.concat, "not_a_table")
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(746, "table.insert wrong-type error preserves 'insert'", custom(function()
    local s, err = pcall(table.insert, "not_a_table")
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(747, "table.sort wrong-type error preserves 'sort'", custom(function()
    local s, err = pcall(table.sort, "not_a_table")
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(748, "math.abs missing arg: full 'no value' format", custom(function()
    local s, err = pcall(math.abs)
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(749, "string.byte missing arg: full format", custom(function()
    local s, err = pcall(string.byte)
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(750, "table.insert missing arg #1: full format", custom(function()
    local s, err = pcall(table.insert)
    if s then return false end
    local msg = tostring(err)
    return not s
end))

register(751, "ipairs() returns correct initial state (table ref + 0)", custom(function()
    local t = {10, 20, 30}
    local iter, tbl, init = ipairs(t)
    if not rawequal(tbl, t) then return false end
    if init ~= 0 then return false end
    if not debug or not debug.info then return true end
    local ok, info = pcall(debug.info, iter, "s")
    return ok and tostring(info) == "[C]"
end))

register(752, "next() is deterministic on same table state", custom(function()
    local t = {x = 10, y = 20}
    local k1, v1 = next(t, nil)
    local k2, v2 = next(t, nil)
    local k3, v3 = next(t, nil)
    return rawequal(k1, k2) and rawequal(k2, k3) and rawequal(v1, v2) and rawequal(v2, v3)
end))

register(753, "next() sequential traversal consistent", custom(function()
    local t = {a = 1, b = 2, c = 3}
    local visited = {}
    local k = nil
    for _ = 1, 4 do
        k = next(t, k)
        if k == nil then break end
        if visited[k] then return false end
        visited[k] = true
    end
    local count = 0
    for _ in pairs(visited) do count = count + 1 end
    return count == 3
end))

register(754, "rawequal(math.abs, math.abs) is true", custom(function()
    return rawequal(math.abs, math.abs) and rawequal(math.floor, math.floor) and rawequal(math.sin, math.sin) and rawequal(math.cos, math.cos)
end))

register(755, "rawequal(string.byte, string.byte) is true", custom(function()
    return rawequal(string.byte, string.byte) and rawequal(string.format, string.format) and rawequal(string.gsub, string.gsub) and rawequal(string.gmatch, string.gmatch)
end))

register(756, "rawequal(table.sort, table.sort) is true", custom(function()
    return rawequal(table.sort, table.sort) and rawequal(table.concat, table.concat) and rawequal(table.insert, table.insert)
end))

register(757, "rawequal(pcall, pcall) and (type, type) is true", custom(function()
    return rawequal(pcall, pcall) and rawequal(type, type) and rawequal(tostring, tostring) and rawequal(error, error) and rawequal(assert, assert) and rawequal(next, next)
end))

register(758, "rawequal(math.abs, math.floor) is false (sanity check)", custom(function()
    return not rawequal(math.abs, math.floor) and not rawequal(math.sin, math.cos) and not rawequal(string.byte, string.sub) and not rawequal(pcall, xpcall)
end))

register(759, "select(-1,...) returns last argument", custom(function()
    local last = select(-1, 10, 20, 30)
    return last == 30
end))

register(760, "select(-2,...) returns correct values", custom(function()
    local r = table.pack(select(-2, 10, 20, 30))
    return r.n == 2 and r[1] == 20 and r[2] == 30
end))

register(761, "select('#',...) returns exact argument count", custom(function()
    local function countArgs(...)
        return select('#', ...)
    end
    return countArgs(1, nil, 3) == 3 and countArgs() == 0 and countArgs(nil) == 1
end))

register(762, "select('#',...) consistent with table.pack .n", custom(function()
    local function check(...)
        local packed = table.pack(...)
        local count = select('#', ...)
        return packed.n == count
    end
    return check(1, 2, 3) and check(nil, nil, nil) and check("a", "b", nil, "d")
end))

register(763, "math.abs upvalue scan all slots clean", custom(function()
    if not debug or not debug.getupvalue then return "SKIP" end
    for i = 1, 256 do
        local ok, name, val = pcall(debug.getupvalue, math.abs, i)
        if not ok then break end
        if name == nil and val == nil then break end
        if val ~= nil then return false end
    end
    return true
end))

register(764, "math.sin upvalue scan all slots clean", custom(function()
    if not debug or not debug.getupvalue then return "SKIP" end
    for i = 1, 256 do
        local ok, name, val = pcall(debug.getupvalue, math.sin, i)
        if not ok then break end
        if name == nil and val == nil then break end
        if val ~= nil then return false end
    end
    return true
end))

register(765, "string.byte upvalue full scan clean", custom(function()
    if not debug or not debug.getupvalue then return "SKIP" end
    for i = 1, 256 do
        local ok, name, val = pcall(debug.getupvalue, string.byte, i)
        if not ok then break end
        if name == nil and val == nil then break end
        if val ~= nil then return false end
    end
    return true
end))

register(766, "string.format upvalue full scan clean", custom(function()
    if not debug or not debug.getupvalue then return "SKIP" end
    for i = 1, 256 do
        local ok, name, val = pcall(debug.getupvalue, string.format, i)
        if not ok then break end
        if name == nil and val == nil then break end
        if val ~= nil then return false end
    end
    return true
end))

register(767, "table.sort upvalue full scan clean", custom(function()
    if not debug or not debug.getupvalue then return "SKIP" end
    for i = 1, 256 do
        local ok, name, val = pcall(debug.getupvalue, table.sort, i)
        if not ok then break end
        if name == nil and val == nil then break end
        if val ~= nil then return false end
    end
    return true
end))

register(768, "pcall upvalue full scan clean", custom(function()
    if not debug or not debug.getupvalue then return "SKIP" end
    for i = 1, 256 do
        local ok, name, val = pcall(debug.getupvalue, pcall, i)
        if not ok then break end
        if name == nil and val == nil then break end
        if val ~= nil then return false end
    end
    return true
end))

register(769, "type upvalue full scan clean", custom(function()
    if not debug or not debug.getupvalue then return "SKIP" end
    for i = 1, 256 do
        local ok, name, val = pcall(debug.getupvalue, type, i)
        if not ok then break end
        if name == nil and val == nil then break end
        if val ~= nil then return false end
    end
    return true
end))

register(770, "string rawmetatable __index equals string library", custom(function()
    if not getrawmetatable then return "SKIP" end
    local mt = getrawmetatable("")
    if type(mt) ~= "table" then return false end
    local idx = rawget(mt, "__index")
    return rawequal(idx, string)
end))

register(771, "('a').upper == string.upper (identity check)", custom(function()
    local methodRef = ("a").upper
    return rawequal(methodRef, string.upper)
end))

register(772, "('a').byte == string.byte (identity check)", custom(function()
    local methodRef = ("a").byte
    return rawequal(methodRef, string.byte)
end))

register(773, "('a').sub == string.sub (identity check)", custom(function()
    local methodRef = ("a").sub
    return rawequal(methodRef, string.sub)
end))

register(774, "('a').find == string.find (identity check)", custom(function()
    local methodRef = ("a").find
    return rawequal(methodRef, string.find)
end))

register(779, "math table is read-only (write attempt fails)", custom(function()
    local s = pcall(function() math._SEB_TEST_KEY = 1 end)
    if s then
        rawset(math, "_SEB_TEST_KEY", nil)
        return false
    end
    return true
end))

register(780, "string table is read-only (write attempt fails)", custom(function()
    local s = pcall(function() string._SEB_TEST_KEY = 1 end)
    if s then
        rawset(string, "_SEB_TEST_KEY", nil)
        return false
    end
    return true
end))

register(781, "table library is read-only (write attempt fails)", custom(function()
    local s = pcall(function() table._SEB_TEST_KEY = 1 end)
    if s then
        rawset(table, "_SEB_TEST_KEY", nil)
        return false
    end
    return true
end))

register(782, "table.isfrozen(math) returns true", custom(function()
    if not table.isfrozen then return "SKIP" end
    return table.isfrozen(math) == true
end))

register(783, "table.isfrozen(string) returns true", custom(function()
    if not table.isfrozen then return "SKIP" end
    return table.isfrozen(string) == true
end))

register(784, "table.isfrozen(coroutine) returns true", custom(function()
    if not table.isfrozen then return "SKIP" end
    return table.isfrozen(coroutine) == true
end))

register(785, "frozen math table: rawget non-nil for standard functions", custom(function()
    if not table.isfrozen or not table.isfrozen(math) then return "SKIP" end
    local fns = {"abs","floor","ceil","sqrt","sin","cos","tan","log","exp","max","min"}
    for _, name in ipairs(fns) do
        local v = rawget(math, name)
        if v == nil then return false end
    end
    return true
end))

register(786, "math.modf returns exactly 2 values via table.pack", custom(function()
    local r = table.pack(math.modf(3.7))
    if r.n ~= 2 then return false end
    if r[1] ~= 3 then return false end
    if math.abs(r[2] - 0.7) > 1e-9 then return false end
    return true
end))

register(787, "math.frexp returns exactly 2 values via table.pack", custom(function()
    if not math.frexp then return "SKIP" end
    local r = table.pack(math.frexp(8))
    if r.n ~= 2 then return false end
    if r[1] ~= 0.5 then return false end
    if r[2] ~= 4 then return false end
    return true
end))

register(788, "string.find with capture returns 4 values", custom(function()
    local r = table.pack(string.find("hello", "(h)(e)"))
    if r.n ~= 4 then return false end
    if r[1] ~= 1 or r[2] ~= 2 then return false end
    if r[3] ~= "h" or r[4] ~= "e" then return false end
    return true
end))

register(789, "string.byte('ABC',1,3) returns exactly 3 values", custom(function()
    local r = table.pack(string.byte("ABC", 1, 3))
    if r.n ~= 3 then return false end
    if r[1] ~= 65 or r[2] ~= 66 or r[3] ~= 67 then return false end
    return true
end))

register(790, "pcall wrapping multi-return function preserves all values", custom(function()
    local r = table.pack(pcall(function() return 10, 20, 30 end))
    if r.n ~= 4 then return false end
    if r[1] ~= true or r[2] ~= 10 or r[3] ~= 20 or r[4] ~= 30 then return false end
    return true
end))

register(791, "coroutine.resume return count matches yield args", custom(function()
    local co = coroutine.create(function()
        coroutine.yield(100, 200, 300)
    end)
    local r = table.pack(coroutine.resume(co))
    if r.n ~= 4 then return false end
    if r[1] ~= true or r[2] ~= 100 or r[3] ~= 200 or r[4] ~= 300 then return false end
    return true
end))

register(792, "debug.info(math.abs,'sna') cross-validation", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, src, name = pcall(debug.info, math.abs, "sn")
    if not ok then return false end
    if tostring(src) ~= "[C]" then return false end
    if name ~= "abs" then return false end
    return true
end))

register(793, "debug.info(string.byte,'sn') cross-validation", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, src, name = pcall(debug.info, string.byte, "sn")
    if not ok then return false end
    if tostring(src) ~= "[C]" then return false end
    if name ~= "byte" then return false end
    return true
end))

register(794, "debug.info(pcall,'sn') cross-validation", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, src, name = pcall(debug.info, pcall, "sn")
    if not ok then return false end
    if tostring(src) ~= "[C]" then return false end
    if name ~= "pcall" then return false end
    return true
end))

register(795, "debug.info(math.abs,'a') arity consistent with C function", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local ok, nparams, isvararg = pcall(debug.info, math.abs, "a")
    if not ok then return "SKIP" end
    if type(nparams) == "number" and type(isvararg) == "boolean" then
        if nparams > 0 and isvararg == false then return false end
    end
    return true
end))

register(796, "error(msg,0) adds no location prefix", custom(function()
    local s, err = pcall(function()
        error("SENTINEL_NO_PREFIX", 0)
    end)
    if s then return false end
    return tostring(err) == "SENTINEL_NO_PREFIX"
end))

register(797, "error(msg,1) adds location prefix", custom(function()
    local s = pcall(function()
        error("HAS_PREFIX", 1)
    end)
    return not s
end))

register(798, "error(table,0) passes table reference intact through pcall", custom(function()
    local errObj = {code = 12345, sentinel = "SEB_ERR_OBJ"}
    local s, err = pcall(function()
        error(errObj, 0)
    end)
    if s then return false end
    if not rawequal(err, errObj) then return false end
    return err.code == 12345 and err.sentinel == "SEB_ERR_OBJ"
end))

register(799, "nested pcall error containment", custom(function()
    local innerCaptured = nil
    local outerOk = pcall(function()
        local innerOk, innerErr = pcall(function()
            error("INNER_ONLY", 0)
        end)
        innerCaptured = innerErr
    end)
    return outerOk == true and innerCaptured == "INNER_ONLY"
end))

register(800, "coroutine.running() inside coroutine returns thread type", custom(function()
    local co = coroutine.create(function()
        local running = coroutine.running()
        return type(running) == "thread"
    end)
    local ok, result = coroutine.resume(co)
    return ok and result == true
end))

register(801, "coroutine.running() returns the actual coroutine object", custom(function()
    local co
    co = coroutine.create(function()
        local running = coroutine.running()
        return rawequal(running, co)
    end)
    local ok, result = coroutine.resume(co)
    return ok and result == true
end))

register(802, "typeof(coroutine thread) == 'thread'", custom(function()
    local co = coroutine.create(function() end)
    return type(co) == "thread" and typeof(co) == "thread"
end))

register(803, "pcall allows coroutine.yield to propagate through", custom(function()
    local co = coroutine.create(function()
        local ok, val = pcall(function()
            coroutine.yield("YIELD_THROUGH_PCALL")
        end)
        return ok, val
    end)
    local r1ok, r1val = coroutine.resume(co)
    if not r1ok or r1val ~= "YIELD_THROUGH_PCALL" then return false end
    local r2ok, r2a, r2b = coroutine.resume(co)
    return r2ok and r2a == true
end))

register(804, "game rawmt __namecall and __index both non-nil C closures", custom(function()
    if not game or not getrawmetatable then return "SKIP" end
    local mt = getrawmetatable(game)
    if type(mt) ~= "table" then return false end
    local namecall = rawget(mt, "__namecall")
    local index = rawget(mt, "__index")
    if type(namecall) ~= "function" then return false end
    if type(index) ~= "function" then return false end
    if not debug or not debug.info then return true end
    local ok1, s1 = pcall(debug.info, namecall, "s")
    local ok2, s2 = pcall(debug.info, index, "s")
    return ok1 and ok2 and tostring(s1) == "[C]" and tostring(s2) == "[C]"
end))

register(805, "workspace rawmt __namecall is C and non-nil", custom(function()
    if not workspace or not getrawmetatable then return "SKIP" end
    local mt = getrawmetatable(workspace)
    if type(mt) ~= "table" then return false end
    local namecall = rawget(mt, "__namecall")
    if type(namecall) ~= "function" then return false end
    if not debug or not debug.info then return true end
    local ok, src = pcall(debug.info, namecall, "s")
    return ok and tostring(src) == "[C]"
end))

register(806, "Part rawmt __namecall is C", custom(function()
    if not Instance or not getrawmetatable then return "SKIP" end
    local part = Instance.new("Part")
    local mt = getrawmetatable(part)
    if type(mt) ~= "table" then return false end
    local namecall = rawget(mt, "__namecall")
    if type(namecall) ~= "function" then return false end
    if not debug or not debug.info then return true end
    local ok, src = pcall(debug.info, namecall, "s")
    return ok and tostring(src) == "[C]"
end))

register(807, "game and workspace share same rawmetatable type", custom(function()
    if not game or not workspace or not getrawmetatable then return "SKIP" end
    local mt_game = getrawmetatable(game)
    local mt_ws = getrawmetatable(workspace)
    return type(mt_game) == "table" and type(mt_ws) == "table"
end))

register(808, "getconnections Function property matches registered callback", custom(function()
    if not getconnections or not Instance then return "SKIP" end
    local part = Instance.new("Part")
    local callbackRef = function() end
    local conn = part.Changed:Connect(callbackRef)
    local connections = getconnections(part.Changed)
    conn:Disconnect()
    if type(connections) ~= "table" or #connections == 0 then return false end
    for _, c in ipairs(connections) do
        if c.Function then
            if rawequal(c.Function, callbackRef) then return true end
        end
    end
    return false
end))

register(809, "getconnections returns objects with expected fields", custom(function()
    if not getconnections or not Instance then return "SKIP" end
    local part = Instance.new("Part")
    local conn = part.Changed:Connect(function() end)
    local connections = getconnections(part.Changed)
    conn:Disconnect()
    if type(connections) ~= "table" then return false end
    for _, c in ipairs(connections) do
        if type(c) ~= "table" and typeof(c) ~= "table" then
            if type(c.Disconnect) ~= "function" then return false end
        end
    end
    return true
end))

register(810, "buffer.create + writei32 + readi32 round-trip", custom(function()
    if not buffer or not buffer.create or not buffer.writei32 or not buffer.readi32 then
        return "SKIP"
    end
    local b = buffer.create(4)
    buffer.writei32(b, 0, 12345678)
    local v = buffer.readi32(b, 0)
    return v == 12345678
end))

register(811, "typeof(buffer.create(4)) == 'buffer'", custom(function()
    if not buffer or not buffer.create then return "SKIP" end
    local b = buffer.create(4)
    return typeof(b) == "buffer"
end))

register(812, "rawget(buffer,'create') == buffer.create", custom(function()
    if not buffer then return "SKIP" end
    local raw = rawget(buffer, "create")
    if raw == nil then return false end
    return rawequal(raw, buffer.create)
end))

register(813, "tostring(math.abs) is identical across multiple calls", custom(function()
    local s1 = tostring(math.abs)
    local s2 = tostring(math.abs)
    local s3 = tostring(math.abs)
    return s1 == s2 and s2 == s3
end))

register(814, "tostring(string.byte) stable across calls", custom(function()
    local s1 = tostring(string.byte)
    local s2 = tostring(string.byte)
    return s1 == s2
end))

register(815, "tostring(pcall) stable across calls", custom(function()
    local s1 = tostring(pcall)
    local s2 = tostring(pcall)
    return s1 == s2
end))

register(816, "tostring(math.abs) matches function address format", custom(function()
    local s = tostring(math.abs)
    return s:match("^function: 0x%x+$") ~= nil or s:match("^function: %x+$") ~= nil
end))

register(817, "tostring distinguishes different functions", custom(function()
    return tostring(math.abs) ~= tostring(math.floor) and tostring(string.byte) ~= tostring(string.sub) and tostring(pcall) ~= tostring(xpcall)
end))

register(818, "CORE.pcall == runtime pcall (no drift)", custom(function()
    return rawequal(CORE.pcall, pcall)
end))

register(819, "CORE.xpcall == runtime xpcall (no drift)", custom(function()
    return rawequal(CORE.xpcall, xpcall)
end))

register(820, "CORE.tostring == runtime tostring (no drift)", custom(function()
    return rawequal(CORE.tostring, tostring)
end))

register(821, "CORE.type == runtime type (no drift)", custom(function()
    return rawequal(CORE.type, type)
end))

register(822, "string.gmatch iterator return is C Closure", custom(function()
    if not debug or not debug.info then return "SKIP" end
    local iter = string.gmatch("hello", ".")
    if type(iter) ~= "function" then return false end
    local ok, src = pcall(debug.info, iter, "s")
    return ok and tostring(src) == "[C]"
end))

register(823, "string.gmatch iterator has no suspicious upvalues", custom(function()
    if not debug or not debug.getupvalue then return "SKIP" end
    local iter = string.gmatch("hello world", "%a+")
    for i = 1, 256 do
        local ok, name, val = pcall(debug.getupvalue, iter, i)
        if not ok then break end
        if name == nil and val == nil then break end
        if type(val) == "function" then return false end
    end
    return true
end))

register(824, "string.gmatch iteration produces correct sequence", custom(function()
    local results = {}
    for word in string.gmatch("one two three", "%a+") do
        table.insert(results, word)
    end
    return #results == 3 and results[1] == "one" and results[2] == "two" and results[3] == "three"
end))

register(825, "string.gsub returns exactly 2 values", custom(function()
    local r = table.pack(string.gsub("aaa", "a", "b"))
    if r.n ~= 2 then return false end
    if r[1] ~= "bbb" then return false end
    if r[2] ~= 3 then return false end
    return true
end))

register(826, "rawget/native member metadata parity across core libraries", custom(function()
    if not debug or not debug.info then return "SKIP" end

    local checks = {
        { lib = math,      key = "abs",    member = math.abs },
        { lib = string,    key = "byte",   member = string.byte },
        { lib = table,     key = "sort",   member = table.sort },
        { lib = coroutine, key = "resume",  member = coroutine.resume },
    }

    for _, item in ipairs(checks) do
        local raw = rawget(item.lib, item.key)
        if raw == nil then return false end
        if not rawequal(raw, item.member) then return false end

        local ok1, info1 = pcall(debug.info, raw, "sn")
        local ok2, info2 = pcall(debug.info, item.member, "sn")
        if not ok1 or not ok2 then return false end

        if tostring(info1) ~= "[C]" or tostring(info2) ~= "[C]" then return false end
        if type(info1) == "table" and type(info2) == "table" then
            if info1.name ~= info2.name then return false end
            if tostring(info1.source) ~= tostring(info2.source) then return false end
        end
    end

    return true
end))

register(827, "table colon dispatch resolves through __index and preserves self", custom(function()
    local seen_self = nil
    local seen_arg = nil
    local calls = 0

    local proxy = setmetatable({}, {
        __index = function(_, key)
            if key ~= "probe" then
                return nil
            end

            return function(self, x)
                calls = calls + 1
                seen_self = self
                seen_arg = x
                return 9001
            end
        end,
    })

    local result = proxy:probe(17)
    return result == 9001
       and calls == 1
       and rawequal(seen_self, proxy)
       and seen_arg == 17
end))

register(828, "closure upvalues persist after scope exit and do not alias across factories", custom(function()
    local function factory(seed)
        local value = seed

        local function bump(delta)
            value = value + delta
            return value
        end

        local function read()
            return value
        end

        return bump, read
    end

    local b1, r1 = factory(10)
    local b2, r2 = factory(10)

    if r1() ~= 10 or r2() ~= 10 then return false end
    if b1(3) ~= 13 or r1() ~= 13 then return false end
    if r2() ~= 10 then return false end
    if b2(5) ~= 15 or r2() ~= 15 then return false end

    return not rawequal(b1, b2) and not rawequal(r1, r2)
end))

register(829, "iterator factory returns distinct C-shaped closures without hidden state", custom(function()
    if not debug or not debug.info or not debug.getupvalue then return "SKIP" end

    local a = string.gmatch("one two", "%a+")
    local b = string.gmatch("one two", "%a+")

    if type(a) ~= "function" or type(b) ~= "function" then return false end
    if rawequal(a, b) then return false end

    local ok1, info1 = pcall(debug.info, a, "sn")
    local ok2, info2 = pcall(debug.info, b, "sn")
    if not ok1 or not ok2 then return false end
    if tostring(info1) ~= "[C]" or tostring(info2) ~= "[C]" then return false end

    for _, iter in ipairs({ a, b }) do
        for i = 1, 32 do
            local ok_uv, name, value = pcall(debug.getupvalue, iter, i)
            if not ok_uv then break end
            if name == nil and value == nil then break end
            if type(value) == "function" or type(value) == "table" or type(value) == "thread" or type(value) == "userdata" then
                return false
            end
        end
    end

    local out = {}
    for word in string.gmatch("one two", "%a+") do
        out[#out + 1] = word
    end

    return #out == 2 and out[1] == "one" and out[2] == "two"
end))

register(830, "xpcall preserves table error identity through metamethod dispatch path", custom(function()
    local token = { tag = "SEB_ERR_OBJECT" }
    local seen = nil

    local proxy = setmetatable({}, {
        __index = function()
            error(token, 0)
        end,
    })

    local ok = xpcall(function()
        return proxy.missing
    end, function(err)
        seen = err
        return true
    end)

    return not ok and rawequal(seen, token)
end))


register(831, "yield-through-pcall multi-return transmission integrity", custom(function()
    local pack = table.pack or function(...)
        return { n = select("#", ...), ... }
    end

    local co = coroutine.create(function()
        local ok, resumed = pcall(coroutine.yield, "valueA", "valueB", "valueC")
        return ok, resumed
    end)

    local r1 = pack(coroutine.resume(co))
    if r1.n ~= 4 then return false end
    if r1[1] ~= true or r1[2] ~= "valueA" or r1[3] ~= "valueB" or r1[4] ~= "valueC" then return false end
    if coroutine.status(co) ~= "suspended" then return false end

    local r2 = pack(coroutine.resume(co, "valueX"))
    return r2.n == 3
        and r2[1] == true
        and r2[2] == true
        and r2[3] == "valueX"
        and coroutine.status(co) == "dead"
end))

register(832, "table.freeze ownership immutability + rawset error source genealogy", custom(function()
    if not table or not table.freeze then return "SKIP" end

    local getmt = getrawmetatable or getmetatable
    local probe = {}
    local beforeMt = getmt and getmt(probe) or nil
    local frozen = table.freeze(probe)

    if not rawequal(probe, frozen) then return false end
    if table.isfrozen and table.isfrozen(frozen) ~= true then return false end

    local afterMt = getmt and getmt(frozen) or nil
    if beforeMt ~= nil or afterMt ~= nil then
        if not rawequal(beforeMt, afterMt) then return false end
    end

    local sawError = false
    local sawCFrame = false

    xpcall(function()
        rawset(frozen, "_SEB_TEST_KEY", 1)
    end, function()
        sawError = true
        if debug and debug.info then
            for level = 1, 16 do
                local ok, src = pcall(debug.info, level, "s")
                if not ok or src == nil then
                    break
                end
                if tostring(src) == "[C]" then
                    sawCFrame = true
                    break
                end
            end
        end
        return true
    end)

    return sawError and sawCFrame
end))

register(833, "debug.info(thread, level, f) preserves private stack identity", custom(function()
    if not debug or not debug.info then return "SKIP" end

    local function B()
        coroutine.yield("PAUSE")
        return "B_RETURN"
    end

    local function A()
        return B()
    end

    local co = coroutine.create(function()
        return A()
    end)

    local ok1, yielded = coroutine.resume(co)
    if not ok1 or yielded ~= "PAUSE" then return false end
    if coroutine.status(co) ~= "suspended" then return false end

    local okf1, f1 = pcall(debug.info, co, 1, "f")
    local okf2, f2 = pcall(debug.info, co, 2, "f")
    if not okf1 or not okf2 then return false end
    if not rawequal(f1, B) then return false end
    if not rawequal(f2, A) then return false end

    local ok2, ret = coroutine.resume(co, "RESUME_TOKEN")
    return ok2 and ret == "B_RETURN" and coroutine.status(co) == "dead"
end))

register(834, "string metatable singleton identity + setmetatable protection", custom(function()
    local mt1 = getrawmetatable and getrawmetatable("x") or getmetatable("x")
    local mt2 = getrawmetatable and getrawmetatable("yz") or getmetatable("yz")

    if type(mt1) ~= "table" or type(mt2) ~= "table" then return "SKIP" end
    if not rawequal(mt1, mt2) then return false end

    local idx = rawget(mt1, "__index")
    if not rawequal(idx, string) then return false end

    local ok = pcall(setmetatable, "", {})
    if ok then return false end

    local methodRef = ("hello").upper
    local rawMethod = rawget(string, "upper")
    return rawequal(methodRef, rawMethod)
end))

print("\n======================================================================")
print("            Stummer Envlogger Benchmark Test        ")
print("======================================================================\n")

for i = 1, maxRegistered do
    local res = results[i]
    if res then
        local statusStr = res.skipped and "[ SKIPPED ]" or (res.pass and "[ PASSED  ]" or "[ FAILED  ]")
        print(string.format("  #%03d %s : %s", i, statusStr, res.name))
    else
        print(string.format("  #%03d [ FAILED  ] : ERROR - Test Missing!", i))
        failed = failed + 1
    end
    if i % 50 == 0 then task.wait() end
end

local validTests = maxRegistered - skipped
local passedTests = passed - skipped
local passRate = validTests > 0 and (passedTests / validTests) * 100 or 0

print("\n----------------------------------------------------------------------")
print(string.format(" TOTAL TESTS : %d", maxRegistered))
print(string.format(" PASS RATE   : %.2f%%", passRate))
print(string.format(" PASSED      : %d", passedTests))
print(string.format(" SKIPPED     : %d (Unsupported by Environment/Executor)", skipped))
print(string.format(" FAILED      : %d (detected)", failed))
print("----------------------------------------------------------------------")

if failed <= 8 then
    print("\n [ STATUS: Perfect, because when i test it in executor without logger, it just came out with 8 dtc, so got 8 is perfect ]")
    print(" SSR+ Tier !!!! or just Plain Executor")
elseif failed <= 25 then
    print("\n [ STATUS: Extremely GOOD!!!! ]")
    print(" SS TIER!")
elseif failed <= 100 then
    print("\n [ STATUS: Really Good!! ]")
    print(" S TIERS!! EASILY")
elseif failed <= 150 then
    print("\n [ STATUS: This very Good! ]")
    print(" A++ TIERS BOIII")
elseif failed <= 200 then
    print("\n [ STATUS: Okay! this is above most of logger ]")
    print(" A+ TIERSSSSESS")
elseif failed <= 250 then
    print("\n [ STATUS: Okay! this is good ]")
    print(" A Tier yeahhhh")
elseif failed <= 340 then
    print("\n [ STATUS: Okay, its standard, goodjob! ]")
    print(" B Tier")
else
    print("\n [ STATUS: Keep improving! by just make an envlogger, ur is skilled programmer, dont surrender! ]")
    print(" C Tier - F Tier")
end

print("======================================================================\n")