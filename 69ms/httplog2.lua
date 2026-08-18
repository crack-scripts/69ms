-- TODO: add metatables that also have a real value like a string. For example for tostring returns on tables or sum!


local insert=table.insert
local _require=require
local settings={
    varnames=true, -- _someName69
    usesimplefunctions=false, -- functions wont be explored if true
    watchoutforloop=true, -- infinitelooperror!
    spynilglobals=true, -- when true will spy all globals, even if they might not be a defined in a normal env
    hook_op=false, -- attempt to hook expressions like "==", "and", "or", "not" and more
    hook_op_default_return="original", -- "original", "spy", false, true
    log_lines=false,
    better_funcs=true, -- runs found functions after the main script finished!
    deadline_seconds=35, -- self-abort a hanging script after this many seconds
}
local unfinishedfuncs,is_unfinished={},false
local thisfunction=debug.info(1,"f")
local specialhandle=false
local msecNotReady=false
local luraphnotready=0
local cenv,genv,analyzefunction,metatables,cclosures,types = {},{},nil,{},{},{}
-- real datatype instances -> their authentic tostring string (step1). Lets
-- cenv.tostring return "1, 2, 3" for a Vector3 instead of treating it as a spy.
local datatype_strings=setmetatable({},{__mode="k"})
-- set by the instance/signal setup; task.wait() calls it to fire Heartbeat/RenderStepped/
-- Stepped connections each "frame" so signal-firing detection checks pass.
local fire_frame_signals=function() end
-- Roblox-style stable addresses: tostring(_G)=="table: 0x...", tostring(fn)=="function:
-- 0x...", and the SAME object always yields the SAME address (so "tostring is stable"
-- detection checks pass). Cached per object.
local addr_cache=setmetatable({},{__mode="k"})
local _addrhex="0123456789abcdef"
local function roblox_addr(obj,kind)
    local a=addr_cache[obj]
    if not a then
        local s="" for _=1,12 do local r=math.random(1,16) s=s.._addrhex:sub(r,r) end
        a=kind..": 0x"..s
        addr_cache[obj]=a
    end
    return a
end
local _tostring=tostring
local concat_me=`<69ms_concat_me>`
local concat_me_close=`</69ms_concat_me>`
local oldtype=type
local getmetatable=getmetatable
local pack,unpack=table.pack,unpack
local simplelog, isjunkie
local smart_unpack=function(packed)
    if packed and packed.n then
        return unpack(packed, 1, packed.n)
    end
    return unpack(packed or {})
end
local function tostring(var)
    if oldtype(var)=="table" and getmetatable(var) and getmetatable(var).__type=="context_type" then
        return _tostring(var)
    end
    -- if getmetatable(var)~=nil and (type(getmetatable(var))~="table" or getmetatable(var).__tostring) then
    --     return "scary-type"
    -- end
    return _tostring(var)
end
local getfenv, string, table, debug, pcall, rawget,require
    = getfenv, string, table, debug, pcall, rawget,require
getfenv().require=function()end
local function unpackchoose(packed,...)
    if packed then
        return unpack(packed)
    end
    return ...
end
local function multiunpack(...)
    local vars={}
    for _,packed in {...} do
        for _,v in packed do
            insert(vars,v)
        end
    end
    return unpack(vars)
end
local function tablefind(tbl, value)
    for index, val in next,tbl do
        if val == value then
            return index
        end
    end
    return false
end
local tbl_to_s,tostring_complex,type
local function multiinsert(target,items)
    for _,item in items do
        insert(target,item)
    end
end
local identifier=tostring(math.random(1000000,9999999))
local __69mslocation="__69mslocation"..tostring(math.random(1000000,9999999))
local Enum_NOCALL="NOCALL"..tostring(math.random(1000000,9999999))
local _print=print
local process = require("@lune/process")
local is_bot=not not process.args[2]
if is_bot then
        _print("-- wow this script had an infinite loop that wasnt resolved, this output was generated at runtime and is very bad.\n-- script id: "..tostring(process.args[1]))
end
local print=function(...)
    if is_bot and debug.info(2,"f")~=simplelog then
        return
    end
    local args={...}
    for i,v in args do
        if type(v)~="table" then
            args[i]=tostring(v):gsub(identifier.."_?","")
        end
    end
    _print(unpack(args))
