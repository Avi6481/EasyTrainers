local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local HighlightStyle = require("Widgets/Core/HighlightStyle")
local SubmenuBar = require("Panels/SubmenuBar/SubmenuBar")
local SheetStyle = require("Panels/Sheet/SheetStyle")

local Sheet = {}

local s_Sheet = {
    Open = false,
    Owner = nil,
    OpenFrame = 0,
    Title = "",
    Items = {},
    Value = 1,
    Current = 1,
    Progress = 0,
    ProgressVelocity = 0,
    HighlightY = 0,
    HighlightVelocity = 0,
    HighlightPlaced = false,
    Scroll = 0,
    ScrollVelocity = 0,
    FirstVisible = 0,
    ResultReady = false,
    ResultOwner = nil,
    ResultIndex = 1
}

local function Normalize(item)
    if type(item) ~= "table" then return { Label = tostring(item), Detail = "", Tip = "" } end
    return { Label = tostring(item.Label or ""), Detail = tostring(item.Detail or ""), Tip = tostring(item.Tip or "") }
end

local function MeasureSheet()
    local menu = State.Menu
    local margin = Scale.S(SheetStyle.Margin)
    local padding = Scale.S(SheetStyle.Padding)
    local titleHeight = Scale.S(SheetStyle.TitleHeight)

    local rect = {}
    rect.ContentTop = menu.Y + Scale.S(Layout.HeaderHeight) + SubmenuBar.Height()
    rect.FooterTop = menu.Y + menu.Height - Scale.S(Layout.FooterHeight)
    rect.RowHeight = Scale.S(SheetStyle.RowHeight)
    rect.X = menu.X + margin
    rect.Width = menu.Width - (margin * 2)

    local available = (rect.FooterTop - rect.ContentTop) * math.max(0.2, math.min(1, SheetStyle.MaxHeight))
    local listMax = math.max(rect.RowHeight, available - titleHeight - (padding * 2))
    local listFull = #s_Sheet.Items * rect.RowHeight

    rect.VisibleRows = math.max(1, math.floor(listMax / rect.RowHeight))
    rect.ListHeight = math.min(listFull, rect.VisibleRows * rect.RowHeight)
    rect.Height = titleHeight + rect.ListHeight + (padding * 2)

    rect.Y = rect.FooterTop - (rect.Height * s_Sheet.Progress)
    rect.ListY = rect.Y + titleHeight + padding
    return rect
end

function Sheet.CloseSheet()
    s_Sheet.Open = false
end

local function Choose(index)
    s_Sheet.ResultReady = true
    s_Sheet.ResultOwner = s_Sheet.Owner
    s_Sheet.ResultIndex = index
    s_Sheet.Value = index
    Sheet.CloseSheet()
end

local function RowY(rect, index)
    return rect.ListY + ((index - 1) * rect.RowHeight) - s_Sheet.Scroll
end

