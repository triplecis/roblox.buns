return function(ContextV)
    local Library = ContextV.Library
    local Window = ContextV.Window

    local MainSection = ContextV.MainSection

    local OreList = MainSection:Listbox({
        Flag = "SelectedOres",
        Items = {},
        Multi = true,
        Callback = function(Value)
            print(Value)
        end,
    })

    

end