print(25,"starting the dummppP!!! Made by 69ms, join discord.gg/69ms",25)
local original_globals=getfenv()
local clock=os.clock
local startt=clock()
local commercial=false
local inpath=commercial and "" or "dumps\\original\\"
local outpath=commercial and "" or "dumps\\dumped\\"
local insert=table.insert
local fs = fs or require("@lune/fs")
local process = process or require("@lune/process")
local luau = luau or require("@lune/luau")
local roblox=not commercial and require("@lune/roblox") or {}
local task=require("@lune/task")
local targetfilename=process.args[1]
if not targetfilename then
    print("lol you didnt put a filename or luarmor link")
    return
end
local LRMPath=targetfilename:find("https://api.luarmor.net/files/v3/") and targetfilename:gsub("https://api.luarmor.net/files/v3/loaders/",""):gsub("https://api.luarmor.net/files/v3/l/","")
if not (LRMPath or fs.isFile(inpath..targetfilename)) then
    print("lol that file doesnt exist")
    return
end
local request=(net or require("@lune/net")).request
local input = LRMPath and (function()
    local cont=request({url=targetfilename:gsub("loaders","l"),method ="GET",headers={["User-Agent"]="Xeno/RobloxApp/V1.0.9"}}).body
    targetfilename=LRMPath
    fs.writeFile(inpath..LRMPath,cont)
    return cont
end)()
or fs.readFile(inpath..targetfilename)
local oldtype=type
local tbl_to_s,tostring_complex,type
function tbl_to_s(tbl, indent)
    indent = indent or 0
    local to_string = function(value)
        if type(value) == "table" then
            return tbl_to_s(value, indent + 2)
        elseif type(value) == "string" then
            return string.format("%q", value)
        else
            return tostring_complex(value)
        end
    end

    local result = "{\n"
    local spacing = string.rep(" ", indent + 2)
    for k, v in pairs(tbl) do
        local key = "[" .. tostring_complex(k) .. "]"
        result = result .. spacing .. key .. " = " .. to_string(v) .. ",\n"
    end
    result = result .. string.rep(" ", indent) .. "}"
    return result
end

local _69msrobloxenv,_tbl=not commercial and require("./fakegame") or {}
local _pcall=pcall
-- if not input:find(expression) then
--     print("couldnt find anything to modify")
--     return
-- end
local runcode = input
-- if runcode==input then
--     warn("regex bad :(")
-- end

local chunk, err = luau.load(runcode)
if err then
    warn("BAD OMGG"..err)
    return
end
local function debug_getinfo(func_or_level)
    local info = {}
    local function getinfo_opt(opt, name)
        local value = debug.info(func_or_level, opt)
        if value ~= nil then
            info[name] = value
        end
    end

    getinfo_opt("l", "linedefined")      -- Line defined
    getinfo_opt("f", "func")              -- Function reference
    -- getinfo_opt("u", "nups")             -- Number of upvalues
    -- getinfo_opt("c", "currentline")      -- Current line
    -- getinfo_opt("p", "nparams")          -- Number of parameters
    -- getinfo_opt("t", "ntransfer")        -- Number of transfer values
    -- getinfo_opt("v", "isvararg")         -- Is variadic
    getinfo_opt("s", "source")           -- Source
    getinfo_opt("n", "namewhat")         -- Name category
    getinfo_opt("l", "istailcall")       -- Is tail call
    getinfo_opt("s", "short_src")        -- Short source
    info.what=info.short_src:gsub("%[(.+)%]","%1")
    -- getinfo_opt("x", "ftransfer")        -- First transfer
    -- getinfo_opt("L", "lastlinedefined")  -- Last line defined
    -- print(info)
    return info
end
local r={}
local c=0
local genv={}
local cenv = {}
for i,v in _69msrobloxenv do
    cenv[i] = v
end
for i,v in roblox do
    cenv[i] = v
end
-- local _game=not commercial and roblox.deserializePlace(fs.readFile("Baseplate.rbxl")) or {}
local whitelistedUrls={
    "https://pastebin.com/",
    "https://raw.githubusercontent.com/",
    "https://gist.githubusercontent.com/",
}
local tablefuncmt=setmetatable({},{
    index=function()return function()return _tbl end end})
