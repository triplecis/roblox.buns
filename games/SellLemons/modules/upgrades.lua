-- Discover upgrade remotes and E prompts under the local player's tycoon.
return function(context)
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local section = context.Sections.Upgrades

    local upgradeStatus = section:Label("Searching for Upgrade RemoteFunctions...")
    local purchaseStatus = section:Label("Searching for purchasable products...")

    local selectedUpgradePath
    local previousUpgradePaths = {}
    local upgradeByPath = {}

    local selectedCategory
    local selectedProducts = {}
    local previousProductLabels = {}
    local productByLabel = {}

    local purchaseLoopEnabled = false
    local purchaseWorkerId = 0
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
            selectedUpgradePath = selection
        end,
    })

    local buttonTypes = { "Structure", "Multiplier", "Other", "Decor", "Itself (Product)" }
    section:Listbox({
        Name = "Button type",
        Flag = "SellLemonsButtonType",
        Items = buttonTypes,
        Multi = false,
        Callback = function(selection)
            if type(selection) == "table" then
                selection = selection[1]
            end
            selectedCategory = selection
        end,
    })

    local productList = section:Listbox({
        Name = "Purchasable products",
        Flag = "SellLemonsPurchasableProducts",
        Items = {},
        Multi = true,
        Callback = function(selection)
            table.clear(selectedProducts)
            if type(selection) == "string" then
                selectedProducts[selection] = true
            elseif type(selection) == "table" then
                for _, label in ipairs(selection) do
                    selectedProducts[label] = true
                end
            end
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

    local function findPurchases()
        local tycoon = findLocalTycoon()
        local purchases = tycoon and tycoon:FindFirstChild("Purchases")
        if purchases and purchases:IsA("Folder") then
            return tycoon, purchases
        end
        return tycoon, nil
    end

    local function collectUpgradeRemotes(purchases)
        local found = {}

        local function visit(parent, parentPath)
            for _, child in ipairs(parent:GetChildren()) do
                local path = table.clone(parentPath)
                table.insert(path, child.Name)

                if child.Name == "Upgrade" and child:IsA("RemoteFunction") then
                    found[table.concat(path, ".")] = child
                end

                -- Upgrade may be nested through folders, models, or parts.
                if #child:GetChildren() > 0 then
                    visit(child, path)
                end
            end
        end

        visit(purchases, { "Purchases" })
        return found
    end

    local function findEarnerPrompt(product)
        if product.Name == "EarnerPrompt" and product:IsA("ProximityPrompt") then
            return product
        end
        for _, descendant in ipairs(product:GetDescendants()) do
            if descendant.Name == "EarnerPrompt" and descendant:IsA("ProximityPrompt") then
                return descendant
            end
        end
        return nil
    end

    local function collectButtonProducts(purchases)
        local found = {}
        local categoryFolders = {
            Structure = { "Structure" },
            Multiplier = { "Multiplier", "Multipler" },
            Other = { "Other" },
            Decor = { "Decor" },
            ["Itself (Product)"] = { "Itself", "Itself(Product)" },
        }

        for _, purchaseFolder in ipairs(purchases:GetChildren()) do
            if purchaseFolder:IsA("Folder") then
                local buttons = purchaseFolder:FindFirstChild("Buttons")
                if buttons and buttons:IsA("Folder") then
                    for category, folderNames in pairs(categoryFolders) do
                        for _, folderName in ipairs(folderNames) do
                            local typeFolder = buttons:FindFirstChild(folderName)
                            if typeFolder and typeFolder:IsA("Folder") then
                                for _, product in ipairs(typeFolder:GetChildren()) do
                                    if product:IsA("Model") or product:IsA("BasePart") then
                                        local label = table.concat({
                                            purchaseFolder.Name,
                                            "Buttons",
                                            folderName,
                                            product.Name,
                                        }, " / ")
                                        found[label] = {
                                            Product = product,
                                            Prompt = findEarnerPrompt(product),
                                            Category = category,
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        return found
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

    local function refreshUpgrades(purchases, tycoon)
        if not purchases then
            table.clear(upgradeByPath)
            if #previousUpgradePaths > 0 then
                previousUpgradePaths = {}
                upgradeList:Refresh(previousUpgradePaths)
                upgradeList:Set({})
            end
            selectedUpgradePath = nil
            upgradeStatus:SetText(tycoon and "Your tycoon has no Purchases folder." or "Couldn't find your owned Tycoon1–Tycoon10.")
            return
        end

        local found = collectUpgradeRemotes(purchases)
        local paths = {}
        for path in pairs(found) do
            table.insert(paths, path)
        end
        table.sort(paths)

        table.clear(upgradeByPath)
        for path, remote in pairs(found) do
            upgradeByPath[path] = remote
        end

        if not listsMatch(previousUpgradePaths, paths) then
            local retainedSelection = selectedUpgradePath
            previousUpgradePaths = paths
            upgradeList:Refresh(paths)
            if retainedSelection and upgradeByPath[retainedSelection] then
                upgradeList:Set({ retainedSelection })
                selectedUpgradePath = retainedSelection
            else
                upgradeList:Set({})
                selectedUpgradePath = nil
            end
        end

        upgradeStatus:SetText(string.format(
            "Found %d Upgrade RemoteFunction(s) in %s.Purchases.",
            #paths,
            tycoon.Name
        ))
    end

    local function refreshProducts(purchases, tycoon)
        if not purchases then
            table.clear(productByLabel)
            if #previousProductLabels > 0 then
                previousProductLabels = {}
                productList:Refresh(previousProductLabels)
                productList:Set({})
            end
            table.clear(selectedProducts)
            purchaseStatus:SetText(tycoon and "Your tycoon has no Purchases folder." or "Couldn't find your owned Tycoon1–Tycoon10.")
            return
        end

        local allProducts = collectButtonProducts(purchases)
        local items = {}
        local hasPrompt = 0
        table.clear(productByLabel)
        for label, productData in pairs(allProducts) do
            if selectedCategory == nil or productData.Category == selectedCategory then
                table.insert(items, label)
                productByLabel[label] = productData
                if productData.Prompt then
                    hasPrompt += 1
                end
            end
        end
        table.sort(items)

        if not listsMatch(previousProductLabels, items) then
            local retained = table.clone(selectedProducts)
            previousProductLabels = items
            productList:Refresh(items)
            local selection = {}
            for _, label in ipairs(items) do
                if retained[label] then
                    table.insert(selection, label)
                end
            end
            productList:Set(selection)
        end

        purchaseStatus:SetText(string.format(
            "%d %s product(s) found in %s.Purchases.Buttons (%d with EarnerPrompt).",
            #items,
            selectedCategory or "button",
            tycoon.Name,
            hasPrompt
        ))
    end

    local function refresh()
        local tycoon, purchases = findPurchases()
        refreshUpgrades(purchases, tycoon)
        refreshProducts(purchases, tycoon)
    end

    local function invokeSelectedUpgrade()
        refresh()
        local remote = selectedUpgradePath and upgradeByPath[selectedUpgradePath]
        if not remote or not remote:IsA("RemoteFunction") then
            upgradeStatus:SetText("Select a detected Upgrade RemoteFunction first.")
            return
        end

        local succeeded, result = pcall(function()
            return remote:InvokeServer(1)
        end)
        if not succeeded then
            upgradeStatus:SetText("Upgrade request failed: " .. tostring(result))
        elseif result == false then
            upgradeStatus:SetText("The server rejected the upgrade request.")
        else
            upgradeStatus:SetText("Invoked " .. selectedUpgradePath .. " with 1.")
        end
    end

    local function activateEarnerPrompt(prompt)
        if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
            return false, "EarnerPrompt is missing or disabled."
        end

        local succeeded, errorMessage = pcall(function()
            prompt:InputHoldBegin()
            if prompt.HoldDuration > 0 then
                task.wait(prompt.HoldDuration)
            end
            prompt:InputHoldEnd()
        end)
        if not succeeded then
            return false, tostring(errorMessage)
        end
        return true
    end

    local function selectedProductLabels()
        local labels = {}
        for label in pairs(selectedProducts) do
            if productByLabel[label] then
                table.insert(labels, label)
            end
        end
        table.sort(labels)
        return labels
    end

    local function purchaseSelectedOnce()
        refresh()
        local labels = selectedProductLabels()
        if #labels == 0 then
            purchaseStatus:SetText("Select one or more products first.")
            return false
        end

        local triggered = 0
        for index, label in ipairs(labels) do
            local productData = productByLabel[label]
            if productData and productData.Prompt then
                local succeeded, errorMessage = activateEarnerPrompt(productData.Prompt)
                if succeeded then
                    triggered += 1
                else
                    purchaseStatus:SetText(label .. ": " .. errorMessage)
                end
                if index < #labels then
                    task.wait(0.1)
                end
            end
        end

        purchaseStatus:SetText(string.format("Triggered %d selected EarnerPrompt(s).", triggered))
        return true
    end

    local function runPurchaseLoop(id)
        while context.Alive and purchaseLoopEnabled and id == purchaseWorkerId do
            refresh()
            local labels = selectedProductLabels()
            if #labels == 0 then
                purchaseStatus:SetText("Select products to auto-purchase.")
            else
                for _, label in ipairs(labels) do
                    if not context.Alive or not purchaseLoopEnabled or id ~= purchaseWorkerId then
                        break
                    end
                    local productData = productByLabel[label]
                    if productData and productData.Prompt then
                        local succeeded, errorMessage = activateEarnerPrompt(productData.Prompt)
                        if not succeeded then
                            purchaseStatus:SetText(label .. ": " .. errorMessage)
                        end
                    end
                    task.wait(0.2)
                end
            end
            task.wait(0.5)
        end
    end

    section:Button({
        Name = "Invoke selected Upgrade",
        Callback = invokeSelectedUpgrade,
    })
    section:Button({
        Name = "Purchase selected products",
        Callback = purchaseSelectedOnce,
    })
    section:Toggle({
        Name = "Auto-purchase selected products",
        Flag = "SellLemonsAutoPurchaseProducts",
        Default = false,
        Callback = function(enabled)
            purchaseLoopEnabled = enabled
            purchaseWorkerId += 1
            if purchaseLoopEnabled then
                task.spawn(runPurchaseLoop, purchaseWorkerId)
            else
                purchaseStatus:SetText("Auto-purchase is off.")
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
    context.AddCleanup(function()
        purchaseLoopEnabled = false
        purchaseWorkerId += 1
    end)

    refresh()
end
