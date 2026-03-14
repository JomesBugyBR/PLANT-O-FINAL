local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local MonsterAI = {}
MonsterAI.__index = MonsterAI

local STATE_PATROL = "PATROL"
local STATE_INVESTIGATE = "INVESTIGATE"
local STATE_CHASE = "CHASE"

function MonsterAI.new(remoteEvents)
	local self = setmetatable({}, MonsterAI)

	self.RemoteEvents = remoteEvents
	self.State = STATE_PATROL
	self.Monster = nil
	self.Humanoid = nil
	self.Root = nil
	self.Hitbox = nil
	self.Waypoints = {}
	self.CurrentWaypointIndex = 1
	self.LastNoisePos = nil
	self.TargetPlayer = nil

	self.PatrolSpeed = 16
	self.ChaseSpeed = 32
	self.SightDistance = 70

	self.PlayerCooldowns = {}

	-- CORRIGIDO: Sistema de pathfinding melhorado
	self.CurrentPathWaypoints = nil
	self.CurrentPathNode = 1
	self.LastPathDestination = nil
	self.IgnoreUntil = {}
	self.IgnoreDuration = 8
	self.SafeZonesFolder = nil
	self.PathRecalcInterval = 0.6  -- Recalcula caminho a cada 0.3s (mais frequente)
	self.LastPathCompute = -999  -- Força cálculo na primeira vez
	self.ConsecutivePathFails = 0
	self.LastPathFailTime = 0
	self.MaxConsecutiveFails = 2
	self.PathFailCooldown = 3

	self.StuckTimer = 0
	self.StuckThreshold = 2
	self.LastValidPosition = nil
	self.LastPositionCheckTime = 0
	self.PositionCheckInterval = 0.5

	return self
end

function MonsterAI:Init(monsterModel, waypointsFolder)
	self.Monster = monsterModel
	self.Humanoid = monsterModel:WaitForChild("Humanoid")
	self.Root = monsterModel:WaitForChild("HumanoidRootPart")

	for _, part in ipairs(self.Monster:GetDescendants()) do
		if part:IsA("BasePart") and part:CanSetNetworkOwnership() then
			part:SetNetworkOwner(nil)
		end
	end

	if waypointsFolder then
		for _, wp in ipairs(waypointsFolder:GetChildren()) do
			if wp:IsA("BasePart") then
				table.insert(self.Waypoints, wp)
			end
		end
	end

	self.SafeZonesFolder = workspace:FindFirstChild("SafeZones") or workspace:FindFirstChild("SafeAreas")

	self:CreateHitbox()
	self:SetupCollisions()
	self:SetupFootsteps()
	if not self.Monster:FindFirstChild("JumpscareScript") then
		self:BindAttack()
	end
	self:StartLoop()

	Players.PlayerRemoving:Connect(function(player)
		self.PlayerCooldowns[player.UserId] = nil
		self.IgnoreUntil[player.UserId] = nil
	end)
end

function MonsterAI:CreateHitbox()
	local hitbox = self.Monster:FindFirstChild("Hitbox")
	if not hitbox then
		hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.CanQuery = false
		hitbox.CanTouch = true
		hitbox.Massless = true

		local bboxCFrame, bboxSize = self.Monster:GetBoundingBox()
		hitbox.Size = Vector3.new(
			math.max(4, bboxSize.X * 0.85),
			math.max(8, bboxSize.Y * 0.95),
			math.max(4, bboxSize.Z * 0.85)
		)
		hitbox.CFrame = bboxCFrame
		hitbox.Parent = self.Monster

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hitbox
		weld.Part1 = self.Root
		weld.Parent = hitbox
	end

	self.Hitbox = hitbox
end

function MonsterAI:SetupFootsteps()
	local sound = self.Root:FindFirstChild("Footsteps")
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Footsteps"
		sound.SoundId = "rbxassetid://140563218459039"
		sound.Looped = true
		sound.Volume = 0.4
		sound.RollOffMaxDistance = 70
		sound.Parent = self.Root
	end

	self.Humanoid.Running:Connect(function(speed)
		if speed > 1 then
			if not sound.IsPlaying then
				sound:Play()
			end
		else
			sound:Stop()
		end
	end)
end

function MonsterAI:BindAttack()
	local hitPart = self.Hitbox or self.Root

	hitPart.Touched:Connect(function(hit)
		if hit:IsDescendantOf(self.Monster) then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		if self.PlayerCooldowns[player.UserId] then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			self.PlayerCooldowns[player.UserId] = true
			humanoid:TakeDamage(50)

			if self.RemoteEvents and self.RemoteEvents.Jumpscare then
				self.RemoteEvents.Jumpscare:FireClient(player)
			end

			task.delay(1.5, function()
				self.PlayerCooldowns[player.UserId] = nil
			end)
		end
	end)
