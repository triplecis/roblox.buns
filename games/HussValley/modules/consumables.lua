return function(Context)
    local Section = Context.Sections.Consumables
    Section:Label("Consumable definitions")
    Context.CreateCatalog(Section, "Consumables", "HussValleySelectedConsumables")
    Section:Label("Carried tools")
    local Inventory = Context.CreateList(Section, "HussValleyInventory", function() end)
    local Info = Context.CreateList(Section, "HussValleyConsumableInfo", function() end)
    Context.Subscribe(function(Snapshot)
        Inventory(Snapshot.Tools)
        Info(Snapshot.ConsumableInfo)
    end)
    Section:Label("Purchasing and use require a verified game binding.")
end
