local Logger = require("Core/Logger")

local Dependencies = {}

local s_Checked = false
local s_Redscript = false
local s_InputHandler = false

local function ScriptsLoaded()
    local ok, class = pcall(function() return EasyInputScripts end)
    if ok and class ~= nil then return true end

    local created, object = pcall(NewObject, "EasyInputScripts")
    return created and object ~= nil
end

function Dependencies.Check()
    s_Checked = true
    s_InputHandler = EasyInputHandler ~= nil
    s_Redscript = ScriptsLoaded()

    if not s_Redscript then
        Logger.Error("Redscript isn't loading EasyTrainer's scripts, so keys and controller input are off. Install redscript and check r6/logs/redscript_rCURRENT.log.")
    end

    if not s_InputHandler then
        Logger.Error("EasyInputHandler didn't load. Update RED4ext and check red4ext/logs. Until then the menu only shows with the CET overlay.")
    end

    if s_Redscript and s_InputHandler then Logger.Log("Redscript and EasyInputHandler found") end
end

local function Ensure()
    if not s_Checked then Dependencies.Check() end
end

function Dependencies.Redscript()
    Ensure()
    return s_Redscript
end

function Dependencies.InputHandler()
    Ensure()
    return s_InputHandler
end

return Dependencies
