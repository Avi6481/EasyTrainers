local Navigation = require("UI/Navigation/Navigation")

local DropdownNavigation = {}

function DropdownNavigation.Update(dropdown)
    if not dropdown.Opened then return end

    local count = #dropdown.Items
    if count <= 0 then
        if Navigation.Input.BackPressed then
            Navigation.Input.BackPressed = false
            dropdown.Close()
        end
        return
    end

    if Navigation.Input.UpPressed then
        dropdown.Current = dropdown.Current - 1
        if dropdown.Current < 1 then dropdown.Current = count end
    end

    if Navigation.Input.DownPressed then
        dropdown.Current = dropdown.Current + 1
        if dropdown.Current > count then dropdown.Current = 1 end
    end

    if Navigation.Input.BackPressed then
        Navigation.Input.BackPressed = false
        dropdown.Close()
        return
    end

    if Navigation.Input.SelectPressed then
        dropdown.Select(dropdown.Current)
    end
end

return DropdownNavigation

