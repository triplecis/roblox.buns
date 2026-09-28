return function(Context)
    local Library = Context.Library
    local Window = Context.Window
    local SaveManager = Context.SaveManager
    local ThemeManager = Context.ThemeManager

    local KeybindList = Library:KeybindList("Keybinds") -- optional; pass nil on touch-only UIs if you prefer

    Library:CreateSettingsPage(Window, KeybindList, { PinToBottom = true })

    Library:Notification({
        Title = "Settings", Description = "Settings page loaded.", Duration = 2, Icon = "97594400820219",
    })
    
end