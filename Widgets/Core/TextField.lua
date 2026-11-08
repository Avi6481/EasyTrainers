local Draw = require("Core/Draw")
local Input = require("Core/Input")
local State = require("Core/State")
local Style = require("Style/Style")
local Scale = require("Style/Scale")
local Navigation = require("Navigation/Navigation")
local TextFieldStyle = require("Widgets/Core/TextFieldStyle")

local TextField = {}

TextField.Result = {
    None = 0,
    Confirmed = 1,
    Cancelled = 2
}

local s_Id = nil
local s_Buffer = ""
local s_Fresh = false
local s_Frame = 0
local s_MaxLength = 64
local s_Filter = nil

local function Length(text)
    local count = 0
    for _ in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do count = count + 1 end
    return count
end

local function Append(character)
    if s_Fresh then
        s_Buffer = ""
        s_Fresh = false
    end

    if Length(s_Buffer) >= s_MaxLength then return end
    if s_Filter and not s_Filter(character, s_Buffer) then return end
    s_Buffer = s_Buffer .. character
end

local function RemoveLast()
    local cut = #s_Buffer
    while cut > 1 and s_Buffer:byte(cut) >= 0x80 and s_Buffer:byte(cut) < 0xC0 do cut = cut - 1 end
    s_Buffer = s_Buffer:sub(1, cut - 1)
end

local function DeleteWord()
    s_Buffer = s_Buffer:gsub("%s+$", "")
    s_Buffer = s_Buffer:gsub("%S+$", "")
end

local function Backspace(word)
    if s_Fresh then
        s_Buffer = ""
    elseif word then
        DeleteWord()
    else
        RemoveLast()
    end
    s_Fresh = false
end

local function Paste()
    if not TextFieldStyle.AllowPaste then return end
    local ok, clipboard = pcall(ImGui.GetClipboardText)
    if not ok or type(clipboard) ~= "string" then return end

    for character in clipboard:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local byte = character:byte(1)
        if byte >= 32 and byte ~= 127 then Append(character) end
    end
end

function TextField.Begin(id, text, maxLength, filter, replace)
    s_Id = id
    s_Buffer = tostring(text or "")
    s_Fresh = replace ~= false
    s_Frame = State.Time.Frame
    s_MaxLength = maxLength or 64
    s_Filter = filter

    Navigation.State.Editing = true
    State.SetTyping(true)
    Input.BeginText()
end

function TextField.End()
    s_Id = nil
    s_Buffer = ""
    s_Filter = nil

    Navigation.State.Editing = false
    State.SetTyping(false)
    Input.EndText()
end

function TextField.Active(id)
    return s_Id ~= nil and s_Id == id
end

function TextField.AnyActive()
    return s_Id ~= nil
end

function TextField.Update()
    if s_Id == nil or State.Time.Frame == s_Frame then return TextField.Result.None end

    for character in Input.TypedText():gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local byte = character:byte(1)
        if byte == 13 or byte == 10 then return TextField.Result.Confirmed end
        if byte == 27 then return TextField.Result.Cancelled end

        if byte == 8 then
            Backspace(false)
        elseif byte == 127 then
            Backspace(true)
        elseif byte == 22 then
            Paste()
        elseif byte >= 32 then
            Append(character)
        end
    end

    if Input.KeyPressed(Input.VK.Escape) then return TextField.Result.Cancelled end
    if Input.KeyPressed(Input.VK.Return) then return TextField.Result.Confirmed end
    return TextField.Result.None
end

function TextField.Text()
    return s_Buffer
end

function TextField.Fresh()
    return s_Fresh
end

function TextField.Width(placeholder, fontSize)
    local shown = (s_Buffer == "" and placeholder) and placeholder or s_Buffer
    local text = Draw.TextSize(shown, fontSize) + Draw.TextSize("0", fontSize)
    return math.max(Scale.S(TextFieldStyle.MinWidth), text + Scale.S(TextFieldStyle.PaddingX * 2))
end

function TextField.DrawBox(x, y, width, fontSize, placeholder)
    local padX = Scale.S(TextFieldStyle.PaddingX)
    local padY = Scale.S(TextFieldStyle.PaddingY)
    local _, textHeight = Draw.TextSize("Ag", fontSize)
    local height = textHeight + (padY * 2)
    local top = y - (height * 0.5)
    local rounding = Scale.S(TextFieldStyle.Rounding)

    Draw.RectFilled(x, top, width, height, TextFieldStyle.Fill, rounding)
    Draw.Rect(x, top, width, height, Style.Accent, rounding)

    local inner = width - (padX * 2)
    local textWidth = Draw.TextSize(s_Buffer, fontSize)
    local shift = math.max(0, textWidth + 2 - inner)

    Draw.PushClip(x + padX, top, inner, height)

    if s_Buffer == "" and placeholder then
        Draw.Text(x + padX, top + padY, Style.TextDisabled, placeholder, fontSize)
    else
        Draw.Text(x + padX - shift, top + padY, s_Fresh and Style.TextDisabled or Style.Text, s_Buffer, fontSize)
    end

    local blink = math.max(0.1, TextFieldStyle.CaretBlink)
    if (State.Time.Time % blink) < blink * 0.5 then
        local caretX = x + padX - shift + textWidth + 1
        Draw.Line(caretX, top + padY, caretX, top + padY + textHeight, Style.Text, 1)
    end

    Draw.PopClip()
end

return TextField
