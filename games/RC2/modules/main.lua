return function(ModuleContext)
    local Library = ModuleContext.Library
    local Window = ModuleContext.Window

    local MainSection = ModuleContext.Main

    local Items = game:GetService("ReplicatedStorage").Content.Items
    local Ores = game:GetService("ReplicatedStorage").Content.Ores -- Needs to ignore bushes
    local Trees = game:GetService("ReplicatedStorage").Content.Trees
    local Fish = game:GetService("ReplicatedStorage").Content.Fishes -- Needs to ignore bushes
    local BigFish = game:GetService("ReplicatedStorage").Content.BigFish -- Needs to ignore bushes
   
    --//
    --// VALUES
    --// Items game:GetService("ReplicatedStorage").Content.Items
    --// Ores game:GetService("ReplicatedStorage").Content.Ores
    --// Trees game:GetService("ReplicatedStorage").Content.Trees
    --// Fishes game:GetService("ReplicatedStorage").Content.BigFish -> game:GetService("ReplicatedStorage").Content.Items (Fish Names)
    --// STORED
    --//
    
    MainSection:Label("Mining")
    local OreList = MainSection:Listbox({
        Flag = "SelectedOres",
        Items = {},
        Multi = true,
        Callback = function(Value)
            print(Value)
        end,
    })

    MainSection:Label("Forestry")
    local TreeList = MainSection:Listbox({
        Flag = "SelectedTrees",
        Items = {},
        Multi = true,
        Callback = function(Value)
            print(Value)
        end,
    })
    MainSection:Label("Fishing")
    local FishList = MainSection:Listbox({
        Flag = "SelectedFishes",
        Items = {},
        Multi = true,
        Callback = function(Value)
            print(Value)
        end,
    })
    MainSection:Label("Oil")
    local OilList = MainSection:Listbox({
        Flag = "SelectedOils",
        Items = {},
        Multi = true,
        Callback = function(Value)
            print(Value)
        end,
    })
end