return function(Context)
    local Players = game:GetService("Players")
    local Storage = game:GetService("ReplicatedStorage")
    local Subscribers = {}
    local Spectating
    local CameraBackup
    local Elapsed = 0
    local MovementModules = {}
    local GameModules = {}
    local Watches = {}
    local Clock = 0
    Context.State.Catalogs = {
        Abilities = { Entries = {}, Sources = {} },
        Consumables = { Entries = {}, Sources = {} },
    }

    local function RunLive(Entry, Callback)
        if Entry.Running or not Context.Alive then return end
        Entry.Running = true
        task.spawn(function()
            if Context.Alive then
                local Success, Error = pcall(Callback)
                if not Success then
                    local Message = tostring(Error)
                    if Entry.Error ~= Message then Context.Notify("Live update failed", Entry.Name .. ": " .. Message, 3) end
                    Entry.Error = Message
                else Entry.Error = nil end
            end
            Entry.Running = false
        end)
    end

    function Context.WatchData(Name, Callback, Interval)
        local Entry = { Name = Name, Callback = Callback, Interval = Interval or 0.5, NextAt = 0 }
        table.insert(Watches, Entry)
        return Entry
    end

    local function Deliver(Entry, Snapshot)
        Entry.Latest = Snapshot
        RunLive(Entry, function() Entry.Callback(Entry.Latest) end)
    end

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

    local function Session()
        local GameRoot = Storage:FindFirstChild("ChickenOrHero")
        local GameFolder = GameRoot and GameRoot:FindFirstChild("Game")
        return GameFolder and GameFolder:FindFirstChild("Session")
    end

    local function SessionMovementReason()
        local Data = Attributes(Session())
        if Data.GlobalPaused == true then return "GlobalPause" end
        if Data.MapChanging == true then return "MapChange" end
        if Attributes(Context.Player).Spectating == true then return "Spectating" end
        return nil
    end

    local function Remaining(Deadline, Duration)
        local Until = Number(Deadline)
        local Seconds = Until and (Until - os.clock()) or Number(Duration)
        return Seconds and math.max(0, Seconds)
    end

    local function NativeModule(FolderName, Modules, Name, Force)
        local GameRoot = Storage:FindFirstChild("ChickenOrHero")
        local Folder = GameRoot and GameRoot:FindFirstChild(FolderName)
        local Module = Folder and Folder:FindFirstChild(Name)
        if not Module or not Module:IsA("ModuleScript") then
            Modules[Name] = nil
            return nil, Name .. " is unavailable."
        end
        local Cached = Modules[Name]
        if Cached and Cached.Instance == Module and not Force then return Cached.Value end
        local Success, Value = pcall(require, Module)
        if not Success or type(Value) ~= "table" then
            Modules[Name] = nil
            return nil, Name .. " could not load: " .. tostring(Value)
        end
        Modules[Name] = { Instance = Module, Value = Value }
        return Value
    end

    local function MovementModule(Name, Force)
        return NativeModule("Movement", MovementModules, Name, Force)
    end

    function Context.ReadGameModule(Name, Force)
        if not Context.Alive then return nil, "Session unloaded." end
        return NativeModule("Game", GameModules, Name, Force)
    end

    local function ReadGates(Force)
        local Gate, Error = MovementModule("ControlGate", Force)
        local Result = { Checked = false, Error = Error }
        if not Context.Alive then return Result end
        if not Gate then return Result end
        for _, Entry in ipairs({ { "movementReason", "MovementReason" }, { "reason", "InputReason" } }) do
            if type(Gate[Entry[1]]) ~= "function" then
                Result.Error = "ControlGate." .. Entry[1] .. " is unavailable."
                return Result
            end
            local Success, Reason = pcall(Gate[Entry[1]], Context.Player)
            if not Context.Alive then return Result end
            if not Success or (Reason ~= nil and type(Reason) ~= "string") then
                Result.Error = "ControlGate." .. Entry[1] .. " failed: " .. tostring(Reason)
                return Result
            end
            Result[Entry[2]] = Reason
        end
        Result.Checked = true
        return Result
    end

    function Context.CheckControlGates()
        if not Context.Alive then return { Checked = false, Error = "Session unloaded." } end
        local Gates = ReadGates(false)
        if Context.Alive then Context.State.ControlGates = Gates end
        return Gates
    end

    local function ReadProfile(Force, Role)
        local Profiles, Error = MovementModule("MovementProfiles", Force)
        if not Context.Alive then return nil, "Session unloaded." end
        if not Profiles then return nil, Error end
        if type(Profiles.get) ~= "function" then return nil, "MovementProfiles.get is unavailable." end
        local Success, Profile = pcall(Profiles.get, Role or Attributes(Context.Player).GameRole, Context.Player)
        if not Success or type(Profile) ~= "table" then return nil, "Could not read movement profile: " .. tostring(Profile) end
        if not Number(Profile.MaxSpeed) or not Number(Profile.Acceleration) then
            return nil, "MovementProfiles returned an invalid speed profile."
        end
        return Profile
    end

    function Context.GetMovementProfile(Role)
        if not Context.Alive then return nil, "Session unloaded." end
        return ReadProfile(false, Role)
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

    function Context.ReadMovementSettings()
        if not Context.Alive then return false end
        local Config, Error = MovementModule("MovementConfig", true)
        if not Context.Alive then return false end
        if Config and (not Number(Config.MaxSpeed) or type(Config.Dash) ~= "table") then
            Config, Error = nil, "MovementConfig returned invalid movement settings."
        end
        Context.State.MovementConfig = Config
        Context.State.MovementConfigError = Error
        local Gates = ReadGates(true)
        if not Context.Alive then return false end
        Context.State.ControlGates = Gates
        if Error or Gates.Error then Context.Notify("Movement settings unavailable", Error or Gates.Error, 3) end
        Context.RefreshData()
        return Config ~= nil and Gates.Checked
    end

    local function DashBlockReason(Character)
        if Context.Player.Character ~= Character then return "Character changed; request dash again." end
        local Human = Humanoid(Context.Player)
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local CharacterAttributes = Attributes(Character)
        local Recovery = Remaining(CharacterAttributes.BoostRecoveryUntil)
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
        elseif Recovery and Recovery > 0 then
            Reason = "Dash is recovering."
        elseif CharacterAttributes.MovementState == "Boosting" or CharacterAttributes.MovementState == "Dashing" then
            Reason = "Dash is already active."
        end
        local Cooldown = Remaining(CharacterAttributes.DashCooldownUntil, CharacterAttributes.DashCooldown)
        if not Reason and Cooldown and Cooldown > 0 then Reason = "Dash is cooling down." end
        if not Reason then Reason = SessionMovementReason() end
        if not Reason and Context.State.Spectating then Reason = "Stop spectating before requesting dash." end
        return Reason
    end

    function Context.RequestDash(TouchStyle)
        if not Context.Alive then return false end
        local Character = Context.Player.Character
        local Reason = DashBlockReason(Character)
        if Reason then Context.Notify("Dash unavailable", Reason, 3); return false end
        local Gates = ReadGates(false)
        if not Context.Alive then return false end
        Context.State.ControlGates = Gates
        Reason = Gates.Error or Gates.MovementReason or Gates.InputReason
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
        -- Native callbacks can yield; recheck the session and input gate before queuing.
        Gates = ReadGates(false)
        if not Context.Alive then return false end
        Context.State.ControlGates = Gates
        Reason = DashBlockReason(Character) or Gates.Error or Gates.MovementReason or Gates.InputReason
        if Reason then Context.Notify("Dash unavailable", Reason, 3); return false end
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

    local function SettingsRows(Settings, Prefix, Rows, Depth)
        if type(Settings) ~= "table" or Depth > 2 then return end
        for Name, Value in pairs(Settings) do
            if type(Value) == "table" then
                SettingsRows(Value, Prefix .. "." .. tostring(Name), Rows, Depth + 1)
            elseif type(Value) ~= "function" then
                table.insert(Rows, Prefix .. "." .. tostring(Name) .. " = " .. tostring(Value))
            end
        end
    end

    function Context.DescribeSettings(Settings, Prefix)
        local Rows = {}
        SettingsRows(Settings, Prefix, Rows, 0)
        table.sort(Rows)
        return Rows
    end

    function Context.RefreshData()
        if not Context.Alive then return Context.State.Snapshot end
        local Snapshot = {
            Runners = {}, Chasers = {}, Unknown = 0,
            Role = Context.GetRole(Context.Player),
            RoundInfo = {}, AbilityInfo = {}, ConsumableInfo = {}, Stats = {}, Tools = {}, MovementDetails = {},
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
        local RoundSession = Session()
        Snapshot.Session = RoundSession and Attributes(RoundSession)
        for Name, Value in pairs(Snapshot.Session or {}) do
            table.insert(Snapshot.RoundInfo, "Session." .. Name .. " = " .. tostring(Value))
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
        Snapshot.Movement = {
            State = MovementAttributes.MovementState,
            Speed = Number(MovementAttributes.MovementSpeed),
            DashReady = MovementAttributes.DashReady,
            DashCount = Number(MovementAttributes.DashCount),
            DashCooldown = Remaining(MovementAttributes.DashCooldownUntil, MovementAttributes.DashCooldown),
            Recovery = Remaining(MovementAttributes.BoostRecoveryUntil),
            LastDashDistance = Number(MovementAttributes.LastDashDistance),
            LastDashEntrySpeed = Number(MovementAttributes.LastDashEntrySpeed),
            FacingPaceMultiplier = Number(MovementAttributes.FacingPaceMultiplier),
            BlockReason = MovementAttributes.MovementBlockReason,
        }
        Snapshot.ControlGates = Context.State.ControlGates or { Checked = false }
        Snapshot.Movement.BlockReason = Snapshot.ControlGates.MovementReason or SessionMovementReason() or Snapshot.Movement.BlockReason
        Snapshot.MovementProfile = Context.State.MovementProfile
        Snapshot.MovementConfig = Context.State.MovementConfig
        SettingsRows(Snapshot.MovementConfig, "Config", Snapshot.MovementDetails, 0)
        SettingsRows(Snapshot.MovementProfile, "Profile", Snapshot.MovementDetails, 0)
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        if Root and Root:IsA("BasePart") then
            local Velocity = Root.AssemblyLinearVelocity
            Snapshot.Speed = math.sqrt(Velocity.X * Velocity.X + Velocity.Z * Velocity.Z)
        end
        for _, Key in ipairs({ "RoundInfo", "AbilityInfo", "ConsumableInfo", "Tools", "MovementDetails" }) do
            table.sort(Snapshot[Key])
        end
        Context.State.Snapshot = Snapshot
        UpdateSpectating()
        for _, Entry in ipairs(Subscribers) do Deliver(Entry, Snapshot) end
        return Snapshot
    end

    function Context.Subscribe(Callback, Name)
        local Entry = { Callback = Callback, Name = Name or ("Panel " .. tostring(#Subscribers + 1)) }
        table.insert(Subscribers, Entry)
        Deliver(Entry, Context.State.Snapshot)
    end

    function Context.RefreshCatalogs(NoPublish)
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
        if not NoPublish then Context.RefreshData() end
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
        table.clear(Watches)
    end)
    Context.RefreshData()
    Context.RefreshCatalogs()
    Context.WatchData("Movement profile", function()
        local Profile, Error = ReadProfile(false)
        if not Context.Alive then return end
        Context.State.MovementProfile, Context.State.MovementProfileError = Profile, Error
    end, 0.25)
    Context.WatchData("Movement settings", function()
        local Config, Error = MovementModule("MovementConfig")
        if not Context.Alive then return end
        if Config and (not Number(Config.MaxSpeed) or type(Config.Dash) ~= "table") then
            Config, Error = nil, "MovementConfig returned invalid movement settings."
        end
        Context.State.MovementConfig, Context.State.MovementConfigError = Config, Error
    end, 1)
    Context.WatchData("Control gates", function()
        local Gates = ReadGates(false)
        if Context.Alive then Context.State.ControlGates = Gates end
    end, 0.25)
    local CatalogWatch = Context.WatchData("Catalogs", function() Context.RefreshCatalogs(true) end, 2)
    for _, Signal in ipairs({ Storage.DescendantAdded, Storage.DescendantRemoving }) do
        Context.Connect(Signal, function() CatalogWatch.NextAt = 0 end)
    end
    Context.Connect(game:GetService("RunService").Heartbeat, function(DeltaTime)
        Clock = Clock + DeltaTime
        for _, Watch in ipairs(Watches) do
            if Clock >= Watch.NextAt and not Watch.Running then
                Watch.NextAt = Clock + Watch.Interval
                RunLive(Watch, Watch.Callback)
            end
        end
        Elapsed = Elapsed + DeltaTime
        if Elapsed >= 0.25 then
            Elapsed = Elapsed % 0.25
            Context.RefreshData()
        end
    end)
end
