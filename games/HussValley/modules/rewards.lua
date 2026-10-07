return function(Context)
    local Section = Context.Sections.Rewards
    Section:Label("Gems, coins, and match rewards")
    Section:Label("Functions pending.")

    -- Context.Connect(Signal, Callback) disconnects listeners when the hub unloads.
    -- Register any other resource teardown with Context.AddCleanup(function() ... end).
    -- Use Context.Notify("Huss Valley", "Message", 3) for notifications.
end
