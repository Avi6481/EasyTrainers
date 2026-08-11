local Input = {}

Input.OpenPressed = false
Input.ToggleMousePressed = false
Input.UpPressed = false
Input.DownPressed = false
Input.LeftPressed = false
Input.RightPressed = false
Input.SelectPressed = false
Input.BackPressed = false

function Input.Clear()
    Input.OpenPressed = false
    Input.ToggleMousePressed = false
    Input.UpPressed = false
    Input.DownPressed = false
    Input.LeftPressed = false
    Input.RightPressed = false
    Input.SelectPressed = false
    Input.BackPressed = false
end

function Input.Apply(source)
    source = source or {}
    Input.OpenPressed = source.OpenPressed or source.openPressed or false
    Input.ToggleMousePressed = source.ToggleMousePressed or source.toggleMousePressed or false
    Input.UpPressed = source.UpPressed or source.upPressed or false
    Input.DownPressed = source.DownPressed or source.downPressed or false
    Input.LeftPressed = source.LeftPressed or source.leftPressed or false
    Input.RightPressed = source.RightPressed or source.rightPressed or false
    Input.SelectPressed = source.SelectPressed or source.selectPressed or false
    Input.BackPressed = source.BackPressed or source.backPressed or false
end

return Input
