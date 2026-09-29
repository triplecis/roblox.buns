--// Refinery Caves 2 //--

return function(Context)
    local Library = Context.Library
    local Window = Context.Window
    local GamePage = Context.Pages.Game
    local MyFullUrl = Context.MyFullUrl

    --// Sections //--

    local MainSection = GamePage:Section({
        Name = "Main",
        Icon = "pickaxe",
        Side = 1,
    })

    local WorldSection = GamePage:Section({
        Name = "World",
        Icon = "map-pinned",
        Side = 2,
    })

    local VehiclesSection = GamePage:Section({
        Name = "Vehicles",
        Icon = "car",
        Side = 1,
    })

    local BaseSection = GamePage:Section({
        Name = "Base",
        Icon = "house",
        Side = 2,
    })

    local AutomationSection = GamePage:Section({
        Name = "Automation",
        Icon = "bot",
        Side = 1,
    })

    local BuySection = GamePage:Section({
        Name = "Buy",
        Icon = "store",
        Side = 2,
    })

    local MiscSection = GamePage:Section({
        Name = "Misc",
        Icon = "wrench",
        Side = 1,
    })

    --// Context for RC2 modules //--

    local ModuleContext = {
        Library = Library,
        Window = Window,

        Player = Context.Player,
        PlaceId = Context.PlaceId,
        GameId = Context.GameId,
        JobId = Context.JobId,

        Sections = {
            Main = MainSection,
            World = WorldSection,
            Vehicles = VehiclesSection,
            Base = BaseSection,
            Automation = AutomationSection,
            Buy = BuySection,
            Misc = MiscSection,
        },
    }

    --// Modules //--

    local BasePath = "games/RC2/modules/"

    local Modules = {
        "main.lua",
        "world.lua",
        "vehicles.lua",
        "base.lua",
        "automation.lua",
        "buy.lua",
        "misc.lua",
    }

    for _, FileName in ipairs(Modules) do
        local URL = MyFullUrl .. BasePath .. FileName

        local Source = game:HttpGet(URL)
        local Module, CompileError = loadstring(Source)

        if not Module then
            warn("Failed to compile " .. FileName .. ": " .. tostring(CompileError))
            continue
        end

        local Success, Result = pcall(Module)

        if not Success then
            warn("Failed to load " .. FileName .. ": " .. tostring(Result))
            continue
        end

        if type(Result) == "function" then
            local ModuleSuccess, ModuleError = pcall(Result, ModuleContext)

            if not ModuleSuccess then
                warn("Failed to run " .. FileName .. ": " .. tostring(ModuleError))
            end
        end
    end

    Library:Notification({
        Title = "Refinery Caves 2",
        Description = "Refinery Caves 2 page loaded.",
        Duration = 2,
        Icon = 89380854415542,
    })
end