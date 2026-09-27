--// Steal an egg //--

local Player = game:GetService("Players").LocalPlayer
local PlayerUserId = tostring(Player.UserId)

local PlotsFolder = workspace.Plots
local AreaEggs = workspace:WaitForChild("AreaEggSlotsClient") 

local PlayerPlot = nil

local function FindProximityPrompts()
    for _, part in ipairs(Workspace:GetDescendants()) do
        if part:IsA("Part")
            and part.Name == "SmartPromptPart"
            and part:FindFirstChildOfClass("ProximityPrompt") then

            print("Found ProximityPrompt: " .. part.Name)
        end
    end
end

local function FindPlotUsingImages()
    for _, plot in ipairs(PlotsFolder:GetChildren()) do
        for _, object in ipairs(plot:GetDescendants()) do
            if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                local image = object.Image
                if image:find("id=" .. PlayerUserId) then
                    PlayerPlot = plot
                    return
                end
            end

            if object:IsA("TextLabel") or object:IsA("TextButton") then
                if object.Text == Player.DisplayName then
                    PlayerPlot = plot
                    return
                end
            end
        end
    end
end

local function FindPlotUsingDisplayNames()
    if PlayerPlot then return end
    for _, v in pairs(PlotsFolder:GetChildren()) do
        if v.PlotSign.PlayerPlotSign.Frame.PlayerName.Text == Player.DisplayName then
            PlayerPlot = v
            break
        end
    end
end

local PlotGroup = _Tabs.Game:AddLeftGroupbox("Steal an egg")
PlotGroup:AddLabel("Plot: " .. PlayerPlot.Name) 

FindPlotUsingImages()
FindPlotUsingDisplayNames()
FindProximityPrompts()