local function UpdateScroll(rect)
    local maxFirst = math.max(0, #s_Sheet.Items - rect.VisibleRows)
    local current = s_Sheet.Current - 1

    if current < s_Sheet.FirstVisible then s_Sheet.FirstVisible = current end
    if current >= s_Sheet.FirstVisible + rect.VisibleRows then s_Sheet.FirstVisible = current - rect.VisibleRows + 1 end

    s_Sheet.FirstVisible = math.max(0, math.min(maxFirst, s_Sheet.FirstVisible))

    local target = s_Sheet.FirstVisible * rect.RowHeight
    s_Sheet.Scroll, s_Sheet.ScrollVelocity = Animation.SmoothDamp(s_Sheet.Scroll, target, s_Sheet.ScrollVelocity, SheetStyle.SlideTime, State.Time.Delta)
end

local function UpdateMouse(rect)
    if not State.Menu.Cursor then return end

    local _, mouseY = Input.MousePos()
    local inSheet = Input.MouseIn(rect.X, rect.Y, rect.Width, rect.Height)
    local inList = Input.MouseIn(rect.X, rect.ListY, rect.Width, rect.ListHeight)

    if inList then
        local index = math.floor((mouseY - rect.ListY + s_Sheet.Scroll) / rect.RowHeight) + 1
        index = math.max(1, math.min(#s_Sheet.Items, index))

        if Input.MouseMoved() then s_Sheet.Current = index end

        if Input.MouseReleased(Input.Mouse.Left) then
            Choose(index)
            return
        end
    end

    if not inSheet and Input.MouseReleased(Input.Mouse.Left) then Sheet.CloseSheet() end
end

function Sheet.OpenSheet(owner, title, items, current)
    if not items or #items == 0 then return end

    local normalized = {}
    for _, item in ipairs(items) do table.insert(normalized, Normalize(item)) end

    s_Sheet.Open = true
    s_Sheet.Owner = owner
    s_Sheet.OpenFrame = State.Time.Frame
    s_Sheet.Title = tostring(title or "")
    s_Sheet.Items = normalized

    s_Sheet.Value = math.max(1, math.min(#normalized, math.floor(current or 1)))
    s_Sheet.Current = s_Sheet.Value
    s_Sheet.FirstVisible = 0
    s_Sheet.HighlightPlaced = false
    s_Sheet.ResultReady = false

    local rect = MeasureSheet()
    if s_Sheet.Current - 1 >= rect.VisibleRows then
        s_Sheet.FirstVisible = (s_Sheet.Current - 1) - math.floor(rect.VisibleRows / 2)
    end

    s_Sheet.Scroll = math.max(0, s_Sheet.FirstVisible) * rect.RowHeight
    s_Sheet.ScrollVelocity = 0
end

function Sheet.SheetTip()
    if not s_Sheet.Open then return "" end

    local item = s_Sheet.Items[s_Sheet.Current]
    if not item then return "" end
    return item.Tip
end

function Sheet.SheetOpen()
    return s_Sheet.Open
end

function Sheet.SheetVisible()
    return s_Sheet.Open or s_Sheet.Progress > 0.01
end

function Sheet.SheetMove(direction)
    local count = #s_Sheet.Items
    if not s_Sheet.Open or count <= 0 then return end

    s_Sheet.Current = ((s_Sheet.Current - 1 + direction) % count) + 1
end

function Sheet.SheetHighlighted(owner)
    if not s_Sheet.Open or s_Sheet.Owner ~= owner then return nil end
    return s_Sheet.Current
end

function Sheet.TakeSheetResult(owner)
    if not s_Sheet.ResultReady or s_Sheet.ResultOwner ~= owner then return nil end

    s_Sheet.ResultReady = false
    return s_Sheet.ResultIndex
end

function Sheet.Update()
    local target = s_Sheet.Open and 1 or 0
    s_Sheet.Progress, s_Sheet.ProgressVelocity = Animation.SmoothDamp(s_Sheet.Progress, target, s_Sheet.ProgressVelocity, SheetStyle.SlideTime, State.Time.Delta)

    if not s_Sheet.Open then return end

    if not State.Menu.Open then
        Sheet.CloseSheet()
        return
    end

    local rect = MeasureSheet()
    UpdateScroll(rect)

    if State.Time.Frame == s_Sheet.OpenFrame then return end

    local nav = Navigation.State
    local selected = nav.SelectPressed
    local back = nav.BackPressed

    nav.SelectPressed = false
    nav.BackPressed = false

    if selected then
        Choose(s_Sheet.Current)
        return
    end

    if back or Input.KeyPressed(Input.VK.Escape) then
        Sheet.CloseSheet()
        return
    end

    UpdateMouse(rect)
end

local function DrawRows(rect)
    local padding = Scale.S(Layout.Padding)
    local rowX = rect.X + Scale.S(SheetStyle.Padding)
    local rowWidth = rect.Width - Scale.S(SheetStyle.Padding * 2)
    local rounding = Scale.S(HighlightStyle.Rounding)
    local fontSize = Scale.FontSize()

    local target = RowY(rect, s_Sheet.Current)
    if not s_Sheet.HighlightPlaced then
        s_Sheet.HighlightY = target
        s_Sheet.HighlightVelocity = 0
        s_Sheet.HighlightPlaced = true
    end

    s_Sheet.HighlightY, s_Sheet.HighlightVelocity = Animation.SmoothDamp(s_Sheet.HighlightY, target, s_Sheet.HighlightVelocity, HighlightStyle.SmoothTime, State.Time.Delta)

    Draw.PushClip(rect.X, rect.ListY, rect.Width, rect.ListHeight)

    Draw.RectFilled(rowX, s_Sheet.HighlightY, rowWidth, rect.RowHeight, HighlightStyle.Fill, rounding)
    if HighlightStyle.ShowAccent then
        Draw.LeftAccent(rowX, s_Sheet.HighlightY, rect.RowHeight, Style.Accent, rounding, Scale.S(HighlightStyle.AccentWidth))
    end
    if HighlightStyle.BorderSize > 0 then
        Draw.Rect(rowX, s_Sheet.HighlightY, rowWidth, rect.RowHeight, HighlightStyle.Border, rounding, 0, HighlightStyle.BorderSize)
    end

    local ringRadius = Scale.S(SheetStyle.CurrentRingRadius)
    local dotX = rowX + padding + ringRadius
    local textX = dotX + ringRadius + Scale.S(8)

    for index, item in ipairs(s_Sheet.Items) do
        local y = RowY(rect, index)
        if y + rect.RowHeight >= rect.ListY and y <= rect.ListY + rect.ListHeight then
            local centerY = y + (rect.RowHeight * 0.5)
            local isValue = index == s_Sheet.Value
            local isCurrent = index == s_Sheet.Current

            Draw.CircleFilled(dotX, centerY, Scale.S(SheetStyle.DotRadius), isValue and Style.Accent or SheetStyle.DotOff)
            if isValue then Draw.Circle(dotX, centerY, ringRadius, Style.Accent, 1.4) end

            local color = (isCurrent or isValue) and Style.Text or Style.TextSoft
            Draw.Text(textX, centerY - (fontSize * 0.5), color, item.Label, fontSize)

            if item.Detail ~= "" then
                local detailSize = fontSize * SheetStyle.DetailScale
                local detailWidth, detailHeight = Draw.TextSize(item.Detail, detailSize)
                local detailX = rowX + rowWidth - padding - detailWidth
                local detailColor = isCurrent and Style.TextSoft or Style.TextDisabled
                Draw.Text(detailX, centerY - (detailHeight * 0.5), detailColor, item.Detail, detailSize)
            end
        end
    end

    Draw.PopClip()
end

function Sheet.Draw()
    if s_Sheet.Progress < 0.01 then return end

    local menu = State.Menu
    local rect = MeasureSheet()
    local progress = math.max(0, math.min(1, s_Sheet.Progress))
    local areaHeight = rect.FooterTop - rect.ContentTop

    Draw.RectFilled(menu.X, rect.ContentTop, menu.Width, areaHeight, Draw.RGBA(0, 0, 0, math.floor(255 * SheetStyle.DimAlpha * progress)))

    Draw.PushClip(menu.X, rect.ContentTop, menu.Width, areaHeight)

    local rounding = Scale.S(Layout.Rounding)
    local titleHeight = Scale.S(SheetStyle.TitleHeight)
    local fill = Draw.Opaque(SheetStyle.UseMenuBackground and Style.Background or SheetStyle.Fill)

    Draw.RectFilled(rect.X, rect.Y, rect.Width, rect.Height + rounding, fill, rounding, Draw.Corners.Top)

    if SheetStyle.ShowAccentLine then
        local lineHeight = Scale.S(SheetStyle.AccentLineHeight)
        Draw.RectFilled(rect.X, rect.Y + titleHeight - lineHeight, rect.Width, lineHeight, Style.Accent)
    end

    local padding = Scale.S(Layout.Padding)
    local fontSize = Scale.FontSize()
    local titleY = rect.Y + ((titleHeight - fontSize) * 0.5)
    Draw.Text(rect.X + padding, titleY, Style.Text, s_Sheet.Title, fontSize)

    if SheetStyle.ShowCount then
        local count = string.format("%d / %d", s_Sheet.Current, #s_Sheet.Items)
        local width = Draw.TextSize(count, fontSize)
        Draw.Text(rect.X + rect.Width - padding - width, titleY, Style.TextDisabled, count, fontSize)
    end

    DrawRows(rect)

    Draw.PopClip()
end

return Sheet
