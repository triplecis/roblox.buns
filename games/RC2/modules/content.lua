return function(Context)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    Context.CatalogListeners = {}

    local function Names(Container, ExcludeBushes)
        local Result, Seen = {}, {}
        if Container then
            for _, Child in ipairs(Container:GetChildren()) do
                local Name = Child.Name
                local IsBush = string.find(string.lower(Name), "bush", 1, true) ~= nil
                if Name ~= "" and not Seen[Name] and not (ExcludeBushes and IsBush) then
                    Seen[Name] = true
                    table.insert(Result, Name)
                end
            end
        end
        table.sort(Result)
        return Result
    end

    function Context.RefreshCatalog()
        local Content = ReplicatedStorage:FindFirstChild("Content")
        local function Folder(Name)
            return Content and Content:FindFirstChild(Name)
        end
        local Items, BigFish = Folder("Items"), Folder("BigFish")
        local Fishes = {}
        -- Fish names must have both a BigFish template and an Items definition.
        for _, Name in ipairs(Names(BigFish, true)) do
            if Items and Items:FindFirstChild(Name) then
                table.insert(Fishes, Name)
            end
        end
        Context.Catalog = {
            Items = Names(Items, false),
            Ores = Names(Folder("Ores"), true),
            Trees = Names(Folder("Trees"), true),
            Fishes = Fishes,
            Oils = Names(Folder("Oils"), true),
        }
        for _, Callback in ipairs(Context.CatalogListeners) do
            Callback(Context.Catalog)
        end
        return Context.Catalog
    end

    Context.RefreshCatalog()
end
