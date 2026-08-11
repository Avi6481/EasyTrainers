local Surface = require("UI/Widgets/Surface/Surface")
local Animation = require("UI/Widgets/Animation/Animation")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Highlight = require("UI/Widgets/Core/Highlight")
local Navigation = require("UI/Navigation/Navigation")
local Tip = require("UI/Panels/Tip/Tip")
local Style = require("UI/Style/Style")
local Widget = require("UI/Widgets/Core/Widget")
local DropdownStyle = require("UI/Widgets/Dropdown/DropdownStyle")
local DropdownNavigation = require("UI/Widgets/Dropdown/DropdownNavigation")
local SurfaceStyle = require("UI/Widgets/Surface/SurfaceStyle")

local Dropdown = {}

local function displayText(value)
    if type(L) == "function" then
        local ok, translated = pcall(L, value)
        if ok and translated ~= nil then return tostring(translated) end
    end
    return tostring(value or "")
end

Dropdown.Surface = Surface.Create("##EasyTrainerDropdown")
Dropdown.Opened = false
Dropdown.OwnerId = nil
Dropdown.ChangedOwner = nil
Dropdown.Label = ""
Dropdown.Items = {}
Dropdown.Value = nil
Dropdown.Current = 1
Dropdown.FirstVisible = 1
Dropdown.OnChange = nil
Dropdown.HighlightY = nil

function Dropdown.Initialize()
    Surface.Initialize(Dropdown.Surface)
    Dropdown.Opened = false
    Dropdown.OwnerId = nil
    Dropdown.ChangedOwner = nil
    Dropdown.Label = ""
    Dropdown.Items = {}
    Dropdown.Value = nil
    Dropdown.Current = 1
    Dropdown.FirstVisible = 1
    Dropdown.OnChange = nil
    Dropdown.HighlightY = nil
end

