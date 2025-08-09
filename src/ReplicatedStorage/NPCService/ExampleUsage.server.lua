local NPCService = require(script.Parent)

local model: Model = Path.To.Your.Model
local controller = NPCService:AddNPC(
	model,
	{
		-- You only need to pass what value you want custom, everything defaults to false
		isAggressive = true
	},
	{
		-- The parameter pathConfig has a default value of Roblox's default AgentParams, specify if want custom.
		WaypointSpacing = 2 -- Recommended value: Above 2, Roblox's default is 4
	}
)

controller.NPCLogic:ReturnToOrigin() -- Forces to origin return

task.wait(100)

NPCService:RemoveNPC(model)
controller = nil -- Remove reference if no longer used