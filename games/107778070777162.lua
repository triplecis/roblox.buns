--// Steal an egg //--

local Plots = game:GetService("Workspace").Plots:GetChildren()
local Player = game:GetService("Players").LocalPlayer
local PlayerUserId = tostring(Player.UserId)

local PlotsFolder = workspace.Plots
local AreaEggs = workspace:WaitForChild("AreaEggSlotsClient") 

local PlayerPlot = nil

local function FindPlotUsingImages()
    for _, plot in ipairs(PlotsFolder:GetChildren()) do
        for _, object in ipairs(plot:GetDescendants()) do
            if object:IsA("ImageLabel") or object:IsA("ImageButton") then
                local image = object.Image
                if image:find("id=" .. PlayerUserId) then
                    PlayerPlot = plot
                    print("Found plot using image: " .. plot.Name)
                    return
                end
            end

            if object:IsA("TextLabel") or object:IsA("TextButton") then
                if object.Text == Player.DisplayName then
                    PlayerPlot = plot
                    print("Found plot using text : " .. plot.Name)
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
            print("Found plot using display name: " .. v.Name)
            break
        end
    end
end

local PlotGroup = _Tabs.Game:AddLeftGroupbox("Steal an egg")
PlotGroup:AddLabel("Steal an egg from another player's plot") 

FindPlotUsingImages()
FindPlotUsingDisplayNames()