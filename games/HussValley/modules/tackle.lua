return function(Context)
    local Section = Context.Sections.Chasers
    local Hitboxes = Context.Sections.Hitboxes
    local State = { BoxEnabled = false, Scale = { X = 1, Y = 1, Z = 1 } }
    Context.State.Tackle = State
    local Bindings, Prediction, BoundsHook
    local BoxToggle
    local RestoreBounds
    local Status = Section:Label("Tackle: waiting for character")
    local Variant = Section:Label("Tackle profile: not loaded")
    local Motion = Section:Label("")
    local BoundsLabel = Hitboxes:Label("Tackle prediction bounds: not loaded")
    Hitboxes:Label("Prediction size affects the local catch box; the server validates catches separately.")
    local RefreshDetails = Context.CreateList(Section, "HussValleyTackleDetails", function() end)

    local function Number(Value: any): number?
        if type(Value) == "number" and Value == Value and math.abs(Value) ~= math.huge then return Value end
        return nil
    end

    local function Display(Value)
        local Numeric = Number(Value)
        return Numeric and string.format("%.2f", Numeric) or "unavailable"
    end

    local function ServerNow()
        local Success, Time = pcall(function() return workspace:GetServerTimeNow() end)
        return Success and Number(Time) or nil
    end

    local function Vector(Value)
        local function ValueType(Object): string return typeof(Object) end
        return ValueType(Value) == "Vector3" and Number(Value.X) and Number(Value.Y) and Number(Value.Z)
            and Value.X > 0 and Value.Y > 0 and Value.Z > 0
    end

    local function ScaleBounds(Value)
        return Vector3.new(Value.X * State.Scale.X, Value.Y * State.Scale.Y, Value.Z * State.Scale.Z)
    end

    local function RefreshProfile()
        if not Bindings then return end
        State.Profile, State.Bounds, State.MotionDistance, State.Details, State.BoundsType = nil, nil, nil, nil, nil
        local Character = Context.Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Speed = 0
        if Root and Root:IsA("BasePart") then
            local Velocity = Root.AssemblyLinearVelocity
            Speed = math.sqrt(Velocity.X * Velocity.X + Velocity.Z * Velocity.Z)
        end
        local Movement, Error = Context.GetMovementProfile("Catcher")
        if not Context.Alive then return end
        if not Movement then State.Error = Error; return end
        if Movement.MaxSpeed <= 0 then State.Error = "Invalid Catcher max speed."; return end
        State.EntrySpeed, State.MaxSpeed = Speed, Movement.MaxSpeed
        local Selected, Profile = pcall(Bindings.TackleProfile.select, Bindings.GameConfig.Tackle, Speed, Movement.MaxSpeed)
        if not Context.Alive then return end
        if not Selected or type(Profile) ~= "table" then State.Error = "TackleProfile.select failed: " .. tostring(Profile); return end
        if not Number(Profile.Duration) or Profile.Duration <= 0 or not Number(Profile.Distance) or Profile.Distance < 0
            or not Number(Profile.Recovery) or Profile.Recovery < 0 then
            State.Error = "Invalid tackle motion profile."; return
        end
        State.Profile, State.Error = Profile, nil
        local BoundsFunction = BoundsHook and BoundsHook.Original or Bindings.HitReplayMath.bounds
        local Read, Bounds = pcall(BoundsFunction, "Tackle", Profile)
        if not Context.Alive then return end
        State.BoundsType = Read and typeof(Bounds) or "error"
        State.BoundsError = not Read and tostring(Bounds) or nil
        if Read and Vector(Bounds) then State.Bounds = Bounds end
        local Sampled, Distance = pcall(Bindings.TackleMotion.distance, Profile, Profile.Duration)
        if not Context.Alive then return end
        State.MotionDistance = Sampled and Number(Distance) or nil
        State.Details = Context.DescribeSettings(Bindings.GameConfig.Tackle, "Tackle")
        for _, Rows in ipairs({ Context.DescribeSettings(Profile, "Profile"),
            Context.DescribeSettings(Bindings.TacklePredictionConfig, "Prediction") }) do
            for _, Row in ipairs(Rows) do table.insert(State.Details, Row) end
        end
        table.sort(State.Details)
    end

    local function Update()
        if not Context.Alive then return end
        local Character = Context.Player.Character
        local Attributes = Character and Character:GetAttributes() or {}
        local ReadyAt = Number(Context.Player:GetAttributes().TackleReadyAt)
        local Now = ServerNow()
        State.Remaining = ReadyAt and Now and math.max(0, ReadyAt - Now) or nil
        State.Active = Attributes.TackleActive == true
        if Prediction then
            local Checked, Remaining = pcall(Prediction.remaining)
            if not Context.Alive then return end
            if Checked and Number(Remaining) then State.Remaining = math.max(State.Remaining or 0, Remaining) end
        end
        Status:SetText("Tackle: " .. (State.Active and "active" or "idle")
            .. " | Cooldown: " .. Display(State.Remaining) .. "s"
            .. " | Variant: " .. tostring(Attributes.TackleVariant or "unavailable"))
        local Profile = State.Profile
        Variant:SetText(Profile and ("Selected tackle: " .. tostring(Profile.Name or "unnamed")
            .. " | Distance: " .. Display(Profile.Distance) .. " studs"
            .. " | Duration: " .. Display(Profile.Duration) .. "s | Recovery: " .. Display(Profile.Recovery) .. "s")
            or (State.Error and "Tackle profile: " .. State.Error or "Tackle profile: not loaded"))
        Motion:SetText(Profile and ("Entry speed: " .. Display(State.EntrySpeed) .. " / " .. Display(State.MaxSpeed)
            .. " | Motion distance: " .. Display(State.MotionDistance) .. " studs") or "")
        if State.Bounds then
            local Value = State.BoxEnabled and ScaleBounds(State.Bounds) or State.Bounds
            BoundsLabel:SetText("Tackle prediction size: " .. Display(Value.X) .. " x " .. Display(Value.Y) .. " x " .. Display(Value.Z)
                .. " studs" .. (State.BoxEnabled and " (edited locally)" or ""))
        else
            BoundsLabel:SetText(State.BoundsType and ("Tackle bounds type: " .. State.BoundsType .. "; need HitReplayMath schema")
                or "Tackle prediction bounds: not loaded")
        end
        RefreshDetails(State.Details or {})
    end

    local function ClearBindings(Error)
        Bindings, State.Profile, State.Bounds, State.Details, State.BoundsType = nil, nil, nil, nil, nil
        State.Error = Error
        if BoundsHook then
            State.BoxEnabled = false
            RestoreBounds()
            if BoxToggle then BoxToggle:Set(false, true) end
        end
    end

    function Context.ReadTackleBindings(Quiet)
        if not Context.Alive then return false end
        local Loaded = {}
        for _, Name in ipairs({ "GameConfig", "TackleProfile", "TackleMotion", "TacklePredictionConfig", "HitReplayMath" }) do
            local Module, Error = Context.ReadGameModule(Name, Quiet ~= true)
            if not Context.Alive then return false end
            if not Module then
                ClearBindings(Error)
                if not Quiet then Context.Notify("Tackle bindings unavailable", Error, 3) end
                Update()
                return false
            end
            Loaded[Name] = Module
        end
        if type(Loaded.GameConfig.Tackle) ~= "table" or type(Loaded.TackleProfile.select) ~= "function"
            or type(Loaded.TackleMotion.distance) ~= "function" or type(Loaded.HitReplayMath.bounds) ~= "function" then
            ClearBindings("Tackle bindings do not expose the expected config/functions.")
            if not Quiet then Context.Notify("Tackle bindings unavailable", State.Error, 3) end
            Update()
            return false
        end
        if BoundsHook and BoundsHook.Module ~= Loaded.HitReplayMath then
            State.BoxEnabled = false
            RestoreBounds()
            if BoxToggle then BoxToggle:Set(false, true) end
        end
        Bindings = Loaded
        RefreshProfile()
        Update()
        return Context.Alive and State.Profile ~= nil
    end

    local function BlockReason(Character)
        if Context.Player.Character ~= Character then return "Character changed." end
        local PlayerAttributes = Context.Player:GetAttributes()
        if PlayerAttributes.GameRole ~= "Catcher" then return "Only Catchers can tackle." end
        if PlayerAttributes.RunState ~= "Active" then return "The run is not active." end
        local Human = Character and Character:FindFirstChildOfClass("Humanoid")
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        if not Human or Human.Health <= 0 or not Root or not Root:IsA("BasePart") then return "No active character." end
        if Root.Anchored or Human.Sit or Human.PlatformStand or Human.FloorMaterial == Enum.Material.Air then
            return "Tackle requires grounded, movable character."
        end
        local Attributes = Character:GetAttributes()
        if Attributes.MovementLocked or Attributes.TackleActive then return "Movement is locked or tackle is active." end
        if Attributes.DaggerEquipped and Attributes.DaggerState ~= "Held" then return "Dagger is not ready." end
        if Context.State.Spectating then return "Stop spectating before tackling." end
        local ReadyAt = Number(PlayerAttributes.TackleReadyAt)
        local Now = ServerNow()
        if ReadyAt and not Now then return "Server clock is unavailable." end
        if ReadyAt and ReadyAt - Now > 0.02 then return "Tackle is cooling down." end
        return nil
    end

    function Context.RequestTackle()
        if not Context.Alive then return false end
        local Character = Context.Player.Character
        local Reason = BlockReason(Character)
        if Reason then Context.Notify("Tackle unavailable", Reason, 3); return false end
        local Module, Error = Context.ReadGameModule("TacklePrediction")
        if not Context.Alive then return false end
        if not Module or type(Module.request) ~= "function" or type(Module.remaining) ~= "function" then
            Context.Notify("Tackle unavailable", Error or "TacklePrediction functions are unavailable.", 3)
            return false
        end
        Prediction = Module
        local Checked, Remaining = pcall(Module.remaining)
        if not Context.Alive then return false end
        if not Checked or not Number(Remaining) or Remaining > 0.02 then
            Context.Notify("Tackle unavailable", Checked and "Tackle is cooling down or its timer is invalid." or tostring(Remaining), 3)
            return false
        end
        local Gates = Context.CheckControlGates()
        if not Context.Alive then return false end
        Reason = BlockReason(Character) or Gates.Error or Gates.MovementReason or Gates.InputReason
        if Reason then Context.Notify("Tackle unavailable", Reason, 3); return false end
        -- The live module owns prediction, request payload, collision limits, and reconciliation.
        local Requested, Result = pcall(Module.request)
        if not Context.Alive then return false end
        if not Requested or Result ~= true then
            Context.Notify("Tackle request failed", Requested and "The game rejected this tackle input." or tostring(Result), 3)
        end
        Update()
        return Requested and Result == true
    end

    RestoreBounds = function()
        local Entry = BoundsHook
        BoundsHook = nil
        if not Entry then return end
        Entry.Active = false
        local Success, Error
        if Entry.Hook then
            Success, Error = pcall(Entry.Hook, Entry.Target, Entry.Original)
        elseif Entry.Module.bounds == Entry.Wrapper then
            Success, Error = pcall(function() Entry.Module.bounds = Entry.Original end)
        else Success = true end
        if not Success then Context.Notify("Tackle bounds restoration failed", Error, 3) end
    end

    local function InstallBounds()
        if not Context.ReadTackleBindings() then return false, State.Error or "Tackle profile is unavailable." end
        if not State.Bounds then return false, "HitReplayMath.bounds did not return a positive Vector3; its source is needed." end
        local Module = Bindings.HitReplayMath
        local Hook = type(hookfunction) == "function" and hookfunction or nil
        if table.isfrozen(Module) and not Hook then return false, "Frozen HitReplayMath requires hookfunction." end
        local Entry = { Module = Module, Target = Module.bounds, Original = Module.bounds, Active = true }
        Entry.Wrapper = function(Kind, Profile, ...)
            local Bounds = Entry.Original(Kind, Profile, ...)
            if Entry.Active and Context.Alive and State.BoxEnabled and Kind == "Tackle" and Vector(Bounds) then
                return ScaleBounds(Bounds)
            end
            return Bounds
        end
        if table.isfrozen(Module) then
            local Success, Original = pcall(Hook, Entry.Target, Entry.Wrapper)
            if not Success or type(Original) ~= "function" then
                Entry.Active = false
                return false, "Could not hook tackle bounds: " .. tostring(Original)
            end
            Entry.Hook, Entry.Original = Hook, Original
        else Module.bounds = Entry.Wrapper end
        BoundsHook = Entry
        return true
    end

    Section:Button({ Name = "Read tackle bindings", Callback = Context.ReadTackleBindings })
    Section:Button({ Name = "Request tackle", Callback = Context.RequestTackle })
    BoxToggle = Hitboxes:Toggle({
        Name = "Edit tackle prediction box", Flag = "HussValleyTackleBoxEnabled", Default = false,
        Callback = function(Enabled)
            if Enabled == State.BoxEnabled then return end
            if Enabled then
                local Success, Error = InstallBounds()
                if not Context.Alive then RestoreBounds(); return end
                if not Success then
                    Context.Notify("Tackle box unavailable", Error, 4)
                    if BoxToggle then BoxToggle:Set(false, true) end
                    return
                end
            else
                State.BoxEnabled = false
                RestoreBounds()
            end
            State.BoxEnabled = Enabled
            Update()
        end,
    })
    for _, Axis in ipairs({ "X", "Y", "Z" }) do
        Hitboxes:Slider({
            Name = "Tackle prediction scale " .. Axis, Flag = "HussValleyTackleBox" .. Axis,
            Default = 1, Min = 0.5, Max = 3, Decimals = 0.1, Suffix = "x",
            Callback = function(Value)
                if not Number(Value) then return end
                State.Scale[Axis] = math.clamp(Value, 0.5, 3)
                Update()
            end,
        })
    end
    Context.Subscribe(Update)
    Context.WatchData("Tackle bindings", function() Context.ReadTackleBindings(true) end, 0.25)
    Context.AddCleanup(function() State.BoxEnabled = false; RestoreBounds() end)
end
