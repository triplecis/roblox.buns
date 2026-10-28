-- Browse item definitions. Purchasing has not been connected to a game action.
return function(context)
    local section = context.Sections.Buy
    section:Label("Item catalog")

    local statusLabel = section:Label("")
    section:Label("Purchasing is not implemented.")

    local itemList = section:Listbox({
        Flag = "SelectedBuyItems",
        Items = context.Catalog.Items,
        Multi = true,
        Callback = function(selectedItems)
            context.Selections.BuyItems = table.clone(selectedItems)
        end,
    })

    -- Keep only selected names that still exist after the catalog refreshes.
    local function refresh(catalog)
        local availableItems = {}
        for _, itemName in ipairs(catalog.Items) do
            availableItems[itemName] = true
        end

        local validSelections = {}
        for _, itemName in ipairs(context.Selections.BuyItems or {}) do
            if availableItems[itemName] then
                table.insert(validSelections, itemName)
            end
        end

        itemList:Refresh(catalog.Items)
        itemList:Set(validSelections)
        statusLabel:SetText(tostring(#catalog.Items) .. " item definitions available")
    end

    table.insert(context.CatalogListeners, refresh)
    refresh(context.Catalog)
end
