return function(Context)
    local Section = Context.Sections.Main
    local Lists, Statuses = {}, {}
    local Groups = {
        { "Ores", "Mining", "SelectedOres" },
        { "Trees", "Forestry", "SelectedTrees" },
        { "Fishes", "Fishing", "SelectedFishes" },
        { "Oils", "Oil", "SelectedOils" },
    }
    for _, Group in ipairs(Groups) do
        local Key = Group[1]
        Section:Label(Group[2])
        Statuses[Key] = Section:Label("")
        Lists[Key] = Section:Listbox({
            Flag = Group[3], Items = Context.Catalog[Key], Multi = true,
            Callback = function(Value)
                Context.Selections[Key] = table.clone(Value)
            end,
        })
    end

    local function Refresh(Catalog)
        for Key, List in pairs(Lists) do
            local Available = {}
            for _, Name in ipairs(Catalog[Key]) do Available[Name] = true end
            local Selected = {}
            for _, Name in ipairs(Context.Selections[Key]) do
                if Available[Name] then table.insert(Selected, Name) end
            end
            List:Refresh(Catalog[Key])
            List:Set(Selected)
            Statuses[Key]:SetText(#Catalog[Key] > 0 and (tostring(#Catalog[Key]) .. " available")
                or "No resource definitions available.")
        end
    end

    table.insert(Context.CatalogListeners, Refresh)
    Section:Button({ Name = "Refresh resources", Icon = "refresh-cw", Callback = Context.RefreshCatalog })
    Refresh(Context.Catalog)
end
