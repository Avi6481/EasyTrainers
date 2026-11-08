local Input = require("Core/Input")
local State = require("Core/State")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local NavigationStyle = require("Navigation/NavigationStyle")
local Sheet = require("Panels/Sheet/Sheet")
local TipBox = require("Panels/TipBox/TipBox")
local InfoPanel = require("Panels/InfoPanel/InfoPanel")

local Widget = {}

Widget.Kinds = {
    Toggle = "Toggle",
    Slider = "Slider",
    Action = "Action"
}

local s_PressedIndex = 0
local s_LastSelected = false
local s_BindLabel = nil
local s_BindKind = nil
local s_BindFrame = -1

function Widget.Begin(label, pinned)
    local nav = Navigation.State
    local content = Navigation.Content()

    local data = {}
    data.Index = pinned and Navigation.NextPinned() or Navigation.Next()
    data.Id = tostring(label) .. "##" .. data.Index

    data.X = content.X
    data.Y = Navigation.RowY(data.Index)
    data.Width = content.Width
    data.Height = Scale.S(Layout.OptionHeight)

    local top = Navigation.IsPinned(data.Index) and content.Y or Navigation.ScrollTop()
    data.Visible = data.Y + data.Height > top and data.Y < content.Y + content.Height
    data.Hovered = Navigation.HoveredRow() == data.Index

    if data.Hovered then
        if NavigationStyle.MouseHoverSelects and Input.MouseMoved() then nav.Current = data.Index end

        if Input.MousePressed(Input.Mouse.Left) then
            s_PressedIndex = data.Index
            nav.Current = data.Index
        end
    end

    data.Selected = nav.Current == data.Index
    s_LastSelected = data.Selected

    local pressed = s_PressedIndex == data.Index
    data.Held = pressed and Input.MouseDown(Input.Mouse.Left)
    data.Clicked = pressed and data.Hovered and Input.MouseReleased(Input.Mouse.Left)
    data.Activated = data.Clicked or (data.Selected and nav.SelectPressed and not Sheet.SheetVisible())

    return data
end

function Widget.Bindable(data, label, kind)
    if not data.Selected then return end
    s_BindLabel = label
    s_BindKind = kind
    s_BindFrame = State.Time.Frame
end

function Widget.BindableRow()
    if s_BindFrame ~= State.Time.Frame then return nil, nil end
    return s_BindLabel, s_BindKind
end

function Widget.Tip(text)
    if s_LastSelected then TipBox.SetTip(text) end
end

function Widget.Selected()
    return s_LastSelected
end

function Widget.Info(build, value)
    if s_LastSelected then InfoPanel.Set(build(value)) end
end

function Widget.EndFrame()
    if not Input.MouseDown(Input.Mouse.Left) then s_PressedIndex = 0 end
end

return Widget
