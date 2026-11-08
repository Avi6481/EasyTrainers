local Draw = require("Core/Draw")

local TextFieldStyle = {}

function TextFieldStyle.Initialize()
    TextFieldStyle.MinWidth = 56
    TextFieldStyle.PaddingX = 6
    TextFieldStyle.PaddingY = 3
    TextFieldStyle.Rounding = 4
    TextFieldStyle.Fill = Draw.RGBA(0, 0, 0, 110)
    TextFieldStyle.CaretBlink = 1
    TextFieldStyle.AllowPaste = true
end

TextFieldStyle.Initialize()

return TextFieldStyle
