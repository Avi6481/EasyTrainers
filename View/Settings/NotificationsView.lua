local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Notify = require("Utils/Notify")
local Notification = require("Panels/Notification/Notification")

local NotificationsView = {}

local KEY = "settings.notifications."

local POSITIONS = { "Auto", "TopLeft", "TopCenter", "TopRight", "BottomLeft", "BottomCenter", "BottomRight" }

local PREVIEWS = {
    { Key = "info", Show = Notify.Info },
    { Key = "success", Show = Notify.Success },
    { Key = "warning", Show = Notify.Warning },
    { Key = "error", Show = Notify.Error }
}

local s_Enabled = Ref.Field(Notification.Style, "Enabled")
local s_Position = Ref.Choice(Notification.Style, "Position", POSITIONS)
local s_Duration = Ref.Field(Notification.Style, "Duration")
local s_Positions = nil

local function Positions()
    if s_Positions then return s_Positions end

    s_Positions = {}
    for index, position in ipairs(POSITIONS) do
        local key = KEY .. "positions." .. position:lower()
        s_Positions[index] = { Label = L(key .. ".label"), Tip = L(key .. ".tip") }
    end
    return s_Positions
end

local function Preview(preview)
    local key = KEY .. "previews." .. preview.Key
    if Widgets.Button(L(key .. ".label")) then preview.Show(L(key .. ".text")) end
    Widgets.Tip(L(key .. ".tip"))
end

local function View()
    Widgets.Toggle(L("layout.notifications.label"), s_Enabled)
    Widgets.Tip(L("layout.notifications.tip"))
    Widgets.Dropdown(L(KEY .. "position.label"), s_Position, Positions())
    Widgets.Tip(L(KEY .. "position.tip"))
    Widgets.SliderFloat(L(KEY .. "duration.label"), s_Duration, 1, 10, 0.5, "%.1fs")
    Widgets.Tip(L(KEY .. "duration.tip"))

    Widgets.Break(L(KEY .. "preview"))
    for _, preview in ipairs(PREVIEWS) do Preview(preview) end
end

NotificationsView.Menu = Submenu.Create("settings.notifications.title", View)

return NotificationsView