end

function MonsterAI:FindVisiblePlayer()
	local nearest = nil
	local nearestDist = self.SightDistance

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { self.Monster }

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if root and humanoid and humanoid.Health > 0 then
				local now = os.clock()
				local skipTarget = false
				local ignoreUntil = self.IgnoreUntil[player.UserId]
				if ignoreUntil and ignoreUntil > now then
					skipTarget = true
				elseif self.SafeZonesFolder and self:IsInSafeZone(root.Position) then
					self.IgnoreUntil[player.UserId] = now + 1.5
					skipTarget = true
				end

				if not skipTarget then
					local direction = root.Position - self.Root.Position
					local dist = direction.Magnitude

					if dist > 0 and dist < nearestDist then
						local castDirection = direction.Unit * math.min(dist, self.SightDistance)
						local result = workspace:Raycast(self.Root.Position, castDirection, rayParams)
						if result and result.Instance and result.Instance:IsDescendantOf(character) then
							nearest = player
							nearestDist = dist
						end
					end
				end
			end
		end
	end

	return nearest
end

function MonsterAI:IsInSafeZone(position)
	if not self.SafeZonesFolder then
		return false
	end

	for _, zone in ipairs(self.SafeZonesFolder:GetDescendants()) do
		if zone:IsA("BasePart") then
			local localPos = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size * 0.5
			if math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z then
				return true
			end
		end
	end

	return false
end

function MonsterAI:SetupCollisions()
	local bodyParts = {
		"HumanoidRootPart",
		"UpperTorso",
		"LowerTorso",
		"Torso",
		"LeftFoot",
		"RightFoot",
		"Left Leg",
		"Right Leg"
	}

	local bodyPartSet = {}
	for _, name in ipairs(bodyParts) do
		bodyPartSet[name] = true
	end

	for _, part in ipairs(self.Monster:GetDescendants()) do
		if part:IsA("BasePart") then
			if bodyPartSet[part.Name] then
				part.CanCollide = true
			else
				part.CanCollide = false
			end
		end
	end
end

function MonsterAI:ResetPathfinding()
	self.CurrentPathWaypoints = nil
	self.CurrentPathNode = 1
	self.LastPathDestination = nil
	self.ConsecutivePathFails = 0
	self.StuckTimer = 0
	self.LastValidPosition = self.Root.Position
	self.LastPathCompute = -999  -- Força recálculo imediato
end

-- NOVO: Calcula caminho de forma assíncrona
function MonsterAI:ComputePath(startPos, endPos)
	local bboxSize = self.Monster:GetExtentsSize()
	local safeRadius = math.max(4, (math.max(bboxSize.X, bboxSize.Z) / 2) + 1.5)

	local path = PathfindingService:CreatePath({
		AgentRadius = safeRadius,
		AgentHeight = 18,
		AgentCanJump = false,
		WaypointSpacing = 6,
	})

	path:ComputeAsync(startPos, endPos)

	if path.Status == Enum.PathStatus.Success then
		return path:GetWaypoints()
	else
		return nil
	end
end

-- COMPLETAMENTE REFEITO: SmoothMove agora é inteligente
function MonsterAI:SmoothMove(targetPosition, isChasing)
	if isChasing then
		self.Humanoid:MoveTo(targetPosition)
		return
	end

	local now = os.clock()
	local destinationChanged = not self.LastPathDestination or (self.LastPathDestination - targetPosition).Magnitude > 3
	local needPath = (not self.CurrentPathWaypoints) or self.CurrentPathNode > #self.CurrentPathWaypoints

	if (destinationChanged or needPath) and (now - self.LastPathCompute >= self.PathRecalcInterval) then
		self.LastPathCompute = now
		self.LastPathDestination = targetPosition

		local waypoints = self:ComputePath(self.Root.Position, targetPosition)
		if waypoints then
			self.CurrentPathWaypoints = waypoints
			self.CurrentPathNode = 2
			self.ConsecutivePathFails = 0
		else
			self.ConsecutivePathFails += 1
			self.LastPathFailTime = now
		end
	end

	if self.CurrentPathWaypoints and self.CurrentPathNode <= #self.CurrentPathWaypoints then
		local waypoint = self.CurrentPathWaypoints[self.CurrentPathNode]
		self.Humanoid:MoveTo(waypoint.Position)

		if (self.Root.Position - waypoint.Position).Magnitude < 4 then
			self.CurrentPathNode += 1
		end
	elseif self.ConsecutivePathFails >= self.MaxConsecutiveFails then
		self.Humanoid:MoveTo(targetPosition)
	end
end

