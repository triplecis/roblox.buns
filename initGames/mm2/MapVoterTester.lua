--// MM2 Map Voter //--
local UserInputService = game:GetService("UserInputService")

local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

local VotePadPositions = {
	Left = Vector3.new(-10.187439, -64.8124008, -95.0001221),
	Center = Vector3.new(-0.187438965, -64.8124008, -96.2501221),
	Right = Vector3.new(9.81256104, -64.8124008, -95.0001221)
}

--// Settings

local SelectedPad = "Left"
local TeleportCount = 1
local Running = false

local Dragging = false
local DragStart
local StartPosition

--// GUI

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2MapVoter"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = Player:WaitForChild("CoreGui")

local Main = Instance.new("Frame")
Main.Size = UDim2.fromOffset(300, 250)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = Main

--// Title

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 35)
Title.BackgroundTransparency = 1
Title.Text = "MM2 Map Voter"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.Parent = Main

--// Vote Pad Label

local PadLabel = Instance.new("TextLabel")
PadLabel.Size = UDim2.new(1, -20, 0, 25)
PadLabel.Position = UDim2.fromOffset(10, 40)
PadLabel.BackgroundTransparency = 1
PadLabel.Text = "Vote Pad"
PadLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
PadLabel.TextSize = 14
PadLabel.Font = Enum.Font.Gotham
PadLabel.TextXAlignment = Enum.TextXAlignment.Left
PadLabel.Parent = Main

--// Pad Buttons

local Pads = {
	Left = UDim2.fromOffset(10, 70),
	Center = UDim2.fromOffset(105, 70),
	Right = UDim2.fromOffset(200, 70)
}

local PadButtons = {}

for Name, Position in pairs(Pads) do
	local Button = Instance.new("TextButton")
	Button.Size = UDim2.fromOffset(85, 35)
	Button.Position = Position
	Button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	Button.Text = Name
	Button.TextColor3 = Color3.fromRGB(255, 255, 255)
	Button.TextSize = 14
	Button.Font = Enum.Font.Gotham
	Button.BorderSizePixel = 0
	Button.Parent = Main

	local ButtonCorner = Instance.new("UICorner")
	ButtonCorner.CornerRadius = UDim.new(0, 6)
	ButtonCorner.Parent = Button

	PadButtons[Name] = Button

	Button.MouseButton1Click:Connect(function()
		if Running then
			return
		end

		SelectedPad = Name

		for PadName, PadButton in pairs(PadButtons) do
			if PadName == SelectedPad then
				PadButton.BackgroundColor3 = Color3.fromRGB(70, 120, 255)
			else
				PadButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
			end
		end
	end)
end

PadButtons.Left.BackgroundColor3 = Color3.fromRGB(70, 120, 255)

--// Teleport Count

local CountLabel = Instance.new("TextLabel")
CountLabel.Size = UDim2.new(1, -20, 0, 25)
CountLabel.Position = UDim2.fromOffset(10, 115)
CountLabel.BackgroundTransparency = 1
CountLabel.Text = "Teleport Count"
CountLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
CountLabel.TextSize = 14
CountLabel.Font = Enum.Font.Gotham
CountLabel.TextXAlignment = Enum.TextXAlignment.Left
CountLabel.Parent = Main

local CountBox = Instance.new("TextBox")
CountBox.Size = UDim2.new(1, -20, 0, 35)
CountBox.Position = UDim2.fromOffset(10, 140)
CountBox.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
CountBox.Text = "1"
CountBox.PlaceholderText = "Number of teleports"
CountBox.TextColor3 = Color3.fromRGB(255, 255, 255)
CountBox.TextSize = 14
CountBox.Font = Enum.Font.Gotham
CountBox.ClearTextOnFocus = false
CountBox.BorderSizePixel = 0
CountBox.Parent = Main

local CountCorner = Instance.new("UICorner")
CountCorner.CornerRadius = UDim.new(0, 6)
CountCorner.Parent = CountBox

--// Teleport Button

local TeleportButton = Instance.new("TextButton")
TeleportButton.Size = UDim2.fromOffset(135, 40)
TeleportButton.Position = UDim2.fromOffset(10, 185)
TeleportButton.BackgroundColor3 = Color3.fromRGB(60, 170, 90)
TeleportButton.Text = "Teleport"
TeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TeleportButton.TextSize = 15
TeleportButton.Font = Enum.Font.GothamBold
TeleportButton.BorderSizePixel = 0
TeleportButton.Parent = Main

local TeleportCorner = Instance.new("UICorner")
TeleportCorner.CornerRadius = UDim.new(0, 6)
TeleportCorner.Parent = TeleportButton

--// Destroy Button

local DestroyButton = Instance.new("TextButton")
DestroyButton.Size = UDim2.fromOffset(135, 40)
DestroyButton.Position = UDim2.fromOffset(155, 185)
DestroyButton.BackgroundColor3 = Color3.fromRGB(170, 60, 60)
DestroyButton.Text = "Destroy GUI"
DestroyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
DestroyButton.TextSize = 15
DestroyButton.Font = Enum.Font.GothamBold
DestroyButton.BorderSizePixel = 0
DestroyButton.Parent = Main

local DestroyCorner = Instance.new("UICorner")
DestroyCorner.CornerRadius = UDim.new(0, 6)
DestroyCorner.Parent = DestroyButton

--// Drag Logic

Main.InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		Dragging = true
		DragStart = Input.Position
		StartPosition = Main.Position

		Input.Changed:Connect(function()
			if Input.UserInputState == Enum.UserInputState.End then
				Dragging = false
			end
		end)
	end
end)

UserInputService.InputChanged:Connect(function(Input)
	if not Dragging then
		return
	end

	if Input.UserInputType == Enum.UserInputType.MouseMovement then
		local Delta = Input.Position - DragStart

		Main.Position = UDim2.new(
			StartPosition.X.Scale,
			StartPosition.X.Offset + Delta.X,
			StartPosition.Y.Scale,
			StartPosition.Y.Offset + Delta.Y
		)
	end
end)

--// Teleport Logic

TeleportButton.MouseButton1Click:Connect(function()
	if Running then
		return
	end

	local Count = tonumber(CountBox.Text)

	if not Count or Count < 1 then
		CountBox.Text = "1"
		return
	end

	Count = math.floor(Count)

	Running = true
	TeleportButton.Text = "Running..."

	for i = 1, Count do
		-- Get the current character
		Character = Player.Character or Player.CharacterAdded:Wait()
		HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

		local Humanoid = Character:WaitForChild("Humanoid")
		local Position = VotePadPositions[SelectedPad]

		-- Teleport to the vote pad
		HumanoidRootPart.CFrame = CFrame.new(Position)

		-- Give the teleport a moment to register
		task.wait(0.2)

		-- Kill the character
		Humanoid.Health = 0

		-- Don't wait for anything on the final iteration
		if i < Count then
			-- Wait until the character actually respawns
			Character = Player.CharacterAdded:Wait()

			-- Make sure the new character is ready
			HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
			Character:WaitForChild("Humanoid")
		end
	end

	TeleportButton.Text = "Teleport"
	Running = false
end)


--// Destroy GUI

DestroyButton.MouseButton1Click:Connect(function()
	ScreenGui:Destroy()
end)