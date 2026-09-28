local BaseUrl = "https://raw.githubusercontent.com/"
local LibraryRepo = "samuraa1/MentalityUI/refs/heads/main/"
local MyRepo = "triplecis/roblox.buns/refs/heads/main/"

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

local Library = loadstring(game:HttpGet(BaseUrl .. LibraryRepo .. "Library.lua"))()
local SaveManager = loadstring(game:HttpGet(BaseUrl .. LibraryRepo .. "SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet(BaseUrl .. LibraryRepo .. "ThemeManager.lua"))()

Library:Notification({
    Title = "roblox.buns", 
    Description = "Loader loading.", 
    Duration = 3, 
    Icon = "97594400820219",
})

local Window = Library:Window({
    Name = "roblox.buns",
    SubName = GameName,
    Logo = "1",
})

local KeybindList = Library:KeybindList("Keybinds")

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
                    setclipboard("discord.gg/")
                end)
                Library:Notification({
                    Title = "Copied", Description = "Clipboard updated.", Duration = 2, Icon = "97594400820219",
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

Dashboard:AddCard({
    Name = "MAIN", Description = "Toggles & sliders.", Icon = "gamepad-2", Tab = MainPage,
})

--[[Dashboard:AddCard({
    Name = "MAIN", Description = "Toggles & sliders.", Icon = "gamepad-2", Tab = MainPage,
})]]--

local TabDivider0 = Window:TabDivider()

-- // Main Category //--

local MainCategory = Window:Category("Main")

local MainPage = Window:Page({
    Name = "Main", Icon = "house"
})

--// Game Category //--
local GameCategory = Window:Category("Game")

local GamePage = Window:Page({
    Name = GameName, Icon = "gamepad-2"
})

local UniversalPage = Window:Page({
    Name = "Universal", Icon = "globe"
})

local TabDivider1 = Window:TabDivider()

local Context = {
    Library = Library, Window = Window, SaveManager = SaveManager, ThemeManager = ThemeManager,

    Player = Player,

    PlaceId = PlaceId, GameId = GameId, JobId = JobId,

    Pages = {
        Main = MainPage, Universal = UniversalPage, Game = GamePage,
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
    local URL = BaseUrl .. MyRepo .. Path

    local Success, Result = pcall(function()
        return loadstring(game:HttpGet(URL))()
    end)

    if not Success then
        Library:Notification({
            Title = "Error", Description = "Failed to load " .. Path .. ": " .. tostring(Result), Duration = 5, Icon = "97594400820219",
        })

        return nil
    end

    return Result
end

--// Universal //--

local UniversalScript = LoadScript("universal.lua")

if type(UniversalScript) == "function" then
    UniversalScript(Context)
end

--// Settings //--

local SettingsScript = LoadScript("settings.lua")

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
        Title = "Unsupported", Description = "No game module found for GameId: " .. tostring(GameId), Duration = 5, Icon = "97594400820219",
    })
end