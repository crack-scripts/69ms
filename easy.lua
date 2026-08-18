print("anti env by za1k <3")
local dtc = "detected by za1k <3"

if type(_G) ~= "table" or not string.find(tostring(_G), "table: ") then
    print(dtc)
    return
end

if _VERSION ~= "Luau" then
    print(dtc)
    return
end

local success, res = pcall(function() return game:GetService("CorePackages") end)
if not success then
    print(dtc)
    return
end

local runserv = game:GetService("RunService")
for i = 1, 125 do
    if runserv:IsStudio() then
        print(dtc)
        return
    end
end

local lunee = pcall(function() return require("@lune/fs") end)
if lunee then
    print(dtc)
    return
end

local Players = game:GetService("Players")
local function validatePlayers()
    local playerList = Players:GetPlayers()
    for _, player in ipairs(playerList) do
        if not player:IsA("Player") then
            print(dtc)
            return false
        end
    end
    return true
end

if not validatePlayers() then
    return
end

local vcs = game:GetService("VoiceChatService")
local function vccheck()
    print(dtc)
    while true do task.wait() end
end
if type(vcs.joinVoice) ~= "function" then
    vccheck(print(dtc))
end
if type(vcs.rejoinVoice) ~= "function" then
    vccheck(print(dtc))
end
if type(vcs.leaveVoice) ~= "function" then
    vccheck(print(dtc))
end
print("straight BALL knowledge if ur getting this far")
local ss = game:GetService("SoundService")

local function sscheck()
    print(dtc)
    while true do end
end
if type(ss.GetAudioInstances) ~= "function" then
    sscheck()
end
if type(ss.GetInputDevices) ~= "function" then
    sscheck()
end
if type(ss.GetOutputDevices) ~= "function" then
    sscheck()
end
local assetdetection = (cloneref and cloneref(game:GetService("AssetService"))) or game:GetService("AssetService")
local function za1kissocute()
    local pass = false
    local success = pcall(function()
        if not assetdetection or not assetdetection.CreateEditableMesh then return end
        local mesh = assetdetection:CreateEditableMesh()
        if not mesh then return end
        local randX, randY, randZ = math.random(5, 50) + math.random(), math.random(5, 50) + math.random(), math.random(5, 50) + math.random()
        local salsavertaa = math.random(2, 5)
        local v2 = mesh:AddVertex(Vector3.new(randX, randY, randZ))
        for i = 1, salsavertaa do mesh:AddVertex(Vector3.new(i, i, i)) end
        local p2 = mesh:GetPosition(v2)
        mesh:Destroy()
        if p2 and math.abs(p2.X - randX) < 1e-4 and math.abs(p2.Y - randY) < 1e-4 and math.abs(p2.Z - randZ) < 1e-4 then
            pass = true
        end
    end)
    return success and pass
end

if not za1kissocute() then
    print(dtc)
    return
end

print("You are ud <@1432986535288111136> with your result including me n shit!")