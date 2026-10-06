return function(Context)
    local Section = Context.Pages.Main:Section({ Name = "roblox.buns", Icon = "house", Side = 1 })
    Section:Label("Game: " .. Context.GameName)
    Section:Label("Player: " .. Context.Player.DisplayName .. " (@" .. Context.Player.Name .. ")")
    Section:Label("Game ID: " .. tostring(Context.GameId))
    Section:Label("Place ID: " .. tostring(Context.PlaceId))
    Section:Button({ Name = "Unload hub", Icon = "power", Callback = Context.Destroy })
end
