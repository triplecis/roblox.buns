--// Scripts //--
print("Loading scripts module...")

--// Services //--
local TeleportService = game:GetService("TeleportService")

print("Loading Scripts module...")

--// Get Games //--
print("Fetching all game scripts...")
local Games = _Tabs.Scripts:AddLeftGroupbox("Games")
local Undetected = Games:AddTab("Undetected Games")
local Detected = Games:AddTab("Detected Games")

Undetected:AddLabel("Undetected Games")
Detected:AddLabel("Detected Games")

