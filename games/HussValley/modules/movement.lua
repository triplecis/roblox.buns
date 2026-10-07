return function(Context)
    local Section = Context.Sections.Movement
    local Speed = Section:Label("Waiting for character...")
    local MovementState = Section:Label("")
    local Dash = Section:Label("")
    local LastDash = Section:Label("")
    local Block = Section:Label("")
    local Profile = Section:Label("Movement profile: not loaded")
    Section:Label("The game controls movement through its own speed profile.")
    Section:Label("Dash: Space | Gamepad: RT / R2 | Touch: DASH")
    local TouchStyle, DashShortcut = false, false
    Section:Toggle({
        Name = "Touch-style dash input",
        Flag = "HussValleyDashTouchInput",
        Default = false,
        Callback = function(Enabled) TouchStyle = Enabled end,
    })
    Section:Button({
        Name = "Request dash",
        Callback = function() Context.RequestDash(TouchStyle) end,
    })
    Section:Toggle({
        Name = "Dash shortcut (V)",
        Flag = "HussValleyDashShortcut",
        Default = false,
        Callback = function(Enabled) DashShortcut = Enabled end,
    })
    Section:Button({ Name = "Read movement profile", Callback = Context.ReadMovementProfile })
    local InputService = game:GetService("UserInputService")
    Context.Connect(InputService.InputBegan, function(Input, Processed)
        if DashShortcut and not Processed and not InputService:GetFocusedTextBox() and Input.KeyCode == Enum.KeyCode.V then
            Context.RequestDash(TouchStyle)
        end
    end)
    local FOVEnabled, RotationDisabled = false, false
    local FOV = 80
    local CameraState, RotationState

    local function RestoreFOV()
        if CameraState then
            if CameraState.Camera.FieldOfView == CameraState.Applied then
                CameraState.Camera.FieldOfView = CameraState.Baseline
            end
            CameraState = nil
        end
    end

    local function UpdateFOV()
        local Camera = workspace.CurrentCamera
        if not FOVEnabled or not Camera then RestoreFOV(); return end
        if CameraState and CameraState.Camera ~= Camera then RestoreFOV() end
        if not CameraState then
            CameraState = { Camera = Camera, Baseline = Camera.FieldOfView }
        elseif Camera.FieldOfView ~= CameraState.Applied then
            CameraState.Baseline = Camera.FieldOfView
        end
        CameraState.Applied = FOV
        Camera.FieldOfView = FOV
    end

    local function RestoreRotation()
        if RotationState then
            local Humanoid = RotationState.Humanoid
            if Humanoid.Parent and Humanoid.AutoRotate == false then
                Humanoid.AutoRotate = RotationState.Baseline
            end
            RotationState = nil
        end
    end

    local function UpdateRotation()
        local Character = Context.Player.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        if not RotationDisabled or not Humanoid then RestoreRotation(); return end
        if RotationState and RotationState.Humanoid ~= Humanoid then RestoreRotation() end
        if not RotationState then
            RotationState = { Humanoid = Humanoid, Baseline = Humanoid.AutoRotate }
        elseif Humanoid.AutoRotate ~= false then
            RotationState.Baseline = Humanoid.AutoRotate
        end
        Humanoid.AutoRotate = false
    end

    local FOVToggle = Section:Toggle({
        Name = "Custom camera FOV",
        Flag = "HussValleyFOVEnabled",
        Default = false,
        Callback = function(Enabled)
            FOVEnabled = Enabled
            UpdateFOV()
        end,
    })
    FOVToggle:Settings(260):Slider({
        Name = "Field of view",
        Flag = "HussValleyFOV",
        Default = FOV,
        Min = 40,
        Max = 120,
        Decimals = 1,
        Suffix = " degrees",
        Callback = function(Value)
            FOV = Value
            UpdateFOV()
        end,
    })
    Section:Toggle({
        Name = "Disable automatic turning",
        Flag = "HussValleyDisableAutoRotate",
        Default = false,
        Callback = function(Enabled)
            RotationDisabled = Enabled
            UpdateRotation()
        end,
    })
    Context.Subscribe(function(Snapshot)
        Speed:SetText(Snapshot.Speed and string.format("Horizontal speed: %.1f studs/s", Snapshot.Speed)
            or "Waiting for character...")
        local Data = Snapshot.Movement
        MovementState:SetText("Movement state: " .. tostring(Data.State or "unavailable"))
        local Ready = Data.DashReady == true and "ready" or (Data.DashReady == false and "not ready" or "unavailable")
        Dash:SetText(string.format("Dash: %s | Cooldown: %s", Ready,
            Data.DashCooldown and string.format("%.2fs", Data.DashCooldown) or "unavailable"))
        LastDash:SetText(string.format("Dashes: %s | Last distance: %s", tostring(Data.DashCount or "unavailable"),
            Data.LastDashDistance and string.format("%.1f studs", Data.LastDashDistance) or "unavailable"))
        Block:SetText("Movement blocked: " .. tostring(Data.BlockReason or "no"))
        local CurrentProfile = Snapshot.MovementProfile
        if CurrentProfile then
            Profile:SetText("Profile max speed: " .. tostring(CurrentProfile.MaxSpeed)
                .. " | Acceleration: " .. tostring(CurrentProfile.Acceleration))
        else
            Profile:SetText(Context.State.MovementProfileError and "Movement profile unavailable" or "Movement profile: not loaded")
        end
        UpdateFOV()
        UpdateRotation()
    end)
    Context.AddCleanup(function()
        RestoreFOV()
        RestoreRotation()
    end)
end
