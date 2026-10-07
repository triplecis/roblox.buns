return function(Context)
    local Players = game:GetService("Players")
    local Storage = game:GetService("ReplicatedStorage")
    local Subscribers = {}
    local Spectating
    local CameraBackup
    local Elapsed = 0
    local MovementModules = {}
    Context.State.Catalogs = {
        Abilities = { Entries = {}, Sources = {} },
        Consumables = { Entries = {}, Sources = {} },
    }

    local function Normalize(Value)
        return type(Value) == "string" and string.lower(Value):gsub("[^%w]", "") or ""
    end

    local function Attributes(Object)
        return Object and Object:GetAttributes() or {}
    end

    local function RoleName(Value)
        local Name = Normalize(Value)
        if Name == "runner" or Name == "runners" then return "Runners" end
        if Name == "chaser" or Name == "chasers" or Name == "catcher" or Name == "catchers" then return "Chasers" end
        return nil
    end

    function Context.GetRole(Player)
        local PlayerAttributes = Attributes(Player)
        -- GameRole is authoritative, including lobby/unknown roles.
        if PlayerAttributes.GameRole ~= nil then return RoleName(PlayerAttributes.GameRole) or "Unknown" end
        local Role = RoleName(PlayerAttributes.Role) or RoleName(Attributes(Player.Character).Role)
        if Role then return Role end
        return Player.Team and not Player.Neutral and RoleName(Player.Team.Name) or "Unknown"
    end

    function Context.PlayerLabel(Player)
        return Player.DisplayName .. " (@" .. Player.Name .. ")"
    end

    local function Humanoid(Player)
        return Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
    end

    local function Number(Value: any): number?
        if type(Value) == "number" and Value == Value and math.abs(Value) ~= math.huge then return Value end
        return nil
    end

    local function MovementModule(Name, Force)
        local GameRoot = Storage:FindFirstChild("ChickenOrHero")
        local Movement = GameRoot and GameRoot:FindFirstChild("Movement")
        local Module = Movement and Movement:FindFirstChild(Name)
        if not Module or not Module:IsA("ModuleScript") then
            return nil, Name .. " is unavailable."
        end
        local Cached = MovementModules[Name]
        if Cached and Cached.Instance == Module and not Force then return Cached.Value end
        local Success, Value = pcall(require, Module)
        if not Success or type(Value) ~= "table" then
            return nil, Name .. " could not load: " .. tostring(Value)
        end
        MovementModules[Name] = { Instance = Module, Value = Value }
        return Value
    end

    local function ReadProfile(Force)
        local Profiles, Error = MovementModule("MovementProfiles", Force)
        if not Profiles then return nil, Error end
        if type(Profiles.get) ~= "function" then return nil, "MovementProfiles.get is unavailable." end
        local Success, Profile = pcall(Profiles.get, Attributes(Context.Player).GameRole, Context.Player)
        if not Success or type(Profile) ~= "table" then return nil, "Could not read movement profile: " .. tostring(Profile) end
        if not Number(Profile.MaxSpeed) or not Number(Profile.Acceleration) then
            return nil, "MovementProfiles returned an invalid speed profile."
        end
        return Profile
    end

    function Context.ReadMovementProfile()
        if not Context.Alive then return false end
        local Profile, Error = ReadProfile(true)
        if not Context.Alive then return false end
        Context.State.MovementProfile = Profile
        Context.State.MovementProfileError = Error
        if not Profile then Context.Notify("Movement profile unavailable", Error, 3) end
        Context.RefreshData()
        return Profile ~= nil
    end

    function Context.RequestDash(TouchStyle)
        if not Context.Alive then return false end
        local Character = Context.Player.Character
        local Human = Humanoid(Context.Player)
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local CharacterAttributes = Attributes(Character)
        local Reason
        if Attributes(Context.Player).GameRole == "Catcher" then
            Reason = "Catchers do not have the Runner dash."
        elseif not Human or not Root or not Root:IsA("BasePart") or Human.Health <= 0 then
            Reason = "No active character."
        elseif Root.Anchored or Human.Sit or Human.PlatformStand then
            Reason = "Character movement is unavailable."
        elseif CharacterAttributes.MovementLocked or CharacterAttributes.TackleActive or CharacterAttributes.GearMotion then
            Reason = CharacterAttributes.MovementBlockReason or CharacterAttributes.MovementLockReason or "Movement is locked."
        elseif CharacterAttributes.DashReady == false then
            Reason = "Dash is not ready."
        end
        local Until = Number(CharacterAttributes.DashCooldownUntil)
        local Cooldown = Until and (Until - os.clock()) or Number(CharacterAttributes.DashCooldown)
        if not Reason and Cooldown and Cooldown > 0 then Reason = "Dash is cooling down." end
        if Reason then Context.Notify("Dash unavailable", Reason, 3); return false end
        local Input, Error = MovementModule("BoostInput")
        if not Context.Alive then return false end
        if not Input or type(Input.available) ~= "function" or type(Input.request) ~= "function" then
            Context.Notify("Dash unavailable", Error or "BoostInput does not expose the required functions.", 3)
            return false
        end
        local Checked, Available = pcall(Input.available, Context.Player)
        if not Context.Alive then return false end
        if not Checked or Available ~= true then
            Context.Notify("Dash unavailable", Checked and "The game is blocking dash input." or tostring(Available), 3)
            return false
        end
        -- The existing movement controller consumes this buffered request and handles the remote.
        local Requested, RequestError = pcall(Input.request, TouchStyle == true)
        if not Requested then Context.Notify("Dash request failed", RequestError, 3) end
        return Requested
    end

    function Context.StopSpectating()
        Spectating = nil
        Context.State.Spectating = nil
        if CameraBackup then
            local Camera = CameraBackup.Camera
            local Subject = CameraBackup.Subject
            -- A local respawn can invalidate the original subject.
            if not Subject or not Subject.Parent then Subject = Humanoid(Context.Player) end
            if Subject then Camera.CameraSubject = Subject end
            Camera.CameraType = CameraBackup.Type
            CameraBackup = nil
        end
    end

    local function UpdateSpectating()
        if not Spectating then return end
        local Present = false
        for _, Player in ipairs(Players:GetPlayers()) do
            if Player == Spectating then Present = true; break end
        end
        if not Present then Context.StopSpectating(); return end
        local Camera = workspace.CurrentCamera
        local Subject = Humanoid(Spectating)
        if not Camera or not Subject or not Subject.Parent then
            Context.StopSpectating()
            return
        end
        if CameraBackup and CameraBackup.Camera ~= Camera then
            -- Restore the old camera before taking ownership of a replacement.
            local Target = Spectating
            Context.StopSpectating()
            Spectating = Target
            Context.State.Spectating = Target
        end
        if not CameraBackup then
            CameraBackup = { Camera = Camera, Subject = Camera.CameraSubject, Type = Camera.CameraType }
        end
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = Subject
    end

    function Context.SpectatePlayer(Player)
        if not Context.Alive then return false end
        if not workspace.CurrentCamera or not Player or not Humanoid(Player) then
            Context.Notify("Spectate unavailable", "That player has no active character or camera.", 3)
            return false
        end
        Spectating = Player
        Context.State.Spectating = Player
        UpdateSpectating()
        return Spectating ~= nil
    end

    local function AttributeRows(Object, Prefix, Matches, Rows)
        for Name, Value in pairs(Attributes(Object)) do
            local Key = Normalize(Name)
            for _, Term in ipairs(Matches) do
                if string.find(Key, Term, 1, true) then
                    table.insert(Rows, Prefix .. "." .. Name .. " = " .. tostring(Value))
                    break
                end
            end
        end
    end

    local function RoundRows(Object, Prefix, Depth, Rows)
        if Depth > 3 then return end
        AttributeRows(Object, Prefix, { "round", "match", "cross", "phase", "hero", "chicken" }, Rows)
        for _, Child in ipairs(Object:GetChildren()) do
            if Child:IsA("ValueBase") then
                table.insert(Rows, Prefix .. "." .. Child.Name .. " = " .. tostring(Child.Value))
            elseif Child:IsA("Folder") or Child:IsA("Configuration") then
                RoundRows(Child, Prefix .. "." .. Child.Name, Depth + 1, Rows)
            end
        end
    end

    function Context.RefreshData()
        if not Context.Alive then return Context.State.Snapshot end
        local Snapshot = {
            Runners = {}, Chasers = {}, Unknown = 0,
            Role = Context.GetRole(Context.Player),
            RoundInfo = {}, AbilityInfo = {}, ConsumableInfo = {}, Stats = {}, Tools = {},
            Catalogs = Context.State.Catalogs,
            ServerSeconds = math.floor(workspace.DistributedGameTime),
            GameRole = Attributes(Context.Player).GameRole,
        }
        for _, Player in ipairs(Players:GetPlayers()) do
            local Role = Context.GetRole(Player)
            if Role == "Unknown" then
                Snapshot.Unknown = Snapshot.Unknown + 1
            else
                table.insert(Snapshot[Role], Player)
            end
        end
        for _, Role in ipairs({ "Runners", "Chasers" }) do
            table.sort(Snapshot[Role], function(A, B) return Context.PlayerLabel(A) < Context.PlayerLabel(B) end)
        end

        for _, Info in ipairs({ { workspace, "Workspace" }, { Storage, "ReplicatedStorage" }, { Context.Player, "Player" } }) do
            AttributeRows(Info[1], Info[2], { "round", "match", "cross", "phase", "hero", "chicken" }, Snapshot.RoundInfo)
        end
        local RoundContainers = {
            round = true, rounddata = true, roundstate = true, currentround = true,
            match = true, matchdata = true, gamestate = true,
        }
        for _, Root in ipairs({ workspace, Storage }) do
            for _, Child in ipairs(Root:GetChildren()) do
                if RoundContainers[Normalize(Child.Name)] then
                    if Child:IsA("ValueBase") then
                        table.insert(Snapshot.RoundInfo, Root.Name .. "." .. Child.Name .. " = " .. tostring(Child.Value))
                    elseif Child:IsA("Folder") or Child:IsA("Configuration") then
                        RoundRows(Child, Root.Name .. "." .. Child.Name, 0, Snapshot.RoundInfo)
                    end
                end
            end
        end
        AttributeRows(Context.Player, "Player", { "ability", "cooldown" }, Snapshot.AbilityInfo)
        AttributeRows(Context.Player.Character, "Character", { "ability", "cooldown" }, Snapshot.AbilityInfo)
        AttributeRows(Context.Player, "Player", { "consumable" }, Snapshot.ConsumableInfo)
        AttributeRows(Context.Player.Character, "Character", { "consumable" }, Snapshot.ConsumableInfo)

        local Leaderstats = Context.Player:FindFirstChild("leaderstats")
        if Leaderstats then
            for _, Value in ipairs(Leaderstats:GetChildren()) do
                if Value:IsA("ValueBase") then Snapshot.Stats[Value.Name] = Value.Value end
            end
        end
        local SeenTools = {}
        for _, Container in pairs({ Context.Player:FindFirstChildOfClass("Backpack"), Context.Player.Character }) do
            for _, Child in ipairs(Container:GetChildren()) do
                if Child:IsA("Tool") and not SeenTools[Child.Name] then
                    SeenTools[Child.Name] = true
                    table.insert(Snapshot.Tools, Child.Name)
                end
            end
        end
        local Character = Context.Player.Character
        local MovementAttributes = Attributes(Character)
        local Until = Number(MovementAttributes.DashCooldownUntil)
        Snapshot.Movement = {
            State = MovementAttributes.MovementState,
            Speed = Number(MovementAttributes.MovementSpeed),
            DashReady = MovementAttributes.DashReady,
            DashCount = Number(MovementAttributes.DashCount),
            DashCooldown = Until and math.max(0, Until - os.clock()) or Number(MovementAttributes.DashCooldown),
            LastDashDistance = Number(MovementAttributes.LastDashDistance),
            BlockReason = MovementAttributes.MovementBlockReason,
        }
        if MovementModules.MovementProfiles then
            local Profile, Error = ReadProfile(false)
            if not Context.Alive then return Context.State.Snapshot end
            Context.State.MovementProfile = Profile
            Context.State.MovementProfileError = Error
        end
        Snapshot.MovementProfile = Context.State.MovementProfile
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        if Root and Root:IsA("BasePart") then
            local Velocity = Root.AssemblyLinearVelocity
            Snapshot.Speed = math.sqrt(Velocity.X * Velocity.X + Velocity.Z * Velocity.Z)
        end
        for _, Key in ipairs({ "RoundInfo", "AbilityInfo", "ConsumableInfo", "Tools" }) do
            table.sort(Snapshot[Key])
        end
        Context.State.Snapshot = Snapshot
        UpdateSpectating()
        for _, Callback in ipairs(Subscribers) do Callback(Snapshot) end
        return Snapshot
    end

    function Context.Subscribe(Callback)
        table.insert(Subscribers, Callback)
        Callback(Context.State.Snapshot)
    end

    function Context.RefreshCatalogs()
        if not Context.Alive then return end
        local Catalogs = {
            Abilities = { Entries = {}, Sources = {} },
            Consumables = { Entries = {}, Sources = {} },
        }
        local Names = {
            abilities = "Abilities", runnerabilities = "Abilities",
            chaserabilities = "Abilities", catcherabilities = "Abilities", consumables = "Consumables",
        }
        local Seen = { Abilities = {}, Consumables = {} }
        local function Collect(Container, Prefix, Group, Depth)
            if Depth > 5 then return end
            for _, Child in ipairs(Container:GetChildren()) do
                local Name = Prefix .. "/" .. Child.Name
                if Child:IsA("Folder") or Child:IsA("Configuration") then
                    Collect(Child, Name, Group, Depth + 1)
                elseif (Child:IsA("ModuleScript") or Child:IsA("Model") or Child:IsA("Tool") or Child:IsA("ValueBase"))
                    and not Seen[Group][Child] then
                    Seen[Group][Child] = true
                    table.insert(Catalogs[Group].Entries, Name)
                end
            end
        end
        for _, Object in ipairs(Storage:GetDescendants()) do
            local Group = Names[Normalize(Object.Name)]
            if Group and (Object:IsA("Folder") or Object:IsA("Configuration")) then
                local Path = Object:GetFullName()
                table.insert(Catalogs[Group].Sources, Path)
                Collect(Object, Path, Group, 0)
            end
        end
        for _, Catalog in pairs(Catalogs) do
            table.sort(Catalog.Entries)
            table.sort(Catalog.Sources)
        end
        Context.State.Catalogs = Catalogs
        Context.RefreshData()
    end

    function Context.CreateList(Section, Flag, OnSelection)
        local List = Section:Listbox({ Flag = Flag, Items = {}, Multi = true, Callback = OnSelection })
        local Previous
        return function(Items)
            local Same = Previous ~= nil and #Previous == #Items
            if Same then
                for Index, Item in ipairs(Items) do
                    if Item ~= Previous[Index] then Same = false; break end
                end
            end
            if Same then return end
            local Available, Selected = {}, {}
            for _, Item in ipairs(Items) do Available[Item] = true end
            for _, Item in ipairs(List.Value) do
                if Available[Item] then table.insert(Selected, Item) end
            end
            Previous = table.clone(Items)
            List:Refresh(Items)
            List:Set(Selected)
        end
    end

    function Context.CreateRoleRoster(Section, Role)
        local Title = Role == "Chasers" and "Catchers" or Role
        local Count = Section:Label(Title .. ": 0")
        local Status = Section:Label("Select one player to spectate.")
        local Selected, PlayerByLabel = {}, {}
        local Refresh = Context.CreateList(Section, "HussValley" .. Role .. "Selected", function(Value)
            Selected = table.clone(Value)
        end)
        Section:Button({
            Name = "Spectate selected " .. string.lower(Title),
            Callback = function()
                if #Selected ~= 1 then
                    Context.Notify("Select a player", "Select exactly one player in this roster.", 3)
                    return
                end
                Context.SpectatePlayer(PlayerByLabel[Selected[1]])
            end,
        })
        Section:Button({ Name = "Stop spectating " .. string.lower(Title), Callback = Context.StopSpectating })
        Context.Subscribe(function(Snapshot)
            local Labels = {}
            table.clear(PlayerByLabel)
            for _, Player in ipairs(Snapshot[Role]) do
                local Label = Context.PlayerLabel(Player)
                PlayerByLabel[Label] = Player
                table.insert(Labels, Label)
            end
            Refresh(Labels)
            Count:SetText(Title .. ": " .. tostring(#Labels))
            Status:SetText(Context.State.Spectating and ("Spectating: " .. Context.PlayerLabel(Context.State.Spectating))
                or "Select one player to spectate.")
        end)
    end

    function Context.CreateCatalog(Section, Group, Flag)
        local Status = Section:Label("")
        Context.State["Selected" .. Group] = {}
        local Refresh = Context.CreateList(Section, Flag, function(Value)
            Context.State["Selected" .. Group] = table.clone(Value)
        end)
        Section:Button({ Name = "Refresh " .. string.lower(Group), Callback = Context.RefreshCatalogs })
        Context.Subscribe(function(Snapshot)
            local Catalog = Snapshot.Catalogs[Group]
            Refresh(Catalog.Entries)
            Status:SetText(#Catalog.Sources > 0 and (tostring(#Catalog.Entries) .. " definitions found")
                or "Definitions are not exposed in a matching folder.")
        end)
    end

    Context.AddCleanup(function()
        Context.StopSpectating()
        table.clear(Subscribers)
    end)
    Context.RefreshData()
    Context.RefreshCatalogs()
    Context.Connect(game:GetService("RunService").Heartbeat, function(DeltaTime)
        Elapsed = Elapsed + DeltaTime
        if Elapsed >= 0.5 then
            Elapsed = Elapsed % 0.5
            Context.RefreshData()
        end
    end)
end
