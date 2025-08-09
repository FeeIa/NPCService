-- Class: NPCLogic
-- Can do inheritance for custom NPC logic (make sure to type check if you want intellisense)

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Modules
local Types = require(script.Parent.Types)
local UtilityFunctions = require(script.Parent.Dependencies.UtilityFunctions)

-- Bindables
local GetActiveNPCModel = script.Parent.Bindables.GetActiveNPCModel

local NPCLogic = {}
NPCLogic.__index = NPCLogic
NPCLogic.__className = "NPCLogic"

NPCLogic.STATUS = {
	IDLE = "Idle",
	CHASING = "Chasing",
	ATTACKING = "Attacking",
	RETURNING = "Returning",
	DEAD = "Dead"
}

NPCLogic.DEFAULTS = {
	MaxSightDistance = 30,
	MaxSightAngle = 100,
	ChaseTimeout = 5,
	AttackRange = 2.5,
	AttackCooldown = 1,
	ChaseDetectionInterval = 0.25
}

export type NPCLogic = Types.NPCLogic

-- CONSTRUCTOR
function NPCLogic.new(
	nameId: string,
	NPCController: Types.NPCController,
	customLogic: {
		MaxSightDistance: number?,
		MaxSightAngle: number?,
		ChaseTimeout: number?,
		AttackRange: number?,
		AttackCooldown: number?,
		ChaseDetectionInterval: number?,
	}?
): NPCLogic
	
	assert(nameId, "[NPCLogic] nameId is nil.")
	assert(NPCController, "[NPCLogic] NPCController is nil.")
	
	local self = setmetatable({} :: NPCLogic, NPCLogic)
	
	self.NPCController = NPCController
	self.NameId = nameId
	
	-- Properties
	for prop, defaultVal in pairs(NPCLogic.DEFAULTS) do
		self[prop] = (customLogic and customLogic[prop]) or defaultVal
	end
	
	-- States
	self._status = self.STATUS.IDLE
	self._lastAttackTime = workspace:GetServerTimeNow()
	self._timeChaseTargetLastSeen = workspace:GetServerTimeNow()
	self._chaseTarget = nil
	self._detectedPlayerChars = {}
	self._connections = {}
	self._threads = {}
	
	return self
end

---- INITIALIZATION
-- INITIALIZE THE LOGIC
function NPCLogic.InitLogic(self: NPCLogic)
	if self._status ~= self.STATUS.CHASING then
		self:StartIdle()
	end
	
	-- Players check loop is done inside StartDetectPlayersThread (which is called by NPCController)
	-- If self.NPCController._isAggressive is true, closest player will be chased after
end

---- RAYCASTING
-- GET DEFAULT RAYCAST PARAMS TO IGNORE FELLOW NPCS
function NPCLogic.GetDefaultRaycastParams(
	self: NPCLogic, 
	includeInRaycast: {Instance}?
): RaycastParams
	
	includeInRaycast = includeInRaycast or {}
	
	-- Create exclude list for RaycastParams
	local excludedInstances = {}
	local NPCModels: {Model} = GetActiveNPCModel:Invoke()
	
	for _, model: Model in pairs(NPCModels) do
		-- CHeck whether its descendants are in the include list
		local exclude = true
		
		for _, ins: Instance in pairs(includeInRaycast) do
			if model:IsAncestorOf(ins) then
				exclude = false
				break
			end
		end
		
		if exclude then table.insert(excludedInstances, model) end
	end
	
	table.clear(NPCModels)
	
	-- Create params
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = excludedInstances
	params.FilterType = Enum.RaycastFilterType.Exclude
	
	return params
end

