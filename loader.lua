local PlaceId = game.PlaceId
local JobId = game.JobId
local Player = game.Players.LocalPlayer

--// Get Game Info //--
local MarketplaceService = game:GetService("MarketplaceService")
local GameName = MarketplaceService:GetProductInfo(PlaceId).Name
local GameDescription = MarketplaceService:GetProductInfo(PlaceId).Description

--// MentalityUI Loader //--

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/samuraa1/MentalityUI/main/Library.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/samuraa1/MentalityUI/main/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/samuraa1/MentalityUI/main/ThemeManager.lua"))()

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
            Icon = "copy", Tooltip = "Copy PlaceId to clipboard", callback = function()
                pcall(function()
                    setclipboard(PlaceId)
                end)
                Library:Notification({
                    Title = "Copied", Description = "Clipboard updated.", Duration = 2, Icon = "97594400820219",
                })
            end,
        },
        {
            Icon = "group", Tooltip = "Copy Discord to clipboard", Callback = function()
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
        {
            Name = "Settings", Icon = "settings", Callback = function()
                Window:OpenPage("Settings")
            end,
        },
    },
})

--[[Dashboard:AddCard({
    Name = "MAIN", Description = "Toggles & sliders.", Icon = "gamepad-2", Tab = MainPage,
})]]--

local TabDivider0 = Window:TabDivider()

-- // Main Category //--

local MainCategory = Window:Category("Main")

local MainPage = Window:Page({
    Name = "Main", Icon = "gamepad-2"
})

--// Game Category //--
local GameCategory = Window:Category("Game")

local UniversalPage = Window:Page({
    Name = "Universal", Icon = "gamepad-2"
})

local GamePage = Window:Page({
    Name = GameName, Icon = "gamepad-2"
})

local TabDivider1 = Window:TabDivider()

loadstring(game:HttpGet("https://raw.githubusercontent.com/triplecis/roblox.buns/refs/heads/main/settings.lua"))()