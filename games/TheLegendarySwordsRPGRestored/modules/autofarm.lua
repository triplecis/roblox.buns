-- Read nested enemy models and their Level/Rebirth values from a Mobs folder.
return function(context)
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local pathfindingService = game:GetService("PathfindingService")
    local section = context.Sections.Autofarm
    local statusLabel = section:Label("Searching Workspace for a Mobs folder...")
    local selectedMobLabel = nil
    local mobByLabel = {}
    local mobByKey = {}
    local selectedMobKey = nil
    local selectedPlaceName = nil
    local placeByLabel = {}
    local stickyEnabled = false
    local stickyStatus = nil
    local stickyWorkerToken = 0
    local frozenRoot = nil
    local frozenRootWasAnchored = nil
    local autoRotateHumanoid = nil
    local originalAutoRotate = nil
    local stickyDepth = 2
    local stickySide = 0
    local stickyHeight = 0
    local stickyRotationX = 0
    local stickyRotationY = 0
    local stickyRotationZ = 0
    section:Label("Mob place")
    local placeList = section:Listbox({
        Flag = "LegendarySwordMobPlaces",
        Items = { "All places" },
        Multi = false,
        Callback = function(selection)
            if type(selection) == "table" then
                selection = selection[1]
            end

            selectedPlaceName = selection and placeByLabel[selection] or nil
            selectedMobLabel = nil
            selectedMobKey = nil
            stickyStatus = nil
        end,
    })
    local mobList = section:Listbox({
        Flag = "LegendarySwordMobs",
        Items = {},
        Multi = false,
        Callback = function(selection)
            if type(selection) == "table" then
                selection = selection[1]
            end
            selectedMobLabel = selection
            local selectedMob = selection and mobByLabel[selection]
            selectedMobKey = selectedMob and selectedMob.key or nil
            stickyStatus = nil
        end,
    })

    local elapsed = 0
    local previousItems = {}
    local previousPlaces = { "All places" }

    local function readValue(container, valueName, searchDescendants)
        local candidateNames = { string.lower(valueName) }
        if string.lower(valueName) == "level" then
            -- This place stores a mob's numeric level as Settings.Lvl.
            table.insert(candidateNames, "lvl")
        end

        local objects = searchDescendants and container:GetDescendants() or container:GetChildren()
        for _, candidateName in ipairs(candidateNames) do
            for _, object in ipairs(objects) do
                if string.lower(object.Name) == candidateName and object:IsA("ValueBase") then
                    return object.Value
                end
            end
        end

        -- Some versions expose the level only as a label, for example "Lv. 4".
        if string.lower(valueName) == "level" then
            for _, object in ipairs(objects) do
                if object.Name == "Level" and object:IsA("TextLabel") then
                    local displayedLevel = string.match(object.Text, "%d+")
                    if displayedLevel then
                        return tonumber(displayedLevel)
                    end
                end
            end
        end

        return nil
    end

    local function listsMatch(first, second)
        if #first ~= #second then
            return false
        end

        for index, item in ipairs(first) do
            if item ~= second[index] then
                return false
            end
        end

        return true
    end

    -- Keep numbered variants together: Bandit, Bandit1, Bandit2, ... Bandit10.
    local function mobNamesBefore(firstName, secondName)
        local firstLower = string.lower(firstName)
        local secondLower = string.lower(secondName)
        local firstBase, firstNumber = string.match(firstLower, "^(.-)(%d+)$")
        local secondBase, secondNumber = string.match(secondLower, "^(.-)(%d+)$")

        if (firstBase or firstLower) == (secondBase or secondLower) then
            if firstNumber == nil then
                return secondNumber ~= nil
            end
            if secondNumber == nil then
                return false
            end

            local firstIndex = tonumber(firstNumber)
            local secondIndex = tonumber(secondNumber)
            if firstIndex == secondIndex then
                return firstLower < secondLower
            end
            return firstIndex < secondIndex
        end

        return firstLower < secondLower
    end

    local function findMobsFolder()
        local directFolder = workspace:FindFirstChild("Mobs")
        if directFolder then
            return directFolder
        end

        -- Search every descendant case-insensitively; maps sometimes vary the
        -- capitalization or add whitespace to the folder name.
        local descendants = workspace:GetDescendants()
        for _, instance in ipairs(descendants) do
            local normalizedName = string.lower(string.gsub(instance.Name, "%s+", ""))
            if normalizedName == "mobs" and instance:IsA("Folder") then
                return instance
            end
        end

        -- Support common alternate names when the mob container is not called
        -- exactly "Mobs" in the live Studio hierarchy.
        local alternateNames = {
            mob = true,
            enemies = true,
            enemy = true,
            monsters = true,
        }
        for _, instance in ipairs(descendants) do
            local normalizedName = string.lower(string.gsub(instance.Name, "%s+", ""))
            if alternateNames[normalizedName] and instance:IsA("Folder") then
                return instance
            end
        end

        return nil
    end

    local function workspaceChildSummary()
        local names = {}
        for _, child in ipairs(workspace:GetChildren()) do
            table.insert(names, child.Name)
            if #names >= 6 then
                break
            end
        end

        if #names == 0 then
            return "Workspace is empty."
        end

        local suffix = #workspace:GetChildren() > #names and ", ..." or ""
        return "Workspace contains: " .. table.concat(names, ", ") .. suffix
    end

    local function refreshMobs()
        local mobsFolder = findMobsFolder()
        if not mobsFolder then
            if not stickyEnabled then
                statusLabel:SetText("No mob container found. " .. workspaceChildSummary())
            end
            table.clear(mobByLabel)
            table.clear(mobByKey)
            selectedMobLabel = nil
            if #previousItems > 0 then
                previousItems = {}
                mobList:Refresh(previousItems)
            end
            return
        end

        local mobs = {}
        local foundPlaces = {}

        local function scanFolder(folder, parentPath, placeName, inheritedLevel, inheritedRebirth)
            local folderLevel = readValue(folder, "Level", false) or inheritedLevel
            local folderRebirth = readValue(folder, "Rebirth", false) or inheritedRebirth

            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Model") then
                    local level = readValue(child, "Level", true) or folderLevel
                    local rebirth = readValue(child, "Rebirth", true) or folderRebirth
                    local modelPath = parentPath == "" and child.Name or (parentPath .. "/" .. child.Name)
                    local modelPlace = placeName or "(root)"

                    local displayName = string.format(
                        "%s  |  Level: %s  |  Rebirth: %s",
                        modelPath,
                        level ~= nil and tostring(level) or "?",
                        rebirth ~= nil and tostring(rebirth) or "?"
                    )

                    table.insert(mobs, {
                        name = child.Name,
                        place = modelPlace,
                        key = modelPath,
                        path = modelPath,
                        level = tonumber(level),
                        displayName = displayName,
                        model = child,
                    })
                elseif child:IsA("Folder") then
                    local folderPath = parentPath == "" and child.Name or (parentPath .. "/" .. child.Name)
                    local childPlace = placeName or child.Name
                    if not placeName then
                        foundPlaces[childPlace] = true
                    end
                    scanFolder(child, folderPath, childPlace, folderLevel, folderRebirth)
                end
            end
        end

        scanFolder(mobsFolder, "", nil, nil, nil)

        local places = { "All places" }
        local placeNames = {}
        for placeName in pairs(foundPlaces) do
            table.insert(placeNames, placeName)
        end
        table.sort(placeNames, function(first, second)
            return string.lower(first) < string.lower(second)
        end)
        table.clear(placeByLabel)
        placeByLabel["All places"] = nil
        for _, placeName in ipairs(placeNames) do
            table.insert(places, placeName)
            placeByLabel[placeName] = placeName
        end
        if selectedPlaceName and not foundPlaces[selectedPlaceName] then
            selectedPlaceName = nil
        end
        if not listsMatch(previousPlaces, places) then
            previousPlaces = places
            placeList:Refresh(places)
        end

        table.sort(mobs, function(first, second)
            local firstLevel = first.level or math.huge
            local secondLevel = second.level or math.huge

            if firstLevel == secondLevel then
                if first.name ~= second.name then
                    return mobNamesBefore(first.name, second.name)
                end
                return first.path < second.path
            end
            return firstLevel < secondLevel
        end)

        local items = {}
        table.clear(mobByLabel)
        table.clear(mobByKey)
        for _, mob in ipairs(mobs) do
            local existing = mobByKey[mob.key]
            local existingHumanoid = existing and existing.model:FindFirstChildWhichIsA("Humanoid", true)
            local currentHumanoid = mob.model:FindFirstChildWhichIsA("Humanoid", true)
            local existingAlive = existingHumanoid == nil or existingHumanoid.Health > 0
            local currentAlive = currentHumanoid == nil or currentHumanoid.Health > 0
            if not existing or (not existingAlive and currentAlive) then
                mobByKey[mob.key] = mob
            end

            if not selectedPlaceName or mob.place == selectedPlaceName then
                table.insert(items, mob.displayName)
                mobByLabel[mob.displayName] = mob
            end
        end

        if selectedMobLabel and not mobByLabel[selectedMobLabel] then
            selectedMobLabel = nil
        end

        if not listsMatch(previousItems, items) then
            previousItems = items
            mobList:Refresh(items)
        end

        if not stickyEnabled then
            if #items == 0 then
                statusLabel:SetText("No enemy models found for the selected place in " .. mobsFolder:GetFullName())
            else
                statusLabel:SetText(string.format("Found %d enemy models in %s.", #items, mobsFolder:GetFullName()))
            end
        end
    end

    local function getMobTargetPart(mob)
        return mob and (
            mob:FindFirstChild("HumanoidRootPart", true)
            or mob:FindFirstChildWhichIsA("BasePart", true)
        )
    end

    local function mobIsAlive(mob)
        if not mob or not mob.Parent then
            return false
        end

        local humanoid = mob:FindFirstChildWhichIsA("Humanoid", true)
        if humanoid and humanoid.Health <= 0 then
            return false
        end

        local health = mob:GetAttribute("Health")
        if type(health) == "number" and health <= 0 then
            return false
        end

        local healthValue = readValue(mob, "Health", true)
        return type(healthValue) ~= "number" or healthValue > 0
    end

    local function setStatus(message)
        if message ~= stickyStatus then
            stickyStatus = message
            statusLabel:SetText(message)
        end
    end

    local function releaseFreeze()
        if frozenRoot and frozenRoot.Parent and frozenRootWasAnchored ~= nil then
            frozenRoot.Anchored = frozenRootWasAnchored
        end
        frozenRoot = nil
        frozenRootWasAnchored = nil
    end

    local function restoreAutoRotate()
        if autoRotateHumanoid and autoRotateHumanoid.Parent and originalAutoRotate ~= nil then
            autoRotateHumanoid.AutoRotate = originalAutoRotate
        end
        autoRotateHumanoid = nil
        originalAutoRotate = nil
    end

    local function freezeInPlace(root)
        if frozenRoot == root then
            return
        end

        releaseFreeze()
        frozenRoot = root
        frozenRootWasAnchored = root.Anchored
        root.Anchored = true
    end

    local function runStickyAutofarm(token)
        local localPlayer = players.LocalPlayer

        while context.Alive and stickyEnabled and token == stickyWorkerToken do
            local mob = selectedMobKey and mobByKey[selectedMobKey]
            local character = localPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if not selectedMobKey then
                releaseFreeze()
                setStatus("Walk autofarm: select a mob to begin.")
                task.wait(0.2)
            elseif not root or not humanoid or humanoid.Health <= 0 then
                releaseFreeze()
                setStatus("Walk autofarm: waiting for your character.")
                task.wait(0.2)
            elseif not mobIsAlive(mob) then
                freezeInPlace(root)
                setStatus("Walk autofarm: holding position until " .. selectedMobKey .. " respawns.")
                task.wait(0.2)
            else
                releaseFreeze()

                if autoRotateHumanoid ~= humanoid then
                    restoreAutoRotate()
                    autoRotateHumanoid = humanoid
                    originalAutoRotate = humanoid.AutoRotate
                    humanoid.AutoRotate = false
                end

                local targetPart = getMobTargetPart(mob.model)
                if not targetPart then
                    setStatus("Walk autofarm: selected mob has no target part.")
                    task.wait(0.2)
                else
                    local destination = targetPart.CFrame
                        * CFrame.new(stickySide, stickyHeight, stickyDepth)
                        * CFrame.Angles(
                            math.rad(stickyRotationX),
                            math.rad(stickyRotationY),
                            math.rad(stickyRotationZ)
                        )
                    setStatus("Walk autofarm: pathing into " .. mob.path .. ".")

                    local path = pathfindingService:CreatePath({ AgentCanJump = true })
                    local computed = pcall(function()
                        path:ComputeAsync(root.Position, destination.Position)
                    end)

                    if computed and path.Status == Enum.PathStatus.Success then
                        for _, waypoint in ipairs(path:GetWaypoints()) do
                            if not context.Alive or not stickyEnabled or token ~= stickyWorkerToken then
                                break
                            end

                            local currentMob = selectedMobKey and mobByKey[selectedMobKey]
                            if not mobIsAlive(currentMob and currentMob.model) then
                                break
                            end

                            if waypoint.Action == Enum.PathWaypointAction.Jump then
                                humanoid.Jump = true
                            end

                            local look = destination.Rotation
                            root.CFrame = CFrame.new(root.Position) * look
                            humanoid:MoveTo(waypoint.Position)

                            local moveFinished = false
                            local reached = false
                            local finishedConnection = humanoid.MoveToFinished:Connect(function(success)
                                moveFinished = true
                                reached = success
                            end)
                            local deadline = os.clock() + 3
                            while context.Alive
                                and stickyEnabled
                                and token == stickyWorkerToken
                                and os.clock() < deadline
                                and not moveFinished
                            do
                                local latestMob = selectedMobKey and mobByKey[selectedMobKey]
                                if not mobIsAlive(latestMob and latestMob.model) then
                                    break
                                end
                                task.wait(0.05)
                            end
                            finishedConnection:Disconnect()

                            if not reached then
                                break
                            end
                        end
                        task.wait(0.25)
                    else
                        setStatus("Walk autofarm: no path to " .. mob.path .. ".")
                        task.wait(0.4)
                    end
                end
            end
        end

        releaseFreeze()
        if not stickyEnabled or not context.Alive then
            restoreAutoRotate()
        end
    end

    section:Toggle({
        Name = "Walk into selected mob (toggle)",
        Flag = "LegendarySwordStickyMobFollow",
        Default = false,
        Callback = function(enabled)
            stickyEnabled = enabled
            stickyWorkerToken = stickyWorkerToken + 1
            stickyStatus = nil
            if enabled then
                task.spawn(runStickyAutofarm, stickyWorkerToken)
            else
                releaseFreeze()
                restoreAutoRotate()
                local character = players.LocalPlayer.Character
                local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                local root = character and character:FindFirstChild("HumanoidRootPart")
                if humanoid and root then
                    humanoid:MoveTo(root.Position)
                end
                statusLabel:SetText("Walk autofarm: stopped.")
            end
        end,
    })

    section:Slider({
        Name = "Sticky front/back offset (+ behind)",
        Flag = "LegendarySwordStickyDepth",
        Default = stickyDepth,
        Min = -12,
        Max = 12,
        Decimals = 0.5,
        Suffix = " studs",
        Callback = function(value)
            if type(value) == "number" and value == value then
                stickyDepth = math.clamp(value, -12, 12)
            end
        end,
    })

    section:Slider({
        Name = "Sticky up/down offset (+ up)",
        Flag = "LegendarySwordStickyHeight",
        Default = stickyHeight,
        Min = -12,
        Max = 12,
        Decimals = 0.5,
        Suffix = " studs",
        Callback = function(value)
            if type(value) == "number" and value == value then
                stickyHeight = math.clamp(value, -12, 12)
            end
        end,
    })

    section:Slider({
        Name = "Sticky left/right offset (+ right)",
        Flag = "LegendarySwordStickySide",
        Default = stickySide,
        Min = -12,
        Max = 12,
        Decimals = 0.5,
        Suffix = " studs",
        Callback = function(value)
            if type(value) == "number" and value == value then
                stickySide = math.clamp(value, -12, 12)
            end
        end,
    })

    for _, axis in ipairs({ "X", "Y", "Z" }) do
        local rotationAxis = axis
        section:Slider({
            Name = "Sticky rotation " .. rotationAxis,
            Flag = "LegendarySwordStickyRotation" .. rotationAxis,
            Default = 0,
            Min = -180,
            Max = 180,
            Decimals = 5,
            Suffix = "°",
            Callback = function(value)
                if type(value) ~= "number" or value ~= value then
                    return
                end

                value = math.clamp(value, -180, 180)
                if rotationAxis == "X" then
                    stickyRotationX = value
                elseif rotationAxis == "Y" then
                    stickyRotationY = value
                else
                    stickyRotationZ = value
                end
            end,
        })
    end

    context.Connect(runService.Heartbeat, function(deltaTime)
        elapsed = elapsed + deltaTime
        if elapsed < 1 then
            return
        end

        elapsed = elapsed % 1
        refreshMobs()
    end)

    refreshMobs()
end
