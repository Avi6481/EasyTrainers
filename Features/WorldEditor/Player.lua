local Logger = require("Core/Logger")
local Entities = require("Features/WorldEditor/Entities")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Inspector = require("Features/WorldEditor/Inspector")

local Player = {
    Hide = true,
    Follow = false,
    FollowDistance = 60
}

local FOLLOW_INTERVAL = 0.5
local FOLLOW_BEHIND = 15
local GROUND_GROUPS = { "Static", "Terrain" }

local VISUAL_CLASSES = {
    entSkinnedMeshComponent = true,
    entMorphTargetSkinnedMeshComponent = true,
    entGarmentSkinnedMeshComponent = true,
    entMeshComponent = true
}

local s_HiddenParts = nil
local s_NextFollow = 0

local Safe = Entities.Safe

local function IsVisiblePart(component)
    local ok, visible = pcall(function()
        return VISUAL_CLASSES[Game.NameToString(component:GetClassName())] == true and component:IsEnabled()
    end)
    return ok and visible == true
end

function Player.SetHidden(hidden)
    if hidden and not s_HiddenParts then
        local player = Game.GetPlayer()
        if not player or not EasyEntityTools then return end
        local components = Safe(function() return EasyEntityTools.GetComponents(player) end)
        if type(components) ~= "table" then return end

        s_HiddenParts = {}
        for _, component in ipairs(components) do
            if IsVisiblePart(component) then
                Safe(function() component:Toggle(false) end)
                table.insert(s_HiddenParts, component)
            end
        end
        Logger.Log(string.format("WorldEditor: hid %d of V's mesh components", #s_HiddenParts))
    elseif not hidden and s_HiddenParts then
        for _, component in ipairs(s_HiddenParts) do Safe(function() component:Toggle(true) end) end
        s_HiddenParts = nil
    end
end

function Player.IsHidden()
    return s_HiddenParts ~= nil
end

local function FollowPosition()
    local camera = FreeCam.GetPosition()
    local radians = math.rad((FreeCam.GetRotation()))
    local x = camera.x + math.sin(radians) * FOLLOW_BEHIND
    local y = camera.y - math.cos(radians) * FOLLOW_BEHIND
    local ground = Inspector.Raycast(Vector4.new(x, y, camera.z + 2, 1.0), Vector4.new(x, y, camera.z - 500, 1.0), GROUND_GROUPS)
    return Vector4.new(x, y, ground and ground.Position.z or camera.z - 2, 1.0)
end

function Player.MoveHere(player)
    if not FreeCam.IsReady() or not player then return false end

    local yaw = FreeCam.GetRotation()
    local ok = pcall(function()
        Game.GetTeleportationFacility():Teleport(player, FollowPosition(), EulerAngles.new(0, 0, yaw))
    end)
    if not ok then return false end
    FreeCam.Rebase()
    return true
end

function Player.UpdateFollow(player)
    if not Player.Follow or not FreeCam.IsReady() then return end

    local now = os.clock()
    if now < s_NextFollow then return end
    s_NextFollow = now + FOLLOW_INTERVAL

    local camera = FreeCam.GetPosition()
    local origin = player:GetWorldPosition()
    local distance = math.sqrt((camera.x - origin.x) ^ 2 + (camera.y - origin.y) ^ 2)
    if distance < Player.FollowDistance then return end

    Player.MoveHere(player)
end

function Player.Forget()
    s_HiddenParts = nil
    s_NextFollow = 0
end

return Player
