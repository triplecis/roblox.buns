return function(Context)
    local Players = game:GetService("Players")
    local Section = Context.Pages.PlayersList:Section({ Name = "Server players", Icon = "users", Side = 1 })
    local Count = Section:Label("Players: 0")
    local Selection = Section:Label("Selected: 0")
    local PlayerByLabel = {}
    local List
    Context.SelectedPlayers = {}

    local function Select(Labels)
        local Selected = {}
        for _, Label in ipairs(Labels) do
            if PlayerByLabel[Label] then table.insert(Selected, PlayerByLabel[Label]) end
        end
        Context.SelectedPlayers = Selected
        Selection:SetText("Selected: " .. tostring(#Selected))
    end

    local function Refresh(RemovingPlayer)
        local Labels = {}
        table.clear(PlayerByLabel)
        for _, Player in ipairs(Players:GetPlayers()) do
            -- PlayerRemoving fires before the player leaves GetPlayers().
            if Player ~= RemovingPlayer then
                local Label = Player.DisplayName .. " (@" .. Player.Name .. ")"
                PlayerByLabel[Label] = Player
                table.insert(Labels, Label)
            end
        end
        table.sort(Labels)
        local Selected = {}
        for _, Label in ipairs(List.Value) do
            if PlayerByLabel[Label] then table.insert(Selected, Label) end
        end
        List:Refresh(Labels)
        List:Set(Selected)
        Count:SetText("Players: " .. tostring(#Labels))
    end

    List = Section:Listbox({ Flag = "SelectedPlayers", Items = {}, Multi = true, Callback = Select })
    Context.Connect(Players.PlayerAdded, function() Refresh() end)
    Context.Connect(Players.PlayerRemoving, Refresh)
    Refresh()
end
