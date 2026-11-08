local Draw = require("Core/Draw")
local Ref = require("Core/Ref")
local Theme = require("Style/Theme")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")

local ThemeView = {}

local COLORS = {
    { Key = "Accent", Label = "theme.accent" },
    { Key = "Background", Label = "theme.background" },
    { Key = "BackgroundLight", Label = "theme.surface" },
    { Key = "Text", Label = "theme.text" },
    { Key = "TextSoft", Label = "theme.softtext", Alpha = true },
    { Key = "TextDisabled", Label = "theme.mutedtext" },
    { Key = "Border", Label = "theme.border" },
    { Key = "Overlay", Label = "theme.overlay" }
}

local s_Theme = Ref.New(Theme.Index, Theme.Select)
local s_Opacity = Ref.Field(Theme.Settings, "Opacity")
local s_Editors = {}

for _, color in ipairs(COLORS) do
    s_Editors[color.Key] = {
        Value = {},
        OnChange = function(value) Theme.SetColor(color.Key, Draw.FromColorTable(value)) end
    }
end

local function ThemeItems()
    local current = Theme.Index()
    local items = {}

    for index, theme in ipairs(Theme.List()) do
        local key = "themes." .. theme.Id
        local detail = theme.Group and L("theme.groups." .. theme.Group) or ""
        if index == current and Theme.IsEdited() then detail = L("theme.edited") end
        items[index] = { Label = L(key .. ".label"), Detail = detail, Tip = L(key .. ".tip") }
    end
    return items
end

local function ColorRow(color)
    local editor = s_Editors[color.Key]
    Draw.ToColorTable(Theme.Color(color.Key), editor.Value)
    Widgets.ColorPicker(L(color.Label .. ".label"), editor.Value, color.Alpha, editor.OnChange)
    Widgets.Tip(L(color.Label .. ".tip"))
end

local function View()
    Widgets.Dropdown(L("theme.theme.label"), s_Theme, ThemeItems(), Theme.Preview)
    Widgets.Tip(L("theme.theme.tip"))
    if Widgets.SliderInt(L("theme.opacity.label"), s_Opacity, 40, 100, 5, "%d%%") then Theme.Refresh(true) end
    Widgets.Tip(L("theme.opacity.tip"))

    Widgets.Break(L("theme.colors"))
    for _, color in ipairs(COLORS) do ColorRow(color) end

    Widgets.Break()
    if Widgets.Button(L("theme.reset.label")) then Theme.ResetColors() end
    Widgets.Tip(L("theme.reset.tip"))
end

ThemeView.Menu = Submenu.Create("theme.title", View)

return ThemeView
