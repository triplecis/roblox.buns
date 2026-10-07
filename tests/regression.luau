-- run.ps1 passes the actual loader and module sources to this test suite.
return function(Sources)
local Passed = 0
local function Equal(Actual, Expected)
    assert(Actual == Expected, string.format("expected %s, got %s", tostring(Expected), tostring(Actual)))
end
local function Near(Actual, Expected)
    assert(math.abs(Actual - Expected) < 0.00001, string.format("expected %s, got %s", Expected, Actual))
end
local function Test(Name, Callback)
    local Success, Error = pcall(Callback)
    assert(Success, Name .. ": " .. tostring(Error))
    Passed += 1
    print("PASS " .. Name)
end

local function Node(Name, ClassName, Children)
    local Object = { Name = Name, ClassName = ClassName or "Folder", Children = Children or {}, Attributes = {} }
    function Object:GetAttributes() return table.clone(self.Attributes) end
    function Object:GetDescendants()
        local Result = {}
        local function Visit(Parent)
            for _, Child in ipairs(Parent:GetChildren()) do
                table.insert(Result, Child)
                Visit(Child)
            end
        end
        Visit(self)
        return Result
    end
    function Object:GetFullName()
        return self.Parent and (self.Parent:GetFullName() .. "." .. self.Name) or self.Name
    end
    function Object:GetChildren() return table.clone(self.Children) end
    function Object:FindFirstChild(ChildName)
        for _, Child in ipairs(self.Children) do
            if Child.Name == ChildName then return Child end
        end
        return nil
    end
    function Object:FindFirstChildOfClass(Class)
        for _, Child in ipairs(self.Children) do
            if Child:IsA(Class) then return Child end
        end
        return nil
    end
    function Object:IsA(Class)
        return self.ClassName == Class or (Class == "ValueBase" and self.ClassName == "NumberValue")
            or (Class == "BasePart" and self.ClassName == "Part")
    end
    return Object
end

