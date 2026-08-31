--// Scripts //--
print("Loading scripts module...")

--// Services //--
local TeleportService = game:GetService("TeleportService")

print("Loading Scripts module...")

--// Get Games //--
print("Fetching all game scripts...")
local Games = _Tabs.Scripts:AddLeftTabbox("Games")

Games:AddTab("Undetected")
Games:AddTab("Detected")

