local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Controls = require("Features/WorldEditor/Controls")
local FreeCam = require("Features/WorldEditor/FreeCam")
local Grab = require("Features/WorldEditor/Grab")
local Selection = require("Features/WorldEditor/Selection")
local PropSpawner = require("Features/WorldEditor/PropSpawner")
local Hud = require("Features/WorldEditor/Hud")
local GameHud = require("Features/WorldEditor/GameHud")
local Player = require("Features/WorldEditor/Player")
local Inspector = require("Features/WorldEditor/Inspector")
local Picker = require("Features/WorldEditor/Picker")

local SettingsView = {}

local s_MoveSpeed = Ref.Field(FreeCam, "MoveSpeed")
local s_FastMultiplier = Ref.Field(FreeCam, "FastMultiplier")
local s_SlowMultiplier = Ref.Field(FreeCam, "SlowMultiplier")
local s_Smoothing = Ref.Field(FreeCam, "Smoothing")
local s_MouseSensitivity = Ref.Field(FreeCam, "MouseSensitivity")
local s_StickLookSpeed = Ref.Field(FreeCam, "StickLookSpeed")
local s_InvertLook = Ref.Field(FreeCam, "InvertLook")
local s_FieldOfView = Ref.Field(FreeCam, "FieldOfView")
local s_BlendTime = Ref.Field(FreeCam, "BlendTime")
local s_WheelSpeed = Ref.Field(FreeCam, "WheelAdjustsSpeed")
local s_StickDeadzone = Ref.Field(FreeCam, "StickDeadzone")

local s_HoldDelay = Ref.Field(Grab, "HoldDelay")
local s_NudgeSpeed = Ref.Field(Grab, "NudgeSpeed")
local s_RotateSpeed = Ref.Field(Grab, "RotateSpeed")
local s_KeepFacing = Ref.Field(Grab, "KeepFacing")
local s_StandPeds = Ref.Field(Grab, "SnapPedsToGround")
local s_Outline = Ref.Field(Selection, "Highlight")

local s_HideGameHud = Ref.Field(GameHud, "Hide")
local s_ShowInfo = Ref.Field(Hud, "ShowInfo")
local s_ShowDebug = Ref.Field(Hud, "ShowDebug")
local s_ShowCrosshair = Ref.Field(Hud, "ShowCrosshair")
local s_ShowControls = Ref.Field(Hud, "ShowControls")
local s_ShowMarkers = Ref.Field(Hud, "ShowGrabMarkers")
local s_ShowBox = Ref.Field(Hud, "ShowTargetBox")
local s_ShowLinks = Ref.Field(Hud, "ShowAttachmentLinks")
local s_TraceDistance = Ref.Field(Inspector, "TraceDistance")
local s_SearchRange = Ref.Field(Picker, "SearchRange")

local s_Preview = Ref.Field(PropSpawner, "PreviewEnabled")
local s_PreviewDistance = Ref.Field(PropSpawner, "PreviewDistance")
local s_PreviewSpin = Ref.Field(PropSpawner, "PreviewSpin")
local s_HidePlayer = Ref.Field(Player, "Hide")
local s_FollowPlayer = Ref.Field(Player, "Follow")
local s_FollowDistance = Ref.Field(Player, "FollowDistance")

local function Link(key, menu)
    Widgets.SubmenuButton(L(key .. ".label"), menu)
    Widgets.Tip(L(key .. ".tip"))
end

local function Toggle(key, ref)
    Widgets.Toggle(L(key .. ".label"), ref)
    Widgets.Tip(L(key .. ".tip"))
end

local function SliderFloat(key, ref, min, max, step, format)
    Widgets.SliderFloat(L(key .. ".label"), ref, min, max, step, format)
    Widgets.Tip(L(key .. ".tip"))
end

local function SliderInt(key, ref, min, max, step, format)
    Widgets.SliderInt(L(key .. ".label"), ref, min, max, step, format)
    Widgets.Tip(L(key .. ".tip"))
end

local function Bind(key, action)
    if Widgets.KeyBind(L(key .. ".label"), Controls.Binds[action]) then Controls.Changed() end
    Widgets.Tip(L(key .. ".tip"))
end

