return function(ModuleContext)
    local Library = ModuleContext.Library
    local Window = ModuleContext.Window

    local MiscSection = ModuleContext.Misc

    local ServerData = workspace.ServerData
    local CurrentCycle = ServerData.CurrentCycle
    local ClockTime = ServerData.ClockTime

    --//
    --// Time game:GetService("Players").LocalPlayer.PlayerGui.HUD.TopRight.Time
    --// ServerTime workspace.ServerData.CurrentCycle --> ClockTime
    --//

   
end

--[[
local _ = game:GetService("Lighting")
local ClockTime_upv_1 = workspace:WaitForChild("ServerData"):WaitForChild("CurrentCycle"):WaitForChild("ClockTime")
local Values_1 = game.Players.LocalPlayer:WaitForChild("Values")
local ShowClock_1 = Values_1:WaitForChild("ShowClock")
local _ClockPass_1 = Values_1:WaitForChild("_ClockPass")
local u1 = nil
local u2 = nil
function Check()
    [
      name: Check
      line: 11
      upvalues:
        u1 (ref,  index: 1)
        ClockTime_upv_1 (copy, index: 2)
        u2 (ref,  index: 3)
    ]
    u1 = math.floor(ClockTime_upv_1.Value)
    u2 = (ClockTime_upv_1.Value - u1) * 60
    local v1 = ((u1 < 10) and "0") or ""
    script.Parent.Text = string.format("%s%s:%s%s", v1, u1, ((u2 < 10) and "0") or "", math.floor(u2))
end
Check()
ClockTime_upv_1:GetPropertyChangedSignal("Value"):Connect(Check)
ShowClock_1:GetPropertyChangedSignal("Value"):Connect(Check)
_ClockPass_1:GetPropertyChangedSignal("Value"):Connect(Check)


]]--