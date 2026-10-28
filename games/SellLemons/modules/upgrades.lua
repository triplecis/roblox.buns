-- Find Upgrade RemoteFunctions under the local player's purchasable tycoon folders.
return function(context)
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local section = context.Sections.Upgrades
    local status = section:Label("Searching your tycoon for Upgrade RemoteFunctions...")

    local selectedPath
    local previousPaths = {}
    local remoteByPath = {}
    local elapsed = 0

    local upgradeList = section:Listbox({
        Name = "Upgrade location",
        Flag = "SellLemonsUpgradeLocations",
        Items = {},
        Multi = false,
        Callback = function(selection)
            if type(selection) == "table" then
                selection = selection[1]
            end
            selectedPath = selection
        end,
    })

    local function findLocalTycoon()
        local localPlayer = context.Player or players.LocalPlayer
        if not localPlayer then
            return nil
        end

        for index = 1, 10 do
            local tycoon = workspace:FindFirstChild("Tycoon" .. index)
            local owner = tycoon and tycoon:FindFirstChild("Owner")
            if tycoon
                and tycoon:IsA("Folder")
                and owner
                and owner:IsA("ObjectValue")
                and owner.Value == localPlayer
            then
                return tycoon
            end
        end

        return nil
    end

    local function collectUpgradeRemotes(purchases)
        local found = {}

        local function visit(folder, parentPath)
            for _, child in ipairs(folder:GetChildren()) do
                local path = table.clone(parentPath)
                table.insert(path, child.Name)

                if child.Name == "Upgrade" and child:IsA("RemoteFunction") then
                    local label = table.concat(path, ".")
                    found[label] = child
                end

                if child:IsA("Folder") then
                    visit(child, path)
                end
            end
        end

        visit(purchases, { "Purchases" })
        return found
    end

    local function refresh()
        local tycoon = findLocalTycoon()
        local purchases = tycoon and tycoon:FindFirstChild("Purchases")
        if not purchases or not purchases:IsA("Folder") then
            table.clear(remoteByPath)
            if #previousPaths > 0 then
                previousPaths = {}
                upgradeList:Refresh(previousPaths)
                upgradeList:Set({})
            end
            selectedPath = nil
            status:SetText(tycoon and "Your tycoon has no Purchases folder." or "Couldn't find your owned Tycoon1–Tycoon10.")
            return
        end

        local found = collectUpgradeRemotes(purchases)
        local paths = {}
        for path in pairs(found) do
            table.insert(paths, path)
        end
        table.sort(paths)

        table.clear(remoteByPath)
        for path, remote in pairs(found) do
            remoteByPath[path] = remote
        end

        local changed = #paths ~= #previousPaths
        if not changed then
            for index, path in ipairs(paths) do
                if path ~= previousPaths[index] then
                    changed = true
                    break
                end
            end
        end

        if changed then
            local retainedSelection = selectedPath
            previousPaths = paths
            upgradeList:Refresh(paths)
            if retainedSelection and remoteByPath[retainedSelection] then
                upgradeList:Set({ retainedSelection })
                selectedPath = retainedSelection
            else
                upgradeList:Set({})
                selectedPath = nil
            end
        end

        status:SetText(string.format(
            "Found %d Upgrade RemoteFunction(s) in %s.Purchases.",
            #paths,
            tycoon.Name
        ))
    end

    section:Button({
        Name = "Invoke selected Upgrade",
        Callback = function()
            refresh()
            local remote = selectedPath and remoteByPath[selectedPath]
            if not remote or not remote:IsA("RemoteFunction") then
                status:SetText("Select a detected Upgrade RemoteFunction first.")
                return
            end

            local succeeded, result = pcall(function()
                return remote:InvokeServer(1)
            end)
            if not succeeded then
                status:SetText("Upgrade request failed: " .. tostring(result))
            elseif result == false then
                status:SetText("The server rejected the upgrade request.")
            else
                status:SetText("Invoked " .. selectedPath .. " with 1.")
            end
        end,
    })

    context.Connect(runService.Heartbeat, function(deltaTime)
        elapsed += deltaTime
        if elapsed >= 0.5 then
            elapsed %= 0.5
            refresh()
        end
    end)

    refresh()
end
