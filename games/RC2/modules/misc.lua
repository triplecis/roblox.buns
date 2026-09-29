return function(ContextV)
    local Library = ContextV.Library
    local Window = ContextV.Window

    local MiscSection = ContextV.MiscSection 

    local ServerData = workspace.ServerData

    --//
    --// Time game:GetService("Players").LocalPlayer.PlayerGui.HUD.TopRight.Time
    --// ServerTime workspace.ServerData.CurrentCycle --> ClockTime
    --//

    local function UpdateTime()
        local Time = ServerData.ClockTime
    end

    local TimeLabel = MiscSection:Label(Time):UpdateTime()
end