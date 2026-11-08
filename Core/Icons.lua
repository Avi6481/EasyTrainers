local Icons = {}

local NAMES = {
    Pencil = { "Pencil", "PencilOutline" },
    Lock = { "Lock", "LockOutline" },
    Keyboard = { "Keyboard", "KeyboardOutline" },
    Check = { "Check", "CheckBold" },
    Play = { "Play" },
    Plus = { "Plus" },
    Search = { "Magnify" },
    Close = { "Close" },
    ArrowUp = { "ArrowUp" },
    ArrowDown = { "ArrowDown" },
    ArrowLeft = { "ArrowLeft" },
    ArrowRight = { "ArrowRight" },
    Mouse = { "Mouse", "MouseVariant" },
    Controller = { "MicrosoftXboxController", "GamepadVariant", "Gamepad" },
    ChevronUp = { "ChevronUp" },
    ChevronDown = { "ChevronDown" }
}

local FALLBACKS = {
    Pencil = "Edit",
    Lock = "Locked",
    Keyboard = "Key",
    Check = "*",
    Play = ">",
    Plus = "+",
    Search = "?",
    Close = "x",
    ArrowUp = "^",
    ArrowDown = "v",
    ArrowLeft = "<",
    ArrowRight = ">",
    Mouse = "M",
    Controller = "Pad",
    ChevronUp = "^",
    ChevronDown = "v"
}

local s_Cache = {}

function Icons.Get(name)
    local cached = s_Cache[name]
    if cached then return cached end

    local glyphs = IconGlyphs
    local found = nil
    if glyphs then
        for _, key in ipairs(NAMES[name] or { name }) do
            if glyphs[key] then
                found = glyphs[key]
                break
            end
        end
    end

    found = found or FALLBACKS[name] or ""
    s_Cache[name] = found
    return found
end

return Icons
