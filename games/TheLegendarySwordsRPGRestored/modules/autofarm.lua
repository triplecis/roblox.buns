-- Read nested enemy models and their Level/Rebirth values from a Mobs folder.
return function(context)
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local section = context.Sections.Autofarm
    local statusLabel = section:Label("Searching Workspace for a Mobs folder...")
    local selectedMobLabel = nil
    local mobByLabel = {}
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
        local valueObject = container:FindFirstChild(valueName, searchDescendants)
        if valueObject and valueObject:IsA("ValueBase") then
            return valueObject.Value
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

        -- Some maps place the Mobs folder under a location or map container.
        return workspace:FindFirstChild("Mobs", true)
    end

    local function refreshMobs()
        local mobsFolder = findMobsFolder()
        if not mobsFolder then
            statusLabel:SetText("No Mobs folder found in Workspace.")
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

        statusLabel:SetText(string.format("Found %d enemy models.", #items))
    end

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

            local targetPart = mob:FindFirstChild("HumanoidRootPart", true)
                or mob:FindFirstChildWhichIsA("BasePart", true)
            if not targetPart then
                context.Notify("Autofarm test", "The selected mob has no target part.", 3)
                return
            end

            local targetName = mob.Name
            task.spawn(function()
                humanoid:MoveTo(targetPart.Position)
                local reached = humanoid.MoveToFinished:Wait()

                if not context.Alive then
                    return
                end

                if reached then
                    statusLabel:SetText("Reached " .. targetName .. "; checking contact behavior.")
                else
                    statusLabel:SetText("Could not reach " .. targetName .. ".")
                end
            end)
        end,
    })

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
