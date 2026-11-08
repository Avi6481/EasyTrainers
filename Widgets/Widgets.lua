local Widget = require("Widgets/Core/Widget")
local Button = require("Widgets/Button/Button")
local Toggle = require("Widgets/Toggle/Toggle")
local Slider = require("Widgets/Slider/Slider")
local Dropdown = require("Widgets/Dropdown/Dropdown")
local InputText = require("Widgets/InputText/InputText")
local Break = require("Widgets/Break/Break")
local SubmenuButton = require("Widgets/SubmenuButton/SubmenuButton")
local ValueRow = require("Widgets/ValueRow/ValueRow")
local Radio = require("Widgets/Radio/Radio")
local Meter = require("Widgets/Meter/Meter")
local HoldButton = require("Widgets/HoldButton/HoldButton")
local KeyBind = require("Widgets/KeyBind/KeyBind")
local ColorPicker = require("Widgets/ColorPicker/ColorPicker")
local Search = require("Widgets/Search/Search")
local Preset = require("Widgets/Preset/Preset")

local Widgets = {}

Widgets.Tip = Widget.Tip
Widgets.Info = Widget.Info
Widgets.Selected = Widget.Selected

Widgets.Button = Button.Draw
Widgets.Toggle = Toggle.Draw
Widgets.SliderInt = Slider.Int
Widgets.SliderFloat = Slider.Float
Widgets.NumberActionInt = Slider.NumberActionInt
Widgets.NumberActionFloat = Slider.NumberActionFloat
Widgets.Dropdown = Dropdown.Draw
Widgets.InputText = InputText.Draw
Widgets.Break = Break.Draw
Widgets.SubmenuButton = SubmenuButton.Draw
Widgets.ValueRow = ValueRow.Draw
Widgets.Radio = Radio.Draw
Widgets.RadioList = Radio.List
Widgets.Meter = Meter.Draw
Widgets.LevelPips = Meter.LevelPips
Widgets.HoldButton = HoldButton.Draw
Widgets.KeyBind = KeyBind.Draw
Widgets.FormatBinding = KeyBind.FormatBinding
Widgets.ColorPicker = ColorPicker.Draw
Widgets.ColorToHex = ColorPicker.ToHex
Widgets.SearchRow = Search.Draw
Widgets.SearchMatch = Search.Match
Widgets.Preset = Preset.Draw

return Widgets
