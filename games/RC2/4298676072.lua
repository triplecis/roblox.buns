-- // Refinery Caves 2 // --

return function(Context)
    local Library = Context.Library
    local Window = Context.Window
    local GamePage = Context.Pages.Game
    local MyFullUrl = Context.MyFullURL

    -- // Sections // --

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
    local VisualsSection = GamePage:Section({
        Name = "Visuals",
        Icon = "eye",
        Side = 2,
    })
    local MiscSection = GamePage:Section({
        Name = "Misc", 
        Icon = "wrench", 
        Side = 1,
    })

    local ContextV = {
        Library = Context.Library
        Window = Context.Window


        --// Sections
        MainSection = MainSection
        WorldSection = WorldSection
        VehiclesSection = VehiclesSection
        BaseSection = BaseSection
        AutomationSection = AutomationSection
        VisualsSection = VisualsSection
        MiscSection = MiscSection
    }

    for _, FileName in ipairs(Modules) do
        local URL = MyFullURL .. BasePath .. FileName

    Library:Notification({
        Title = "Refinery Caves 2", Description = "Refinery Caves 2 page loaded.", Duration = 2, Icon = "97594400820219",
    })
end