-- Read enemy models and their Level/Rebirth values from workspace.Mobs.
return function(context)
    local runService = game:GetService("RunService")
    local section = context.Sections.Autofarm
    local statusLabel = section:Label("Searching for workspace.Mobs...")
    local mobList = section:Listbox({
        Flag = "LegendarySwordMobs",
        Items = {},
        Multi = false,
        Callback = function() end,
    })

    local elapsed = 0
    local previousItems = {}

    local function readValue(model, valueName)
        local valueObject = model:FindFirstChild(valueName, true)
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

    local function refreshMobs()
        local mobsFolder = workspace:FindFirstChild("Mobs")
        if not mobsFolder then
            statusLabel:SetText("workspace.Mobs was not found.")
            if #previousItems > 0 then
                previousItems = {}
                mobList:Refresh(previousItems)
            end
            return
        end

        local mobs = {}
        for _, mob in ipairs(mobsFolder:GetChildren()) do
            if mob:IsA("Model") then
                local level = readValue(mob, "Level")
                local rebirth = readValue(mob, "Rebirth")

                table.insert(mobs, {
                    name = mob.Name,
                    level = tonumber(level),
                    levelText = level ~= nil and tostring(level) or "?",
                    rebirthText = rebirth ~= nil and tostring(rebirth) or "?",
                })
            end
        end

        table.sort(mobs, function(first, second)
            local firstLevel = first.level or math.huge
            local secondLevel = second.level or math.huge

            if firstLevel == secondLevel then
                return first.name < second.name
            end
            return firstLevel < secondLevel
        end)

        local items = {}
        for _, mob in ipairs(mobs) do
            table.insert(items, string.format(
                "%s  |  Level: %s  |  Rebirth: %s",
                mob.name,
                mob.levelText,
                mob.rebirthText
            ))
        end

        if not listsMatch(previousItems, items) then
            previousItems = items
            mobList:Refresh(items)
        end

        statusLabel:SetText(string.format("Found %d enemy models.", #items))
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