local services={
    -- RunService=tablefuncmt,
    HttpService=setmetatable({},{
        __index=function(_,key)
            return function(...)
                print(key,"->",...)
                return setmetatable({},{
                    __index=function(_,key)
                        print("index",key)
                        return function (_,func)
                            print(debug_getinfo(func))
                        end
                    end
                })
            end
        end
    })
}

local getglobalfuncname=function(func)
    -- not implemented, LOL!
end
type=function(var)
    local t=oldtype(var)
    return t=="table" and getmetatable(var) and getmetatable(var).__type or t
end 

function tostring_complex(var)
    print(var,type(var))
    if type(var)=="table"then
        return tbl_to_s(var)
    elseif type(var)=="string" then
        return string.format("%q", tostring(var))
    elseif type(var)=="function" then
        local info=debug_getinfo(var)
        local name=info.namewhat~="" and info.namewhat or getglobalfuncname(var) or "~anonymous"
        return "<function n="..name..">"
    elseif type(var)=="context_type" then
        return var.__69mslocation
    else
        return tostring(var)
    end
end


local stringify=function(...)
    local data={...}
    local stringified={}
    for _,v in data do
        insert(stringified,tostring_complex(v))
    end
    return table.concat(stringified,", ")
end
local parentstringify=function(parent,...)
    local data={...}
    local stringified={}
    for i,v in data do
        if v==parent then
            insert(stringified,"self")
        else
            insert(stringified,tostring_complex(v))
        end
    end
    return table.concat(stringified,", ")
end

local function simplelog(source,...)
    print(source,...)
    local callargs=stringify(...)
    insert(r,"["..source.."]:"..callargs)
end
local function complexlog(source,options,...)
    print(source,options,...)
    if options.type=="newindex" then
        local key,value=...
        insert(r,"<ASSIGN>"..source.."."..key.." = "..stringify(value))
    elseif options.parent then
        local callargs=options.parent and parentstringify(options.parent,...) or stringify(...)
        insert(r,"["..source.."]:"..callargs)
    end
end
local spytbl
spytbl=function(pre,parent)
    local lowerpre=pre:lower()
    return setmetatable({
        __69mslocation=pre,
    },{
        __index=function(_,key)
            return spytbl(pre.."."..key,_)
        end,
        __newindex=function(_,key,value)
            complexlog(pre,{
                type="newindex",
            },key,value)
        end,
        __call=function(_,...)
            if parent then
                complexlog(pre,{parent=parent},...)
            else
                simplelog(pre,...)
            end
            local meowstr=(parent and parentstringify(...) or stringify(...))
            if #meowstr>15 then
                meowstr="..."
            end
            return spytbl(pre.."("..meowstr..")",_)
        end,
        __concat=function(_,other)
            return tostring(_)..tostring(other)
        end,
        __tostring=function()
            return pre
        end,
        __type=lowerpre:find("id") and "number" or lowerpre:find("name") or lowerpre:find"GUID" and "string" or "context_type",
    })
