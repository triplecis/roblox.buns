-- Apply local camera and humanoid settings continuously while each option is enabled.
return function(context)
    local runService = game:GetService("RunService")
    local section = context.Sections.Misc

    local fovEnabled = false
    local fov = 70
    local fovState

    local walkSpeedEnabled = false
    local walkSpeed = 16
    local jumpEnabled = false
    local jumpStrength = 50
    local humanoidState

    local function restoreFov()
        if fovState then
            if fovState.Camera.FieldOfView == fovState.Applied then
                pcall(function()
                    fovState.Camera.FieldOfView = fovState.Baseline
                end)
            end
            fovState = nil
        end
    end

    local function updateFov()
        local camera = workspace.CurrentCamera
        if not fovEnabled or not camera then
            restoreFov()
            return
        end

        if fovState and fovState.Camera ~= camera then
            restoreFov()
        end
        if not fovState then
            fovState = { Camera = camera, Baseline = camera.FieldOfView }
        elseif camera.FieldOfView ~= fovState.Applied then
            fovState.Baseline = camera.FieldOfView
        end

        fovState.Applied = fov
        if camera.FieldOfView ~= fov then
            camera.FieldOfView = fov
        end
    end

    local function restoreHumanoid()
        if not humanoidState then
            return
        end

        for property, saved in pairs(humanoidState.Properties) do
            pcall(function()
                if humanoidState.Humanoid[property] == saved.Applied then
                    humanoidState.Humanoid[property] = saved.Baseline
                end
            end)
        end
        humanoidState = nil
    end

    local function applyHumanoidProperty(humanoid, property, desired)
        local saved = humanoidState.Properties[property]
        local current = humanoid[property]
        if saved.Applied ~= nil and current ~= saved.Applied then
            -- Remember game-authored changes so disabling the slider restores them.
            saved.Baseline = current
        end
        saved.Applied = desired
        if current ~= desired then
            humanoid[property] = desired
        end
    end

    local function updateHumanoid()
        local player = context.Player or game:GetService("Players").LocalPlayer
        local character = player and player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            restoreHumanoid()
            return
        end

        if humanoidState and humanoidState.Humanoid ~= humanoid then
            restoreHumanoid()
        end
        if not humanoidState then
            humanoidState = {
                Humanoid = humanoid,
                Properties = {
                    WalkSpeed = { Baseline = humanoid.WalkSpeed },
                    JumpPower = { Baseline = humanoid.JumpPower },
                    JumpHeight = { Baseline = humanoid.JumpHeight },
                },
            }
        end

        if walkSpeedEnabled then
            applyHumanoidProperty(humanoid, "WalkSpeed", walkSpeed)
        else
            local saved = humanoidState.Properties.WalkSpeed
            if saved.Applied ~= nil then
                if humanoid.WalkSpeed ~= saved.Applied then
                    saved.Baseline = humanoid.WalkSpeed
                else
                    humanoid.WalkSpeed = saved.Baseline
                end
                saved.Applied = nil
            end
        end

        if jumpEnabled then
            -- One strength slider scales both Roblox jump modes from their defaults.
            applyHumanoidProperty(humanoid, "JumpPower", jumpStrength)
            applyHumanoidProperty(humanoid, "JumpHeight", jumpStrength * (7.2 / 50))
        else
            for _, property in ipairs({ "JumpPower", "JumpHeight" }) do
                local saved = humanoidState.Properties[property]
                if saved.Applied ~= nil then
                    if humanoid[property] ~= saved.Applied then
                        saved.Baseline = humanoid[property]
                    else
                        humanoid[property] = saved.Baseline
                    end
                    saved.Applied = nil
                end
            end
        end
    end

    local fovToggle = section:Toggle({
        Name = "Sticky FOV",
        Flag = "SellLemonsMiscFOVEnabled",
        Default = false,
        Callback = function(enabled)
            fovEnabled = enabled
            updateFov()
        end,
    })
    fovToggle:Settings(260):Slider({
        Name = "Field of view",
        Flag = "SellLemonsMiscFOV",
        Default = fov,
        Min = 40,
        Max = 120,
        Decimals = 1,
        Suffix = " degrees",
        Callback = function(value)
            fov = value
            updateFov()
        end,
    })

    local walkToggle = section:Toggle({
        Name = "Sticky WalkSpeed",
        Flag = "SellLemonsMiscWalkSpeedEnabled",
        Default = false,
        Callback = function(enabled)
            walkSpeedEnabled = enabled
            updateHumanoid()
        end,
    })
    walkToggle:Settings(260):Slider({
        Name = "WalkSpeed",
        Flag = "SellLemonsMiscWalkSpeed",
        Default = walkSpeed,
        Min = 0,
        Max = 150,
        Decimals = 1,
        Suffix = " studs/s",
        Callback = function(value)
            walkSpeed = value
            updateHumanoid()
        end,
    })

    local jumpToggle = section:Toggle({
        Name = "Sticky Jump",
        Flag = "SellLemonsMiscJumpEnabled",
        Default = false,
        Callback = function(enabled)
            jumpEnabled = enabled
            updateHumanoid()
        end,
    })
    jumpToggle:Settings(260):Slider({
        Name = "Jump strength",
        Flag = "SellLemonsMiscJump",
        Default = jumpStrength,
        Min = 0,
        Max = 150,
        Decimals = 1,
        Suffix = "",
        Callback = function(value)
            jumpStrength = value
            updateHumanoid()
        end,
    })

    context.Connect(runService.Heartbeat, function()
        updateFov()
        updateHumanoid()
    end)

    context.AddCleanup(function()
        fovEnabled = false
        walkSpeedEnabled = false
        jumpEnabled = false
        restoreFov()
        restoreHumanoid()
    end)
end
