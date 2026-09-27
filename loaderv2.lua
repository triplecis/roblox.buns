<<<<<<< HEAD
local PlaceId = game.PlaceId
local JobId = game.JobId
local Player = game.Players.LocalPlayer

--// Get Game Info //--
local MarketplaceService = game:GetService("MarketplaceService")
local GameName = MarketplaceService:GetProductInfo(PlaceId).Name
local GameDescription = MarketplaceService:GetProductInfo(PlaceId).Description

--// MentalityUI Loader //--

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/samuraa1/MentalityUI/main/Library.lua"))()

local Window = Library:Window({
    Name = "roblox.buns",
    SubName = GameName,
    Logo = "1",
})

local KeybindList = Library:KeybindList("Keybinds")

local Category = Window:Category("Main")

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
            Icon = "copy",
            Tooltip = "Copy PlaceId to clipboard",
            callback = function()
                pcall(function()
                    setclipboard(PlaceId)
                end)
                Library:Notification({
                    Title = "Copied",
                    Description = "Clipboard updated.",
                    Duration = 2,
                    Icon = "97594400820219",
                })
            end,
        },
        {
            Icon = "group",
            Tooltip = "Copy Discord to clipboard",
            Callback = function()
                pcall(function()
                    setclipboard("discord.gg/")
                end)
                Library:Notification({
                    Title = "Copied",
                    Description = "Clipboard updated.",
                    Duration = 2,
                    Icon = "97594400820219",
                })
            end,
        },
        
    },
    Stats = {
        {
            Name = "TIME",
            Icon = "clock",
            GetValue = function()
                return os.date("%H:%M:%S")
            end,
        },
        {
            Name = "GAMETIME",
            Icon = "clock",
            GetValue = function()
                return tostring(math.floor(workspace.DistributedGameTime)) .. "s"
            end,
        },
    },
    Credits = {
        { Name = "samet", Role = "Library" },
    },
    QuickAccess = {},
})

Dashboard:AddCard({
    Name = "MAIN",
    Description = "Toggles & sliders.",
    Icon = "gamepad-2",
    Tab = MainPage,
})

local MainPage = Window:Page({
    Name = "Main",
    Icon = "gamepad-2"
})

local TabDivider0 = Window:TabDivider()
local GameCategory = Window:Category("Game")

local GamePage = Window:Page({
    Name = "Game",
    Icon = "gamepad-2"
})

loadstring(game:HttpGet("https://raw.githubusercontent.com/triplecis/roblox.buns/main/Settings.lua"))()
=======
--// roblox.buns //--

print("roblox.buns loaded successfully!")

-- // Services //--

-- // Linoria Lib //--

_Linoria = {
    Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua'))(),
    ThemeManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua'))(),
    SaveManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua'))(),
}

local _linoriaScreenGUI = _Linoria.Library.ScreenGui
_linoriaScreenGUI.Name = '// roblox.buns //'

_Linoria.ThemeManager:SetLibrary(_Linoria.Library)
_Linoria.SaveManager:SetLibrary(_Linoria.Library)
_Linoria.SaveManager:IgnoreThemeSettings()
_Linoria.ThemeManager:SetFolder('Silveria/themes')
_Linoria.SaveManager:SetFolder('Silveria/configs')

_Window = _Linoria.Library:CreateWindow({
    Title = 'roblox.buns',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
    --Position = float (optional)
    --Size = 600
})

_Tabs = {
    Home = _Window:AddTab('Home'), -- Home Module
    Universal = _Window:AddTab('Universal'), -- Universal Module
    Game = _Window:AddTab('Game'), -- Game Module [ Detect the Game and load the script for it ]
    --Scripts = _Window:AddTab('Scripts'), -- Scripts Module [ Shows games available to load scripts for ]
    Lobby = _Window:AddTab('Lobby'), -- Lobby Module [ Shows players in lobby ]
    Settings = _Window:AddTab('Settings'), -- Settings Module [ Settings for the UI ]
    --Control = _Window:AddTab('Control'), -- Control Module [ Premium features for controlling other users, may not implement ]
}

--// Load Modules //--
loadstring(game:HttpGet("https://raw.githubusercontent.com/triplecis/roblox.buns/refs/heads/main/launch/home.lua?t=" .. os.time()))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/triplecis/roblox.buns/refs/heads/main/launch/universal.lua?t=" .. os.time()))()
--// Game module is loaded dynamically based on the game being played, so we don't load it here. //--
--loadstring(game:HttpGet("https://raw.githubusercontent.com/triplecis/roblox.buns/refs/heads/main/launch/scripts.lua?t=" .. os.time()))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/triplecis/roblox.buns/refs/heads/main/launch/lobby.lua?t=" .. os.time()))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/triplecis/roblox.buns/refs/heads/main/launch/settings.lua?t=" .. os.time()))()
--loadstring(game:HttpGet("https://raw.githubusercontent.com/triplecis/roblox.buns/refs/heads/main/launch/control.lua?t=" .. os.time()))()

--// Get Games //--
local GamePlaceID = game.PlaceId
local url = string.format(
    "https://raw.githubusercontent.com/triplecis/roblox.buns/refs/heads/main/games/%d.lua?t=%d",
    GamePlaceID,
    os.time()
)

local success, response = pcall(function()
    return game:HttpGet(url)
end)
if not success then
    warn("Failed to fetch game script: " .. tostring(response))
    return
end

if not response or response == "" then
    warn("GitHub returned an empty response.")
    return
end

local func, err = loadstring(response)

if not func then
    warn("Failed to compile game script:")
    warn(err)
    return
end

local ran, runtimeError = pcall(func)

if not ran then
    warn("Game script encountered an error:")
    warn(runtimeError)
else
    print("Game script loaded successfully!")
end
>>>>>>> dbe3cd43c438ce74e49fdbb9f48612b6851e540d
