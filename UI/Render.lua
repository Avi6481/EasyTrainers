local Logger = require("Core/Logger")
local Context = require("UI/Core/Context")
local Draw = require("UI/Core/Draw")
local Layout = require("UI/Style/Layout")
local Navigation = require("UI/Navigation/Navigation")
local Submenu = require("UI/Navigation/Submenu")
local Animation = require("UI/Widgets/Animation/Animation")
local Highlight = require("UI/Widgets/Core/Highlight")
local Dropdown = require("UI/Widgets/Dropdown/Dropdown")
local ColorPicker = require("UI/Widgets/ColorPicker/ColorPicker")
local Background = require("UI/Panels/Background/Background")
local Footer = require("UI/Panels/Footer/Footer")
local Header = require("UI/Panels/Header/Header")
local Notification = require("UI/Panels/Notification/Notification")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local SubmenuBar = require("UI/Panels/SubmenuBar/SubmenuBar")
local Tip = require("UI/Panels/Tip/Tip")
local Mouse = require("Core/Mouse")

local Renderer = {}

local DEFAULT_DELTA = 1 / 60
local FADE_SPEED = 14
local WINDOW_FLAGS = ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoScrollbar
    + ImGuiWindowFlags.NoScrollWithMouse + ImGuiWindowFlags.NoSavedSettings
    + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove

local s_Initialized = false
local s_Enabled = false
local s_Alpha = 0
local s_Dragging = false
local s_DragOffsetX = 0
local s_DragOffsetY = 0

function Renderer.Initialize(root)
    Navigation.Initialize()
    Submenu.Initialize(root)
    Dropdown.Initialize()
    ColorPicker.Initialize()
    Highlight.Initialize()
    Notification.Initialize()
    SidePanel.Initialize()
    Tip.Initialize()

    s_Dragging = false
    s_Initialized = true
    Logger.Log(string.format("Renderer: initialized at (%.0f, %.0f) size (%.0f, %.0f)", Layout.X, Layout.Y, Layout.Width, Layout.Height))
end

function Renderer.SetInput(input)
    Navigation.Input.Apply(input)
end

function Renderer.Enable(enabled)
    s_Enabled = enabled ~= false
end

function Renderer.IsEnabled()
    return s_Enabled
end

local function BeginWindow()
    Layout.Width = math.max(Layout.MinimumWidth, tonumber(Layout.Width) or Layout.DefaultWidth)
    Layout.Height = math.max(Layout.MinimumHeight, tonumber(Layout.Height) or Layout.DefaultHeight)

    ImGui.SetNextWindowSize(Layout.Width, Layout.Height, ImGuiCond.Always)
    ImGui.SetNextWindowPos(Layout.X, Layout.Y, ImGuiCond.Always)
    local open = ImGui.Begin("EasyTrainer###EasyTrainerConsolidated", WINDOW_FLAGS)
    Layout.ApplyFontScale()
    return open
end

local function UpdateDragging()
    if not Navigation.State.MouseEnabled or Navigation.State.BlockMouseInput then
        s_Dragging = false
        return
    end

    local mouseX, mouseY = Mouse.GetPosition()
    local inHeader = mouseX >= Layout.X and mouseX <= Layout.X + Layout.Width
        and mouseY >= Layout.Y and mouseY <= Layout.Y + Layout.HeaderHeight

    if inHeader and Mouse.IsClicked() then
        s_Dragging = true
        s_DragOffsetX = mouseX - Layout.X
        s_DragOffsetY = mouseY - Layout.Y
    end

    if not s_Dragging then return end
    if not Mouse.IsDown() then
        s_Dragging = false
        return
    end

    local screenWidth, screenHeight = GetDisplayResolution()
    Layout.X = math.max(0, math.min(screenWidth - Layout.Width, mouseX - s_DragOffsetX))
    Layout.Y = math.max(0, math.min(screenHeight - Layout.HeaderHeight, mouseY - s_DragOffsetY))
end

local function BeginFrame(deltaTime)
    local x, y = ImGui.GetWindowPos()
    local width, height = ImGui.GetWindowSize()
    Layout.X, Layout.Y = x, y

    Context.Begin(deltaTime, { X = x, Y = y, Width = width, Height = height })
    UpdateDragging()
    Navigation.Begin()
    SidePanel.BeginFrame()
    Tip.BeginFrame()
end

local function UpdateWidgets()
    if Navigation.State.ModeCurrent == Navigation.State.Mode.Menu and Navigation.Input.BackPressed then
        Submenu.Close(Navigation, Layout)
    end

    Dropdown.Update()
    ColorPicker.Update()
    Highlight.Update()
end

local function DrawFrame()
    Background.Draw()
    Header.Draw()
    SubmenuBar.Draw()
    Highlight.Draw()
    Submenu.DrawCurrent()
    Dropdown.Draw()
    ColorPicker.Draw()
    Navigation.Update(Layout, Context.DeltaTime)
    Footer.Draw()
end

function Renderer.Render(deltaTime)
    if not s_Initialized then return end

    deltaTime = deltaTime or DEFAULT_DELTA
    s_Alpha = Animation.Animate(s_Alpha, s_Enabled and 1 or 0, FADE_SPEED, deltaTime)
    if not s_Enabled and s_Alpha < 0.01 then
        Navigation.Input.Clear()
        return
    end

    ImGui.PushStyleVar(ImGuiStyleVar.Alpha, s_Alpha)
    Draw.SetAlpha(s_Alpha)

    local visible = BeginWindow()
    if visible then
        BeginFrame(deltaTime)
        UpdateWidgets()
        DrawFrame()
    end
    ImGui.End()

    if visible then
        SidePanel.Draw()
        Tip.Draw()
    end

    ImGui.PopStyleVar()
    Draw.SetAlpha(1)
    Navigation.Input.Clear()
end

function Renderer.Shutdown()
    s_Enabled = false
    s_Alpha = 0
    s_Initialized = false
    Navigation.Input.Clear()
end

return Renderer