end
cenv.game=setmetatable({
    HttpGet=function(_,Url)
        simplelog("game:HttpGet",Url)
        for _,v in whitelistedUrls do
            if Url:sub(1,#v) == v then
                print("returning real")
                return request{url=Url,method="GET"}.body
            end
        end
        return spytbl("game:HttpGet("..tostring_complex(Url)..")")
    end,
    HttpGetAsync=function(_,Url)
        simplelog("game:HttpGetAsync",Url)
        for _,v in whitelistedUrls do
            if Url:sub(1,#v) == v then
                print("returning real")
                return request{url=Url,method="GET"}.body
            end
        end
        return spytbl("game:HttpGetAsync("..tostring_complex(Url)..")")
    end,
    IsLoaded=function()return true end,
    -- GetService=function(_,service)
    --     return spytbl("game.GetService("..service..")")
    -- end,
},{
    __index=function(_,key)
        return spytbl("game."..key,cenv.game)
    end
})

for _,name in {"Instance","Drawing","UDim","CFrame"} do
    cenv[name]=spytbl(name)
end
for _,func_name in {"request","http_request","httpRequest","HttpRequest","http.request"} do
    local requestfunc=function(cont)
        insert(r,"["..func_name.."]:"..tbl_to_s(cont))
        for _,v in whitelistedUrls do
            if cont.Url:sub(1,#v) == v then
                print("returning real")
                return request{url=cont.Url,method=cont.Method,body=cont.Body,headers=cont.Headers}.body
            end
        end
        return [[_LOL_Replace_69ms_]]
    end
    if func_name:find(".",1,true) then
        local splits=func_name:split(".")
        cenv[splits[1]]={}
        cenv[splits[1]][splits[2]]=requestfunc
    else
        cenv[func_name]=requestfunc
    end
end
local print=print
local enumspytbl
enumspytbl=function(pre)
    return setmetatable({},{
        __index=function(_,key)
            return enumspytbl(pre.."."..key)
        end,
        __type="string",
        __tostring=function()
            return "<Enum: "..pre..">"
        end
    })
end
cenv.Enum=enumspytbl("Enum")
-- cenv._69ms=function(var)
--     local vartype=type(var)
--     if vartype=="string" then
--         local wow="["..vartype.."]:"..var
--         if not r[c] or r[c]~=wow:sub(1,#wow-1) then
--             c=c+1
--         end
--         print(wow)
--         r[c]=wow
--     end
--     return var
-- end
cenv.pcall=pcall,function(...)
    local res={_pcall(...)}
    if res[1] == false then
        res[2] = tostring(res[2])
    end
    return unpack(res)
end
cenv.ishooked=function()return false end
cenv.wait=function()return 1 end
local loadstringcount=0
cenv.loadstring=function(src,b)
    if type(src)=="string" then
        simplelog("loadstring["..loadstringcount.."]",#src<10 and src or "<69ms: long_string>")
        local _func=luau.load(src,b)
        setfenv(_func,cenv)
        return _func
    elseif type(src)=="context_type" then
        simplelog("loadstring["..loadstringcount.."]",src)
        return function(...)
            if ... then simplelog("loadstring[<CALL_WITH_ARGS:"..loadstringcount..">]",...) end
            return spytbl("loadstring["..loadstringcount.."]")
        end
    end
end
cenv.ce_like_loadstring_fn=cenv.loadstring
cenv.script_key="c4ce76cd36f2afee4dcee7e87576e5fa"
cenv.getgenv=function()
    -- return genv
    return setmetatable({},{__index=genv,__newindex=function(_,k,v)
        insert(r,"genv["..stringify(k).."]="..stringify(v))
    end})
end
cenv._G=setmetatable({},{__index=genv,__newindex=function(_,k,v)
    insert(r,"_G["..stringify(k).."]="..stringify(v))
end})
-- cenv.print=function()end
cenv.print=spytbl("print")
cenv.warn=function()end
cenv.task=setmetatable({wait=function()return 1 end},{__index=task})
cenv.spawn=task.spawn
local fake_file_system={}
cenv.writefile=function(path,cont)
    fake_file_system[path]=cont
end
cenv.readfile=function(path)
    return fake_file_system[path]
end
cenv.isfile=function(path)
    return fake_file_system[path]~=nil
end
cenv.isfolder=function(path)
    return fake_file_system[path]~=nil
end
cenv.mkdir=function(path)
    fake_file_system[path]={}
end
for i,v in cenv do
    genv[i] = v
end
cenv.setclipbard=function()end
cenv.toclipboard=function()end
cenv.assert=function()end
cenv._69mssigma=function(...) if ...=="meow :3" then error("Controlled shutdown") end end
cenv.getfenv=function(lvl)
    if lvl then
        local res=getfenv(lvl)
        if res.require~=cenv.require then
            return cenv
        end
        return res
    end
    return cenv
end
local env=getfenv(chunk)
env.require=function()end
local logged_undefined_fenv={}
setfenv(chunk,setmetatable(cenv,{__index=function(_,key)
    if key=="printuiwarn" then error()end
    if not env[key] and not logged_undefined_fenv[key] then
        logged_undefined_fenv[key]=true
        simplelog("fenvRead",key)
        -- return genv[key] --or spytbl("fenv."..key)
    end
    return env[key]
end,__newindex=function(_,k,v)
    insert(r,"fenv["..tostring_complex(k).."]="..tostring_complex(v))
    env[k]=v
end
}))
local success, er = _pcall(chunk)
if not success then
    simplelog("error",er)
else
    simplelog("return",er)
end
print(success,er)

local post=commercial and "_dump.lua" or ".lua"
local result=table.concat(r,"\n")
fs.writeFile(outpath..targetfilename:gsub(".lua","")..post,table.concat(r,"\n"))
local endt=clock()-startt
print("success in",endt,"seconds!\nWritten to "..outpath..targetfilename:gsub(".lua","")..post)
print(result)
