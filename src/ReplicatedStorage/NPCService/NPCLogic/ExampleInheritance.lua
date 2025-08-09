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

-- Override method
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
