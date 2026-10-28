-- Read resource names from ReplicatedStorage and keep the RC2 pages up to date.
return function(context)
    local replicatedStorage = game:GetService("ReplicatedStorage")
    local runService = game:GetService("RunService")

    context.CatalogListeners = {}

    local refreshTimer = 0
    local lastListenerErrors = {}

    -- Return sorted, unique child names from a folder.
    local function getNames(folder, excludeBushes)
        local names = {}
        local seenNames = {}

        if not folder then
            return names
        end

        for _, child in ipairs(folder:GetChildren()) do
            local name = child.Name
            local isBush = string.find(string.lower(name), "bush", 1, true) ~= nil

            if name ~= "" and not seenNames[name] and not (excludeBushes and isBush) then
                seenNames[name] = true
                table.insert(names, name)
            end
        end

        table.sort(names)
        return names
    end

    local function catalogsMatch(firstCatalog, secondCatalog)
        if not firstCatalog then
            return false
        end

        for category, newNames in pairs(secondCatalog) do
            local oldNames = firstCatalog[category]
            if not oldNames or #oldNames ~= #newNames then
                return false
            end

            for index, name in ipairs(newNames) do
                if oldNames[index] ~= name then
                    return false
                end
            end
        end

        return true
    end

    local function buildCatalog()
        local contentFolder = replicatedStorage:FindFirstChild("Content")

        local function findContentFolder(name)
            return contentFolder and contentFolder:FindFirstChild(name)
        end

        local itemsFolder = findContentFolder("Items")
        local fishFolder = findContentFolder("BigFish")
        local fishNames = {}

        -- A fish is usable when both its template and item definition exist.
        for _, fishName in ipairs(getNames(fishFolder, true)) do
            if itemsFolder and itemsFolder:FindFirstChild(fishName) then
                table.insert(fishNames, fishName)
            end
        end

        return {
            Items = getNames(itemsFolder, false),
            Ores = getNames(findContentFolder("Ores"), true),
            Trees = getNames(findContentFolder("Trees"), true),
            Fishes = fishNames,
            Oils = getNames(findContentFolder("Oils"), true),
        }
    end

    local function notifyListeners(catalog)
        for _, listener in ipairs(context.CatalogListeners) do
            local succeeded, errorMessage = pcall(listener, catalog)

            if not succeeded and lastListenerErrors[listener] ~= tostring(errorMessage) then
                context.Notify("Catalog update failed", errorMessage, 3)
            end

            if succeeded then
                lastListenerErrors[listener] = nil
            else
                lastListenerErrors[listener] = tostring(errorMessage)
            end
        end
    end

    -- Publish only changed catalogs so UI lists do not refresh needlessly.
    function context.RefreshCatalog()
        if not context.Alive then
            return context.Catalog
        end

        local newCatalog = buildCatalog()
        if catalogsMatch(context.Catalog, newCatalog) then
            return context.Catalog
        end

        context.Catalog = newCatalog
        notifyListeners(newCatalog)
        return newCatalog
    end

    context.RefreshCatalog()

    -- Replication events trigger a refresh on the next Heartbeat interval.
    context.Connect(replicatedStorage.DescendantAdded, function()
        refreshTimer = 2
    end)

    context.Connect(replicatedStorage.DescendantRemoving, function()
        refreshTimer = 2
    end)

    context.Connect(runService.Heartbeat, function(deltaTime)
        refreshTimer = refreshTimer + deltaTime
        if refreshTimer < 2 then
            return
        end

        refreshTimer = refreshTimer % 2
        context.RefreshCatalog()
    end)

    context.AddCleanup(function()
        table.clear(context.CatalogListeners)
    end)
end
