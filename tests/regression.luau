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
    local Object = { Name = Name, ClassName = ClassName or "Folder", Children = Children or {} }
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
            UseJumpPower = true, Parent = true, Name = "Humanoid",
        }
        local Signals = {}
        local Methods = {}
        function Methods:IsA(Class) return Class == "Humanoid" end
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
    }
    F.Hum = F:Humanoid()
    if not Options.NoCharacter then F.Player.Character = F:Character(F.Hum) end
    F.OtherPlayer = { Name = "OtherUser", DisplayName = "Other Player", UserId = 2 }
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
    F.Heartbeat = F:Signal()
    F.Marketplace = { Calls = 0 }
    function F.Marketplace:GetProductInfo()
        self.Calls += 1
        if Options.NoInfo then error("metadata unavailable") end
        return { Name = "Test Game", Description = "Test description" }
    end
    F.Services = {
        Players = F.Players, ReplicatedStorage = F.Storage,
        MarketplaceService = F.Marketplace, RunService = { Heartbeat = F.Heartbeat },
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
        getgenv = function() return F.Global end,
        warn = function(Message) table.insert(F.Warnings, Message) end,
    }, { __index = getfenv() })
    F.Env.loadstring = function(Source, Name)
        local Chunk, Error = loadstring(Source, Name)
        if Chunk then setfenv(Chunk, F.Env) end
        return Chunk, Error
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

print(string.format("%d regression tests passed.", Passed))
end
