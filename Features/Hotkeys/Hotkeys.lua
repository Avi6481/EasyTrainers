local Input = require("Core/Input")
local InputBlock = require("Core/InputBlock")
local Language = require("Core/Language")
local Logger = require("Core/Logger")
local Session = require("Core/Session")
local State = require("Core/State")
local Notify = require("Utils/Notify")
local Navigation = require("Navigation/Navigation")
local KeyBind = require("Widgets/KeyBind/KeyBind")
local Define = require("Features/Hotkeys/Define")

local Hotkeys = {
    Bindings = {}
}

Hotkeys.Kinds = Define.Kinds

Hotkeys.Categories = {
    { Id = "Self", Title = "mainmenu.self", List = require("Features/Hotkeys/SelfHotkeys") },
    { Id = "Modifiers", Title = "mainmenu.modifiers", List = require("Features/Hotkeys/ModifiersHotkeys") },
    { Id = "Teleports", Title = "mainmenu.teleport", List = require("Features/Hotkeys/TeleportsHotkeys") },
    { Id = "Vehicles", Title = "mainmenu.vehicle", List = require("Features/Hotkeys/VehiclesHotkeys") },
    { Id = "Weapons", Title = "mainmenu.weapon", List = require("Features/Hotkeys/WeaponsHotkeys") },
    { Id = "Items", Title = "mainmenu.items", List = require("Features/Hotkeys/ItemsHotkeys") },
    { Id = "Time", Title = "mainmenu.time", List = require("Features/Hotkeys/TimeHotkeys") },
    { Id = "Weather", Title = "mainmenu.weather", List = require("Features/Hotkeys/WeatherHotkeys") },
    { Id = "WorldEditor", Title = "mainmenu.worldeditor", List = require("Features/Hotkeys/WorldEditorHotkeys") }
}

local WINDOW = 0.5
local MAX_CODE = 0xFFFFF

local s_All = {}
local s_Ids = {}
local s_ById = {}
local s_Pending = {}
local s_Version = 0
local s_BoundVersion = -1
local s_Bound = {}
local s_BoundIn = {}
local s_Failed = {}
local s_Labels = {}
local s_LabelsCode = nil

for _, category in ipairs(Hotkeys.Categories) do
    for _, definition in ipairs(category.List) do
        definition.Id = category.Id .. "." .. definition.Name
        definition.Category = category
        table.insert(s_All, definition)
        table.insert(s_Ids, definition.Id)
        s_ById[definition.Id] = definition
    end
end

local function Try(name, callback, ...)
    local ok, err = pcall(callback, ...)
    if not ok and not s_Failed[name] then
        s_Failed[name] = true
        Logger.Log(name .. " failed: " .. tostring(err))
    end
    return ok
end

local function Clean(codes)
    local list, seen = {}, {}
    for _, code in ipairs(type(codes) == "table" and codes or {}) do
        local value = tonumber(code)
        if value and value >= 1 and value <= MAX_CODE and value == math.floor(value) and not seen[value] then
            seen[value] = true
            table.insert(list, value)
        end
    end
    return list
end

local function Assign(list, codes)
    for index = #list, 1, -1 do list[index] = nil end
    for _, code in ipairs(codes) do table.insert(list, code) end
end

local function Empty(binding)
    return #binding.Keys == 0 and #binding.Buttons == 0
end

function Hotkeys.Fill()
    local bindings = Hotkeys.Bindings
    for id in pairs(bindings) do
        if not s_ById[id] then bindings[id] = nil end
    end

    for _, id in ipairs(s_Ids) do
        local binding = bindings[id]
        if type(binding) ~= "table" then
            binding = {}
            bindings[id] = binding
        end
        for key in pairs(binding) do
            if key ~= "Keys" and key ~= "Buttons" then binding[key] = nil end
        end
        binding.Keys = Clean(binding.Keys)
        binding.Buttons = Clean(binding.Buttons)
    end
    s_Version = s_Version + 1
end

Hotkeys.Fill()

function Hotkeys.Ids()
    return s_Ids
end

function Hotkeys.Version()
    return s_Version
end

function Hotkeys.Find(id)
    return s_ById[id]
end

local function Compatible(definition, kind)
    if definition.Kind == Define.Kinds.Action then return kind == Define.Kinds.Action end
    return kind ~= Define.Kinds.Action
end