function Dropdown.Open(ownerId, label, valueRef, items, onChange)
    Dropdown.Opened = true
    Dropdown.OwnerId = ownerId
    Dropdown.ChangedOwner = nil
    Dropdown.Label = label or ""
    Dropdown.Items = items or {}
    Dropdown.Value = valueRef
    Dropdown.Current = math.max(1, math.min(valueRef and valueRef.index or 1, math.max(1, #Dropdown.Items)))
    Dropdown.FirstVisible = 1
    Dropdown.OnChange = onChange
    Dropdown.HighlightY = nil
    Surface.Open(Dropdown.Surface)
    Navigation.State.EnterMode(Navigation.State.Mode.Dropdown)
    Navigation.State.BlockMouseInput = true
end

function Dropdown.Close()
    Dropdown.Opened = false
    Dropdown.OwnerId = nil
    Dropdown.Value = nil
    Dropdown.OnChange = nil
    Surface.Close(Dropdown.Surface)
    Navigation.State.LeaveMode()
end

function Dropdown.Select(index)
    if not Dropdown.Items[index] then return false end
    Dropdown.Current = index
    if Dropdown.Value then Dropdown.Value.index = index end
    Dropdown.ChangedOwner = Dropdown.OwnerId
    local onChange = Dropdown.OnChange
    Navigation.Input.SelectPressed = false
    Dropdown.Close()
    if onChange then onChange(index, Dropdown.Items[index]) end
    return true
end

function Dropdown.ConsumeChanged(ownerId)
    if Dropdown.ChangedOwner ~= ownerId then return false end
    Dropdown.ChangedOwner = nil
    return true
end

function Dropdown.Update()
    DropdownNavigation.Update(Dropdown)
end

local function mouseInteraction(x, y, width, height)
    if not Navigation.State.MouseEnabled then return false, false end
    local mouseX, mouseY = ImGui.GetMousePos()
    local hovered = mouseX >= x and mouseX <= x + width and mouseY >= y and mouseY <= y + height
    return hovered, hovered and ImGui.IsMouseClicked(0)
end

function Dropdown.Option(id, label, valueRef, items, tip, onChange)
    local data = Widget.Begin(true)
    local changed = Dropdown.ConsumeChanged(id)
    if not data.Visible then return changed, data end

    local hovered, clicked = mouseInteraction(data.X, data.Y, data.Width, data.Height)
    data.Hovered = hovered
    if clicked then Navigation.State.Current = data.Index end
    if data.Selected then Highlight.Set(data.Y, data.Height) end
    if data.Selected or data.Hovered then Tip.Set(tip or "", id) end

    local drawList = ImGui.GetWindowDrawList()
    local textY = data.Y + ((data.Height - ImGui.GetFontSize()) * 0.5)
    local index = math.max(1, math.min(valueRef.index or 1, math.max(1, #items)))
    local current = Draw.FitText(displayText(items[index]), data.Width * 0.45)
    local currentWidth = ImGui.CalcTextSize(current)
    local arrow = Dropdown.Opened and Dropdown.OwnerId == id and "v" or ">"
    local arrowWidth = ImGui.CalcTextSize(arrow)
    Draw.Text(drawList, data.X + 8, textY, Style.Text,
        Draw.FitText(label, data.Width - currentWidth - arrowWidth - 42))
    Draw.Text(drawList, data.X + data.Width - 8 - arrowWidth, textY, Style.Accent, arrow)
    Draw.Text(drawList, data.X + data.Width - 18 - arrowWidth - currentWidth, textY, Style.Text, current)

    if (clicked or (data.Selected and Navigation.Input.SelectPressed))
        and Navigation.State.ModeCurrent == Navigation.State.Mode.Menu then
        Dropdown.Open(id, label, valueRef, items, onChange)
    end

    return changed, data
end

function Dropdown.Draw()
    if not Dropdown.Opened and Dropdown.Surface.Alpha < 0.01 then return end

    local visibleCount = math.min(#Dropdown.Items, DropdownStyle.MaxVisibleItems)
    local listHeight = visibleCount * DropdownStyle.OptionHeight
    local height = DropdownStyle.HeaderHeight + listHeight + DropdownStyle.FooterHeight
        + (SurfaceStyle.Padding * 2)
    if not Surface.Begin(Dropdown.Surface, DropdownStyle.SurfaceWidth, height) then return end

    local drawList = ImGui.GetWindowDrawList()
    local x = Dropdown.Surface.X + SurfaceStyle.Padding
    local y = Dropdown.Surface.Y + SurfaceStyle.Padding
    local width = DropdownStyle.SurfaceWidth - (SurfaceStyle.Padding * 2)

    local headerLabel = Draw.FitText(Dropdown.Label, width * 0.4)
    local selectedText = Draw.FitText(displayText(Dropdown.Items[Dropdown.Current]), width * 0.52)
    Draw.Text(drawList, x, y, Style.TextDisabled, headerLabel)
    local selectedWidth = ImGui.CalcTextSize(selectedText)
    Draw.Text(drawList, x + width - selectedWidth, y, Style.Accent, selectedText)
    Draw.Line(drawList, x, y + DropdownStyle.HeaderHeight - 7,
        x + width, y + DropdownStyle.HeaderHeight - 7, Style.Border, 1)
    local listY = y + DropdownStyle.HeaderHeight

    if Dropdown.Current < Dropdown.FirstVisible then Dropdown.FirstVisible = Dropdown.Current end
    if Dropdown.Current >= Dropdown.FirstVisible + visibleCount then
        Dropdown.FirstVisible = Dropdown.Current - visibleCount + 1
    end
    Dropdown.FirstVisible = math.max(1, math.min(Dropdown.FirstVisible, math.max(1, #Dropdown.Items - visibleCount + 1)))

    local rowWidth = width
    local selectedRow = Dropdown.Current - Dropdown.FirstVisible
    local targetHighlightY = listY + (selectedRow * DropdownStyle.OptionHeight)
    Dropdown.HighlightY = Animation.Animate(Dropdown.HighlightY or targetHighlightY,
        targetHighlightY, 20, Context.DeltaTime)
    Draw.RectFilled(drawList, x, Dropdown.HighlightY, rowWidth, DropdownStyle.OptionHeight,
        Animation.WithAlpha(Style.Accent, 0.22), SurfaceStyle.Rounding)
    Draw.LeftAccent(drawList, x, Dropdown.HighlightY, DropdownStyle.OptionHeight,
        Style.Accent, SurfaceStyle.Rounding, 3)

    for row = 0, visibleCount - 1 do
        local index = Dropdown.FirstVisible + row
        local item = Dropdown.Items[index]
        if item then
            local rowY = listY + (row * DropdownStyle.OptionHeight)
            local hovered, clicked = mouseInteraction(x, rowY, rowWidth, DropdownStyle.OptionHeight)
            if hovered then Dropdown.Current = index end

            if index ~= Dropdown.Current and hovered then
                Draw.RectFilled(drawList, x, rowY, rowWidth, DropdownStyle.OptionHeight,
                    DropdownStyle.HoveredRow, SurfaceStyle.Rounding)
            end

            local textY = rowY + ((DropdownStyle.OptionHeight - ImGui.GetFontSize()) * 0.5)
            Draw.Text(drawList, x + 8, textY, Style.Text,
                Draw.FitText(displayText(item), rowWidth - 34))
            if Dropdown.Value and Dropdown.Value.index == index then
                Draw.Text(drawList, x + rowWidth - 16, textY, Style.Accent, "*")
            end

            if clicked then Dropdown.Select(index) end
        end
    end

    local footerY = listY + listHeight
    Draw.Line(drawList, x, footerY + 5, x + width, footerY + 5, Style.Border, 1)
    local position = string.format("%d / %d", Dropdown.Current, #Dropdown.Items)
    local positionWidth = ImGui.CalcTextSize(position)
    Draw.Text(drawList, x, footerY + 11, Style.TextDisabled, "SELECT")
    Draw.Text(drawList, x + width - positionWidth, footerY + 11, Style.TextDisabled, position)

    Surface.End(Dropdown.Surface)
end

return Dropdown

