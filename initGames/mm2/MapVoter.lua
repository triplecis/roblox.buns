--// MM2 Map Voter //--

--// Services

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

--// LinoriaLib

local Repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"

--[[
	Your main Linoria already has its own global Options/Toggles tables.

	When we load another Linoria instance, the new library replaces
	getgenv().Options and getgenv().Toggles.

	We preserve the main tables, load the secondary library, capture
	its tables, and then restore the main tables.
]]

local MainOptions = getgenv().Options
local MainToggles = getgenv().Toggles

local Library = loadstring(game:HttpGet(
	Repo .. "Library.lua?t=" .. DateTime.now().UnixTimestampMillis
))()

-- Capture the Options/Toggles belonging to THIS Linoria instance.

local MapVoterOptions = getgenv().Options
local MapVoterToggles = getgenv().Toggles

-- Restore the main Linoria tables.

getgenv().Options = MainOptions
getgenv().Toggles = MainToggles

--// Vote Pad Positions

local VotePadPositions = {
	Left = Vector3.new(-10.187439, -64.8124008, -95.0001221),
	Center = Vector3.new(-0.187438965, -64.8124008, -96.2501221),
	Right = Vector3.new(9.81256104, -64.8124008, -95.0001221)
}

--// Settings

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
	Tooltip = "Select which vote pad to use."
})

--// Teleport Count

VotingGroup:AddInput("MM2TeleportCount", {
	Default = "1",
	Numeric = true,
	Finished = false,

	Text = "Teleport Count",
	Placeholder = "Enter amount",

	Tooltip = "Number of times to teleport to the vote pad."
})

--// Verify Options Exist

local VotePadOption = MapVoterOptions.MM2VotePad
local TeleportCountOption = MapVoterOptions.MM2TeleportCount

if not VotePadOption then
	warn("[Map Voter] Failed to create Vote Pad option")
	return
end

if not TeleportCountOption then
	warn("[Map Voter] Failed to create Teleport Count option")
	return
end

--// Status

local StatusLabel = StatusGroup:AddLabel("Status: Ready")
local ProgressLabel = StatusGroup:AddLabel("Progress: 0/0")
local SelectedLabel = StatusGroup:AddLabel("Pad: Left")

local function SetStatus(Text)
	StatusLabel:SetText("Status: " .. Text)
end

local function SetProgress(Current, Total)
	ProgressLabel:SetText(
		("Progress: %d/%d"):format(Current, Total)
	)
end

local function SetSelectedPad(Pad)
	SelectedLabel:SetText("Pad: " .. Pad)
end

--// Dropdown Changed

VotePadOption:OnChanged(function(Value)
	SetSelectedPad(Value)
end)

--// Black Screen
--// Uses Linoria's own protected ScreenGui.

local BlackScreen = Instance.new("Frame")

BlackScreen.Name = "MM2MapVoterBlackScreen"

BlackScreen.Size = UDim2.fromScale(1, 1)
BlackScreen.Position = UDim2.fromScale(0, 0)

BlackScreen.BackgroundColor3 = Color3.new(0, 0, 0)
BlackScreen.BorderSizePixel = 0

BlackScreen.Visible = false
BlackScreen.ZIndex = 999999

BlackScreen.Parent = Library.ScreenGui

--// Start Voting

VotingGroup:AddButton({
	Text = "Start Voting",

	Func = function()
		if Running then
			return
		end

		if Unloaded then
			return
		end

		-- Read the CURRENT value directly from this Linoria instance.

		local Count = tonumber(TeleportCountOption.Value)
		local SelectedPad = VotePadOption.Value

		-- Validate count.

		if not Count or Count < 1 then
			SetStatus("Invalid count")
			return
		end

		Count = math.floor(Count)

		-- Validate pad.

		local Position = VotePadPositions[SelectedPad]

		if not Position then
			SetStatus("Invalid vote pad")
			return
		end

		Running = true

		SetStatus("Starting...")
		SetProgress(0, Count)

		-- Hide the screen for the entire voting sequence.

		BlackScreen.Visible = true

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

				-- Get HumanoidRootPart.

				local HumanoidRootPart = Character:WaitForChild(
					"HumanoidRootPart"
				)

				-- Teleport.

				HumanoidRootPart.CFrame = CFrame.new(Position)

				-- Give the vote pad a small amount of time to register.

				task.wait(0.1)

				if not Running or Unloaded then
					break
				end

				-- Kill.

				SetStatus("Dying...")

				Humanoid.Health = 0

				-- Wait for respawn unless this was the final cycle.

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

					-- Make sure the new character is completely ready.

					local NewCharacter = Player.Character

					NewCharacter:WaitForChild("Humanoid")
					NewCharacter:WaitForChild("HumanoidRootPart")
				end
			end

			-- Finished / stopped.

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

			-- Reveal the game after the entire sequence.

			if BlackScreen then
				BlackScreen.Visible = false
			end
		end)
	end
})

--// Stop

VotingGroup:AddButton({
	Text = "Stop",

	Func = function()
		if not Running then
			SetStatus("Ready")

			if BlackScreen then
				BlackScreen.Visible = false
			end

			return
		end

		Running = false

		if BlackScreen then
			BlackScreen.Visible = false
		end

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

		if BlackScreen then
			BlackScreen.Visible = false
		end

		Library:Unload()
	end
})

MenuGroup:AddLabel("Menu Bind"):AddKeyPicker("MenuKeybind", {
	Default = "End",
	NoUI = true,
	Text = "Menu keybind"
})

-- Set this instance's keybind.

Library.ToggleKeybind = MapVoterOptions.MenuKeybind

--// Cleanup

Library:OnUnload(function()

	Unloaded = true
	Running = false

	if BlackScreen then
		BlackScreen.Visible = false
	end

	-- Restore the main Linoria globals.

	getgenv().Options = MainOptions
	getgenv().Toggles = MainToggles

end)