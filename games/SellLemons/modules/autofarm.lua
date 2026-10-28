-- Collect CashDrop and SpookyCoinDrop objects from workspace.Drops.
return function(context)
    local players = game:GetService("Players")
    local section = context.Sections.Autofarm
    local statusLabel = section:Label("AutoFarm is off.")
    local touchStatusLabel = section:Label("TouchInterest AutoFarm is off.")
    local enabled = false
    local workerId = 0
    local touchEnabled = false
    local touchWorkerId = 0

    local dropNames = {
        CashDrop = true,
        SpookyCoinDrop = true,
    }

    local function getDropCFrame(drop)
        return drop and drop:IsA("BasePart") and drop.CFrame or nil
    end

    local function findDrops()
        local dropsFolder = workspace:FindFirstChild("Drops")
        if not dropsFolder then
            return nil
        end

        local found = {}
        for _, instance in ipairs(dropsFolder:GetDescendants()) do
            if dropNames[instance.Name] and instance:IsA("BasePart") then
                table.insert(found, instance)
            end
        end

        return found
    end

    local function findTouchInterestDrops()
        local dropsFolder = workspace:FindFirstChild("Drops")
        if not dropsFolder then
            return nil
        end

        local found = {}
        for _, instance in ipairs(dropsFolder:GetDescendants()) do
            if dropNames[instance.Name]
                and instance:IsA("BasePart")
                and instance:FindFirstChild("TouchInterest")
            then
                table.insert(found, instance)
            end
        end

        return found
    end

    local function runAutofarm(id)
        while context.Alive and enabled and id == workerId do
            local character = players.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local dropsFolder = workspace:FindFirstChild("Drops")
            local drops = findDrops()

            if not dropsFolder then
                statusLabel:SetText("Waiting for workspace.Drops.")
                task.wait(0.5)
            elseif not root or not humanoid or humanoid.Health <= 0 then
                statusLabel:SetText("Waiting for your character.")
                task.wait(0.5)
            elseif not drops or #drops == 0 then
                statusLabel:SetText("Waiting for CashDrop or SpookyCoinDrop.")
                task.wait(0.5)
            else
                table.sort(drops, function(first, second)
                    local firstCFrame = getDropCFrame(first)
                    local secondCFrame = getDropCFrame(second)
                    if not firstCFrame then return false end
                    if not secondCFrame then return true end
                    return (firstCFrame.Position - root.Position).Magnitude
                        < (secondCFrame.Position - root.Position).Magnitude
                end)

                for _, drop in ipairs(drops) do
                    if not context.Alive or not enabled or id ~= workerId then
                        break
                    end

                    local dropCFrame = drop.Parent and getDropCFrame(drop)
                    character = players.LocalPlayer.Character
                    root = character and character:FindFirstChild("HumanoidRootPart")
                    humanoid = character and character:FindFirstChildOfClass("Humanoid")

                    if dropCFrame and root and humanoid and humanoid.Health > 0 then
                        statusLabel:SetText("Collecting " .. drop.Name .. "...")
                        root.AssemblyLinearVelocity = Vector3.zero
                        root.AssemblyAngularVelocity = Vector3.zero
                        local destination = CFrame.new(dropCFrame.Position + Vector3.new(0, 0.5, 0))
                        character:PivotTo(destination)
                        task.wait(0.15)
                    end
                end

                task.wait(0.2)
            end
        end
    end

    section:Toggle({
        Name = "AutoFarm",
        Flag = "SellLemonsAutoFarm",
        Default = false,
        Callback = function(isEnabled)
            enabled = isEnabled
            workerId = workerId + 1

            if enabled then
                task.spawn(runAutofarm, workerId)
            else
                statusLabel:SetText("AutoFarm is off.")
            end
        end,
    })

    local function runTouchInterestAutofarm(id)
        while context.Alive and touchEnabled and id == touchWorkerId do
            local dropsFolder = workspace:FindFirstChild("Drops")
            local character = players.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local drops = findTouchInterestDrops()

            if type(firetouchinterest) ~= "function" then
                touchStatusLabel:SetText("TouchInterest AutoFarm needs firetouchinterest support.")
                task.wait(1)
            elseif not dropsFolder then
                touchStatusLabel:SetText("Waiting for workspace.Drops.")
                task.wait(0.5)
            elseif not root or not humanoid or humanoid.Health <= 0 then
                touchStatusLabel:SetText("Waiting for your character.")
                task.wait(0.5)
            elseif not drops or #drops == 0 then
                touchStatusLabel:SetText("Waiting for CashDrop or SpookyCoinDrop TouchInterest parts.")
                task.wait(0.5)
            else
                local triggered = 0
                for _, drop in ipairs(drops) do
                    if not context.Alive or not touchEnabled or id ~= touchWorkerId then
                        break
                    end

                    if drop.Parent and drop:FindFirstChild("TouchInterest") then
                        local began = pcall(firetouchinterest, root, drop, 0)
                        task.wait(0.03)
                        pcall(firetouchinterest, root, drop, 1)
                        if began then
                            triggered = triggered + 1
                        end
                    end
                end

                touchStatusLabel:SetText(string.format(
                    "Triggered %d drop touch(es).",
                    triggered
                ))
                task.wait(0.25)
            end
        end
    end

    section:Toggle({
        Name = "TouchInterest AutoFarm",
        Flag = "SellLemonsTouchInterestAutoFarm",
        Default = false,
        Callback = function(isEnabled)
            touchEnabled = isEnabled
            touchWorkerId = touchWorkerId + 1

            if touchEnabled then
                task.spawn(runTouchInterestAutofarm, touchWorkerId)
            else
                touchStatusLabel:SetText("TouchInterest AutoFarm is off.")
            end
        end,
    })

    context.AddCleanup(function()
        enabled = false
        workerId = workerId + 1
        touchEnabled = false
        touchWorkerId = touchWorkerId + 1
    end)
end
