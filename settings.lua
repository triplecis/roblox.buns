return function(Context)
    local Library = Context.Library
    local KeybindList = Library:KeybindList("Keybinds")
    Context.Pages.Settings = Library:CreateSettingsPage(Context.Window, KeybindList)
end
