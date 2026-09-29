return function(ContextV)
    local Library = ContextV.Library
    local Window = ContextV.Window

    local VisualsSection = ContextV.VisualsSection

    local MiningList = VisualsSection:Listbox({
        Flag = "SelectedESPOres",
        Items = {},
        Multi = true,
        Callback = function(Value)
            print(Value)
        end,
    })
    local ForestryList = VisualsSection:Listbox({
        Flag = "SelectedESPWood",
        Items = {},
        Multi = true,
        Callback = function(Value)
            print(Value)
        end,
    })
    local FishingList = VisualsSection:Listbox({
        Flag = "SelectedESPFish",
        Items = {},
        Multi = true,
        Callback = function(Value)
            print(Value)
        end,
    })
end