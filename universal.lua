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
    }); local WalkspeedSub = WalkspeedToggle:Settings(260); local WalkspeedSlider = WalkspeedSub:Slider({
        Name = "Speed", Flag = "WalkspeedSlider", Default = 16, Min = 10, Max = 500, Increment = 2, Suffix = " WalkSpeed", Callback = function(Value)
            if WalkspeedToggle.Value then
                Player.Character.Humanoid.WalkSpeed = Value
            end
        end,
    }); local JumpPowerToggle = PlayerSection:Toggle({
        Name = "Jump Power Toggle", Flag = "JumpPowerToggle", Default = false, Tooltip = "Toggles jump power modification", Callback = function(State)
            if State then
                Player.Character.Humanoid.JumpPower = JumpPowerSlider.Value
            else
                Player.Character.Humanoid.JumpPower = OriginalJumpPower
            end
        end,
    }); local JumpPowerSub = JumpPowerToggle:Settings(260); local JumpPowerSlider = JumpPowerSub:Slider({
        Name = "Jump", Flag = "JumpPowerSlider", Default = 50, Min = 10, Max = 200, Increment = 2, Suffix = " JumpPower", Callback = function(Value)
            if JumpPowerToggle.Value then
                Player.Character.Humanoid.JumpPower = Value
            end
        end,
    })

    Library:Notification({
        Title = "Universal", Description = "Universal page loaded.", Duration = 2, Icon = "97594400820219",
    })
end