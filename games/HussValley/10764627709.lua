-- Huss Valley: game-specific module entry point.
return function(Context)
    local ModuleContext = setmetatable({
        Sections = {},
        State = {},
    }, { __index = Context })
    Context.HussValley = ModuleContext

    -- Gameplay categories researched for Huss Valley Official; see README.md.
    local Modules = {
        { Name = "Rounds", Icon = "flag", Side = 1, File = "rounds.lua" },
        { Name = "Runners", Icon = "shield", Side = 1, File = "runners.lua" },
        { Name = "Chasers", Title = "Catchers", Icon = "swords", Side = 2, File = "chasers.lua" },
        { Name = "Movement", Icon = "zap", Side = 2, File = "movement.lua" },
        { Name = "Abilities", Icon = "sparkles", Side = 1, File = "abilities.lua" },
        { Name = "Consumables", Icon = "package", Side = 2, File = "consumables.lua" },
        { Name = "Rewards", Icon = "gem", Side = 1, File = "rewards.lua" },
    }

    for _, Module in ipairs(Modules) do
        ModuleContext.Sections[Module.Name] = Context.Pages.Game:Section({
            Name = Module.Title or Module.Name,
            Icon = Module.Icon,
            Side = Module.Side,
        })
    end

    local Loaded = 0
    if not Context.LoadModule("games/HussValley/modules/runtime.lua", ModuleContext) then
        Context.Notify("Huss Valley", "Shared data helpers could not load.", 3)
        return
    end
    Loaded = Loaded + 1
    for _, Module in ipairs(Modules) do
        if Context.LoadModule("games/HussValley/modules/" .. Module.File, ModuleContext) then
            Loaded = Loaded + 1
        end
    end

    Context.Notify("Huss Valley",
        string.format("Loaded %d/%d modules.", Loaded, #Modules + 1), 3)
end
