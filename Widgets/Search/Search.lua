local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Icons = require("Core/Icons")
local Input = require("Core/Input")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local Highlight = require("Widgets/Core/Highlight")
local Row = require("Widgets/Core/Row")
local TextField = require("Widgets/Core/TextField")
local Widget = require("Widgets/Core/Widget")
local Toggle = require("Widgets/Toggle/Toggle")
local SliderStyle = require("Widgets/Slider/SliderStyle")

local Search = {}

local ICON_SCALE = 0.66
local ICON_GAP = 10
local MAX_LENGTH = 48
local BOX_INSET = 6

local s_Before = ""

local function Printable(character)
    local byte = character:byte(1)
    return #character == 1 and byte >= 32 and byte < 127
end

function Search.Match(text, query)
    local haystack = string.lower(tostring(text or ""))
    for word in string.lower(tostring(query or "")):gmatch("[^ ]+") do
        if not string.find(haystack, word, 1, true) then return false end
    end
    return true
end

function Search.Draw(ref, placeholder, results)
    placeholder = placeholder or "Search"
    results = results or -1

    local data = Widget.Begin(placeholder, true)
    local state = Row.Animate(data)

    local query = ref.Value or ""
    local before = query
    local editing = TextField.Active(data.Id)

    local controlWidth = Toggle.ControlWidth()
    local padding = Scale.S(Layout.Padding)
    local rowLeft = data.X + padding
    local rowRight = data.X + data.Width - padding
    local columnCenter = rowRight - (controlWidth * 0.5)
    local columnLeft = rowRight - controlWidth
    local centerY = data.Y + (data.Height * 0.5)

    if editing then
        if not data.Selected then
            TextField.End()
        else
            local result = TextField.Update()
            query = TextField.Text()

            if result == TextField.Result.Cancelled then
                query = s_Before
                TextField.End()
            elseif result == TextField.Result.Confirmed then
                TextField.End()
            elseif Input.KeyPressed(Input.VK.Down) then
                TextField.End()
                Navigation.MoveDown()
            end
        end
    elseif data.Selected then
        local mouseX = Input.MousePos()
        local clickClear = data.Clicked and query ~= "" and mouseX >= columnLeft

        if clickClear or Input.KeyPressed(Input.VK.Delete) then
            query = ""
        elseif data.Activated or Navigation.State.EditPressed then
            s_Before = query
            TextField.Begin(data.Id, query, MAX_LENGTH, Printable, false)
        end
    end

    ref.Value = query
    editing = TextField.Active(data.Id)

    local fontSize = Scale.FontSize()
    local iconSize = fontSize * ICON_SCALE
    local icon = Icons.Get("Search")
    local iconWidth, iconHeight = Draw.TextSize(icon, iconSize)
    local textX = rowLeft + iconWidth + Scale.S(ICON_GAP)

    local slider = SliderStyle
    local valueSize = fontSize * slider.ValueScale
    local gap = Scale.S(slider.ValueGap)
    local valueRight = columnLeft - gap

    local count = ""
    if query ~= "" and results >= 0 then count = string.format(results == 1 and "%d result" or "%d results", results) end

    local countWidth, countHeight = 0, 0
    if count ~= "" then countWidth, countHeight = Draw.TextSize(count, valueSize) end
    local countSpace = count ~= "" and (countWidth + gap) or 0

    if data.Selected then
        local hint = nil
        if not editing then hint = Highlight.SelectHint() end
        Highlight.SetHint(hint, (rowRight - valueRight) + countSpace + gap)
    end

    if not data.Visible then return query ~= before end

    Row.DrawBackground(data, state)

    local active = math.max(state.Select, state.Hover)
    local iconAmount = (editing or query ~= "") and 1 or (active * 0.5)
    local iconColor = Animation.LerpColor(Style.TextDisabled, Style.Accent, iconAmount)
    Draw.Text(rowLeft, centerY - (iconHeight * 0.5), iconColor, icon, iconSize)

    if editing then
        local boxX = textX - Scale.S(BOX_INSET)
        TextField.DrawBox(boxX, centerY, columnLeft - boxX, valueSize, placeholder)
        return query ~= before
    end

    if count ~= "" then Draw.Text(valueRight - countWidth, centerY - (countHeight * 0.5), Style.TextDisabled, count, valueSize) end

    local empty = query == ""
    local shown = Draw.FitText(empty and placeholder or query, valueRight - countSpace - textX, fontSize)
    local textColor = empty and Style.TextDisabled or Animation.LerpColor(Style.TextSoft, Style.Text, active)
    Draw.Text(textX, centerY - (fontSize * 0.5), textColor, shown, fontSize)

    if empty then return query ~= before end

    local clearSize = fontSize * ICON_SCALE
    local clearIcon = Icons.Get("Close")
    local clearWidth, clearHeight = Draw.TextSize(clearIcon, clearSize)
    local clearColor = Animation.LerpColor(Style.TextDisabled, Style.Text, active * 0.6)
    Draw.Text(columnCenter - (clearWidth * 0.5), centerY - (clearHeight * 0.5), clearColor, clearIcon, clearSize)

    return query ~= before
end

return Search