-- CHECKS IF A PART IS IN SIGHT OF THE NPC DETECTION CONE
function NPCLogic.IsPartInSight(
	self: NPCLogic, 
	part: BasePart, 
	raycastParams: RaycastParams?,
	includeSiblings: boolean?
): boolean
	
	assert(part, "[NPCLogic] Attempted to check the visibility of a nil part.")
	
	local root: BasePart = self.NPCController.NPCModel.PrimaryPart
	
	-- Check distance/radius of sight
	local dist: number = (part.Position - root.Position).Magnitude
	local inDistance = dist <= self.MaxSightDistance
	if not inDistance then return false end
	
	-- Check FOV
	local rootLookDirection = root.CFrame.LookVector
	local toPartDirection = (part.Position - root.Position).Unit
	local dotProduct = rootLookDirection:Dot(toPartDirection)
	local angle = math.deg(math.acos(dotProduct))
	local inAngle = angle <= self.MaxSightAngle
	if not inAngle then return false end
	
	-- Checking raycast
	raycastParams = raycastParams or self:GetDefaultRaycastParams({part})
	
	local result: RaycastResult = workspace:Raycast(
		root.Position,
		toPartDirection * (dist + 3),
		raycastParams
	)
	if not result then return false end
	
	local hit = result.Instance
	local isBlocked: boolean
	
	if hit == part then
		isBlocked = false
	else
		if includeSiblings then
			if hit:IsDescendantOf(part.Parent) then
				isBlocked = false
			else
				isBlocked = true
			end
		else
			isBlocked = true
		end
	end
	
	return not isBlocked
end

---- DETECTION
--  START THE LOOP FOR NEARBY PLAYERS DETECTION AND THEN CHASES THE NEAREST ONE
function NPCLogic.StartDetectPlayersThread(self: NPCLogic)
	UtilityFunctions:AddThread(self._threads, "DetectPlayers", function()
		while task.wait(self.ChaseDetectionInterval) do
			-- Get players within sight
			local playerChars = {} :: {Model}

			for _, player in pairs(Players:GetPlayers()) do
				local char: Model = player.Character
				if not char then continue end

				table.insert(playerChars, char)
			end

			table.clear(self._detectedPlayerChars)

			for _, char: Model in pairs(playerChars) do
				local root = char.PrimaryPart
				if not root then continue end

				local hum = char:FindFirstChildOfClass("Humanoid")
				if not hum or hum:GetState() == Enum.HumanoidStateType.Dead then continue end

				local inSight: boolean = self:IsPartInSight(root, nil, true)
				if inSight and hum.Health > 0 then
					table.insert(self._detectedPlayerChars, char)
				end
			end
			
			-- Get closest player
			if not self.NPCController._isAggressive then return end
			
			local closestChar = self:GetClosestPlayerCharInSight()
			
			-- Only start a new chase when the target is different
			if closestChar and closestChar.PrimaryPart ~= self._chaseTarget then
				self:ChasePart(closestChar.PrimaryPart)
			end
		end
	end)
end

-- GET CLOSEST PLAYER CHARACTER IN SIGHT
function NPCLogic.GetClosestPlayerCharInSight(self: NPCLogic): Model
	local closestChar = nil
	local closestDist = math.huge
	
	for _, playerChar in pairs(self._detectedPlayerChars) do
		if self:IsPartInSight(playerChar.PrimaryPart, nil, true) then
			local playerRoot = playerChar.PrimaryPart
			local NPCRoot = self.NPCController.NPCModel.PrimaryPart
			
			if not playerRoot or not NPCRoot then continue end
			
			local dist = (playerRoot.Position - NPCRoot.Position).Magnitude
			if dist < closestDist then
				closestDist = dist
				closestChar = playerChar
			end
		end
	end
	
	return closestChar
end

---- ATTACKING BEHAVIOUR
-- ATTACKS A MAIN TARGET MODEL. THIS CAN BE STATIC IF self IS NOT NEEDED
function NPCLogic.Attack(self: NPCLogic, target: Model)
	assert(target, "[NPCLogic] Tried to attack nil target.")
	
	-- You can impement your custom attack logic here, play animations (locally), etc.
	-- Can be static if you don't need the NPCLogic object. 
	-- Example usage of the NPCLogic object: do damage based on the NPC's hp, etc.
	
	-- This is just an example (directly do damage):
	local hum = target:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	
	NPCLogic.DoDamage(nil, hum, 10)
end

