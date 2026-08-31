--// Murder Mystery 2 //--

local TabBox = _Tabs.Game:AddLeftTabbox("Murder Mystery 2")
local Created = TabBox:AddTab("Created")
local Ripped = TabBox:AddTab("Ripped")

local MapVoter = Created:AddButton("Map Voter", function()
	local Success, Source = pcall(function()
		return game:HttpGet(
			"https://raw.githubusercontent.com/triplecis/roblox.buns/main/initGames/mm2/MapVoterTester.lua"
		)
	end)

	if not Success then
		warn("Failed to download MapVoterTester.lua:", Source)
		return
	end

	local Execute = loadstring(Source)

	if not Execute then
		warn("Failed to compile MapVoterTester.lua")
		return
	end

	Execute()
end)