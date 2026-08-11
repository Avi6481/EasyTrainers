local Defaults = require("UI/Style/Defaults")

local Style = {}
for key, value in pairs(Defaults.Colors) do Style[key] = value end

return Style


