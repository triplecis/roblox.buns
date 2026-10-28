-- Create the Sell Lemons sections and load the drop autofarm.
return function(context)
    local gameContext = setmetatable({ Sections = {} }, { __index = context })
    context.SellLemons = gameContext

    gameContext.Sections.Autofarm = context.Pages.Game:Section({
        Name = "Autofarm",
        Icon = "coins",
        Side = 1,
    })

    context.LoadModule("games/SellLemons/modules/autofarm.lua", gameContext)
end
