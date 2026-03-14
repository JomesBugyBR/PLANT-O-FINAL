local Players = game:GetService('Players')

local function onPlayerAdded(player)
    -- Create SafeZone detection value
detectedValue = Instance.new('BoolValue')
    detectedValue.Name = 'SafeZoneDetected'
    detectedValue.Value = false
    detectedValue.Parent = player

    -- Create ResumeMusic value
dimmedMusic = Instance.new('BoolValue')
    dimmedMusic.Name = 'ResumeMusic'
    dimmedMusic.Value = false
    dimmedMusic.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)