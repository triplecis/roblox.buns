--// Scripts //--
print("Loading scripts module...")

--// Services //--
local TeleportService = game:GetService("TeleportService")

print("Loading Scripts module...")

--// Get Games //--
print("Fetching all game scripts...")
local Games = _Tabs.Scripts:AddLeftGroupbox("Games")
local Undetected = Games:AddLeftTabbox("Undetected Games")
local Detected = Games:AddRightTabbox("Detected Games")

Undetected:AddLabel("Undetected Games")
Detected:AddLabel("Detected Games")

