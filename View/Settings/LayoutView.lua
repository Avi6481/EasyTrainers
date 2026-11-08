local Ref = require("Core/Ref")
local Settings = require("Features/Settings/Settings")
local Layout = require("Style/Layout")
local Menu = require("Style/Menu")
local Scale = require("Style/Scale")
local Submenu = require("Navigation/Submenu")
local HighlightStyle = require("Widgets/Core/HighlightStyle")
local SliderStyle = require("Widgets/Slider/SliderStyle")
local ToggleStyle = require("Widgets/Toggle/ToggleStyle")
local Widgets = require("Widgets/Widgets")
local ControlsHudStyle = require("Panels/ControlsHud/ControlsHudStyle")
local SubmenuBarStyle = require("Panels/SubmenuBar/SubmenuBarStyle")
local TipBox = require("Panels/TipBox/TipBox")
local InfoPanel = require("Panels/InfoPanel/InfoPanel")

local LayoutView = {}

local TOGGLE_SHAPES = { ToggleStyle.Shapes.Orbit, ToggleStyle.Shapes.Light, ToggleStyle.Shapes.Switch }
local SLIDER_SHAPES = { SliderStyle.Shapes.Chevron, SliderStyle.Shapes.Ring, SliderStyle.Shapes.Track }

local s_ManualScale = Ref.New(function() return not Scale.Auto end, function(value)
    if value then Scale.Manual = Scale.Current end
    Scale.Auto = not value
end)

local s_Scale = Ref.New(function() return Scale.Auto and Scale.Current or Scale.Manual end, function(value)
    if not Scale.Auto then Scale.Manual = value end
end)

local s_TextSize = Ref.Scaled(Scale, "TextScale", 100)
local s_Width = Ref.New(function() return Settings.Window.Width end, function(value) Settings.SetWindowSize("Width", value) end)
local s_Height = Ref.New(function() return Settings.Window.Height end, function(value) Settings.SetWindowSize("Height", value) end)
local s_RowHeight = Ref.Field(Layout, "OptionHeight")
local s_Spacing = Ref.Field(Layout, "Spacing")
local s_Padding = Ref.Field(Layout, "Padding")
local s_Rounding = Ref.Field(Layout, "Rounding")
local s_SubmenuBar = Ref.Field(SubmenuBarStyle, "Enabled")
local s_ControlsBar = Ref.Field(ControlsHudStyle, "Enabled")
local s_TipBox = Ref.Field(TipBox.Style, "Enabled")
local s_InfoPanel = Ref.Field(InfoPanel.Style, "Enabled")
local s_KeyHints = Ref.Field(HighlightStyle, "ShowHint")
local s_EdgeFade = Ref.Field(Menu, "ShowEdgeFade")
local s_ToggleShape = Ref.Choice(ToggleStyle, "Shape", TOGGLE_SHAPES)
local s_SliderShape = Ref.Choice(SliderStyle, "Shape", SLIDER_SHAPES)

local function ShapeItems(shapes)
    local items = {}
    for index, shape in ipairs(shapes) do
        local key = "layout.shapes." .. shape:lower()
        items[index] = { Label = L(key .. ".label"), Tip = L(key .. ".tip") }
    end
    return items
end

local function Toggle(key, ref)
    Widgets.Toggle(L(key .. ".label"), ref)
    Widgets.Tip(L(key .. ".tip"))
end

local function SliderInt(key, ref, min, max, step, format)
    Widgets.SliderInt(L(key .. ".label"), ref, min, max, step, format)
    Widgets.Tip(L(key .. ".tip"))
end

local function View()
    Widgets.SliderFloat(L("layout.scale.label"), s_Scale, Scale.Min, 2, 0.05, "%.2fx", s_ManualScale)
    Widgets.Tip(L("layout.scale.tip"))
    SliderInt("layout.textsize", s_TextSize, 80, 130, 5, "%d%%")
    SliderInt("settings.window.width", s_Width, 300, 1200, 10)
    SliderInt("settings.window.height", s_Height, 360, 1000, 10)
    SliderInt("layout.rowheight", s_RowHeight, 24, 48, 1)
    SliderInt("layout.spacing", s_Spacing, 0, 10, 1)
    SliderInt("layout.padding", s_Padding, 4, 24, 1)
    SliderInt("layout.rounding", s_Rounding, 0, 16, 1)

    Widgets.Break(L("layout.panels"))
    Toggle("layout.submenubar", s_SubmenuBar)
    Toggle("layout.controlsbar", s_ControlsBar)
    Toggle("layout.tipbox", s_TipBox)
    Toggle("layout.infopanel", s_InfoPanel)
    Toggle("layout.keyhints", s_KeyHints)
    Toggle("layout.edgefade", s_EdgeFade)

    Widgets.Break(L("layout.controls"))
    Widgets.Dropdown(L("layout.toggleshape.label"), s_ToggleShape, ShapeItems(TOGGLE_SHAPES))
    Widgets.Tip(L("layout.toggleshape.tip"))
    Widgets.Dropdown(L("layout.slidershape.label"), s_SliderShape, ShapeItems(SLIDER_SHAPES))
    Widgets.Tip(L("layout.slidershape.tip"))
end

LayoutView.Menu = Submenu.Create("layout.title", View)

return LayoutView
