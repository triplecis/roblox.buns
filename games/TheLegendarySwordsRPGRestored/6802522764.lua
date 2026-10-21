-- Create the game sections and load each section's matching feature module.
return function(context)
    local gameContext = setmetatable({ Sections = {} }, { __index = context })
    context.LegendarySwords = gameContext

    local sectionDefinitions = {
        { name = "Shop", icon = "shopping-cart", side = 1 },
        { name = "Autofarm", icon = "bot", side = 1 },
        { name = "Misc", icon = "wrench", side = 2 },
        { name = "Teleports", icon = "map-pin", side = 1 },
        { name = "Settings", icon = "settings", side = 2 },
        { name = "Debug", icon = "bug", side = 2 },
    }

    for _, definition in ipairs(sectionDefinitions) do
        gameContext.Sections[definition.name] = context.Pages.Game:Section({
            Name = definition.name,
            Icon = definition.icon,
            Side = definition.side,
        })
    end

    local moduleNames = {
        "shop",
        "autofarm",
        "misc",
        "teleports",
        "settings",
        "debug",
    }

    local loadedCount = 0
    for _, moduleName in ipairs(moduleNames) do
        local path = "games/TheLegendarySwordsRPGRestored/modules/" .. moduleName .. ".lua"
        if context.LoadModule(path, gameContext) then
            loadedCount = loadedCount + 1
        end
    end

    context.Notify(
        "The Legendary Swords RPG Restored",
        string.format("Loaded %d/%d modules.", loadedCount, #moduleNames),
        3
    )
end
