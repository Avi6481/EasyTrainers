local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Weapons = require("Features/Weapons/Weapons")

local WeaponSettingsView = {}

local KEY = "weapons.settings."

local s_Power = Ref.Field(Weapons.ForceGun, "Power")
local s_Distance = Ref.Field(Weapons.GravityGun, "Distance")
local s_Range = Ref.Field(Weapons.TeleportGun, "Range")

local function Slider(key, ref, min, max, step, format)
    Widgets.SliderFloat(L(KEY .. key .. ".label"), ref, min, max, step, format)
    Widgets.Tip(L(KEY .. key .. ".tip"))
end

local function View()
    Slider("forcepower", s_Power, 5, 100, 5, "%.0f")
    Slider("gravitydistance", s_Distance, 3, 20, 0.5, "%.1f m")
    Slider("teleportrange", s_Range, 25, 500, 25, "%.0f m")

    local controls = Weapons.Controls
    Widgets.Break(L(KEY .. "controls"))
    for _, action in ipairs(controls.Actions) do
        local key = KEY .. "keys." .. action:lower()
        if Widgets.KeyBind(L(key .. ".label"), controls.Binds[action]) then controls.Fill() end
        Widgets.Tip(L(key .. ".tip"))
    end
    if Widgets.Button(L(KEY .. "resetkeys.label")) then controls.Reset() end
    Widgets.Tip(L(KEY .. "resetkeys.tip"))
end

WeaponSettingsView.Menu = Submenu.Create("weapons.settings.label", View)

return WeaponSettingsView
