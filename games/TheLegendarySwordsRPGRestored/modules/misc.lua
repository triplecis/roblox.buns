-- Local bubble preview controls for The Legendary Swords RPG Restored.
return function(context)
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local inputService = game:GetService("UserInputService")
    local replicatedStorage = game:GetService("ReplicatedStorage")

    local section = context.Sections.Misc
    local bubbleEvent = replicatedStorage:FindFirstChild("Bubbles")
    local loopKey = Enum.KeyCode.B
    local loopEnabled = false
    local waitingForKey = false
    local elapsed = 0
    local bubblesInLoop = 0
    local maxBubblesPerLoop = 10
    local removeLoopEnabled = false
    local removeElapsed = 0

    local statusLabel = section:Label("Bubble preview: stopped (local player only)")
    local keyLabel = section:Label("Loop key: B")
    local removerStatus = section:Label("Bubble remover: stopped")

    local function setStatus(message)
        statusLabel:SetText(message)
    end

    local function spawnLocalBubble()
        local localPlayer = players.LocalPlayer

        if not bubbleEvent or not bubbleEvent:IsA("RemoteEvent") then
            setStatus("Bubble event is unavailable.")
            return false
        end

        if type(firesignal) ~= "function" then
            setStatus("This client does not support local signal testing.")
            return false
        end

        -- Fire only this client's listener and pass only the local player.
        local succeeded, errorMessage = pcall(
            firesignal,
            bubbleEvent.OnClientEvent,
            localPlayer
        )

        if not succeeded then
            setStatus("Bubble preview failed: " .. tostring(errorMessage))
            return false
        end

        return true
    end

    local function toggleLoop()
        loopEnabled = not loopEnabled
        elapsed = 0
        bubblesInLoop = 0

        if loopEnabled then
            setStatus("Bubble preview: looping (local player only)")
        else
            setStatus("Bubble preview: stopped (local player only)")
        end
    end

    -- Require the name, material, shape, location, and mesh to all match.
    local function isBubblePart(instance)
        if not instance:IsA("Part") then
            return false
        end

        if instance.Parent ~= workspace or instance.Name ~= "bubble" then
            return false
        end

        if instance.Material ~= Enum.Material.Brick or instance.Shape ~= Enum.PartType.Block then
            return false
        end

        for _, child in ipairs(instance:GetChildren()) do
            if child:IsA("BlockMesh") then
                return true
            end

            if child:IsA("SpecialMesh") and child.MeshType == Enum.MeshType.Brick then
                return true
            end
        end

        return false
    end

    local function removeBubbleParts()
        local removedCount = 0

        for _, instance in ipairs(workspace:GetChildren()) do
            if isBubblePart(instance) then
                local succeeded = pcall(function()
                    instance:Destroy()
                end)

                if succeeded then
                    removedCount = removedCount + 1
                end
            end
        end

        removerStatus:SetText("Bubble remover removed " .. tostring(removedCount) .. ".")
        return removedCount
    end

    section:Button({
        Name = "Spawn one bubble",
        Callback = function()
            if spawnLocalBubble() then
                setStatus("Spawned one local bubble.")
            end
        end,
    })

    section:Button({
        Name = "Change loop key",
        Callback = function()
            waitingForKey = true
            setStatus("Press a keyboard key to bind the loop.")
        end,
    })

    section:Button({
        Name = "Remove existing bubbles",
        Callback = removeBubbleParts,
    })

    section:Toggle({
        Name = "Loop bubble remover",
        Flag = "LegendaryBubbleRemoverLoop",
        Default = false,
        Callback = function(enabled)
            removeLoopEnabled = enabled
            removeElapsed = 0

            if enabled then
                removerStatus:SetText("Bubble remover: running")
                removeBubbleParts()
            else
                removerStatus:SetText("Bubble remover: stopped")
            end
        end,
    })

    section:Label("Press the loop key to start or stop the one-second preview loop.")

    context.Connect(inputService.InputBegan, function(input, gameProcessed)
        if inputService:GetFocusedTextBox() then
            return
        end

        if waitingForKey then
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end

            waitingForKey = false
            if input.KeyCode == Enum.KeyCode.Escape then
                keyLabel:SetText("Loop key: " .. loopKey.Name)
                setStatus("Key change cancelled.")
                return
            end

            loopKey = input.KeyCode
            keyLabel:SetText("Loop key: " .. loopKey.Name)
            setStatus("Press the loop key to start or stop the preview.")
            return
        end

        if not gameProcessed and input.KeyCode == loopKey then
            toggleLoop()
        end
    end)

    context.Connect(runService.Heartbeat, function(deltaTime)
        if not loopEnabled then
            return
        end

        elapsed = elapsed + deltaTime
        if elapsed < 1 then
            return
        end

        elapsed = elapsed % 1
        if not spawnLocalBubble() then
            loopEnabled = false
            return
        end

        bubblesInLoop = bubblesInLoop + 1
        if bubblesInLoop >= maxBubblesPerLoop then
            loopEnabled = false
            setStatus("Preview stopped after 10 bubbles.")
        end
    end)

    context.Connect(runService.Heartbeat, function(deltaTime)
        if not removeLoopEnabled then
            return
        end

        removeElapsed = removeElapsed + deltaTime
        if removeElapsed < 0.5 then
            return
        end

        removeElapsed = removeElapsed % 0.5
        removeBubbleParts()
    end)

    context.AddCleanup(function()
        loopEnabled = false
        waitingForKey = false
        removeLoopEnabled = false
    end)
end
