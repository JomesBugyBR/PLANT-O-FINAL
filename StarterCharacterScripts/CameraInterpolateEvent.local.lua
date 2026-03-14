local player = game.Players.LocalPlayer
local cameraInterpolateEvent = game.ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("cameraInterpolateEvent")
local cameraToPlayerEvent = game.ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("cameraToPlayerEvent")

cameraInterpolateEvent.OnClientEvent:Connect(function(posEnd, focusEnd, duration)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera:Interpolate(posEnd, focusEnd, duration)
end)

cameraToPlayerEvent.OnClientEvent:Connect(function()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
end)
