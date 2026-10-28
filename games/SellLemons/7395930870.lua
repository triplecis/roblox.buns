-- Create the Sell Lemons sections and load their feature modules.
return function(context)
    local gameContext = setmetatable({ Sections = {} }, { __index = context })
    context.SellLemons = gameContext

    gameContext.Sections.Autofarm = context.Pages.Game:Section({
        Name = "Autofarm",
        Icon = "coins",
        Side = 1,
    })
    gameContext.Sections.Misc = context.Pages.Game:Section({
        Name = "Misc",
        Icon = "wrench",
        Side = 2,
    })
    gameContext.Sections.Upgrades = context.Pages.Game:Section({
        Name = "Upgrades",
        Icon = "trending-up",
        Side = 2,
    })

    context.LoadModule("games/SellLemons/modules/autofarm.lua", gameContext)
    context.LoadModule("games/SellLemons/modules/misc.lua", gameContext)
    context.LoadModule("games/SellLemons/modules/upgrades.lua", gameContext)
end
