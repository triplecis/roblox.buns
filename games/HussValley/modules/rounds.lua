return function(Context)
    local Section = Context.Sections.Rounds
    local Role = Section:Label("Your role: Unknown")
    local Counts = Section:Label("")
    local Time = Section:Label("")
    local Status = Section:Label("")
    local RefreshInfo = Context.CreateList(Section, "HussValleyRoundInfo", function() end)
    Section:Button({ Name = "Refresh round information", Callback = Context.RefreshData })
    Context.Subscribe(function(Snapshot)
        Role:SetText("Your role: " .. tostring(Snapshot.GameRole or Snapshot.Role))
        Counts:SetText(string.format("Runners: %d | Catchers: %d | Unknown: %d",
            #Snapshot.Runners, #Snapshot.Chasers, Snapshot.Unknown))
        local Seconds = Snapshot.ServerSeconds
        Time:SetText(string.format("Server uptime: %02d:%02d:%02d",
            math.floor(Seconds / 3600), math.floor(Seconds / 60) % 60, Seconds % 60))
        Status:SetText(#Snapshot.RoundInfo > 0 and "Available round information"
            or "Round information is not exposed.")
        RefreshInfo(Snapshot.RoundInfo)
    end)
end
