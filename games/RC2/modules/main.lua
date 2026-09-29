return function(ContextV)
    local Library = ContextV.Library
    local Window = ContextV.Window

    local MainSection = ContextV.MainSection

    --//
    --// Items game:GetService("ReplicatedStorage").Content.Items
    --// Ores game:GetService("ReplicatedStorage").Content.Ores
    --// Trees game:GetService("ReplicatedStorage").Content.Trees
    --// Fishes game:GetService("ReplicatedStorage").Content.BigFish -> game:GetService("ReplicatedStorage").Content.Items (Fish Names)
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

    MainSection:Label("Fishing")

    MainSection:Label("Oil")
end