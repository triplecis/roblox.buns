-- Show the mining, forestry, fishing, and oil resource catalogs.
return function(context)
    local section = context.Sections.Main
    local listsByCategory = {}
    local statusByCategory = {}

    local categories = {
        { key = "Ores", title = "Mining", selection = "SelectedOres" },
        { key = "Trees", title = "Forestry", selection = "SelectedTrees" },
        { key = "Fishes", title = "Fishing", selection = "SelectedFishes" },
        { key = "Oils", title = "Oil", selection = "SelectedOils" },
    }

    for _, category in ipairs(categories) do
        section:Label(category.title)
        statusByCategory[category.key] = section:Label("")

        listsByCategory[category.key] = section:Listbox({
            Flag = category.selection,
            Items = context.Catalog[category.key],
            Multi = true,
            Callback = function(selectedNames)
                context.Selections[category.key] = table.clone(selectedNames)
            end,
        })
    end

    local function refreshCategory(categoryKey, names)
        local availableNames = {}
        for _, name in ipairs(names) do
            availableNames[name] = true
        end

        local validSelections = {}
        for _, name in ipairs(context.Selections[categoryKey]) do
            if availableNames[name] then
                table.insert(validSelections, name)
            end
        end

        listsByCategory[categoryKey]:Refresh(names)
        listsByCategory[categoryKey]:Set(validSelections)

        if #names == 0 then
            statusByCategory[categoryKey]:SetText("No resource definitions available.")
        else
            statusByCategory[categoryKey]:SetText(tostring(#names) .. " available")
        end
    end

    -- Remove selections for resources that disappeared from replicated data.
    local function refresh(catalog)
        for categoryKey in pairs(listsByCategory) do
            refreshCategory(categoryKey, catalog[categoryKey])
        end
    end

    table.insert(context.CatalogListeners, refresh)

    section:Button({
        Name = "Refresh resources",
        Icon = "refresh-cw",
        Callback = context.RefreshCatalog,
    })

    refresh(context.Catalog)
end
