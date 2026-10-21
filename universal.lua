-- Shared movement controls for the local character.
return function(context)
    local player = context.Player
    local section = context.Pages.Universal:Section({
        Name = "Player",
        Icon = "user",
        Side = 1,
    })
    local statusLabel = section:Label("Waiting for character...")

    local humanoid
    local characterConnections = {}
    local baselines = {}
    local lastAppliedValues = {}
    local enabled = {
        WalkSpeed = false,
        JumpPower = false,
        JumpHeight = false,
    }
    local sliderValues = {
        WalkSpeed = 16,
        JumpPower = 50,
        JumpHeight = 7.2,
    }
    local walkSpeedSuspended = false

    local function disconnectCharacterSignals()
        for _, connection in ipairs(characterConnections) do
            connection:Disconnect()
        end

        table.clear(characterConnections)
    end

    local function applyProperty(property)
        if not humanoid or not humanoid.Parent or not enabled[property] then
            return
        end

        if property == "WalkSpeed" and walkSpeedSuspended then
            return
        end

        local value = sliderValues[property]
        if property == "WalkSpeed" then
            value = baselines.WalkSpeed * (1 + value / 100)
        end

        -- Record our write so the change signal can distinguish it from game updates.
        lastAppliedValues[property] = value
        if humanoid[property] ~= value then
            humanoid[property] = value
        end
    end

    local function restoreProperty(property)
        if not humanoid or not humanoid.Parent or baselines[property] == nil then
            return
        end

        -- Capture a game update that arrived before its property signal ran.
        local appliedValue = lastAppliedValues[property]
        if appliedValue ~= nil and humanoid[property] ~= appliedValue then
            baselines[property] = humanoid[property]
        end

        lastAppliedValues[property] = baselines[property]
        humanoid[property] = baselines[property]
    end

    -- The Huss Valley sprint control can temporarily take ownership of WalkSpeed.
    function context.SetWalkSpeedSuspended(shouldSuspend)
        if walkSpeedSuspended == shouldSuspend then
            return
        end

        if shouldSuspend and enabled.WalkSpeed then
            restoreProperty("WalkSpeed")
        end

        walkSpeedSuspended = shouldSuspend

        if not shouldSuspend and context.Alive then
            applyProperty("WalkSpeed")
        end
    end

    local function updateStatus()
        if not context.Alive then
            return
        end

        if not humanoid then
            statusLabel:SetText("Waiting for character...")
        elseif humanoid.UseJumpPower then
            statusLabel:SetText("Jump mode: power")
        else
            statusLabel:SetText("Jump mode: height")
        end
    end

    local function bindHumanoid(newHumanoid)
        humanoid = newHumanoid
        table.clear(lastAppliedValues)

        local properties = { "WalkSpeed", "JumpPower", "JumpHeight" }
        for _, property in ipairs(properties) do
            baselines[property] = humanoid[property]

            local signal = humanoid:GetPropertyChangedSignal(property)
            local connection = signal:Connect(function()
                if not context.Alive or humanoid ~= newHumanoid then
                    return
                end

                local currentValue = newHumanoid[property]
                if currentValue == lastAppliedValues[property] then
                    return
                end

                baselines[property] = currentValue
                applyProperty(property)
            end)

            table.insert(characterConnections, connection)
            applyProperty(property)
        end

        local jumpModeSignal = humanoid:GetPropertyChangedSignal("UseJumpPower")
        table.insert(characterConnections, jumpModeSignal:Connect(updateStatus))
        updateStatus()
    end

    local function bindCharacter(character)
        disconnectCharacterSignals()
        humanoid = nil
        table.clear(baselines)
        table.clear(lastAppliedValues)
        updateStatus()

        -- Watch for a Humanoid that is added after the character model appears.
        local childAdded = character.ChildAdded:Connect(function(child)
            local isCurrentCharacter = player.Character == character
            if context.Alive and isCurrentCharacter and child:IsA("Humanoid") and not humanoid then
                bindHumanoid(child)
            end
        end)
        table.insert(characterConnections, childAdded)

        local existingHumanoid = character:FindFirstChildOfClass("Humanoid")
        if existingHumanoid then
            bindHumanoid(existingHumanoid)
        end
    end

    local function addMovementControl(property, displayName, flag, minimum, maximum, decimals, suffix)
        local toggle = section:Toggle({
            Name = displayName,
            Flag = flag .. "Toggle",
            Default = false,
            Callback = function(shouldEnable)
                local wasEnabled = enabled[property]
                enabled[property] = shouldEnable

                if shouldEnable then
                    if humanoid and not wasEnabled then
                        baselines[property] = humanoid[property]
                    end
                    applyProperty(property)
                elseif wasEnabled then
                    restoreProperty(property)
                end
            end,
        })

        local sliderName = displayName
        if property == "WalkSpeed" then
            sliderName = "Speed increase"
        end

        toggle:Settings(260):Slider({
            Name = sliderName,
            Flag = flag .. "Slider",
            Default = sliderValues[property],
            Min = minimum,
            Max = maximum,
            Decimals = decimals,
            Suffix = suffix,
            Callback = function(value)
                sliderValues[property] = value
                applyProperty(property)
            end,
        })
    end

    addMovementControl("WalkSpeed", "Walk speed", "WalkSpeed", 0, 500, 1, " %")
    addMovementControl("JumpPower", "Jump power", "JumpPower", 0, 500, 1, "")
    addMovementControl("JumpHeight", "Jump height", "JumpHeight", 0, 200, 0.1, " studs")

    context.Connect(player.CharacterAdded, bindCharacter)

    context.Connect(player.CharacterRemoving, function()
        disconnectCharacterSignals()
        humanoid = nil
        updateStatus()
    end)

    context.AddCleanup(function()
        disconnectCharacterSignals()

        for property, isEnabled in pairs(enabled) do
            if isEnabled then
                restoreProperty(property)
            end
        end

        humanoid = nil
    end)

    if player.Character then
        bindCharacter(player.Character)
    end
end
