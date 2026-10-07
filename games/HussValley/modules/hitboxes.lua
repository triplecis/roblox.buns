return function(Context)
    local Players = game:GetService("Players")
    local Section = Context.Sections.Hitboxes
    local Status = Section:Label("Hitbox editing: disabled")
    Section:Label("Edits are local. Tackle hit registration needs the game's hit-detection bindings.")
    Section:Label("Select actual character parts below; HumanoidRootPart is the initial target.")
    Section:Label("Your root size affects tackle wall clearance. Catch bounds come from HitReplayMath.")
    local State = { Enabled = false, AllOthers = true, IncludeSelf = false,
        Size = { X = 6, Y = 6, Z = 6 }, NonColliding = true, Preview = true }
    Context.State.Hitboxes = State
    local SelectedPlayers, SelectedParts = {}, { HumanoidRootPart = true }
    local Records = {}
    local Update = function() end
    local PreviousPlayers, PreviousParts

    local function Map(Values)
        local Result = {}
        for _, Value in ipairs(Values) do Result[Value] = true end
        return Result
    end

    local function Restore(Part, Record)
        if Record.Box then Record.Box:Destroy() end
        if Part.Parent then
            if Part.Size == Record.AppliedSize then Part.Size = Record.Size end
            if Record.AppliedCollision ~= nil and Part.CanCollide == Record.AppliedCollision then
                Part.CanCollide = Record.CanCollide
            end
        end
        Records[Part] = nil
    end

    local function PlayerLabel(Player)
        return Context.PlayerLabel(Player) .. " [" .. tostring(Player.UserId) .. "]"
    end

    local PlayerList = Section:Listbox({
        Flag = "HussValleyHitboxPlayers", Items = {}, Multi = true,
        Callback = function(Values) SelectedPlayers = Map(Values); Update() end,
    })
    local PartList = Section:Listbox({
        Flag = "HussValleyHitboxParts", Items = { "HumanoidRootPart" }, Multi = true,
        Default = { "HumanoidRootPart" },
        Callback = function(Values) SelectedParts = Map(Values); Update() end,
    })

    local function RefreshList(List, Items, Previous)
        if Previous and table.concat(Items, "\n") == table.concat(Previous, "\n") then return Previous end
        local Available, Selected = Map(Items), {}
        for _, Name in ipairs(List.Value) do
            if Available[Name] then table.insert(Selected, Name) end
        end
        List:Refresh(Items)
        List:Set(Selected)
        return table.clone(Items)
    end

    local Refreshing = false
    local function Discover()
        local Names, Paths, Seen = {}, {}, {}
        local function Visit(Container, Prefix)
            for _, Child in ipairs(Container:GetChildren()) do
                local Path = Prefix .. Child.Name
                if Child:IsA("BasePart") and not Seen[Path] then
                    Seen[Path] = true
                    table.insert(Paths, Path)
                end
                Visit(Child, Path .. "/")
            end
        end
        for _, Player in ipairs(Players:GetPlayers()) do
            table.insert(Names, PlayerLabel(Player))
            if Player.Character then Visit(Player.Character, "") end
        end
        table.sort(Names)
        table.sort(Paths)
        Refreshing = true
        PreviousPlayers = RefreshList(PlayerList, Names, PreviousPlayers)
        -- Retain selection during a respawn/streaming gap; never invent a part instance.
        if #Paths > 0 then PreviousParts = RefreshList(PartList, Paths, PreviousParts) end
        Refreshing = false
    end

    local function FindPart(Character, Path)
        local Object = Character
        for Name in string.gmatch(Path, "[^/]+") do
            Object = Object and Object:FindFirstChild(Name)
        end
        return Object and Object:IsA("BasePart") and Object or nil
    end

    Update = function()
        if Refreshing or not Context.Alive then return end
        local Wanted, Count = {}, 0
        if State.Enabled then
            local Size = Vector3.new(State.Size.X, State.Size.Y, State.Size.Z)
            for _, Player in ipairs(Players:GetPlayers()) do
                local Target = Player == Context.Player and State.IncludeSelf
                    or (Player ~= Context.Player and (State.AllOthers or SelectedPlayers[PlayerLabel(Player)]))
                if Target and Player.Character then
                    for Path in pairs(SelectedParts) do
                        local Part = FindPart(Player.Character, Path)
                        if Part and Part.Parent then
                            Wanted[Part] = true
                            Count += 1
                            local Record = Records[Part]
                            if not Record then
                                Record = { Size = Part.Size, CanCollide = Part.CanCollide }
                                Records[Part] = Record
                            elseif Part.Size ~= Record.AppliedSize then
                                Record.Size = Part.Size
                            end
                            Record.AppliedSize = Size
                            Part.Size = Size
                            if State.NonColliding then
                                if Record.AppliedCollision == nil or Part.CanCollide ~= Record.AppliedCollision then
                                    Record.CanCollide = Part.CanCollide
                                end
                                Record.AppliedCollision = false
                                Part.CanCollide = false
                            elseif Record.AppliedCollision ~= nil then
                                if Part.CanCollide == Record.AppliedCollision then Part.CanCollide = Record.CanCollide end
                                Record.AppliedCollision = nil
                            end
                            if State.Preview and not Record.Box then
                                local Box = Instance.new("SelectionBox")
                                Box.Name, Box.Adornee = "RobloxBunsHitboxPreview", Part
                                Box.LineThickness, Box.SurfaceTransparency = 0.03, 0.85
                                Box.Color3 = Color3.fromRGB(100, 149, 255)
                                Box.Parent = Part
                                Record.Box = Box
                            elseif not State.Preview and Record.Box then
                                Record.Box:Destroy()
                                Record.Box = nil
                            end
                        end
                    end
                end
            end
        end
        for Part, Record in pairs(Records) do
            if not Wanted[Part] then Restore(Part, Record) end
        end
        State.EditedParts = Count
        Status:SetText(State.Enabled and ("Local edited parts: " .. tostring(Count)) or "Hitbox editing: disabled")
    end

    Section:Toggle({
        Name = "Edit character hitboxes (local)", Flag = "HussValleyHitboxesEnabled", Default = false,
        Callback = function(Enabled) State.Enabled = Enabled; Update() end,
    })
    for _, Axis in ipairs({ "X", "Y", "Z" }) do
        Section:Slider({
            Name = "Hitbox size " .. Axis, Flag = "HussValleyHitboxSize" .. Axis,
            Default = State.Size[Axis], Min = 0.5, Max = 20, Decimals = 0.1, Suffix = " studs",
            Callback = function(Value)
                if type(Value) ~= "number" or Value ~= Value then return end
                State.Size[Axis] = math.clamp(Value, 0.5, 20)
                Update()
            end,
        })
    end
    for _, Control in ipairs({
        { "All other players", "AllOthers", "HussValleyHitboxAllOthers" },
        { "Include your character", "IncludeSelf", "HussValleyHitboxIncludeSelf" },
        { "Non-colliding edited parts", "NonColliding", "HussValleyHitboxNonColliding" },
        { "Show edited hitboxes", "Preview", "HussValleyHitboxPreview" },
    }) do
        Section:Toggle({
            Name = Control[1], Flag = Control[3], Default = State[Control[2]],
            Callback = function(Enabled) State[Control[2]] = Enabled; Update() end,
        })
    end
    Section:Button({ Name = "Refresh hitbox parts", Callback = function() Discover(); Update() end })
    Context.Subscribe(function() Discover(); Update() end)
    Context.AddCleanup(function()
        State.Enabled = false
        for Part, Record in pairs(Records) do Restore(Part, Record) end
        State.EditedParts = 0
    end)
end
