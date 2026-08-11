local Context = require("UI/Core/Context")
local Layout = require("UI/Style/Layout")
local Navigation = require("UI/Navigation/Navigation")
local Submenu = require("UI/Navigation/Submenu")

local Background = require("UI/Panels/Background/Background")
local Footer = require("UI/Panels/Footer/Footer")
local Header = require("UI/Panels/Header/Header")
local Notification = require("UI/Panels/Notification/Notification")
local SidePanel = require("UI/Panels/SidePanel/SidePanel")
local SubmenuBar = require("UI/Panels/SubmenuBar/SubmenuBar")
local Tip = require("UI/Panels/Tip/Tip")

local Dropdown = require("UI/Widgets/Dropdown/Dropdown")
local ColorPicker = require("UI/Widgets/ColorPicker/ColorPicker")
local Highlight = require("UI/Widgets/Core/Highlight")
local MainMenu = require("UI/MainMenu/MainMenu")
local Logger = require("Core/Logger")
local Animation = require("UI/Widgets/Animation/Animation")
local Draw = require("UI/Core/Draw")

local Renderer = {}

Renderer.Enabled = false
Renderer.Initialized = false
Renderer.FirstFrame = true
Renderer.DebugFramesRemaining = 0
Renderer.Dragging = false
Renderer.DragOffsetX = 0
Renderer.DragOffsetY = 0
Renderer.Alpha = 0

function Renderer.Initialize(rootSubmenu)
    Navigation.Initialize()
    Submenu.Initialize(rootSubmenu or MainMenu.GetRoot())
    Dropdown.Initialize()
    ColorPicker.Initialize()
    Highlight.Initialize()
    Notification.Initialize()
    SidePanel.Initialize()
    Tip.Initialize()
    Renderer.FirstFrame = true
    Renderer.DebugFramesRemaining = 8
    Renderer.Dragging = false
    Logger.Log(string.format(
        "UI Renderer: initialized; requested position=(%.1f, %.1f), size=(%.1f, %.1f), minimum=(%.1f, %.1f)",
        Layout.X, Layout.Y, Layout.Width, Layout.Height, Layout.MinimumWidth, Layout.MinimumHeight))
    Renderer.Initialized = true
end

function Renderer.SetRoot(rootSubmenu)
    Submenu.Initialize(rootSubmenu or MainMenu.GetRoot())
end

function Renderer.SetInput(input)
    Navigation.Input.Apply(input)
end

function Renderer.Enable(enabled)
    Renderer.Enabled = enabled ~= false
end

function Renderer.IsEnabled()
    return Renderer.Enabled
end

function Renderer.RequestResize() end

local function BeginWindow()
    Layout.Width = math.max(Layout.MinimumWidth, tonumber(Layout.Width) or Layout.DefaultWidth)
    Layout.Height = math.max(Layout.MinimumHeight, tonumber(Layout.Height) or Layout.DefaultHeight)

    ImGui.SetNextWindowSize(Layout.Width, Layout.Height, ImGuiCond.Always)
    ImGui.SetNextWindowPos(Layout.X, Layout.Y, ImGuiCond.Always)
    Renderer.FirstFrame = false

    local flags = ImGuiWindowFlags.NoDecoration + ImGuiWindowFlags.NoScrollbar
        + ImGuiWindowFlags.NoScrollWithMouse + ImGuiWindowFlags.NoSavedSettings
        + ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove
    return ImGui.Begin("EasyTrainer###EasyTrainerConsolidated", flags)
end

local function UpdateDragging()
    if not Navigation.State.MouseEnabled or Navigation.State.BlockMouseInput then
        Renderer.Dragging = false
        return
    end

    local mouseX, mouseY = ImGui.GetMousePos()
    local inHeader = mouseX >= Layout.X and mouseX <= Layout.X + Layout.Width
        and mouseY >= Layout.Y and mouseY <= Layout.Y + Layout.HeaderHeight

    if inHeader and ImGui.IsMouseClicked(0) then
        Renderer.Dragging = true
        Renderer.DragOffsetX = mouseX - Layout.X
        Renderer.DragOffsetY = mouseY - Layout.Y
    end

    if Renderer.Dragging then
        if ImGui.IsMouseDown(0) then
            local screenWidth, screenHeight = GetDisplayResolution()
            Layout.X = math.max(0, math.min(screenWidth - Layout.Width, mouseX - Renderer.DragOffsetX))
            Layout.Y = math.max(0, math.min(screenHeight - Layout.HeaderHeight, mouseY - Renderer.DragOffsetY))
        else
            Renderer.Dragging = false
        end
    end
end

local function BeginFrame(deltaTime)
    local x, y = ImGui.GetWindowPos()
    local width, height = ImGui.GetWindowSize()
    Layout.X, Layout.Y = x, y

    Context.Begin(deltaTime or (1 / 60), { X = x, Y = y, Width = width, Height = height })
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
    if not Renderer.Initialized then return end
    Renderer.Alpha = Animation.Animate(Renderer.Alpha, Renderer.Enabled and 1 or 0, 14, deltaTime or (1 / 60))
    if not Renderer.Enabled and Renderer.Alpha < 0.01 then return end

    ImGui.PushStyleVar(ImGuiStyleVar.Alpha, Renderer.Alpha)
    Draw.SetAlpha(Renderer.Alpha)
    local visible = BeginWindow()
    if Renderer.DebugFramesRemaining > 0 then
        local x, y = ImGui.GetWindowPos()
        local width, height = ImGui.GetWindowSize()
        Logger.Log(string.format(
            "UI Renderer: visible=%s requested=(%.1f, %.1f) actual position=(%.1f, %.1f), size=(%.1f, %.1f)",
            tostring(visible), Layout.Width, Layout.Height, x, y, width, height))
        Renderer.DebugFramesRemaining = Renderer.DebugFramesRemaining - 1
    end
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
    Renderer.Enabled = false
    Renderer.Alpha = 0
    Renderer.Initialized = false
    Navigation.Input.Clear()
end

return Renderer