local function BuildLabels()
    s_Labels = {}
    for _, definition in ipairs(s_All) do
        local text = L(definition.Label)
        if s_Labels[text] == nil then
            s_Labels[text] = definition
        else
            s_Labels[text] = false
        end
    end
end

function Hotkeys.ForLabel(label, kind)
    local code = Language.GetCurrentCode()
    if s_LabelsCode ~= code then
        s_LabelsCode = code
        BuildLabels()
    end

    local definition = s_Labels[label]
    if definition and Compatible(definition, kind) then return definition end
    return nil
end

function Hotkeys.IsOn(definition)
    return definition.Kind ~= Define.Kinds.Action and definition.Target[definition.Field] == true
end

local function Set(definition, value)
    if definition.Set then
        definition.Set(value)
    else
        definition.Target[definition.Field] = value
    end
end

function Hotkeys.TurnOff(definition)
    if not Hotkeys.IsOn(definition) then return false end
    Set(definition, false)
    return true
end

function Hotkeys.Binding(definition)
    local binding = Hotkeys.Bindings[definition.Id]
    if type(binding) ~= "table" or type(binding.Keys) ~= "table" or type(binding.Buttons) ~= "table" then
        binding = { Keys = {}, Buttons = {} }
        Hotkeys.Bindings[definition.Id] = binding
    end
    return binding
end

function Hotkeys.Name(definition)
    if not definition.Pattern then return L(definition.Label) end

    local code = Language.GetCurrentCode()
    if definition.NameCode ~= code then
        definition.NameCode = code
        definition.NameText = tip(definition.Pattern, { name = definition.Label })
    end
    return definition.NameText
end

local function Rebuild()
    if s_BoundVersion == s_Version then return end
    s_BoundVersion = s_Version
    s_Bound = {}
    s_BoundIn = {}

    for _, definition in ipairs(s_All) do
        if not Empty(Hotkeys.Binding(definition)) then
            table.insert(s_Bound, definition)
            s_BoundIn[definition.Category] = (s_BoundIn[definition.Category] or 0) + 1
        end
    end
end

function Hotkeys.Bound()
    Rebuild()
    return s_Bound
end

function Hotkeys.BoundIn(category)
    Rebuild()
    return s_BoundIn[category] or 0
end

local function Same(first, second)
    if #first == 0 or #first ~= #second then return false end

    local set = {}
    for _, code in ipairs(first) do set[code] = true end
    for _, code in ipairs(second) do
        if not set[code] then return false end
    end
    return true
end

local function All(codes, check)
    for _, code in ipairs(codes) do
        if not check(code) then return false end
    end
    return true
end

local function Any(codes, check)
    for _, code in ipairs(codes) do
        if check(code) then return true end
    end
    return false
end

local function Format(keys, buttons)
    return KeyBind.FormatBinding({ Keys = keys or {}, Buttons = buttons or {} })
end

local function MenuOnly(codes, check)
    return #codes > 0 and All(codes, check)
end

function Hotkeys.MenuOnly(binding)
    return MenuOnly(binding.Keys, InputBlock.IsMenuKey) or MenuOnly(binding.Buttons, InputBlock.IsMenuButton)
end

function Hotkeys.SharedWith(definition)
    local binding = Hotkeys.Binding(definition)
    for _, other in ipairs(s_All) do
        if other ~= definition then
            local otherBinding = Hotkeys.Binding(other)
            if Same(binding.Keys, otherBinding.Keys) or Same(binding.Buttons, otherBinding.Buttons) then return other end
        end
    end
    return nil
end

local function Warn(definition, binding)
    local toggle = State.ToggleBinding()
    if Same(binding.Keys, toggle.Keys) or Same(binding.Buttons, toggle.Buttons) then
        Notify.Warning(tip("notify.hotkeys.menukey", { keys = Format(binding.Keys, binding.Buttons), name = Hotkeys.Name(definition) }))
        return
    end

    if MenuOnly(binding.Keys, InputBlock.IsMenuKey) then
        Notify.Info(tip("notify.hotkeys.menuonly", { keys = Format(binding.Keys) }))
    end
    if MenuOnly(binding.Buttons, InputBlock.IsMenuButton) then
        Notify.Info(tip("notify.hotkeys.menuonly", { keys = Format(nil, binding.Buttons) }))
    end

    local other = Hotkeys.SharedWith(definition)
    if other then
        Notify.Warning(tip("notify.hotkeys.shared", { keys = Format(binding.Keys, binding.Buttons), name = Hotkeys.Name(other) }))
    end
