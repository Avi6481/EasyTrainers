local Animation = require("Core/Animation")
local Draw = require("Core/Draw")
local State = require("Core/State")
local Style = require("Style/Style")
local Layout = require("Style/Layout")
local Scale = require("Style/Scale")
local ControlsHud = require("Panels/ControlsHud/ControlsHud")
local Sheet = require("Panels/Sheet/Sheet")

local TipBox = {}

local s_Pending = ""
local s_Suffix = ""
local s_JoinedTip = ""
local s_JoinedSuffix = ""
local s_Joined = ""
local s_Shown = ""
local s_Height = 0
local s_HeightVelocity = 0
local s_TextAlpha = 0
local s_Above = false

function TipBox.InitializeStyle()
    TipBox.Style = {
        Enabled = true,
        Gap = 6,
        PaddingX = 12,
        PaddingY = 9,
        Rounding = Layout.Rounding,
        TextScale = 0.9,
        SmoothTime = 0.08,
        FadeSpeed = 14
    }
end

TipBox.InitializeStyle()

function TipBox.SetTip(text)
    s_Pending = text and tostring(text) or ""
end

function TipBox.SetSuffix(text)
    s_Suffix = text or ""
end

local function Join(text, suffix)
    if s_JoinedTip ~= text or s_JoinedSuffix ~= suffix then
        s_JoinedTip = text
        s_JoinedSuffix = suffix
        s_Joined = text .. " " .. suffix
    end
    return s_Joined
end

local function DrawBox(x, y, width, height, wrap, paddingX, paddingY, size)
    Draw.RectFilled(x, y, width, height, Style.Background, Scale.S(TipBox.Style.Rounding))

    local previous = Draw.GetAlpha()
    Draw.SetAlpha(previous * s_TextAlpha)
    Draw.PushClip(x, y, width, height)
    Draw.TextWrapped(x + paddingX, y + paddingY, wrap, Style.TextSoft, s_Shown, size)
    Draw.PopClip()
    Draw.SetAlpha(previous)
end

function TipBox.Draw()
    local style = TipBox.Style

    local target = s_Pending
    if target ~= "" and s_Suffix ~= "" then target = Join(target, s_Suffix) end
    if Sheet.SheetOpen() then target = Sheet.SheetTip() end
    s_Pending = ""
    s_Suffix = ""

    if not style.Enabled then
        s_Height = 0
        return
    end

    if target ~= s_Shown and target ~= "" then
        s_Shown = target
        s_TextAlpha = math.min(s_TextAlpha, 0.35)
    end

    local visible = target ~= "" and State.Menu.Open

    local menu = State.Menu
    local delta = State.Time.Delta
    local paddingX = Scale.S(style.PaddingX)
    local paddingY = Scale.S(style.PaddingY)
    local size = Scale.FontSize() * style.TextScale
    local wrap = menu.Width - (paddingX * 2)

    local wanted = visible and (Draw.WrapHeight(s_Shown, wrap, size) + (paddingY * 2)) or 0
    s_Height, s_HeightVelocity = Animation.SmoothDamp(s_Height, wanted, s_HeightVelocity, style.SmoothTime, delta)
    s_TextAlpha = Animation.Animate(s_TextAlpha, visible and 1 or 0, style.FadeSpeed, delta)

    if s_Height < 0.5 then
        if not visible then s_Shown = "" end
        return
    end

    local gap = Scale.S(style.Gap)
    local below = menu.Y + menu.Height + gap + ControlsHud.Below()

    if visible then
        local _, screenHeight = GetDisplayResolution()
        s_Above = below + wanted > screenHeight - gap
    end

    local x = menu.X
    local height = s_Height
    local y = s_Above and (menu.Y - gap - ControlsHud.Above() - height) or below

    local ok, err = true, nil
    if Draw.BeginWindow("##EasyTrainerTip", x, y, menu.Width, height) then
        ok, err = pcall(DrawBox, x, y, menu.Width, height, wrap, paddingX, paddingY, size)
    end
    Draw.EndWindow()

    if not ok then error(err, 0) end
end

return TipBox
