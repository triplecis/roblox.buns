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
    Scripts = _Window:AddTab('Scripts'), -- Scripts Module [ Shows games available to load scripts for ]
    Lobby = _Window:AddTab('Lobby'), -- Lobby Module [ Shows players in lobby ]
    Settings = _Window:AddTab('Settings'), -- Settings Module [ Settings for the UI ]
    --Control = _Window:AddTab('Control'), -- Control Module [ Premium features for controlling other users, may not implement ]
}

--// Get Games //--

local GamePlaceID = game.PlaceId
local url = string.format(
    "https://raw.githubusercontent.com/triplecis/roblox.buns/main/games/%d.lua", 
    GamePlaceID
)

local success, response = pcall(function()
    return game:HttpGet(url)
end)

if success then
    local func, err = loadstring(response)
    if func then
        func()
    else
        warn("Failed to load game script: " .. err)
    end
else
    warn("Failed to fetch game script: " .. response)
end