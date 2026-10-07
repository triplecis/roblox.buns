return function(Context)
    local Section = Context.Sections.Movement
    local Input = game:GetService("UserInputService")
    local Storage = game:GetService("ReplicatedStorage")
    local Status = Section:Label("Sprint: disabled")
    Section:Label("Hold Shift to sprint, or enable Always sprint.")
    Section:Label("Sprint follows the native profile. Server corrections can still occur.")
    local State = { Enabled = false, Active = false, Increase = 15, Always = false }
    Context.State.Sprint = State
    local Keys = {}
    local HookState
    local Cache = setmetatable({}, { __mode = "k" })
    local Toggle

    local function SprintActive()
        if not Context.Alive or not State.Enabled then return false end
        if Input:GetFocusedTextBox() then return false end
        local Character = Context.Player.Character
        local Human = Character and Character:FindFirstChildOfClass("Humanoid")
        if not Human or Human.Health <= 0 then return false end
        local Role = Context.Player:GetAttributes().GameRole
        if Role ~= "Runner" and Role ~= "Catcher" then return false end
        local Attributes = Character:GetAttributes()
        if Attributes.MovementLocked or Attributes.TackleActive or Attributes.GearMotion then return false end
        return State.Always or Keys[Enum.KeyCode.LeftShift] or Keys[Enum.KeyCode.RightShift] or false
    end

    local function RestoreHook()
        local Previous = HookState
        HookState = nil
        if not Previous then return end
        -- Even if restoration fails, the wrapper becomes a pass-through.
        Previous.Active = false
        local Success, Error
        if Previous.Hook then
            Success, Error = pcall(Previous.Hook, Previous.Target, Previous.Original)
        elseif Previous.Profiles.get == Previous.Wrapper then
            Success, Error = pcall(function() Previous.Profiles.get = Previous.Original end)
        else
            Success = true
        end
        if not Success then Context.Notify("Sprint restoration failed", Error, 3) end
        table.clear(Cache)
    end

    local function InstallHook()
        local Root = Storage:FindFirstChild("ChickenOrHero")
        local Movement = Root and Root:FindFirstChild("Movement")
        local Module = Movement and Movement:FindFirstChild("MovementProfiles")
        if not Module or not Module:IsA("ModuleScript") then return false, "MovementProfiles is unavailable." end
        local Loaded, Profiles = pcall(require, Module)
        if not Context.Alive then return false, "Session unloaded." end
        if not Loaded or type(Profiles) ~= "table" or type(Profiles.get) ~= "function" then
            return false, "Could not load MovementProfiles: " .. tostring(Profiles)
        end
        local Hook = type(hookfunction) == "function" and hookfunction or nil
        if table.isfrozen(Profiles) and not Hook then
            return false, "This client needs hookfunction to edit the frozen movement profile."
        end
        local Entry = { Active = true, Profiles = Profiles, Target = Profiles.get, Original = Profiles.get }
        Entry.Wrapper = function(Role, Player, ...)
            local Profile = Entry.Original(Role, Player, ...)
            if not Entry.Active or not Context.Alive or Player ~= Context.Player or type(Profile) ~= "table" then
                return Profile
            end
            if type(Profile.MaxSpeed) ~= "number" or Profile.MaxSpeed <= 0 then return Profile end
            -- Stable identity matters: the native controller resets dash state when its profile changes.
            local Tuned = Cache[Profile]
            if not Tuned then Tuned = table.clone(Profile); Cache[Profile] = Tuned end
            -- Only our copy changes. Starting/releasing Shift keeps the same profile identity.
            local Scale = SprintActive() and (1 + State.Increase / 100) or 1
            for _, Name in ipairs({ "MaxSpeed", "Acceleration", "Deceleration" }) do
                if type(Profile[Name]) == "number" then Tuned[Name] = Profile[Name] * Scale end
            end
            return Tuned
        end
        if table.isfrozen(Profiles) then
            local Installed, Original = pcall(Hook, Entry.Target, Entry.Wrapper)
            if not Installed or type(Original) ~= "function" then
                Entry.Active = false
                return false, "Could not install sprint profile hook: " .. tostring(Original)
            end
            Entry.Hook, Entry.Original = Hook, Original
        else
            Profiles.get = Entry.Wrapper
        end
        HookState = Entry
        return true
    end

    local function UpdateStatus()
        State.Active = SprintActive()
        Status:SetText(not State.Enabled and "Sprint: disabled" or
            (State.Active and ("Sprint: active | +" .. tostring(State.Increase) .. "%") or "Sprint: ready (hold Shift)"))
    end

    Toggle = Section:Toggle({
        Name = "Native sprint speed",
        Flag = "HussValleySprintEnabled", Default = false,
        Callback = function(Enabled)
            if Enabled == State.Enabled then return end
            if Enabled then
                local Installed, Error = InstallHook()
                if not Context.Alive then RestoreHook(); return end
                if not Installed then
                    Context.Notify("Sprint unavailable", Error, 4)
                    if Toggle then Toggle:Set(false, true) end
                    return
                end
            else
                State.Enabled = false
                RestoreHook()
            end
            State.Enabled = Enabled
            if Context.SetWalkSpeedSuspended then Context.SetWalkSpeedSuspended(Enabled) end
            UpdateStatus()
        end,
    })
    Toggle:Settings(260):Slider({
        Name = "Sprint speed increase", Flag = "HussValleySprintIncrease",
        Default = State.Increase, Min = 0, Max = 100, Decimals = 1, Suffix = " %",
        Callback = function(Value)
            if type(Value) ~= "number" or Value ~= Value then return end
            State.Increase = math.clamp(Value, 0, 100)
            UpdateStatus()
        end,
    })
    Section:Toggle({
        Name = "Always sprint", Flag = "HussValleySprintAlways", Default = false,
        Callback = function(Enabled) State.Always = Enabled; UpdateStatus() end,
    })
    Context.Connect(Input.InputBegan, function(Key, Processed)
        if not Processed and not Input:GetFocusedTextBox()
            and (Key.KeyCode == Enum.KeyCode.LeftShift or Key.KeyCode == Enum.KeyCode.RightShift) then
            Keys[Key.KeyCode] = true
            UpdateStatus()
        end
    end)
    Context.Connect(Input.InputEnded, function(Key)
        Keys[Key.KeyCode] = nil
        UpdateStatus()
    end)
    Context.Connect(Input.WindowFocusReleased, function() table.clear(Keys); UpdateStatus() end)
    Context.Subscribe(UpdateStatus)
    Context.AddCleanup(function()
        State.Enabled, State.Active = false, false
        RestoreHook()
        if Context.SetWalkSpeedSuspended then Context.SetWalkSpeedSuspended(false) end
    end)
end
