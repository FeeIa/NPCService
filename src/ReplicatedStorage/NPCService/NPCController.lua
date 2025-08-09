-- Class: NPCController

-- Servies
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local Types = require(script.Parent.Types)
local SimplePath = require(script.Parent.Dependencies.SimplePath)
local UtilityFunctions = require(script.Parent.Dependencies.UtilityFunctions)
local SETTINGS = require(script.Parent.SETTINGS)

-- Classes
local NPCLogic = require(script.Parent.NPCLogic)

local NPCController = {}
NPCController.__index = NPCController
NPCController.__className = "NPCController"

NPCController.DEFAULTS = {
	isAggressive = false,
	canRespawn = false,
	respawnAtOrigin = false,
	canWander = false
}

export type NPCController = Types.NPCController

-- CONSTRUCTOR
function NPCController.new(
	model: Model, 
	behaviourConfig: {
		isAggressive: boolean?,
		canRespawn: boolean?, 
		respawnAtOrigin: boolean?, 
		canWander: boolean?
	}?,
	pathConfig: {
		AgentRadius: integer?,
		AgentHeight: integer?,
		AgentCanJump: boolean?,
		AgentCanClimb: boolean?,
		WaypointSpacing: number?,
		CostModifiers: {[string]: number}?
	}?,
	customLogic: {
		MaxSightDistance: number?,
		MaxSightAngle: number?,
		ChaseTimeout: number?,
		AttackRange: number?,
		AttackCooldown: number?,
		ChaseDetectionInterval: number?,
	}?
): NPCController
	
	assert(model, "[NPCController] Enemy model is nil.")
	
	local self = setmetatable({} :: NPCController, NPCController)
	
	self.NPCModel = model
	self.OldParent = nil
	self.OriginCFrame = self.NPCModel.PrimaryPart.CFrame
	
	-- In case of a custom inherited logic
	local isCustom: ModuleScript = script.Parent.NPCLogic:FindFirstChild(model.Name)
	if isCustom then
		self.NPCLogic = (require(isCustom) :: NPCLogic.NPCLogic).new(model.Name, self, customLogic)
	else
		self.NPCLogic = NPCLogic.new(model.Name, self, customLogic)
	end
	
	-- Pathfinding
	self.Path = SimplePath.new(self.NPCModel, pathConfig or nil)
	self.Path.Visualize = SETTINGS.PATH_VISUALIZE
	
	self._isSpawned = false
	self._threads = {}
	self._connections = {}
	
	-- Behaviour
	for key, defaultValue in pairs(NPCController.DEFAULTS) do
		self[`_{key}`] = (behaviourConfig and behaviourConfig[key]) or defaultValue
	end
	
	-- Edge cases check
	repeat task.wait() until self.NPCModel:FindFirstAncestorOfClass("Workspace")
	
	-- Network ownership to server
	for _, part: BasePart in pairs(self.NPCModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetNetworkOwner(nil)
		end
	end
	
	-- Initialization
	self:Spawn()
	self:StartAutoSleepThread()
		
	return self
end

-- SPAWNS ENEMY TO THE WORKSPACE
function NPCController.Spawn(self: NPCController, spawnCFrame: CFrame?)
	if self._isSpawned then return end
	
	if self.OldParent then
		self.NPCModel.Parent = self.OldParent
	end
	
	if spawnCFrame then
		self.NPCModel:PivotTo(spawnCFrame)
	end
	
	-- We call this no matter what for both aggressive & passive, so we know players that are in sight
	self.NPCLogic:StartDetectPlayersThread()
	
	self.NPCLogic:InitLogic()
	
	for _, part: BasePart in pairs(self.NPCModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetNetworkOwner(nil)
		end
	end
	
	self._isSpawned = true
end

-- REMOVES ENEMY FROM WORKSPACE
function NPCController.Despawn(self: NPCController)
	if not self._isSpawned then return end
	
	self.OldParent = self.NPCModel.Parent
	self.NPCModel.Parent = nil
	
	-- Was despawned, snap back to the origin CFrame and exit the thread if was returning
	if self.OriginCFrame and self.NPCLogic._status == self.NPCLogic.STATUS.RETURNING 
		and self.Path._status == self.Path.StatusType.Active then
		
		self.Path:Stop()
		self.NPCModel:PivotTo(self.OriginCFrame)
		
		-- Disconnect any connections
		for connectionName, connection in pairs(self.NPCLogic._connections) do
			UtilityFunctions:DisconnectConnection(self.NPCLogic._connections, connectionName)
		end
		table.clear(self.NPCLogic._connections)
	end
	
	-- Stop any ongoing thread inside the NPCLogic to save computational resources
	for threadName, thread in pairs(self.NPCLogic._threads) do
		UtilityFunctions:StopThread(self.NPCLogic._threads, threadName)
	end
	table.clear(self.NPCLogic._threads)
	
	self._isSpawned = false
end

-- START THE LOOP FOR NEARBY PLAYERS DETECTION (CULLING PURPOSES)
function NPCController.StartAutoSleepThread(self: NPCController): thread
	if not RunService:IsServer() then return end

	return UtilityFunctions:AddThread(self._threads, "AutoSleep", function()
		while task.wait(1 / SETTINGS.CULLING_FREQUENCY) do
			local NPCModel = self.NPCModel
			local NPCRoot = NPCModel.PrimaryPart

			if not NPCRoot then continue end

			local playersNearbyCount = 0

			for _, player in pairs(Players:GetPlayers()) do
				local playerChar = player.Character
				if not playerChar then continue end

				local playerRoot = playerChar.PrimaryPart
				if not playerRoot then continue end

				local dist = (playerRoot.Position - NPCRoot.Position).Magnitude

				if dist <= SETTINGS.CULLING_DISTANCE then
					playersNearbyCount += 1
				end
			end

			if playersNearbyCount > 0 then
				self:Spawn()
			else
				self:Despawn()
			end
		end
	end)
end

-- STOPS ACTIVE PATH DEPENDING ON STATUS
function NPCController.StopOtherActivePathExcept(self: NPCController, exemptedStatus: string)
	assert(exemptedStatus, "[NPCController] Missing exemptedStatus field.")
	
	if self.NPCLogic._status ~= exemptedStatus and self.Path._status == self.Path.StatusType.Active then
		self.Path:Stop()
	end
end

-- CLEANUP
function NPCController.Destroy(self: NPCController)		
	-- Objects
	self.NPCLogic:Destroy()
	self.NPCLogic = nil
	
	self.Path:Destroy()
	self.Path = nil
	
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

return NPCController