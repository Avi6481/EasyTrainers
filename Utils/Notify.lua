local Notification = require("Panels/Notification/Notification")

local Notify = {}

function Notify.Info(text, duration)
    Notification.Push(text, "info", duration)
end

function Notify.Success(text, duration)
    Notification.Push(text, "success", duration)
end

function Notify.Warning(text, duration)
    Notification.Push(text, "warning", duration)
end

function Notify.Error(text, duration)
    Notification.Push(text, "error", duration)
end

return Notify
