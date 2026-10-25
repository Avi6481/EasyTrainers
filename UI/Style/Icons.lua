local Layout = require("UI/Style/Layout")

local GLYPHS = {
    Submenu = { "ChevronRight", ">" },
    Back = { "ChevronLeft", "<" },
    Expanded = { "ChevronDown", "v" },
    Collapsed = { "ChevronRight", ">" },
    Selected = { "Check", "*" }
}

local Icons = setmetatable({}, {
    __index = function(_, key)
        local entry = GLYPHS[key]
        if not entry then return nil end

        local glyphs = IconGlyphs
        if Layout.UseIcons ~= false and glyphs and glyphs[entry[1]] then return glyphs[entry[1]] end
        return entry[2]
    end
})

return Icons
