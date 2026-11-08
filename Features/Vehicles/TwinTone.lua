local Catalog = require("Features/Vehicles/Catalog")

local TwinTone = {}

local SCAN_DISABLED = "twintone_scan_disabled"

local function Fact(name)
    return Game.GetQuestsSystem():GetFactStr(name) > 0
end

local function PlayingJohnny()
    local ok, name = pcall(Game.GetPlayAsJohnnyFactName)
    return ok and name ~= nil and Game.GetQuestsSystem():GetFact(name) > 0
end

local function Scannable(controller)
    local object = controller.m_scannedObject
    if not object or not object:IsVehicle() then return false end
    if Fact(SCAN_DISABLED) or PlayingJohnny() then return false end
    return not Catalog.IsOriginal(object:GetRecordID())
end

local function ShouldDisplay(controller, wrapped)
    local shown = wrapped()
    if shown or not Catalog.Injected then return shown end

    local ok, scannable = pcall(Scannable, controller)
    return ok and scannable == true
end

function TwinTone.Initialize()
    Override("scannerDetailsGameController", "ShouldDisplayTwintoneTab", ShouldDisplay)
end

return TwinTone
