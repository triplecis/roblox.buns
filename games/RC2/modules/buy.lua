return function(ModuleContext)
    local Library = ModuleContext.Library
    local Window = ModuleContext.Window

    local BuySection = ModuleContext.Buy

    BuySection:Label("Purchase")
    BuySection:Button({
        Name = "Purchase " .. "Item",
        Icon = "shopping-cart",
        Callback = function()
            Library:Notification({
                Title = "Test Notification",
                Description = "Purchased ".. "Item" .." for " .. "ItemPrice",
                Duration = 3,
                Icon = 89380854415542
            })
        end
    })

    
end