--// Scripts //--
print("Loading scripts module...")

--// Services //--
local TeleportService = game:GetService("TeleportService")

print("Loading Scripts module...")

--// Get Games //--
print("Fetching all game scripts...")
local Games = _Tabs.Scripts:AddLeftTabbox("Games")

local Undetected = Games:AddTab("Undetected")
local Detected = Games:AddTab("Detected")