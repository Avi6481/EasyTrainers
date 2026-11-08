local Landing = require("Utils/Landing")

local NoFallDamage = {
    Enabled = false
}

local OWNER = "NoFallDamage"

function NoFallDamage.Initialize()
    Landing.Initialize()
end

function NoFallDamage.Update()
    Landing.Hold(OWNER, NoFallDamage.Enabled)
end

function NoFallDamage.Shutdown()
    Landing.Hold(OWNER, false)
end

return NoFallDamage
