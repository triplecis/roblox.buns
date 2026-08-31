--// MM2 Map Voter //--
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character.HumanoidRootPart

--[[ a little deprecated due to the votepads all being named "votepad3"
local Lobby

for _, Map in ipairs(workspace:GetDescendants()) do
    if Map:IsA("Model") and Map:FindFirstChild("VotePads") then
        Lobby = Map
    end
end

local VotePads = Lobby:FindFirstChild("VotePads")
]]--

local VotePadPositions = {
    Left = Vector3.new(-10.187439, -64.8124008, -95.0001221)
    Center = Vector3.new(-0.187438965, -64.8124008, -96.2501221)
    Right = Vector3.new(9.81256104, -64.8124008, -95.0001221)
}


