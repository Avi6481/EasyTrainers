local Logger = require("Core/Logger")
local Input = require("Core/Input")
local State = require("Controls/State")
local StatusEffect = require("Utils/StatusEffect")
local UIConfig = require("Config/UIConfig")
local Lifecycle = require("Core/Lifecycle")

local Restrictions = {}

local OWNER = "Menu"
local CLEANUP_DELAY = 3.0
local EXTRA_STALE = {
    "GameplayRestriction.NoFallDamage", "GameplayRestriction.BlockFastTravel",
    "GameplayRestriction.PhoneCall", "GameplayRestriction.BinocularView"
}

Restrictions.Modes = {
    { Id = "Closed", Label = "Menu Closed", Tip = "Controls blocked while the trainer menu is closed." },
    { Id = "Keyboard", Label = "Menu Open (Keyboard)", Tip = "Controls blocked while you browse the menu with the keyboard." },
    { Id = "Controller", Label = "Menu Open (Controller)", Tip = "Controls blocked while you browse the menu with a controller." },
    { Id = "Mouse", Label = "Mouse Mode", Tip = "Controls blocked while the menu cursor is on." },
    { Id = "Typing", Label = "Typing Mode", Tip = "Controls blocked while a text box is open." }
}

Restrictions.Catalog = {
    { Id = "GameplayRestriction.NoMovement", Label = "Movement" },
    { Id = "GameplayRestriction.NoJump", Label = "Jumping" },
    { Id = "GameplayRestriction.NoSprint", Label = "Sprinting" },
    { Id = "GameplayRestriction.NoCameraControl", Label = "Camera Look" },
    { Id = "GameplayRestriction.NoWeapons", Label = "Weapons" },
    { Id = "GameplayRestriction.NoCombat", Label = "Combat" },
    { Id = "GameplayRestriction.Melee", Label = "Melee" },
    { Id = "GameplayRestriction.NoQuickMelee", Label = "Quick Melee" },
    { Id = "GameplayRestriction.NoZooming", Label = "Aim Zoom" },
    { Id = "GameplayRestriction.NoScanning", Label = "Scanner" },
    { Id = "GameplayRestriction.NoHealing", Label = "Healing Items" },
    { Id = "GameplayRestriction.NoPhone", Label = "Phone" },
    { Id = "GameplayRestriction.NoDriving", Label = "Driving" },
    { Id = "GameplayRestriction.VehicleNoSummoning", Label = "Vehicle Summon" },
    { Id = "GameplayRestriction.VehicleNoInteraction", Label = "Enter and Exit Vehicles" },
    { Id = "GameplayRestriction.NoRadialMenus", Label = "Radial Menus" },
    { Id = "GameplayRestriction.BlockAllHubMenu", Label = "Hub Menus" },
    { Id = "GameplayRestriction.NoPhotoMode", Label = "Photo Mode" },
    { Id = "GameplayRestriction.NoWorldInteractions", Label = "World Interactions" },
    { Id = "GameplayRestriction.BlockDeviceInteractions", Label = "Device Interactions" },
    { Id = "GameplayRestriction.InDaClub", Label = "Club Lockdown" }
}

local DEFAULTS = {
    Closed = {},
    Keyboard = { "GameplayRestriction.NoDriving" },
    Controller = {
        "GameplayRestriction.NoPhone", "GameplayRestriction.VehicleNoSummoning",
        "GameplayRestriction.NoHealing", "GameplayRestriction.NoJump", "GameplayRestriction.InDaClub"
    },
    Mouse = "All",
    Typing = {
        "GameplayRestriction.BlockAllHubMenu", "GameplayRestriction.NoDriving", "GameplayRestriction.Melee",
        "GameplayRestriction.NoPhone", "GameplayRestriction.VehicleNoSummoning",
        "GameplayRestriction.NoHealing", "GameplayRestriction.NoJump", "GameplayRestriction.NoMovement",
        "GameplayRestriction.NoPhotoMode", "GameplayRestriction.NoQuickMelee", "GameplayRestriction.NoScanning",
        "GameplayRestriction.NoSprint"
    }
}

Restrictions.Blocked = {}

