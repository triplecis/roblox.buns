return function(Context)
    local Player = Context.Player
    local Section = Context.Pages.Universal:Section({ Name = "Player", Icon = "user", Side = 1 })
    local Status = Section:Label("Waiting for character...")
    local Humanoid
    local CharacterConnections = {}
    local Baselines, Applied = {}, {}
    local Enabled = { WalkSpeed = false, JumpPower = false, JumpHeight = false }
    local Values = { WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2 }
    local WalkSpeedSuspended = false

    local function DisconnectCharacter()
        for _, Connection in ipairs(CharacterConnections) do Connection:Disconnect() end
        table.clear(CharacterConnections)
    end

    local function Apply(Property)
        if not Humanoid or not Humanoid.Parent or not Enabled[Property] then return end
        if Property == "WalkSpeed" and WalkSpeedSuspended then return end
        local Value = Values[Property]
        if Property == "WalkSpeed" then Value = Baselines.WalkSpeed * (1 + Value / 100) end
        -- Signals may be deferred; remember our writes rather than using a temporary guard.
        Applied[Property] = Value
        if Humanoid[Property] ~= Value then Humanoid[Property] = Value end
    end

    local function Restore(Property)
        if Humanoid and Humanoid.Parent and Baselines[Property] ~= nil then
            -- Capture a game update even if its change signal has not run yet.
            if Applied[Property] ~= nil and Humanoid[Property] ~= Applied[Property] then
                Baselines[Property] = Humanoid[Property]
            end
            Applied[Property] = Baselines[Property]
            Humanoid[Property] = Baselines[Property]
        end
    end

    function Context.SetWalkSpeedSuspended(State)
        if WalkSpeedSuspended == State then return end
        if State and Enabled.WalkSpeed then Restore("WalkSpeed") end
        WalkSpeedSuspended = State
        if not State and Context.Alive then Apply("WalkSpeed") end
    end

    local function UpdateStatus()
        if not Context.Alive then return end
        Status:SetText(Humanoid and (Humanoid.UseJumpPower and "Jump mode: power" or "Jump mode: height")
            or "Waiting for character...")
    end

    local function BindHumanoid(NewHumanoid)
        Humanoid = NewHumanoid
        table.clear(Applied)
        for _, Property in ipairs({ "WalkSpeed", "JumpPower", "JumpHeight" }) do
            Baselines[Property] = Humanoid[Property]
            table.insert(CharacterConnections, Humanoid:GetPropertyChangedSignal(Property):Connect(function()
                if not Context.Alive or Humanoid ~= NewHumanoid then return end
                local Current = NewHumanoid[Property]
                if Current == Applied[Property] then return end
                Baselines[Property] = Current
                Apply(Property)
            end))
            Apply(Property)
        end
        table.insert(CharacterConnections, Humanoid:GetPropertyChangedSignal("UseJumpPower"):Connect(UpdateStatus))
        UpdateStatus()
    end

    local function BindCharacter(Character)
        DisconnectCharacter()
        Humanoid = nil
        table.clear(Baselines)
        table.clear(Applied)
        UpdateStatus()
        -- Listen first so a delayed Humanoid is handled without blocking other pages.
        table.insert(CharacterConnections, Character.ChildAdded:Connect(function(Child)
            if Context.Alive and Player.Character == Character and Child:IsA("Humanoid") and not Humanoid then
                BindHumanoid(Child)
            end
        end))
        local Existing = Character:FindFirstChildOfClass("Humanoid")
        if Existing then BindHumanoid(Existing) end
    end

    local function AddControl(Property, Name, Flag, Min, Max, Decimals, Suffix)
        local Toggle = Section:Toggle({
            Name = Name, Flag = Flag .. "Toggle", Default = false,
            Callback = function(State)
                local WasEnabled = Enabled[Property]
                Enabled[Property] = State
                if State then
                    if Humanoid and not WasEnabled then Baselines[Property] = Humanoid[Property] end
                    Apply(Property)
                elseif WasEnabled then
                    Restore(Property)
                end
            end,
        })
        Toggle:Settings(260):Slider({
            Name = Property == "WalkSpeed" and "Speed increase" or Name,
            Flag = Flag .. "Slider", Default = Values[Property],
            Min = Min, Max = Max, Decimals = Decimals, Suffix = Suffix,
            Callback = function(Value)
                Values[Property] = Value
                Apply(Property)
            end,
        })
    end

    AddControl("WalkSpeed", "Walk speed", "WalkSpeed", 0, 500, 1, " %")
    AddControl("JumpPower", "Jump power", "JumpPower", 0, 500, 1, "")
    AddControl("JumpHeight", "Jump height", "JumpHeight", 0, 200, 0.1, " studs")

    Context.Connect(Player.CharacterAdded, BindCharacter)
    Context.Connect(Player.CharacterRemoving, function()
        DisconnectCharacter()
        Humanoid = nil
        UpdateStatus()
    end)
    Context.AddCleanup(function()
        DisconnectCharacter()
        for Property, State in pairs(Enabled) do
            if State then Restore(Property) end
        end
        Humanoid = nil
    end)
    if Player.Character then BindCharacter(Player.Character) end
end
