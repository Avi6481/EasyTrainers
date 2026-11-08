local InputBlock = require("Core/InputBlock")
local Notify = require("Utils/Notify")
local StatModifiers = require("Utils/StatModifiers")
local World = require("Features/World/World")
local Weather = require("Features/World/Weather")
local Hotkeys = require("Features/Hotkeys/Hotkeys")

local TrainerEffects = {}

TrainerEffects.Kinds = {
    Stat = "Stat",
    Hold = "Hold",
    World = "World",
    Weather = "Weather"
}

TrainerEffects.Targets = {
    Player = "effects.targets.player",
    RightWeapon = "effects.targets.rightweapon",
    LeftWeapon = "effects.targets.leftweapon",
    Input = "effects.targets.input",
    World = "effects.targets.world"
}

local REFRESH = 0.25
local HIDE_TIME = 0.6
local PREFIXES = { "", "Self.", "Modifiers.", "Weapons." }
local HANDS = {
    { Suffix = ".RightObject", Target = TrainerEffects.Targets.RightWeapon },
    { Suffix = ".LeftObject", Target = TrainerEffects.Targets.LeftWeapon },
    { Suffix = ".Right", Target = TrainerEffects.Targets.RightWeapon },
    { Suffix = ".Left", Target = TrainerEffects.Targets.LeftWeapon },
    { Suffix = ".Player", Target = TrainerEffects.Targets.Player }
}
local WORLD_IDS = { "Time.Freeze", "Time.Sync", "Time.DaySpeed", "Time.NightSpeed", "Time.Lapse", "Weather.Freeze" }

local s_List = {}
local s_NextBuild = 0
local s_Hidden = {}
local s_Definitions = {}
local s_StatNames = {}

