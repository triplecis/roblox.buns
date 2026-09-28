return function(Context)
    local Player = Context.Player
    local Character = Player.Character or Player.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")

    local Library = Context.Library
    local Window = Context.Window
    local UniversalPage = Context.Pages.Universal


   local BaseWalkSpeed = Humanoid.WalkSpeed or 16; local BaseJumpPower = Humanoid.JumpPower or 50 ; local BaseJumpHeight = Humanoid.JumpHeight or 7.2
    local ChangingWalkSpeed = false; local ChangingJump = false

    --// Functions //--

    local function ApplyWalkSpeed()
        if not WalkSpeedToggle or WalkSpeedToggle.State then
            return
        end

        local Multiplier = 1 + (WalkSpeedSlider.Value / 100)

        ChangingWalkSpeed = true
        Humanoid.WalkSpeed = (BaseWalkSpeed * Multiplier)
        ChangingWalkSpeed = false
    end

    Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if ChangingWalkSpeed then
            return
        end

        BaseWalkSpeed = Humanoid.WalkSpeed

        if WalkSpeedToggle and WalkSpeedToggle.State then
            ApplyWalkSpeed()
        end
    end)

    local function ApplyJump()
        --//apply later
    end

    Humanoid:GetPropertyChangedSignal("JumpPower" or "JumpHeight"):Connect(function()
        if ChangingJump then
            return
        end

        BaseJumpPower = Humanoid.JumpPower
        BaseJumpHeight = Humanoid.JumpHeight

        if Jump and WalkSpeedToggle.State then
            ApplyWalkSpeed()
        end
    end)
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

    local WalkSpeedToggle = PlayerSection:Toggle({
        Name = "WalkSpeed Toggle", 
        Flag = "WalkSpeedToggle", 
        Default = false, 
        Tooltip = "Toggles WalkSpeed modification", 
        Callback = function(State)
            if State then
                BaseWalkSpeed = Humanoid.WalkSpeed
                ApplyWalkSpeed()
            else
                ChangingWalkSpeed = true
                Humanoid.WalkSpeed = BaseWalkSpeed
                ChangingWalkSpeed = false
            end
        end,
    }); local WalkSpeedSub = WalkSpeedToggle:Settings(260); local WalkSpeedSlider = WalkSpeedSub:Slider({
        Name = "Speed", 
        Flag = "WalkSpeedSlider", 
        Default = 16, 
        Min = 10, 
        Max = 500, 
        Increment = 2, 
        Suffix = " %",
        Callback = function(Value)
            if WalkSpeedToggle.State then
                local Multiplier = 1 + (WalkSpeedSlider.Value / WalkSpeedSlider.Max)
                Humanoid.WalkSpeed = (Humanoid.WalkSpeed * Multiplier)
            end
        end,
    }); 

    if Humanoid.UseJumpPower == true then
        local JumpPowerToggle = PlayerSection:Toggle({
            Name = "Jump Power Toggle", 
            Flag = "JumpPowerToggle", 
            Default = false, 
            Tooltip = "Toggles Jump Power modification", Callback = function(State)

            if State then
                Humanoid.JumpPower = JumpPowerSlider.Value

            else
                Humanoid.JumpPower = BaseJumpPower

            end; end,}); 

        local JumpPowerSub = JumpPowerToggle:Settings(260)
        local JumpPowerSlider = JumpPowerSub:Slider({
            Name = "Jump", Flag = "JumpPowerSlider", Default = 50, Min = 10, Max = 200, Increment = 2, Suffix = " JumpPower", Callback = function(Value)
                if JumpPowerToggle.State then
                    Humanoid.JumpPower = Value
                end
            end,
        })
    else
        local JumpHeightToggle = PlayerSection:Toggle({
            Name = "JumpHeight Toggle", 
            Flag = "JumpHeightToggle", 
            Default = false, 
            Tooltip = "Toggles Jump Height modification", Callback = function(State)

            if State then
                Humanoid.JumpHeight = JumpHeightSlider.Value

            else
                Humanoid.JumpHeight = BaseJumpHeight
            end; end,});
        local JumpHeightSub = JumpHeightToggle:Settings(260)
        local JumpHeightSlider = JumpHeightSub:Slider({
            Name = "Jump", 
            Flag = "JumpHeightSlider", 
            Default = 50, 
            Min = 10, 
            Max = 200, 
            Increment = 2, 
            Suffix = " %", Callback = function(Value)
                if JumpHeightToggle.State then
                    Humanoid.JumpHeight = Value
                end
            end,
        })
    
    

    Library:Notification({
        Title = "Universal", 
        Description = "Universal page loaded.", 
        Duration = 2, 
        Icon = "97594400820219",
    })
end