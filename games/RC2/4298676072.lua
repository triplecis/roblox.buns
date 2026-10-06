return function(Context)
    local ModuleContext = setmetatable({
        Sections = {},
        Selections = { Ores = {}, Trees = {}, Fishes = {}, Oils = {} },
    }, { __index = Context })
    Context.RC2 = ModuleContext

    local Sections = {
        { "Main", "pickaxe", 1 }, { "World", "map-pinned", 2 },
        { "Vehicles", "car", 1 }, { "Base", "house", 2 },
        { "Automation", "bot", 1 }, { "Buy", "store", 2 }, { "Misc", "wrench", 1 },
    }
    for _, Info in ipairs(Sections) do
        ModuleContext.Sections[Info[1]] = Context.Pages.Game:Section({
            Name = Info[1], Icon = Info[2], Side = Info[3],
        })
    end

    local Modules = { "content", "main", "world", "vehicles", "base", "automation", "buy", "misc" }
    local Loaded = 0
    for _, Name in ipairs(Modules) do
        if Context.LoadModule("games/RC2/modules/" .. Name .. ".lua", ModuleContext) then
            Loaded = Loaded + 1
        end
    end
    Context.Notify("Refinery Caves 2",
        string.format("Loaded %d/%d modules.", Loaded, #Modules), 3)
end
