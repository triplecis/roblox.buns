--// Scripts //--

--// Services //--
local TeleportService = game:GetService("TeleportService")

print("Loading Scripts module...")

--// Get Games //--
print("Fetching all game scripts...")
local Games = _Tabs.Scripts:AddLeftGroupbox("Games")
local Undetected = LeftGroupBox:AddTabbox("Undetected Games")
local Detected = LeftGroupBox:AddTabbox("Detected Games")

Undetected:AddLabel("Undetected Games")
Detected:AddLabel("Detected Games")

