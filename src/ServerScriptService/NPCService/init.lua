--[[

Created by: Feelings_La (ROBLOX)
Contact me at: feela._ (Discord)

Copyright 2025 Feela

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]

-- Services
local CollectionService = game:GetService("CollectionService")

-- Modules
local Types = require(script.Types)
local UtilityFunctions = require(script.Dependencies.UtilityFunctions)
local SETTINGS = require(script.SETTINGS)

-- Bindables
local GetActiveNPCModel = script.Bindables.GetActiveNPCModel
local OnNPCRemoval = script.Bindables.OnNPCRemoval

-- Classes
local NPCController = require(script.NPCController)

local NPCService = {}
NPCService.NPCControllers = {} :: {[Model]: Types.NPCController}

---- HELPERS
-- Get current active NPC models
GetActiveNPCModel.OnInvoke = function()
	local list = {}

	for NPCModel, _ in pairs(NPCService.NPCControllers) do
		table.insert(list, NPCModel)
	end

	return list
end

---- PUBLIC APIs
-- Initialize existing models in Workspace as NPCs with behaviourConfig according to their tags
function NPCService:Init()
	for _, model: Model in pairs(CollectionService:GetTagged(SETTINGS.NPC_TAG)) do
		if not model:FindFirstChildOfClass("Humanoid") then
			warn(`[NPCService] Missing Humanoid for {model.Name}.`)
			
			continue
		end
		
		local behaviourConfig = {
			isAggressive = model:HasTag(SETTINGS.NPC_AGGRESSIVE_TAG),
			canRespawn = model:HasTag(SETTINGS.NPC_RESPAWN_TAG),
			respawnAtOrigin = model:HasTag(SETTINGS.NPC_RESPAWN_AT_ORIGIN_TAG),
			canWander = model:HasTag(SETTINGS.NPC_WANDER_TAG)
		}
		
		NPCService:AddNPC(model, behaviourConfig) -- No custom pathConfig nor customLogic
	end
end

-- Add an NPC manually
function NPCService:AddNPC(
	NPCModel: Model, 
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
): Types.NPCController
	
	assert(NPCModel, `[NPCService] Tried to add a nil model as NPC.`)
	
	local model = NPCModel
	local hum = model:FindFirstChildOfClass("Humanoid")
	assert(hum, `[NPCService] Humanoid for model {model.Name} is missing. Please add one.`)
	
	assert(not NPCService.NPCControllers[model],
		`[NPCService] Model {model.Name} is already instantiated as an NPC.`
	)
	
	local controller = NPCController.new(model, behaviourConfig, pathConfig, customLogic)
	NPCService.NPCControllers[model] = controller

	local function onDied()
		if NPCService.NPCControllers[model]._canRespawn then
			local savedCFrame = controller._respawnAtOrigin 
				and controller.OriginCFrame or controller.NPCModel.PrimaryPart.CFrame
			local savedParent = model.Parent

			-- Destroy the old controller
			controller.NPCLogic:OnDeath()
			controller:Destroy()
			NPCService.NPCControllers[model] = nil
			
			-- Find new model
			assert(SETTINGS.NPC_STORAGE,
				`[NPCService] NPC_STORAGE path is missing. Please add one inside SETTINGS. NPC won't be respawned by default.`
			)

			local newModel: Model = SETTINGS.NPC_STORAGE:FindFirstChild(model.Name)
			assert(newModel, 
				`[NPCService] NPC model for {model.Name} is missing. Please add one. This NPC won't be respawned by default.`
			)
			
			newModel = newModel:Clone()
			newModel.Parent = savedParent
			newModel:PivotTo(savedCFrame)
			
			model = newModel
			hum = newModel:FindFirstChildOfClass("Humanoid")
			assert(hum,
				`[NPCService] Humanoid for cloned model of {model.Name} is missing. Please add one.`
			)
			
			-- Make new controller
			controller = NPCController.new(model, behaviourConfig, pathConfig, customLogic)
			NPCService.NPCControllers[model] = controller
			
			UtilityFunctions:AddConnection(controller._connections, "Died", hum.Died, function()
				onDied()
			end)
		else
			controller.NPCLogic:OnDeath()
			controller:Destroy()
			NPCService.NPCControllers[model] = nil
		end
	end
	
	UtilityFunctions:AddConnection(controller._connections, "Died", hum.Died, function()
		onDied()
	end)
	
	-- To remove the local reference of 'controller' when :RemoveNPC() is called
	local conn
	conn = OnNPCRemoval.Event:Connect(function(modelToRemove: Model)
		if modelToRemove == model then
			controller = nil
			conn:Disconnect()
		end
	end)
	
	return controller
end

-- Remove the controller of a specified model. Stops all behaviour controlled by it.
function NPCService:RemoveNPC(
	NPCModel: Model
)
	assert(NPCModel, `[NPCService] Tried to remove an NPC of nil model.`)
	
	if NPCService.NPCControllers[NPCModel] then
		NPCModel.Parent = NPCService.NPCControllers[NPCModel].OldParent -- Just in case it was culled
		NPCService.NPCControllers[NPCModel]:Destroy()
		NPCService.NPCControllers[NPCModel] = nil
		
		OnNPCRemoval:Fire(NPCModel)
	else
		warn(`[NPCService] Attempted to remove a missing NPC with model {NPCModel.Name}. It might have been removed already.`)
	end
end

return NPCService