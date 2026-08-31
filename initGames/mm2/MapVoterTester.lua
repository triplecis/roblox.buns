```lua
--// MM2 Map Voter //--

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer

--// Vote Pad Positions

local VotePadPositions = {
	Left = Vector3.new(-10.187439, -64.8124008, -95.0001221),
	Center = Vector3.new(-0.187438965, -64.8124008, -96.2501221),
	Right = Vector3.new(9.81256104, -64.8124008, -95.0001221)
}

--// Settings

local SelectedPad = "Left"
local Running = false

--// Remove Previous GUI

pcall(function()
	local Existing = CoreGui:FindFirstChild("// MM2 Map Voter //")

	if Existing then
		Existing:Destroy()
	end
end)

pcall(function()
	local Existing = Player:WaitForChild("PlayerGui"):FindFirstChild("// MM2 Map Voter //")

	if Existing then
		Existing:Destroy()
	end
end)

--// GUI

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "// MM2 Map Voter //"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

--// Try CoreGui, fallback to PlayerGui

local CoreGuiSuccess = pcall(function()
	ScreenGui.Parent = CoreGui
end)

if not CoreGuiSuccess or ScreenGui.Parent ~= CoreGui then
	ScreenGui.Parent = Player:WaitForChild("PlayerGui")
end

--// Main Window

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(300, 250)
Main.Position = UDim2.fromScale(0.5, 0.5)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Main.BorderSizePixel = 0
Main.Parent = ScreenGui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = Main

--// Title Bar

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 35)
TitleBar.BackgroundTransparency = 1
TitleBar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -20, 1, 0)
Title.Position = UDim2.fromOffset(10, 0)
Title.BackgroundTransparency = 1
Title.Text = "MM2 Map Voter"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

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

	Button.Name = Name
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
CountBox.Name = "CountBox"
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
TeleportButton.Name = "Teleport"
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
DestroyButton.Name = "Destroy"
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

--// Dragging

local Dragging = false
local DragStart
local StartPosition

TitleBar.InputBegan:Connect(function(Input)
	if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end

	Dragging = true
	DragStart = Input.Position
	StartPosition = Main.Position

	local Connection

	Connection = Input.Changed:Connect(function()
		if Input.UserInputState == Enum.UserInputState.End then
			Dragging = false

			if Connection then
				Connection:Disconnect()
			end
		end
	end)
end)

UserInputService.InputChanged:Connect(function(Input)
	if not Dragging then
		return
	end

	if Input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end

	local Delta = Input.Position - DragStart

	Main.Position = UDim2.new(
		StartPosition.X.Scale,
		StartPosition.X.Offset + Delta.X,
		StartPosition.Y.Scale,
		StartPosition.Y.Offset + Delta.Y
	)
end)

--// Teleport / Death Logic

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

		-- Get current character

		local Character = Player.Character or Player.CharacterAdded:Wait()

		local Humanoid = Character:WaitForChild("Humanoid")
		local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

		-- Get selected vote pad

		local Position = VotePadPositions[SelectedPad]

		if not Position then
			break
		end

		-- Teleport to vote pad

		HumanoidRootPart.CFrame = CFrame.new(Position)

		-- Allow the teleport to register

		task.wait(0.25)

		-- Kill player

		Humanoid.Health = 0

		-- Wait for respawn before next cycle

		if i < Count then
			repeat
				task.wait()
			until Player.Character and Player.Character ~= Character

			Player.Character:WaitForChild("Humanoid")
			Player.Character:WaitForChild("HumanoidRootPart")
		end
	end

	TeleportButton.Text = "Teleport"
	Running = false
end)

--// Destroy

DestroyButton.MouseButton1Click:Connect(function()
	Running = false
	ScreenGui:Destroy()
end)
```
