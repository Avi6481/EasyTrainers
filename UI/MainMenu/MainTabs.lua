local MainTabs = { Entries = {} }

function MainTabs.Initialize()
    MainTabs.Entries = MainTabs.Entries or {}
end

function MainTabs.Register(id, title, submenu, tip)
    local entry = type(id) == "table" and id or {
        Id = id,
        Title = title,
        Submenu = submenu,
        Tip = tip or "",
        Enabled = true,
    }
    entry.Enabled = entry.Enabled ~= false

    for index, existing in ipairs(MainTabs.Entries) do
        if existing.Id == entry.Id then
            MainTabs.Entries[index] = entry
            return entry
        end
    end

    table.insert(MainTabs.Entries, entry)
    return entry
end

function MainTabs.Clear()
    MainTabs.Entries = {}
end

function MainTabs.GetEnabled()
    local enabled = {}
    for _, entry in ipairs(MainTabs.Entries) do
        if entry.Enabled then table.insert(enabled, entry) end
    end
    return enabled
end

return MainTabs
