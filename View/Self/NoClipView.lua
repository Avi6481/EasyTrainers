local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Self = require("Features/Self/Self")

local NoClipView = {}

local s_Enabled = Ref.Field(Self.NoClip, "Enabled")
local s_Speed = Ref.Field(Self.NoClip, "Speed")
local s_Boost = Ref.Field(Self.NoClip, "Boost")
local s_FollowCamera = Ref.Field(Self.NoClip, "FollowCamera")

local function Toggle(key, ref)
    Widgets.Toggle(L(key .. ".label"), ref)
    Widgets.Tip(L(key .. ".tip"))
end

local function SliderFloat(key, ref, min, max, step, format)
    Widgets.SliderFloat(L(key .. ".label"), ref, min, max, step, format)
    Widgets.Tip(L(key .. ".tip"))
end

local function Control(action)
    local key = "noclip.controls." .. action:lower()
    if Widgets.KeyBind(L(key .. ".label"), Self.NoClip.Controls[action]) then Self.NoClip.ApplyControls() end
    Widgets.Tip(L(key .. ".tip"))
end

local function View()
    Toggle("noclip.enabled", s_Enabled)
    SliderFloat("noclip.speed", s_Speed, 0.5, 10, 0.5, "%.1fx")
    SliderFloat("noclip.boost", s_Boost, 1, 10, 0.5, "%.1fx")
    Toggle("noclip.followcamera", s_FollowCamera)

    Widgets.Break(L("noclip.controls.title"))
    for _, action in ipairs(Self.NoClip.Actions) do Control(action) end

    if Widgets.Button(L("noclip.resetcontrols.label")) then Self.NoClip.ResetControls() end
    Widgets.Tip(L("noclip.resetcontrols.tip"))
end

NoClipView.Menu = Submenu.Create("noclip.title", View)

return NoClipView