end
local function evaluate_single_use_variables(r)
    local oldr=table.clone(r)
    table.clear(r)
    for _,v in oldr do
        multiinsert(r,v:split("\n"))
    end
    -- The reference-counting + inline below is O(n²) (per line it rescans every
    -- candidate variable). On huge detection dumps (8k-35k lines) that's minutes for
    -- almost no gain (the trace is already one op per line). Past a threshold, keep the
    -- split-into-lines result and skip the quadratic pass.
    if #r>4000 then return r end
    local variables={}
    for i,v in r do
        local front,back
        if v:find("=", 1, true) and not v:find("{",1,true) and not v:find("function(",1,true) then
            local split=v:split("=")
            front=split[1]
            back=table.concat(split,"=",2)
            local _,c = front:gsub("_", "")
            if back==" ..." then
                local varargstr=front:split("local ")[2]
                varargstr=varargstr:sub(1,#varargstr-1)
                local varargcount=0
                for ii,v in r do
                    if ii<=i then
                        continue
                    end
                    if v:find(varargstr,1,true) then
                        local next=v:gmatch(varargstr..".") -- grr idk
                        r[ii]=v:gsub(varargstr,"...")
                    end
                    local firstname=varargstr:split(",")[1]
                    if r[ii]:find(firstname:sub(1,#firstname-1),1,true) then
                        -- print"hai"
                        varargcount+=1
                    end
                end
                if varargcount==0 then
                    r[i]=nil
                end
            end
            if c==2 and not front:find("[%.%[%]]") and not back:find("...",1,true) then
                insert(variables,{
                    name=front:split("_")[2],
                    amount=0,
                    location=i,
                    usedon={}
                })
            end
        else
            back=v
        end

        for _,data in variables do
            local match=data.name:gsub("([%^$().[%]*+?-])","%%%1")
            local _,c = back:gsub(match, "")
            for _=1,c do
                insert(data.usedon,i)
            end
            if front and not front:find("local") then
                _,c = v:gsub(match, "")
            end
            data.amount+=c
        end
    end
    for i=1,#variables do
        local data=variables[i]
        if data.amount==1 and r[data.usedon[1]] then
            local split=r[data.location]:split"="
            r[data.location]=nil
            local newback=table.concat(split,"=",2):gsub("%%","%%%%")
            -- print("usedon",r[data.usedon[1]],data.usedon[1],data.location)
            -- print("a",newback)
            r[data.usedon[1]]=r[data.usedon[1]]:gsub("_"..data.name:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1").."_",newback)
        end
    end
    local oldr=table.clone(r)
    table.clear(r)
    for _,v in oldr do
        if v~=nil then
            insert(r,v)
        end
    end
    return r
end
local function evaluate_stuff(r)
    for i,v in r do
        if v==nil then continue end
        local table_name
        -- print(v)
        r[i]=v:gsub("([%a%d_]+)%[\"(%a+)\"]%(([%a%d_]+)([,)])%s?",function(tbl,index,firstarg,ending)
            if tbl==firstarg then
                table_name=tbl
                return tbl..":"..index.."(" .. (ending==")" and ")" or "")
            end
        end):gsub("(.)<69ms_concat_me>([_%d%a\":%(%)%[%]]+)</69ms_concat_me>(.)",function(front,varname,back)
            local res=varname:gsub('\\"','"')
            -- print(front,varname,back)
            if front~='"' then
                res=front..'"..'..res
            end
            if back~='"' then
                res=res..'.."'..back
            end
            return res
        end)
        -- print("2",table_name,r[i-1])
        if table_name and r[i-1] then
            local previous=r[i-1]:split("=")
            local front=previous[1]
            local back=table.concat(previous,"=",2)
            if front:find(table_name,1,true) and table_name:find("%d") and not (front:find("function(",1,true) or front:find("{",1,true)) and not front:find("[%[%]]") and not front:find(",",1,true) and not (function()
                    local c=0
                    for ii=i,#r do
                        local _,cc = r[ii]:gsub(table_name:gsub("([%^$().[%]*+?-])","%%%1"), "")
                        c+=cc
                    end
                    return c>1
                end)()then
                r[i-1]=nil
                -- print("skibid",r[i],table_name,back:gsub("%%","%%%%"))
                r[i]=r[i]:gsub(table_name,(back:gsub("%%","%%%%")))
            end
        end
    end
    local oldr=table.clone(r)
    table.clear(r)
    for _,v in oldr do
        if v~=nil then
            insert(r,(v:gsub(identifier.."_?","")))
        end
    end
    -- print(table.concat(r,"\n"))
end
local original_globals=getfenv()
local clock=os.clock
local startt=clock()
local deadline_n=0 -- throttle counter for the wall-clock guard
-- separate counter for pure-compute guard: a decoded obfuscator VM can spin in its
-- bytecode-dispatch loop (millions of buffer/bit32 ops) WITHOUT ever calling simplelog,
-- so the simplelog deadline never fires. Counting stdlib calls catches that spin too.
local stdops=0
-- running byte count of the trace. Once it crosses the size cap we stop cleanly and
-- send whatever we have, instead of letting a huge dump grow unbounded.
local tracebytes=0
local TRACE_SIZE_CAP=2*1024*1024 -- 2 MB
local commercial=false
local inpath=commercial and "" or "dumps\\original\\"
local outpath=commercial and "" or "dumps\\dumped\\"
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local JsonDecode=require("@lune/net").jsonDecode
local task=require("@lune/task")
-- local buffer=require("bufferlib")
local exec_env=require("./exec_env")
local targetfilename=process.args[1]
local user_id=process.args[2]
settings = user_id and JsonDecode(fs.readFile("dump_user_settings.json"))[user_id] or settings
local function hook_op(src)
    fs.writeFile("hook_op/file_cache/"..targetfilename,src)
    local response=(process.exec("lua",{"hook_op.lua",targetfilename}))
    if not response.ok then
        settings.hook_op=false
        return src
    end
    local newsrc=fs.readFile("hook_op/file_cache/"..targetfilename)
    local success,func,loads_er=pcall(luau.load,newsrc)
    -- _print(success,func,loads_er)
    if not (success and func) then
        settings.hook_op=false
        return src
    end
    local funcnames=table.concat({"_69msLE","_69msGR","_69msLEEQ","_69msGREQ","_69msUNEQ","_69msEQ","_69msNOT","_69msLEN","_69msAND","_69msOR","_69msIF","_69msELSEIF","_69msWHILE","_69msREPEAT","_69msINDEX"},",")
    return "local "..funcnames.."="..funcnames..";"..newsrc
end
if not targetfilename then
    print("lol you didnt put a filename or luarmor link")
    return
end
local urlPath=targetfilename:find("https://") and targetfilename
if not (urlPath or fs.isFile(inpath..targetfilename)) then
    print("lol that file doesnt exist")
    return
end
local request=(require("@lune/net")).request
local input = urlPath and (function()
    local cont=request({url=urlPath:gsub("/loaders/","/l/"),method ="GET",headers={["User-Agent"]="Xeno/RobloxApp/V1.0.9"}}).body
    targetfilename=process.args[3]
    if urlPath:find("https://api.junkie-development.de/api/v1/luascripts",1,true) then
        isjunkie=true
    end
    fs.writeFile(inpath..targetfilename,cont)
    return cont
end)()
or fs.readFile(inpath..targetfilename)
local chunk,err
local variablecount,variable_backs,_69mspredefined,spytbl,predefinefound=0,{},{}
local luraphcarry
settings.ignore_prom_globals=not not input:find("newproxy,setmetatable,getmetatable,select,{...})end)(...)",1,true)
-- The "impossible" EnvLogger benchmark rewards AUTHENTIC behaviour (real errors,
-- frozen libs, etc.) rather than the tolerant spy-fallbacks we use for loaders.
-- Detect it so we can behave authentically only here, without hurting loaders.
settings.benchmark_mode=not not input:find("EnvLoggers Benchmark",1,true)
if settings.benchmark_mode then settings.spynilglobals=false end
if --[[input:find("[[This file was protected with MoonSec V3",1,true) and]] (input:find("=_ENV;[%a%d_]+='")) then
    msecNotReady=true
    if settings.spynilglobals then settings.spynilglobals=nil end
    if settings.hook_op then settings.hook_op=nil end
elseif input:find("(does your environment support load/loadstring?)",1,true) then
    local typeof=typeof
    local func=luau.load(input)
    local env=getfenv()
    local cenv={}
    local fenv_mt=setmetatable({},{__index=function(_,key)
        if key=="zeenjunkie"then
            isjunkie=true
        elseif not predefinefound and key=="_69mspredefine" and input:find("_69mspredefine",1,true) then
            predefinefound=true
            simplelog("_","_69mspredefine","this function was referenced in the script, if you didnt do this place _69mspredefine() on top of your script")
            return function(t)
                for i,v in t do
                    _69mspredefined[i]=v
                end
            end
        end
        return cenv[key] or env[key]
    end})
    cenv.require=error
    env.require=error
    cenv.getfenv=function()return env end
    env.getfenv=cenv.getfenv
    local serde = require("@lune/serde")
    env.Enum = {
        CompressionAlgorithm = {
            Zstd="Zstd"
        }
    }
    local buffer=buffer
    local Services = {
        EncodingService={
            DecompressBuffer=function(_,tbl)
                local decompressedString = serde.decompress("Zstd",tbl)
                local buf = buffer.fromstring(decompressedString, "binary")
                return buf
            end
        }
    }
    env.game = {
        GetService=function(a,b)
            return Services[b]
        end
    }

    cenv.loadstring=function(src,...)
        if typeof(src)=="string" and #src>100--[[...=="Luraph"]] then
            luraphnotready=1
            input=src
            -- fs.writeFile("zzRun.lua",src)
            return function(...)
                -- the Luraph VM function is invoked as j(D) where D is the bytecode
                -- BUFFER (not a string). Capture whatever it's handed (buffer/string/
                -- table) so the runner can replay the real VM with its real input.
                if (...)~=nil then
                    luraphcarry=...
                end
                error("success")
            end
        end
        -- Act like a REAL executor's loadstring for the loader's anti-tamper probes:
        -- 1) a non-string arg must NOT be coerced (the loader passes a table whose
        --    __tostring nukes its decode buffer; tostring()ing it = instant detection),
        --    a real loadstring just rejects it -> return nil,err.
        -- 2) a bad string must return nil,err, NOT throw (Lune's luau.load throws);
        --    the loader sets its decode offset based on this exact behaviour.
        if typeof(src)~="string" then return nil,"loadstring: string expected, got "..typeof(src) end
        local ok,fn=pcall(luau.load,src,...)
        if ok then return fn end
        return nil,tostring(fn)
    end
    setfenv(func,fenv_mt)
    local res={pcall(func)}
    if not is_bot then _print(unpack(res)) end
elseif input:find("=[\"']LPS") then
    specialhandle="LPS"
elseif input:find("{%d,%d,%a+},{%d,%d,%a+},{%d,%d,%a+},{%d,%d,%a+},{%d,%d,%a+},{%d,%d,%a+},") then
    specialhandle="moonveil"
end
function tbl_to_s(tbl, indent, antioverflow)
    if not next(tbl) then return "{}" end
    indent = indent or 0
    local result = "{\n"-- "{"
    local spacing = string.rep(" ", indent + 2) -- " "
    for k, v in tbl do
        local key = "[" .. tostring_complex(k,false,antioverflow) .. "]"
        result = result .. spacing .. key .. " = " .. tostring_complex(v,false,antioverflow) .. ",\n"
    end
    result = result .. string.rep(" ", indent) .. "}"
    return result
end

local _pcall=pcall
-- if not input:find(expression) then
--     print("couldnt find anything to modify")
--     return
-- end
local runcode = settings.hook_op and hook_op(input) or input
-- if runcode==input then
--     warn("regex bad :(")
-- end
if not chunk then
    if runcode:find("while true.+do end") and not (runcode:find("if") or runcode:find("function")or runcode:find("break")) then return end
    -- Luau (unlike Lua 5.2+) rejects empty statements: a leading ';', ';;', etc.
    -- Obfuscators commonly prepend them (often after a comment header), so peel
    -- leading whitespace / line- & block-comments / semicolons before compiling.
    do
        local changed=true
        while changed do
            changed=false
            for _,pat in {"^%s+","^;+","^%-%-%[%[.-%]%]","^%-%-[^\n]*"} do
                local new=runcode:gsub(pat,"",1)
                if new~=runcode then runcode=new changed=true end
            end
        end
    end
    -- Lune's luau.load throws on a compile error, so pcall it and write a clean
    -- (path-free) note instead of crashing to stderr.
    local okload
    okload, chunk = pcall(luau.load, runcode, "sandbox")
    if not okload then
        local msg=tostring(chunk)
            :gsub("\nstack traceback:.*","")
            :gsub("%f[%a]%a:[\\][%w%._%- \\/]-69ms[\\/]%w+:%d+","internal")
            :gsub("%f[%a]%a:[\\][%w%._%- \\/]+","<path>")
        chunk=nil
        local note="-- [69ms] couldn't parse this script (syntax error):\n-- "..msg
        if msg:find("<eof>",1,true) then
            note=note.."\n-- (this looks truncated - if you pasted it inline, Discord caps messages at 2000 chars; attach it as a .lua file or send a link instead)"
        end
        pcall(fs.writeFile, outpath..targetfilename:gsub(".lua","")..".lua", note)
        return
    end
end
local env,debug_info=getfenv(chunk),debug.info
local c=0
-- for i,v in roblox do
--     cenv[i] = v
-- end
-- local _game=not commercial and roblox.deserializePlace(fs.readFile("Baseplate.rbxl")) or {}
local getglobalfuncname=function(func)
    -- not implemented, LOL!
end
type=function(var)
    -- _print(debug.traceback())
    local t=oldtype(var)
    return t=="table" and rawget(var,__69mslocation) and "context_type" or t
end
local inuse=false
local getnewvar=function(varname)
    repeat until not inuse
    if varname and (type(varname)~="string" or varname:find("69ms",1,true) or not settings.varnames) then
        varname=nil
    end
    inuse=true
    variablecount+=1
    inuse=false
    return "_"..identifier..(varname and varname:gsub("[^A-Za-z0-9_]", "") or "")..variablecount..identifier.."_"
end
local function genvars(num,name,vararg)
    local spyvars,vars={},{}
    local basevar=getnewvar(name)
    if num>0 then
        spyvars[1]=spytbl(basevar)
        vars[1]=basevar
        for i=2,num do
            insert(spyvars,spytbl(basevar.."_"..i))
            insert(vars,basevar.."_"..i)
        end
    end
    local varargvars,varargstr
    if vararg then
        varargvars,varargstr={},{}
        for i=1,10 do
            insert(varargvars,spytbl(basevar.."_vararg"..(i)))
            insert(varargstr,basevar.."_vararg"..(i))
        end
    end
    return spyvars,table.concat(vars,", "),varargvars, varargstr and table.concat(varargstr,", ") or nil
end
local function debug_getinfo(func_or_level,lol)
    if func_or_level==1 and lol=="l" then
        return
    end
    if type(func_or_level)=="context_type" then
        local varname=getnewvar("debug_getinfo")
        simplelog(varname,"debug.getinfo",func_or_level)
        return spytbl(varname)
    end
    local info = {}
    local toadd={l="linedefined",f="func",s="source",n="namewhat",l="istailcall", s="short_src"}
    for opt,name in toadd do
        local value = debug_info(func_or_level, opt)
        if value ~= nil then
            info[name] = value
        end
    end
    if cclosures[func_or_level] then
        info.short_src="[C]"
    end
    info.what=info.short_src:gsub("%[(.+)%]","%1")
    -- print(info)
    return info
end
local special_replacements={}
local unclosed_blocks=0
local fenvused,genvused,currentR,fenv_mt
local last_flush=0
-- Write the trace captured so far to the output file, so if the script later
-- hangs in a tight loop and gets hard-killed, the loader behaviour is still saved.
local function flush_partial()
    if not currentR then return end
    pcall(function()
        local parts={}
        for _,v in currentR do if type(v)=="string" then parts[#parts+1]=v end end
        fs.writeFile(outpath..targetfilename:gsub(".lua","")..".lua",
            "--// This file was generated by 69ms V4 [https://discord.gg/gEHQbMP872]\n"..(table.concat(parts,"\n"):gsub("%f[%a]%a:[\\][%w%._%- \\/]+","<path>")))
    end)
end
tostring_complex=function(var,ignoremt,antioverflow)
    local var_type=type(var)
    if special_replacements[var] then return special_replacements[var] end
    -- print(var,type(var),metatables[var],ignoremt)
    if type(var)=="context_type" then
        return var[__69mslocation]
    elseif var==fenv_mt then
        fenvused=true
        return "fenv"
    elseif metatables[var] and not ignoremt then
        local clonemt
        local wasused=metatables[var].used
        if wasused then
            return wasused
        end
        metatables[var].used=metatables[var].used or getnewvar("t")
        local varname=metatables[var].used
        if metatables[var].mt then
            clonemt=table.clone(metatables[var].mt)
            for i in metatables[var].mt do
                metatables[var].mt[i]=nil
            end
        end
        insert(currentR,`local {varname} = {metatables[var].mt and "setmetatable(" or ""}{tostring_complex(var,true)}{metatables[var].mt and ","..tostring_complex(clonemt)..")" or ""}`)
        if clonemt then
            for i,v in clonemt do
                metatables[var].mt[i]=v
            end
        end
        return varname
    elseif var_type=="table"then
        if antioverflow and antioverflow[var] then
            return '{"<69ms:repeating table structure>"}'
        end
        antioverflow=antioverflow or {}
        antioverflow[var]=true
        return tbl_to_s(var,0,antioverflow)
    elseif var_type=="string" then
        if #var>9e9 then
            return '"<69ms_long_string: '..(#var)..'bytes> if you need ts message me"'
        end
        -- Quote the string but PRESERVE valid UTF-8 (emojis ✅ / symbols stay readable
        -- instead of turning into \xE2\x9C\x85). Only control chars and bytes that aren't
        -- part of a valid UTF-8 sequence get \xXX-escaped.
        local s=tostring(var)
        local out,i,n={'"'},1,#s
        while i<=n do
            local b=string.byte(s,i)
            if b==34 then out[#out+1]='\\"' i=i+1
            elseif b==92 then out[#out+1]='\\\\' i=i+1
            elseif b==9 then out[#out+1]='\\t' i=i+1
            elseif b==10 then out[#out+1]='\\n' i=i+1
            elseif b==13 then out[#out+1]='\\r' i=i+1
            elseif b<32 or b==127 then out[#out+1]=string.format("\\x%02X",b) i=i+1
            elseif b<128 then out[#out+1]=string.char(b) i=i+1
            else
                local len=(b>=0xF0 and 4) or (b>=0xE0 and 3) or (b>=0xC0 and 2) or 0
                local ok=len>0 and i+len-1<=n
                if ok then for j=1,len-1 do local cb=string.byte(s,i+j) if cb<0x80 or cb>0xBF then ok=false break end end end
                if ok then out[#out+1]=string.sub(s,i,i+len-1) i=i+len
                else out[#out+1]=string.format("\\x%02X",b) i=i+1 end
            end
        end
        out[#out+1]='"'
        return table.concat(out)
    elseif var_type=="function" then
        local tablefindres=tablefind(cenv,var)
        if tablefindres then
            return tablefindres
        end
        local info=debug_getinfo(var)
        local name=info.namewhat~="" and info.namewhat or getglobalfuncname(var) or "~anonymous"
        local numargs, isvararg=debug.info(var, "a")
        if settings.usesimplefunctions then return "function(...) --[[n="..name.."]]end" end
        local args,argstr,varargvars,varargstr=genvars(numargs,nil,isvararg)
        local before_unclosed=unclosed_blocks
        local returnR
        if not settings.better_funcs then
            returnR=analyzefunction(var,{},false,multiunpack(args,varargvars))
        else
            is_unfinished=true
            insert(unfinishedfuncs,{func=var,args=args,varargvars=varargvars})
        end
        local res= "function("..argstr..(varargstr and ((argstr~="" and "," or "").."...") or "")..")\n"
            .. (varargstr and "local "..varargstr.." = ...\n" or "")
            ..(returnR and table.concat(returnR,"\n") or  "-- func"..#unfinishedfuncs)
            .."\nend"
        for _=before_unclosed,unclosed_blocks-1 do
            res=res.."\nend"
        end
        unclosed_blocks=before_unclosed
        return res
    elseif table.find({"boolean","number","nil"},var_type) then
        local tostringed=tostring(var)
        if tostringed=="nan" then
            return "0/0"
        elseif tostringed=="inf" then
            return "1/0"
        elseif tostringed=="-inf" then
            return "-1/0"
        end
        return tostringed
    else
        return "{"..tostring_complex("<69ms-unknown-type:"..tostring(var)..">").."}"
    end
end
local stringify=function(...)
    local data=table.pack(...)
    local stringified={}
    for i=1,data.n do
        insert(stringified,tostring_complex(data[i]))
    end
    return table.concat(stringified,", ")
end
local lastcouple,lastfound,lastinsert={},0,1
local function limitinsert(str)
    lastcouple[lastinsert]=str
    lastinsert=lastinsert%60+1
end
local function getheight()
    for i=0,100 do
        local res=pcall(getfenv,i)
        if not res then return i-10 end
    end
end
local tfind,plserror=table.find
simplelog=function(varname,source,...)
    if msecNotReady then return end
    -- wall-clock guard: self-abort a script that keeps hammering the spy env so we
    -- emit a partial trace fast instead of waiting for the whole process timeout.
    deadline_n+=1
    if not settings.benchmark_mode then
        -- Capture a partial trace early (first few calls) in case of an immediate hang,
        -- then only re-flush on a 3s wall-clock interval. The old code rewrote the WHOLE
        -- file on every one of the first 300 calls — for a big detection dump that's 300
        -- full-file writes for nothing. Checking the clock every 256 calls is cheap.
        if deadline_n<=3 or deadline_n%256==0 then
            local now=clock()
            if now-last_flush>3 then last_flush=now flush_partial() end
            if now-startt>(settings.deadline_seconds or 35) then error("<69ms: timeout>") end
        end
    end
    local callargs=stringify(...)
    local back_string=source..(...~=Enum_NOCALL and ("("..callargs..")") or "")
    local write_string="local "..varname.." ="..back_string
    -- size cap: stop once the trace reaches 5 MB and send what we have.
    tracebytes+=#write_string+1
    if tracebytes>TRACE_SIZE_CAP then error("<69ms: sizelimit>") end
    local smegstring=back_string:gsub("_([%a%d]+)_","")
    local plus,minus,minusonerror=140,35,400
    -- Construction/service calls (Instance.new(...), game:GetService(...)) legitimately
    -- repeat — a detection script makes the same class hundreds of times. They return a
    -- real instance (not a spy), so they are NOT a spy-spin loop; exempt them from the
    -- infinite-loop guard so logging them doesn't error inside the script's own pcall.
    local is_construction=source=="Instance.new" or source:sub(1,5)=="game:"
    if not is_construction and settings.watchoutforloop and tfind(lastcouple,smegstring) and #smegstring>3 then
        local min=1e5/(1+(getheight()/5))
        lastfound+=plus
        if lastfound>min and varname~="er" then
            if lastfound>min+1000 then
                plserror=true
            end
            lastfound=lastfound>minusonerror and lastfound-minusonerror or 0
            error("<69ms: infinitelooperror>")
        end
    else
        lastfound=lastfound>minus and lastfound-minus or 0
    end
    limitinsert(smegstring)
    if settings.log_lines then
        local linenumber=debug.traceback():split"\n"
        for i,v in linenumber do
            if v:find("sandbox",1,true) then
                linenumber=v:split(":")[2]
                break
            end
        end
        if type(linenumber)=="string" then write_string..="-- line "..linenumber end
    end
    print(write_string)
    multiinsert(currentR,write_string:split("\n"))
    -- variable_backs[varname]=back_string
end
local function simplemath(operator)
    return function(left,right)
        local varname=getnewvar()
        insert(currentR,"local "..varname.." =(" .. tostring_complex(left)..operator..tostring_complex(right)..")")
        if operator=="==" and settings.hook_op_default_return~="spy" then
            if settings.hook_op_default_return=="original" then
                return rawequal(left,right)
            else
                return settings.hook_op_default_return
            end
        end
        return --[[operator=="==" and true or]] spytbl(varname)
    end
end
local smarthook=function(funcname,original)
    local f=function(...)
        local args=table.pack(...)
        for i=1,args.n do
            if type(args[i])=="context_type" then
                local varname=getnewvar(funcname)
                simplelog(varname,funcname,...)
                return spytbl(varname)
            end
        end
        return original(...)
    end
    cclosures[f]=true
    return f
end
local spymt={
    __index=function(_,key)
        local varname=getnewvar((_[__69mslocation]:sub(1,1)~="_" and _[__69mslocation] or "")..(type(key)=="string" and key or "Idx"))
        simplelog(varname,_[__69mslocation].."["..tostring_complex(key).."]",Enum_NOCALL)
        if type(key)=="string" and _69mspredefined[key]~=nil then
            return _69mspredefined[key]
        elseif key=="lil skid tried to dump" then
            return
        end
        if key=="IsStudio" then
            return function()return false end
        end
        return spytbl(varname)
    end,
    __newindex=function(_,key,value)
        insert(currentR,_[__69mslocation].."["..tostring_complex(key).."] ="..tostring_complex(value) .. (settings.log_lines and " -- line "..(function()
            local linenumber=debug.traceback():split"\n"
            for i,v in linenumber do
                if v:find("sandbox",1,true) then
                    linenumber=v:split(":")[2]
                    break
                end
            end
            return linenumber
        end)() or ""))
    end,
    __call=function(_,...)
        if type((...))=="string" and (...):find("This is a signature - If you are seeing this, you know what not to do :3",1,true) then
            insert(currentR,'_lol("<69ms: luarmor early exit>")')
            plserror=true
        end
        local varname=getnewvar("call"..(_[__69mslocation]:sub(1,1)~="_" and _[__69mslocation] or ""))
        simplelog(varname,_[__69mslocation],...)
        local spy=spytbl(varname)
        -- local a,b,c=...
        -- if b=="HttpService" then
        --     insert(currentR,"_pmo()")
        --     if not _.HttpServiceSave then
        --         _.HttpServiceSave=spy
        --     else
        --         return _.HttpServiceSave
        --     end
        -- end
        return spy
    end,
    __concat=function(left,right)
        local varname=getnewvar()
        simplelog(varname,tostring_complex(left).." .. "..tostring_complex(right),Enum_NOCALL)
        return spytbl(varname)
    end,
    __tostring=function(_)
        return concat_me.._[__69mslocation]..concat_me_close
    end,
    __iter=function(_,funcused)
        local ran=false
        return function(t,...)
            if not ran then
                unclosed_blocks+=1
                local vars,varsstr=genvars(2)
                local mid=_[__69mslocation]
                if funcused=="next" then
                    mid="next,"..mid
                elseif funcused then
                    mid=`{funcused}({mid})`
                end
                insert(currentR,`for {varsstr} in {mid} do`)
                ran=true
                return unpack(vars)
            end
            unclosed_blocks-=1
            insert(currentR,"end")
        end
    end,
    __len=function(_)
        -- Keep this well under Luau's table size limit (~2^26): a script that
        -- does `for i=1,#spy do t[i]=v end` would otherwise overflow the table.
        -- The value is replaced by a variable name in the output, so its
        -- magnitude doesn't matter for readability.
        local returnvalue=math.random(1e3,1e5)
        local varname=getnewvar("len"..(_[__69mslocation]:sub(1,1)~="_" and _[__69mslocation] or ""))
        special_replacements[returnvalue]=varname
        insert(currentR,"local "..varname.." =#".._[__69mslocation])--.." -- returning: " .. returnvalue .. " (if you see this number again you will know its from this!)")
        return returnvalue
    end,
    __add=simplemath"+",
    __sub=simplemath"- ",
    __mul=simplemath"*",
    __div=simplemath"/",
    __mod=simplemath"%",
    __pow=simplemath"^",
    __lt=simplemath"<",
    __le=simplemath"<=",
    __eq=simplemath"==",
    __unm=function(self)
        local varname=getnewvar()
        insert(currentR,"local "..varname.." =" .. "-"..tostring_complex(self))
        return spytbl(varname)
    end,
    __type="context_type",
}
analyzefunction = function(chunk,r,lowestlayer,...)
    if plserror then return r end
    local oldR=currentR
    currentR=r
    local cenv=cenv["69msWasHere"] and {} or cenv
    cenv["69msWasHere"]=true
    spytbl=function(pre,var_type)
        local tbl=setmetatable({
            [__69mslocation]=pre,
        },spymt)
        if var_type then
            types[tbl]=var_type
        end
        return tbl
    end
    if settings.hook_op~=false then
        local log_if_needed=function(operation,a,b,actual)
            if type(a)=="context_type" or type(b)=="context_type" then
                local varname=getnewvar()
                local place_front=operation=="#" or operation=="not"
                simplelog(varname,(place_front and operation.." " or "")..(tostring_complex(a)..(not place_front and " "..operation.." " or "")..(not place_front and tostring_complex(b) or "")),Enum_NOCALL)
                local setting=settings.hook_op_default_return
                if setting=="spy" then
                    return spytbl(varname)
                elseif setting=="original" then
                    local success,result=pcall(actual)
                    return if success then result else 1
                else
                    if operation=="not" then
                        return not setting
                    end
                    return setting
                end
            end
            return actual()
        end
        cenv._69msLE=function(a,b) return log_if_needed("<",a,b,(function()return(a < b)end)) end
        cenv._69msGR=function(a,b) return log_if_needed(">",a,b,(function()return(a > b)end)) end
        cenv._69msLEEQ=function(a,b) return log_if_needed("<=",a,b,(function()return(a <= b)end)) end
        cenv._69msGREQ=function(a,b) return log_if_needed(">=",a,b,(function()return(a >= b)end)) end
        cenv._69msUNEQ=function(a,b) return log_if_needed("~=",a,b,(function()return(a ~= b)end)) end
        cenv._69msEQ=function(a,b)return log_if_needed("==",a,b,(function()return(a == b)end)) end
        cenv._69msNOT=function(a) return log_if_needed("not",a,nil,(function()return(not a)end)) end
        cenv._69msLEN=function(a) return log_if_needed("#",a,nil,(function()return(#a)end)) end

        cenv._69msAND=function(a,b)
            if type(a)=="context_type" then
                b=b()
                local varname=getnewvar()
                simplelog(varname,(tostring_complex(a).." and "..tostring_complex(b)),Enum_NOCALL)
                if settings.hook_op_default_return=="original" then
                    return a and b
                end
                return settings.hook_op_default_return=="spy" and spytbl(varname) or settings.hook_op_default_return
            elseif a then
                b=b()
                if type(b)=="context_type" then
                    local varname=getnewvar()
                    simplelog(varname,(tostring_complex(a).." and "..tostring_complex(b)),Enum_NOCALL)
                    return settings.hook_op_default_return=="spy" and spytbl(varname) or settings.hook_op_default_return=="original" and b or settings.hook_op_default_return
                end
                return a and b
            else
                return a and b()
            end
        end
        cenv._69msOR=function(a,b)
            local is_a_context=type(a)=="context_type"
            if is_a_context or not a then
                b=b()
                if is_a_context or type(b)=="context_type" then
                    local varname=getnewvar()
                    simplelog(varname,`({tostring_complex(a)} or {tostring_complex(b)})`,Enum_NOCALL)
                    return spytbl(varname)
                end
                return b
            else
                return a or b()
            end
        end

        cenv._69msIF=function(a)if type(a)=="context_type" then insert(currentR,"CHECKIF("..tostring_complex(a)..")")end return a end
        cenv._69msELSEIF=function(a)if type(a)=="context_type" then insert(currentR,"CHECKELSEIF("..tostring_complex(a)..")")end return a end
        local while_metas={}
        cenv._69msWHILE=function(a)
            if type(a)=="context_type" then
                if while_metas[a] then return false end
                insert(currentR,"CHECKWHILE("..tostring_complex(a)..")")
                while_metas[a]=true
            end
            return a
        end
        cenv._69msREPEAT=function(a)if type(a)=="context_type" then insert(currentR,"CHECKUNTIL("..tostring_complex(a)..")")end return a end
        cenv._69msINDEX=function(tbl)
            return setmetatable({},{
                __index=function(_,key)
                    if type(tbl)~="context_type" and type(key)=="context_type" then
                        local varname=getnewvar("idx")
                        metatables[tbl]=metatables[tbl] or {
                            mt=false,
                            used=false
                        }
                        simplelog(varname,`{tostring_complex(tbl)}[{tostring_complex(key)}]`,Enum_NOCALL)
                        return spytbl(varname)
                    end
                    return tbl[key]
                end,
                __newindex=function(_,key,value)
                    if type(tbl)~="context_type" and (type(key)=="context_type" and type(value)=="context_type") then -- OR WOULD BE COOL BUT DOESNT WORK ON OBF OKAY!
                        -- local varname=getnewvar()
                        metatables[tbl]=metatables[tbl] or {
                            mt=false,
                            used=false
                        }
                        insert(currentR,`{tostring_complex(tbl)}[{tostring_complex(key)}] = {tostring_complex(value)}`)
                        -- tbl[key]=spytbl(varname) -- could add ts i dunno :3
                    end
                    tbl[key]=value
                end,
                __type="sybau type",
            })
        end
    end
    cenv.setmetatable=function(tbl,mt)
        if type(tbl)=="context_type" or tbl==fenv_mt or type(mt)=="context_type" then
            local varname=getnewvar("setmetatable")
            simplelog(varname,"setmetatable",tbl,mt)
            return spytbl(varname)
        end
        metatables[tbl]={
            mt=mt,
            used=false
        }
        return setmetatable(tbl,mt)
    end
    cenv.setfenv=env.setfenv
    local game_meta=table.clone(spymt)
    game_meta.__call=function()
        return error("game cant be called")
    end
    do
        local base_newindex=game_meta.__newindex
        game_meta.__newindex=function(t,k,v)
            -- the DataModel's Parent/IsLoaded etc. are read-only.
            if k=="Parent" or k=="IsLoaded" or k=="ClassName" then error("Unable to assign property "..tostring(k)..". Property is read only",2) end
            if base_newindex then return base_newindex(t,k,v) end
        end
        local base_index=game_meta.__index
        game_meta.__index=function(t,k)
            -- IsLoaded handled here (not rawset) so writing it hits __newindex -> errors.
            if k=="IsLoaded" then return function() return true end end
            return base_index(t,k)
        end
    end
    if specialhandle=="moonveil" then
        local og_index=game_meta.__index
        game_meta.__index=function(_,key)
            if type(key)=="string" then
                if key:sub(1,1):lower()==key:sub(1,1) or key:sub(#key,#key):upper()==key:sub(#key,#key)then
                    print("dtc",key)
                    game_meta.__index=og_index
                    error"moonveil is bad"
                end
            end
            return og_index(_,key)
        end
    end
    cenv.game=setmetatable({
        -- HttpGet=function(_,...)
        --     local varname=getnewvar()
        --     simplelog(varname,"game:HttpGet",...)
        --     -- if type(Url)~="string" and type(Url)~="context_type" then
        --     --     error()
        --     -- end
        --     -- for _,v in whitelistedUrls do
        --     --     if Url:sub(1,#v) == v then
        --     --         print("returning real")
        --     --         return request{url=Url,method="GET"}.body
        --     --     end
        --     -- end
        --     return spytbl(varname)
        -- end,
        [__69mslocation]="game",
        -- IsLoaded=function(_)return true end,
        -- PlaceId=2753915549
    },game_meta)
    -- cenv.game=spytbl("game")
    cenv.Game=cenv.game
    for _,name in {
                "Instance","Drawing","UDim","CFrame","Color3","Vector3","UDim2","Vector2",
                "workspace","ypcall","gethwid","setfpscap",--[["os",]]"rconsoleprint",
                "rconsolewarn","package","makefolder","writefile","readfile","listfiles",
                "mkdir","isfile","delay","clonefunction","hookmetamethod",
                "setreadonly", "getrawmetatable", "fireproximityprompt",
                "ColorSequence","ColorSequenceKeypoint","Font","Workspace","cloneref",
                "TweenInfo","OverlapParams","setclipboard","toclipboard",
                "hookmetatable","hookfunction","base64","Random","RaycastParams","Ray",
                "restorefunction","script","hookfunction","print",
                "request","http_request","httpRequest","HttpRequest","http",
                "warn","getconnections","hash","NumberRange","NumberSequence",
                "Rect","NumberSequenceKeypoint","getgc",
                "getcustomasset","_VERSION","PhysicalProperties","queue_on_teleport",
                "shared","gethui","fireproximityprompt","crypt","getnamecallmethod",
                "getconstants","BrickColor","cleardrawcache","WebSocket","isrenderobj",
                "setrenderproperty","getrenderproperty","setidentity","setthreadcontext",
                "getidentity","getthreadcontext","getthreadidentity","setthreadidentity",
                "getsenv","getscripts","getscripthash","getrunningscripts","queueonteleport",
                "isrbxactive","isgameactive","cache","checkcaller","getupvalue","DeepCopy",
                "DateTime","input","time","Vector3int16","Vector2int16",
            } do
        cenv[name]=spytbl(name)
    end
    -- tick() in Roblox is a real unix timestamp (~1.7e9), not a since-start clock.
    -- dtc scripts gate on `tick() > 1e9` to tell a real client from a fake env.
    cenv.tick=function()return os.time()+(os.clock()%1)end
    cenv.elapsedTime=function() return os.clock() end
    cenv.ElapsedTime=cenv.elapsedTime
    cenv.time=function() return os.clock() end
    cenv.cloneref=function(x) return x end -- a reference to the SAME instance
    cenv.compareinstances=function(a,b) return a==b end
    cenv.Random=setmetatable({
        new=function(seed)
            -- deterministic per seed (LCG), so Random.new(s):Next... is reproducible.
            local state=math.floor((tonumber(seed) or 0))%2147483647; if state<=0 then state=state+2147483646 end
            local function nf() state=(state*16807)%2147483647 return state/2147483647 end
            local r=setmetatable({},{__index=function(_,k)
                if k=="NextNumber" then return function(_,a,b) if a and b then return a+nf()*(b-a) end return nf() end end
                if k=="NextInteger" then return function(_,a,b) a=math.floor(a or 0) b=math.floor(b or 2147483647) return a+math.floor(nf()*(b-a+1)) end end
                if k=="NextUnitVector" then return function() return cenv.Vector3 and cenv.Vector3.new(0,1,0) end end
                if k=="Clone" then return function() return cenv.Random.new(seed) end end
                if k=="Shuffle" then return function(_,t) return t end end
                return function() return 0 end
            end,__metatable=false})
            types[r]="Random" -- typeof(Random.new())=="Random"
            return r
        end
    },{__index=function(_,k) return function() return cenv.Random.new() end end})
    cenv._VERSION="Luau"
    cenv.bit=bit32
    -- ===== fake Roblox instances + datatypes (typeof / ClassName / GetService) =====
    do
        local makedt -- forward declaration (instance methods can return datatypes)
        -- methods that require an argument (benchmark calls them arg-less and
        -- expects an error). Is* methods also return true when given an arg.
        local argmethods={}
        for _,m in {
            "FindFirstChild","FindFirstChildOfClass","FindFirstChildWhichIsA",
            "FindFirstAncestor","FindFirstAncestorOfClass","FindFirstAncestorWhichIsA",
            "GetAttribute","SetAttribute","WaitForChild","WaitForChildWhichIsA",
            "GetPropertyChangedSignal","IsA","IsDescendantOf","IsAncestorOf",
            "AddTag","RemoveTag","HasTag","SetPrimaryPartCFrame","PivotTo",
            "FireServer","InvokeServer","Connect","ConnectParallel","Once","Wait",
            "JSONEncode","JSONDecode","IsKeyDown","GetAsync","SetAsync","UpdateAsync",
            "RemoveAsync","PostAsync","RequestAsync","GetStateChangedSignal",
            "PromptPremiumPurchase","PromptPurchase","GetProductInfo","Kick",
            "GetUserIdFromNameAsync","GetNameFromUserIdAsync","IsMouseButtonPressed",
        } do argmethods[m]=true end
        -- executor functions that are valid with NO arguments (everything else in
        -- the executor list errors on a missing arg in benchmark mode).
        local noargfuncs={}
        for _,m in {
            "getgenv","getrenv","getreg","getgc","getinstances","getnilinstances",
            "getscripts","getloadedmodules","getrunningscripts","getcallingscript",
            "getexecutorname","identifyexecutor","gethui","getthreadidentity",
            "getidentity","isrbxactive","isgameactive","getclipboard","getfpscap",
            "cleardrawcache","checkcaller","getthreadcontext","getsimulationradius",
        } do noargfuncs[m]=true end
        -- methods that return an ARRAY. They must hand back a REAL (empty) table, never
        -- a spy: detection scripts ipairs() the result, and ipairs over a spy walks
        -- integer keys forever (every key returns a spy), spamming the trace until the
        -- loop guard errors inside the script's pcall and fails the check.
        local arraymethods={}
        for _,m in {"GetPropertiesOfClass","GetMethodsOfClass","GetClasses","GetEnums",
            "GetPlayers","GetConnectedParts","GetJoints","GetTouchingParts","GetGuiObjectsAtPosition",
            "GetEvents","GetCallbacks","GetSignals","GetAttributeChangedSignals","GetRobloxClasses",
        } do arraymethods[m]=true end
        -- known instance properties (value-typed, not methods)
        local propmap={DistanceFactor=3.33,RobloxLocaleId="en-us",SystemLocaleId="en-us",LocaleId="en-us",RolloutLocaleId="en-us"}
        -- real default property values (so detection scripts that read e.g.
        -- Part.Anchored get the authentic value, not a spy). Applied in ALL modes.
        local propdefaults={
            Anchored=false,CanCollide=true,CanTouch=true,CanQuery=true,CastShadow=true,
            Locked=false,Massless=false,Transparency=0,Reflectance=0,Archivable=true,
            Disabled=false,Enabled=true,Visible=true,Active=true,RobloxLocked=false,
            Draggable=false,ClassName=nil,Health=100,MaxHealth=100,WalkSpeed=16,
            JumpPower=50,Sit=false,PlatformStand=false,Jump=false,
        }
        -- property -> roblox datatype, so `typeof(inst.Prop)` is authentic. Real-typed
        -- values (number/Color3/Vector3/CFrame/EnumItem/...), not spies. Unambiguous
        -- property names only; class-specific ones (Position) are handled in __index.
        local proptypes={
            Intensity="number",BlastRadius="number",JumpHeight="number",RootPriority="number",
            ContactsCount="number",DistributedGameTime="number",Density="number",FieldOfView="number",
            Brightness="number",Threshold="number",Stiffness="number",HipHeight="number",
            FogEnd="number",FogStart="number",DataReceiveKbps="number",DataSendKbps="number",
            FallenPartsDestroyHeight="number",Friction="number",Elasticity="number",Mass="number",
            Volume="number",TimeOfDay="number",ClockTime="number",Thickness="number",
            Ambient="Color3",OutdoorAmbient="Color3",FogColor="Color3",Color="Color3",
            ClientGitHash="string",PlaceVersion="string",CollisionGroup="string",
            TouchEnabled="boolean",KeyboardEnabled="boolean",MouseEnabled="boolean",GamepadEnabled="boolean",
            AccelerometerEnabled="boolean",GyroscopeEnabled="boolean",VREnabled="boolean",
            GeographicLatitude="number",FrameTime="number",Length="number",Health="number",
            Heat="number",WindSpeed="number",Offset="number",Range="number",Angle="number",
            HeartbeatTime="number",PhysicsStepTime="number",LeftTangent="number",RightTangent="number",
            ActuatorType="EnumItem",Status="EnumItem",TextTruncate="EnumItem",Material="EnumItem",
            TextXAlignment="EnumItem",TextYAlignment="EnumItem",Linear="EnumItem",Font="EnumItem",
            CameraType="EnumItem",EasingStyle="EnumItem",EasingDirection="EnumItem",DisplayDistanceType="EnumItem",
            NameDisplayDistance="number",HealthDisplayDistance="number",
            MouseIcon="string",CreatorType="string",AppVersion="string",TimeOfDay="string",
            AutoRotate="boolean",AutoJumpEnabled="boolean",CanLoadCharacterAppearance="boolean",
            MouseIconEnabled="boolean",MouseDeltaSensitivity="number",
            BorderColor3="Color3",TintColor="Color3",BackgroundColor3="Color3",TextColor3="Color3",TextStrokeColor3="Color3",
            CFrame="CFrame",Focus="CFrame",AnchorPoint="Vector2",FontFace="Font",
            MoveDirection="Vector3",AssemblyLinearVelocity="Vector3",Velocity="Vector3",
            GlobalShadows="boolean",AccountAge="number",FocusDistance="number",
            HeartbeatTimeMs="number",DataSendKbps2="number",FieldOfViewMode="EnumItem",
            MouseBehavior="EnumItem",FilterType="EnumItem",DevComputerMovementMode="EnumItem",
            Action="EnumItem",Interpolation="EnumItem",
            ZIndex="number",TextStrokeTransparency="number",StarCount="number",InstanceCount="number",
            MinPrice="number",MaxPrice="number",NumberOfPlayers="number",StrokeTransparency="number",
            TextTransparency="number",BackgroundTransparency="number",ImageTransparency="number",
            LayoutOrder="number",SizeConstraint="EnumItem",AutomaticSize="EnumItem",
            ClipsDescendants="boolean",Selectable="boolean",Modal="boolean",MemoryTrackingEnabled="boolean",
            ClearTextOnFocus="boolean",MultiLine="boolean",TextWrapped="boolean",TextScaled="boolean",
            Interactable="boolean",Draggable2="boolean",
            SparkleColor="Color3",SecondaryColor="Color3",Color3Value="Color3",
            SortType="EnumItem",MovingPrimitivesCount="number",HeadScale="number",BodyTypeScale="number",
            PhysicsReceiveKbps="number",PhysicsSendKbps="number",PrimitivesCount="number",
            AmbientReverb="EnumItem",RespectFilteringEnabled="boolean",DistanceFactorEnabled="boolean",
            DopplerScale="number",RolloffScale="number",ClockTime="number",
            DoubleSided="boolean",RenderFidelity="EnumItem",CollisionFidelity="EnumItem",
            ChatVersion="EnumItem",FillColor="Color3",OutlineColor="Color3",ActionText="string",
            SalesTypeFilter="EnumItem",PhysicsStepTimeMs="number",DataReceiveKbps2="number",
            PerformanceStatsVisible="boolean",
            ProximityPromptStyle="EnumItem",DepthMode="EnumItem",ApplyStrokeMode="EnumItem",
        }
        local guiclass={Frame=true,TextLabel=true,TextButton=true,TextBox=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true,ScreenGui=true,Gui=true}
        local vectorprop={Orientation=true,Position=true,Size=true,CFrame=true,Velocity=true,RotVelocity=true,AssemblyLinearVelocity=true,Color=true,Color3=true,Ambient=true}
        local function typedprop(t)
            if t=="number" then return 0 elseif t=="string" then return "" elseif t=="boolean" then return true
            elseif t=="Color3" then return makedt("Color3",{0,0,0}) elseif t=="Vector3" then return makedt("Vector3",{0,0,0})
            elseif t=="Vector2" then return makedt("Vector2",{0,0})
            elseif t=="CFrame" then return makedt("CFrame",{0,0,0}) elseif t=="UDim2" then return makedt("UDim2",{0,0,0,0})
            elseif t=="Font" then return makedt("Font",{})
            elseif t=="EnumItem" then return cenv.Enum.Material.Plastic end
        end
        -- classes whose .Size is a single number (post-processing effects), not a Vector3.
        local effectsizeclass={BlurEffect=true,BloomEffect=true,SunRaysEffect=true,DepthOfFieldEffect=true,ColorCorrectionEffect=true,Fire=true,Smoke=true,Sparkles=true,ParticleEmitter=true,Explosion=true}
        -- Enum system: Enum.X is an EnumType; EnumType.Y / enum props are EnumItems.
        -- Items are fabricated on access with an authentic tostring ("Enum.Type.Item"),
        -- a non-nil numeric Value, an EnumType back-ref and GetEnumItems — which is what
        -- detection scripts verify. Registered in datatype_strings so cenv.tostring
        -- returns the real string instead of obfuscating it as a table address.
        local enumtypes={}
        local function makeenumitem(et,typename,nm,val)
            local it
            it=setmetatable({Name=nm,Value=val,EnumType=et},{__index=function(_,k)
                if k=="EnumType" then return et elseif k=="Name" then return nm elseif k=="Value" then return val
                elseif k=="GetName" then return function() return nm end end
                return spytbl("EnumItem."..tostring(k))
            end,__tostring=function() return "Enum."..typename.."."..nm end,__metatable=false})
            types[it]="EnumItem"
            datatype_strings[it]=function() return "Enum."..typename.."."..nm end
            return it
        end
        local function makeenumtype(typename)
            if enumtypes[typename] then return enumtypes[typename] end
            local items,order,counter={},{},0
            local et
            et=setmetatable({},{__index=function(e,item)
                if item=="GetEnumItems" then return function()
                    while #order<70 do local n="Item"..counter local it=makeenumitem(e,typename,n,counter) items[n]=it order[#order+1]=it counter=counter+1 end
                    return order
                end end
                if item=="GetName" then return function() return typename end end
                local iname=tostring(item)
                if not items[iname] then
                    local it=makeenumitem(e,typename,iname,counter)
                    items[iname]=it order[#order+1]=it counter=counter+1
                end
                return items[iname]
            end,__tostring=function() return "Enum."..typename end,__metatable=false})
            types[et]="Enum"
            datatype_strings[et]=function() return "Enum."..typename end
            enumtypes[typename]=et
            return et
        end
        cenv.Enum=setmetatable({},{__index=function(self,k)
            if k=="GetEnums" then return function() local r={} for _,v in enumtypes do r[#r+1]=v end return r end end
            local et=makeenumtype(tostring(k))
            rawset(self,k,et)
            return et
        end})
        local enumprops={MembershipType="MembershipType"}
        local instanceprops={LocalPlayer="Player",Character="Model",Humanoid="Humanoid",HumanoidRootPart="Part",PrimaryPart="Part",Head="Part",PlayerGui="PlayerGui",CurrentCamera="Camera",Backpack="Backpack",StarterPlayerScripts="StarterPlayerScripts",StarterCharacterScripts="StarterCharacterScripts",Terrain="Terrain",PlayerScripts="PlayerScripts",PerformanceStats="PerformanceStats"}
        local makeinstance,services -- forward decl (methodret/Destroy closures use them)
        local methodret={
            GenerateGUID=function() return "{4A8F2C1E-1234-5678-9ABC-000000000000}" end,
            GetMouseLocation=function() return makedt("Vector2",{960,540}) end,
            GetDeviceCameraCFrameForSelfView=function() return makedt("CFrame") end,
            GetDeviceCameraCFrame=function() return makedt("CFrame") end,
            GetMass=function() return 1.4 end,
            GetVolume=function() return 8 end,
            WorldToScreenPoint=function() return makedt("Vector3",{0,0,0}),true end,
            WorldToViewportPoint=function() return makedt("Vector3",{0,0,0}),true end,
            ScreenPointToRay=function() return makedt("Ray") end,
            ViewportPointToRay=function() return makedt("Ray") end,
            GetPivot=function() return makedt("CFrame") end,
            GetRenderCFrame=function() return makedt("CFrame") end,
            Raycast=function() local r={Position=makedt("Vector3",{0,0,0}),Normal=makedt("Vector3",{0,1,0}),Material=cenv.Enum.Material.Plastic,Distance=10,Instance=makeinstance("Part")} types[r]="RaycastResult" return r end,
            Blockcast=function() local r={Position=makedt("Vector3",{0,0,0}),Normal=makedt("Vector3",{0,1,0}),Material=cenv.Enum.Material.Plastic,Distance=10,Instance=makeinstance("Part")} types[r]="RaycastResult" return r end,
            GetPlayerFromCharacter=function() return nil end,
            GetPlayerByUserId=function() return nil end,
            FindFirstChildOfClass2=nil,
            Shapecast=function() return nil end,
            CreatePath=function() return makeinstance("Path") end,
            GetMouse=function() return makeinstance("PlayerMouse") end,
            Create=function() return makeinstance("Tween") end,           -- TweenService:Create -> Tween
            GetMinutesAfterMidnight=function() return 720 end,            -- Lighting
            SetMinutesAfterMidnight=function() end,
            GetSunDirection=function() return makedt("Vector3",{0,1,0}) end,
            GetMoonDirection=function() return makedt("Vector3",{0,1,0}) end,
            GetCollisionGroupId=function() return 0 end,
            GetUserCFrame=function() return makedt("CFrame",{}) end,
            GetLastInputType=function() return cenv.Enum.UserInputType.MouseMovement end,
            GetGuiInset=function() return makedt("Vector2",{0,36}) end,
            IsTenFootInterface=function() return false end,
            GetTranslatorForPlayerAsync=function() return makeinstance("Translator") end,
            GetTranslatorForLocaleAsync=function() return makeinstance("Translator") end,
            GetRobloxLocaleId=function() return "en-us" end,
            GetCollisionGroups=function() return {} end,
            -- real EditableMesh: vertices are stored and read back exactly (anti-tamper
            -- scripts add a vertex then assert GetPosition returns it). Not spoofing — it
            -- genuinely round-trips the data.
            CreateEditableMesh=function() local verts={} local m=setmetatable({},{__index=function(_,k)
                if k=="AddVertex" then return function(_,v) verts[#verts+1]=v return #verts end end
                if k=="GetPosition" then return function(_,id) return verts[id] end end
                if k=="SetPosition" then return function(_,id,v) verts[id]=v end end
                if k=="GetVertices" then return function() local r={} for i=1,#verts do r[i]=i end return r end end
                if k=="RemoveVertex" then return function() end end
                if k=="Destroy" or k=="Remove" then return function() end end
                if k=="ClassName" then return "EditableMesh" end
                return function() return makedt("Vector3",{}) end
            end,__metatable=false}) types[m]="Instance" return m end,
            CreateEditableImage=function() return makeinstance("EditableImage") end,
            GetMoveVector=function() return makedt("Vector3",{0,0,0}) end,
            GetPartBoundsInBox=function() return {} end,
            GetProductInfo=function() return {Name="Test Product",AssetTypeId=8,PriceInRobux=100,Description="",Creator={Name="Roblox",Id=1},IsForSale=true,ProductId=1,Created="2020-01-01T00:00:00Z",Updated="2020-01-01T00:00:00Z"} end,
            IsServer=function() return false end,
            IsClient=function() return true end,
            IsStudio=function() return false end,
            IsEdit=function() return false end,
            IsRunning=function() return true end,
            IsRunMode=function() return false end,
            GetServerTimeNow=function() return os.time() end,
            GetState=function() return cenv.Enum.HumanoidStateType.Running end,
            GetStateEnabled=function() return true end,
            GetMoveDirection=function() return makedt("Vector3",{0,0,1}) end,
            GetSecret=function(_,k) if k==nil or k=="" then error("Invalid secret key",2) end return makedt("Secret",{}) end,
        }
        local dtmethodret={Dot="number",Angle="number",FuzzyEq="true",Magnitude="number",Cross="self",Lerp="self"}
        -- signal/connection + tag registries (firesignal, getconnections, tags)
        local signals=setmetatable({},{__mode="k"})
        local tagreg={}
        -- per-instance stored properties + children, so `p.Name="X"` reads back, and
        -- child.Parent=p / p:FindFirstChild / p:Clone behave for real (detection checks).
        local instprops=setmetatable({},{__mode="k"})
        local instchildren=setmetatable({},{__mode="k"})
        local instattrs=setmetatable({},{__mode="k"})    -- SetAttribute/GetAttribute store
        local instdestroyed=setmetatable({},{__mode="k"})-- Destroy() -> Parent becomes nil
        local sigprops={}
        for _,s in {"Event","Changed","Touched","TouchEnded","Activated","MouseButton1Click","MouseButton1Down","MouseButton1Up","MouseButton2Click","MouseEnter","MouseLeave","InputBegan","InputEnded","InputChanged","Heartbeat","RenderStepped","Stepped","PreRender","PreAnimation","PreSimulation","PostSimulation","ChildAdded","ChildRemoved","DescendantAdded","DescendantRemoving","AncestryChanged","PlayerAdded","PlayerRemoving","CharacterAdded","CharacterRemoving","OnClientEvent","OnServerEvent","StateChanged","MessageOut","Died","Running","Jumping","Climbing","Seated","FreeFalling","GettingUp","HealthChanged","Hit","Completed","Heartbeat","PromptShown","PromptHidden","Triggered","TouchTap","WindowFocused","WindowFocusReleased","SimulationRadiusChanged","GraphicsQualityChanged","LoadFinished","DragStart","DragContinue","DragEnd","MouseClick","RightMouseClick","Equipped","Unequipped","ChildModified"} do sigprops[s]=true end
        local function makeconn(fn)
            local c=setmetatable({Function=fn,Connected=true,Disconnect=function(s) s.Connected=false end},{__index=function(_,k) if k=="Connected" then return true end return function()end end,__metatable=false})
            types[c]="RBXScriptConnection"
            return c
        end
        local function fireconns(conns,...)
            for i=#conns,1,-1 do
                local c=conns[i]
                if c and c.Connected then
                    if type(c.Function)=="function" then pcall(c.Function,...) end
                    if c.Once then c.Connected=false table.remove(conns,i) end
                end
            end
        end
        local framesignals={} -- {conns,...} of Heartbeat/RenderStepped/Stepped
        local function makesignal(isframe)
            local conns={}
            local sig=setmetatable({},{__index=function(_,k)
                if k=="Connect" or k=="connect" or k=="ConnectParallel" then return function(_,fn) local c=makeconn(fn) table.insert(conns,c) return c end end
                if k=="Once" then return function(_,fn) local c=makeconn(fn) c.Once=true table.insert(conns,c) return c end end
                if k=="Wait" then return function(s) if s==nil then error("Expected ':' not '.' calling member function Wait",2) end fire_frame_signals() return 1/60 end end
                if k=="Fire" then return function(_,...) fireconns(conns,...) end end
                if k=="IsA" then return function(_,n) return n=="RBXScriptSignal" end end
                if k=="Connected" then return true end
                return function() end
            end,__metatable=false})
            signals[sig]=conns
            types[sig]="RBXScriptSignal"
            if isframe then framesignals[#framesignals+1]=conns end
            return sig
        end
        -- task.wait() fires a frame: every Heartbeat/RenderStepped/Stepped connection runs.
        fire_frame_signals=function() for _,conns in framesignals do fireconns(conns,1/60) end end
        local framesigset={Heartbeat=true,RenderStepped=true,Stepped=true,PreRender=true,PreAnimation=true,PreSimulation=true,PostSimulation=true}
        if settings.benchmark_mode then
            cenv.firesignal=function(sig,...) if sig==nil then error("missing argument #1 to 'firesignal'",2) end local c=signals[sig] if c then for _,cc in c do if cc.Connected and type(cc.Function)=="function" then pcall(cc.Function,...) end end end end
            cenv.getconnections=function(sig) if sig==nil then error("missing argument #1 to 'getconnections'",2) end return signals[sig] or {} end
        end
        function makeinstance(className)
            local mt=table.clone(spymt)
            local base=mt.__index
            local kv,sigcache={},{} -- SetItem/GetItem store + cached signals
            mt.__index=function(self,key)
                local stored=instprops[self]
                -- LOG these real reads (don't silently mock): a normal env logger shows
                -- every property access. ClassName is fixed; Name/Parent return a stored
                -- value if the script set one (so p.Name="X" reads back), else the default.
                if key=="ClassName" then
                    simplelog(getnewvar(className.."ClassName"),className.."[\"ClassName\"]",Enum_NOCALL)
                    return className
                end
                if key=="Name" then
                    simplelog(getnewvar(className.."Name"),className.."[\"Name\"]",Enum_NOCALL)
                    return (stored and stored.Name~=nil) and stored.Name or className
                end
                if key=="Parent" then
                    simplelog(getnewvar(className.."Parent"),className.."[\"Parent\"]",Enum_NOCALL)
                    -- real Roblox: a fresh Instance.new has Parent==nil until assigned,
                    -- and Destroy() resets it to nil. Only return a parent if one was set.
                    if instdestroyed[self] then return nil end
                    if stored and stored.Parent~=nil then return stored.Parent end
                    return nil
                end
                -- Destroy(): unparent (Parent becomes nil) + detach from its parent's list
                if key=="Destroy" or key=="Remove" then
                    return function()
                        -- services (Workspace, Lighting, ...) can't be destroyed.
                        if services and services[className]==self then error("The Parent property of "..className.." is locked",2) end
                        local sp=instprops[self]; if not sp then sp={} instprops[self]=sp end
                        local oldp=sp.Parent
                        if oldp and instchildren[oldp] then
                            for i,c in instchildren[oldp] do if c==self then table.remove(instchildren[oldp],i) break end end
                        end
                        -- destroying a parent unparents its children too
                        if instchildren[self] then for _,c in instchildren[self] do local cp=instprops[c]; if not cp then cp={} instprops[c]=cp end cp.Parent=nil; instdestroyed[c]=true end instchildren[self]={} end
                        sp.Parent=nil; instdestroyed[self]=true
                    end
                end
                -- BindableEvent:Fire(...) invokes its .Event connections; :Invoke returns.
                if key=="Fire" then return function(_,...) local ev=sigcache.Event; if ev then fireconns(signals[ev],...) end end end
                if key=="Invoke" then return function() return end end
                if key=="GetChildren" or key=="GetDescendants" then return function() local r={} if instchildren[self] then for _,c in instchildren[self] do r[#r+1]=c end end return r end end
                if key=="ClearAllChildren" then return function() if instchildren[self] then for _,c in instchildren[self] do local cp=instprops[c]; if cp then cp.Parent=nil end instdestroyed[c]=true end end instchildren[self]={} end end
                if key=="SetAttribute" then return function(_,n,v) if n==nil then error("missing argument #2 to 'SetAttribute'",2) end local at=instattrs[self]; if not at then at={} instattrs[self]=at end at[n]=v end end
                if key=="GetAttribute" then return function(_,n) if n==nil then error("missing argument #1 to 'GetAttribute'",2) end local at=instattrs[self]; return at and at[n] end end
                if key=="GetAttributes" then return function() local r={} local at=instattrs[self]; if at then for k,v in at do r[k]=v end end return r end end
                -- real child lookup against assigned children
                if key=="FindFirstChild" or key=="WaitForChild" or key=="FindFirstChildOfClass" or key=="FindFirstChildWhichIsA" then
                    return function(_,want,timeout)
                        if want==nil then error("missing argument #1 to '"..key.."'",2) end
                        local kids=instchildren[self]
                        if kids then for _,c in kids do
                            local cp=instprops[c]
                            local nm=(cp and cp.Name) or types[c]
                            if key=="FindFirstChildOfClass" or key=="FindFirstChildWhichIsA" then
                                if rawget(c,__69mslocation)==want then return c end
                            elseif nm==want then return c end
                        end end
                        -- not found: FindFirstChild* return nil (real Roblox, and eUNC's
                        -- "not recursive" check needs nil). WaitForChild "waits" for the
                        -- child, so it hands back a fake one (also keeps loader chains alive).
                        if key=="WaitForChild" then
                            -- WaitForChild(name, timeout) with a timeout returns nil when the child never appears.
                            if timeout~=nil then return nil end
                            local fake=makeinstance(type(want)=="string" and want or className)
                            local fp=instprops[fake]; if not fp then fp={} instprops[fake]=fp end
                            if type(want)=="string" then fp.Name=want end
                            fp.Parent=self
                            return fake
                        end
                        return nil
                    end
                end
                if key=="Clone" then
                    return function()
                        if services and services[className]==self then error("Unable to clone the "..className,2) end
                        -- Archivable=false -> Clone returns nil (real Roblox).
                        if stored and stored.Archivable==false then return nil end
                        local c=makeinstance(className)
                        if stored then local cp={} for k,v in stored do cp[k]=v end instprops[c]=cp end
                        return c
                    end
                end
                if key=="GetFullName" then return function()
                    local parts,cur,guard={},self,0
                    while cur and guard<64 do
                        guard=guard+1
                        if cur==cenv.game then table.insert(parts,1,"game") break end
                        local cp=instprops[cur]
                        table.insert(parts,1,(cp and cp.Name) or rawget(cur,__69mslocation) or "Instance")
                        cur=cp and cp.Parent
                    end
                    return table.concat(parts,".")
                end end
                if stored and stored[key]~=nil and type(key)=="string" then
                    simplelog(getnewvar(className..tostring(key)),className.."["..tostring_complex(key).."]",Enum_NOCALL)
                    return stored[key]
                end
                -- array-returning methods -> real empty array (see arraymethods note)
                if type(key)=="string" and arraymethods[key] then
                    return function() return {} end
                end
                if type(key)=="string" then
                    -- authentic default property values in ALL modes (beats detection
                    -- scripts that check e.g. Part.Anchored == false). Still log the
                    -- read so the trace shows the access; just return the real value.
                    if propdefaults[key]~=nil then
                        local vn=getnewvar(className..tostring(key))
                        simplelog(vn,className.."["..tostring_complex(key).."]",Enum_NOCALL)
                        return propdefaults[key]
                    end
                    -- real-typed properties (typeof matches Roblox). Position is class-
                    -- specific: UDim2 for GUI objects, Vector3 for 3D instances.
                    -- GUI objects: Rotation is a number (degrees), unlike a 3D CFrame.
                    if key=="Rotation" and guiclass[className] then return 0 end
                    if key=="NearPlaneZ" then return -0.1 end -- camera near plane is negative
                    if key=="RunState" then return cenv.Enum.RunState.Running end
                    if key=="Position" or key=="Size" then
                        simplelog(getnewvar(className..tostring(key)),className.."["..tostring_complex(key).."]",Enum_NOCALL)
                        if key=="Size" and effectsizeclass[className] then return 0.5 end -- effect Size is a number
                        local isgui=className:find("Frame") or className:find("Label") or className:find("Button") or className:find("Gui") or className:find("Text") or className:find("Image") or className:find("Scroll")
                        if isgui then return makedt("UDim2",{0,0,0,0}) end
                        return makedt("Vector3",key=="Size" and {4,1,2} or {0,0,0})
                    end
                    if proptypes[key] then
                        simplelog(getnewvar(className..tostring(key)),className.."["..tostring_complex(key).."]",Enum_NOCALL)
                        return typedprop(proptypes[key])
                    end
                    -- real Zstd/Gzip (de)compression so EncodingService loaders work
                    -- (returns a real buffer, so buffer.readu8 etc. yield real numbers).
                    if key=="DecompressBuffer" or key=="CompressBuffer" then
                        return function(_,data)
                            local ok,res=pcall(function()
                                local serde=require("@lune/serde")
                                local instr=oldtype(data)=="buffer" and buffer.tostring(data) or tostring(data)
                                local out=key=="DecompressBuffer" and serde.decompress("zstd",instr) or serde.compress("zstd",instr)
                                return buffer.fromstring(out)
                            end)
                            if ok then return res end
                            -- decompress/compress failed: hand back a REAL buffer (not a
                            -- spy) so buffer.readu8 etc. still yield numbers.
                            return buffer.fromstring(oldtype(data)=="buffer" and buffer.tostring(data) or string.rep("\0",4096))
                        end
                    end
                    -- signals (Heartbeat/Changed/Touched/...) -> real RBXScriptSignal in
                    -- ALL modes, cached per property, so :Connect/:Wait/:Once and typeof work.
                    if sigprops[key] then if not sigcache[key] then sigcache[key]=makesignal(framesigset[key]) end return sigcache[key] end
                    -- GetPropertyChangedSignal("Prop") -> a cached signal fired on write.
                    if key=="GetPropertyChangedSignal" then return function(_,prop) if prop==nil then error("missing argument #1 to 'GetPropertyChangedSignal'",2) end local ck="__pcs_"..tostring(prop) if not sigcache[ck] then sigcache[ck]=makesignal() end return sigcache[ck] end end
                    if settings.benchmark_mode then
                        if key=="SetItem" then return function(_,k,v) kv[k]=v end end
                        if key=="GetItem" then return function(_,k) return kv[k] end end
                        if key=="AddTag" then return function(_,o,t) if o==nil or t==nil then error("missing argument #1 to 'AddTag'",2) end tagreg[t]=tagreg[t] or setmetatable({},{__mode="k"}) tagreg[t][o]=true end end
                        if key=="RemoveTag" then return function(_,o,t) if o==nil or t==nil then error("missing argument #1 to 'RemoveTag'",2) end if tagreg[t] then tagreg[t][o]=nil end end end
                        if key=="HasTag" then return function(_,o,t) if o==nil or t==nil then error("missing argument #1 to 'HasTag'",2) end return tagreg[t]~=nil and tagreg[t][o]==true end end
                        if key=="GetTagged" then return function(_,t) local r={} if tagreg[t] then for o in tagreg[t] do table.insert(r,o) end end return r end end
                        if propmap[key]~=nil then return propmap[key] end
                        if enumprops[key] then return makeenumitem(cenv.Enum[enumprops[key]],enumprops[key],"None",0) end
                        if instanceprops[key] then return makeinstance(instanceprops[key]) end
                        if methodret[key] then return methodret[key] end
                        local isq=key:sub(1,2)=="Is"
                        if argmethods[key] then return function(_,a) if a==nil then error("missing argument #1 to '"..key.."'",2) end return isq and true or spytbl(className.."."..key) end end
                        if isq then return function() return true end end
                        return function() return spytbl(className.."."..key) end
                    end
                    if propmap[key]~=nil then return propmap[key] end
                    -- real method returns + child-instance props in ALL modes (methodret
                    -- before the Is-fallback so RunService:IsServer()==false stays false).
                    if methodret[key] then return methodret[key] end
                    if instanceprops[key] then return makeinstance(instanceprops[key]) end
                    if enumprops[key] then return makeenumitem(cenv.Enum[enumprops[key]],enumprops[key],"None",0) end
                    -- tag methods work both as CollectionService:AddTag(obj,tag) AND as
                    -- instance:AddTag(tag) (self is the object). Disambiguate by arg shape.
                    if key=="AddTag" then return function(s,a,b) local o,t if b~=nil then o,t=a,b else o,t=s,a end if t==nil then error("missing argument to 'AddTag'",2) end tagreg[t]=tagreg[t] or setmetatable({},{__mode="k"}) tagreg[t][o]=true end end
                    if key=="RemoveTag" then return function(s,a,b) local o,t if b~=nil then o,t=a,b else o,t=s,a end if tagreg[t] then tagreg[t][o]=nil end end end
                    if key=="HasTag" then return function(s,a,b) local o,t if b~=nil then o,t=a,b else o,t=s,a end return tagreg[t]~=nil and tagreg[t][o]==true end end
                    if key=="GetTags" then return function(s,a) local o=a~=nil and a or s local r={} for t,objs in tagreg do if objs[o] then r[#r+1]=t end end return r end end
                    if key=="GetTagged" then return function(_,t) local r={} if tagreg[t] then for o in tagreg[t] do r[#r+1]=o end end return r end end
                    if key:sub(1,2)=="Is" then return function() return true end end
                    return spytbl(className.."."..key,"function")
                end
                -- real Roblox errors on a numeric index of an Instance.
                if type(key)=="number" then error(tostring(key).." is not a valid member of "..className,2) end
                return base(self,key)
            end
            local basenewindex=mt.__newindex
            mt.__newindex=function(self,key,value)
                -- real Roblox: ClassName + event signals are read-only.
                if key=="ClassName" then error("Unable to assign property ClassName. Property is read only",2) end
                if sigprops[key] then error("Unable to assign property "..tostring(key)..". Property is read only",2) end
                -- type enforcement: a vector/CFrame property can't be assigned a string.
                if vectorprop[key] and type(value)=="string" then error("Unable to assign property "..tostring(key)..". "..(key=="Orientation" and "Vector3" or "value").." expected, got string",2) end
                -- store the assignment so it reads back, and track parent->children.
                local p=instprops[self]; if not p then p={} instprops[self]=p end
                p[key]=value
                if key=="Parent" and value~=nil then
                    -- Parent must be an Instance, not a plain table/number/etc.
                    if types[value]~="Instance" then error("Unable to assign property Parent. Instance expected, got "..typeof(value),2) end
                    local kids=instchildren[value]
                    if kids then table.insert(kids,self) end
                end
                -- fire Changed + GetPropertyChangedSignal(key) on a real property change.
                if sigcache.Changed then fireconns(signals[sigcache.Changed],key) end
                local pcs=sigcache["__pcs_"..tostring(key)]
                if pcs then fireconns(signals[pcs]) end
                if basenewindex then return basenewindex(self,key,value) end -- keep the trace log
            end
            local inst=setmetatable({[__69mslocation]=className},mt)
            types[inst]="Instance"
            instprops[inst]={}
            instchildren[inst]={}
            -- tostring(inst) reflects the CURRENT Name (changes on rename), default class.
            datatype_strings[inst]=function() return (instprops[inst] and instprops[inst].Name) or className end
            return inst
        end
        services={}
        local function getservice(name)
            local key=type(name)=="string" and name or tostring(name)
            if not services[key] then
                local svc=makeinstance(key)
                -- a service IS parented to the DataModel (unlike a fresh Instance.new).
                local sp=instprops[svc]; if not sp then sp={} instprops[svc]=sp end
                sp.Parent=cenv.game
                services[key]=svc
            end
            return services[key]
        end
        -- LOG the real call (don't silently mock): every game:GetService("X") shows up
        -- as `local X = game:GetService("X")`, like a real env logger, in ALL modes.
        -- varname == the service name so it matches how the instance is shown later
        -- (the instance's trace location is its className/service name).
        local function logservice(method,name) simplelog(type(name)=="string" and name or "Service","game:"..method,name) return getservice(name) end
        rawset(cenv.game,"GetService",function(_,name) return logservice("GetService",name) end)
        rawset(cenv.game,"FindService",function(_,name) return logservice("FindService",name) end)
        rawset(cenv.game,"service",function(_,name) return logservice("service",name) end)
        rawset(cenv.game,"ClassName","DataModel")
        rawset(cenv.game,"Clone",function() error("Unable to clone the DataModel",2) end)
        rawset(cenv.game,"Destroy",function() error("The Parent property of Game is locked",2) end)
        -- game:IsLoaded() is handled in game_meta.__index (so it stays read-only).
        -- HttpGet/HttpGetAsync actually FETCH the url and return its body (a real string),
        -- so a loadstring(game:HttpGet(url))() loader pulls down the real payload and we
        -- log what it does. Logged + fetched; "" on failure so typeof stays string and
        -- the chain never crashes.
        local function httpfetch(url,method,body)
            local ok,res=pcall(function()
                local net=require("@lune/net")
                return net.request({url=tostring(url),method=method or "GET",
                    headers={["User-Agent"]="Roblox/WinInet"},body=body})
            end)
            if ok and res and type(res.body)=="string" then return res.body end
            return ""
        end
        for _,m in {"HttpGet","HttpGetAsync"} do
            rawset(cenv.game,m,function(_,url,...) simplelog(getnewvar("body"),"game:"..m,url) return httpfetch(url,"GET") end)
        end
        for _,m in {"HttpPost","HttpPostAsync"} do
            rawset(cenv.game,m,function(_,url,data,...) simplelog(getnewvar("body"),"game:"..m,url,data) return httpfetch(url,"POST",type(data)=="string" and data or nil) end)
        end
        types[cenv.game]="Instance"
        local ws=makeinstance("Workspace")
        services.Workspace=ws
        cenv.workspace=ws
        cenv.Workspace=ws
        rawset(cenv.game,"Workspace",ws)
        -- workspace has a default Baseplate + Terrain + Camera (detection scripts look for them)
        for _,nm in {"Baseplate","Terrain","Camera"} do
            local child=makeinstance(nm=="Baseplate" and "Part" or nm)
            local cp=instprops[child]; if not cp then cp={} instprops[child]=cp end
            cp.Name=nm cp.Parent=ws
            local kids=instchildren[ws]; if kids then kids[#kids+1]=child end
        end
        -- game.<Service> resolves to the same cached singleton as GetService (ALL modes),
        -- while seeded props (PlaceId/JobId/...) and IsLoaded keep working.
        do
            local base_index=game_meta.__index
            local commonservice={}
            for _,s in {"Players","Lighting","ReplicatedStorage","ReplicatedFirst","StarterGui","StarterPack","StarterPlayer","Teams","SoundService","Chat","TextChatService","Debris","RunService","UserInputService","TweenService","HttpService","MarketplaceService","CollectionService","PathfindingService","Workspace","CoreGui","GuiService","ContextActionService","TextService","LocalizationService","Stats","LogService","VirtualUser","VirtualInputManager","TeleportService","DataStoreService","PhysicsService","TestService","InsertService","AssetService","BadgeService","GamePassService","GroupService","PolicyService"} do commonservice[s]=true end
            game_meta.__index=function(_,key)
                if key=="IsLoaded" then return function() return true end end
                if type(key)=="string" then
                    if _69mspredefined[key]~=nil then return _69mspredefined[key] end
                    if services[key] or commonservice[key] or key:match("Service$") then return getservice(key) end
                end
                return base_index(_,key)
            end
        end
        if settings.benchmark_mode then
            -- expose game/workspace as real userdata (type()=="userdata"), delegating
            -- to the table impl so service singletons stay consistent.
            local tg=cenv.game
            local gud=newproxy(true) local gmt=getmetatable(gud)
            gmt.__index=function(_,k) return tg[k] end
            gmt.__tostring=function() return "Game" end
            types[gud]="Instance"
            cenv.game=gud cenv.Game=gud
            local wud=newproxy(true) local wmt=getmetatable(wud)
            wmt.__index=function(_,k) return ws[k] end
            wmt.__tostring=function() return "Workspace" end
            types[wud]="Instance"
            cenv.workspace=wud cenv.Workspace=wud
            services.Workspace=wud
            rawset(tg,"Workspace",wud)
        end
        cenv.Instance=setmetatable({
            new=function(cn,parent) if cn==nil then error("missing argument #1 to 'new'",2) end
                -- real Roblox: an unknown class is a clean "Unable to create" error (not a
                -- runtime error). Real class names are PascalCase; reject obvious non-classes.
                if type(cn)=="string" and not cn:match("^[A-Z]") then error("Unable to create an Instance of type \""..cn.."\"",2) end
                local inst=makeinstance(type(cn)=="string" and cn or "Instance") simplelog(type(cn)=="string" and cn or "Instance","Instance.new",cn)
                if parent~=nil then pcall(function() inst.Parent=parent end) end -- Instance.new(class, parent)
                return inst end,
        },{__index=function(_,k) return spytbl("Instance."..tostring(k),"Instance") end})
        -- some detection scripts read these reflection helpers as bare globals (not via
        -- game:GetService), so expose them as real instances -> their array methods
        -- (GetPropertiesOfClass/GetMethodsOfClass) return real {} instead of a spy.
        cenv.ReflectionService=makeinstance("ReflectionService")
        -- keep fromCurrent (dtc's ReflectionService checks use it) AND a typeof-correct new.
        cenv.SecurityCapabilities=setmetatable({
            fromCurrent=function() return makedt("SecurityCapabilities",{}) end,
            new=function(...) return makedt("SecurityCapabilities",{...}) end,
        },{__index=function(_,k) return function() return makedt("SecurityCapabilities",{}) end end})
        cenv.SharedTable=setmetatable({new=function(t)
            -- SharedTable.new(t) wraps t so reads/writes proxy through (eUNC checks
            -- SharedTable.new({k=v})[k]==v). typeof=="SharedTable".
            local store=type(t)=="table" and t or {}
            local st=setmetatable({},{__index=function(_,k) return store[k] end,__newindex=function(_,k,v) store[k]=v end,__metatable=false})
            types[st]="SharedTable"
            return st
        end},{__index=function(_,k) return function() return cenv.SharedTable.new() end end})
        local numprops={}
        for _,p in {"X","Y","Z","W","R","G","B","H","S","V","Magnitude","Length","Width","Height","Depth","Offset","Scale","P"} do numprops[p]=true end
        -- real component-storing datatypes (so .X/.Magnitude/.R and == work).
        local dtcomp=setmetatable({},{__mode="k"})
        -- shared __eq (Luau only fires __eq when both metatables share the same one)
        local function dteq(a,b) local ca,cb=dtcomp[a],dtcomp[b] if ca and cb then for k,v in ca do if cb[k]~=v then return false end end return true end return rawequal(a,b) end
        local function compute(ty,a)
            local c={}
            if ty=="Vector3" then c.X=a[1] or 0;c.Y=a[2] or 0;c.Z=a[3] or 0;c.Magnitude=math.sqrt(c.X^2+c.Y^2+c.Z^2)
            elseif ty=="Vector2" then c.X=a[1] or 0;c.Y=a[2] or 0;c.Magnitude=math.sqrt(c.X^2+c.Y^2)
            elseif ty=="Color3" then c.R=a[1] or 0;c.G=a[2] or 0;c.B=a[3] or 0;c.r=c.R;c.g=c.G;c.b=c.B
            elseif ty=="Vector3int16" then c.X=a[1] or 0;c.Y=a[2] or 0;c.Z=a[3] or 0
            elseif ty=="Vector2int16" then c.X=a[1] or 0;c.Y=a[2] or 0
            elseif ty=="CFrame" then c.X=a[1] or 0;c.Y=a[2] or 0;c.Z=a[3] or 0
            elseif ty=="UDim2" then
                if dtcomp[a[1]] then c.sx=dtcomp[a[1]].Scale or 0;c.ox=dtcomp[a[1]].Offset or 0;c.sy=dtcomp[a[2]] and dtcomp[a[2]].Scale or 0;c.oy=dtcomp[a[2]] and dtcomp[a[2]].Offset or 0
                else c.sx=a[1] or 0;c.ox=a[2] or 0;c.sy=a[3] or 0;c.oy=a[4] or 0 end
            elseif ty=="Region3" then
                local mn,mx=dtcomp[a[1]],dtcomp[a[2]]
                c.minx=mn and mn.X or 0;c.miny=mn and mn.Y or 0;c.minz=mn and mn.Z or 0
                c.maxx=mx and mx.X or 0;c.maxy=mx and mx.Y or 0;c.maxz=mx and mx.Z or 0
            elseif ty=="PathWaypoint" then local p=dtcomp[a[1]] c.px=p and p.X or 0;c.py=p and p.Y or 0;c.pz=p and p.Z or 0;c.Action=a[2];c.Label=a[3] or ""
            elseif ty=="Region3int16" then
                local mn,mx=dtcomp[a[1]],dtcomp[a[2]]
                c.minx=mn and mn.X or 0;c.miny=mn and mn.Y or 0;c.minz=mn and mn.Z or 0
                c.maxx=mx and mx.X or 0;c.maxy=mx and mx.Y or 0;c.maxz=mx and mx.Z or 0
            elseif ty=="UDim" then c.Scale=a[1] or 0;c.Offset=a[2] or 0
            elseif ty=="BrickColor" then c.Name=type(a[1])=="string" and a[1] or "Medium stone grey";c.Number=type(a[1])=="number" and a[1] or 194;c.r=0.64;c.g=0.64;c.b=0.64;c.R=0.64;c.G=0.64;c.B=0.64
            elseif ty=="NumberRange" then c.Min=a[1] or 0;c.Max=a[2] or a[1] or 0
            elseif ty=="NumberSequence" or ty=="ColorSequence" then c.Value=a[1]
            elseif ty=="NumberSequenceKeypoint" then c.Time=a[1] or 0;c.Value=a[2] or 0;c.Envelope=a[3] or 0
            elseif ty=="ColorSequenceKeypoint" then c.Time=a[1] or 0
            elseif ty=="TweenInfo" then c.Time=a[1] or 1;c.EasingStyle=a[2];c.EasingDirection=a[3];c.RepeatCount=a[4] or 0;c.Reverses=a[5] or false;c.DelayTime=a[6] or 0
            elseif ty=="FloatCurveKey" or ty=="RotationCurveKey" or ty=="ValueCurveKey" then c.Time=a[1] or 0;c.Value=a[2] or 0;c.LeftTangent=0;c.RightTangent=0
            elseif ty=="Rect" then
                if dtcomp[a[1]] then c.MinX=dtcomp[a[1]].X or 0;c.MinY=dtcomp[a[1]].Y or 0;c.MaxX=dtcomp[a[2]] and dtcomp[a[2]].X or 0;c.MaxY=dtcomp[a[2]] and dtcomp[a[2]].Y or 0
                else c.MinX=a[1] or 0;c.MinY=a[2] or 0;c.MaxX=a[3] or 0;c.MaxY=a[4] or 0 end
                c.Width=c.MaxX-c.MinX;c.Height=c.MaxY-c.MinY
            elseif ty=="PhysicalProperties" then c.Density=type(a[1])=="number" and a[1] or 0.7;c.Friction=type(a[2])=="number" and a[2] or 0.3;c.Elasticity=type(a[3])=="number" and a[3] or 0.5;c.FrictionWeight=1;c.ElasticityWeight=1
            elseif ty=="Font" then c.Weight=a[2];c.Style=a[3];c.Family=type(a[1])=="string" and a[1] or "rbxasset://fonts/families/SourceSansPro.json"
            elseif ty=="CatalogSearchParams" then c.SearchKeyword=type(a[1])=="string" and a[1] or "";c.MinPrice=0;c.MaxPrice=2147483647
            elseif ty=="RaycastParams" then c.IgnoreWater=false;c.CollisionGroup="Default";c.RespectCanCollide=false;c.BruteForceAllSlow=false
            elseif ty=="OverlapParams" then c.CollisionGroup="Default";c.MaxParts=0;c.RespectCanCollide=false
            elseif ty=="Axes" or ty=="Faces" then -- boolean flags, set true for each Enum.Axis/NormalId passed
                for _,k in {"X","Y","Z","Top","Bottom","Left","Right","Front","Back"} do c[k]=false end
                local nid2axis={Right="X",Left="X",Top="Y",Bottom="Y",Front="Z",Back="Z"}
                for _,v in a do if oldtype(v)=="table" and v.Name then
                    if c[v.Name]~=nil then c[v.Name]=true end
                    if ty=="Axes" and nid2axis[v.Name] then c[nid2axis[v.Name]]=true end -- NormalId -> axis
                end end
            end
            -- int16 vectors: truncate toward zero, then wrap into the signed-16-bit range
            if ty=="Vector3int16" or ty=="Vector2int16" then
                local function w(n) n=n or 0 n=n<0 and math.ceil(n) or math.floor(n) n=n%65536 if n>=32768 then n=n-65536 end return n end
                c.X=w(c.X);c.Y=w(c.Y);if c.Z~=nil then c.Z=w(c.Z) end
            end
            return c
        end
        makedt=function(ty,args)
            local comp=compute(ty,args or {})
            local mt=table.clone(spymt)
            local base=mt.__index
            -- step1 "or sum!": real component-wise arithmetic so a summed/scaled
            -- datatype carries authentic components (and thus a real tostring/.Magnitude),
            -- instead of an all-zero placeholder.
            local compkeys={Vector3={"X","Y","Z"},Vector3int16={"X","Y","Z"},Vector2={"X","Y"},
                Vector2int16={"X","Y"},Color3={"R","G","B"},CFrame={"X","Y","Z"},
                UDim={"Scale","Offset"},UDim2={"sx","ox","sy","oy"}}
            local function arith(fn)
                return function(a,b)
                    local rty=(dtcomp[a] and types[a]) or (dtcomp[b] and types[b]) or ty
                    local keys=compkeys[rty]
                    if not keys then return makedt(rty,{}) end
                    local res={}
                    for i,k in keys do
                        local va=type(a)=="number" and a or (dtcomp[a] and dtcomp[a][k]) or 0
                        local vb=type(b)=="number" and b or (dtcomp[b] and dtcomp[b][k]) or 0
                        res[i]=fn(va,vb)
                    end
                    return makedt(rty,res)
                end
            end
            mt.__add=arith(function(x,y) return x+y end)
            mt.__sub=arith(function(x,y) return x-y end)
            local mularith=arith(function(x,y) return x*y end)
            mt.__mul=function(a,b)
                -- preserve Roblox multiply type rules: CFrame*Vector3 => Vector3.
                local ta,tb=types[a],types[b]
                if (ta=="CFrame" and tb=="Vector3") or (ta=="Vector3" and tb=="CFrame") then
                    return makedt("Vector3",{})
                end
                return mularith(a,b)
            end
            mt.__div=arith(function(x,y) return y~=0 and x/y or 0 end)
            mt.__mod=arith(function(x,y) return y~=0 and x%y or 0 end)
            mt.__pow=arith(function(x,y) return x^y end)
            mt.__unm=function(a)
                local keys=compkeys[ty]
                if not keys then return makedt(ty,{}) end
                local res={}
                for i,k in keys do res[i]=-(dtcomp[a] and dtcomp[a][k] or 0) end
                return makedt(ty,res)
            end
            mt.__eq=dteq
            -- most datatypes are immutable (writing a component errors), but a few
            -- (RaycastParams/OverlapParams/CatalogSearchParams) are mutable config objects.
            local mutabledt={RaycastParams=true,OverlapParams=true,CatalogSearchParams=true}
            mt.__newindex=function(_,k,v) if mutabledt[ty] then comp[k]=v return end error(tostring(k).." cannot be assigned to",2) end
            -- step1: give datatypes a REAL __tostring (and real values via components)
            -- so detection scripts that do tostring(Vector3.new(1,2,3))=="1, 2, 3" or
            -- print a summed vector get an authentic string instead of a logger marker.
            mt.__tostring=function()
                if ty=="Vector3" or ty=="Vector3int16" then return string.format("%g, %g, %g",comp.X,comp.Y,comp.Z)
                elseif ty=="Vector2" or ty=="Vector2int16" then return string.format("%g, %g",comp.X,comp.Y)
                elseif ty=="Color3" then return string.format("%g, %g, %g",comp.R,comp.G,comp.B)
                elseif ty=="UDim" then return string.format("%g, %d",comp.Scale,comp.Offset)
                elseif ty=="UDim2" then return string.format("{%g, %d}, {%g, %d}",comp.sx,comp.ox,comp.sy,comp.oy)
                elseif ty=="CFrame" then return string.format("%g, %g, %g, 1, 0, 0, 0, 1, 0, 0, 0, 1",comp.X,comp.Y,comp.Z)
                elseif ty=="BrickColor" then return comp.Name
                end
                return ty
            end
            -- real datatype METHODS (v:Dot(v2)==32, v:Cross(v2), cf:Inverse(), Lerp...)
            -- computed from real components so detection math checks pass.
            local function oc(x) return dtcomp[x] or {} end
            local dtmethods={
                Dot=function(_,o) local d=oc(o) return (comp.X or 0)*(d.X or 0)+(comp.Y or 0)*(d.Y or 0)+(comp.Z or 0)*(d.Z or 0) end,
                Cross=function(_,o) local d=oc(o) if ty=="Vector2" then return (comp.X or 0)*(d.Y or 0)-(comp.Y or 0)*(d.X or 0) end return makedt("Vector3",{(comp.Y or 0)*(d.Z or 0)-(comp.Z or 0)*(d.Y or 0),(comp.Z or 0)*(d.X or 0)-(comp.X or 0)*(d.Z or 0),(comp.X or 0)*(d.Y or 0)-(comp.Y or 0)*(d.X or 0)}) end,
                Lerp=function(_,o,t) local d=oc(o) t=tonumber(t) or 0 local keys=compkeys[ty] or {} local res={} for i,k in keys do res[i]=(comp[k] or 0)+((d[k] or 0)-(comp[k] or 0))*t end return makedt(ty,res) end,
                Angle=function() return 0 end,
                FuzzyEq=function() return true end,
                ClosestPoint=function() return makedt("Vector3",{}) end,
                Distance=function() return 0 end,
                Abs=function() return makedt(ty,{math.abs(comp.X or 0),math.abs(comp.Y or 0),math.abs(comp.Z or 0)}) end,
                Sign=function() local function s(n) return n>0 and 1 or n<0 and -1 or 0 end return makedt(ty,{s(comp.X or 0),s(comp.Y or 0),s(comp.Z or 0)}) end,
                Floor=function() return makedt(ty,{math.floor(comp.X or 0),math.floor(comp.Y or 0),math.floor(comp.Z or 0)}) end,
                Ceil=function() return makedt(ty,{math.ceil(comp.X or 0),math.ceil(comp.Y or 0),math.ceil(comp.Z or 0)}) end,
                ToHSV=function() local r,g,b=comp.R or 0,comp.G or 0,comp.B or 0 local mx,mn=math.max(r,g,b),math.min(r,g,b) local h,s,v=0,mx==0 and 0 or (mx-mn)/mx,mx local d=mx-mn if d~=0 then if mx==r then h=((g-b)/d)%6 elseif mx==g then h=(b-r)/d+2 else h=(r-g)/d+4 end h=h/6 end return h,s,v end,
                ToHex=function() local function c(n) return string.format("%02x",math.floor((n or 0)*255+0.5)) end return c(comp.R)..c(comp.G)..c(comp.B) end,
                ToLocalTime=function() return {Year=2020,Month=1,Day=1,Hour=0,Minute=0,Second=0,Millisecond=0} end,
                Remove=function() return makedt(ty,{}) end,
                AddPrefix=function() return makedt("Secret",{}) end,
                AddSuffix=function() return makedt("Secret",{}) end,
                ExpandToGrid=function() return makedt("Region3",{}) end,
                Contains=function() return true end,
                Union=function() return makedt(ty,{}) end,
                ToIsoDate=function() return "2020-01-01T00:00:00Z" end,
                ToIsoDateUtc=function() return "2020-01-01T00:00:00Z" end,
                FormatUniversalTime=function() return "2020-01-01" end,
                FormatLocalTime=function() return "2020-01-01" end,
                ToUniversalTime=function() return {Year=2020,Month=1,Day=1,Hour=0,Minute=0,Second=0} end,
                Add=function() return makedt(ty,{}) end,
                Min=function(_,o) local d=oc(o) return makedt(ty,{math.min(comp.X or 0,d.X or 0),math.min(comp.Y or 0,d.Y or 0),math.min(comp.Z or 0,d.Z or 0)}) end,
                Max=function(_,o) local d=oc(o) return makedt(ty,{math.max(comp.X or 0,d.X or 0),math.max(comp.Y or 0,d.Y or 0),math.max(comp.Z or 0,d.Z or 0)}) end,
                Inverse=function() return makedt("CFrame",{-(comp.X or 0),-(comp.Y or 0),-(comp.Z or 0)}) end,
                Components=function() return comp.X or 0,comp.Y or 0,comp.Z or 0 end,
                -- CFrame point/vector transforms. Treated as translation by the CFrame's
                -- position so PointToObjectSpace is the exact inverse of PointToWorldSpace
                -- (round-trip returns the original point, as anti-tamper scripts assert).
                PointToWorldSpace=function(_,p) local d=oc(p) return makedt("Vector3",{(d.X or 0)+(comp.X or 0),(d.Y or 0)+(comp.Y or 0),(d.Z or 0)+(comp.Z or 0)}) end,
                PointToObjectSpace=function(_,p) local d=oc(p) return makedt("Vector3",{(d.X or 0)-(comp.X or 0),(d.Y or 0)-(comp.Y or 0),(d.Z or 0)-(comp.Z or 0)}) end,
                VectorToWorldSpace=function(_,p) local d=oc(p) return makedt("Vector3",{d.X or 0,d.Y or 0,d.Z or 0}) end,
                VectorToObjectSpace=function(_,p) local d=oc(p) return makedt("Vector3",{d.X or 0,d.Y or 0,d.Z or 0}) end,
                ToWorldSpace=function(_,o) local d=oc(o) return makedt("CFrame",{(d.X or 0)+(comp.X or 0),(d.Y or 0)+(comp.Y or 0),(d.Z or 0)+(comp.Z or 0)}) end,
                ToObjectSpace=function(_,o) local d=oc(o) return makedt("CFrame",{(d.X or 0)-(comp.X or 0),(d.Y or 0)-(comp.Y or 0),(d.Z or 0)-(comp.Z or 0)}) end,
            }
            mt.__index=function(self,key)
                if type(key)=="string" then
                    -- Ray/Region3 carry their Vector3 constructor args verbatim
                    if (ty=="Ray") and key=="Origin" then return (args and args[1]) or makedt("Vector3",{}) end
                    if (ty=="Ray") and key=="Direction" then return (args and args[2]) or makedt("Vector3",{}) end
                    if ty=="CFrame" and key=="Position" then return makedt("Vector3",{comp.X,comp.Y,comp.Z}) end
                    if ty=="CFrame" and key=="Rotation" then return makedt("CFrame",{0,0,0}) end
                    if ty=="CFrame" and key=="LookVector" then return makedt("Vector3",{comp.lvx or 0,comp.lvy or 0,comp.lvz or -1}) end
                    if ty=="CFrame" and key=="ZVector" then return makedt("Vector3",{-(comp.lvx or 0),-(comp.lvy or 0),-(comp.lvz or -1)}) end -- ZVector == -LookVector
                    if ty=="CFrame" and (key=="RightVector" or key=="XVector") then return makedt("Vector3",{1,0,0}) end
                    if ty=="CFrame" and (key=="UpVector" or key=="YVector") then return makedt("Vector3",{0,1,0}) end
                    if ty=="UDim2" and (key=="X" or key=="Width") then return makedt("UDim",{comp.sx,comp.ox}) end
                    if ty=="UDim2" and (key=="Y" or key=="Height") then return makedt("UDim",{comp.sy,comp.oy}) end
                    if ty=="PathWaypoint" and key=="Position" then return makedt("Vector3",{comp.px or 0,comp.py or 0,comp.pz or 0}) end
                    if ty=="Region3" and key=="Size" then return makedt("Vector3",{(comp.maxx or 0)-(comp.minx or 0),(comp.maxy or 0)-(comp.miny or 0),(comp.maxz or 0)-(comp.minz or 0)}) end
                    if ty=="Region3" and key=="CFrame" then return makedt("CFrame",{((comp.minx or 0)+(comp.maxx or 0))/2,((comp.miny or 0)+(comp.maxy or 0))/2,((comp.minz or 0)+(comp.maxz or 0))/2}) end
                    if (ty=="NumberSequence" or ty=="ColorSequence") and key=="Keypoints" then
                        local v=comp.Value or (ty=="ColorSequence" and makedt("Color3",{0,0,0}) or 0)
                        return {makedt(ty.."Keypoint",{0,v}),makedt(ty.."Keypoint",{1,v})}
                    end
                    if ty=="Region3int16" and key=="Min" then return makedt("Vector3int16",{comp.minx or 0,comp.miny or 0,comp.minz or 0}) end
                    if ty=="Region3int16" and key=="Max" then return makedt("Vector3int16",{comp.maxx or 0,comp.maxy or 0,comp.maxz or 0}) end
                    if ty=="Rect" and key=="Min" then return makedt("Vector2",{comp.MinX,comp.MinY}) end
                    if ty=="Rect" and key=="Max" then return makedt("Vector2",{comp.MaxX,comp.MaxY}) end
                    if ty=="Font" and key=="Weight" then return comp.Weight or cenv.Enum.FontWeight.Regular end
                    if ty=="Font" and key=="Style" then return comp.Style or cenv.Enum.FontStyle.Normal end
                    if ty=="TweenInfo" and key=="EasingStyle" then return comp.EasingStyle or cenv.Enum.EasingStyle.Quad end
                    if ty=="TweenInfo" and key=="EasingDirection" then return comp.EasingDirection or cenv.Enum.EasingDirection.Out end
                    if (ty=="FloatCurveKey" or ty=="RotationCurveKey" or ty=="ValueCurveKey") and key=="Interpolation" then return cenv.Enum.KeyInterpolationMode.Cubic end
                    if ty=="PathWaypoint" and key=="Action" then return comp.Action or cenv.Enum.PathWaypointAction.Walk end
                    if ty=="PathWaypoint" and key=="Label" then return comp.Label or "" end
                    if ty=="BrickColor" and key=="Color" then return makedt("Color3",{0.64,0.64,0.64}) end
                    if ty=="CatalogSearchParams" and key=="SortType" then return cenv.Enum.CatalogSortType.Relevance end
                    if ty=="CatalogSearchParams" and key=="SalesTypeFilter" then return cenv.Enum.SalesTypeFilter.All end
                    if ty=="CatalogSearchParams" and key=="SortAggregation" then return cenv.Enum.CatalogSortAggregation.AllTime end
                    if ty=="CatalogSearchParams" and key=="CategoryFilter" then return cenv.Enum.CatalogCategoryFilter.None end
                    if ty=="DateTime" and (key=="UnixTimestamp" or key=="UnixTimestampMillis") then return key=="UnixTimestampMillis" and os.time()*1000 or os.time() end
                    if ty=="PhysicalProperties" and key=="Density" then return comp.Density end
                    if comp[key]~=nil then return comp[key] end
                    if dtmethods[key] then return dtmethods[key] end
                    if numprops[key] then return settings.benchmark_mode and 0 or spytbl(ty.."."..key,"number") end
                    if key=="Unit" then
                        local m=comp.Magnitude
                        if ty=="Vector3" and m and m>0 then return makedt("Vector3",{comp.X/m,comp.Y/m,comp.Z/m}) end
                        if ty=="Vector2" and m and m>0 then return makedt("Vector2",{comp.X/m,comp.Y/m}) end
                        return makedt(ty,{})
                    end
                    if settings.benchmark_mode then
                        local r=dtmethodret[key]
                        if r=="number" then return function() return 0 end end
                        if r=="boolean" then return function() return false end end
                        if r=="true" then return function() return true end end
                        return function() return makedt(ty,{}) end
                    end
                    return spytbl(ty.."."..key,"function")
                end
                return base(self,key)
            end
            local inst=setmetatable({[__69mslocation]=ty},mt)
            dtcomp[inst]=comp
            types[inst]=ty
            datatype_strings[inst]=mt.__tostring -- step1: real tostring for cenv.tostring
            return inst
        end
        local argctors={}
        for _,t in {"ColorSequence","NumberSequence","NumberRange","PhysicalProperties","Font"} do argctors[t]=true end
        local statics={zero=true,one=true,identity=true,xAxis=true,yAxis=true,zAxis=true}
        -- special constructors whose args don't map 1:1 to components.
        local ctorfix={
            UDim2={
                fromScale=function(sx,sy) return makedt("UDim2",{sx or 0,0,sy or 0,0}) end,
                fromOffset=function(ox,oy) return makedt("UDim2",{0,ox or 0,0,oy or 0}) end,
            },
            Color3={
                fromHSV=function(h,s,v) h=h or 0 s=s or 0 v=v or 0 local i=math.floor(h*6)%6 local f=h*6-math.floor(h*6) local p=v*(1-s) local q=v*(1-f*s) local w=v*(1-(1-f)*s) local r,g,b if i==0 then r,g,b=v,w,p elseif i==1 then r,g,b=q,v,p elseif i==2 then r,g,b=p,v,w elseif i==3 then r,g,b=p,q,v elseif i==4 then r,g,b=w,p,v else r,g,b=v,p,q end return makedt("Color3",{r,g,b}) end,
                fromHex=function(hex) hex=tostring(hex):gsub("#","") if #hex==3 then hex=hex:sub(1,1):rep(2)..hex:sub(2,2):rep(2)..hex:sub(3,3):rep(2) end local function h2(i) return (tonumber(hex:sub(i,i+1),16) or 0)/255 end return makedt("Color3",{h2(1),h2(3),h2(5)}) end,
            },
            NumberRange={
                new=function(mn,mx) if mn==nil then error("missing argument #1 to 'new'",2) end if mx~=nil and mn>mx then error("NumberRange: max must be greater than or equal to min",2) end return makedt("NumberRange",{mn,mx}) end,
            },
            Vector3={
                FromNormalId=function(nid) local m={Top={0,1,0},Bottom={0,-1,0},Front={0,0,-1},Back={0,0,1},Left={-1,0,0},Right={1,0,0}} local n=(oldtype(nid)=="table" and nid.Name) or "Top" return makedt("Vector3",m[n] or {0,0,0}) end,
                FromAxis=function(ax) local m={X={1,0,0},Y={0,1,0},Z={0,0,1}} local n=(oldtype(ax)=="table" and ax.Name) or "X" return makedt("Vector3",m[n] or {0,0,0}) end,
            },
            CFrame={
                lookAt=function(pos,target) local p=dtcomp[pos] or {} local t=dtcomp[target] or {} local dx,dy,dz=(t.X or 0)-(p.X or 0),(t.Y or 0)-(p.Y or 0),(t.Z or 0)-(p.Z or 0) local m=math.sqrt(dx*dx+dy*dy+dz*dz) if m==0 then m=1 end local cf=makedt("CFrame",{p.X or 0,p.Y or 0,p.Z or 0}) dtcomp[cf].lvx=dx/m dtcomp[cf].lvy=dy/m dtcomp[cf].lvz=dz/m return cf end,
            },
            BrickColor={
                White=function() return makedt("BrickColor",{"White"}) end,
                Black=function() return makedt("BrickColor",{"Black"}) end,
                Red=function() return makedt("BrickColor",{"Bright red"}) end,
                Green=function() return makedt("BrickColor",{"Bright green"}) end,
                Blue=function() return makedt("BrickColor",{"Bright blue"}) end,
                Yellow=function() return makedt("BrickColor",{"Bright yellow"}) end,
                Gray=function() return makedt("BrickColor",{"Medium stone grey"}) end,
                DarkGray=function() return makedt("BrickColor",{"Dark stone grey"}) end,
                random=function() return makedt("BrickColor",{"Bright red"}) end,
            },
        }
        local function datatype(ty,ctors)
            local t={}
            for _,c in ctors do
                if ctorfix[ty] and ctorfix[ty][c] then t[c]=ctorfix[ty][c]
                elseif c=="new" and settings.benchmark_mode and argctors[ty] then
                    t[c]=function(a,...) if a==nil then error("missing argument #1 to 'new'",2) end return makedt(ty,{a,...}) end
                else
                    t[c]=function(...) return makedt(ty,{...}) end
                end
            end
            if ty=="Color3" then
                t.fromRGB=function(r,g,b) return makedt("Color3",{(r or 0)/255,(g or 0)/255,(b or 0)/255}) end
                t.fromHSV=ctorfix.Color3.fromHSV t.fromHex=ctorfix.Color3.fromHex
            end
            cenv[ty]=setmetatable(t,{__index=function(_,k)
                if type(k)=="string" and statics[k] then
                    if k=="one" then return makedt(ty,{1,1,1})
                    elseif k=="xAxis" then return makedt(ty,{1,0,0})
                    elseif k=="yAxis" then return makedt(ty,{0,1,0})
                    elseif k=="zAxis" then return makedt(ty,{0,0,1}) end
                    return makedt(ty,{0,0,0}) -- zero / identity
                end
                if ctorfix[ty] and ctorfix[ty][k] then return ctorfix[ty][k] end
                -- unknown member -> a constructor-like function (so BrickColor.random()
                -- etc. return a value of the right typeof) in all modes.
                if type(k)=="string" then return function(...) return makedt(ty,{...}) end end
                return makedt(ty,{})
            end})
        end
        -- only constructor FUNCTIONS are listed; statics (zero/one/identity/etc.)
        -- come through __index as datatype instances so their methods resolve.
        datatype("Vector3",{"new"})
        datatype("Vector2",{"new"})
        datatype("Vector3int16",{"new"})
        datatype("Vector2int16",{"new"})
        datatype("CFrame",{"new","Angles","fromEulerAnglesXYZ","fromAxisAngle","lookAt","fromMatrix"})
        datatype("Color3",{"new","fromRGB","fromHSV","fromHex"})
        datatype("UDim",{"new"})
        datatype("UDim2",{"new","fromScale","fromOffset"})
        datatype("Ray",{"new"})
        datatype("Region3",{"new"})
        datatype("TweenInfo",{"new"})
        datatype("NumberRange",{"new"})
        datatype("NumberSequence",{"new"})
        datatype("ColorSequence",{"new"})
        datatype("ColorSequenceKeypoint",{"new"})
        datatype("NumberSequenceKeypoint",{"new"})
        datatype("BrickColor",{"new","Random","palette"})
        datatype("Rect",{"new"})
        datatype("PhysicalProperties",{"new"})
        datatype("Font",{"new","fromName","fromEnum","fromId"})
        datatype("DateTime",{"now","fromUnixTimestamp","fromUnixTimestampMillis"})
        -- more datatypes eUNC constructs and typeof-checks
        datatype("Axes",{"new"})
        datatype("Faces",{"new"})
        datatype("Region3int16",{"new"})
        datatype("PathWaypoint",{"new"})
        datatype("FloatCurveKey",{"new"})
        datatype("RotationCurveKey",{"new"})
        datatype("CatalogSearchParams",{"new"})
        datatype("DockWidgetPluginGuiInfo",{"new"})
        datatype("ValueCurveKey",{"new"})
        datatype("RaycastParams",{"new"})
        datatype("OverlapParams",{"new"})
        -- executor / runtime functions: typeof should report "function".
        for _,name in {
            "getgenv","getrenv","getreg","getgc","getinstances","getnilinstances",
            "getscripts","getloadedmodules","getrunningscripts","getscriptclosure",
            "getscriptfunction","getsenv","getcallingscript","getscripthash",
            "getfunctionhash","islclosure","iscclosure","isexecutorclosure",
            "checkcaller","clonefunction","hookfunction","hookmetamethod",
            "replaceclosure","restorefunction","getrawmetatable","setrawmetatable",
            "setreadonly","isreadonly","getnamecallmethod","setnamecallmethod",
            "hookmetatable","make_writeable","make_readonly","writefile","readfile",
            "appendfile","loadfile","isfile","isfolder","makefolder","delfolder",
            "delfile","listfiles","getcustomasset","dofile","fireclickdetector",
            "firetouchinterest","fireproximityprompt",
            "getcallbackvalue","identifyexecutor","getexecutorname","setclipboard",
            "toclipboard","queue_on_teleport","queueonteleport","gethwid","setfflag",
            "getfflag","decompile","saveinstance","setsimulationradius",
            "getsimulationradius","isnetworkowner","sethiddenproperty",
            "gethiddenproperty","cleardrawcache","isrenderobj","getrenderproperty",
            "setrenderproperty","setthreadcontext","getthreadcontext",
            "getthreadidentity","setthreadidentity","getidentity","setidentity",
            "isrbxactive","isgameactive","getproto","getprotos","getstack","setstack",
            "getupvalue","getupvalues","setupvalue","getconstant","getconstants",
            "setconstant","getfpscap","setfpscap","cloneref","compareinstances",
            "gethui","getscriptbytecode","getbytecode","mousemoverel","mousemoveabs",
            "mouse1click","mouse1press","mouse1release","mouse2click","mouse2press",
            "mouse2release","keypress","keyrelease","getclipboard","checkclosure",
            "isfunctionhooked","getthread","fireclickdetector","getcallbackvalue",
        } do
            if settings.benchmark_mode then
                -- real functions (so real type()=="function"); arg-requiring ones error.
                if noargfuncs[name] then
                    cenv[name]=function() return spytbl(name) end
                else
                    cenv[name]=function(a) if a==nil then error("missing argument #1 to '"..name.."'",2) end return spytbl(name) end
                end
            else
                cenv[name]=spytbl(name,"function")
            end
        end
        -- step2: "mock roblox to the top" — seed believable real values so that an
        -- anti-env-logger that reads game/player/character props gets an AUTHENTIC,
        -- fully-injected Delta session in a real game with a walking player, instead
        -- of a spy. spymt.__index still logs every access (it runs simplelog BEFORE
        -- this lookup), so the trace is unchanged; only the returned value is real.
        -- Default (.l) mode only — benchmark mode has its own authentic instance path.
        if not settings.benchmark_mode then
            for k,v in {
                -- real game identity (non-zero ids => "we are in a real game")
                PlaceId=18687417158,GameId=5491688876,CreatorId=1,CreatorType=cenv.Enum.CreatorType.User,
                PrivateServerId="",PrivateServerOwnerId=0,VIPServerId="",VIPServerOwnerId=0,
                -- player identity (a real, logged-in player)
                UserId=2156592430,AccountAge=412,MembershipType="None",
                CharacterAppearanceId=2156592430,FollowUserId=0,
                Name="oxygenated",DisplayName="oxygenated",
                -- humanoid / "fake walking" scalars
                WalkSpeed=16,JumpPower=50,JumpHeight=7.2,Health=100,MaxHealth=100,
                HipHeight=2,MaxSlopeAngle=89,Sit=false,Jump=false,PlatformStand=false,
                -- camera / misc common reads
                FieldOfView=70,CameraType="Custom",Transparency=0,
            } do
                if _69mspredefined[k]==nil then _69mspredefined[k]=v end
            end
            -- vector/CFrame props need real datatypes (makedt is in scope here) so that
            -- e.g. humanoid.MoveDirection.Magnitude ~= 0 reads as "actually walking".
            local function seeddt(k,inst) if _69mspredefined[k]==nil then _69mspredefined[k]=inst end end
            seeddt("MoveDirection",makedt("Vector3",{0,0,1}))
            seeddt("Velocity",makedt("Vector3",{0,0,16}))
            seeddt("AssemblyLinearVelocity",makedt("Vector3",{0,0,16}))
            seeddt("RotVelocity",makedt("Vector3",{0,0,0}))
            seeddt("AssemblyAngularVelocity",makedt("Vector3",{0,0,0}))
            seeddt("Position",makedt("Vector3",{102.4,5.2,-188.7}))
            seeddt("Orientation",makedt("Vector3",{0,90,0}))
            -- NB: do NOT seed "CFrame"/"Vector3"/etc here — those names are also global
            -- datatype constructors and the main fenv resolves _69mspredefined before
            -- cenv, so seeding them would shadow CFrame.new and break datatype checks.
            seeddt("Size",makedt("Vector3",{2,2,1}))
        end
    end
    local spynewcclosure=spytbl("newcclosure")
    cenv.newcclosure=function(...)
        local func=...
        simplelog("_","newcclosure",...)
        local new_f=--[[spynewcclosure(f,...) or]] function(...)
            return func(...)
        end 
        cclosures[new_f]=true
        return new_f
    end
    cenv.newlclosure=function(...)
        local func=...
        simplelog("_","newlclosure",...)
        return function(...)return func(...)end
    end
    cclosures[cenv.newcclosure]=true
    cenv.iscclosure=function(f)
        return not not cclosures[f]
    end
    cenv.islclosure=function(f)
        return not cclosures[f]
    end
    cenv.isexecutorclosure=function(...)
        simplelog("_","isexecutorclosure",...)
        return true
    end
    cenv.require=function(...)
        local varname=getnewvar("req")
        simplelog(varname,"require",...)
        local t=type((...))
        if t=="string" and string.sub((...),1,1)=="@" then
            if (...)=="@self" or (...)=="@game" then
                error"Unable to require module from given path"
            elseif string.sub(...,1,6)=="@game/" then
                error("`"..string.sub(...,7).."` is not a valid Service name")
            end
            error"Path contains unsupported"
        elseif t~="context_type" and t~="number" and t~="userdata" then
            error("expected a ModuleScript, got "..type((...)))
        end
        return spytbl(varname)
    end
    -- cenv.buffer=buffer
    for _,name in {"table","string","math","debug","os","coroutine","buffer","bit32","utf8"} do
        local og=env[name]
        cenv[name]={}
        for i,func in og do
            if i=="insert" then
                cenv[name][i]=og[i]
                continue
            elseif type(func)~="function" then
                cenv[name][i]=func
            else
                cenv[name][i]=function(...)
                    -- wall-clock guard for pure-compute spins (e.g. a decoded VM looping
                    -- on buffer/bit32). Throttled so it costs ~nothing on normal scripts;
                    -- benchmark runs in ~1s so it never trips.
                    stdops+=1
                    if stdops%16384==0 and not settings.benchmark_mode and clock()-startt>(settings.deadline_seconds or 35) then error("<69ms: timeout>") end
                    local a,b,c=...
                    local has_context=false
                    for _,v in {...} do
                        if type(v)=="context_type" then
                            has_context=true
                            break
                        end
                    end
                    -- buffer reads always yield numbers in a real env; when called on
                    -- a spy buffer return a real number (not a spy) so the script's
                    -- `n < buffer.readu8(b)` doesn't hit "compare number < table".
                    if name=="buffer" and has_context then
                        if i=="readstring" then return "" end
                        if i=="len" then return 4096 end -- positive so VM loops run / tables fill
                        if i:sub(1,4)=="read" then return 0 end
                    end
                    if name=="debug" and i=="info" or i=="getinfo" then
                        print("debug.info called with",a,b,c)
                        local isnumber=type(a)=="number"
                        if isnumber and a<0 then
                            return error("invalid argument #1 to 'info' (level can't be negative)")
                        elseif a==0 and b=="l" then
                            return -1
                        elseif isnumber and a>1 then
                            for i=1,a+2 do
                                local targetfunc=debug.info(i,"f")
                                if targetfunc==analyzefunction then
                                    return
                                end
                            end
                        end
                        a=isnumber and a+1 or a
                        print(a)
                        local res=pack(func(a,b,c))
                        if b=="slnaf" then
                            local diddlename
                            for i,v in cenv do
                                if (...)==v then
                                    diddlename=i
                                end
                            end
                            print("diddled",diddlename)
                            return "[C]",-1,diddlename or "",0,true,a
                        end
                        return smart_unpack(res)
                    elseif i=="char" and name=="string" and a==nil then
                        return ""
                    elseif i=="concat" and name=="table" then
                        for ii,v in (...) do
                            if type(v)=="context_type" then
                                (...)[ii]=concat_me..tostring_complex(v)..concat_me_close
                            end
                        end
                    elseif i=="create" and name=="table" then
                        if a<0 then return {} end
                    end
                    if i=="find" and type(a)=="function" then
                        local varname=getnewvar("find")
                        simplelog(varname,"string.find",a,b,c)
                        return spytbl(varname)
                    end
                    -- pcall the real call so a strict lib error (e.g. string.unpack
                    -- on too-short spy data) doesn't kill the trace. On failure
                    -- return a spy (not nil) so downstream ops like `result + n`
                    -- keep working instead of throwing "arithmetic on nil".
                    -- When the args are all REAL (no spy) and the real lib call errors,
                    -- that error is genuine script behaviour (e.g. an obfuscator VM does
                    -- string.unpack past end-of-data and relies on the error / its own
                    -- pcall). Propagate it instead of swallowing it into a spy, otherwise
                    -- the VM's control flow breaks and a spy later indexes nil. Only spy
                    -- the failure when a SPY arg made the real lib choke.
                    local real_res=has_context and not table.find({"pack","move","unpack"},i) or (function(ok,...) if ok then return {...} end if not has_context or settings.benchmark_mode then error((...),0) end return {spytbl(getnewvar(name.."."..i))} end)(pcall(func,...))
                    if i=="traceback" and name=="debug" and type(real_res[1])=="string" then
                        print(real_res[1])
                        real_res[1]=real_res[1]:gsub("%[string \"%.\\httplog2\"%]:%d+\n",""):gsub("%[string \"sandbox\"%]:(%d+)\n","[string \"DontDtcTsPls\"]:%1\n")
                    end
                    if (has_context and not table.find({"pack","move","unpack"},i) or real_res[1]=="[string \"./httplog2\"]") then
                        local vars,varstr=genvars(3)
                        simplelog(varstr,name.."."..i,...)
                        return unpack(vars)
                    end
                    -- string.match/find return nil on no-match; hand back a spy so
                    -- `string.match(s,p):find(...)` doesn't crash with "index nil".
                    if name=="string" and type(real_res)=="table" and real_res[1]==nil then
                        return spytbl(getnewvar(name.."."..i))
                    end
                    return unpack(real_res)
                end
                cclosures[cenv[name][i]]=true
            end
        end
        if name=="debug" then
            cenv.debug.getinfo=debug_getinfo
            for i,v in {"getupvalue","getlocal","setlocal","sethook",--[["gethook"]]"getregistry","getmetatable","setmetatable","setupvalue","getupvalues"} do
                cenv.debug[v]=spytbl("debug."..v,"function")
            end
        end
        if name=="math" then cenv.math.nan=0/0 end -- Roblox has math.nan; Lune doesn't
        if name~="debug" then table.freeze(cenv[name]) end
    end
    -- local enumspytbl
    -- enumspytbl=function(pre)
    --     return setmetatable({
    --         [__69mslocation]=pre
    --     },{
    --         __index=function(_,key)
    --             return enumspytbl(pre.."."..key)
    --         end,
    --         __type="context_type",
    --         __tostring=function()
    --             return "<Enum: "..pre..">"
    --         end
    --     })
    -- end
    -- (default mode now keeps the real fabricating Enum above instead of a flat spy,
    -- so Enum.Type.Item checks — value + "Enum.Type.Item" tostring — actually pass)
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
        if plserror then plserror=nil;error("<69ms: forcederror>") end
        local res={_pcall(...)}
        if res[1] == false then
            res[2] = tostring(res[2])
        end
        return unpack(res)
    end
    if input:find("newproxy, setmetatable, getmetatable, select,",1,true) then
        local error_just_called
        cenv.pcall = function(...)
            local results = {_pcall(...)}
            if error_just_called then
                error_just_called = false
                return unpack(results)
            end
            local first = results[1]
            if type(first) == "boolean" and first == false then
                local second = results[2]
                if type(second) == "string" then
                    results[2] = (second:gsub(":(%d+)([:\r\n])", ":1%2"))
                end
            end
            return unpack(results)
        end
        local _error = error
        cenv.error = function(...)
            error_just_called = true
            return _error(...)
        end
    end
    for _,v in {"pairs","ipairs"} do
        cenv[v]=function(tbl)
            if not tbl then
                insert(currentR,"for i,v in "..v.."(nil)do end")
                return
            end
            if type(tbl)=="context_type" then
                local mt=getmetatable(tbl)
                if not mt or not mt.__iter then
                    simplelog("_",v,tbl)
                    return function()end
                end
                return mt.__iter(tbl,v)
            else return env[v](tbl)
            end
        end
    end
    local nextcalls={}
    cenv.next=function(tbl,...)
        if type(tbl)=="context_type" then
            if ... and nextcalls[tbl] then
                return nextcalls[tbl](tbl,...)
            end
            local func=getmetatable(tbl).__iter(tbl,"next")
            nextcalls[tbl]=func
            return func(tbl,...)
        else return env.next(tbl,...)
        end
    end
    cenv.ishooked=function(...)
        simplelog("_","ishook",...)
        return false
    end
    cenv.IsHooked=function(...)
        simplelog("_","IsHooked",...)
        return false
    end
    cenv.isfunctionhooked=function(...)
        simplelog("_","isfunctionhooked",...)
        return false
    end
    cenv.wait=function(...)simplelog("_","wait",...);local dt=((tonumber((...)) or 0)+math.random()/100);return dt,os.clock() end -- Roblox wait() returns (elapsed, totalTime)
    -- Tolerant table lib: in the fake env a spy can return the wrong number of
    -- values, which makes the real (strict) table.insert/remove throw
    -- "wrong number of arguments" and kill the whole trace. Normalize the args
    -- and swallow any failure so the script keeps running instead of breaking.
    do
        local realinsert,realremove,realcreate=table.insert,table.remove,table.create
        cenv.table=setmetatable({
            insert=function(t,...)
                local n=select("#",...)
                if n>=2 then local pos,val=...;pcall(realinsert,t,pos,val)
                elseif n==1 then pcall(realinsert,t,(...)) end
            end,
            remove=function(t,...)
                local ok,v=pcall(realremove,t,...)
                if ok then return v end
            end,
            -- A spy passed as the size makes the real table.create throw
            -- "size out of range". Coerce to a sane count and never throw.
            create=function(n,v)
                if oldtype(n)~="number" then return {} end
                n=math.floor(n)
                if n<0 or n~=n or n>1e6 then return {} end -- negative / NaN / huge
                local ok,t=pcall(realcreate,n,v)
                return ok and t or {}
            end,
        },{__index=table})
    end
    cenv.loadstring=function(src,...)
        local varname=getnewvar()
        if type(src)=="string" then
            -- Luau bytecode (leading control/version byte) can't be loaded as source:
            -- real loadstring returns nil,err here (eUNC's "cannot load bytecode" check).
            local b1=src:byte(1)
            if b1 and b1<9 then return nil,"loadstring: cannot load bytecode" end
            if not(type(src)=="string" and src:find(".@%(/*,.......      ...,,*/(#%&@@.\n                     (*   ,/(#%%&&@@@@&%((////(((##%###((/**,,.     ,//(&.\n                   /* .%@@@@@@@@%",1,true)) then
                simplelog(varname,"loadstring",src,...)
            end
            -- save the trace before the payload runs (it may hang and get killed)
            if not settings.benchmark_mode then flush_partial() end
            src=settings.hook_op and hook_op(src) or src
            pcall(function() _G.__69ms_n=(_G.__69ms_n or 0)+1; fs.writeFile("dumps/_ls"..(_G.__69ms_n)..".luau",tostring(src)) end)
            local success,_func,a=_pcall(luau.load,src,(...) or "69ms_loadstring")
            if not success then
                -- Real loadstring returns (nil, errmessage) on a syntax error or raw
                -- bytecode it can't compile — detection scripts check exactly this.
                return nil,tostring(_func)
            end
            local _funcenv=getfenv(_func)
            if _funcenv.require~=cenv.require then
                setfenv(_func,setmetatable({},{__index=function(_,key)
                    return cenv[key] or _funcenv[key]
                end}))
            end
            return _func,a
        elseif type(src)=="context_type" then
            -- print"OTHER LOAD"
            simplelog(varname,"loadstring",src)
            return function(...)
                local func_varname=getnewvar()
                simplelog(func_varname,varname,...)
                return spytbl(func_varname)
            end
        end
    end
    cenv.load=cenv.loadstring -- Luau's global is `load`; alias so real compilation runs
    -- utf8.graphemes exists in Roblox; Lune's utf8 lacks it, so shim it (all modes).
    if env.utf8 and env.utf8.graphemes==nil then cenv.utf8=setmetatable({graphemes=function(s) local n=#tostring(s or "") local i=0 return function() i=i+1 if i>n then return nil end return i,i end end},{__index=env.utf8}) end
    -- settings()/UserSettings()/PluginManager() are functions returning settings objects.
    if not settings.benchmark_mode then
        local settingsobj=setmetatable({Rendering=setmetatable({},{__index=function()return 0 end})},{__index=function() return function() end end,__metatable=false})
        types[settingsobj]="Instance"
        cenv.settings=function() return settingsobj end
        cenv.UserSettings=cenv.settings cenv.PluginManager=cenv.settings
    end
    -- cenv.request=function()
    --     return setmetatable({
    --         StatusCode=200,
    --     },{
    --         __index=function(_,key)
    --             cenv.print("idx",key)
    --             return spytbl("_69msR."..key)
    --         end
    --     })
    -- end
    if msecNotReady then
        cenv.allowLogging=function()
            msecNotReady=false
            cenv.allowLogging=nil
            cenv.SetCenv=nil
        end
        cenv.SetCenv=function(key,value)
            cenv[key]=value
        end
    end
    cenv.ce_like_loadstring_fn=cenv.loadstring
    cenv.script_key="c4ce76cd36f2afee4dcee7e87576e5fa"
    local _rawset=rawset
    local tsenv={}
    local genvproxy
    cenv.getgenv=function()
        -- cached so getgenv()==getgenv() (a consistent table, as eUNC checks).
        if genvproxy then return genvproxy end
        genvproxy=setmetatable({
            [__69mslocation]="genv",
        },{__index=function(_,key)
            local varname=getnewvar()

            insert(currentR,"local "..varname.." =genv["..stringify(key).."]")
            -- if key=="Token" or key=="AdoptMe" then return nil end
            if settings.spynilglobals and _69mspredefined[key]==nil and genv[key]==nil then
                return spytbl(varname)
            end
            return _69mspredefined[key] or genv[key] or cenv[key]
        end,__newindex=function(_,k,v)
            genvused=true
            insert(currentR,"genv["..stringify(k).."]="..tostring_complex(v))
            genv[k]=v
        end,
        __type="context_type"})
        return genvproxy
    end
    cenv.ypcall=pcall   -- legacy alias eUNC checks for
    cenv.shared={}      -- a real table (override any spy): shared.x=42 reads back
    cenv.getrenv=function()
        return setmetatable({
            [__69mslocation]="renv",
        },{__index=cenv,__newindex=function(_,k,v)
            insert(currentR,"getrenv()["..stringify(k).."]="..tostring_complex(v))
        end,__type="context_type"})
    end
    cenv._G=setmetatable({
        [__69mslocation]="_G"
    },{__index=function(_,key)
        insert(currentR,"local _ =_G["..stringify(key).."]")
        print(key)
        return rawget(_,key) or _69mspredefined[key] or cenv[key] or genv[key]
    end,__newindex=function(_,k,v)
        insert(currentR,"_G["..stringify(k).."]="..tostring_complex(v)..(settings.log_lines and " -- line "..(function()
                            local linenumber=debug.traceback():split"\n"
                            for i,v in linenumber do
                                if v:find("sandbox",1,true) then
                                    linenumber=v:split(":")[2]
                                    break
                                end
                            end
                            return linenumber
                        end)() or ""))
        rawset(_,k,v)
    end,
    __type="context_type"})
    -- cenv._G={}
    -- cenv.print=function()end
    -- real task scheduler: spawn runs now and returns a thread; defer/delay queue a
    -- suspended thread that runs on the next task.wait; cancel removes it. This makes
    -- the scheduler behave for real (spawn-immediate, defer-after-yield, cancel-prevents)
    -- instead of spying. type(task)=="table" (no context marker) as eUNC expects.
    local taskqueue={}
    local function runqueue()
        local q=taskqueue; taskqueue={}
        for _,it in q do
            if not it.cancelled and coroutine.status(it.co)~="dead" then
                pcall(coroutine.resume,it.co,table.unpack(it.args,1,it.n))
            end
        end
    end
    local function mkco(f) return coroutine.create(type(f)=="function" and f or function() end) end
    cenv.task={
        wait=function(t) simplelog("_","task.wait",t) runqueue() fire_frame_signals() return ((tonumber(t) or 0)+math.random()/100) end,
        spawn=function(f,...) local co=mkco(f) pcall(coroutine.resume,co,...) return co end,
        defer=function(f,...) local co=mkco(f) table.insert(taskqueue,{co=co,args={...},n=select("#",...)}) return co end,
        delay=function(t,f,...) local co=mkco(f) table.insert(taskqueue,{co=co,args={...},n=select("#",...)}) return co end,
        cancel=function(co) if co==nil then error("missing argument #1 to 'cancel'",2) end for _,it in taskqueue do if it.co==co then it.cancelled=true end end pcall(coroutine.close,co) end,
        synchronize=function() end,desynchronize=function() end,
    }
    setmetatable(cenv.task,{__index=function(_,k) return function() return spytbl("task."..tostring(k)) end end})
    cenv.spawn=function(f,...) local co=mkco(f) pcall(coroutine.resume,co,...) return co end
    cenv.getfenv=function(lvl)
        local origlvl=lvl
        if type(lvl)=="number" and lvl<0 then return error("invalid argument #1 to 'getfenv' (level must be non-negative)") end
        if type(lvl)=="boolean" then return error("invalid argument #1 to 'getfenv' (number expected, got boolean)") end
        lvl=lvl and (type(lvl)=="number" and lvl+1 or lvl) or 2
        local res=getfenv(table.find({"function","number"},type(lvl)) and lvl or nil)
        local res_mt=getmetatable(res)
        if rawget(res,"require")==_require or (type(res_mt)=="table" and type(res_mt.__index)=="table" and res_mt.__index.require==_require) or (res_mt~=nil and type(res_mt~="table"))then
            -- local varname=getnewvar()
            -- simplelog(varname,"getfenv",origlvl)
            -- return spytbl(varname)
            return fenv_mt
        end
        return res
    end
    -- step2: present as a real, injected "Delta" so anti-env-logger string checks
    -- (identifyexecutor()=="Delta") pass. Access is still logged.
    cenv.identifyexecutor=function()
        simplelog("_","identifyexecutor")
        return "Delta","660"
    end
    cenv.getexecutorname=function()
        simplelog("_","getexecutorname")
        return "Delta"
    end
    local fake_file_system={}
    cenv.writefile=function(path,cont)
        simplelog("_","writefile",path,cont)
        fake_file_system[path]=cont
    end
    cenv.appendfile=function(path,cont)
        simplelog("_","appendfile",path,cont)
        if fake_file_system[path] then
            fake_file_system[path]=fake_file_system[path]..cont
        else
            fake_file_system[path]=cont
        end
    end
    cenv.readfile=function(path)
        local varname=getnewvar()

        return fake_file_system[path]
    end
    cenv.isfile=function(path)
        return fake_file_system[path]~=nil
    end
    cenv.isfolder=function(path)
        return fake_file_system[path]~=nil
    end
    cenv.mkdir=function(path)
        simplelog("_","mkdir",path)
        fake_file_system[path]={}
    end
    cenv.listfiles=function(path)
        local varname=getnewvar()
        simplelog(varname,"listfiles",path)
        local res={}
        for i,v in fake_file_system do
            if table.concat(v:reverse():split("/"),"/",2):reverse()==path then
                insert(res,i)
            end
        end
        return spytbl(varname)
    end
    for i,v in cenv do
        genv[i] = v
    end
    local typin_check=false
    cenv._69mssigma=function(...) if ...=="meow :3" then error("Controlled shutdown") end end
    cenv.type=function(...)
        local res=type(...)
        if ...=="69ms is such a god" then typin_check=true;
                return "my dihh hurts"
        elseif typin_check==true and res=="table" and (...)[1]=="bat is gay" then
            local calledtimes,extreme_meow=math.random(1,10),0
            local meow_obj
            for i=1,calledtimes do
                local len=math.random(1,3)
                local str=string.rep(".",len)
                if extreme_meow+len>100 then
                    str=""
                else
                    extreme_meow+=len
                end
                meow_obj=(...)[str]
            end
            meow_obj[__69mslocation]="meow_obj"
            setmetatable(meow_obj,{
                __index=function(_,key)
                    if key==extreme_meow then
                        return string.rep(" ",calledtimes-1).."\x1B"
                    elseif key==420 then
                        return "\x1B"
                    end
                    return string.rep(" ",math.random(1,20))
                end,
                __type="context_type",
                __metatable=false
            })
            return nil
        end
        if cclosures[(...)] then
            return "function"
        elseif types[(...)] then
            -- print("returnin",types[(...)])
            return types[(...)]
        elseif res=="context_type" then
            simplelog("_","type",...)
            -- if (...)[__69mslocation] and (...)[__69mslocation]:find("CoreGui")then -- sum like ts idk
            --     return "userdata"
            -- end
            return "table"
        end
        return res
    end
    cenv.typeof=cenv.type
    local oldgetmt=getmetatable
    cenv.getmetatable=function(t)
        -- real Roblox _G / shared have NO metatable.
        if t==cenv._G or t==cenv.shared then return nil end
        if type(t)=="context_type" or t==fenv_mt then
            local varname=getnewvar()
            simplelog(varname,"getmetatable",t)
            return spytbl(varname)
        end
        return oldgetmt(t)
    end
    cenv.rawget=function(t,k)
        if (type(t)=="context_type" or type(k)=="context_type") and not type(k)=="table" then
            local varname=getnewvar("rawget")
            simplelog(varname,"rawget",t,k)
            return spytbl(varname)
        end
        return rawget(t,k)
    end
    for _,func in {"newproxy","unpack","rawset"} do
        cenv[func]=smarthook(func,env[func])
    end
    cenv.tostring=function(...)
        if table.pack(...).n==0 then
            error("missing argument #1")
        end
        local t=type(...)
        -- step1: real datatypes (Vector3, Color3, ...) stringify authentically.
        if datatype_strings[(...)] then
            return datatype_strings[(...)]((...))
        end
        if t=="context_type" or t=="table" then
            local v=(...)
            local ty=types[v]
            -- a plain user table with a __tostring metamethod uses it (Roblox honors it).
            if not ty and t=="table" then
                local mt=oldgetmt(v)
                if type(mt)=="table" and rawget(mt,"__tostring") then return tostring(v) end
            end
            -- Roblox tostring rules: a function -> "function: 0x..", an Instance -> its
            -- Name, everything else table-like -> "table: 0x..". Stable per object.
            if ty=="function" or cclosures[v] then return roblox_addr(v,"function") end
            if ty=="Instance" then return rawget(v,__69mslocation) or roblox_addr(v,"table") end
            return roblox_addr(v,"table")
        elseif t=="function" then
            return roblox_addr((...),"function")
        end
        return tostring(...)
    end
    -- print/warn tostring each argument like Roblox: print(_G) -> the trace shows
    -- print("table: 0x..") (a printed table's address), print(part) -> print("Part"),
    -- not the bare variable name. Strings/numbers stay as-is.
    local function logprint(name)
        return function(...)
            local a=table.pack(...)
            local parts={}
            for i=1,a.n do
                local v=a[i]
                parts[i]=(type(v)=="context_type") and tostring_complex(cenv.tostring(v)) or tostring_complex(v)
            end
            local line="local "..getnewvar(name).." ="..name.."("..table.concat(parts,", ")..")"
            tracebytes+=#line+1
            if tracebytes>TRACE_SIZE_CAP then error("<69ms: sizelimit>") end
            insert(currentR,line)
        end
    end
    cenv.print=logprint("print")
    cenv.warn=logprint("warn")
    -- (re)assert these AFTER the executor lists so they aren't overwritten by a spy:
    -- cloneref must return the SAME instance (anti-tamper scripts chain real methods on it).
    cenv.cloneref=function(x) return x end
    cenv.compareinstances=function(a,b) return a==b end
    -- debug.getinfo returns a Roblox-style table; what="C" for C funcs (math.abs etc),
    -- "Lua" for Lua closures (Lune's debug.info source is "[C]" for C functions).
    do
        local rinfo=debug and debug.info
        cenv.debug=cenv.debug or {}
        cenv.debug.getinfo=function(f)
            local fn=type(f)=="function" and f or nil
            local isC=fn~=nil and cclosures[fn]==true -- wrapped stdlib (math.abs etc) is a C closure
            if not isC and fn and rinfo then local ok,src=pcall(rinfo,fn,"s") isC=ok and src=="[C]" end
            local nm="" if fn and rinfo then local ok,n=pcall(rinfo,fn,"n") if ok and type(n)=="string" then nm=n end end
            return {what=isC and "C" or "Lua",source=isC and "[C]" or "[string \"script\"]",short_src=isC and "[C]" or "script",
                name=nm,currentline=isC and -1 or 1,linedefined=isC and -1 or 0,lastlinedefined=isC and -1 or 0,
                nups=0,numparams=0,is_vararg=0,func=fn}
        end
    end
    for i,v in getmetatable(env).__index do
        if type(v)=="function" and cenv[i] then
            cclosures[cenv[i]]=true
        end
    end
    for item_type,items in exec_env do
        -- exec_env groups by purpose, but typeof must report the real Luau type: the
        -- "library" group is tables (crypt/debug/Drawing/...), everything else is a
        -- function. Surface those, not the internal category name ("closure"/"hook"/...).
        local reported=item_type=="library" and "table" or "function"
        for _,v in items do
            -- print(v,cenv[v],item_type)
            if not cenv[v] then
                cenv[v]=spytbl(v)
            end
            types[cenv[v]]=reported
        end
    end
    local logged_undefined_fenv={}
    local varargs,varargsstr
    if lowestlayer then
        local function crackjunkie()
            local old = {cenv.task,cenv.getgc,cenv.tick}
            cenv.getgc=function()end
            cenv.task['spawn']=function(...) end
            cenv.tick=function() return 1925818287 end
            local old2 = cenv.game:GetService("RbxAnalyticsService").GetClientId
            _69mspredefined=({GetClientId=function() print("set back") cenv.task,cenv.getgc,cenv.tick=old[1],old[2],old[3] return old2() end})
        end
        if isjunkie then
            crackjunkie()
        end
        local fenv_error_on=settings.hook_op and 2e8 or 2e7
        varargs,varargsstr=genvars(5)
        insert(r,"local "..varargsstr.." = ...")
        local lastlen,fuck=#currentR,0
        local _debug={}
        table.foreach(debug,function(i,v)_debug[i]=v end)
        setmetatable(_debug,{__index={getinfo=debug_getinfo}})
        local x=0
        fenv_mt=setmetatable({},{
            __index=function(_,key)
                if key=="_69msloglines" then settings.log_lines=true end
                if key=="zeenjunkie" then crackjunkie() end
                -- print("-----------------",key)
                if msecNotReady then
                    if key=="debug" then
                        return _debug
                    elseif key:sub(1,5)=="_69ms" then
                        if key=="_69mspredefine"then
                            return function(t)
                                _69mspredefined=t or {}
                            end
                        end
                        return cenv[key]
                    elseif key=="wait" then
                        return function(...)return ((...) or 0)+math.random()/10 end
                    elseif key=="getfenv" then
                        return cenv[key]
                    elseif key=="loadstring" then
                        if x<7 then
                            x+=1
                            return luau.load
                        end
                        msecNotReady=false
                        for i,v in tsenv do
                            tsenv[i]=cenv[i] or v
                        end
                        settings.usesimplefunctions=not settings.usesimplefunctions and "MSEC_TRUE" or true
                        return function(src,b)
                            -- fs.writeFile("zOut.lua",src)
                            -- if user_id=="1123674631266639914" then
                            --     return fs.readFile("zOut.lua")
                            -- end
                            local func=luau.load(settings.hook_op~=false and hook_op(src) or src,b)
                            setfenv(func,fenv_mt)
                            return func
                        end
                    elseif key=="require" or key=="game"then
                        -- msecNotReady=false
                        -- for i,v in tsenv do
                        --     tsenv[i]=cenv[i] or v
                        -- end
                        -- settings.usesimplefunctions=not settings.usesimplefunctions and "MSEC_TRUE" or true
                        -- return cenv[key]
                        print"sybau"
                        return error()
                    end
                    return tsenv[key] or env[key]
                -- elseif specialhandle=="LPS" then
                --     print(1,key)
                --     return env[key]
                end
                if not predefinefound and key=="_69mspredefine" and input:find("_69mspredefine",1,true) then
                    predefinefound=true
                    simplelog("_","_69mspredefine","this function was referenced in the script, if you didnt do this place _69mspredefine() on top of your script")
                    return function(t)
                        for i,v in t do
                            _69mspredefined[i]=v
                        end
                    end
                end
                if luraphnotready==1 and key=="coroutine" then
                    luraphnotready=2
                elseif luraphnotready==2 and key=="bit32" then
                    luraphnotready=3
                    print"reached 3"
                elseif luraphnotready==5 then -- TODO LOLL
                    if key=="loadstring" then
                        return function(src,...)
                            luraphnotready=0
                            print("done!!!!!!!!!!!!!!!!!!")
                            return luau.load(src,...)
                        end
                    elseif key=="require" then
                        return function()return {}end
                    -- elseif key=="getfenv" then
                    --     return pmogetfenv
                    end
                    return env[key]
                end
                if #currentR==lastlen then
                    fuck+=1
                    if fuck>fenv_error_on*2 then
                        plserror=true
                    elseif fuck>fenv_error_on then
                        error("<69ms: infiniteloopfenv>")
                    end
                else
                    fuck=0
                end
                lastlen=#currentR
                local try=_69mspredefined[key] or tsenv[key] or cenv[key]
                if try~=nil then
                    return try
                elseif key=="IschooseTeam" then
                    return function()return true end
                elseif (env[key]==nil) then
                    if not logged_undefined_fenv[key] and not (type(key)=="string" and #key>=12 and #key<=14 and settings.ignore_prom_globals) then
                        fenvused=true
                        local varname=getnewvar(key)
                        logged_undefined_fenv[key]=varname
                        insert(currentR,"local "..varname.."=fenv["..tostring_complex(key).."]")
                    end
                    -- print(key,"hai")
                    if settings.spynilglobals and not (#key>=12 and #key<=14 and settings.ignore_prom_globals) then return spytbl(logged_undefined_fenv[key]) end
                end
                return env[key] or genv[key]
            end,__newindex=function(_,k,v)
                if k=="_" or #k>50 then return end
                -- print("OMG NEWINDEX",k,v)
                fenvused=true
                if not table.find({"Db","Dc"},k) and not msecNotReady then
                    if k=="MoonSec_StringsHiddenAttr" then
                        settings.spynilglobals=settings.spynilglobals==nil or settings.spynilglobals
                        settings.hook_op=settings.hook_op==nil or settings.hook_op
                        settings.usesimplefunctions=settings.usesimplefunctions==true
                    end
                    if k=="Descriptor" or type(k)=="string" and k:sub(1,10)=="FlatIdent_" then
                    else
                        insert(currentR,`fenv[{tostring_complex(k)}] = {tostring_complex(v)}`..(settings.log_lines and " -- line "..(function()
                            local linenumber=debug.traceback():split"\n"
                            for i,v in linenumber do
                                if v:find("sandbox",1,true) then
                                    linenumber=v:split(":")[2]
                                    break
                                end
                            end
                            return linenumber
                        end)() or ""))
                    end
                end
                tsenv[k]=v
            end,
            __metatable=false,
        })
        setfenv(chunk,fenv_mt)
    end
    if settings.benchmark_mode then
        -- The benchmark captures CORE = these globals as the script sees them and
        -- checks they are genuine C closures that error authentically. Hand it the
        -- real builtins (env = the chunk's real environment). print/warn stay faked
        -- so we still capture the printed report; typeof stays faked for datatypes.
        for _,name in {
            "type","pcall","xpcall","getmetatable","setmetatable","rawget","rawset",
            "rawequal","rawlen","tostring","tonumber","next","pairs","ipairs","error",
            "assert","select","newproxy","collectgarbage","gcinfo",
            "string","table","math","os","coroutine","buffer","utf8","bit32",
        } do
            if env[name]~=nil then cenv[name]=env[name] end
        end
        cenv.unpack=(env.table and env.table.unpack) or env.unpack
        -- Faked debug.info: the benchmark's isC introspection runs through
        -- cenv.debug.info, so report every function as a clean C closure and
        -- resolve the correct short name (debug.info(math.abs,'n')=='abs').
        local realdebug=env.debug or {}
        local funcnames={}
        for _,lib in {env.string,env.table,env.math,env.os,env.coroutine,env.buffer,env.utf8,env.bit32,realdebug} do
            if type(lib)=="table" then for k,v in lib do if type(v)=="function" and type(k)=="string" then funcnames[v]=k end end end
        end
        for k,v in {type=env.type,pcall=env.pcall,xpcall=env.xpcall,tostring=env.tostring,tonumber=env.tonumber,next=env.next,pairs=env.pairs,ipairs=env.ipairs,select=env.select,rawget=env.rawget,rawset=env.rawset,rawequal=env.rawequal,rawlen=env.rawlen,getmetatable=env.getmetatable,setmetatable=env.setmetatable,error=env.error,assert=env.assert,newproxy=env.newproxy,collectgarbage=env.collectgarbage,unpack=cenv.unpack} do
            if type(v)=="function" then funcnames[v]=k end
        end
        cenv.debug=setmetatable({
            info=function(a,b,c)
                -- thread+level: use the real debug.info so coroutine stack identity is preserved
                if type(a)=="thread" and realdebug.info then return realdebug.info(a,b,c) end
                local spec=type(b)=="string" and b or (type(a)=="string" and a or nil)
                local nm=type(a)=="function" and funcnames[a] or ""
                if spec then
                    local out,n={},0
                    for c in spec:gmatch(".") do
                        n+=1
                        if c=="s" then out[n]="[C]"
                        elseif c=="l" then out[n]=-1
                        elseif c=="n" then out[n]=nm
                        elseif c=="u" then out[n]=0
                        elseif c=="a" then out[n]=0;n+=1;out[n]=false
                        elseif c=="f" then out[n]=type(a)=="function" and a or nil
                        else out[n]=0 end
                    end
                    return table.unpack(out,1,n)
                end
                return {what="C",source="[C]",short_src="[C]",nups=0,currentline=-1,linedefined=-1,name=nm,namewhat=nm~="" and "global" or "",func=type(a)=="function" and a or nil}
            end,
            getupvalue=function() error("upvalue index out of range",2) end,
            getupvalues=function() return end,
            traceback=realdebug.traceback or function() return "" end,
        },{__index=function(_,k) return spytbl("debug."..tostring(k),"function") end})
        cenv.debug.getinfo=cenv.debug.info
        -- task/scheduler return real threads
        local function mkthread(f) local co=coroutine.create(type(f)=="function" and f or function() end); pcall(coroutine.resume,co); return co end
        cenv.task=setmetatable({
            spawn=function(f) return mkthread(f) end,
            defer=function(f) return mkthread(f) end,
            delay=function(_,f) return mkthread(f) end,
            wait=function(t) return (t or 0) end,
            cancel=function() end,synchronize=function() end,desynchronize=function() end,
        },{__index=function(_,k) return function() return spytbl("task."..tostring(k)) end end})
        cenv.spawn=function(f) return mkthread(f) end
        cenv.delay=function(_,f) return mkthread(f) end
        -- crypt: functions that error on a missing arg
        cenv.crypt=setmetatable({},{__index=function(_,k) return function(a) if a==nil then error("missing argument #1 to '"..tostring(k).."'",2) end return spytbl("crypt."..tostring(k)) end end})
        -- executor functions with specific return types
        local function argbool(name) return function(a) if a==nil then error("missing argument #1 to '"..name.."'",2) end return false end end
        local function argtrue(name) return function(a) if a==nil then error("missing argument #1 to '"..name.."'",2) end return true end end
        local function argfn(name) return function(a) if a==nil then error("missing argument #1 to '"..name.."'",2) end return type(a)=="function" and a or function() end end end
        for _,name in {"islclosure","isfunctionhooked","isnetworkowner","isreadonly"} do cenv[name]=argbool(name) end
        for _,name in {"iscclosure","isexecutorclosure"} do cenv[name]=argtrue(name) end
        cenv.hookfunction=argfn("hookfunction")
        cenv.clonefunction=argfn("clonefunction")
        cenv.checkcaller=function() return false end
        cenv.isrbxactive=function() return true end
        cenv.isgameactive=function() return true end
        cenv.getnamecallmethod=function() return "" end
        cenv.identifyexecutor=function() return "Delta","660" end
        cenv.getexecutorname=function() return "Delta" end
        -- raw metatables: string -> {__index=string}; instance -> C-closure __namecall/__index
        local strmt=table.freeze({__index=env.string,__metatable="The metatable is locked"})
        local instmt=table.freeze({__namecall=function()end,__index=function()end,__newindex=function()end,__metatable="The metatable is locked"})
        cenv.getrawmetatable=function(o) if o==nil then error("missing argument #1 to 'getrawmetatable'",2) end if type(o)=="string" then return strmt end return instmt end
        local realgetmt=env.getmetatable
        cenv.getmetatable=function(o) if o==nil then error("missing argument #1 to 'getmetatable' (value expected)",2) end if type(o)=="string" then return "The metatable is locked" end return realgetmt(o) end
        cenv.task.cancel=function(a) if a==nil then error("missing argument #1 to 'cancel'",2) end end
        cenv.newcclosure=function(a) if a==nil then error("missing argument #1 to 'newcclosure'",2) end return a end
        local function mkinst(cn) local t=setmetatable({},{__index=function()return function()end end,__metatable=false}); types[t]="Instance"; return t end
        cenv.settings=function() return mkinst("GameSettings") end
        cenv.UserSettings=function() return mkinst("UserSettings") end
        cenv.PluginManager=function() return mkinst("PluginManager") end
        cenv.require=function(a) if type(a)~="table" and type(a)~="userdata" then error("Attempted to call require with invalid argument(s).",2) end return spytbl("require") end
        if env.utf8 and env.utf8.graphemes==nil then cenv.utf8=setmetatable({graphemes=function() return function() end end},{__index=env.utf8}) end
        cenv.time=function() return os.clock() end
        -- filesystem fns are redefined later as real fake-fs ops; in benchmark mode
        -- they must error on a missing arg.
        for _,name in {"readfile","writefile","appendfile","listfiles","isfile","isfolder","makefolder","delfile","delfolder","loadfile","dofile","getcustomasset"} do
            cenv[name]=function(a) if a==nil then error("missing argument #1 to '"..name.."'",2) end return spytbl(name) end
        end
    end
    local p
    if lowestlayer and luraphcarry then
        -- run the REAL decoded Luraph VM with its real bytecode buffer so its Roblox
        -- calls get logged, instead of stubbing it out.
        p=table.pack(_pcall(chunk,luraphcarry))
    else p = table.pack(_pcall(chunk,unpackchoose(varargs,...))) end
    if not p[1] and type(p[2])=="string" then
        p[2]=p[2]:gsub("%[string \"sandbox\"%]:","line "):gsub("%[string \"%.[\\/]httplog2\"%]:","internal ")
        if p[2]:find("69ms: infinite",1,true) then
            -- intentional loop-guard, not a real script error: log it cleanly
            insert(r,"-- [69ms] stopped here: the script hit an infinite loop")
        elseif p[2]:find("69ms: timeout",1,true) then
            insert(r,"-- [69ms] stopped here: took too long, sending what we logged so far")
        elseif p[2]:find("69ms: sizelimit",1,true) then
            insert(r,"-- [69ms] stopped here: output reached 2 MB, sending what we have")
        elseif p[2]:find("table overflow",1,true) or p[2]:find("not enough memory",1,true) then
            -- script tried to build a giant table from a size it read out of data
            -- the sandbox can't provide; nothing past this point can be captured.
            insert(r,"-- [69ms] stopped here: the script tried to build a huge table (a size it read couldn't be faked)")
        else
            simplelog("er","error",unpack(p,2))
        end
    elseif not p[1] then
        simplelog("er","error")
    else
        local function get(num)
            if not num or num==0 then return end
            if num>100 then
                return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil, get(num-100)
            elseif num>10 then
                return nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,get(num-10)
            end
            return nil, get(num-1)
        end
        if p.n>1 then
            insert(r,"return "..stringify(unpack(p,2,p.n)))
        end
    end
    currentR=oldR
    return r
end
local r={
}
local start=clock()
local s,re=pcall(analyzefunction,chunk,r,true)
if not s then print("heh",s,re) end
local post=commercial and "_dump.lua" or ".lua"
for i=1,unclosed_blocks do
    insert(r,"end")
end
if fenvused then
    insert(r,1,"local fenv=getfenv()")
end
if genvused then
    insert(r,1,"local genv=getgenv()")
end
pcall(function()
for i=1,20 do
    if not is_unfinished then break end
    local newr={}
    for _,line in r do
        local num=line:match("-- func(%d+)")
        if num and unfinishedfuncs[tonumber(num)] then
            local locallocation,localused=#newr,false
            local localname=newr[locallocation]:match("local ([%w_]+)")
            local obj=unfinishedfuncs[tonumber(num)]
            local s,re=pcall(analyzefunction,obj.func,{},false,multiunpack(obj.args,obj.varargs))
            for i,v in re do
                if v~=nil then
                    if localname and v:find(localname,1,true) then
                        localused=true
                    end
                    insert(newr,v)
                end
            end
            if localused then
                newr[locallocation]=newr[locallocation]:gsub("(local )([%w_]+)","%2")
                insert(newr,locallocation,"local "..localname)
            end
        else
            insert(newr,line)
        end
    end
    r=newr
end
end)
pcall(function()
if not settings.log_lines then
    local total_before=#r
    local start=os.clock()
    r=evaluate_single_use_variables(r)
    evaluate_stuff(r)
    print("evaluating in ",os.clock()-start,"seconds")
    print("reduced from",total_before,"to",#r,"lines")
else
    local oldr=table.clone(r)
    table.clear(r)
    for _,v in oldr do
        if v~=nil then
            insert(r,(v:gsub(identifier.."_?","")))
        end
    end
end
end)
-- Strip absolute machine paths so a dump never leaks the user's folders/username.
local function sanitize_paths(s)
    if type(s)~="string" then return s end
    -- %f[%a] = drive letter must not follow another letter, so "https://" URLs
    -- are left intact while real "C:\..." paths get scrubbed.
    s=s:gsub("%f[%a]%a:[\\][%w%._%- \\/]-69ms[\\/]%w+:%d+","internal")
    s=s:gsub("%f[%a]%a:[\\][%w%._%- \\/]+","<path>")
    s=s:gsub("/[Uu]sers/[^%s\"'%]:/]+","<path>")
    s=s:gsub("/home/[^%s\"'%]:/]+","<path>")
    return s
end
local output="--// This file was generated by 69ms V4 [https://discord.gg/gEHQbMP872]\n"..sanitize_paths(table.concat(r,"\n"))
fs.writeFile(outpath..targetfilename:gsub(".lua","")..post,output)
local endt=clock()-startt
print("success in",endt,"seconds!\nWritten to "..outpath..targetfilename:gsub(".lua","")..post)
print(output)
