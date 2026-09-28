-- // Refinery Caves 2 // --

return function(Context)
    local Library = Context.Library
    local Window = Context.Window
    local GamePage = Context.Pages.Game

    -- // Sections // --

    local Section0 = GamePage:Section({
        Name = "Resources ESP", Icon = "gamepad-2", Side = 1,
    }); local Section1 = GamePage:Section({
        Name = "Mining", Icon = "gamepad-2", Side = 2,
    }); local Section2 = GamePage:Section({
        Name = "Logging", Icon = "gamepad-2", Side = 1,
    }); local Section3 = GamePage:Section({
        Name = "Autofarm", Icon = "hammer", Side = 2,
    })

    Library:Notification({
        Title = "Refinery Caves 2", Description = "Refinery Caves 2 page loaded.", Duration = 2, Icon = "97594400820219",
    })
end