local Buttons = require("UI/Options/Buttons")
local Submenu = require("UI/Navigation/Submenu")
local Defaults = require("UI/Style/Defaults")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")
local UIConfig = require("Config/UIConfig")

local PALETTE_NAMES = {
    "Night City Blue", "Samurai Red", "Arasaka Gold", "Neon Violet",
    "Afterlife Teal", "Kiroshi Amber", "NCPD Cobalt", "Lucy",
    "David Martinez", "Rebecca", "King"
}

local SURFACE_KEYS = { "Background", "BackgroundLight", "BackgroundDark", "TextDisabled", "Border" }

local PALETTES = {
    { Accent = 0xFFA56E3A, AccentHover = 0xFFBE844C, AccentActive = 0xFF9314FF },
    { Accent = 0xFF463BE8, AccentHover = 0xFF6255F2, AccentActive = 0xFF2D28C8 },
    { Accent = 0xFF5AB8E7, AccentHover = 0xFF76CBF2, AccentActive = 0xFF3B94C7 },
    { Accent = 0xFFFF6CB8, AccentHover = 0xFFFF86CA, AccentActive = 0xFFE94E9D },
    { Accent = 0xFFB1C719, AccentHover = 0xFFC9D834, AccentActive = 0xFF96A90F },
    { Accent = 0xFF288CF2, AccentHover = 0xFF42A2FF, AccentActive = 0xFF1B70D2 },
    { Accent = 0xFFFF7943, AccentHover = 0xFFFF9162, AccentActive = 0xFFE25F2D },
    { Accent = 0xFFF0E17E, AccentHover = 0xFFF7EFA2, AccentActive = 0xFFE58BD6 },
    { Accent = 0xFF2DE6DC, AccentHover = 0xFF4AF4EE, AccentActive = 0xFF26BEF2 },
    { Accent = 0xFFEBC43A, AccentHover = 0xFFF5D85B, AccentActive = 0xFFAB4FEF },
    {
        Accent = 0xFF00D4F5, AccentHover = 0xFF40E4FF, AccentActive = 0xFF00AAFF,
        Background = 0xF5101214, BackgroundLight = 0xF5181B1F, BackgroundDark = 0xFA0A0B0C,
        TextDisabled = 0xFF6EB4C8, Border = 0xFF1E5F6E
    }
}

local LAYOUT_FIELDS = {
    { Field = "Width", Label = "Menu Width", Tip = "Width of the main trainer window.", Min = 300, Max = 900, Step = 10 },
    { Field = "Height", Label = "Menu Height", Tip = "Height of the main trainer window.", Min = 360, Max = 900, Step = 10 },
    { Field = "OptionHeight", Label = "Option Height", Tip = "Height of each option row.", Min = 22, Max = 52, Step = 1 },
    { Field = "Padding", Label = "Outer Padding", Tip = "Padding around menu content.", Min = 2, Max = 30, Step = 1 },
    { Field = "Spacing", Label = "Row Spacing", Tip = "Space between option rows.", Min = 0, Max = 12, Step = 1 },
    { Field = "Rounding", Label = "Corner Rounding", Tip = "Window and panel corner rounding.", Min = 0, Max = 20, Step = 1 },
    { Field = "FontScale", Label = "Text Size", Tip = "Size of the menu text in percent. Only affects EasyTrainer, not the rest of CET.", Min = 60, Max = 140, Step = 5 }
}

local s_Palette = { index = 1 }
local s_UseIcons = { value = true }
local s_LayoutRefs = {}

for _, field in ipairs(LAYOUT_FIELDS) do
    s_LayoutRefs[field.Field] = { value = Layout[field.Field], min = field.Min, max = field.Max, step = field.Step }
end

for index, palette in ipairs(PALETTES) do
    if palette.Accent == Style.Accent then
        s_Palette.index = index
        break
    end
end

local function ApplyPalette(index)
    for _, key in ipairs(SURFACE_KEYS) do Style[key] = Defaults.Colors[key] end
    for key, value in pairs(PALETTES[index] or {}) do Style[key] = value end
end

local function ResetAppearance()
    for key, value in pairs(Defaults.Layout) do Layout[key] = value end
    for key, value in pairs(Defaults.Colors) do Style[key] = value end
end

local function AppearanceView()
    for _, field in ipairs(LAYOUT_FIELDS) do
        local ref = s_LayoutRefs[field.Field]
        ref.value = Layout[field.Field]
        Buttons.Int(field.Label, ref, field.Tip, function(value) Layout[field.Field] = value end)
    end

    s_UseIcons.value = Layout.UseIcons ~= false
    Buttons.GhostToggle("Use Icons", s_UseIcons, "Show icons for arrows and checkmarks instead of plain characters.", function(value) Layout.UseIcons = value end)

    Buttons.Break("Colors")
    Buttons.Dropdown("Color Scheme", s_Palette, PALETTE_NAMES, "Choose a Night City accent palette.", ApplyPalette)
    Buttons.ColorHex("Background", Style, "Background", "Main window background color.")
    Buttons.ColorHex("Raised Background", Style, "BackgroundLight", "Breadcrumb and raised surface color.")
    Buttons.ColorHex("Accent", Style, "Accent", "Primary selection and control accent.")
    Buttons.ColorHex("Text", Style, "Text", "Primary text color.")
    Buttons.ColorHex("Muted Text", Style, "TextDisabled", "Secondary and informational text color.")
    Buttons.ColorHex("Border", Style, "Border", "Panel and frame border color.")

    Buttons.Break("Actions")
    Buttons.Option("Save Appearance", "Save the current layout and colors.", UIConfig.Save)
    Buttons.Option("Reset Appearance", "Restore the default layout and colors.", ResetAppearance)
end

return Submenu.Create("Appearance", AppearanceView)
