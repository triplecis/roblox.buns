-- Keep a live list of players in this server.
return function(context)
    local players = game:GetService("Players")
    local runService = game:GetService("RunService")
    local section = context.Pages.PlayersList:Section({
        Name = "Server players",
        Icon = "users",
        Side = 1,
    })

    local countLabel = section:Label("Players: 0")
    local selectionLabel = section:Label("Selected: 0")

    local playerByLabel = {}
    local playerList
    local previousLabels
    local elapsedSeconds = 0

    context.SelectedPlayers = {}

    local function saveSelection(labels)
        local selectedPlayers = {}

        for _, label in ipairs(labels) do
            local player = playerByLabel[label]
            if player then
                table.insert(selectedPlayers, player)
            end
        end

        context.SelectedPlayers = selectedPlayers
        selectionLabel:SetText("Selected: " .. tostring(#selectedPlayers))
    end

    -- PlayerRemoving fires before GetPlayers stops returning the departing player.
    local function refreshList(removingPlayer)
        local labels = {}
        local selectedLabels = {}
        local selectedPlayers = {}

        for _, player in ipairs(context.SelectedPlayers) do
            selectedPlayers[player] = true
        end

        table.clear(playerByLabel)

        for _, player in ipairs(players:GetPlayers()) do
            if player ~= removingPlayer then
                local label = player.DisplayName .. " (@" .. player.Name .. ")"
                playerByLabel[label] = player
                table.insert(labels, label)

                if selectedPlayers[player] then
                    table.insert(selectedLabels, label)
                end
            end
        end

        table.sort(labels)

        local listChanged = not previousLabels
            or table.concat(labels, "\n") ~= table.concat(previousLabels, "\n")
        if not listChanged then
            return
        end

        table.sort(selectedLabels)
        previousLabels = table.clone(labels)

        playerList:Refresh(labels)
        playerList:Set(selectedLabels)
        countLabel:SetText("Players: " .. tostring(#labels))
    end

    playerList = section:Listbox({
        Flag = "SelectedPlayers",
        Items = {},
        Multi = true,
        Callback = saveSelection,
    })

    context.Connect(players.PlayerAdded, function()
        refreshList()
    end)

    context.Connect(players.PlayerRemoving, refreshList)

    context.Connect(runService.Heartbeat, function(deltaTime)
        elapsedSeconds = elapsedSeconds + deltaTime
        if elapsedSeconds < 1 then
            return
        end

        elapsedSeconds = elapsedSeconds % 1
        refreshList()
    end)

    refreshList()
end
