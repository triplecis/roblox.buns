-- Collect the selected drop type by moving to it, or test direct server redemption.
return function(context)
    local players = game:GetService("Players")
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local section = context.Sections.Autofarm

    local dropTypes = { "CashDrop", "SpookyCoinDrop" }
    local selectedDropType
    -- The game uses the pickup ordinal as the redeem argument: 1, 2, 3, ...
    local nextRedeemId = 1
    local autofarmEnabled = false
    local autofarmWorkerId = 0
    local redeemEnabled = false
    local redeemWorkerId = 0
    local redeemedDrops = {}

    local autofarmStatus = section:Label("Choose a drop type to begin.")
    local redeemStatus = section:Label("Remote redeem is off.")

    section:Listbox({
        Name = "Drop type",
        Flag = "SellLemonsDropType",
        Items = dropTypes,
        Multi = false,
        Callback = function(selection)
            if type(selection) == "table" then
                selection = selection[1]
            end

            if selection ~= "CashDrop" and selection ~= "SpookyCoinDrop" then
                selectedDropType = nil
            else
                selectedDropType = selection
            end

            table.clear(redeemedDrops)
            autofarmStatus:SetText(selectedDropType
                and ("Selected " .. selectedDropType .. ".")
                or "Choose a drop type to begin.")
        end,
    })

    section:Label("Redeem IDs start at 1 and advance after each successful request.")

    local function findDrops()
        local dropsFolder = workspace:FindFirstChild("Drops")
        if not dropsFolder or not selectedDropType then
            return dropsFolder, {}
        end

        local found = {}
        for _, instance in ipairs(dropsFolder:GetDescendants()) do
            if instance.Name == selectedDropType and instance:IsA("BasePart") then
                table.insert(found, instance)
            end
        end

        return dropsFolder, found
    end

    local function getRedeemRemote()
        local core = replicatedStorage:FindFirstChild("Core")
        local remoteRequest = core and core:FindFirstChild("RemoteRequest")
        local redeem = remoteRequest and remoteRequest:FindFirstChild("DropService.Redeem")
        return redeem and redeem:IsA("RemoteFunction") and redeem or nil
    end

    local function runAutofarm(id)
        while context.Alive and autofarmEnabled and id == autofarmWorkerId do
            local dropsFolder, drops = findDrops()
            local character = players.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if not selectedDropType then
                autofarmStatus:SetText("Choose CashDrop or SpookyCoinDrop.")
            elseif not dropsFolder then
                autofarmStatus:SetText("Waiting for workspace.Drops.")
            elseif not root or not humanoid or humanoid.Health <= 0 then
                autofarmStatus:SetText("Waiting for your character.")
            elseif #drops == 0 then
                autofarmStatus:SetText("Waiting for " .. selectedDropType .. ".")
            else
                table.sort(drops, function(first, second)
                    return (first.Position - root.Position).Magnitude
                        < (second.Position - root.Position).Magnitude
                end)

                local drop = drops[1]
                if drop.Parent then
                    autofarmStatus:SetText("Moving to " .. selectedDropType .. "...")
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.AssemblyAngularVelocity = Vector3.zero
                    character:PivotTo(CFrame.new(drop.Position + Vector3.new(0, 0.5, 0)))
                end
            end

            task.wait(0.2)
        end
    end

    local function runRemoteRedeem(id)
        while context.Alive and redeemEnabled and id == redeemWorkerId do
            local dropsFolder, drops = findDrops()
            local redeem = getRedeemRemote()

            if not selectedDropType then
                redeemStatus:SetText("Choose CashDrop or SpookyCoinDrop.")
            elseif not dropsFolder then
                redeemStatus:SetText("Waiting for workspace.Drops.")
            elseif not redeem then
                redeemStatus:SetText("Waiting for Core.RemoteRequest.DropService.Redeem.")
            else
                local present = {}
                for _, drop in ipairs(drops) do
                    present[drop] = true
                end
                for drop in pairs(redeemedDrops) do
                    if not present[drop] then
                        redeemedDrops[drop] = nil
                    end
                end

                local redeemedOne = false
                for _, drop in ipairs(drops) do
                    if not context.Alive or not redeemEnabled or id ~= redeemWorkerId then
                        break
                    end

                    if not redeemedDrops[drop] and drop.Parent then
                        local requestId = tostring(nextRedeemId)
                        redeemStatus:SetText(string.format(
                            "Redeeming %s (ID %s)...",
                            selectedDropType,
                            requestId
                        ))

                        local succeeded, result = pcall(function()
                            return redeem:InvokeServer(requestId)
                        end)

                        if succeeded and result ~= false then
                            redeemedDrops[drop] = true
                            nextRedeemId += 1
                            redeemedOne = true
                            redeemStatus:SetText(string.format(
                                "Redeemed %s. Next ID: %d.",
                                selectedDropType,
                                nextRedeemId
                            ))
                        else
                            redeemStatus:SetText(string.format(
                                "Redeem failed for ID %s; check the next ID setting.",
                                requestId
                            ))
                            break
                        end

                        task.wait(0.05)
                    end
                end

                if not redeemedOne and #drops == 0 then
                    redeemStatus:SetText("Waiting for " .. selectedDropType .. ".")
                elseif not redeemedOne and #drops > 0 then
                    redeemStatus:SetText(string.format(
                        "Watching %s drops. Next ID: %d.",
                        selectedDropType,
                        nextRedeemId
                    ))
                end
            end

            task.wait(0.2)
        end
    end

    section:Toggle({
        Name = "AutoFarm",
        Flag = "SellLemonsAutoFarm",
        Default = false,
        Callback = function(isEnabled)
            autofarmEnabled = isEnabled
            autofarmWorkerId += 1
            if autofarmEnabled then
                task.spawn(runAutofarm, autofarmWorkerId)
            else
                autofarmStatus:SetText("AutoFarm is off.")
            end
        end,
    })

    section:Toggle({
        Name = "Remote Redeem AutoFarm",
        Flag = "SellLemonsRemoteRedeemAutoFarm",
        Default = false,
        Callback = function(isEnabled)
            redeemEnabled = isEnabled
            redeemWorkerId += 1
            if redeemEnabled then
                task.spawn(runRemoteRedeem, redeemWorkerId)
            else
                redeemStatus:SetText("Remote redeem is off.")
            end
        end,
    })

    context.AddCleanup(function()
        autofarmEnabled = false
        autofarmWorkerId += 1
        redeemEnabled = false
        redeemWorkerId += 1
    end)
end