-- DO DAMAGE TO TARGET HUMANOID. THIS CAN BE STATIC IF self IS NOT NEEDED
function NPCLogic.DoDamage(self: NPCLogic, hum: Humanoid, damage: number?)
	assert(hum, "[NPCLogic] Target humanoid is nil.")
	
	hum:TakeDamage(damage or 5)
end

---- BEHAVIOUR LOGIC
-- CHASES AFTER A PART
function NPCLogic.ChasePart(self: NPCLogic, part: BasePart)
	assert(part, "[NPCLogic] Target part to chase is nil.")
	
	self._chaseTarget = part
	
	self.NPCController:StopOtherActivePathExcept(self.STATUS.CHASING)
	self._status = self.STATUS.CHASING
	
	-- Main logic
	local model = self.NPCController.NPCModel
	if not model or not part then self:StopChase() return end

	local NPCHum = model:FindFirstChildOfClass("Humanoid")
	if not NPCHum then self:StopChase() return end

	local targetHum = part.Parent:FindFirstChildOfClass("Humanoid")
	if targetHum and targetHum:GetState() == Enum.HumanoidStateType.Dead then
		self:StopChase()

		return
	end
	
	local isInSight = self:IsPartInSight(part, nil, true)
	
	if isInSight then
		self._timeChaseTargetLastSeen = workspace:GetServerTimeNow()
	end
	
	UtilityFunctions:StopThread(self._threads, "Wandering")
	
	-- Setup connections
	UtilityFunctions:AddConnection(self._connections, "Blocked", self.NPCController.Path.Blocked, function()
		self.NPCController.Path:Run(part)
	end)
	
	UtilityFunctions:AddConnection(self._connections, "WaypointReached", self.NPCController.Path.WaypointReached, function()
		isInSight = self:IsPartInSight(part, nil, true)

		if isInSight then
			self._timeChaseTargetLastSeen = workspace:GetServerTimeNow()
		end
		
		-- Check if target is still seen
		if (workspace:GetServerTimeNow() - self._timeChaseTargetLastSeen) >= self.ChaseTimeout then
			self:StopChase()
			
			return
		end
		
		-- Check if target is a humanoid and is still alive
		if targetHum and targetHum:GetState() == Enum.HumanoidStateType.Dead then
			self:StopChase()
			
			return
		end
		
		-- Check if target is valid to attack
		if (workspace:GetServerTimeNow() - self._lastAttackTime) >= self.AttackCooldown then
			if (model.PrimaryPart.Position - part.Position).Magnitude <= self.AttackRange then
				local targetPlayerChar = part:FindFirstAncestorOfClass("Model")

				if targetPlayerChar then
					self:Attack(targetPlayerChar)
					self._lastAttackTime = workspace:GetServerTimeNow()
				end
			end
		end
		
		self.NPCController.Path:Run(part)
	end)
	
	UtilityFunctions:AddConnection(self._connections, "Reached", self.NPCController.Path.Reached, function()
		-- Check if target is a humanoid and is still alive
		if targetHum and targetHum:GetState() == Enum.HumanoidStateType.Dead then
			self:StopChase()

			return
		end
		
		-- Check if target is valid to attack
		if (workspace:GetServerTimeNow() - self._lastAttackTime) >= self.AttackCooldown then
			if (model.PrimaryPart.Position - part.Position).Magnitude <= self.AttackRange then
				local targetPlayerChar = part:FindFirstAncestorOfClass("Model")

				if targetPlayerChar then
					self:Attack(targetPlayerChar)
					self._lastAttackTime = workspace:GetServerTimeNow()
				end
			end
		end
		
		self.NPCController.Path:Run(part)
	end)
	
	UtilityFunctions:AddConnection(self._connections, "Error", self.NPCController.Path.Error, function()
		self.NPCController.Path:Run(self.NPCController.OriginCFrame.Position)
	end)
	
	local succ, err = pcall(function()
		self.NPCController.Path:Run(part)
	end)
end

