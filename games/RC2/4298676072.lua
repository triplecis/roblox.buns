-- Create the RC2 pages, then load each page's feature module.
return function(context)
    local gameContext = setmetatable({
        Sections = {},
        Selections = {
            Ores = {},
            Trees = {},
            Fishes = {},
            Oils = {},
        },
    }, { __index = context })

    context.RC2 = gameContext

    local sectionDefinitions = {
        { name = "Main", icon = "pickaxe", side = 1 },
        { name = "World", icon = "map-pinned", side = 2 },
        { name = "Vehicles", icon = "car", side = 1 },
        { name = "Base", icon = "house", side = 2 },
        { name = "Automation", icon = "bot", side = 1 },
        { name = "Buy", icon = "store", side = 2 },
        { name = "Misc", icon = "wrench", side = 1 },
    }

    for _, definition in ipairs(sectionDefinitions) do
        gameContext.Sections[definition.name] = context.Pages.Game:Section({
            Name = definition.name,
            Icon = definition.icon,
            Side = definition.side,
        })
    end

    -- The content module must run first so the pages receive an initial catalog.
    local moduleNames = {
        "content",
        "main",
        "world",
        "vehicles",
        "base",
        "automation",
        "buy",
        "misc",
    }

    local loadedCount = 0
    for _, moduleName in ipairs(moduleNames) do
        local path = "games/RC2/modules/" .. moduleName .. ".lua"
        if context.LoadModule(path, gameContext) then
            loadedCount = loadedCount + 1
        end
    end

    context.Notify(
        "Refinery Caves 2",
        string.format("Loaded %d/%d modules.", loadedCount, #moduleNames),
        3
    )
end
