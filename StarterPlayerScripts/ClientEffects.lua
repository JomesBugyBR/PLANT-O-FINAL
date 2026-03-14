local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local objectiveEvent = remoteEvents:WaitForChild("ObjectiveUpdate")
local jumpscareEvent = remoteEvents:WaitForChild("Jumpscare")
local powerEvent = remoteEvents:WaitForChild("PowerUpdate")
local gameStateEvent = remoteEvents:WaitForChild("GameState")

-- Simple objective UI.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ObjectivesGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(0, 0)
container.Position = UDim2.new(0, 18, 0, 18)
container.Size = UDim2.new(0, 320, 0, 180)
container.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
container.BackgroundTransparency = 0.25
container.BorderSizePixel = 0
container.Parent = screenGui

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 22)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Plantao Final Objectives"
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = container

local list = Instance.new("Frame")
list.Size = UDim2.new(1, -16, 1, -34)
list.Position = UDim2.new(0, 8, 0, 30)
list.BackgroundTransparency = 1
list.Parent = container

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local rows = {}

local function clearRows()
    for _, row in pairs(rows) do
        row:Destroy()
    end
    rows = {}
end

local function renderObjectives(payload)
    clearRows()

    for id, obj in pairs(payload) do
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0, 20)
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = obj.Complete and Color3.fromRGB(140, 255, 140) or Color3.fromRGB(220, 220, 220)
        label.Text = string.format("%s (%d/%d)", obj.Title, obj.Progress, obj.Required)
        label.Parent = list
        rows[id] = label
    end
end

objectiveEvent.OnClientEvent:Connect(function(payload)
    renderObjectives(payload)
end)

-- Jumpscare camera effect.
jumpscareEvent.OnClientEvent:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end

    local originalFov = camera.FieldOfView
    local tween = TweenService:Create(camera, TweenInfo.new(0.1), {FieldOfView = originalFov - 15})
    tween:Play()

    task.delay(0.2, function()
        TweenService:Create(camera, TweenInfo.new(0.2), {FieldOfView = originalFov}):Play()
    end)
end)

-- Power feedback (screen flicker).
powerEvent.OnClientEvent:Connect(function(isOn)
    local overlay = Instance.new("Frame")
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    overlay.BackgroundTransparency = 0.85
    overlay.BorderSizePixel = 0
    overlay.Parent = screenGui

    TweenService:Create(overlay, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
    task.delay(0.4, function()
        overlay:Destroy()
    end)
end)

-- Victory / defeat banner.
gameStateEvent.OnClientEvent:Connect(function(state)
    local banner = Instance.new("TextLabel")
    banner.Size = UDim2.new(1, 0, 0, 60)
    banner.Position = UDim2.new(0, 0, 0.4, 0)
    banner.BackgroundTransparency = 0.2
    banner.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    banner.BorderSizePixel = 0
    banner.TextColor3 = Color3.fromRGB(255, 255, 255)
    banner.Font = Enum.Font.GothamBlack
    banner.TextSize = 28
    banner.Text = state == "VICTORY" and "ESCAPED" or "YOU DIED"
    banner.Parent = screenGui

    task.delay(3, function()
        banner:Destroy()
    end)
end)
