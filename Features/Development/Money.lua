local Money = {
    MAX = 999999999
}

function Money.Get(player)
    return Game.GetTransactionSystem():GetItemQuantity(player, MarketSystem.Money())
end

function Money.Set(value)
    local player = Game.GetPlayer()
    if not player then return end

    local system = Game.GetTransactionSystem()
    local id = MarketSystem.Money()
    local delta = math.max(0, math.min(Money.MAX, value)) - system:GetItemQuantity(player, id)

    if delta > 0 then
        system:GiveItem(player, id, delta)
    elseif delta < 0 then
        system:RemoveItem(player, id, -delta)
    end
end

return Money
