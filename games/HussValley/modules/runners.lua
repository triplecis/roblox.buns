-- Runner roster, selection, and camera spectating controls.
return function(Context)
    local Section = Context.Sections.Runners
    Section:Label("Live Runner roster")
    Context.CreateRoleRoster(Section, "Runners")
end
