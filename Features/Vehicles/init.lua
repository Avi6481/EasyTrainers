local VehicleFeatures = {}

VehicleFeatures.ViewStates = require("Features/Vehicles/VehicleViewStates")
VehicleFeatures.VehicleLights = require("Features/Vehicles/VehicleLights")
VehicleFeatures.VehicleRepair = require("Features/Vehicles/VehicleRepair")
VehicleFeatures.VehicleGodMode = require("Features/Vehicles/VehicleGodMode")
VehicleFeatures.VehiclePaint = require("Features/Vehicles/VehiclePaint")
VehicleFeatures.VehiclePerformance = require("Features/Vehicles/VehiclePerformance")
VehicleFeatures.VehicleUnlocking = require("Features/Vehicles/VehicleUnlocking")
VehicleFeatures.VehicleSpawning = require("Features/Vehicles/VehicleSpawning")
VehicleFeatures.VehiclePreview = require("Features/Vehicles/VehiclePreview")
VehicleFeatures.VehicleMountOnRoof = require("Features/Vehicles/VehicleMountOnRoof")
VehicleFeatures.VehicleLightFade = require("Features/Vehicles/VehicleLightFade")
VehicleFeatures.FreezeQuestTimer = require("Features/Vehicles/FreezeQuestTimer")
VehicleFeatures.VehicleNitro = require("Features/Vehicles/VehicleNitro")
VehicleFeatures.VehicleSpeedometer = require("Features/Vehicles/VehicleSpeedometer")

function VehicleFeatures.Tick(deltaTime)
    VehicleFeatures.VehicleLightFade.Tick(deltaTime)
    VehicleFeatures.VehiclePreview.Update(deltaTime)
    VehicleFeatures.VehicleSpawning.HandlePending()
    VehicleFeatures.VehicleNitro.Tick()
    VehicleFeatures.VehicleGodMode.Tick()
    VehicleFeatures.VehicleRepair.Tick()
    VehicleFeatures.VehiclePaint.Tick()
    VehicleFeatures.VehiclePerformance.Tick(deltaTime)
    VehicleFeatures.VehicleSpeedometer.Update(deltaTime)
end

return VehicleFeatures
