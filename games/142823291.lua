--// Murder Mystery 2 //--

local TabBox = _Tabs.Game:AddLeftTabbox("Murder Mystery 2")
local Created = TabBox:AddTab("Created")
local Ripped = TabBox:AddTab("Ripped")

local MapVoter = Created:AddButton("Map Voter", function()
	local Success, Source = pcall(function()
		return game:HttpGet(
			"https://raw.githubusercontent.com/triplecis/roblox.buns/main/initGames/mm2/MapVoter.lua?t=" .. os.time()
		)
	end)

	if not Success then
		warn("[Map Voter] HTTP Error:", Source)
		return
	end

	print("[Map Voter] Downloaded:", #Source, "characters")

	local Execute, CompileError = loadstring(Source)

	if not Execute then
		warn("[Map Voter] COMPILE ERROR:")
		warn(CompileError)

		print("----- SOURCE -----")
		print(Source)
		print("----- END SOURCE -----")

		return
	end

	print("[Map Voter] Successfully compiled")

	local RunSuccess, RuntimeError = pcall(Execute)

	if not RunSuccess then
		warn("[Map Voter] RUNTIME ERROR:")
		warn(RuntimeError)
	end
end)

local MapVoterTest = Created:AddButton("Map Voter Test", function()
	local Success, Source = pcall(function()
		return game:HttpGet(
			"https://raw.githubusercontent.com/triplecis/roblox.buns/main/initGames/mm2/MapVoterTester.lua?t=" .. os.time()
		)
	end)

	if not Success then
		warn("[Map Voter] HTTP Error:", Source)
		return
	end

	print("[Map Voter] Downloaded:", #Source, "characters")

	local Execute, CompileError = loadstring(Source)

	if not Execute then
		warn("[Map Voter] COMPILE ERROR:")
		warn(CompileError)

		print("----- SOURCE -----")
		print(Source)
		print("----- END SOURCE -----")

		return
	end

	print("[Map Voter] Successfully compiled")

	local RunSuccess, RuntimeError = pcall(Execute)

	if not RunSuccess then
		warn("[Map Voter] RUNTIME ERROR:")
		warn(RuntimeError)
	end
end)