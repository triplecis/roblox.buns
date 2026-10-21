-- Detect level doors and shops, and let the user move to a selected shop.
return function(context)
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local section = context.Sections.Teleports

    section:Label("Level doors")
    local doorStatus = section:Label("Searching for workspace.LevelDoors...")
    local doorList = section:Listbox({
        Flag = "LegendarySwordLevelDoors",
        Items = {},
        Multi = false,
        Callback = function() end,
    })

    section:Label("Shops")
    local shopStatus = section:Label("Searching for workspace.Shops...")
    local shopList = section:Listbox({
        Flag = "LegendarySwordShops",
        Items = {},
        Multi = false,
        Callback = function(selectedShop)
            if type(selectedShop) == "table" then
                selectedShop = selectedShop[1]
            end
            context.SelectedShop = selectedShop
        end,
    })

    local elapsed = 0
    local previousDoors = {}
    local previousShops = {}
    local shopByLabel = {}

    local function requiredLevel(name)
        local lowerName = string.lower(name)
        local levelText = string.match(lowerName, "lvl%s*(%d+)")
            or string.match(lowerName, "level%s*(%d+)")

        return tonumber(levelText)
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

    local function refreshDoors()
        local doorsFolder = workspace:FindFirstChild("LevelDoors")
        if not doorsFolder then
            doorStatus:SetText("workspace.LevelDoors was not found.")
            if #previousDoors > 0 then
                previousDoors = {}
                doorList:Refresh(previousDoors)
            end
            return
        end

        local doors = {}
        for _, door in ipairs(doorsFolder:GetChildren()) do
            local level = requiredLevel(door.Name)
            if level then
                table.insert(doors, { name = door.Name, level = level })
            end
        end

        table.sort(doors, function(first, second)
            if first.level == second.level then
                return first.name < second.name
            end
            return first.level < second.level
        end)

        local doorNames = {}
        for _, door in ipairs(doors) do
            table.insert(doorNames, string.format("Level %d+  |  %s", door.level, door.name))
        end

        if not listsMatch(previousDoors, doorNames) then
            previousDoors = doorNames
            doorList:Refresh(doorNames)
        end

        doorStatus:SetText(string.format("Found %d level doors (lowest level first).", #doorNames))
    end

    local function shopPivot(shop)
        if shop:IsA("Model") then
            return shop:GetPivot()
        end

        if shop:IsA("BasePart") then
            return shop.CFrame
        end

        local model = shop:FindFirstChildWhichIsA("Model", true)
        if model then
            return model:GetPivot()
        end

        local part = shop:FindFirstChildWhichIsA("BasePart", true)
        return part and part.CFrame
    end

    local function refreshShops()
        local shopsFolder = workspace:FindFirstChild("Shops")
        if not shopsFolder then
            shopStatus:SetText("workspace.Shops was not found.")
            table.clear(shopByLabel)

            if #previousShops > 0 then
                previousShops = {}
                shopList:Refresh(previousShops)
            end
            context.SelectedShop = nil
            return
        end

        local shops = {}
        for _, shop in ipairs(shopsFolder:GetChildren()) do
            if shopPivot(shop) then
                table.insert(shops, {
                    label = shop:GetFullName(),
                    instance = shop,
                })
            end
        end

        table.sort(shops, function(first, second)
            return first.label < second.label
        end)

        local shopLabels = {}
        table.clear(shopByLabel)
        for _, shop in ipairs(shops) do
            table.insert(shopLabels, shop.label)
            shopByLabel[shop.label] = shop.instance
        end

        if not listsMatch(previousShops, shopLabels) then
            previousShops = shopLabels
            shopList:Refresh(shopLabels)
        end

        if context.SelectedShop and not shopByLabel[context.SelectedShop] then
            context.SelectedShop = nil
        end

        shopStatus:SetText(string.format("Found %d shops.", #shopLabels))
    end

    section:Button({
        Name = "Teleport to selected shop",
        Callback = function()
            local shop = context.SelectedShop and shopByLabel[context.SelectedShop]
            local destination = shop and shopPivot(shop)
            local character = players.LocalPlayer.Character

            if not destination then
                context.Notify("Shop teleport", "Select a detected shop first.", 3)
                return
            end

            if not character then
                context.Notify("Shop teleport", "Your character is not available.", 3)
                return
            end

            character:PivotTo(destination + Vector3.new(0, 4, 0))
            context.Notify("Shop teleport", "Moved to " .. shop.Name .. ".", 3)
        end,
    })

    context.Connect(runService.Heartbeat, function(deltaTime)
        elapsed = elapsed + deltaTime
        if elapsed < 1 then
            return
        end

        elapsed = elapsed % 1
        refreshDoors()
        refreshShops()
    end)

    refreshDoors()
    refreshShops()
end
