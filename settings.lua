local KeybindList = Library:KeybindList("Keybinds") -- optional; pass nil on touch-only UIs if you prefer

Library:CreateSettingsPage(Window, KeybindList, { PinToBottom = true })
