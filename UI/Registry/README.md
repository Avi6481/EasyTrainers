# Option registry

The registry is the shared catalog for legacy UI views and the replacement UI.
Persistence remains in `Config/OptionConfig.lua`; widgets only report option metadata
and state changes.

Every searchable or bindable option needs a stable `Id`. IDs are also the keys in
`Config/JSON/Options.json`, so existing IDs must not be renamed without a migration.

```lua
local OptionConfig = require("Config/OptionConfig")

OptionConfig.RegisterAll({
    OptionConfig.DefineToggle("toggle.self.godmode", GodMode.enabled, false, {
        LabelKey = "self.godmode.label",
        TipKey = "self.godmode.tip",
        Category = "self",
        Keywords = { "health", "invincible" },
    }),
})
```

Supported definitions include toggles, buttons, dropdowns, and submenus. Registry
entries can be retrieved by ID or state reference, searched by multiple terms and
category, activated without knowing their widget, and assigned hotkey metadata.

Feature modules own state and behavior. The registry owns identity and discovery.
The option facade owns drawing. `OptionConfig` owns disk persistence.