function MonsterAI:Patrol()
	if #self.Waypoints == 0 then
		return
	end

	self.Humanoid.WalkSpeed = self.PatrolSpeed
	local targetWaypoint = self.Waypoints[self.CurrentWaypointIndex]

	self:SmoothMove(targetWaypoint.Position, false)

	local flatRootPos = Vector3.new(self.Root.Position.X, 0, self.Root.Position.Z)
	local flatTargetPos = Vector3.new(targetWaypoint.Position.X, 0, targetWaypoint.Position.Z)
	local distanceToWaypoint = (flatRootPos - flatTargetPos).Magnitude

	if distanceToWaypoint < 5 then
		self.CurrentWaypointIndex += 1
		self:ResetPathfinding()
		if self.CurrentWaypointIndex > #self.Waypoints then
			self.CurrentWaypointIndex = 1
		end
	end
end

function MonsterAI:Investigate()
	if not self.LastNoisePos then
		self.State = STATE_PATROL
		self:ResetPathfinding()
		return
	end

	self.Humanoid.WalkSpeed = self.PatrolSpeed
	self:SmoothMove(self.LastNoisePos, false)

	local flatRootPos = Vector3.new(self.Root.Position.X, 0, self.Root.Position.Z)
	local flatNoisePos = Vector3.new(self.LastNoisePos.X, 0, self.LastNoisePos.Z)

	if (flatRootPos - flatNoisePos).Magnitude < 4 then
		self.LastNoisePos = nil
		self.State = STATE_PATROL
		self:ResetPathfinding()
	end
end

function MonsterAI:Chase(player)
	self.TargetPlayer = player
	local character = player.Character

	if not character then
		self.State = STATE_PATROL
		self:ResetPathfinding()
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not root or not humanoid or humanoid.Health <= 0 then
		self.State = STATE_PATROL
		self.TargetPlayer = nil
		self:ResetPathfinding()
		return
	end

	local distance = (root.Position - self.Root.Position).Magnitude

	if self.SafeZonesFolder and self:IsInSafeZone(root.Position) then
		self.IgnoreUntil[player.UserId] = os.clock() + self.IgnoreDuration
		self.State = STATE_PATROL
		self.TargetPlayer = nil
		self:ResetPathfinding()
		return
	end

	local now = os.clock()

	if now - self.LastPositionCheckTime >= self.PositionCheckInterval then
		self.LastValidPosition = self.Root.Position
		self.LastPositionCheckTime = now
	end

	-- Detecção de travamento
	if self.Humanoid.MoveDirection.Magnitude > 0.1 then
		local posDelta = (self.Root.Position - self.LastValidPosition).Magnitude
		if posDelta < 0.5 then
			self.StuckTimer += 0.1
		else
			self.StuckTimer = 0
		end
	else
		self.StuckTimer = 0
	end

	if self.StuckTimer > self.StuckThreshold then
		self.StuckTimer = 0
		self.State = STATE_INVESTIGATE
		self.TargetPlayer = nil
		self:ResetPathfinding()
		self.LastNoisePos = self.Root.Position + Vector3.new(math.random(-15,15), 0, math.random(-15,15))
		self.IgnoreUntil[player.UserId] = now + self.IgnoreDuration
		return
	end

	if self.ConsecutivePathFails >= self.MaxConsecutiveFails then
		if now - self.LastPathFailTime < self.PathFailCooldown then
			self.State = STATE_INVESTIGATE
			self.TargetPlayer = nil
			self:ResetPathfinding()
			self.LastNoisePos = self.Root.Position + Vector3.new(math.random(-15,15), 0, math.random(-15,15))
			self.IgnoreUntil[player.UserId] = now + self.IgnoreDuration
			return
		else
			self.ConsecutivePathFails = 0
		end
	end

	if distance > self.SightDistance * 1.5 then
		self.State = STATE_INVESTIGATE
		self.TargetPlayer = nil
		self:ResetPathfinding()
		self.LastNoisePos = root.Position
		return
	end

	self.Humanoid.WalkSpeed = self.ChaseSpeed

	-- Perseguição: RECALCULA CAMINHO CONSTANTEMENTE
	self:SmoothMove(root.Position, false)
end

function MonsterAI:StartLoop()
	task.spawn(function()
		while self.Monster and self.Monster.Parent and self.Humanoid.Health > 0 do
			local visiblePlayer = self:FindVisiblePlayer()

			if visiblePlayer then
				self.State = STATE_CHASE
				self.TargetPlayer = visiblePlayer
			end

			if self.State == STATE_CHASE and self.TargetPlayer then
				self:Chase(self.TargetPlayer)
			elseif self.State == STATE_INVESTIGATE then
				self:Investigate()
			else
				self.State = STATE_PATROL
				self:Patrol()
			end

			task.wait(0.1)
		end
	end)
end

return MonsterAI



