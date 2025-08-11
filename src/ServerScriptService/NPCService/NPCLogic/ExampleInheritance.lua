-- Modules
local UtilityFunctions = require(script.Parent.Parent.Dependencies.UtilityFunctions)

-- Classes
local NPCLogic = require(script.Parent)

local InheritedLogic = {}
InheritedLogic.__index = InheritedLogic

export type InheritedLogic = typeof(setmetatable({}, InheritedLogic)) & NPCLogic.NPCLogic

function InheritedLogic.new(
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
): InheritedLogic
	
	local self = setmetatable(NPCLogic.new(nameId, NPCController, customLogic) :: InheritedLogic, InheritedLogic)
	
	return self
end

-- Override :InitCustomLogic() for custom behaviour 
function InheritedLogic.InitCustomLogic(self: InheritedLogic)
	-- Example: Make NPC randomly dies when there is a player nearby

	UtilityFunctions:AddThread(self._threads, "CustomerDetection", function()
		local hum = self.NPCController.NPCModel:FindFirstChildOfClass("Humanoid")
		
		while task.wait(3) do
			if not hum then return end
			
			local nearestChar, dist = self:GetClosestPlayerCharInSight()
			
			if nearestChar and dist < 20 and math.random(1, 100) <= 40 then
				hum:TakeDamage(math.huge)
			end
		end
	end)
end

-- Override :Attack()
function InheritedLogic.Attack(self: InheritedLogic)
	self:CustomNewMethod()
end

-- Making custom method for custom logic (example)
function InheritedLogic.CustomNewMethod(self: InheritedLogic)
	warn("THIS IS A CUSTOM")
end

-- Set at the end for type checking to fully work
setmetatable(InheritedLogic, NPCLogic)

return InheritedLogic