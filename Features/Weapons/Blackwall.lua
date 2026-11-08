local Logger = require("Core/Logger")
local Notify = require("Utils/Notify")
local Aim = require("Utils/Aim")
local Controls = require("Features/Weapons/Controls")

local Blackwall = {
    Enabled = false
}

local MARK = "BaseStatusEffect.SoMi_Q306_BlackwallMark"
local UPLOAD = "BaseStatusEffect.SoMi_Q306_BlackwallHackUpload"
local HACK_TAG = "BlackwallHack"
local JOHNNY_GLITCH = "BaseStatusEffect.JohnnySicknessMedium"
local KNOCKDOWN = "BaseStatusEffect.Knockdown"
local MAX_DISTANCE = 70
local GLITCH_TIME = 3
local KID_MESSAGES = 6
local SHOVE_STRIKES = { [3] = true, [5] = true, [6] = true }

local s_KidStrikes = 0
local s_GlitchUntil = nil
local s_HackTag = nil

local function Usable(player, target)
    if not target or Aim.IsOwn(player, target) then return false end

    local ok, npc = pcall(function() return target:IsNPC() end)
    if not ok or not npc then return false end

    local deadOk, dead = pcall(function() return target:IsDead() end)
    return not (deadOk and dead)
end

local function FindTarget(player)
    local target = Aim.Object(player)
    if Usable(player, target) then return target end

    local targeting = Game.GetTargetingSystem()
    local ok, closest = pcall(function()
        local query = TSQ_NPC()
        query.maxDistance = MAX_DISTANCE
        return targeting:GetObjectClosestToCrosshair(player, EulerAngles.new(0, 0, 0), query)
    end)
    if ok and Usable(player, closest) then return closest end
    return nil
end

local function IsChild(target)
    local ok, child = pcall(function() return target:GetRecord():IsChild() end)
    return ok and child == true
end

local function JohnnyShove(player, system)
    local id = player:GetEntityID()
    system:ApplyStatusEffect(id, TweakDBID.new(JOHNNY_GLITCH), player:GetRecordID(), id)
    system:ApplyStatusEffect(id, TweakDBID.new(KNOCKDOWN), player:GetRecordID(), id)
    s_GlitchUntil = os.clock() + GLITCH_TIME
end

local function Scold(player, system)
    s_KidStrikes = s_KidStrikes + 1
    if SHOVE_STRIKES[s_KidStrikes] then JohnnyShove(player, system) end

    local message = L("weapons.blackwall.kid" .. math.min(s_KidStrikes, KID_MESSAGES))
    if s_KidStrikes < KID_MESSAGES then
        Notify.Warning(message, 4)
        return
    end

    Notify.Warning(message, 6)
    Blackwall.Enabled = false
    s_KidStrikes = 0
end

function Blackwall.Use(player)
    local system = Game.GetStatusEffectSystem()
    if not system then return end

    local target = FindTarget(player)
    if not target then return Notify.Info(L("notify.weapons.blackwallnone"), 2) end
    if IsChild(target) then return Scold(player, system) end

    local id = target:GetEntityID()
    s_HackTag = s_HackTag or CName.new(HACK_TAG)
    if system:HasStatusEffectWithTag(id, s_HackTag) then return end

    system:ApplyStatusEffect(id, TweakDBID.new(MARK))
    system:ApplyStatusEffect(id, TweakDBID.new(UPLOAD))
    Logger.Log("Blackwall: uploaded to " .. tostring(id.hash))
end

local function Glitch(player, now)
    if not s_GlitchUntil or now < s_GlitchUntil then return end
    s_GlitchUntil = nil

    local system = Game.GetStatusEffectSystem()
    if system then system:RemoveStatusEffect(player:GetEntityID(), TweakDBID.new(JOHNNY_GLITCH)) end
end

function Blackwall.Update(player, now)
    Glitch(player, now)
    if Blackwall.Enabled and Controls.Pressed("Blackwall") then Blackwall.Use(player) end
end

function Blackwall.Reset()
    s_GlitchUntil = nil
end

return Blackwall
