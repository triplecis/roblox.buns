return function(Context)
    local Section = Context.Pages.Scripts:Section({ Name = "Scripts", Icon = "code", Side = 1 })
    Section:Label("No additional scripts are configured.")
end
