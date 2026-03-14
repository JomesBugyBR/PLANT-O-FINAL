local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local cameraInterpolateEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("cameraInterpolateEvent")
local cameraToPlayerEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("cameraToPlayerEvent")

local entity = script.Parent
local hitbox = entity:WaitForChild("Hitbox")

local playerCooldowns = {}

local function getCharacterFromHit(hit)
	return hit:FindFirstAncestorOfClass("Model")
end

local function playJumpscare(player, humanoid)
	if playerCooldowns[player.UserId] then
		return
	end

	playerCooldowns[player.UserId] = true

	task.spawn(function()
		if entity:FindFirstChild("Head") and entity.Head:FindFirstChild("Scream") then
			entity.Head.Scream:Play()
		end

		local cameraPosition = entity:FindFirstChild("CameraPosition")
		local cameraAim = entity:FindFirstChild("CameraAim")

		if cameraPosition and cameraAim then
			cameraInterpolateEvent:FireClient(player, cameraPosition.CFrame, cameraAim.CFrame, 0.2)
			task.wait(0.2)

			local duracao = 1
			local frequencia = 0.01
			local tempoPassado = 0

			while tempoPassado < duracao do
				cameraInterpolateEvent:FireClient(player, cameraPosition.CFrame, cameraAim.CFrame, 0.005)
				task.wait(frequencia)
				tempoPassado += frequencia
			end
		end

		if humanoid and humanoid.Health > 0 then
			humanoid.Health = 0
		end

		cameraToPlayerEvent:FireClient(player)

		task.delay(1.5, function()
			playerCooldowns[player.UserId] = nil
		end)
	end)
end

hitbox.Touched:Connect(function(hit)
	if hit:IsDescendantOf(entity) then
		return
	end

	local character = getCharacterFromHit(hit)
	if not character then
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		playJumpscare(player, humanoid)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)