-- IDLE AND WANDERS AROUND THE ORIGIN IF ENABLED
function NPCLogic.StartIdle(self: NPCLogic)
	self.NPCController:StopOtherActivePathExcept(self.STATUS.IDLE)
	self._status = self.STATUS.IDLE
	
	if not self.NPCController._canWander then return end
	
	UtilityFunctions:AddThread(self._threads, "Wandering", function()
		while self._status == self.STATUS.IDLE do
			local root = self.NPCController.NPCModel.PrimaryPart
			if root then
				local randomOffset = Vector3.new(
					math.random(-10, 10),
					root.Position.Y,
					math.random(-10, 10)
				)
				local targetPosition = root.Position + randomOffset

				local hum = self.NPCController.NPCModel:FindFirstChildOfClass("Humanoid")
				if hum then
					hum:MoveTo(targetPosition)
				end
			end
			
			task.wait(math.random(3, 6))
		end
	end)
end

-- RETURNS TO THE ORIGIN
function NPCLogic.ReturnToOrigin(self: NPCLogic)
	self.NPCController:StopOtherActivePathExcept(self.STATUS.RETURNING)
	self._status = self.STATUS.RETURNING
	
	local hum = self.NPCController.NPCModel:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	
	-- Setup connections
	UtilityFunctions:AddConnection(self._connections, "Blocked", self.NPCController.Path.Blocked, function()
		self.NPCController.Path:Run(self.NPCController.OriginCFrame.Position)
	end)
	
	UtilityFunctions:AddConnection(self._connections, "WaypointReached", self.NPCController.Path.WaypointReached, function()
		self.NPCController.Path:Run(self.NPCController.OriginCFrame.Position)
	end)
	
	UtilityFunctions:AddConnection(self._connections, "Reached", self.NPCController.Path.Reached, function()
		self._status = self.STATUS.IDLE

		if self.NPCController.Path._status == self.NPCController.Path.StatusType.Active then
			self.NPCController.Path:Stop()
		end
		
		self:StartIdle()
		
		UtilityFunctions:DisconnectConnection(self._connections, "Blocked")
		UtilityFunctions:DisconnectConnection(self._connections, "WaypointReached")
		UtilityFunctions:DisconnectConnection(self._connections, "Reached")
		UtilityFunctions:DisconnectConnection(self._connections, "Error")
	end)
	
	UtilityFunctions:AddConnection(self._connections, "Error", self.NPCController.Path.Error, function()
		self.NPCController.Path:Run(self.NPCController.OriginCFrame.Position)
	end)
	
	local succ, err = pcall(function()
		self.NPCController.Path:Run(self.NPCController.OriginCFrame.Position)
	end)
end

-- STOP CHASING
function NPCLogic.StopChase(self: NPCLogic)
	-- Disconnect chasing connections
	UtilityFunctions:DisconnectConnection(self._connections, "Blocked")
	UtilityFunctions:DisconnectConnection(self._connections, "WaypointReached")
	UtilityFunctions:DisconnectConnection(self._connections, "Reached")
	UtilityFunctions:DisconnectConnection(self._connections, "Error")
	
	self._chaseTarget = nil
	self:ReturnToOrigin()
end

---- CLEANUP
-- FIRES AFTER THE MODEL ASSSOCIATED DIES
function NPCLogic.OnDeath(self: NPCLogic)
	task.wait(3)
	self.NPCController.NPCModel:Destroy()
end

-- DESTROYS THE OBJECT FOR CLEANUP
function NPCLogic.Destroy(self: NPCLogic)
	-- Tables
	table.clear(self._detectedPlayerChars)
	self._detectedPlayerChars = nil
	
	-- Threads & Connections
	for threadName, thread in pairs(self._threads) do
		UtilityFunctions:StopThread(self._threads, threadName)
	end
	table.clear(self._threads)
	self._threads = nil
	
	for connectionName, connection in pairs(self._connections) do
		UtilityFunctions:DisconnectConnection(self._connections, connectionName)
	end
	table.clear(self._connections)
	self._connections = nil

	-- Others
	for k in pairs(self) do
		self[k] = nil
	end
	
	setmetatable(self, nil)
end

return NPCLogic