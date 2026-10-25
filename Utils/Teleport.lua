local Logger = require("Core/Logger")
local Cron = require("Core/cp2077-cet-kit/Cron")

local Teleport = {}

local REPORT_INTERVAL = 2.0
local VERIFY_DELAY = 0.6
local VERIFY_DISTANCE = 1.0

local s_LastReport = ""
local s_NextReport = 0
local s_Verifying = false

local function ReportRestrictions(player)
    local now = os.clock()
    if now < s_NextReport then return end
    s_NextReport = now + REPORT_INTERVAL

    local ok, applied = pcall(function() return Game.GetStatusEffectSystem():GetAppliedEffects(player:GetEntityID()) end)
    if not ok or type(applied) ~= "table" then return end

    local active = {}
    for _, entry in ipairs(applied) do
        local name = TDBID.ToStringDEBUG(entry:GetRecord():GetID())
        if name:find("GameplayRestriction", 1, true) then
            table.insert(active, name .. " (by " .. TDBID.ToStringDEBUG(entry:GetInstigatorStaticDataID()) .. ")")
        end
    end
    table.sort(active)

    local report = table.concat(active, ", ")
    if report == s_LastReport then return end
    s_LastReport = report
    if report ~= "" then Logger.Log("Teleport: player restrictions active: " .. report) end
end

local function Safe(callback)
    local ok, value = pcall(callback)
    return ok and value or nil
end

local function PlayerContext(player)
    local defs = GetAllBlackboardDefs().PlayerStateMachine
    local board = Safe(function() return Game.GetBlackboardSystem():GetLocalInstanced(player:GetEntityID(), defs) end)
    local function Int(field)
        return board and Safe(function() return board:GetInt(defs[field]) end)
    end
    local angles = Safe(function() return player:GetWorldOrientation():ToEulerAngles() end)
    local effects = {}
    local applied = Safe(function() return Game.GetStatusEffectSystem():GetAppliedEffects(player:GetEntityID()) end)
    for _, entry in ipairs(type(applied) == "table" and applied or {}) do
        table.insert(effects, Safe(function() return TDBID.ToStringDEBUG(entry:GetRecord():GetID()) end) or "?")
    end
    table.sort(effects)
    return string.format("scene tier %s, high level %s, vehicle %s, rotation %s; effects: %s",
        tostring(Int("SceneTier")), tostring(Int("HighLevel")), tostring(Int("Vehicle")),
        angles and string.format("%.1f/%.1f/%.1f", angles.pitch, angles.yaw, angles.roll) or "?",
        #effects > 0 and table.concat(effects, ", ") or "none")
end

local function VerifyPlayerTeleport(player, target)
    if s_Verifying then return end
    local start = player:GetWorldPosition()
    if Teleport.DistanceBetween(start, target) < VERIFY_DISTANCE * 3 then return end

    s_Verifying = true
    Cron.After(VERIFY_DELAY, function()
        s_Verifying = false
        local current = Game.GetPlayer()
        if not current then return end
        local position = current:GetWorldPosition()
        if Teleport.DistanceBetween(position, start) >= VERIFY_DISTANCE then return end
        Logger.Log(string.format("Teleport: did not apply (wanted %.1f, %.1f, %.1f; still at %.1f, %.1f, %.1f); %s",
            target.x, target.y, target.z, position.x, position.y, position.z, PlayerContext(current)))
    end)
end

local function Finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function CleanRotation(rotation)
    local yaw = rotation and rotation.yaw
    return EulerAngles.new(0, 0, Finite(yaw) and yaw or 0)
end

function Teleport.TeleportEntity(entity, position, facing)
    if not entity or not position then return false end
    local isPlayer = pcall(function() return entity:IsPlayer() end) and entity:IsPlayer()
    if isPlayer then
        ReportRestrictions(entity)
        VerifyPlayerTeleport(entity, position)
    end

    local target = Vector4.new(position.x, position.y, position.z, position.w or 1.0)
    local rotation = facing or entity:GetWorldOrientation():ToEulerAngles()
    if isPlayer then rotation = CleanRotation(rotation) end

    Game.GetTeleportationFacility():Teleport(entity, target, rotation)
    return true
end

function Teleport.DistanceBetween(a, b)
    if not a or not b then return math.huge end
    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Teleport.DistanceFromPlayer(position)
    local player = Game.GetPlayer()
    if not player or not position then return math.huge end
    return Teleport.DistanceBetween(player:GetWorldPosition(), position)
end

function Teleport.GetWaypointPosition()
    local mappinSystem = Game.GetMappinSystem()
    if not mappinSystem then return nil end

    local id = mappinSystem:GetManuallyTrackedMappinID()
    if not id then return nil end

    local mappin = mappinSystem:GetMappin(id)
    if not mappin or not mappin:IsPlayerTracked() then return nil end
    return mappin:GetWorldPosition()
end

function Teleport.GetQuestMarkerPosition()
    local journal = Game.GetJournalManager()
    local tracked = journal and journal:GetTrackedEntry() or nil
    local mappinSystem = Game.GetMappinSystem()
    if not tracked or not mappinSystem then return nil end

    local ok, positions = mappinSystem:GetQuestMappinPositionsByObjective(journal:GetEntryHash(tracked))
    if not ok or not positions or #positions == 0 then return nil end
    return positions[1]
end

function Teleport.ToWaypoint()
    return Teleport.TeleportEntity(Game.GetPlayer(), Teleport.GetWaypointPosition())
end

function Teleport.ToQuestMarker()
    return Teleport.TeleportEntity(Game.GetPlayer(), Teleport.GetQuestMarkerPosition())
end

local function OffsetFromPlayer(distance, yawOffset, yawOverride)
    local player = Game.GetPlayer()
    if not player then return nil end

    local position = player:GetWorldPosition()
    local yaw = yawOverride or player:GetWorldOrientation():ToEulerAngles().yaw
    local radians = math.rad(yaw + yawOffset)

    return Vector4.new(
        position.x - distance * math.sin(radians),
        position.y + distance * math.cos(radians),
        position.z,
        1.0
    )
end

function Teleport.GetForwardOffset(distance, yawOverride)
    return OffsetFromPlayer(distance, 0, yawOverride)
end

function Teleport.GetRightOffset(distance, yawOverride)
    return OffsetFromPlayer(distance, 90, yawOverride)
end

return Teleport
