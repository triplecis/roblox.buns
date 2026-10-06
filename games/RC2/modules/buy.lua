return function(Context)
    local Section = Context.Sections.Buy
    Section:Label("Item catalog")
    local Status = Section:Label("")
    Section:Label("Purchasing is not implemented.")
    local List = Section:Listbox({
        Flag = "SelectedBuyItems", Items = Context.Catalog.Items, Multi = true,
        Callback = function(Value)
            Context.Selections.BuyItems = table.clone(Value)
        end,
    })

    local function Refresh(Catalog)
        local Available = {}
        for _, Name in ipairs(Catalog.Items) do Available[Name] = true end
        local Selected = {}
        for _, Name in ipairs(Context.Selections.BuyItems or {}) do
            if Available[Name] then table.insert(Selected, Name) end
        end
        List:Refresh(Catalog.Items)
        List:Set(Selected)
        Status:SetText(tostring(#Catalog.Items) .. " item definitions available")
    end
    table.insert(Context.CatalogListeners, Refresh)
    Refresh(Context.Catalog)
end