local function CameraView()
    SliderFloat("worldeditor.camera.movespeed", s_MoveSpeed, FreeCam.MinSpeed, FreeCam.MaxSpeed, 0.5, "%.1f m/s")
    SliderFloat("worldeditor.camera.fast", s_FastMultiplier, 1, 20, 0.5, "%.1fx")
    SliderFloat("worldeditor.camera.slow", s_SlowMultiplier, 0.05, 1, 0.05, "%.2fx")
    SliderInt("worldeditor.camera.smoothing", s_Smoothing, 0, 30, 1, "%d")
    SliderFloat("worldeditor.camera.mouse", s_MouseSensitivity, 0.1, 5, 0.1, "%.1fx")
    SliderInt("worldeditor.camera.stick", s_StickLookSpeed, 20, 400, 10, "%d deg/s")
    Toggle("worldeditor.camera.invert", s_InvertLook)
    SliderInt("worldeditor.camera.fov", s_FieldOfView, 20, 120, 1, "%d deg")
    SliderFloat("worldeditor.camera.blend", s_BlendTime, 0, 3, 0.1, "%.1f s")
    Toggle("worldeditor.camera.wheel", s_WheelSpeed)
    SliderFloat("worldeditor.camera.deadzone", s_StickDeadzone, 0, 0.5, 0.01, "%.2f")
end

local function MoveView()
    SliderFloat("worldeditor.move.holddelay", s_HoldDelay, 0.1, 1, 0.05, "%.2f s")
    SliderFloat("worldeditor.move.nudgespeed", s_NudgeSpeed, 0.05, 5, 0.05, "%.2f m/s")
    SliderFloat("worldeditor.move.rotatespeed", s_RotateSpeed, 0.1, 5, 0.1, "%.1fx")
    Toggle("worldeditor.move.keepfacing", s_KeepFacing)
    Toggle("worldeditor.move.standpeds", s_StandPeds)
    Toggle("worldeditor.move.outline", s_Outline)
end

local function HudView()
    Toggle("worldeditor.hudsettings.hidegamehud", s_HideGameHud)
    Toggle("worldeditor.hudsettings.info", s_ShowInfo)
    Toggle("worldeditor.hudsettings.debug", s_ShowDebug)
    Toggle("worldeditor.hudsettings.crosshair", s_ShowCrosshair)
    Toggle("worldeditor.hudsettings.controlsbar", s_ShowControls)
    Toggle("worldeditor.hudsettings.grabmarkers", s_ShowMarkers)
    Toggle("worldeditor.hudsettings.targetbox", s_ShowBox)
    Toggle("worldeditor.hudsettings.links", s_ShowLinks)
    SliderInt("worldeditor.hudsettings.tracedistance", s_TraceDistance, 10, 1000, 10, "%d m")
    SliderInt("worldeditor.hudsettings.searchrange", s_SearchRange, 20, 500, 10, "%d m")
end

local function ControlsView()
    for index, group in ipairs(Controls.Groups) do
        if index > 1 then Widgets.Break(L("worldeditor.controls." .. group.Key)) end
        for _, action in ipairs(group.Actions) do Bind("worldeditor.controls." .. action:lower(), action) end
    end

    Widgets.Break("")
    if Widgets.Button(L("worldeditor.controls.reset.label")) then Controls.Reset() end
    Widgets.Tip(L("worldeditor.controls.reset.tip"))
end

local s_CameraMenu = Submenu.Create("worldeditor.settings.camera.label", CameraView)
local s_MoveMenu = Submenu.Create("worldeditor.settings.move.label", MoveView)
local s_HudMenu = Submenu.Create("worldeditor.settings.hud.label", HudView)
local s_ControlsMenu = Submenu.Create("worldeditor.settings.controls.label", ControlsView)

local function View()
    Link("worldeditor.settings.camera", s_CameraMenu)
    Link("worldeditor.settings.move", s_MoveMenu)
    Link("worldeditor.settings.hud", s_HudMenu)
    Link("worldeditor.settings.controls", s_ControlsMenu)

    Widgets.Break(L("worldeditor.settings.spawning"))
    Toggle("worldeditor.settings.preview", s_Preview)
    SliderFloat("worldeditor.settings.previewdistance", s_PreviewDistance, 1.5, 20, 0.5, "%.1f m")
    Toggle("worldeditor.settings.previewspin", s_PreviewSpin)

    Widgets.Break(L("worldeditor.settings.player"))
    Toggle("worldeditor.settings.hidev", s_HidePlayer)
    Toggle("worldeditor.settings.bringv", s_FollowPlayer)
    SliderInt("worldeditor.settings.bringdistance", s_FollowDistance, 20, 300, 10, "%d m")
end

SettingsView.Menu = Submenu.Create("worldeditor.settings.label", View)

return SettingsView
