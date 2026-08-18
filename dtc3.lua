-- game:HttpGet("") returns spy table (typeof=="table"), should be "string"
local ok, res = pcall(game.HttpGet, game, "")
if ok then
    if typeof(res) == "string" then
        print("ud")
    else
        print("dtc")
    end
else
    print("dtc")
end