local function Split(owner)
    for _, hand in ipairs(HANDS) do
        if owner:sub(-#hand.Suffix) == hand.Suffix then return owner:sub(1, -#hand.Suffix - 1), hand.Target end
    end
    return owner, TrainerEffects.Targets.Player
end

local function Lookup(base)
    for _, prefix in ipairs(PREFIXES) do
        local definition = Hotkeys.Find(prefix .. base) or Hotkeys.Find(prefix .. base .. ".Enabled")
        if definition and definition.Kind ~= Hotkeys.Kinds.Action then return definition end
    end
    return false
end

local function DefinitionFor(owner)
    local base = Split(owner)
    if s_Definitions[base] == nil then s_Definitions[base] = Lookup(base) end
    return s_Definitions[base] or nil
end

local function Spaced(name)
    local last = name:match("([^%.]+)$") or name
    return (last:gsub("(%l)(%u)", "%1 %2"))
end

local function EnumName(enumType, value)
    local ok, name = pcall(function() return EnumValueToString(enumType, EnumInt(value)) end)
    if ok and type(name) == "string" and name ~= "" then return name end
    return tostring(value)
end

local function StatName(stat)
    local name = s_StatNames[stat]
    if not name then
        name = Spaced(EnumName("gamedataStatType", stat))
        s_StatNames[stat] = name
    end
    return name
end

local function Number(value)
    if type(value) ~= "number" then return tostring(value) end
    if value == math.floor(value) then return string.format("%d", value) end
    return (string.format("%.2f", value):gsub("0+$", ""))
end

local function ModifierValue(kind, value)
    local name = EnumName("gameStatModifierType", kind)
    if name == "Multiplier" then return "x" .. Number(value) end
    if name == "AdditiveMultiplier" then return string.format("%+d%%", math.floor((tonumber(value) or 0) * 100 + 0.5)) end
    if type(value) == "number" and value >= 0 then return "+" .. Number(value) end
    return Number(value)
end

local function Name(owner, definition)
    if definition then return Hotkeys.Name(definition) end
    return Spaced(owner)
end

local function StatEntry(applied)
    local definition = DefinitionFor(applied.Owner)
    local _, target = Split(applied.Owner)
    return {
        Id = "Stat." .. applied.Owner,
        Kind = TrainerEffects.Kinds.Stat,
        Owner = applied.Owner,
        Name = Name(applied.Owner, definition),
        Target = target,
        Count = #applied.Modifiers,
        Definition = definition,
        Applied = applied
    }
end

local function HoldEntry(owner)
    local definition = DefinitionFor(owner)
    local counts = InputBlock.Describe(owner) or { Keys = 0, Buttons = 0, Sticks = 0, Mouse = 0 }
    return {
        Id = "Hold." .. owner,
        Kind = TrainerEffects.Kinds.Hold,
        Owner = owner,
        Name = Name(owner, definition),
        Target = TrainerEffects.Targets.Input,
        Count = counts.Keys + counts.Buttons + counts.Sticks + counts.Mouse,
        Definition = definition,
        Inputs = counts
    }
end

local function WorldEntry(definition)
    return {
        Id = "World." .. definition.Id,
        Kind = TrainerEffects.Kinds.World,
        Owner = definition.Id,
        Name = Hotkeys.Name(definition),
        Target = TrainerEffects.Targets.World,
        Definition = definition
    }
end

local function WeatherEntry()
    return {
        Id = "Weather.Forced",
        Kind = TrainerEffects.Kinds.Weather,
        Owner = "Weather",
        Name = L("effects.forcedweather"),
        Target = TrainerEffects.Targets.World,
        State = Weather.Current
    }
end

local function Add(list, entry, now)
    local hiddenUntil = s_Hidden[entry.Id]
    if hiddenUntil and now < hiddenUntil then return end
    s_Hidden[entry.Id] = nil
    table.insert(list, entry)
end

local function Build(now)
    local list = {}
    for _, applied in ipairs(StatModifiers.Active()) do Add(list, StatEntry(applied), now) end
    for _, owner in ipairs(InputBlock.Holds()) do Add(list, HoldEntry(owner), now) end

    for _, id in ipairs(WORLD_IDS) do
        local definition = Hotkeys.Find(id)
        if definition and Hotkeys.IsOn(definition) then Add(list, WorldEntry(definition), now) end
    end
    if Weather.Forced and not Weather.Freeze then Add(list, WeatherEntry(), now) end

    return list
end

function TrainerEffects.List()
    local now = os.clock()
    if now >= s_NextBuild then
        s_List = Build(now)
        s_NextBuild = now + REFRESH
    end
    return s_List
end

function TrainerEffects.Stats(entry)
    local stats = {}
    for _, item in ipairs(entry.Applied and entry.Applied.Entries or {}) do
        table.insert(stats, { Label = StatName(item[1]), Value = ModifierValue(item[2], item[3]) })
    end
    return stats
end

local function ReleaseWeather()
    Weather.ResetWeather()
end

local function Apply(entry)
    local turnedOff = entry.Definition ~= nil and Hotkeys.TurnOff(entry.Definition)

    if entry.Kind == TrainerEffects.Kinds.Stat then
        StatModifiers.Drop(entry.Owner)
    elseif entry.Kind == TrainerEffects.Kinds.Hold and not entry.Definition then
        InputBlock.Release(entry.Owner)
    elseif entry.Kind == TrainerEffects.Kinds.Weather then
        World.Run(ReleaseWeather)
    end

    s_Hidden[entry.Id] = os.clock() + HIDE_TIME
    s_NextBuild = 0
    return turnedOff
end

function TrainerEffects.Returns(entry)
    return entry.Definition == nil and entry.Kind ~= TrainerEffects.Kinds.Weather
end

function TrainerEffects.Remove(entry)
    local turnedOff = Apply(entry)
    if turnedOff then
        Notify.Success(tip("notify.effects.turnedoff", { name = entry.Name }))
    elseif TrainerEffects.Returns(entry) then
        Notify.Warning(tip("notify.effects.mayreturn", { name = entry.Name }))
    else
        Notify.Success(tip("notify.effects.removed", { name = entry.Name }))
    end
end

function TrainerEffects.ClearAll()
    s_NextBuild = 0
    local list = TrainerEffects.List()
    if #list == 0 then
        Notify.Info(L("notify.effects.nothing"))
        return
    end

    local count = #list
    for _, entry in ipairs(list) do Apply(entry) end
    Notify.Success(tip("notify.effects.clearedall", { count = count }))
end

return TrainerEffects
