return function(Context)
    local Section = Context.Sections.Rounds
    Section:Label("Round flow and arena crossings")
    Section:Label("Hero / Chicken choices")
    Section:Label("Functions pending.")

    -- Example control: keep flags unique to Huss Valley.
    -- Section:Toggle({
    --     Name = "Example feature",
    --     Flag = "HussValleyExampleEnabled",
    --     Default = false,
    --     Callback = function(Enabled)
    --         Context.State.ExampleEnabled = Enabled
    --     end,
    -- })
end
