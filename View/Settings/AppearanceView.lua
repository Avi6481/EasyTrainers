local UI = require("UI")
local Defaults = require("UI/Style/Defaults")
local Layout = require("UI/Style/Layout")
local Style = require("UI/Style/Style")
local UIConfig = require("Config/UIConfig")

local Buttons = UI.Buttons

local width = { value = Layout.Width, min = 300, max = 900, step = 10 }
local height = { value = Layout.Height, min = 360, max = 900, step = 10 }
local optionHeight = { value = Layout.OptionHeight, min = 22, max = 52, step = 1 }
local padding = { value = Layout.Padding, min = 2, max = 30, step = 1 }
local spacing = { value = Layout.Spacing, min = 0, max = 12, step = 1 }
local rounding = { value = Layout.Rounding, min = 0, max = 20, step = 1 }
local palette = { index = 1 }
local paletteNames = {
    "Night City Blue", "Samurai Red", "Arasaka Gold", "Neon Violet",
    "Afterlife Teal", "Kiroshi Amber", "NCPD Cobalt", "Lucy",
    "David Martinez", "Rebecca",
}
local palettes = {
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
}

for index, entry in ipairs(palettes) do
    if entry.Accent == Style.Accent then palette.index = index break end
end

local function ApplyPalette(index)
    local selected = palettes[index or palette.index]
    if not selected then return end
    for key, value in pairs(selected) do Style[key] = value end
end

local function ApplyLayout()
    Layout.Width = width.value
    Layout.Height = height.value
    Layout.OptionHeight = optionHeight.value
    Layout.Padding = padding.value
    Layout.Spacing = spacing.value
    Layout.Rounding = rounding.value
    UI.Renderer.RequestResize()
end

local function ResetAppearance()
    for key, value in pairs(Defaults.Layout) do Layout[key] = value end
    for key, value in pairs(Defaults.Colors) do Style[key] = value end
    width.value, height.value = Layout.Width, Layout.Height
    optionHeight.value, padding.value = Layout.OptionHeight, Layout.Padding
    spacing.value, rounding.value = Layout.Spacing, Layout.Rounding
    UI.Renderer.RequestResize()
end

local function DrawAppearance()
    Buttons.Int("Menu width", width, "Width of the main trainer window.", ApplyLayout)
    Buttons.Int("Menu height", height, "Height of the main trainer window.", ApplyLayout)
    Buttons.Int("Option height", optionHeight, "Height of each option row.", ApplyLayout)
    Buttons.Int("Outer padding", padding, "Padding around menu content.", ApplyLayout)
    Buttons.Int("Row spacing", spacing, "Space between option rows.", ApplyLayout)
    Buttons.Int("Corner rounding", rounding, "Window and panel corner rounding.", ApplyLayout)

    Buttons.Break("Colors", "")
    Buttons.Dropdown("Color scheme", palette, paletteNames,
        "Choose a restrained Night City accent palette.", ApplyPalette)
    Buttons.ColorHex("Background", Style, "Background", "Main window background color.")
    Buttons.ColorHex("Raised background", Style, "BackgroundLight", "Breadcrumb and raised surface color.")
    Buttons.ColorHex("Accent", Style, "Accent", "Primary selection and control accent.")
    Buttons.ColorHex("Text", Style, "Text", "Primary text color.")
    Buttons.ColorHex("Muted text", Style, "TextDisabled", "Secondary and informational text color.")
    Buttons.ColorHex("Border", Style, "Border", "Panel and frame border color.")

    Buttons.Break("Actions", "")
    Buttons.Option("Save appearance", "Save the consolidated UI appearance.", UIConfig.Save)
    Buttons.Option("Reset appearance", "Restore the consolidated UI defaults.", ResetAppearance)
end

return { title = "Appearance", view = DrawAppearance }
