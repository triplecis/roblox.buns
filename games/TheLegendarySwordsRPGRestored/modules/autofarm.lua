-- Read nested enemy models and their Level/Rebirth values from a Mobs folder.
return function(context)
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local section = context.Sections.Autofarm
    local statusLabel = section:Label("Searching Workspace for a Mobs folder...")
    local mobByLabel = {}
    local mobByKey = {}
    local selectedMobKeys = {}
    local selectedMobOrder = {}
    local selectedPlaces = {}
    local placeByLabel = {}
    local stickyEnabled = false
    local stickyStatus = nil
    local stickyTargetKey = nil
    local stickyTargetIndex = 0
    local frozenRoot = nil
    local frozenRootWasAnchored = nil
    local stickyDepth = 2
    local stickySide = 0
    local stickyHeight = 0
    local stickyRotationX = 0
    local stickyRotationY = 0
    local stickyRotationZ = 0

    local function selectionItems(selection)
        if type(selection) == "table" then
            return selection
        end
        if type(selection) == "string" then
            return { selection }
        end
        return {}
    end

    section:Label("Mob places (select none for all)")
    local placeList = section:Listbox({
        Flag = "LegendarySwordMobPlaces",
        Items = {},
        Multi = true,
        Callback = function(selection)
            table.clear(selectedPlaces)
            for _, label in ipairs(selectionItems(selection)) do
                local placeName = placeByLabel[label]
                if placeName then
                    selectedPlaces[placeName] = true
                end
            end
            stickyStatus = nil
        end,
    })
    section:Label("Mobs (select one or more targets)")
    local mobList = section:Listbox({
        Flag = "LegendarySwordMobs",
        Items = {},
        Multi = true,
        Callback = function(selection)
            local retainedOrder = {}
            if next(selectedPlaces) ~= nil then
                for _, key in ipairs(selectedMobOrder) do
                    local mob = mobByKey[key]
                    local keyPlace = mob and mob.place or string.match(key, "^([^/]+)")
                    if not selectedPlaces[keyPlace] then
                        table.insert(retainedOrder, key)
                    end
                end
            end

            table.clear(selectedMobKeys)
            table.clear(selectedMobOrder)
            for _, key in ipairs(retainedOrder) do
                selectedMobKeys[key] = true
                table.insert(selectedMobOrder, key)
            end
            for _, label in ipairs(selectionItems(selection)) do
                local selectedMob = mobByLabel[label]
                if selectedMob and not selectedMobKeys[selectedMob.key] then
                    selectedMobKeys[selectedMob.key] = true
                    table.insert(selectedMobOrder, selectedMob.key)
                end
            end
            stickyStatus = nil
        end,
    })

    local elapsed = 0
    local previousItems = {}
    local previousPlaces = {}

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
            if #previousItems > 0 then
                previousItems = {}
                local retainedPlaces = table.clone(selectedPlaces)
                local retainedKeys = table.clone(selectedMobKeys)
                local retainedOrder = table.clone(selectedMobOrder)
                mobList:Refresh(previousItems)
                mobList:Set({})
                table.clear(selectedMobKeys)
                for key in pairs(retainedKeys) do
                    selectedMobKeys[key] = true
                end
                table.clear(selectedMobOrder)
                for _, key in ipairs(retainedOrder) do
                    table.insert(selectedMobOrder, key)
                end
                table.clear(selectedPlaces)
                for placeName in pairs(retainedPlaces) do
                    selectedPlaces[placeName] = true
                end
            end
            if #previousPlaces > 0 then
                previousPlaces = {}
                local retainedPlaces = table.clone(selectedPlaces)
                placeList:Refresh(previousPlaces)
                placeList:Set({})
                table.clear(selectedPlaces)
                for placeName in pairs(retainedPlaces) do
                    selectedPlaces[placeName] = true
                end
            end
            table.clear(placeByLabel)
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

        local places = {}
        local placeNames = {}
        local hasRootMobs = false
        for placeName in pairs(foundPlaces) do
            table.insert(placeNames, placeName)
        end
        for _, mob in ipairs(mobs) do
            if mob.place == "(root)" then
                hasRootMobs = true
                break
            end
        end
        if hasRootMobs then
            table.insert(placeNames, "(root)")
        end
        table.sort(placeNames, function(first, second)
            return string.lower(first) < string.lower(second)
        end)
        table.clear(placeByLabel)
        for _, placeName in ipairs(placeNames) do
            table.insert(places, placeName)
            placeByLabel[placeName] = placeName
        end
        if not listsMatch(previousPlaces, places) then
            local retainedPlaces = table.clone(selectedPlaces)
            previousPlaces = places
            placeList:Refresh(places)
            local desiredSelection = {}
            for _, placeName in ipairs(places) do
                if retainedPlaces[placeName] then
                    table.insert(desiredSelection, placeName)
                end
            end
            placeList:Set(desiredSelection)
            -- Refresh/Set may invoke the selection callback. Keep selections
            -- for places that are temporarily absent so detection can recover.
            table.clear(selectedPlaces)
            for placeName in pairs(retainedPlaces) do
                selectedPlaces[placeName] = true
            end
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
        local function isModelAlive(model)
            local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
            if humanoid and humanoid.Health <= 0 then
                return false
            end

            local health = model:GetAttribute("Health")
            if type(health) == "number" and health <= 0 then
                return false
            end

            local healthValue = readValue(model, "Health", true)
            return type(healthValue) ~= "number" or healthValue > 0
        end

        for _, mob in ipairs(mobs) do
            local existing = mobByKey[mob.key]
            local existingAlive = existing and isModelAlive(existing.model)
            local currentAlive = isModelAlive(mob.model)
            if not existing or (not existingAlive and currentAlive) then
                mobByKey[mob.key] = mob
            end
        end

        local addedKeys = {}
        for _, mob in ipairs(mobs) do
            local selectedMob = mobByKey[mob.key]
            if not addedKeys[mob.key]
                and selectedMob
                and (next(selectedPlaces) == nil or selectedPlaces[selectedMob.place])
            then
                addedKeys[mob.key] = true
                table.insert(items, selectedMob.displayName)
                mobByLabel[selectedMob.displayName] = selectedMob
            end
        end

        if not listsMatch(previousItems, items) then
            local retainedKeys = table.clone(selectedMobKeys)
            local retainedOrder = table.clone(selectedMobOrder)
            previousItems = items
            mobList:Refresh(items)
            local desiredSelection = {}
            for _, label in ipairs(items) do
                local mob = mobByLabel[label]
                if mob and retainedKeys[mob.key] then
                    table.insert(desiredSelection, label)
                end
            end
            mobList:Set(desiredSelection)

            -- Keep temporarily filtered or despawned targets registered. They
            -- can reappear after changing the place filter or after respawn.
            table.clear(selectedMobKeys)
            for key in pairs(retainedKeys) do
                selectedMobKeys[key] = true
            end
            table.clear(selectedMobOrder)
            for _, key in ipairs(retainedOrder) do
                table.insert(selectedMobOrder, key)
            end
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

    local function freezeInPlace(root)
        if frozenRoot == root then
            return
        end

        releaseFreeze()
        frozenRoot = root
        frozenRootWasAnchored = root.Anchored
        root.Anchored = true
    end

    local function getSelectedLiveMob()
        local selectedCount = #selectedMobOrder
        if selectedCount == 0 then
            stickyTargetKey = nil
            stickyTargetIndex = 0
            return nil
        end

        local function getEligibleMob(index)
            local key = selectedMobOrder[index]
            local mob = mobByKey[key]
            local isPlaceSelected = next(selectedPlaces) == nil or (mob and selectedPlaces[mob.place])
            if selectedMobKeys[key]
                and isPlaceSelected
                and mobIsAlive(mob and mob.model)
                and getMobTargetPart(mob.model)
            then
                return mob, key
            end
            return nil
        end

        for index, key in ipairs(selectedMobOrder) do
            if key == stickyTargetKey then
                local activeMob = getEligibleMob(index)
                if activeMob then
                    stickyTargetIndex = index
                    return activeMob
                end
                break
            end
        end

        for offset = 1, selectedCount do
            local index = ((stickyTargetIndex + offset - 1) % selectedCount) + 1
            local mob, key = getEligibleMob(index)
            if mob then
                stickyTargetKey = key
                stickyTargetIndex = index
                return mob
            end
        end
        return nil
    end

    section:Toggle({
        Name = "Sticky autofarm",
        Flag = "LegendarySwordStickyMobFollow",
        Default = false,
        Callback = function(enabled)
            stickyEnabled = enabled
            stickyStatus = nil
            if not enabled then
                releaseFreeze()
                statusLabel:SetText("Sticky autofarm: stopped.")
            else
                statusLabel:SetText("Sticky autofarm: select one or more mobs to begin.")
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
        if stickyEnabled then
            local character = players.LocalPlayer.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local selectedMob = getSelectedLiveMob()

            if not root or not humanoid or humanoid.Health <= 0 then
                releaseFreeze()
                setStatus("Sticky autofarm: waiting for your character.")
            elseif #selectedMobOrder == 0 then
                releaseFreeze()
                setStatus("Sticky autofarm: select one or more mobs to begin.")
            elseif not selectedMob then
                freezeInPlace(root)
                setStatus("Sticky autofarm: holding position until a selected mob respawns.")
            else
                releaseFreeze()
                local targetPart = getMobTargetPart(selectedMob.model)
                if not targetPart then
                    setStatus("Sticky autofarm: " .. selectedMob.path .. " has no target part.")
                else
                    local pivotOffset = root.CFrame:ToObjectSpace(character:GetPivot())
                    local stickyTarget = targetPart.CFrame
                        * CFrame.new(stickySide, stickyHeight, stickyDepth)
                        * CFrame.Angles(
                            math.rad(stickyRotationX),
                            math.rad(stickyRotationY),
                            math.rad(stickyRotationZ)
                        )
                    local moved = pcall(function()
                        character:PivotTo(stickyTarget * pivotOffset)
                    end)
                    setStatus(moved
                        and ("Sticky autofarm: following " .. selectedMob.path .. ".")
                        or ("Sticky autofarm: could not follow " .. selectedMob.path .. "."))
                end
            end
        end

        elapsed = elapsed + deltaTime
        if elapsed < 1 then
            return
        end

        elapsed = elapsed % 1
        refreshMobs()
    end)

    refreshMobs()
end
