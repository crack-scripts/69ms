-- exec_env.lua
--
-- A categorized list of common Roblox script-executor globals. httplog2.lua
-- iterates this as `for item_type, items in exec_env do` and pre-seeds any
-- name it doesn't already define as a spy object (so an obfuscated script that
-- calls e.g. `hookfunction(...)` gets logged instead of erroring on a nil
-- global). The category string is stored as the spy's reported type.

return {
    -- Environment / reflection
    closure = {
        "getgenv", "getrenv", "getreg", "getgc", "getfenv", "setfenv",
        "getinstances", "getnilinstances", "getscripts", "getloadedmodules",
        "getrunningscripts", "getscriptclosure", "getscriptfunction",
        "getsenv", "getcallingscript", "getscripthash", "getfunctionhash",
        "islclosure", "iscclosure", "newcclosure", "clonefunction",
        "isexecutorclosure", "checkcaller", "getcallbackvalue",
    },

    -- Hooking
    hook = {
        "hookfunction", "hookmetamethod", "replaceclosure", "restorefunction",
        "getrawmetatable", "setrawmetatable", "setreadonly", "isreadonly",
        "make_writeable", "make_readonly", "getnamecallmethod",
        "setnamecallmethod", "hookmetatable",
    },

    -- Filesystem
    filesystem = {
        "writefile", "readfile", "appendfile", "loadfile", "isfile",
        "isfolder", "makefolder", "delfolder", "delfile", "listfiles",
        "getcustomasset", "dofile",
    },

    -- Network
    network = {
        "request", "http_request", "httprequest", "httpget", "httpgetasync",
        "syn_request", "WebSocket", "websocket",
    },

    -- Crypto / misc libraries (referenced as tables)
    library = {
        "crypt", "base64", "syn", "Drawing", "debug", "cache",
        "fluxus", "krnl", "protosmasher", "secure_load",
    },

    -- Input
    input = {
        "fireclickdetector", "firetouchinterest", "fireproximityprompt",
        "firesignal", "getconnections", "mouse1click", "mouse1press",
        "mouse1release", "mouse2click", "mouse2press", "mouse2release",
        "keypress", "keyrelease", "mousemoverel", "mousemoveabs",
    },

    -- Identity / clipboard / misc
    misc = {
        "identifyexecutor", "getexecutorname", "setclipboard", "toclipboard",
        "queue_on_teleport", "queueonteleport", "gethwid", "gethwid",
        "setfflag", "getfflag", "decompile", "saveinstance", "messagebox",
        "rconsoleprint", "rconsolewarn", "rconsolename", "loadstring",
    },
}
