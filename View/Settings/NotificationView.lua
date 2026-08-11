local UI = require("UI")

local Buttons = UI.Buttons
local Notification = UI.Notification

local position = { index = 1 }
local positions = {
    "Auto",
    "TopLeft",
    "TopCenter",
    "TopRight",
    "BottomLeft",
    "BottomCenter",
    "BottomRight",
}

local function DrawNotificationSettings()
    Buttons.Dropdown("Notification position", position, positions,
        "Choose where test and future configurable notifications appear.")

    Buttons.Break("Preview", "")
    Buttons.Option("Information notification", "Preview a standard notification.", function()
        Notification.Info("This is an information notification.", 3, positions[position.index])
    end)
    Buttons.Option("Success notification", "Preview a success notification.", function()
        Notification.Success("This is a success notification.", 3, positions[position.index])
    end)
    Buttons.Option("Warning notification", "Preview a warning notification.", function()
        Notification.Warning("This is a warning notification.", 3, positions[position.index])
    end)
    Buttons.Option("Error notification", "Preview an error notification.", function()
        Notification.Error("This is an error notification.", 3, positions[position.index])
    end)
end

return { title = "settings.notifications.title", view = DrawNotificationSettings }
