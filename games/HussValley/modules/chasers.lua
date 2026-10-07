return function(Context)
    local Section = Context.Sections.Chasers
    Section:Label("Live Catcher roster")
    Context.CreateRoleRoster(Section, "Chasers")
end
