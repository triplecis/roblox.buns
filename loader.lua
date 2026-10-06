local BaseUrl = "https://raw.githubusercontent.com/"
-- Pin the UI API used by this project so upstream changes cannot break the loader.
local LibraryRepo = "samuraa1/MentalityUI/4f5c7733335bd6576f9fbda7931e8838b1eb8d39/"
local MyFullUrl = BaseUrl .. "triplecis/roblox.buns/refs/heads/main/"
local Icon = "89380854415542"
local Player = game:GetService("Players").LocalPlayer
if not Player then
    warn("roblox.buns must be loaded on the client after LocalPlayer is available.")
    return
end

local Environment = getgenv and getgenv() or _G
local PreviousContext = Environment.RobloxBunsContext
if PreviousContext and PreviousContext.Destroy then
    local Success, Error = pcall(PreviousContext.Destroy)
    if not Success then
        warn("Failed to unload the previous roblox.buns session: " .. tostring(Error))
    end
end

local function Download(URL)
    local Success, Source = pcall(function() return game:HttpGet(URL) end)
    if not Success then
        return nil, "HTTP error: " .. tostring(Source)
    end
    if type(Source) ~= "string" or Source == "" then
        return nil, "HTTP response was empty or invalid"
    end
    return Source
end

local function Execute(Source, Name)
    local Success, Chunk, CompileError = pcall(loadstring, Source, "=" .. Name)
    if not Success or not Chunk then
        return nil, "Compile error: " .. tostring(CompileError or Chunk)
    end
    local RunSuccess, Result = pcall(Chunk)
    if not RunSuccess then
        return nil, "Runtime error: " .. tostring(Result)
    end
    return Result
end

local LibrarySource, LibraryError = Download(BaseUrl .. LibraryRepo .. "Library.lua")
if not LibrarySource then
    warn("roblox.buns: " .. LibraryError)
    return
end
local Library, StartupError = Execute(LibrarySource, "MentalityUI/Library.lua")
if type(Library) ~= "table" then
    warn("roblox.buns could not load MentalityUI: " .. tostring(StartupError or "invalid library"))
    return
end

local PlaceId, GameId = game.PlaceId, game.GameId
local GameName = "Place " .. tostring(PlaceId)
local GameDescription = "Game information is unavailable."
local InfoSuccess, GameInfo = pcall(function()
    return game:GetService("MarketplaceService"):GetProductInfo(PlaceId)
end)
if InfoSuccess and type(GameInfo) == "table" then
    GameName = GameInfo.Name or GameName
    GameDescription = GameInfo.Description or GameDescription
end

-- MentalityUI provides settings and config persistence directly.
Library.Folders.Directory = "roblox.buns"
Library.Folders.Configs = "roblox.buns/Configs/" .. tostring(GameId)
if type(makefolder) == "function" and type(isfolder) == "function" then
    for _, Folder in ipairs({ "roblox.buns", "roblox.buns/Configs", Library.Folders.Configs }) do
        pcall(function()
            if not isfolder(Folder) then makefolder(Folder) end
        end)
    end
end

local Context = {
    Library = Library, MyFullUrl = MyFullUrl, Player = Player,
    PlaceId = PlaceId, GameId = GameId, JobId = game.JobId,
    GameName = GameName, Alive = true, Pages = {},
}
local Cleanups = {}

function Context.Notify(Title, Description, Duration)
    if not Context.Alive then return end
    local Success, Error = pcall(function()
        Library:Notification({
            Title = Title, Description = tostring(Description),
            Duration = Duration or 5, Icon = Icon,
        })
    end)
    if not Success then
        warn(Title .. ": " .. tostring(Description) .. " (notification failed: " .. tostring(Error) .. ")")
    end
end

function Context.AddCleanup(Callback)
    if Context.Alive then
        table.insert(Cleanups, Callback)
    else
        Callback()
    end
end

function Context.Connect(Signal, Callback)
    local Connection = Signal:Connect(function(...)
        if Context.Alive then Callback(...) end
    end)
    Context.AddCleanup(function() Connection:Disconnect() end)
    return Connection
end

