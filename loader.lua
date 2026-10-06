local BaseUrl = "https://raw.githubusercontent.com/" 
local LibraryRepo = "samuraa1/MentalityUI/refs/heads/main/" 
local MyRepo = "triplecis/roblox.buns/refs/heads/main/"
local FullLibUrl = BaseUrl .. LibraryRepo
local MyFullUrl = BaseUrl .. MyRepo

-- // IDs // --
local PlaceId = game.PlaceId
local GameId = game.GameId
local JobId = game.JobId

--// Local Player //--

local Player = game.Players.LocalPlayer

--// Get Game Info //--
local MarketplaceService = game:GetService("MarketplaceService")
local GameName = MarketplaceService:GetProductInfo(PlaceId).Name
local GameDescription = MarketplaceService:GetProductInfo(PlaceId).Description

--// MentalityUI Loader //--

local Library = loadstring(game:HttpGet(FullLibUrl .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(FullLibUrl .. "SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet(FullLibUrl .. "ThemeManager.lua"))()

Library:Notification({
    Title = "roblox.buns", 
    Description = "Loader loading.", 
    Duration = 3, 
    Icon = "89380854415542",
})

local Window = Library:Window({
    Name = "roblox.buns",
    SubName = GameName,
    Logo = "89380854415542",
})

local Dashboard = Window:DashboardPage({
    Name = "Dashboard",
    Icon = "layout-dashboard",
    WelcomeText = "WELCOME TO",
    HubName = "roblox.buns",
    StatusText = "documentation build",
    Badge = "PLAYER",
    GameName = GameName,
    GameDescription = GameDescription,
    Links = {
        {
            Icon = "copy", Tooltip = "Copy Discord to clipboard", Callback = function()
                pcall(function()
                    setclipboard("https://discord.gg/ys78VPnnJQ")
                    
                end)
                Library:Notification({
                    Title = "Copied", Description = "Clipboard updated.", Duration = 2, Icon = "89380854415542",
                })
            end,
        },
    },
    Stats = {
        {
            Name = "TIME", Icon = "clock", GetValue = function()
                return os.date("%H:%M:%S")
            end,
        },
        {
            Name = "GAMETIME", Icon = "clock", GetValue = function()
                return tostring(math.floor(workspace.DistributedGameTime)) .. "s"
            end,
        },
    },
    QuickAccess = {
    },
})

Window:TabDivider()

-- // Main Category //--

local MainCategory = Window:Category("Main")

local MainPage = Window:Page({
    Name = "Main", 
    Icon = "house"
})

--// Game Category //--
local GameCategory = Window:Category("Game")

local GamePage = Window:Page({
    Name = GameName, 
    Icon = "gamepad-2"
})

local UniversalPage = Window:Page({
    Name = "Universal", 
    Icon = "globe"
})

local PlayersListPage = Window:Page({
    Name = "Players List",
    Icon = "users"
})

local ScriptsPage = Window:Page({
    Name = "Scripts",
    Icon = "code"
})

Window:TabDivider()

local Context = {
    Library = Library, 
    Window = Window,
    
    SaveManager = SaveManager, 
    ThemeManager = ThemeManager,

    MyFullUrl = MyFullUrl,

    Player = Player,

    PlaceId = PlaceId, 
    GameId = GameId, 
    JobId = JobId,

    Pages = {
        Main = MainPage, 
        Universal = UniversalPage, 
        Game = GamePage, 
        PlayersList = PlayersListPage,
        Scripts = ScriptsPage,
    },
}

--// Games //--

local Games = {
    [4298676072] = {
        Folder = "RC2",
        Default = "4298676072.lua",
    },

    -- Example of a game with multiple places:
    --[[
    [1234567890] = {
        Folder = "ExampleGame",
        Default = "main.lua",

        Places = {
            [1111111111] = "lobby.lua",
            [2222222222] = "match.lua",
        },
    },
    ]]
}

--// Script Loader //--

local function LoadScript(Path)
    local URL = MyFullUrl .. Path

    local Success, Source = pcall(function()
        return game:HttpGet(URL)
    end)

    if not Success then
        Library:Notification({
            Title = "HTTP Error",
            Description = "Failed to download " .. Path .. ": " .. tostring(Source),
            Duration = 5,
            Icon = "89380854415542",
        })

        return nil
    end

    local Script, CompileError = loadstring(Source)

    if not Script then
        Library:Notification({
            Title = "Compile Error",
            Description = Path .. ": " .. tostring(CompileError),
            Duration = 8,
            Icon = "89380854415542",
        })

        return nil
    end

    local RunSuccess, Result = pcall(Script)

    if not RunSuccess then
        Library:Notification({
            Title = "Runtime Error",
            Description = Path .. ": " .. tostring(Result),
            Duration = 8,
            Icon = "89380854415542",
        })

        return nil
    end

    return Result
end

--// Universal //--

local UniversalScript = LoadScript("universal.lua")
local PlayersListScript = LoadScript("playerslist.lua")
local ScriptsScript = LoadScript("scripts.lua")
local SettingsScript = LoadScript("settings.lua")

if type(UniversalScript) == "function" then
    UniversalScript(Context)
end

if type(PlayersListScript) == "function" then
    PlayersListScript(Context)
end

if type(ScriptsScript) == "function" then
    ScriptsScript(Context)
end

if type(SettingsScript) == "function" then
    SettingsScript(Context)
end

--// Game //--

local GameData = Games[GameId]

if GameData then
    local Filename = GameData.Default

    if GameData.Places and GameData.Places[PlaceId] then
        Filename = GameData.Places[PlaceId]
    end

    local Path = "games/" .. GameData.Folder .. "/" .. Filename

    local GameScript = LoadScript(Path)

    if type(GameScript) == "function" then
        GameScript(Context)
    end
else
    Library:Notification({
        Title = "Unsupported", 
        Description = "No game module found for GameId: " .. tostring(GameId), 
        Duration = 5, 
        Icon = "89380854415542",
    })
end

Dashboard:AddCard({
    Name = "Main", 
    Description = "Toggles & sliders.", 
    Icon = "house", 
    Tab = MainPage,
})
