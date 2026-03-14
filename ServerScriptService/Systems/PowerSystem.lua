local PowerSystem = {}
PowerSystem.__index = PowerSystem

-- Controls power state and lighting.
function PowerSystem.new(remoteEvents)
    local self = setmetatable({}, PowerSystem)
    self.RemoteEvents = remoteEvents
    self.GeneratorOn = false
    return self
end

local function setLights(folder, enabled)
    if not folder then
        return
    end

    for _, light in ipairs(folder:GetDescendants()) do
        if light:IsA("Light") then
            light.Enabled = enabled
        end
    end
end

function PowerSystem:SetGeneratorOn(state)
    if self.GeneratorOn == state then
        return
    end

    self.GeneratorOn = state

    local lightsFolder = workspace:FindFirstChild("Lights")
    if lightsFolder then
        setLights(lightsFolder:FindFirstChild("EmergencyLights"), not state)
        setLights(lightsFolder:FindFirstChild("MainLights"), state)
    end

    self.RemoteEvents.PowerUpdate:FireAllClients(state)
end

return PowerSystem
