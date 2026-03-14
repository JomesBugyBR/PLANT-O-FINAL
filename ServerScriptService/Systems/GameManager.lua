local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MonsterAI = require(script.Parent:WaitForChild("MonsterAI"))
local ObjectiveSystem = require(script.Parent:WaitForChild("ObjectiveSystem"))
local PowerSystem = require(script.Parent:WaitForChild("PowerSystem"))

local GameManager = {}
GameManager.__index = GameManager

-- Creates RemoteEvents if missing.
local function getRemoteEvents()
    local folder = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RemoteEvents"
        folder.Parent = ReplicatedStorage
    end

    local function ensure(name)
        local event = folder:FindFirstChild(name)
        if not event then
            event = Instance.new("RemoteEvent")
            event.Name = name
            event.Parent = folder
        end
        return event
    end

    return {
        ObjectiveUpdate = ensure("ObjectiveUpdate"),
        Jumpscare = ensure("Jumpscare"),
        PowerUpdate = ensure("PowerUpdate"),
        GameState = ensure("GameState"),
        cameraInterpolateEvent = ensure("cameraInterpolateEvent"),
        cameraToPlayerEvent = ensure("cameraToPlayerEvent"),
    }
end

function GameManager.new()
    local self = setmetatable({}, GameManager)

    self.RemoteEvents = getRemoteEvents()
    self.Objectives = ObjectiveSystem.new(self.RemoteEvents)
    self.Power = PowerSystem.new(self.RemoteEvents)
    self.Monster = MonsterAI.new(self.RemoteEvents)

    self.GameOver = false
    self.AlivePlayers = {}

    return self
end

function GameManager:Init()
    self.Objectives:Init()
    self.Objectives:BindPlayerJoin()
    self.Objectives:BindPrompts(workspace:FindFirstChild("Objectives"))

    self:BindObjectiveUpdates()
    self:BindPlayerLifecycle()
    self:BindNoisePrompts(workspace:FindFirstChild("Objectives"))
    self:SetupAmbientSounds()

    local monsterModel = workspace:WaitForChild("Monster")
    local waypoints = workspace:WaitForChild("Waypoints")
    self.Monster:Init(monsterModel, waypoints)

    self:DisableExitDoor()
end

function GameManager:BindObjectiveUpdates()
    self.Objectives.Updated.Event:Connect(function(id, obj)
        if id == "Generator" and obj.Complete then
            self.Power:SetGeneratorOn(true)
        end

        if self:PreExitObjectivesComplete() then
            self:UnlockExitDoor()
        end

        if self.Objectives:AllComplete() then
            self:CheckVictory()
        end
    end)
end

function GameManager:PreExitObjectivesComplete()
    local objectives = self.Objectives.Objectives
    local generator = objectives.Generator and objectives.Generator.Complete
    local panels = objectives.Panels and objectives.Panels.Complete
    local cameras = objectives.Cameras and objectives.Cameras.Complete

    return generator and panels and cameras
end

function GameManager:DisableExitDoor()
    local objectivesFolder = workspace:FindFirstChild("Objectives")
    if not objectivesFolder then
        return
    end

    local exitDoor = objectivesFolder:FindFirstChild("ExitDoor")
    if exitDoor and exitDoor:FindFirstChild("ProximityPrompt") then
        exitDoor.ProximityPrompt.Enabled = false
    end
end

function GameManager:UnlockExitDoor()
    local objectivesFolder = workspace:FindFirstChild("Objectives")
    if not objectivesFolder then
        return
    end

    local exitDoor = objectivesFolder:FindFirstChild("ExitDoor")
    if exitDoor and exitDoor:FindFirstChild("ProximityPrompt") then
        exitDoor.ProximityPrompt.Enabled = true
    end
end

function GameManager:BindNoisePrompts(objectivesFolder)
    if not objectivesFolder then
        return
    end

    for _, prompt in ipairs(objectivesFolder:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            local parentPart = prompt.Parent
            prompt.Triggered:Connect(function(player)
                if parentPart and parentPart:IsA("BasePart") then
                    self.Monster:ReportNoise(parentPart.Position)
                end
            end)
        end
    end
end

function GameManager:SetupAmbientSounds()
    local folder = workspace:FindFirstChild("SoundEmitters")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "SoundEmitters"
        folder.Parent = workspace
    end

    local function ensureEmitter(name)
        local part = folder:FindFirstChild(name)
        if not part then
            part = Instance.new("Part")
            part.Name = name
            part.Anchored = true
            part.CanCollide = false
            part.Transparency = 1
            part.Size = Vector3.new(1, 1, 1)
            part.Position = Vector3.new(0, 5, 0)
            part.Parent = folder
        end
        return part
    end

    local function ensureSound(parent, soundName, soundId, volume)
        local sound = parent:FindFirstChild(soundName)
        if not sound then
            sound = Instance.new("Sound")
            sound.Name = soundName
            sound.SoundId = soundId
            sound.Looped = true
            sound.Volume = volume
            sound.RollOffMaxDistance = 120
            sound.Parent = parent
            sound:Play()
        end
        return sound
    end

    local ambientEmitter = ensureEmitter("AmbientEmitter")
    local screamEmitter = ensureEmitter("ScreamEmitter")
    local buzzEmitter = ensureEmitter("BuzzEmitter")

    ensureSound(ambientEmitter, "AmbientHospital", "rbxassetid://0", 0.2) -- Replace ids.
    ensureSound(screamEmitter, "DistantScreams", "rbxassetid://0", 0.25)
    ensureSound(buzzEmitter, "ElectricalBuzz", "rbxassetid://0", 0.3)
end

function GameManager:BindPlayerLifecycle()
    local function trackCharacter(player, character)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            humanoid = character:WaitForChild("Humanoid")
        end

        self.AlivePlayers[player] = true

        humanoid.Died:Connect(function()
            self.AlivePlayers[player] = nil
            self:CheckDefeat()
        end)
    end

    Players.PlayerAdded:Connect(function(player)
        if player.Character then
            trackCharacter(player, player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            trackCharacter(player, character)
        end)
    end)

    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            trackCharacter(player, player.Character)
        end
        player.CharacterAdded:Connect(function(character)
            trackCharacter(player, character)
        end)
    end
end

function GameManager:CheckVictory()
    if self.GameOver then
        return
    end

    if self.Objectives:AllComplete() then
        self.GameOver = true
        self.RemoteEvents.GameState:FireAllClients("VICTORY")
    end
end

function GameManager:CheckDefeat()
    if self.GameOver then
        return
    end

    if next(self.AlivePlayers) == nil then
        self.GameOver = true
        self.RemoteEvents.GameState:FireAllClients("DEFEAT")
    end
end

return GameManager

