local Input = require("Core/Input")

local Typing = {}

local VK_BACK = 0x08
local VK_RETURN = 0x0D
local VK_ESCAPE = 0x1B
local VK_SHIFT = 0x10
local VK_CONTROL = 0x11
local VK_V = 0x56
local REPEAT_DELAY = 0.45
local REPEAT_RATE = 0.04
local MAX_LENGTH = 256

local CHARACTERS = {
    [0x20] = { " ", " " },
    [0x30] = { "0", ")" }, [0x31] = { "1", "!" }, [0x32] = { "2", "@" }, [0x33] = { "3", "#" }, [0x34] = { "4", "$" },
    [0x35] = { "5", "%" }, [0x36] = { "6", "^" }, [0x37] = { "7", "&" }, [0x38] = { "8", "*" }, [0x39] = { "9", "(" },
    [0x60] = { "0", "0" }, [0x61] = { "1", "1" }, [0x62] = { "2", "2" }, [0x63] = { "3", "3" }, [0x64] = { "4", "4" },
    [0x65] = { "5", "5" }, [0x66] = { "6", "6" }, [0x67] = { "7", "7" }, [0x68] = { "8", "8" }, [0x69] = { "9", "9" },
    [0x6A] = { "*", "*" }, [0x6B] = { "+", "+" }, [0x6D] = { "-", "-" }, [0x6E] = { ".", "." }, [0x6F] = { "/", "/" },
    [0xBA] = { ";", ":" }, [0xBB] = { "=", "+" }, [0xBC] = { ",", "<" }, [0xBD] = { "-", "_" }, [0xBE] = { ".", ">" },
    [0xBF] = { "/", "?" }, [0xC0] = { "`", "~" }, [0xDB] = { "[", "{" }, [0xDC] = { "\\", "|" }, [0xDD] = { "]", "}" },
    [0xDE] = { "'", "\"" }
}

for code = 0x41, 0x5A do
    CHARACTERS[code] = { string.char(code + 32), string.char(code) }
end

local s_Held = {}
local s_BackspaceAt = nil
local s_NextRepeat = 0

local function Pressed(code)
    local down = Input.IsKeyDown(code)
    local wasDown = s_Held[code]
    s_Held[code] = down
    return down and not wasDown
end

local function Paste(buffer)
    local ok, text = pcall(ImGui.GetClipboardText)
    if not ok or type(text) ~= "string" then return buffer end
    return buffer .. text:gsub("[\r\n]", "")
end

local function RemoveLastCharacter(buffer)
    local cut = #buffer
    while cut > 1 and buffer:byte(cut) >= 0x80 and buffer:byte(cut) < 0xC0 do cut = cut - 1 end
    return buffer:sub(1, cut - 1)
end

local function Backspace(buffer, now)
    if not Input.IsKeyDown(VK_BACK) then
        s_BackspaceAt = nil
        return buffer
    end

    if not s_BackspaceAt then
        s_BackspaceAt = now
        s_NextRepeat = now + REPEAT_DELAY
        return RemoveLastCharacter(buffer)
    end

    if now < s_NextRepeat then return buffer end
    s_NextRepeat = now + REPEAT_RATE
    return RemoveLastCharacter(buffer)
end

local function ApplyNativeText(buffer, text)
    for index = 1, #text do
        local byte = text:byte(index)
        if byte == 8 then
            buffer = RemoveLastCharacter(buffer)
        elseif byte == 10 or byte == 13 then
            return buffer, true, false
        elseif byte == 27 then
            return buffer, false, true
        elseif byte >= 32 then
            buffer = buffer .. string.char(byte)
        end
    end
    return buffer, false, false
end

function Typing.End()
    Input.EndTextCapture()
end

function Typing.Begin()
    Input.BeginTextCapture()
    Input.ConsumeTypedText()
    s_Held = {}
    for code in pairs(CHARACTERS) do s_Held[code] = Input.IsKeyDown(code) end
    s_Held[VK_RETURN] = Input.IsKeyDown(VK_RETURN)
    s_Held[VK_ESCAPE] = Input.IsKeyDown(VK_ESCAPE)
    s_BackspaceAt = nil
end

function Typing.Update(buffer)
    buffer = buffer or ""
    local native = Input.ConsumeTypedText()
    if native ~= nil then
        local submitted, cancelled
        buffer, submitted, cancelled = ApplyNativeText(buffer, native)
        return buffer:sub(1, MAX_LENGTH), submitted, cancelled
    end

    local now = os.clock()
    local shift = Input.IsKeyDown(VK_SHIFT)
    local control = Input.IsKeyDown(VK_CONTROL)

    if Pressed(VK_RETURN) then return buffer, true, false end
    if Pressed(VK_ESCAPE) then return buffer, false, true end

    buffer = Backspace(buffer, now)

    for code, characters in pairs(CHARACTERS) do
        if Pressed(code) then
            if control and code == VK_V then
                buffer = Paste(buffer)
            elseif not control then
                buffer = buffer .. characters[shift and 2 or 1]
            end
        end
    end

    return buffer:sub(1, MAX_LENGTH), false, false
end

return Typing
