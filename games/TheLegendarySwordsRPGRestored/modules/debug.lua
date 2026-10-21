-- Runtime information useful when checking game and place registration.
return function(context)
    local section = context.Sections.Debug

    section:Label("Universe ID: " .. tostring(context.GameId))
    section:Label("Place ID: " .. tostring(context.PlaceId))
end
