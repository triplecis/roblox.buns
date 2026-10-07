return function(Context)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    Context.CatalogListeners = {}
    local Elapsed = 0
    local ListenerErrors = {}

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
        if not Context.Alive then return Context.Catalog end
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
        local Catalog = {
            Items = Names(Items, false),
            Ores = Names(Folder("Ores"), true),
            Trees = Names(Folder("Trees"), true),
            Fishes = Fishes,
            Oils = Names(Folder("Oils"), true),
        }
        local Same = Context.Catalog ~= nil
        if Same then
            for Group, ItemsInGroup in pairs(Catalog) do
                local Old = Context.Catalog[Group]
                if #Old ~= #ItemsInGroup then Same = false; break end
                for Index, Name in ipairs(ItemsInGroup) do
                    if Old[Index] ~= Name then Same = false; break end
                end
                if not Same then break end
            end
        end
        if Same then return Context.Catalog end
        Context.Catalog = Catalog
        for _, Callback in ipairs(Context.CatalogListeners) do
            local Success, Error = pcall(Callback, Context.Catalog)
            if not Success and ListenerErrors[Callback] ~= tostring(Error) then
                Context.Notify("Catalog update failed", Error, 3)
            end
            ListenerErrors[Callback] = not Success and tostring(Error) or nil
        end
        return Context.Catalog
    end

    Context.RefreshCatalog()
    for _, Signal in ipairs({ ReplicatedStorage.DescendantAdded, ReplicatedStorage.DescendantRemoving }) do
        Context.Connect(Signal, function() Elapsed = 2 end)
    end
    Context.Connect(game:GetService("RunService").Heartbeat, function(DeltaTime)
        Elapsed = Elapsed + DeltaTime
        if Elapsed >= 2 then Elapsed = Elapsed % 2; Context.RefreshCatalog() end
    end)
    Context.AddCleanup(function() table.clear(Context.CatalogListeners) end)
end