local OriginalUnload = Library.Unload
function Context.Destroy()
    if not Context.Alive then return end
    Context.Alive = false
    for Index = #Cleanups, 1, -1 do
        local Success, Error = pcall(Cleanups[Index])
        if not Success then warn("roblox.buns cleanup failed: " .. tostring(Error)) end
    end
    table.clear(Cleanups)
    if Environment.RobloxBunsContext == Context then Environment.RobloxBunsContext = nil end
    OriginalUnload(Library)
end
Library.Unload = Context.Destroy
Environment.RobloxBunsContext = Context

function Context.LoadModule(Path, ModuleContext)
    if not Context.Alive then return false end
    local Source, Error = Download(MyFullUrl .. Path)
    -- HttpGet can yield while this session is being unloaded or replaced.
    if not Context.Alive then return false end
    if not Source then
        Context.Notify("Module download failed", Path .. ": " .. Error)
        return false
    end
    local Initializer, LoadError = Execute(Source, Path)
    if type(Initializer) ~= "function" then
        Context.Notify("Module load failed", Path .. ": " .. tostring(LoadError or "expected an initializer function"))
        return false
    end
    local Success, Result = pcall(Initializer, ModuleContext or Context)
    if not Success then Context.Notify("Module initialization failed", Path .. ": " .. tostring(Result)) end
    return Success
end

local Games = {
    [4298676072] = { Folder = "RC2", Default = "4298676072.lua" },
}

local function Initialize()
    local Window = Library:Window({ Name = "roblox.buns", SubName = GameName, Logo = Icon })
    Context.Window = Window
    local Dashboard = Window:DashboardPage({
        Name = "Dashboard", Icon = "layout-dashboard",
        WelcomeText = "WELCOME TO", HubName = "roblox.buns",
        StatusText = "Ready", Badge = "PLAYER",
        GameName = GameName, GameDescription = GameDescription,
        Links = {
            {
                Icon = "copy", Tooltip = "Copy Discord to clipboard",
                Callback = function()
                    local Success = type(setclipboard) == "function" and pcall(setclipboard, "https://discord.gg/ys78VPnnJQ")
                    Context.Notify(Success and "Copied" or "Clipboard unavailable",
                        Success and "Discord link copied." or "Could not copy the Discord link.", 2)
                end,
            },
        },
        Stats = {
            { Name = "TIME", Icon = "clock", GetValue = function() return os.date("%H:%M:%S") end },
            { Name = "GAMETIME", Icon = "clock", GetValue = function()
                return tostring(math.floor(workspace.DistributedGameTime)) .. "s"
            end },
        },
    })
    Window:TabDivider()
    Window:Category("Main")
    Context.Pages.Main = Window:Page({ Name = "Main", Icon = "house" })
    Window:Category("Game")
    Context.Pages.Game = Window:Page({ Name = GameName, Icon = "gamepad-2" })
    Context.Pages.Universal = Window:Page({ Name = "Universal", Icon = "globe" })
    Context.Pages.PlayersList = Window:Page({ Name = "Players List", Icon = "users" })
    Context.Pages.Scripts = Window:Page({ Name = "Scripts", Icon = "code" })
    Window:TabDivider()

    for _, Path in ipairs({ "main.lua", "universal.lua", "playerslist.lua", "scripts.lua" }) do
        Context.LoadModule(Path)
    end
    local GameData = Games[GameId]
    if GameData then
        local Filename = GameData.Places and GameData.Places[PlaceId] or GameData.Default
        Context.LoadModule("games/" .. GameData.Folder .. "/" .. Filename)
    else
        Context.Pages.Game:Section({ Name = "Support", Side = 1 }):Label("No game module is available for this game.")
        Context.Notify("Unsupported game", "Universal controls are available. GameId: " .. tostring(GameId))
    end
    Context.LoadModule("settings.lua")
    Dashboard:AddCard({ Name = "Main", Description = "Hub information and controls.", Icon = "house", Tab = Context.Pages.Main })
    Dashboard:AddCard({ Name = "Universal", Description = "Player movement controls.", Icon = "globe", Tab = Context.Pages.Universal })
    Dashboard:AddCard({ Name = "Players", Description = "Live server roster.", Icon = "users", Tab = Context.Pages.PlayersList })
end

local Success, Error = pcall(Initialize)
if not Success then
    warn("roblox.buns startup failed: " .. tostring(Error))
    Context.Destroy()
    return
end
return Context