local ALL_EXCEPT = { ["GameplayRestriction.InDaClub"] = true }
local DEFAULTS_VERSION = 2

local function FillDefaults(mode)
    local blocked = Restrictions.Blocked[mode] or {}
    local defaults = DEFAULTS[mode]
    for _, entry in ipairs(Restrictions.Catalog) do
        blocked[entry.Id] = defaults == "All" and not ALL_EXCEPT[entry.Id]
    end
    if type(defaults) == "table" then
        for _, id in ipairs(defaults) do blocked[id] = true end
    end
    Restrictions.Blocked[mode] = blocked
end

for _, mode in ipairs(Restrictions.Modes) do FillDefaults(mode.Id) end
local s_Settings = { DefaultsVersion = 0 }
UIConfig.RegisterSection("BlockedControls", Restrictions.Blocked)
UIConfig.RegisterSection("BlockedControlsMeta", s_Settings)

local function Migrate()
    if (s_Settings.DefaultsVersion or 0) >= DEFAULTS_VERSION then return end
    FillDefaults("Mouse")
    s_Settings.DefaultsVersion = DEFAULTS_VERSION
    UIConfig.Save()
end

local s_Applied = nil
local s_AppliedMode = nil
local s_CleanupAt = nil
local s_Cleaned = false

function Restrictions.RemoveStale()
    local effects = {}
    for _, entry in ipairs(Restrictions.Catalog) do table.insert(effects, entry.Id) end
    for _, effect in ipairs(EXTRA_STALE) do table.insert(effects, effect) end
    return StatusEffect.RemoveStale(effects)
end

local function CleanupAfterLoad()
    if s_Cleaned then return end
    if not Game.GetPlayer() then
        s_CleanupAt = nil
        return
    end

    local now = os.clock()
    s_CleanupAt = s_CleanupAt or (now + CLEANUP_DELAY)
    if now < s_CleanupAt then return end

    local removed = Restrictions.RemoveStale()
    if removed == nil then return end
    s_Cleaned = true
    if removed > 0 then Logger.Log(string.format("Restrictions: cleared %d stale restrictions from the save", removed)) end
end

local function CurrentMode()
    if not State.IsMenuOpen() then return "Closed" end
    if State.TypingEnabled then return "Typing" end
    if State.MouseEnabled then return "Mouse" end
    if Input.IsController() then return "Controller" end
    return "Keyboard"
end

function Restrictions.Clear()
    if not s_Applied then return end
    for _, effect in ipairs(s_Applied) do StatusEffect.Set(effect, false, OWNER) end
    s_Applied = nil
    s_AppliedMode = nil
end

function Restrictions.Refresh()
    Restrictions.Clear()
end

function Restrictions.SetBlocked(mode, effect, blocked)
    Restrictions.Blocked[mode][effect] = blocked
    UIConfig.Save()
    if s_AppliedMode == mode then Restrictions.Refresh() end
end

function Restrictions.ResetMode(mode)
    FillDefaults(mode)
    UIConfig.Save()
    if s_AppliedMode == mode then Restrictions.Refresh() end
end

local function BlockedList(mode)
    local list = {}
    for _, entry in ipairs(Restrictions.Catalog) do
        if Restrictions.Blocked[mode][entry.Id] then table.insert(list, entry.Id) end
    end
    return list
end

function Restrictions.Update()
    Migrate()
    CleanupAfterLoad()
    if State.IsMenuOpen() then Input.UpdateDevice() end

    local mode = CurrentMode()
    if mode == s_AppliedMode then return end

    Restrictions.Clear()
    Restrictions.RemoveStale()
    local list = BlockedList(mode)
    for _, effect in ipairs(list) do StatusEffect.Set(effect, true, OWNER) end
    s_Applied = list
    s_AppliedMode = mode
    Logger.Log(string.format("Restrictions: applied %s (%d blocked)", mode, #list))
end

Lifecycle.Register("Restrictions", {
    OnSessionEnd = function()
        s_Applied = nil
        s_AppliedMode = nil
        s_CleanupAt = nil
        s_Cleaned = false
    end
})

return Restrictions
