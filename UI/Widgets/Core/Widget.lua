local Widget = {}

local Context = require("UI/Core/Context")
local Layout = require("UI/Style/Layout")
local Navigation = require("UI/Navigation/Navigation")
local Highlight = require("UI/Widgets/Core/Highlight")
local Tip = require("UI/Panels/Tip/Tip")

function Widget.Begin(selectable)
    local index = Navigation.Next()
    if selectable == false then Navigation.RegisterNonSelectable(index) end

    Context.OptionCount = Context.OptionCount + 1

    local bounds = Context.Bounds
    local x = bounds.X + Layout.Padding
    local y = bounds.Y + Layout.HeaderHeight + Context.SubmenuBarHeight + Layout.Padding
        + ((index - 1) * (Layout.OptionHeight + Layout.Spacing)) - Navigation.State.ScrollOffset
    local width = bounds.Width - (Layout.Padding * 2)
    local height = Layout.OptionHeight

    local minY = bounds.Y + Layout.HeaderHeight + Context.SubmenuBarHeight + Layout.Padding
    local maxY = bounds.Y + bounds.Height - Layout.FooterHeight - Layout.Padding

    return {
        Index = index,
        Visible = y + height > minY and y + height <= maxY,
        Selected = Navigation.IsCurrent(index),
        Selectable = selectable ~= false,
        Hovered = false,
        X = x,
        Y = y,
        Width = width,
        Height = height,
    }
end

function Widget.Interact(data)
    if not data.Visible or not Navigation.State.MouseEnabled or Navigation.State.BlockMouseInput then
        return false, false
    end

    local mouseX, mouseY = ImGui.GetMousePos()
    local hovered = mouseX >= data.X and mouseX <= data.X + data.Width
        and mouseY >= data.Y and mouseY <= data.Y + data.Height
    local clicked = hovered and ImGui.IsMouseClicked(0)

    data.Hovered = hovered
    if clicked and data.Selectable then
        Navigation.State.Current = data.Index
        data.Selected = true
    end
    return hovered, clicked
end

function Widget.Prepare(data, tip, source)
    local hovered, clicked = Widget.Interact(data)
    if data.Selected and data.Selectable then Highlight.Set(data.Y, data.Height) end
    if data.Selected or hovered then Tip.Set(tip or "", source) end
    return clicked
end

function Widget.IsActivated(data, clicked)
    return data.Selectable and Navigation.State.ModeCurrent == Navigation.State.Mode.Menu
        and (clicked or (data.Selected and Navigation.Input.SelectPressed))
end

function Widget.GetTextY(data)
    return data.Y + ((data.Height - ImGui.GetFontSize()) * 0.5)
end

return Widget

