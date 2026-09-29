return function(ContextV)
    local Library = ContextV.Library
    local Window = ContextV.Window

    local BuySection = ContextV.BuySection

    BuySection:Label("Purchase")
    BuySection:Button({
        Name = "Purchase " .. Item,
        Icon = "shopping-cart",
        Callback = function()
            Library:Notification({
                Title = "Test Notification",
                Description = "Purchased ".. Item .." for " .. ItemPrice,
                Duration = 3,
                Icon = IconAsset
            })
        end
    })

    
end