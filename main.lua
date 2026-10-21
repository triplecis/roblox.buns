-- Show game and player details, with a button to unload the current session.
return function(context)
    local section = context.Pages.Main:Section({
        Name = "roblox.buns",
        Icon = "house",
        Side = 1,
    })

    section:Label("Game: " .. context.GameName)
    section:Label(
        "Player: " .. context.Player.DisplayName .. " (@" .. context.Player.Name .. ")"
    )
    section:Label("Game ID: " .. tostring(context.GameId))
    section:Label("Place ID: " .. tostring(context.PlaceId))

    section:Button({
        Name = "Unload hub",
        Icon = "power",
        Callback = context.Destroy,
    })
end
