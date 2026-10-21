-- Read nested enemy models and their Level/Rebirth values from a Mobs folder.
return function(context)
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local pathfindingService = game:GetService("PathfindingService")
    local section = context.Sections.Autofarm
    local statusLabel = section:Label("Searching Workspace for a Mobs folder...")
    local selectedMobLabel = nil
    local mobByLabel = {}
    local stickyEnabled = false
    local stickyStatus = nil
    local mobList = section:Listbox({
        Flag = "LegendarySwordMobs",
        Items = {},
        Multi = false,
        Callback = function(selection)
            if type(selection) == "table" then
                selection = selection[1]
            end
            selectedMobLabel = selection
        end,
    })

    local elapsed = 0
    local previousItems = {}

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
            statusLabel:SetText("No mob container found. " .. workspaceChildSummary())
            table.clear(mobByLabel)
            selectedMobLabel = nil
            if #previousItems > 0 then
                previousItems = {}
                mobList:Refresh(previousItems)
            end
            return
        end

        local mobs = {}

        local function scanFolder(folder, parentPath, inheritedLevel, inheritedRebirth)
            local folderLevel = readValue(folder, "Level", false) or inheritedLevel
            local folderRebirth = readValue(folder, "Rebirth", false) or inheritedRebirth

            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA("Model") then
                    local level = readValue(child, "Level", true) or folderLevel
                    local rebirth = readValue(child, "Rebirth", true) or folderRebirth
                    local modelPath = parentPath .. "/" .. child.Name

                    local displayName = string.format(
                        "%s  |  Level: %s  |  Rebirth: %s",
                        modelPath,
                        level ~= nil and tostring(level) or "?",
                        rebirth ~= nil and tostring(rebirth) or "?"
                    )

                    table.insert(mobs, {
                        name = child.Name,
                        path = modelPath,
                        level = tonumber(level),
                        displayName = displayName,
                        model = child,
                    })
                elseif child:IsA("Folder") then
                    local folderPath = parentPath .. "/" .. child.Name
                    scanFolder(child, folderPath, folderLevel, folderRebirth)
                end
            end
        end

        scanFolder(mobsFolder, mobsFolder.Name, nil, nil)

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
        for _, mob in ipairs(mobs) do
            table.insert(items, mob.displayName)
            mobByLabel[mob.displayName] = mob.model
        end

        if selectedMobLabel and not mobByLabel[selectedMobLabel] then
            selectedMobLabel = nil
        end

        if not listsMatch(previousItems, items) then
            previousItems = items
            mobList:Refresh(items)
        end

        if #items == 0 then
            statusLabel:SetText("Mob container found, but it has no enemy models: " .. mobsFolder:GetFullName())
        else
            statusLabel:SetText(string.format("Found %d enemy models in %s.", #items, mobsFolder:GetFullName()))
        end
    end

    local function getMobTargetPart(mob)
        return mob and (
            mob:FindFirstChild("HumanoidRootPart", true)
            or mob:FindFirstChildWhichIsA("BasePart", true)
        )
    end

    section:Toggle({
        Name = "Sticky farm selected mob",
        Flag = "LegendarySwordStickyMobFollow",
        Default = false,
        Callback = function(enabled)
            stickyEnabled = enabled
            stickyStatus = nil
            statusLabel:SetText(enabled
                and "Sticky placement: select a mob to stay 2 studs behind it."
                or "Sticky placement: stopped.")
        end,
    })

    section:Button({
        Name = "Walk into selected mob",
        Callback = function()
            local mob = selectedMobLabel and mobByLabel[selectedMobLabel]
            local character = players.LocalPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if not mob or not mob.Parent then
                context.Notify("Autofarm test", "Select a detected mob first.", 3)
                return
            end

            if not humanoid or humanoid.Health <= 0 then
                context.Notify("Autofarm test", "Your character is not alive.", 3)
                return
            end

            local targetPart = getMobTargetPart(mob)
            if not targetPart then
                context.Notify("Autofarm test", "The selected mob has no target part.", 3)
                return
            end

            local targetName = mob.Name
            task.spawn(function()
                local path = pathfindingService:CreatePath({
                    AgentCanJump = true,
                })

                local computed = pcall(function()
                    path:ComputeAsync(character:GetPivot().Position, targetPart.Position)
                end)

                if not computed or path.Status ~= Enum.PathStatus.Success then
                    if context.Alive then
                        statusLabel:SetText("No path found to " .. targetName .. ".")
                    end
                    return
                end

                local reached = true
                for _, waypoint in ipairs(path:GetWaypoints()) do
                    if not context.Alive or players.LocalPlayer.Character ~= character then
                        return
                    end

                    if waypoint.Action == Enum.PathWaypointAction.Jump then
                        humanoid.Jump = true
                    end

                    humanoid:MoveTo(waypoint.Position)
                    reached = humanoid.MoveToFinished:Wait()
                    if not reached then
                        break
                    end
                end

                if not context.Alive then
                    return
                end

                if reached then
                    statusLabel:SetText("Reached " .. targetName .. " using pathfinding.")
                else
                    statusLabel:SetText("Path to " .. targetName .. " was blocked.")
                end
            end)
        end,
    })

    context.Connect(runService.Heartbeat, function(deltaTime)
        if stickyEnabled then
            local mob = selectedMobLabel and mobByLabel[selectedMobLabel]
            local character = players.LocalPlayer.Character
            local characterRoot = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local targetPart = getMobTargetPart(mob)
            local message

            if not mob or not mob.Parent then
                message = "Sticky placement: select a detected mob."
            elseif not characterRoot or not humanoid or humanoid.Health <= 0 then
                message = "Sticky placement: waiting for your character."
            elseif not targetPart then
                message = "Sticky placement: selected mob has no target part."
            else
                message = "Sticky placement: 2 studs behind " .. mob.Name .. "."
                local pivotOffset = characterRoot.CFrame:ToObjectSpace(character:GetPivot())
                pcall(function()
                    local behindMob = targetPart.CFrame * CFrame.new(0, 0, 2)
                    character:PivotTo(behindMob * pivotOffset)
                end)
            end

            if message ~= stickyStatus then
                stickyStatus = message
                statusLabel:SetText(message)
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
