-- Display the replicated server cycle clock in 24-hour format.
return function(context)
    local runService = game:GetService("RunService")
    local clockLabel = context.Sections.Misc:Label("Server time unavailable")
    local elapsedSeconds = 0

    local function readClockHours()
        local serverData = workspace:FindFirstChild("ServerData")
        local currentCycle = serverData and serverData:FindFirstChild("CurrentCycle")
        local clockValue = currentCycle and currentCycle:FindFirstChild("ClockTime")

        if not clockValue or not clockValue:IsA("ValueBase") then
            return nil
        end

        local hours = tonumber(clockValue.Value)
        if not hours or hours ~= hours or math.abs(hours) == math.huge then
            return nil
        end

        return hours
    end

    local function updateClockLabel()
        local hours = readClockHours()
        if not hours then
            clockLabel:SetText("Server time unavailable")
            return
        end

        local totalMinutes = math.floor(hours * 60 + 0.000001) % (24 * 60)
        local displayHours = math.floor(totalMinutes / 60)
        local displayMinutes = totalMinutes % 60

        clockLabel:SetText(string.format(
            "Server time: %02d:%02d",
            displayHours,
            displayMinutes
        ))
    end

    context.Connect(runService.Heartbeat, function(deltaTime)
        elapsedSeconds = elapsedSeconds + deltaTime
        if elapsedSeconds < 1 then
            return
        end

        elapsedSeconds = elapsedSeconds % 1
        updateClockLabel()
    end)

    updateClockLabel()
end
