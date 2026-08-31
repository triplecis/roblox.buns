```lua
--// MM2 Map Voter //--

--// Services

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

--// LinoriaLib

local Repo = "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/"

-- Preserve the main Linoria globals.
local OldOptions = getgenv().Options
local OldToggles = getgenv().Toggles

local Library = loadstring(game:HttpGet(
	Repo .. "Library.lua?t=" .. DateTime.now().UnixTimestampMillis
))()

-- Restore the main Linoria globals so this secondary library
-- does not replace the Options/Toggles tables used by your hub.
getgenv().Options = OldOptions
getgenv().Toggles = OldToggles

--// Vote Pad Positions

local VotePadPositions = {
	Left = Vector3.new(-10.187439, -64.8124008, -95.0001221),
	Center = Vector3.new(-0.187438965, -64.8124008, -96.2501221),
	Right = Vector3.new(9.81256104, -64.8124008, -95.0001221)
}

--// Settings

local SelectedPad = "Left"
local TeleportCount = 1
local Running = false

--// Window

local Window = Library:CreateWindow({
	Title = "MM2 Map Voter",
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

--// Tab

local Tab = Window:AddTab("Map Voter")

--// Groupboxes

local VotingGroup = Tab:AddLeftGroupbox("Voting")
local StatusGroup = Tab:AddRightGroupbox("Status")

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

-- Keep a direct reference so we don't depend on the global
-- Options table that Linoria normally places in getgenv().
local VotePadOption = Library.Options
	and Library.Options.MM2VotePad

if VotePadOption then
	VotePadOption:OnChanged(function()
		SelectedPad = VotePadOption.Value
	end)
end

--// Teleport Count

VotingGroup:AddInput("MM2TeleportCount", {
	Default = "1",
	Numeric = true,
	Finished = false,

	Text = "Teleport Count",
	Placeholder = "Enter amount",

	Tooltip = "Number of vote-pad cycles to perform."
})

local TeleportCountOption = Library.Options
	and Library.Options.MM2TeleportCount

if TeleportCountOption then
	TeleportCountOption:OnChanged(function()
		local Value = tonumber(TeleportCountOption.Value)

		if Value and Value >= 1 then
			TeleportCount = math.floor(Value)
		end
	end)
end

--// Status

local StatusLabel = StatusGroup:AddLabel("Status: Ready")
local ProgressLabel = StatusGroup:AddLabel("Progress: 0/0")

local function SetStatus(Status)
	StatusLabel:SetText("Status: " .. Status)
end

local function SetProgress(Current, Total)
	ProgressLabel:SetText(
		("Progress: %d/%d"):format(Current, Total)
	)
end

--// Black Screen
--// This is parented to Linoria's own protected ScreenGui.

local BlackScreen = Instance.new("Frame")

BlackScreen.Name = "MM2MapVoterBlackScreen"
BlackScreen.Size = UDim2.fromScale(1, 1)
BlackScreen.Position = UDim2.fromScale(0, 0)

BlackScreen.BackgroundColor3 = Color3.new(0, 0, 0)
BlackScreen.BorderSizePixel = 0

BlackScreen.Visible = false
BlackScreen.ZIndex = 1000

BlackScreen.Parent = Library.ScreenGui

--// Start Voting

VotingGroup:AddButton({
	Text = "Start Voting",

	Func = function()
		if Running then
			return
		end

		local Count = TeleportCount

		if not Count or Count < 1 then
			SetStatus("Invalid teleport count")
			return
		end

		local Position = VotePadPositions[SelectedPad]

		if not Position then
			SetStatus("Invalid vote pad")
			return
		end

		Count = math.floor(Count)

		Running = true

		SetStatus("Starting...")
		SetProgress(0, Count)

		-- Hide the game during the complete sequence.
		BlackScreen.Visible = true

		task.spawn(function()
			for i = 1, Count do
				if not Running or Library.Unloaded then
					break
				end

				SetProgress(i, Count)
				SetStatus("Teleporting...")

				--// Get current character

				local Character = Player.Character

				if not Character then
					Character = Player.CharacterAdded:Wait()
				end

				local Humanoid = Character:WaitForChild("Humanoid")
				local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

				--// Teleport to vote pad

				HumanoidRootPart.CFrame = CFrame.new(Position)

				-- Give the vote pad a moment to register.
				task.wait(0.1)

				if not Running or Library.Unloaded then
					break
				end

				--// Kill player

				SetStatus("Dying...")

				Humanoid.Health = 0

				--// Wait for new character

				if i < Count then
					SetStatus("Waiting for respawn...")

					repeat
						task.wait()
					until (
						not Running
						or Library.Unloaded
						or (
							Player.Character
							and Player.Character ~= Character
						)
					)

					if not Running or Library.Unloaded then
						break
					end

					Player.Character:WaitForChild("Humanoid")
					Player.Character:WaitForChild("HumanoidRootPart")
				end
			end

			--// Finished

			if Running and not Library.Unloaded then
				SetStatus("Finished")
				SetProgress(Count, Count)
			else
				SetStatus("Stopped")
			end

			Running = false

			-- Reveal the game after the entire sequence.
			BlackScreen.Visible = false
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

		BlackScreen.Visible = false

		SetStatus("Stopped")
	end
})

--// Unload

VotingGroup:AddButton({
	Text = "Unload",

	Func = function()
		Running = false

		BlackScreen.Visible = false

		Library:Unload()
	end
})

--// Cleanup

Library:OnUnload(function()
	Running = false

	if BlackScreen then
		BlackScreen.Visible = false
		BlackScreen:Destroy()
		BlackScreen = nil
	end
end)
```
