return function(Context)
    local Section = Context.Sections.Abilities
    Section:Label("Ability definitions")
    Context.CreateCatalog(Section, "Abilities", "HussValleySelectedAbilities")
    local Info = Context.CreateList(Section, "HussValleyAbilityInfo", function() end)
    Context.Subscribe(function(Snapshot) Info(Snapshot.AbilityInfo) end)
    Section:Label("Equipping requires a verified game binding.")
end
