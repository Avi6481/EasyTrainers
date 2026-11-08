local Ref = require("Core/Ref")
local Submenu = require("Navigation/Submenu")
local Widgets = require("Widgets/Widgets")
local Notify = require("Utils/Notify")
local World = require("Features/World/World")
local Weather = require("Features/World/Weather")

local WeatherView = {}

local KEY = "weather."

local s_Freeze = Ref.Field(Weather, "Freeze")
local s_Blend = Ref.Field(Weather, "Blend")
local s_Names = {}
local s_Keys = {}

for _, state in ipairs(Weather.States) do s_Keys[state.Name] = KEY .. "states." .. state.Key end

local function Capital(first, rest)
    return first:upper() .. rest
end

local function Pretty(state)
    if s_Keys[state] then return L(s_Keys[state]) end

    local name = s_Names[state]
    if name then return name end

    name = state:gsub("^24h_weather_", ""):gsub("_", " "):gsub("(%a)(%w*)", Capital)
    s_Names[state] = name
    return name
end

local function Apply(state)
    World.Run(function()
        if Weather.Set(state) then
            Notify.Success(tip("notify.world.weatherset", { weather = Pretty(state) }))
        else
            Notify.Error(L("notify.world.weatherfailed"))
        end
    end)
end

local function Random()
    World.Run(function()
        local entry = Weather.SetRandom()
        if entry then
            Notify.Success(tip("notify.world.weatherset", { weather = Pretty(entry.Name) }))
        else
            Notify.Error(L("notify.world.weatherfailed"))
        end
    end)
end

local function Reset()
    World.Run(function()
        if Weather.ResetWeather() then
            Notify.Info(L("notify.world.weatherreset"))
        else
            Notify.Error(L("notify.world.weatherfailed"))
        end
    end)
end

local function CurrentIndex()
    for index, state in ipairs(Weather.States) do
        if state.Name == Weather.Current then return index end
    end
    return 0
end

local s_Selected = Ref.New(CurrentIndex, function() end)

local function AllStatesView()
    World.Watch()

    local states = Weather.AllStates()
    if #states == 0 then
        Widgets.ValueRow(L(KEY .. "nostates.label"), "")
        Widgets.Tip(L(KEY .. "nostates.tip"))
        return
    end

    local active = L(KEY .. "active")
    for _, state in ipairs(states) do
        if Widgets.ValueRow(Pretty(state), state == Weather.Current and active or "", true) then Apply(state) end
        if Widgets.Selected() then Widgets.Tip(tip(KEY .. "allstate.tip", { state = state })) end
    end
end

local AllStatesMenu = Submenu.Create("weather.allstates.title", AllStatesView)

local function Links()
    Widgets.SubmenuButton(L(KEY .. "allstates.label"), AllStatesMenu)
    Widgets.Tip(L(KEY .. "allstates.tip"))
end

local function Controls()
    local current = Weather.Current ~= "" and Pretty(Weather.Current) or L(KEY .. "unknown")
    Widgets.ValueRow(L(KEY .. "current.label"), current)
    Widgets.Tip(L(KEY .. "current.tip"))

    Widgets.Toggle(L(KEY .. "freeze.label"), s_Freeze)
    Widgets.Tip(L(KEY .. "freeze.tip"))

    if Widgets.Button(L(KEY .. "random.label")) then Random() end
    Widgets.Tip(L(KEY .. "random.tip"))

    if Widgets.Button(L(KEY .. "reset.label")) then Reset() end
    Widgets.Tip(L(KEY .. "reset.tip"))

    Widgets.SliderInt(L(KEY .. "transition.label"), s_Blend, 1, 60, 1, "%ds")
    Widgets.Tip(L(KEY .. "transition.tip"))
end

local function Types()
    Widgets.Break(L(KEY .. "types"))
    for index, state in ipairs(Weather.States) do
        if Widgets.Radio(Pretty(state.Name), s_Selected, index) then Apply(state.Name) end
        Widgets.Tip(L(KEY .. "type.tip"))
    end
end

local function View()
    World.Watch()

    Links()
    Widgets.Break("")
    Controls()
    Types()
end

WeatherView.Menu = Submenu.Create("weather.title", View)

return WeatherView
