--//
return function(Context)
    local Library = Context.Library
    local Window = Context.Window

    local ScriptsPage = Context.Scripts


    Library:Notification({
            Title = "Scripts page Loaded",
            Description = "The scripts page has been loaded successfully.",
            Duration = 8,
            Icon = "89380854415542",
        })
    
end