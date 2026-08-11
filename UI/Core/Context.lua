local Context = {}

Context.Frame = 0
Context.DeltaTime = 0
Context.Bounds = { X = 0, Y = 0, Width = 0, Height = 0 }
Context.OptionCount = 0
Context.SubmenuBarHeight = 0

function Context.Begin(deltaTime, bounds)
    Context.Frame = Context.Frame + 1
    Context.DeltaTime = deltaTime or 0
    Context.Bounds = bounds or Context.Bounds
    Context.OptionCount = 0
    Context.SubmenuBarHeight = 0
end

return Context
