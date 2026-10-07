return function(Context)
    local Section = Context.Sections.Rewards
    local Status = Section:Label("")
    local RefreshStats = Context.CreateList(Section, "HussValleyRewardStats", function() end)
    Context.State.RewardBaselines = {}
    Section:Button({
        Name = "Reset session gains",
        Callback = function()
            local Snapshot = Context.RefreshData()
            Context.State.RewardBaselines = table.clone(Snapshot.Stats)
            Context.RefreshData()
        end,
    })
    Context.Subscribe(function(Snapshot)
        local Rows = {}
        for Name, Value in pairs(Snapshot.Stats) do
            local Baseline = Context.State.RewardBaselines[Name]
            if Baseline == nil then
                Baseline = Value
                Context.State.RewardBaselines[Name] = Value
            end
            local Delta = ""
            if type(Value) == "number" and type(Baseline) == "number" then
                Delta = string.format(" (session %+.0f)", Value - Baseline)
            end
            table.insert(Rows, Name .. ": " .. tostring(Value) .. Delta)
        end
        table.sort(Rows)
        Status:SetText(#Rows > 0 and "Live stats and net session changes"
            or "No public leaderboard stats available.")
        RefreshStats(Rows)
    end)
end