end

function Hotkeys.Changed(definition)
    s_Version = s_Version + 1

    local binding = Hotkeys.Binding(definition)
    if Empty(binding) then
        Notify.Info(tip("notify.hotkeys.cleared", { name = Hotkeys.Name(definition) }))
        return
    end

    Notify.Success(tip("notify.hotkeys.bound", { name = Hotkeys.Name(definition), keys = KeyBind.FormatBinding(binding) }))
    Warn(definition, binding)
end

function Hotkeys.MenuChanged()
    local binding = State.Hotkeys.ToggleMenu
    local keys = KeyBind.FormatBinding(State.ToggleBinding())
    if type(binding) ~= "table" or Empty(binding) then
        Notify.Info(tip("notify.hotkeys.menudefault", { keys = keys }))
        return
    end
    Notify.Success(tip("notify.hotkeys.menubound", { keys = keys }))
end

function Hotkeys.ClearAll()
    local count = 0
    for _, definition in ipairs(s_All) do
        local binding = Hotkeys.Binding(definition)
        if not Empty(binding) then
            count = count + 1
            Assign(binding.Keys, {})
            Assign(binding.Buttons, {})
        end
    end
    s_Version = s_Version + 1

    if count == 0 then
        Notify.Info(L("notify.hotkeys.nothingtoclear"))
        return
    end
    Notify.Success(tip("notify.hotkeys.clearedall", { count = count }))
end

local function Combo(codes, down, pressed)
    if #codes == 0 then return false, false end

    local fresh = false
    for _, code in ipairs(codes) do
        if not down(code) then return false, false end
        if pressed(code) then fresh = true end
    end
    return true, fresh
end

local function Side(codes, down, pressed, isMenu, menuOpen)
    local held, fresh = Combo(codes, down, pressed)
    if not held then return false, false end
    if menuOpen and All(codes, isMenu) then return false, false end
    return fresh, menuOpen and Any(codes, isMenu)
end

local function Blocked()
    if not Session.IsLoaded() or State.OverlayOpen or State.Menu.Typing then return true end
    return KeyBind.IsCapturing() or not Input.IsAvailable()
end

function Hotkeys.Detect()
    if Blocked() then return end
    if State.BindingPressed(State.ToggleBinding()) then return end

    local menuOpen = State.Menu.Open
    local now = State.Time.Time
    local suppress = false

    for _, definition in ipairs(s_All) do
        local binding = Hotkeys.Binding(definition)
        local keyFresh, keyMenu = Side(binding.Keys, Input.KeyDown, Input.KeyPressed, InputBlock.IsMenuKey, menuOpen)
        local buttonFresh, buttonMenu = Side(binding.Buttons, Input.ButtonDown, Input.ButtonPressed, InputBlock.IsMenuButton, menuOpen)

        if keyMenu or buttonMenu then suppress = true end
        if keyFresh or buttonFresh then table.insert(s_Pending, { Definition = definition, At = now }) end
    end

    if suppress then Navigation.Suppress() end
end

local function Announce(definition, on)
    local name = Hotkeys.Name(definition)
    if not on then
        Notify.Info(tip("notify.hotkeys.off", { name = name }))
        return
    end

    if definition.Kind == Define.Kinds.Slider then
        local value = string.format(definition.Format, definition.Target[definition.Value] or 0)
        Notify.Success(tip("notify.hotkeys.onvalue", { name = name, value = value }))
        return
    end
    Notify.Success(tip("notify.hotkeys.on", { name = name }))
end

local function Fire(definition)
    if definition.Kind == Define.Kinds.Action then
        definition.Run()
        if not definition.Silent then Notify.Info(Hotkeys.Name(definition)) end
        return
    end

    Set(definition, definition.Target[definition.Field] ~= true)
    Announce(definition, definition.Target[definition.Field] == true)
end

function Hotkeys.Update()
    if #s_Pending == 0 then return end

    local pending = s_Pending
    s_Pending = {}

    local now = State.Time.Time
    for _, entry in ipairs(pending) do
        if now - entry.At <= WINDOW then Try(entry.Definition.Id, Fire, entry.Definition) end
    end
end

function Hotkeys.Reset()
    s_Pending = {}
end

return Hotkeys
