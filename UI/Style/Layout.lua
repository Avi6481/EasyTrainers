local Defaults = require("UI/Style/Defaults")

local Layout = {}
for key, value in pairs(Defaults.Layout) do Layout[key] = value end

function Layout.GetContentBounds(bounds)
    return {
        X = bounds.X,
        Y = bounds.Y + Layout.HeaderHeight + Layout.SubmenuBarHeight,
        Width = bounds.Width,
        Height = bounds.Height - Layout.HeaderHeight - Layout.SubmenuBarHeight - Layout.FooterHeight,
    }
end

return Layout


