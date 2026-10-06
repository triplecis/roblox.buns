return function(Context)
    local Clock = Context.Sections.Misc:Label("Server time unavailable")
    local Elapsed = 0

    local function Update()
        local ServerData = workspace:FindFirstChild("ServerData")
        local Cycle = ServerData and ServerData:FindFirstChild("CurrentCycle")
        local ClockTime = Cycle and Cycle:FindFirstChild("ClockTime")
        local Hours = ClockTime and ClockTime:IsA("ValueBase") and tonumber(ClockTime.Value)
        if not Hours or Hours ~= Hours or math.abs(Hours) == math.huge then
            Clock:SetText("Server time unavailable")
            return
        end
        local Minutes = math.floor(Hours * 60 + 0.000001) % (24 * 60)
        Clock:SetText(string.format("Server time: %02d:%02d", math.floor(Minutes / 60), Minutes % 60))
    end

    Context.Connect(game:GetService("RunService").Heartbeat, function(DeltaTime)
        Elapsed = Elapsed + DeltaTime
        if Elapsed >= 1 then
            Elapsed = Elapsed % 1
            Update()
        end
    end)
    Update()
end
