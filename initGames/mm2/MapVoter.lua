--// MM2 Map Voter //--

--// Services

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

--// LinoriaLib

local Repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"

--// Preserve Existing Linoria Globals

local MainOptions = getgenv().Options
local MainToggles = getgenv().Toggles

--// Load Separate Linoria Instance

local Library = loadstring(game:HttpGet(
	Repo .. "Library.lua?t=" .. DateTime.now().UnixTimestampMillis
))()

--// Capture This Instance's Options/Toggles

local MapVoterOptions = getgenv().Options
local MapVoterToggles = getgenv().Toggles

--// Restore Main Linoria Globals

getgenv().Options = MainOptions
getgenv().Toggles = MainToggles

--// Vote Pad Positions

local VotePadPositions = {
	Left = Vector3.new(-10.187439, -64.8124008, -95.0001221),
	Center = Vector3.new(-0.187438965, -64.8124008, -96.2501221),
	Right = Vector3.new(9.81256104, -64.8124008, -95.0001221)
}

--// State

local Running = false
local Unloaded = false

--// Window

local Window = Library:CreateWindow({
	Title = "MM2 Map Voter",
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

--// Tabs

local Tabs = {
	Main = Window:AddTab("Map Voter"),
	["UI Settings"] = Window:AddTab("UI Settings")
}

--// Groupboxes

local VotingGroup = Tabs.Main:AddLeftGroupbox("Voting")
local StatusGroup = Tabs.Main:AddRightGroupbox("Status")

--// Vote Pad Dropdown

VotingGroup:AddDropdown("MM2VotePad", {
	Values = {
		"Left",
		"Center",
		"Right"
	},

	Default = "Left",
	Multi = false,

	Text = "Vote Pad",
	Tooltip = "Select the vote pad to use."
})

--// Teleport Count

VotingGroup:AddInput("MM2TeleportCount", {
	Default = "1",
	Numeric = true,
	Finished = false,

	Text = "Teleport Count",
	Placeholder = "Enter amount",

	Tooltip = "Number of teleport/death cycles."
})

--// Capture Options

local VotePadOption = MapVoterOptions.MM2VotePad
local TeleportCountOption = MapVoterOptions.MM2TeleportCount

if not VotePadOption then
	warn("[Map Voter] Vote Pad option failed to initialize.")
	return
end

if not TeleportCountOption then
	warn("[Map Voter] Teleport Count option failed to initialize.")
	return
end

--// Status

local StatusLabel = StatusGroup:AddLabel("Status: Ready")
local ProgressLabel = StatusGroup:AddLabel("Progress: 0/0")
local PadLabel = StatusGroup:AddLabel("Pad: Left")

local function SetStatus(Text)
	StatusLabel:SetText("Status: " .. Text)
end

local function SetProgress(Current, Total)
	ProgressLabel:SetText(
		("Progress: %d/%d"):format(Current, Total)
	)
end

local function SetPad(Pad)
	PadLabel:SetText("Pad: " .. Pad)
end

--// Update Pad Display

VotePadOption:OnChanged(function(Value)
	SetPad(Value)
end)

--// Start Voting

VotingGroup:AddButton({
	Text = "Start Voting",

	Func = function()

		if Running then
			SetStatus("Already running")
			return
		end

		if Unloaded then
			return
		end

		-- Read the current values directly from this Linoria instance.

		local SelectedPad = VotePadOption.Value
		local Count = tonumber(TeleportCountOption.Value)

		-- Validate count.

		if not Count or Count < 1 then
			SetStatus("Invalid teleport count")
			return
		end

		Count = math.floor(Count)

		-- Validate pad.

		local Position = VotePadPositions[SelectedPad]

		if not Position then
			SetStatus("Invalid vote pad")
			return
		end

		-- Begin.

		Running = true

		SetStatus("Starting...")
		SetProgress(0, Count)

		task.spawn(function()

			for i = 1, Count do

				if not Running or Unloaded then
					break
				end

				-- Update progress.

				SetProgress(i, Count)
				SetStatus("Teleporting...")

				-- Get current character.

				local Character = Player.Character

				if not Character then
					Character = Player.CharacterAdded:Wait()
				end

				if not Running or Unloaded then
					break
				end

				-- Get Humanoid.

				local Humanoid = Character:WaitForChild("Humanoid")

				-- Get RootPart.

				local HumanoidRootPart = Character:WaitForChild(
					"HumanoidRootPart"
				)

				-- Teleport to selected pad.

				HumanoidRootPart.CFrame = CFrame.new(Position)

				-- Small delay to allow the vote pad to register.

				task.wait(0.1)

				if not Running or Unloaded then
					break
				end

				-- Kill.

				SetStatus("Dying...")

				Humanoid.Health = 0

				-- Wait for respawn.

				if i < Count then

					SetStatus("Waiting for respawn...")

					repeat
						task.wait()
					until (
						not Running
						or Unloaded
						or (
							Player.Character
							and Player.Character ~= Character
						)
					)

					if not Running or Unloaded then
						break
					end

					-- Wait for the new character to be ready.

					local NewCharacter = Player.Character

					NewCharacter:WaitForChild("Humanoid")
					NewCharacter:WaitForChild("HumanoidRootPart")
				end
			end

			--// Complete

			if Unloaded then
				return
			end

			if Running then
				SetProgress(Count, Count)
				SetStatus("Finished")
			else
				SetStatus("Stopped")
			end

			Running = false
		end)
	end
})

--// Stop

VotingGroup:AddButton({
	Text = "Stop",

	Func = function()

		if not Running then
			SetStatus("Ready")
			return
		end

		Running = false

		SetStatus("Stopped")
	end
})

--// UI Settings

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu")

MenuGroup:AddButton({
	Text = "Unload",

	Func = function()

		Running = false
		Unloaded = true

		Library:Unload()
	end
})

MenuGroup:AddLabel("Menu Bind"):AddKeyPicker("MenuKeybind", {
	Default = "End",
	NoUI = true,
	Text = "Menu keybind"
})

--// Toggle Keybind

Library.ToggleKeybind = MapVoterOptions.MenuKeybind

--// Cleanup

Library:OnUnload(function()

	Running = false
	Unloaded = true

	-- Restore the original Linoria globals.

	getgenv().Options = MainOptions
	getgenv().Toggles = MainToggles

end)
