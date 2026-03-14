local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local ObjectivesConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ObjectivesConfig"))

local ObjectiveSystem = {}
ObjectiveSystem.__index = ObjectiveSystem

-- Keeps objective progress and updates clients.
function ObjectiveSystem.new(remoteEvents)
    local self = setmetatable({}, ObjectiveSystem)

    self.RemoteEvents = remoteEvents
    self.Objectives = {}
    self.Completed = false
    self.Updated = Instance.new("BindableEvent")

    for _, data in ipairs(ObjectivesConfig) do
        self.Objectives[data.Id] = {
            Title = data.Title,
            Required = data.Required,
            Progress = 0,
            Complete = false,
        }
    end

    return self
end

function ObjectiveSystem:Init()
    self:SendFullUpdate()
end

function ObjectiveSystem:SendFullUpdate(player)
    local payload = {}
    for id, obj in pairs(self.Objectives) do
        payload[id] = {
            Title = obj.Title,
            Required = obj.Required,
            Progress = obj.Progress,
            Complete = obj.Complete,
        }
    end

    if player then
        self.RemoteEvents.ObjectiveUpdate:FireClient(player, payload)
    else
        self.RemoteEvents.ObjectiveUpdate:FireAllClients(payload)
    end
end

function ObjectiveSystem:Increment(id, amount)
    local obj = self.Objectives[id]
    if not obj or obj.Complete then
        return
    end

    obj.Progress = math.clamp(obj.Progress + (amount or 1), 0, obj.Required)
    if obj.Progress >= obj.Required then
        obj.Complete = true
    end

    self:SendFullUpdate()
    self.Updated:Fire(id, obj)
end

function ObjectiveSystem:AllComplete()
    for _, obj in pairs(self.Objectives) do
        if not obj.Complete then
            return false
        end
    end
    return true
end

-- Connect ProximityPrompts under Workspace.Objectives to objective progress.
function ObjectiveSystem:BindPrompts(workspaceObjectives)
    if not workspaceObjectives then
        return
    end

    local generator = workspaceObjectives:FindFirstChild("Generator")
    if generator and generator:FindFirstChild("ProximityPrompt") then
        generator.ProximityPrompt.Triggered:Connect(function(player)
            self:Increment("Generator", 1)
        end)
    end

    local panelsFolder = workspaceObjectives:FindFirstChild("Panels")
    if panelsFolder then
        for _, panel in ipairs(panelsFolder:GetChildren()) do
            local prompt = panel:FindFirstChild("ProximityPrompt")
            if prompt then
                prompt.Triggered:Connect(function(player)
                    self:Increment("Panels", 1)
                end)
            end
        end
    end

    local cameras = workspaceObjectives:FindFirstChild("Cameras")
    if cameras and cameras:FindFirstChild("ProximityPrompt") then
        cameras.ProximityPrompt.Triggered:Connect(function(player)
            self:Increment("Cameras", 1)
        end)
    end

    local exitDoor = workspaceObjectives:FindFirstChild("ExitDoor")
    if exitDoor and exitDoor:FindFirstChild("ProximityPrompt") then
        exitDoor.ProximityPrompt.Triggered:Connect(function(player)
            self:Increment("Exit", 1)
        end)
    end
end

-- Keep new players in sync.
function ObjectiveSystem:BindPlayerJoin()
    Players.PlayerAdded:Connect(function(player)
        self:SendFullUpdate(player)
    end)
end

return ObjectiveSystem
