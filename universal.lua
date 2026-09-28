return function(Context)
    local Player = Context.Player

    local Library = Context.Library
    local Window = Context.Window
    local UniversalPage = Context.Pages.Universal


    local OriginalWalkspeed = Player.Character.Humanoid.WalkSpeed
    local OriginalJumpPower = Player.Character.Humanoid.JumpPower
    -- // Sections // --
    
    local PlayerSection = UniversalPage:Section({
        Name = "Player", Icon = "user", Side = 1,
    }); local MovementSection = UniversalPage:Section({
        Name = "Movement", Icon = "zap", Side = 2,
    }); local VisualSection = UniversalPage:Section({
        Name = "Visuals", Icon = "eye", Side = 1,
    }); local CameraSection = UniversalPage:Section({
        Name = "Camera", Icon = "camera", Side = 2,
    })

    local WalkspeedToggle = PlayerSection:Toggle({
        Name = "Walkspeed Toggle", Flag = "WalkspeedToggle", Default = false, Tooltip = "Toggles walkspeed modification", Callback = function(State)
            if State then
                Player.Character.Humanoid.WalkSpeed = WalkspeedSlider.Value
            else
                Player.Character.Humanoid.WalkSpeed = OriginalWalkspeed
            end
        end,
    })

    local WalkspeedSub = WalkspeedToggle:Settings(260)
    local WalkspeedSlider = WalkspeedSub:Slider({
        Name = "Speed", Flag = "WalkspeedSlider", Default = 16, Min = 10, Max = 500, Increment = 2, Suffix = " WalkSpeed", Callback = function(Value)
            if WalkspeedToggle.Value then
                Player.Character.Humanoid.WalkSpeed = Value
            end
        end,
    })

    Library:Notification({
        Title = "Universal", Description = "Universal page loaded.", Duration = 2, Icon = "97594400820219",
    })
end