local function Fixture(Options)
    Options = Options or {}
    local F = { Queue = {}, Connections = {}, Notifications = {}, Warnings = {}, Requests = {}, Overrides = {} }
    F.Global = {}
    function F:Flush()
        local Iterations = 0
        while #self.Queue > 0 do
            Iterations += 1
            assert(Iterations < 100, "property signal feedback loop")
            local Queue = self.Queue
            self.Queue = {}
            for _, Callback in ipairs(Queue) do Callback() end
        end
    end
    function F:Signal(Deferred)
        local Signal = { Listeners = {} }
        function Signal:Connect(Callback)
            local Connection = { Connected = true }
            function Connection:Disconnect() self.Connected = false end
            Connection.Callback = Callback
            table.insert(self.Listeners, Connection)
            table.insert(F.Connections, Connection)
            return Connection
        end
        function Signal:Fire(...)
            local Arguments = table.pack(...)
            for _, Connection in ipairs(table.clone(self.Listeners)) do
                if Connection.Connected then
                    local function Deliver()
                        if Connection.Connected then Connection.Callback(table.unpack(Arguments, 1, Arguments.n)) end
                    end
                    if Deferred then table.insert(F.Queue, Deliver) else Deliver() end
                end
            end
        end
        return Signal
    end
    function F:Humanoid(Speed, Power, Height)
        local Properties = {
            WalkSpeed = Speed or 16, JumpPower = Power or 50, JumpHeight = Height or 7.2,
            UseJumpPower = true, AutoRotate = true, Parent = true, Name = "Humanoid",
            Health = 100, Sit = false, PlatformStand = false, FloorMaterial = "Ground",
        }
        local Signals = {}
        local Methods = {}
        function Methods:IsA(Class) return Class == "Humanoid" end
        function Methods:GetChildren() return {} end
        function Methods:GetPropertyChangedSignal(Property)
            Signals[Property] = Signals[Property] or F:Signal(Options.Deferred)
            return Signals[Property]
        end
        return setmetatable({}, {
            __index = function(_, Key) return Methods[Key] or Properties[Key] end,
            __newindex = function(_, Key, Value)
                local Old = Properties[Key]
                Properties[Key] = Value
                if Old ~= Value and Signals[Key] then Signals[Key]:Fire() end
            end,
        })
    end
    function F:Character(Humanoid)
        local Character = Node("Character", "Model", Humanoid and { Humanoid } or {})
        Character.ChildAdded = self:Signal()
        return Character
    end
    F.Player = {
        Name = "LocalUser", DisplayName = "Local Player", UserId = 1,
        CharacterAdded = F:Signal(), CharacterRemoving = F:Signal(),
        Attributes = {}, Children = {},
    }
    F.Player.GetAttributes = Node("Player").GetAttributes
    F.Player.FindFirstChild = Node("Player").FindFirstChild
    F.Player.FindFirstChildOfClass = Node("Player").FindFirstChildOfClass
    F.Hum = F:Humanoid()
    if not Options.NoCharacter then F.Player.Character = F:Character(F.Hum) end
    F.OtherPlayer = { Name = "OtherUser", DisplayName = "Other Player", UserId = 2, Attributes = {} }
    F.OtherPlayer.GetAttributes = F.Player.GetAttributes
    F.Players = {
        LocalPlayer = not Options.NoPlayer and F.Player or nil,
        PlayerAdded = F:Signal(), PlayerRemoving = F:Signal(),
        List = { F.Player, F.OtherPlayer },
    }
    function F.Players:GetPlayers() return table.clone(self.List) end
    F.Storage = Node("ReplicatedStorage")
    F.Content = Node("Content", "Folder", {
        Node("Items", "Folder", { Node("Salmon"), Node("Carp"), Node("Pickaxe"), Node("FishBush") }),
        Node("Ores", "Folder", { Node("Copper"), Node("Copper"), Node("CopperBush"), Node("Iron") }),
        Node("Trees", "Folder", { Node("Oak"), Node("Pine"), Node("Bush") }),
        Node("BigFish", "Folder", { Node("Salmon"), Node("Carp"), Node("FishBush"), Node("InvalidFish") }),
    })
    if not Options.NoContent then table.insert(F.Storage.Children, F.Content) end
    F.ClockTime = Node("ClockTime", "NumberValue")
    F.ClockTime.Value = 13.5
    F.Workspace = Node("Workspace", "Folder", {
        Node("ServerData", "Folder", { Node("CurrentCycle", "Folder", { F.ClockTime }) }),
    })
    F.Workspace.DistributedGameTime = 10
    F.ServerTime = 100
    function F.Workspace:GetServerTimeNow() return F.ServerTime end
    F.Workspace.CurrentCamera = { CameraSubject = F.Hum, CameraType = "Custom", FieldOfView = 70 }
    F.Heartbeat = F:Signal()
    F.InputService = { InputBegan = F:Signal(), InputEnded = F:Signal(), WindowFocusReleased = F:Signal() }
    function F.InputService:GetFocusedTextBox() return self.FocusedTextBox end
    F.Marketplace = { Calls = 0 }
    function F.Marketplace:GetProductInfo()
        self.Calls += 1
        if Options.NoInfo then error("metadata unavailable") end
        return { Name = "Test Game", Description = "Test description" }
    end
    F.Services = {
        Players = F.Players, ReplicatedStorage = F.Storage,
        MarketplaceService = F.Marketplace, RunService = { Heartbeat = F.Heartbeat },
        UserInputService = F.InputService,
    }
    F.Game = { PlaceId = 12345, GameId = Options.GameId or 4298676072, JobId = "job" }
    function F.Game:GetService(Name) return assert(F.Services[Name], "unknown service " .. Name) end
    function F.Game:HttpGet(URL)
        table.insert(F.Requests, URL)
        if string.find(URL, "MentalityUI", 1, true) then
            if Options.LibraryFailure then error("library network failure") end
            return "return TestLibrary"
        end
        local Path = URL:match("/refs/heads/main/(.*)$")
        if F.BeforeResponse then F.BeforeResponse(Path) end
        local Override = F.Overrides[Path]
        if Override == false then error("HTTP failure for " .. tostring(Path)) end
        if Override ~= nil then return Override end
        return assert(Sources[Path], "unknown module path " .. tostring(Path))
    end

    function F:Library()
        local Library = { Folders = {}, Controls = {}, Buttons = {}, Labels = {}, Notifications = self.Notifications, Unloads = 0 }
        function Library:Notification(Info)
            if F.FailNotification then error("notification failure") end
            table.insert(self.Notifications, Info)
        end
        function Library:Unload() self.Unloads += 1 end
        local Section = {}
        function Section:Label(Text)
            local Label = { Text = Text }
            function Label:SetText(Value) self.Text = Value end
            table.insert(Library.Labels, Label)
            return Label
        end
        function Section:Button(Data)
            Library.Buttons[Data.Name] = Data.Callback
            return Data
        end
        local function Control(Data, Kind)
            local Object = { Value = Data.Default or (Kind == "Listbox" and {} or false), Items = Data.Items }
            function Object:Set(Value, SkipCallback)
                self.Value = Value
                if Data.Callback and not SkipCallback then Data.Callback(Value) end
            end
            function Object:Settings() return Section end
            function Object:Refresh(Items)
                self.Refreshes = (self.Refreshes or 0) + 1
                self.Items = table.clone(Items)
                self.Value = {}
            end
            Library.Controls[Data.Flag] = Object
            return Object
        end
        function Section:Toggle(Data) return Control(Data, "Toggle") end
        function Section:Slider(Data) return Control(Data, "Slider") end
        function Section:Listbox(Data) return Control(Data, "Listbox") end
        local Page = {}
        function Page:Section() return Section end
        local Window = {}
        function Window:Category() end
        function Window:TabDivider() end
        function Window:Page() return Page end
        function Window:DashboardPage(Data)
            Library.Dashboard = Data
            return { AddCard = function() end }
        end
        function Library:Window()
            if Options.WindowFailure then error("window creation failed") end
            return Window
        end
        function Library:KeybindList() return {} end
        function Library:CreateSettingsPage() self.SettingsCreated = true; return Page end
        return Library
    end

    F.Env = setmetatable({
        game = F.Game, workspace = F.Workspace,
        Enum = { CameraType = { Custom = "Custom", Scriptable = "Scriptable" },
            Material = { Air = "Air" },
            KeyCode = { V = "V", LeftShift = "LeftShift", RightShift = "RightShift" } },
        getgenv = function() return F.Global end,
        warn = function(Message) table.insert(F.Warnings, Message) end,
    }, { __index = getfenv() })
    F.Env.loadstring = function(Source, Name)
        local Chunk, Error = loadstring(Source, Name)
        if Chunk then setfenv(Chunk, F.Env) end
        return Chunk, Error
    end
    F.Env.require = function(Module)
        F.RequireCalls = (F.RequireCalls or 0) + 1
        if Module.ModuleError then error(Module.ModuleError) end
        return Module.ModuleValue
    end
    local VectorMeta = { __type = "Vector3", __eq = function(A, B) return A.X == B.X and A.Y == B.Y and A.Z == B.Z end }
    F.Env.typeof = function(Value)
        local Meta = type(Value) == "table" and getmetatable(Value)
        return Meta and Meta.__type or type(Value)
    end
    F.Spawned = {}
    F.Env.task = { spawn = function(Callback)
        local Thread = coroutine.create(Callback)
        table.insert(F.Spawned, Thread)
        local Success, Error = coroutine.resume(Thread)
        assert(Success, Error)
        return Thread
    end }
    F.Env.Vector3 = { new = function(X, Y, Z) return setmetatable({ X = X, Y = Y, Z = Z }, VectorMeta) end }
    F.Env.Color3 = { fromRGB = function(R, G, B) return { R, G, B } end }
    F.Boxes = {}
    F.Env.Instance = { new = function(Class)
        Equal(Class, "SelectionBox")
        local Box = { ClassName = Class }
        function Box:Destroy() self.Destroyed = true; self.Parent = nil end
        table.insert(F.Boxes, Box)
        return Box
    end }
    function F:EnableHooks()
        self.Hooks = {}
        self.Env.hookfunction = function(Target, Replacement)
            local Entry = assert(self.Hooks[Target], "unregistered hook target")
            local Previous = Entry.Current
            Entry.Current = Replacement
            return Previous
        end
    end
    function F:Hookable(Callback)
        local Entry = { Current = Callback }
        local Target = function(...) return Entry.Current(...) end
        self.Hooks[Target] = Entry
        return Target
    end
    function F:Load()
        self.Lib = self:Library()
        self.Env.TestLibrary = self.Lib
        local Chunk = assert(self.Env.loadstring(Sources["loader.lua"], "=loader.lua"))
        self.Context = Chunk()
        return self.Context
    end
    function F:ContainsLabel(Text)
        for _, Label in ipairs(self.Lib.Labels) do
            if Label.Text == Text then return true end
        end
        return false
    end
    function F:ActiveConnections()
        local Count = 0
        for _, Connection in ipairs(self.Connections) do
            if Connection.Connected then Count += 1 end
        end
        return Count
    end
    function F:NoModuleErrors()
        for _, Notification in ipairs(self.Notifications) do
            assert(not Notification.Title:find("failed", 1, true), Notification.Description)
        end
        Equal(#self.Warnings, 0)
    end
    return F
end

Test("complete RC2 startup and settings", function()
    local F = Fixture()
    local Context = assert(F:Load())
    F:NoModuleErrors()
    Equal(F.Marketplace.Calls, 1)
    Equal(Context.GameName, "Test Game")
    Equal(F.Lib.SettingsCreated, true)
    Equal(F.Lib.Folders.Configs, "roblox.buns/Configs/4298676072")
    assert(F:ContainsLabel("Purchasing is not implemented."))
    assert(F:ContainsLabel("Server time: 13:30"))
    assert(Context.Pages.Settings)
    Context.Destroy()
end)

for _, Deferred in ipairs({ false, true }) do
    Test("movement baselines and jump modes; deferred=" .. tostring(Deferred), function()
        local F = Fixture({ Deferred = Deferred })
        local Context = assert(F:Load())
        local C = F.Lib.Controls
        C.WalkSpeedToggle:Set(true)
        Near(F.Hum.WalkSpeed, 18.56)
        C.WalkSpeedSlider:Set(100)
        F:Flush()
        Near(F.Hum.WalkSpeed, 32)
        C.WalkSpeedSlider:Set(100)
        C.WalkSpeedToggle:Set(true)
        F:Flush()
        Near(F.Hum.WalkSpeed, 32)
        F.Hum.WalkSpeed = 20
        F:Flush()
        Near(F.Hum.WalkSpeed, 40)
        C.WalkSpeedToggle:Set(false)
        F:Flush()
        Near(F.Hum.WalkSpeed, 20)
        F.Hum.WalkSpeed = 24
        C.WalkSpeedToggle:Set(false)
        Near(F.Hum.WalkSpeed, 24)
        C.WalkSpeedToggle:Set(true)
        F:Flush()
        Near(F.Hum.WalkSpeed, 48)
        F.Hum.WalkSpeed = 18
        C.WalkSpeedToggle:Set(false)
        F:Flush()
        Near(F.Hum.WalkSpeed, 18)
        C.JumpPowerSlider:Set(120)
        Near(F.Hum.JumpPower, 50)
        C.JumpPowerToggle:Set(true)
        F:Flush()
        Near(F.Hum.JumpPower, 120)
        F.Hum.JumpPower = 60
        F:Flush()
        Near(F.Hum.JumpPower, 120)
        C.JumpPowerToggle:Set(false)
        F:Flush()
        Near(F.Hum.JumpPower, 60)
        C.JumpHeightSlider:Set(12)
        C.JumpHeightToggle:Set(true)
        F.Hum.UseJumpPower = false
        F:Flush()
        assert(F:ContainsLabel("Jump mode: height"))
        Near(F.Hum.JumpHeight, 12)
        Context.Destroy()
        F:Flush()
        Near(F.Hum.JumpHeight, 7.2)
        Equal(F:ActiveConnections(), 0)
    end)
end

Test("late character and Humanoid do not block startup", function()
    local F = Fixture({ NoCharacter = true })
    local Context = assert(F:Load())
    F:NoModuleErrors()
    Equal(F.Lib.SettingsCreated, true)
    F.Lib.Controls.WalkSpeedSlider:Set(100)
    F.Lib.Controls.WalkSpeedToggle:Set(true)
    local Character = F:Character()
    F.Player.Character = Character
    F.Player.CharacterAdded:Fire(Character)
    local Humanoid = F:Humanoid(10)
    table.insert(Character.Children, Humanoid)
    Character.ChildAdded:Fire(Humanoid)
    Near(Humanoid.WalkSpeed, 20)
    Context.Destroy()
    Near(Humanoid.WalkSpeed, 10)
end)

Test("respawn rebinds controls and disconnects old character", function()
    local F = Fixture({ Deferred = true })
    local Context = assert(F:Load())
    local C = F.Lib.Controls
    C.WalkSpeedSlider:Set(100)
    C.WalkSpeedToggle:Set(true)
    C.JumpHeightSlider:Set(15)
    C.JumpHeightToggle:Set(true)
    F:Flush()
    F.Player.CharacterRemoving:Fire(F.Player.Character)
    local NewHumanoid = F:Humanoid(10, 40, 5)
    F.Player.Character = F:Character(NewHumanoid)
    F.Player.CharacterAdded:Fire(F.Player.Character)
    F:Flush()
    Near(NewHumanoid.WalkSpeed, 20)
    Near(NewHumanoid.JumpHeight, 15)
    F.Hum.WalkSpeed = 500
    F:Flush()
    Near(NewHumanoid.WalkSpeed, 20)
    Context.Destroy()
    F:Flush()
    Near(NewHumanoid.WalkSpeed, 10)
    Near(NewHumanoid.JumpHeight, 5)
    Equal(F:ActiveConnections(), 0)
end)

Test("catalog filtering, deduplication, refresh and stale selections", function()
    local F = Fixture()
    local Context = assert(F:Load())
    local RC2, C = Context.RC2, F.Lib.Controls
    Equal(table.concat(RC2.Catalog.Ores, ","), "Copper,Iron")
    Equal(table.concat(RC2.Catalog.Trees, ","), "Oak,Pine")
    Equal(table.concat(RC2.Catalog.Fishes, ","), "Carp,Salmon")
    Equal(#RC2.Catalog.Oils, 0)
    C.SelectedOres:Set({ "Copper" })
    C.SelectedFishes:Set({ "Salmon" })
    C.SelectedBuyItems:Set({ "Salmon" })
    RC2.RefreshCatalog()
    Equal(table.concat(RC2.Selections.Ores, ","), "Copper")
    F.Content:FindFirstChild("Ores").Children = { Node("Iron") }
    F.Content:FindFirstChild("Items").Children = { Node("Carp"), Node("Pickaxe") }
    table.insert(F.Content.Children, Node("Oils", "Folder", { Node("CrudeOil") }))
    F.Lib.Buttons["Refresh resources"]()
    Equal(#RC2.Selections.Ores, 0)
    Equal(#RC2.Selections.Fishes, 0)
    Equal(#RC2.Selections.BuyItems, 0)
    Equal(table.concat(RC2.Catalog.Oils, ","), "CrudeOil")
    Equal(table.concat(C.SelectedOils.Items, ","), "CrudeOil")
    Context.Destroy()
end)

Test("missing content can arrive after startup", function()
    local F = Fixture({ NoContent = true })
    local Context = assert(F:Load())
    F:NoModuleErrors()
    Equal(#Context.RC2.Catalog.Items, 0)
    table.insert(F.Storage.Children, F.Content)
    Context.RC2.RefreshCatalog()
    Equal(#Context.RC2.Catalog.Fishes, 2)
    Context.Destroy()
end)

Test("live player roster handles joins and PlayerRemoving timing", function()
    local F = Fixture()
    local Context = assert(F:Load())
    local List = F.Lib.Controls.SelectedPlayers
    Equal(#List.Items, 2)
    List:Set({ "Other Player (@OtherUser)" })
    Equal(Context.SelectedPlayers[1], F.OtherPlayer)
    F.Players.PlayerRemoving:Fire(F.OtherPlayer)
    Equal(#List.Items, 1)
    Equal(#Context.SelectedPlayers, 0)
    F.Players.List = { F.Player }
    local NewPlayer = { Name = "Joined", DisplayName = "Joined", UserId = 3 }
    table.insert(F.Players.List, NewPlayer)
    F.Players.PlayerAdded:Fire(NewPlayer)
    Equal(#List.Items, 2)
    assert(F:ContainsLabel("Players: 2"))
    Context.Destroy()
end)

Test("server clock wraps midnight and tolerates missing or invalid data", function()
    local F = Fixture()
    local Context = assert(F:Load())
    F.ClockTime.Value = 24.999
    F.Heartbeat:Fire(1)
    assert(F:ContainsLabel("Server time: 00:59"))
    F.ClockTime.Value = 0 / 0
    F.Heartbeat:Fire(1)
    assert(F:ContainsLabel("Server time unavailable"))
    F.Workspace.Children = {}
    F.Heartbeat:Fire(1)
    assert(F:ContainsLabel("Server time unavailable"))
    F.ClockTime.Value = 7.2
    F.Workspace.Children = { Node("ServerData", "Folder", { Node("CurrentCycle", "Folder", { F.ClockTime }) }) }
    F.Heartbeat:Fire(1)
    assert(F:ContainsLabel("Server time: 07:12"))
    Context.Destroy()
end)

Test("all module failure stages are isolated", function()
    local F = Fixture()
    F.Overrides["games/RC2/modules/main.lua"] = false
    local Context = assert(F:Load())
    assert(F:ContainsLabel("Server time: 13:30"))
    Equal(F.Lib.SettingsCreated, true)
    Equal(F.Notifications[1].Title, "Module download failed")
    Equal(F.Notifications[2].Description, "Loaded 7/8 modules.")
    local Failures = {
        "", "return function(", "error('chunk failed')", "return {}",
        "return function() error('initializer failed') end",
    }
    for _, Source in ipairs(Failures) do
        F.Overrides["bad.lua"] = Source
        Equal(Context.LoadModule("bad.lua"), false)
    end
    F.Overrides["good.lua"] = "return function(Context) Context.TestLoaded = true end"
    Equal(Context.LoadModule("good.lua"), true)
    Equal(Context.TestLoaded, true)
    Context.Destroy()
end)

Test("unsupported game and unavailable metadata preserve universal controls", function()
    local F = Fixture({ GameId = 999, NoInfo = true })
    local Context = assert(F:Load())
    Equal(Context.GameName, "Place 12345")
    Equal(F.Lib.SettingsCreated, true)
    assert(F.Lib.Controls.WalkSpeedToggle)
    Equal(Context.RC2, nil)
    F.Lib.Dashboard.Links[1].Callback()
    Equal(F.Notifications[#F.Notifications].Title, "Clipboard unavailable")
    F.Env.setclipboard = function() error("clipboard blocked") end
    F.Lib.Dashboard.Links[1].Callback()
    Equal(F.Notifications[#F.Notifications].Title, "Clipboard unavailable")
    F.Env.setclipboard = function(Value) F.Copied = Value end
    F.Lib.Dashboard.Links[1].Callback()
    Equal(F.Notifications[#F.Notifications].Title, "Copied")
    Equal(F.Copied, "https://discord.gg/ys78VPnnJQ")
    Context.Destroy()
end)

Test("reload and repeated unload clean up every listener", function()
    local F = Fixture()
    local OldContext = assert(F:Load())
    local OldLibrary = F.Lib
    F.Lib.Controls.WalkSpeedToggle:Set(true)
    local NewContext = assert(F:Load())
    Equal(OldContext.Alive, false)
    Equal(OldLibrary.Unloads, 1)
    Near(F.Hum.WalkSpeed, 16)
    Equal(F.Global.RobloxBunsContext, NewContext)
    local Recovered = false
    NewContext.AddCleanup(function() Recovered = true end)
    NewContext.AddCleanup(function() error("cleanup failed") end)
    F.Lib:Unload()
    Equal(Recovered, true)
    Equal(F:ActiveConnections(), 0)
    Equal(F.Lib.Unloads, 1)
    Equal(F.Global.RobloxBunsContext, nil)
    NewContext.Destroy()
    Equal(F.Lib.Unloads, 1)
    Equal(NewContext.LoadModule("good.lua"), false)
end)

Test("startup failures return cleanly", function()
    local NoPlayer = Fixture({ NoPlayer = true })
    Equal(NoPlayer:Load(), nil)
    Equal(#NoPlayer.Requests, 0)
    local NoLibrary = Fixture({ LibraryFailure = true })
    Equal(NoLibrary:Load(), nil)
    Equal(#NoLibrary.Warnings, 1)
    local NoWindow = Fixture({ WindowFailure = true })
    Equal(NoWindow:Load(), nil)
    Equal(NoWindow.Lib.Unloads, 1)
    Equal(NoWindow.Global.RobloxBunsContext, nil)
end)

Test("unload during a module request prevents stale initialization", function()
    local F = Fixture()
    local Context = assert(F:Load())
    F.Overrides["late.lua"] = "return function() error('stale initializer ran') end"
    F.BeforeResponse = function(Path)
        if Path == "late.lua" then Context.Destroy() end
    end
    Equal(Context.LoadModule("late.lua"), false)
    Equal(F:ActiveConnections(), 0)
    Equal(#F.Warnings, 0)
end)

Test("Huss Valley loads without assuming game data exists", function()
    local F = Fixture({ GameId = 10764627709, NoContent = true, NoCharacter = true })
    local Context = assert(F:Load())
    F:NoModuleErrors()
    Equal(F.Notifications[1].Description, "Loaded 11/11 modules.")
    Equal(Context.HussValley.State.Snapshot.Role, "Unknown")
    Equal(Context.HussValley.State.Snapshot.Unknown, 2)
    Equal(#Context.HussValley.State.Catalogs.Abilities.Entries, 0)
    Equal(#Context.HussValley.State.Catalogs.Consumables.Entries, 0)
    assert(F:ContainsLabel("Round information is not exposed."))
    assert(F:ContainsLabel("No public leaderboard stats available."))
    F.Heartbeat:Fire(0.5)
    Context.Destroy()
    Equal(F:ActiveConnections(), 0)
end)

Test("Huss Valley role rosters change without rebuilding unchanged lists", function()
    local F = Fixture({ GameId = 10764627709 })
    F.Player.Attributes.Role = "Runner"
    F.OtherPlayer.Team = { Name = "Chasers" }
    F.OtherPlayer.Neutral = false
    local Context = assert(F:Load())
    local HV, C = Context.HussValley, F.Lib.Controls
    F:NoModuleErrors()
    Equal(#HV.State.Snapshot.Runners, 1)
    Equal(#HV.State.Snapshot.Chasers, 1)
    Equal(C.HussValleyChasersSelected.Items[1], "Other Player (@OtherUser)")
    local Refreshes = C.HussValleyChasersSelected.Refreshes
    HV.RefreshData()
    Equal(C.HussValleyChasersSelected.Refreshes, Refreshes)
    C.HussValleyChasersSelected:Set({ "Other Player (@OtherUser)" })
    F.OtherPlayer.Attributes.Role = "Runner"
    F.Heartbeat:Fire(0.5)
    Equal(#HV.State.Snapshot.Runners, 2)
    Equal(#C.HussValleyChasersSelected.Value, 0)
    F.OtherPlayer.Attributes.Role = nil
    F.OtherPlayer.Neutral = true
    F.Heartbeat:Fire(0.5)
    Equal(HV.State.Snapshot.Unknown, 1)
    F.Player.Attributes.Role = nil
    F.Player.Character.Attributes.Role = "Chaser"
    F.Heartbeat:Fire(0.5)
    Equal(HV.State.Snapshot.Role, "Chasers")
    Context.Destroy()
end)

Test("Huss Valley spectating follows respawns and restores replaced cameras", function()
    local F = Fixture({ GameId = 10764627709 })
    F.OtherPlayer.Attributes.Role = "Chaser"
    local Target = F:Humanoid()
    F.OtherPlayer.Character = F:Character(Target)
    local Context = assert(F:Load())
    local HV = Context.HussValley
    local Camera = F.Workspace.CurrentCamera
    Camera.CameraType = "Scriptable"
    F.Lib.Controls.HussValleyChasersSelected:Set({ "Other Player (@OtherUser)" })
    F.Lib.Buttons["Spectate selected catchers"]()
    Equal(Camera.CameraSubject, Target)
    Equal(Camera.CameraType, "Custom")
    local Respawned = F:Humanoid()
    F.OtherPlayer.Character = F:Character(Respawned)
    F.Heartbeat:Fire(0.5)
    Equal(Camera.CameraSubject, Respawned)
    local NewCamera = { CameraSubject = F.Hum, CameraType = "Scriptable", FieldOfView = 60 }
    F.Workspace.CurrentCamera = NewCamera
    F.Heartbeat:Fire(0.5)
    Equal(Camera.CameraSubject, F.Hum)
    Equal(Camera.CameraType, "Scriptable")
    Equal(NewCamera.CameraSubject, Respawned)
    F.Players.List = { F.Player }
    F.Heartbeat:Fire(0.5)
    Equal(NewCamera.CameraSubject, F.Hum)
    Equal(NewCamera.CameraType, "Scriptable")
    Equal(HV.State.Spectating, nil)
    Equal(HV.SpectatePlayer(nil), false)
    Context.Destroy()
end)

Test("Huss Valley restores the current local character after a local respawn", function()
    local F = Fixture({ GameId = 10764627709 })
    F.OtherPlayer.Character = F:Character(F:Humanoid())
    local Context = assert(F:Load())
    local HV = Context.HussValley
    assert(HV.SpectatePlayer(F.OtherPlayer))
    F.Hum.Parent = nil
    local LocalHumanoid = F:Humanoid()
    F.Player.Character = F:Character(LocalHumanoid)
    HV.StopSpectating()
    Equal(F.Workspace.CurrentCamera.CameraSubject, LocalHumanoid)
    Context.Destroy()
end)

Test("Huss Valley FOV and turning controls restore values across respawns", function()
    local F = Fixture({ GameId = 10764627709 })
    local Root = Node("HumanoidRootPart", "Part")
    Root.AssemblyLinearVelocity = { X = 3, Y = 100, Z = 4 }
    table.insert(F.Player.Character.Children, Root)
    local Context = assert(F:Load())
    local HV, C = Context.HussValley, F.Lib.Controls
    Near(HV.State.Snapshot.Speed, 5)
    C.HussValleyFOV:Set(95)
    Near(F.Workspace.CurrentCamera.FieldOfView, 70)
    C.HussValleyFOVEnabled:Set(true)
    C.HussValleyFOVEnabled:Set(true)
    Near(F.Workspace.CurrentCamera.FieldOfView, 95)
    C.HussValleyFOVEnabled:Set(false)
    Near(F.Workspace.CurrentCamera.FieldOfView, 70)
    C.HussValleyFOVEnabled:Set(true)
    F.Workspace.CurrentCamera.FieldOfView = 76
    F.Heartbeat:Fire(0.5)
    Near(F.Workspace.CurrentCamera.FieldOfView, 95)
    C.HussValleyDisableAutoRotate:Set(true)
    Equal(F.Hum.AutoRotate, false)
    local NewHumanoid = F:Humanoid()
    F.Player.Character = F:Character(NewHumanoid)
    local OldCamera = F.Workspace.CurrentCamera
    local NewCamera = { FieldOfView = 60, CameraSubject = NewHumanoid, CameraType = "Custom" }
    F.Workspace.CurrentCamera = NewCamera
    F.Heartbeat:Fire(0.5)
    Near(OldCamera.FieldOfView, 76)
    Near(NewCamera.FieldOfView, 95)
    Equal(F.Hum.AutoRotate, true)
    Equal(NewHumanoid.AutoRotate, false)
    Context.Destroy()
    Near(NewCamera.FieldOfView, 60)
    Equal(NewHumanoid.AutoRotate, true)
    Equal(F:ActiveConnections(), 0)
end)

Test("Huss Valley catalogs refresh definitions without executing scripts", function()
    local F = Fixture({ GameId = 10764627709, NoContent = true })
    local Context = assert(F:Load())
    local HV, C = Context.HussValley, F.Lib.Controls
    local Cloak = Node("Cloak", "ModuleScript")
    local Nested = Node("RunnerAbilities", "Folder", { Cloak })
    local Abilities = Node("Abilities", "Folder", { Nested, Node("UseAbility", "RemoteEvent") })
    Nested.Parent = Abilities
    Abilities.Parent = F.Storage
    local Consumables = Node("Consumables", "Folder", { Node("Banana Peel", "Model") })
    Consumables.Parent = F.Storage
    table.insert(F.Storage.Children, Abilities)
    table.insert(F.Storage.Children, Consumables)
    F.Lib.Buttons["Refresh abilities"]()
    Equal(#HV.State.Catalogs.Abilities.Entries, 1)
    Equal(#HV.State.Catalogs.Consumables.Entries, 1)
    Equal(C.HussValleySelectedAbilities.Items[1], "ReplicatedStorage.Abilities/RunnerAbilities/Cloak")
    C.HussValleySelectedAbilities:Set(table.clone(C.HussValleySelectedAbilities.Items))
    Equal(#HV.State.SelectedAbilities, 1)
    Nested.Children = {}
    F.Lib.Buttons["Refresh consumables"]()
    Equal(#HV.State.SelectedAbilities, 0)
    local Backpack = Node("Backpack", "Backpack", { Node("Tool A", "Tool") })
    table.insert(F.Player.Children, Backpack)
    table.insert(F.Player.Character.Children, Node("Tool A", "Tool"))
    table.insert(F.Player.Character.Children, Node("Tool B", "Tool"))
    F.Player.Attributes.EquippedAbility = "Cloak"
    F.Player.Attributes.Consumable = "Banana Peel"
    F.Heartbeat:Fire(0.5)
    Equal(table.concat(C.HussValleyInventory.Items, ","), "Tool A,Tool B")
    Equal(C.HussValleyAbilityInfo.Items[1], "Player.EquippedAbility = Cloak")
    Equal(C.HussValleyConsumableInfo.Items[1], "Player.Consumable = Banana Peel")
    Context.Destroy()
end)

Test("Huss Valley round metadata and session stats handle delayed data", function()
    local F = Fixture({ GameId = 10764627709 })
    local Context = assert(F:Load())
    local C = F.Lib.Controls
    F.Workspace.Attributes.RoundPhase = "Crossing"
    local Crossing = Node("Crossing", "NumberValue")
    Crossing.Value = 2
    table.insert(F.Workspace.Children, Node("RoundData", "Folder", { Crossing }))
    local Gems = Node("Gems", "NumberValue")
    Gems.Value = 100
    local Leaderstats = Node("leaderstats", "Folder", { Gems })
    table.insert(F.Player.Children, Leaderstats)
    F.Heartbeat:Fire(0.5)
    Equal(table.concat(C.HussValleyRoundInfo.Items, ","), "Workspace.RoundData.Crossing = 2,Workspace.RoundPhase = Crossing")
    Equal(C.HussValleyRewardStats.Items[1], "Gems: 100 (session +0)")
    Gems.Value = 125
    F.Heartbeat:Fire(0.5)
    Equal(C.HussValleyRewardStats.Items[1], "Gems: 125 (session +25)")
    Gems.Value = 90
    F.Heartbeat:Fire(0.5)
    Equal(C.HussValleyRewardStats.Items[1], "Gems: 90 (session -10)")
    F.Lib.Buttons["Reset session gains"]()
    Equal(C.HussValleyRewardStats.Items[1], "Gems: 90 (session +0)")
    Leaderstats.Children = {}
    F.Heartbeat:Fire(0.5)
    Equal(#C.HussValleyRewardStats.Items, 0)
    Context.Destroy()
end)

local function HussMovementFixture()
    local F = Fixture({ GameId = 10764627709 })
    F.Player.Attributes.GameRole = "Runner"
    local Root = Node("HumanoidRootPart", "Part")
    Root.AssemblyLinearVelocity = { X = 0, Y = 0, Z = 0 }
    Root.Anchored = false
    Root.Parent = F.Player.Character
    Root.Size = F.Env.Vector3.new(2, 2, 1)
    Root.CanCollide = false
    table.insert(F.Player.Character.Children, Root)
    F.Root = Root
    F.MovementFolder = Node("Movement")
    table.insert(F.Storage.Children, Node("ChickenOrHero", "Folder", { F.MovementFolder }))
    function F:AddModule(Name, Value)
        local Module = Node(Name, "ModuleScript")
        Module.ModuleValue = Value
        table.insert(self.MovementFolder.Children, Module)
        return Module
    end
    F.ControlGate = F:AddModule("ControlGate", {
        movementReason = function(Player) Equal(Player, F.Player); return F.MovementBlock end,
        reason = function(Player) Equal(Player, F.Player); return F.InputBlock end,
    })
    return F
end

Test("Huss Valley GameRole is authoritative and Catchers are recognized", function()
    local F = Fixture({ GameId = 10764627709 })
    F.Player.Attributes.Role = "Runner"
    F.Player.Attributes.GameRole = "Catcher"
    local Context = assert(F:Load())
    Equal(Context.HussValley.State.Snapshot.Role, "Chasers")
    Equal(#Context.HussValley.State.Snapshot.Chasers, 1)
    assert(F:ContainsLabel("Your role: Catcher"))
    F.Player.Attributes.GameRole = "Lobby"
    F.Heartbeat:Fire(0.5)
    Equal(Context.HussValley.State.Snapshot.Role, "Unknown")
    Context.Destroy()
end)

Test("Huss Valley reads native movement telemetry and frozen profiles", function()
    local F = HussMovementFixture()
    local Base = table.freeze({ MaxSpeed = 24, Acceleration = 12 })
    local Slowed = table.freeze({ MaxSpeed = 13.2, Acceleration = 8.4 })
    F:AddModule("MovementProfiles", {
        get = function(Role, Player)
            Equal(Role, "Runner")
            Equal(Player, F.Player)
            return Player.Attributes.GearSlow and Slowed or Base
        end,
    })
    local A = F.Player.Character.Attributes
    A.MovementState = "Dashing"
    A.MovementSpeed = 30
    A.DashReady = true
    A.DashCooldownUntil = os.clock() + 60
    A.DashCount = 3
    A.LastDashDistance = 12
    local Context = assert(F:Load())
    local HV = Context.HussValley
    Equal(F.RequireCalls, nil)
    Equal(HV.State.Snapshot.Movement.State, "Dashing")
    Equal(HV.State.Snapshot.Movement.Speed, 30)
    assert(HV.State.Snapshot.Movement.DashCooldown > 50)
    F.Lib.Buttons["Read movement profile"]()
    Equal(F.RequireCalls, 1)
    Equal(HV.State.Snapshot.MovementProfile, Base)
    assert(table.isfrozen(Base))
    F.Player.Attributes.GearSlow = true
    F.Heartbeat:Fire(0.5)
    Equal(HV.State.Snapshot.MovementProfile, Slowed)
    Equal(F.RequireCalls, 2) -- Automatic ControlGate discovery also loaded once.
    Near(Base.MaxSpeed, 24)
    A.DashCooldownUntil = os.clock() - 1
    F.Heartbeat:Fire(0.5)
    Near(HV.State.Snapshot.Movement.DashCooldown, 0)
    Context.Destroy()
end)

Test("Huss Valley dash uses native input and honors movement gates", function()
    local F = HussMovementFixture()
    local Requested = {}
    local Available = true
    local Input = {
        available = function(Player) Equal(Player, F.Player); return Available end,
        request = function(TouchStyle) table.insert(Requested, TouchStyle) end,
    }
    F:AddModule("BoostInput", Input)
    local Context = assert(F:Load())
    local HV, A = Context.HussValley, F.Player.Character.Attributes
    A.DashReady = false
    Equal(HV.RequestDash(false), false)
    Equal(F.RequireCalls, nil)
    A.DashReady = true
    A.DashCooldownUntil = os.clock() + 60
    Equal(HV.RequestDash(false), false)
    A.DashCooldownUntil = nil
    A.MovementLocked = true
    Equal(HV.RequestDash(false), false)
    A.MovementLocked = false
    Available = false
    Equal(HV.RequestDash(false), false)
    Equal(#Requested, 0)
    Available = true
    assert(HV.RequestDash(false))
    Equal(Requested[1], false)
    F.Lib.Controls.HussValleyDashTouchInput:Set(true)
    F.Lib.Buttons["Request dash"]()
    Equal(Requested[2], true)
    F.Player.Attributes.GameRole = "Catcher"
    Equal(HV.RequestDash(false), false)
    Equal(#Requested, 2)
    F.Player.Attributes.GameRole = "Runner"
    F.Root.Anchored = true
    Equal(HV.RequestDash(false), false)
    F.Root.Anchored = false
    Input.available = function() error("decompiler-style invalid character property") end
    Equal(HV.RequestDash(false), false)
    Equal(#Requested, 2)
    Context.Destroy()
    Equal(HV.RequestDash(false), false)
end)

Test("Huss Valley dash shortcut ignores UI input and disconnects on unload", function()
    local F = HussMovementFixture()
    local Requested = 0
    F:AddModule("BoostInput", {
        available = function() return true end,
        request = function() Requested += 1 end,
    })
    local Context = assert(F:Load())
    F.InputService.InputBegan:Fire({ KeyCode = "V" }, false)
    Equal(Requested, 0)
    F.Lib.Controls.HussValleyDashShortcut:Set(true)
    F.InputService.InputBegan:Fire({ KeyCode = "V" }, true)
    Equal(Requested, 0)
    F.InputService.FocusedTextBox = {}
    F.InputService.InputBegan:Fire({ KeyCode = "V" }, false)
    Equal(Requested, 0)
    F.InputService.FocusedTextBox = nil
    F.InputService.InputBegan:Fire({ KeyCode = "V" }, false)
    Equal(Requested, 1)
    Context.Destroy()
    F.InputService.InputBegan:Fire({ KeyCode = "V" }, false)
    Equal(Requested, 1)
    Equal(F:ActiveConnections(), 0)
end)

Test("Huss Valley native module failures stay isolated", function()
    local F = HussMovementFixture()
    local Broken = F:AddModule("MovementProfiles", { get = function() error("profile failed") end })
    local Context = assert(F:Load())
    Equal(Context.HussValley.ReadMovementProfile(), false)
    Equal(Context.HussValley.State.MovementProfile, nil)
    F.Heartbeat:Fire(0.5)
    Equal(Context.HussValley.RequestDash(false), false)
    assert(F.Lib.SettingsCreated)
    Broken.ModuleError = "module require failed"
    Equal(Context.HussValley.ReadMovementProfile(), false)
    Context.Destroy()
end)

Test("Huss Valley discovers native Session data when it appears or changes", function()
    local F = HussMovementFixture()
    local Context = assert(F:Load())
    local HV = Context.HussValley
    Equal(HV.State.Snapshot.Session, nil)
    local Session = Node("Session")
    Session.Attributes = { Phase = "SelectHero", LeadUserId = 1, SelectedUserId = 2, GlobalPaused = true }
    local GameRoot = F.Storage:FindFirstChild("ChickenOrHero")
    table.insert(GameRoot.Children, Node("Game", "Folder", { Session }))
    F.Heartbeat:Fire(0.5)
    Equal(HV.State.Snapshot.Session.LeadUserId, 1)
    Equal(HV.State.Snapshot.Movement.BlockReason, "GlobalPause")
    assert(F:ContainsLabel("Phase: SelectHero | Session: paused"))
    assert(table.find(F.Lib.Controls.HussValleyRoundInfo.Items, "Session.SelectedUserId = 2"))
    Equal(F.RequireCalls, 1)
    Session.Attributes.GlobalPaused = false
    Session.Attributes.MapChanging = true
    Session.Attributes.Phase = "Crossing"
    F.Heartbeat:Fire(0.5)
    Equal(HV.State.Snapshot.Movement.BlockReason, "MapChange")
    assert(F:ContainsLabel("Phase: Crossing | Session: changing map"))
    table.clear(GameRoot.Children)
    F.Heartbeat:Fire(0.5)
    Equal(HV.State.Snapshot.Session, nil)
    Equal(HV.State.Snapshot.Movement.BlockReason, nil)
    Context.Destroy()
end)

Test("Huss Valley displays frozen settings and touch timing without changing them", function()
    local F = HussMovementFixture()
    local Dash = table.freeze({ Mode = "RunBoost", Enabled = true, Distance = 10.8, Duration = 0.28,
        Cooldown = 1.1, InputBuffer = 0.18, TouchInputBuffer = 0.32,
        TurnInputGrace = 0.38, TouchTurnInputGrace = 0.55, MinIntentAngle = 35, TouchMinIntentAngle = 25 })
    local Config = table.freeze({ MaxSpeed = 33.6, Acceleration = 36, JumpEnabled = false, Dash = Dash,
        Camera = table.freeze({ MinZoom = 6, MaxZoom = 18 }) })
    F:AddModule("MovementConfig", Config)
    local Profile = table.freeze({ MaxSpeed = 35.616, Acceleration = 51.12, JumpEnabled = false, Dash = Dash })
    F:AddModule("MovementProfiles", { get = function() return Profile end })
    local Context = assert(F:Load())
    local HV = Context.HussValley
    Equal(F.RequireCalls, nil)
    F.InputBlock = "Settings"
    assert(HV.ReadMovementSettings())
    assert(F:ContainsLabel("Input blocked: Settings"))
    Equal(HV.State.Snapshot.MovementConfig, Config)
    assert(F:ContainsLabel("Input buffer: 0.18s | Turn history: 0.38s | Intent angle: 35.00 degrees"))
    assert(F:ContainsLabel("Profile jump: disabled"))
    assert(table.find(F.Lib.Controls.HussValleyMovementDetails.Items, "Config.Camera.MinZoom = 6"))
    F.Lib.Controls.HussValleyDashTouchInput:Set(true)
    assert(F:ContainsLabel("Input buffer: 0.32s | Turn history: 0.55s | Intent angle: 25.00 degrees"))
    assert(HV.ReadMovementProfile())
    assert(table.find(HV.State.Snapshot.MovementDetails, "Profile.MaxSpeed = 35.616"))
    F.Player.Character.Attributes.BoostRecoveryUntil = os.clock() + 60
    F.Player.Character.Attributes.LastDashEntrySpeed = 24
    F.Player.Character.Attributes.FacingPaceMultiplier = 0.85
    F.InputBlock = nil
    F.Heartbeat:Fire(0.5)
    assert(HV.State.Snapshot.Movement.Recovery > 50)
    Near(HV.State.Snapshot.Movement.LastDashEntrySpeed, 24)
    assert(F:ContainsLabel("Input blocked: no"))
    local Requires = F.RequireCalls
    F.Heartbeat:Fire(0.5)
    Equal(F.RequireCalls, Requires)
    assert(table.isfrozen(Config) and table.isfrozen(Profile) and table.isfrozen(Dash))
    Near(Config.MaxSpeed, 33.6)
    Near(Dash.Cooldown, 1.1)
    Context.Destroy()
end)

Test("Huss Valley dash respects session, native UI gates, and recovery", function()
    local F = HussMovementFixture()
    local Requested = 0
    local Session = Node("Session")
    table.insert(F.Storage:FindFirstChild("ChickenOrHero").Children, Node("Game", "Folder", { Session }))
    local Input = { available = function() return true end, request = function() Requested += 1 end }
    F:AddModule("BoostInput", Input)
    local Context = assert(F:Load())
    local HV, A = Context.HussValley, F.Player.Character.Attributes
    for _, Attribute in ipairs({ "GlobalPaused", "MapChanging" }) do
        Session.Attributes[Attribute] = true
        Equal(HV.RequestDash(false), false)
        Session.Attributes[Attribute] = false
    end
    F.Player.Attributes.Spectating = true
    Equal(HV.RequestDash(false), false)
    F.Player.Attributes.Spectating = false
    Equal(F.RequireCalls, nil)
    for _, Reason in ipairs({ "Settings", "TextInput", "ChoiceCamera", "RobloxMenu" }) do
        F.InputBlock = Reason
        Equal(HV.RequestDash(false), false)
    end
    F.InputBlock = nil
    F.MovementBlock = "GlobalPause"
    Equal(HV.RequestDash(false), false)
    F.MovementBlock = nil
    A.BoostRecoveryUntil = os.clock() + 60
    Equal(HV.RequestDash(false), false)
    A.BoostRecoveryUntil = os.clock() - 1
    A.MovementState = "Boosting"
    Equal(HV.RequestDash(false), false)
    A.MovementState = "Running"
    assert(HV.RequestDash(false))
    Equal(Requested, 1)
    Input.available = function() F.InputBlock = "Settings"; return true end
    Equal(HV.RequestDash(false), false)
    Equal(Requested, 1)
    Context.Destroy()
end)

Test("Huss Valley ControlGate failures prevent input and recover on refresh", function()
    local F = HussMovementFixture()
    local Requested = 0
    F:AddModule("BoostInput", { available = function() return true end, request = function() Requested += 1 end })
    F:AddModule("MovementConfig", table.freeze({ MaxSpeed = 33.6, Dash = table.freeze({}) }))
    local Gate = F.ControlGate.ModuleValue
    local OriginalReason = Gate.reason
    Gate.reason = function() error("gate failed") end
    local Context = assert(F:Load())
    local HV = Context.HussValley
    Equal(HV.ReadMovementSettings(), false)
    Equal(HV.RequestDash(false), false)
    assert(F:ContainsLabel("Input blocked: check failed"))
    Equal(Requested, 0)
    Gate.reason = function() return false end
    Equal(HV.RequestDash(false), false)
    Gate.reason = OriginalReason
    F.Heartbeat:Fire(0.5)
    assert(F:ContainsLabel("Input blocked: no"))
    assert(HV.RequestDash(false))
    Equal(Requested, 1)
    F.ControlGate.ModuleError = "cannot load gate"
    Equal(HV.ReadMovementSettings(), false)
    Equal(HV.RequestDash(false), false)
    assert(F:ContainsLabel("Input blocked: check failed"))
    Equal(Requested, 1)
    Context.Destroy()
end)

Test("Huss Valley unload during require cancels pending dash input", function()
    local F = HussMovementFixture()
    local Requested = 0
    F:AddModule("BoostInput", {
        available = function() return true end,
        request = function() Requested += 1 end,
    })
    local Context = assert(F:Load())
    local OriginalRequire = F.Env.require
    F.Env.require = function(Module)
        Context.Destroy()
        return OriginalRequire(Module)
    end
    Equal(Context.HussValley.RequestDash(false), false)
    Equal(Requested, 0)
end)

Test("Huss Valley sprint hooks frozen profiles and keeps Shift transitions stable", function()
    local F = HussMovementFixture()
    F:EnableHooks()
    local Dash = table.freeze({ Cooldown = 1.1 })
    local Base = table.freeze({ MaxSpeed = 30, Acceleration = 40, Deceleration = 60, Dash = Dash })
    local Profiles = table.freeze({ get = F:Hookable(function() return Base end) })
    F:AddModule("MovementProfiles", Profiles)
    local Context = assert(F:Load())
    local C = F.Lib.Controls
    C.HussValleySprintEnabled:Set(true)
    assert(Context.HussValley.State.Sprint.Enabled)
    local Standing = Profiles.get("Runner", F.Player)
    Near(Standing.MaxSpeed, 30)
    F.InputService.InputBegan:Fire({ KeyCode = "LeftShift" }, false)
    local Running = Profiles.get("Runner", F.Player)
    Equal(Standing, Running)
    Near(Running.MaxSpeed, 34.5)
    Near(Running.Acceleration, 46)
    Equal(Running.Dash, Dash)
    Equal(Profiles.get("Runner", F.OtherPlayer), Base)
    C.HussValleySprintIncrease:Set(50)
    Equal(Profiles.get("Runner", F.Player), Running)
    Near(Running.MaxSpeed, 45)
    F.InputService.InputEnded:Fire({ KeyCode = "LeftShift" })
    Equal(Profiles.get("Runner", F.Player), Running)
    Near(Running.MaxSpeed, 30)
    C.HussValleySprintAlways:Set(true)
    Near(Profiles.get("Runner", F.Player).MaxSpeed, 45)
    C.HussValleySprintEnabled:Set(false)
    Equal(Profiles.get("Runner", F.Player), Base)
    Near(Base.MaxSpeed, 30)
    C.HussValleySprintEnabled:Set(true)
    Context.Destroy()
    Equal(Profiles.get("Runner", F.Player), Base)
    Equal(F:ActiveConnections(), 0)
end)

Test("Huss Valley sprint ignores UI input, locks, lobby roles, and focus loss", function()
    local F = HussMovementFixture()
    local Base = table.freeze({ MaxSpeed = 30, Acceleration = 40 })
    local Profiles = { get = function() return Base end }
    F:AddModule("MovementProfiles", Profiles)
    local Context = assert(F:Load())
    F.Lib.Controls.HussValleySprintEnabled:Set(true)
    F.InputService.InputBegan:Fire({ KeyCode = "LeftShift" }, true)
    Near(Profiles.get("Runner", F.Player).MaxSpeed, 30)
    F.InputService.InputBegan:Fire({ KeyCode = "RightShift" }, false)
    Near(Profiles.get("Runner", F.Player).MaxSpeed, 34.5)
    F.InputService.FocusedTextBox = {}
    Near(Profiles.get("Runner", F.Player).MaxSpeed, 30)
    F.InputService.FocusedTextBox = nil
    F.Player.Character.Attributes.MovementLocked = true
    Near(Profiles.get("Runner", F.Player).MaxSpeed, 30)
    F.Player.Character.Attributes.MovementLocked = false
    F.Player.Attributes.GameRole = "Lobby"
    Near(Profiles.get("Lobby", F.Player).MaxSpeed, 30)
    F.Player.Attributes.GameRole = "Runner"
    F.InputService.WindowFocusReleased:Fire()
    Near(Profiles.get("Runner", F.Player).MaxSpeed, 30)
    Context.Destroy()
    Equal(Profiles.get("Runner", F.Player), Base)
end)

Test("Huss Valley sprint pauses Universal speed and handles missing hooks", function()
    local F = HussMovementFixture()
    local Base = table.freeze({ MaxSpeed = 30, Acceleration = 40 })
    local Get = function() return Base end
    local Module = F:AddModule("MovementProfiles", table.freeze({ get = Get }))
    local Context = assert(F:Load())
    local C = F.Lib.Controls
    C.WalkSpeedSlider:Set(50)
    C.WalkSpeedToggle:Set(true)
    Near(F.Hum.WalkSpeed, 24)
    C.HussValleySprintEnabled:Set(true)
    Equal(C.HussValleySprintEnabled.Value, false)
    Equal(Context.HussValley.State.Sprint.Enabled, false)
    Near(F.Hum.WalkSpeed, 24)
    Module.ModuleValue = { get = Get }
    C.HussValleySprintEnabled:Set(true)
    Near(F.Hum.WalkSpeed, 16)
    F.Hum.WalkSpeed = 30
    Near(F.Hum.WalkSpeed, 30)
    C.HussValleySprintEnabled:Set(false)
    Near(F.Hum.WalkSpeed, 45)
    C.WalkSpeedToggle:Set(false)
    Near(F.Hum.WalkSpeed, 30)
    Context.Destroy()
end)

Test("Huss Valley unload during sprint module load cancels installation", function()
    local F = HussMovementFixture()
    local Base = table.freeze({ MaxSpeed = 30, Acceleration = 40 })
    local Profiles = { get = function() return Base end }
    local Original = Profiles.get
    F:AddModule("MovementProfiles", Profiles)
    local Context = assert(F:Load())
    local Require = F.Env.require
    F.Env.require = function(Module) Context.Destroy(); return Require(Module) end
    F.Lib.Controls.HussValleySprintEnabled:Set(true)
    Equal(Profiles.get, Original)
    Equal(Context.HussValley.State.Sprint.Enabled, false)
end)

local function OtherHitbox(F, Size)
    local Part = Node("HumanoidRootPart", "Part")
    Part.Size = Size or F.Env.Vector3.new(2, 2, 1)
    Part.CanCollide = true
    F.OtherPlayer.Character = F:Character(F:Humanoid())
    table.insert(F.OtherPlayer.Character.Children, Part)
    Part.Parent = F.OtherPlayer.Character
    return Part
end

Test("Huss Valley edits discovered hitbox parts and restores selection and previews", function()
    local F = HussMovementFixture()
    local Other = OtherHitbox(F)
    local Original = Other.Size
    local Context = assert(F:Load())
    local C = F.Lib.Controls
    Equal(Other.Size, Original)
    C.HussValleyHitboxesEnabled:Set(true)
    Equal(Other.Size, F.Env.Vector3.new(6, 6, 6))
    Equal(Other.CanCollide, false)
    Equal(F.Root.Size, F.Env.Vector3.new(2, 2, 1))
    Equal(#F.Boxes, 1)
    Equal(F.Boxes[1].Adornee, Other)
    C.HussValleyHitboxSizeX:Set(8)
    Near(Other.Size.X, 8)
    C.HussValleyHitboxNonColliding:Set(false)
    Equal(Other.CanCollide, true)
    C.HussValleyHitboxPreview:Set(false)
    assert(F.Boxes[1].Destroyed)
    C.HussValleyHitboxIncludeSelf:Set(true)
    Near(F.Root.Size.X, 8)
    C.HussValleyHitboxParts:Set({})
    Equal(Other.Size, Original)
    Equal(F.Root.Size, F.Env.Vector3.new(2, 2, 1))
    Equal(Context.HussValley.State.Hitboxes.EditedParts, 0)
    C.HussValleyHitboxParts:Set({ "HumanoidRootPart" })
    Context.Destroy()
    Equal(Other.Size, Original)
    Equal(Other.CanCollide, true)
    Equal(F.Root.Size, F.Env.Vector3.new(2, 2, 1))
    Equal(F:ActiveConnections(), 0)
end)

Test("Huss Valley hitboxes follow respawns, filter players, and preserve game updates", function()
    local F = HussMovementFixture()
    local Old = OtherHitbox(F)
    local Original = Old.Size
    local Context = assert(F:Load())
    local C = F.Lib.Controls
    C.HussValleyHitboxesEnabled:Set(true)
    C.HussValleyHitboxAllOthers:Set(false)
    Equal(Old.Size, Original)
    local Label = "Other Player (@OtherUser) [2]"
    C.HussValleyHitboxPlayers:Set({ Label })
    Near(Old.Size.X, 6)
    local New = OtherHitbox(F)
    F.Heartbeat:Fire(0.5)
    Equal(Old.Size, Original)
    Near(New.Size.X, 6)
    New.Size = F.Env.Vector3.new(3, 4, 2)
    F.Heartbeat:Fire(0.5)
    Near(New.Size.X, 6)
    C.HussValleyHitboxesEnabled:Set(false)
    Equal(New.Size, F.Env.Vector3.new(3, 4, 2))
    C.HussValleyHitboxesEnabled:Set(true)
    New.Size = F.Env.Vector3.new(4, 5, 3)
    Context.Destroy()
    Equal(New.Size, F.Env.Vector3.new(4, 5, 3))
    for _, Box in ipairs(F.Boxes) do assert(Box.Destroyed) end
end)

local function HussTackleFixture(Hooked, BoundsValue)
    local F = HussMovementFixture()
    F.Player.Attributes.GameRole = "Catcher"
    F.Player.Attributes.RunState = "Active"
    F.GameFolder = Node("Game")
    table.insert(F.Storage:FindFirstChild("ChickenOrHero").Children, F.GameFolder)
    function F:AddGameModule(Name, Value)
        local Module = Node(Name, "ModuleScript")
        Module.ModuleValue = Value
        table.insert(self.GameFolder.Children, Module)
        return Module
    end
    F.BaseTackle = table.freeze({ Variants = table.freeze({}), Cooldown = 1.2 })
    F.SlowTackle = table.freeze({ Name = "Standing", Distance = 4, Duration = 0.2, Recovery = 0.4 })
    F.FastTackle = table.freeze({ Name = "Running", Distance = 10, Duration = 0.3, Recovery = 0.5 })
    F:AddModule("MovementProfiles", { get = function(Role, Player)
        Equal(Role, "Catcher"); Equal(Player, F.Player)
        return { MaxSpeed = F.Player.Attributes.GearSlow and 20 or 40, Acceleration = 36 }
    end })
    F:AddGameModule("GameConfig", table.freeze({ Tackle = F.BaseTackle }))
    F:AddGameModule("TackleProfile", table.freeze({ select = function(Config, Speed, MaxSpeed)
        Equal(Config, F.BaseTackle)
        F.LastSelection = { Speed = Speed, MaxSpeed = MaxSpeed }
        return Speed >= 10 and F.FastTackle or F.SlowTackle
    end }))
    F:AddGameModule("TackleMotion", table.freeze({ distance = function(Profile, Time)
        Near(Time, Profile.Duration); return Profile.Distance
    end }))
    F:AddGameModule("TacklePredictionConfig", table.freeze({ EntrySpeedTolerance = 2, ConfirmTimeout = 0.9 }))
    F.BaseBounds = BoundsValue or F.Env.Vector3.new(2, 3, 4)
    local Bounds = function(Kind) return Kind == "Tackle" and F.BaseBounds or F.Env.Vector3.new(1, 1, 1) end
    if Hooked then F:EnableHooks(); Bounds = F:Hookable(Bounds) end
    F.Replay = Hooked and table.freeze({ bounds = Bounds }) or { bounds = Bounds }
    F:AddGameModule("HitReplayMath", F.Replay)
    F.Requested = 0
    F.Remaining = 0
    F.Prediction = {
        remaining = function() return F.Remaining end,
        request = function()
            F.Requested += 1
            F.Player.Character.Attributes.TackleActive = true
            F.Player.Character.Attributes.TackleVariant = "Running"
            return F.Accepted ~= false
        end,
    }
    F:AddGameModule("TacklePrediction", F.Prediction)
    return F
end

Test("Huss Valley tackle settings refresh live variants, gear speed, and server-clock cooldown", function()
    local F = HussTackleFixture()
    F.Player.Attributes.TackleReadyAt = F.ServerTime + 0.6
    local Context = assert(F:Load())
    local HV = Context.HussValley
    Equal(F.RequireCalls, nil)
    F.Heartbeat:Fire(0.25)
    Equal(HV.State.Tackle.Profile, F.SlowTackle)
    Near(HV.State.Tackle.Remaining, 0.6)
    Near(HV.State.Tackle.MotionDistance, 4)
    assert(table.find(F.Lib.Controls.HussValleyTackleDetails.Items, "Prediction.EntrySpeedTolerance = 2"))
    assert(F:ContainsLabel("Tackle prediction size: 2.00 x 3.00 x 4.00 studs"))
    local Requires = F.RequireCalls
    F.Root.AssemblyLinearVelocity = { X = 12, Y = 50, Z = 0 }
    F.Player.Attributes.GearSlow = true
    F.ServerTime += 0.5
    F.Heartbeat:Fire(0.25)
    Equal(HV.State.Tackle.Profile, F.FastTackle)
    Near(F.LastSelection.Speed, 12)
    Near(F.LastSelection.MaxSpeed, 20)
    Near(HV.State.Tackle.Remaining, 0.1)
    Equal(F.RequireCalls, Requires)
    Context.Destroy()
end)

Test("Huss Valley native tackle honors roles, physical state, dagger, UI, and cooldown", function()
    local F = HussTackleFixture()
    local Context = assert(F:Load())
    local HV = Context.HussValley
    F.Player.Attributes.GameRole = "Runner"
    Equal(HV.RequestTackle(), false)
    Equal(F.RequireCalls, nil)
    F.Player.Attributes.GameRole = "Catcher"
    F.Player.Attributes.RunState = "Lobby"
    Equal(HV.RequestTackle(), false)
    F.Player.Attributes.RunState = "Active"
    F.Hum.FloorMaterial = "Air"
    Equal(HV.RequestTackle(), false)
    F.Hum.FloorMaterial = "Ground"
    F.Player.Character.Attributes.DaggerEquipped = true
    F.Player.Character.Attributes.DaggerState = "Drawing"
    Equal(HV.RequestTackle(), false)
    F.Player.Character.Attributes.DaggerState = "Held"
    F.Player.Attributes.TackleReadyAt = F.ServerTime + 0.1
    Equal(HV.RequestTackle(), false)
    F.Player.Attributes.TackleReadyAt = F.ServerTime
    F.Remaining = 0.1
    Equal(HV.RequestTackle(), false)
    F.Remaining = 0
    F.InputBlock = "ChoiceCamera"
    Equal(HV.RequestTackle(), false)
    F.InputBlock = nil
    assert(HV.RequestTackle())
    Equal(F.Requested, 1)
    assert(HV.State.Tackle.Active)
    Equal(HV.RequestTackle(), false)
    Context.Destroy()
    Equal(HV.RequestTackle(), false)
end)

Test("Huss Valley tackle native failures and unloads cancel action", function()
    local F = HussTackleFixture()
    local Context = assert(F:Load())
    local HV = Context.HussValley
    F.Prediction.remaining = function() error("timer failed") end
    Equal(HV.RequestTackle(), false)
    Equal(F.Requested, 0)
    F.Prediction.remaining = function() return 0 end
    F.Prediction.request = function() error("native request failed") end
    Equal(HV.RequestTackle(), false)
    Equal(F.Requested, 0)
    F.Prediction.remaining = function() Context.Destroy(); return 0 end
    Equal(HV.RequestTackle(), false)
    Equal(F.Requested, 0)
end)

Test("Huss Valley prediction box hooks only verified vector tackle bounds and restores", function()
    local F = HussTackleFixture(true)
    local Context = assert(F:Load())
    local C = F.Lib.Controls
    C.HussValleyTackleBoxEnabled:Set(true)
    assert(Context.HussValley.State.Tackle.BoxEnabled)
    C.HussValleyTackleBoxX:Set(2)
    C.HussValleyTackleBoxY:Set(1.5)
    Equal(F.Replay.bounds("Tackle", F.FastTackle), F.Env.Vector3.new(4, 4.5, 4))
    Equal(F.Replay.bounds("Knife", F.FastTackle), F.Env.Vector3.new(1, 1, 1))
    Equal(F.BaseBounds, F.Env.Vector3.new(2, 3, 4))
    C.HussValleyTackleBoxEnabled:Set(false)
    Equal(F.Replay.bounds("Tackle", F.FastTackle), F.BaseBounds)
    C.HussValleyTackleBoxEnabled:Set(true)
    Context.Destroy()
    Equal(F.Replay.bounds("Tackle", F.FastTackle), F.BaseBounds)
end)

Test("Huss Valley prediction box refuses unknown schemas and missing frozen hooks", function()
    local F = HussTackleFixture(false, { Size = { X = 2, Y = 3, Z = 4 } })
    local Context = assert(F:Load())
    F.Lib.Controls.HussValleyTackleBoxEnabled:Set(true)
    Equal(F.Lib.Controls.HussValleyTackleBoxEnabled.Value, false)
    Equal(Context.HussValley.State.Tackle.BoxEnabled, false)
    Equal(F.Replay.bounds("Tackle"), F.BaseBounds)
    Context.Destroy()
    local Frozen = HussTackleFixture()
    Frozen.Replay = table.freeze(Frozen.Replay)
    local FrozenContext = assert(Frozen:Load())
    Frozen.Lib.Controls.HussValleyTackleBoxEnabled:Set(true)
    Equal(Frozen.Lib.Controls.HussValleyTackleBoxEnabled.Value, false)
    Equal(FrozenContext.HussValley.State.Tackle.BoxEnabled, false)
    FrozenContext.Destroy()
end)

Test("Huss Valley replaced or removed tackle bindings restore the active box hook", function()
    local F = HussTackleFixture()
    local Context = assert(F:Load())
    local C = F.Lib.Controls
    C.HussValleyTackleBoxEnabled:Set(true)
    C.HussValleyTackleBoxX:Set(2)
    local OldReplay = F.Replay
    local OldModule = F.GameFolder:FindFirstChild("HitReplayMath")
    table.remove(F.GameFolder.Children, assert(table.find(F.GameFolder.Children, OldModule)))
    local NewBounds = F.Env.Vector3.new(3, 3, 3)
    F:AddGameModule("HitReplayMath", { bounds = function() return NewBounds end })
    F.Heartbeat:Fire(0.25)
    Equal(Context.HussValley.State.Tackle.BoxEnabled, false)
    Equal(C.HussValleyTackleBoxEnabled.Value, false)
    Equal(OldReplay.bounds("Tackle"), F.BaseBounds)
    Equal(Context.HussValley.State.Tackle.Bounds, NewBounds)
    C.HussValleyTackleBoxEnabled:Set(true)
    local GameConfig = F.GameFolder:FindFirstChild("GameConfig")
    table.remove(F.GameFolder.Children, assert(table.find(F.GameFolder.Children, GameConfig)))
    F.Heartbeat:Fire(0.25)
    Equal(Context.HussValley.State.Tackle.BoxEnabled, false)
    Equal(Context.HussValley.State.Tackle.Bounds, nil)
    Context.Destroy()
end)

Test("Huss Valley replicated descendant signals refresh catalogs before the polling interval", function()
    local F = HussMovementFixture()
    F.Storage.DescendantAdded = F:Signal()
    F.Storage.DescendantRemoving = F:Signal()
    local Context = assert(F:Load())
    F.Heartbeat:Fire(0.25)
    local Consumables = Node("Consumables", "Folder", { Node("Banana", "ModuleScript") })
    table.insert(F.Storage.Children, Consumables)
    F.Storage.DescendantAdded:Fire(Consumables)
    F.Heartbeat:Fire(0.25)
    Equal(#F.Lib.Controls.HussValleySelectedConsumables.Items, 1)
    table.clear(Consumables.Children)
    F.Storage.DescendantRemoving:Fire(Consumables)
    F.Heartbeat:Fire(0.25)
    Equal(#F.Lib.Controls.HussValleySelectedConsumables.Items, 0)
    Context.Destroy()
    Equal(F:ActiveConnections(), 0)
end)

Test("Huss Valley automatically discovers late movement data and catalog changes", function()
    local F = HussMovementFixture()
    local Context = assert(F:Load())
    local HV, C = Context.HussValley, F.Lib.Controls
    F.Heartbeat:Fire(0.25)
    Equal(HV.State.Snapshot.MovementProfile, nil)
    local Module = F:AddModule("MovementProfiles", { get = function()
        return { MaxSpeed = 30, Acceleration = 40 }
    end })
    Module.ModuleError = "loading failed"
    F:AddModule("MovementConfig", { MaxSpeed = 30, Dash = { Distance = 10, Duration = 0.28, Cooldown = 1.1 } })
    F.Heartbeat:Fire(0.25)
    Equal(HV.State.Snapshot.MovementProfile, nil)
    Module.ModuleError = nil
    F.Heartbeat:Fire(0.5)
    Near(HV.State.Snapshot.MovementProfile.MaxSpeed, 30)
    F.Heartbeat:Fire(0.25)
    Near(HV.State.Snapshot.MovementConfig.MaxSpeed, 30)
    local Abilities = Node("Abilities", "Folder", { Node("Cloak", "ModuleScript") })
    table.insert(F.Storage.Children, Abilities)
    F.Heartbeat:Fire(2)
    Equal(#C.HussValleySelectedAbilities.Items, 1)
    C.HussValleySelectedAbilities:Set(table.clone(C.HussValleySelectedAbilities.Items))
    local Refreshes = C.HussValleySelectedAbilities.Refreshes
    F.Heartbeat:Fire(2)
    Equal(C.HussValleySelectedAbilities.Refreshes, Refreshes)
    Equal(#C.HussValleySelectedAbilities.Value, 1)
    table.clear(Abilities.Children)
    F.Heartbeat:Fire(2)
    Equal(#C.HussValleySelectedAbilities.Items, 0)
    Equal(#C.HussValleySelectedAbilities.Value, 0)
    Context.Destroy()
end)

Test("Huss Valley live workers isolate failing panels and stalled module reads", function()
    local F = HussMovementFixture()
    local Context = assert(F:Load())
    local HV = Context.HussValley
    local Calls, Healthy, ProfileCalls = 0, 0, 0
    HV.Subscribe(function() Calls += 1; error("panel failed") end, "Broken test panel")
    HV.Subscribe(function() Healthy += 1 end, "Healthy test panel")
    local Notifications = #F.Notifications
    F:AddModule("MovementProfiles", { get = function()
        ProfileCalls += 1
        coroutine.yield()
        return { MaxSpeed = 30, Acceleration = 40 }
    end })
    F.Player.Attributes.GameRole = "Catcher"
    F.Heartbeat:Fire(0.25)
    Equal(HV.State.Snapshot.Role, "Chasers")
    F.Player.Attributes.GameRole = "Runner"
    F.Heartbeat:Fire(0.25)
    Equal(HV.State.Snapshot.Role, "Runners")
    assert(Calls >= 3 and Healthy >= 3)
    Equal(ProfileCalls, 1)
    Equal(#F.Notifications, Notifications)
    Context.Destroy()
    for _, Thread in ipairs(F.Spawned) do
        if coroutine.status(Thread) == "suspended" then assert(coroutine.resume(Thread)) end
    end
    Equal(HV.State.MovementProfile, nil)
    Equal(F:ActiveConnections(), 0)
end)

Test("RC2 catalogs and player display names refresh automatically without selection loss", function()
    local F = Fixture()
    local Context = assert(F:Load())
    local C = F.Lib.Controls
    C.SelectedPlayers:Set({ "Other Player (@OtherUser)" })
    F.OtherPlayer.DisplayName = "Renamed Player"
    table.insert(F.Content:FindFirstChild("Ores").Children, Node("Gold"))
    F.Heartbeat:Fire(2)
    assert(table.find(C.SelectedOres.Items, "Gold"))
    Equal(C.SelectedPlayers.Value[1], "Renamed Player (@OtherUser)")
    Equal(Context.SelectedPlayers[1], F.OtherPlayer)
    local ResourceRefreshes, PlayerRefreshes = C.SelectedOres.Refreshes, C.SelectedPlayers.Refreshes
    F.Heartbeat:Fire(2)
    Equal(C.SelectedOres.Refreshes, ResourceRefreshes)
    Equal(C.SelectedPlayers.Refreshes, PlayerRefreshes)
    Context.Destroy()
end)

print(string.format("%d regression tests passed.", Passed))
end
