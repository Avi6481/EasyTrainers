local Logger = require("Core/Logger")
local Bindings = require("Controls/Bindings")
local ControlState = require("Controls/State")
local Notification = require("UI/Panels/Notification/Notification")
local AimHelpers = require("Features/Weapons/Abilities/AimHelpers")

local BlackwallForce = {}

BlackwallForce.Enabled = { value = false }
BlackwallForce.Action = "BLACKWALL_FORCE"


local MARK = "BaseStatusEffect.SoMi_Q306_BlackwallMark"
local UPLOAD = "BaseStatusEffect.SoMi_Q306_BlackwallHackUpload"
local HACK_TAG = "BlackwallHack"
local MAX_DISTANCE = 70.0

local KID_MESSAGES = {
    "Wait, why are we aiming at a kid here? Let's maybe not do that.",
    "Okay, why are we trying that again? You do realize that's a kid, right?",
    "Seriously, dude? There's an entire city of people and you keep picking the kid?",
    "Dude, what the fuck is actually wrong with you? I'm genuinely starting to wonder.",
    "Okay, I'm actually concerned now. How many times do I have to tell you to leave the kids alone?",
    "You know what? I'm just going to disable this for you. Clearly you can't be trusted with it. Feel free to turn it back on when you've thought about what you've done."
}

local SHOVE_STRIKES = { [3] = true, [5] = true, [6] = true }
local JOHNNY_GLITCH = "BaseStatusEffect.JohnnySicknessMedium"
local KNOCKDOWN = "BaseStatusEffect.Knockdown"
local GLITCH_TIME = 3.0

local s_KeyWasDown = false
local s_KidStrikes = 0
local s_HackTag = nil
local s_GlitchUntil = nil

local function IsChild(target)
    local ok, child = pcall(function() return target:GetRecord():IsChild() end)
    return ok and child == true
end

local function IsUsable(target)
    if not target or AimHelpers.IsPlayerOrMount(target) then return false end
    local ok, npc = pcall(function() return target:IsNPC() end)
    if not ok or not npc then return false end

    local deadOk, dead = pcall(function() return target:IsDead() end)
    return not (deadOk and dead)
end

local function FindTarget(player)
    local targeting = Game.GetTargetingSystem()
    if not targeting then return nil end

    local target = targeting:GetLookAtObject(player, true, false)
    if IsUsable(target) then return target end

    local ok, closest = pcall(function()
        local query = TSQ_NPC()
        query.maxDistance = MAX_DISTANCE
        return targeting:GetObjectClosestToCrosshair(player, EulerAngles.new(0, 0, 0), query)
    end)
    if ok and IsUsable(closest) then return closest end
    return nil
end

local function JohnnyShove(player)
    local system = Game.GetStatusEffectSystem()
    if not system then return end
    local playerID = player:GetEntityID()
    system:ApplyStatusEffect(playerID, TweakDBID.new(JOHNNY_GLITCH), player:GetRecordID(), playerID)
    system:ApplyStatusEffect(playerID, TweakDBID.new(KNOCKDOWN), player:GetRecordID(), playerID)
    s_GlitchUntil = os.clock() + GLITCH_TIME
end

local function ScoldKidAttempt(player)
    s_KidStrikes = s_KidStrikes + 1
    if SHOVE_STRIKES[s_KidStrikes] then JohnnyShove(player) end

    local message = KID_MESSAGES[math.min(s_KidStrikes, #KID_MESSAGES)]
    if s_KidStrikes >= #KID_MESSAGES then
        Notification.Warning(message, 6)
        BlackwallForce.Enabled.value = false
        require("Config/OptionConfig").Save()
        s_KidStrikes = 0
        return
    end

    Notification.Warning(message, 4)
end

function BlackwallForce.Use()
    if not BlackwallForce.Enabled.value then return false end

    local player = Game.GetPlayer()
    local system = Game.GetStatusEffectSystem()
    if not player or not system then return false end

    local target = FindTarget(player)
    if not target then
        Notification.Info("Look at someone to Blackwall them", 2)
        return false
    end
    if IsChild(target) then
        ScoldKidAttempt(player)
        return false
    end

    local targetID = target:GetEntityID()
    s_HackTag = s_HackTag or CName.new(HACK_TAG)
    if system:HasStatusEffectWithTag(targetID, s_HackTag) then return false end

    system:ApplyStatusEffect(targetID, TweakDBID.new(MARK))
    system:ApplyStatusEffect(targetID, TweakDBID.new(UPLOAD))
    Logger.Log("BlackwallForce: uploaded to " .. tostring(targetID.hash))
    return true
end

local function UpdateGlitch()
    if not s_GlitchUntil or os.clock() < s_GlitchUntil then return end
    s_GlitchUntil = nil
    local player = Game.GetPlayer()
    local system = Game.GetStatusEffectSystem()
    if player and system then system:RemoveStatusEffect(player:GetEntityID(), TweakDBID.new(JOHNNY_GLITCH)) end
end

function BlackwallForce.Tick()
    UpdateGlitch()
    if not BlackwallForce.Enabled.value then
        s_KeyWasDown = false
        return
    end

    local down = Bindings.IsActionDown(BlackwallForce.Action)
    local pressed = down and not s_KeyWasDown
    s_KeyWasDown = down
    if not pressed or ControlState.BindingKey or ControlState.TypingEnabled or ControlState.MenuOpen then return end
    BlackwallForce.Use()
end

return BlackwallForce
