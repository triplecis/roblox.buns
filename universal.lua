return function(Context)

    local Player = Context.Player

    local Library = Context.Library
    local Window = Context.Window
    local UniversalPage = Context.Pages.Universal

    -- // Sections // --
    
    local PlayerSection = UniversalPage:Section({
        Name = "Player",
        Icon = "user",
        Side = 1,
    })

    local MovementSection = UniversalPage:Section({
        Name = "Movement",
        Icon = "zap",
        Side = 2,
    })

    local VisualSection = UniversalPage:Section({
        Name = "Visuals",
        Icon = "eye",
        Side = 3,
    })

    local CameraSection = UniversalPage:Section({
        Name = "Camera",
        Icon = "camera",
        Side = 4,
    })

    PlayerSection:Toggle({
        Name = "Toggle Speed", Flag = "ToggleSpeed", Default = false, Callback = function(State)
            if State then
                Player.Character.Humanoid.WalkSpeed = SpeedToggle.Value
            else
                Player.Character.Humanoid.WalkSpeed = SpeedToggle.Value
            end
        end,
    })

    PlayerSection:Slider({
        Name = "Speed", Flag = "SpeedToggle", Default = 16, Min = 16, Max = 100, Increment = 1, Suffix = "WalkSpeed", Callback = function(Value)
            if Player.Character.Humanoid.WalkSpeed ~= Value then
                Player.Character.Humanoid.WalkSpeed = Value
            end
        end,
    })

    Library:Notification({
        Title = "Universal", Description = "Universal page loaded.", Duration = 2, Icon = "97594400820219",
    })
end