# NPCService
Easily create and manage NPCs with aggressive or passive behaviours, including a simple combat and wandering logic.

Get it:
* Creator Store: https://create.roblox.com/store/asset/88389726359588/NPCService
* File:
[NPCService.rbxm|attachment](upload://iMLpn6lp6eMzxHJPR8ycTcrKcf3.rbxm) (19.4 KB)

## Overview
`NPCService` is a modular, reusable system to help create and manage server-sided NPCs efficiently. I decided to create this module because I wanted to minimize lag as much as possible while still using the server as the handler. As you may know, there are ways to make NPCs run locally, but then it gets quite complicated against exploiters.

## Architecture
Each NPC is assigned to a `NPCController` that handles its state on the server:
* Spawning
* Despawning
* Culling (disables all running threads when they don't need to be rendered)
* Path using [SimplePath](https://grayzcale.github.io/simplepath/) 
* Any info unrelated to `NPCLogic` should be put here

Each `NPCController` also has its own `NPCLogic` to handle every movement/AI-related behaviour.

## Features
### Smart Chasing: 
- Uses [SimplePath](https://grayzcale.github.io/simplepath/) module modified with type checking added for ease of use.
- When `_chaseTarget` part is no longer within sight of the NPC, they enter a state of smart chasing.  If this continues for `ChaseTimeout` seconds, NPC will return to the origin. This is done for the realism aspect.

### Aggressive Behaviour: 
- Detects for nearby players within a detection cone and chases after them if ```isAggressive``` is set to ```true``` upon instantiation.
- Returns to the origin if no players are within sight for `ChaseTimeout` seconds. 
- Attacks when their ```_chaseTarget``` is within ```AttackRange``` studs with a cooldown of ```AttackCooldown``` seconds.

### Passive Behaviour: 
- Nothing will happen other than wandering if enabled.

### Player Detection
- Detects player if they are within the sight of the NPC, i.e. within ```MaxSightDistance``` and ```MaxSightAngle```. In other words, within its detection cone.

### Respawning: 
- Respawns the NPC if ```canRespawn``` is set to true upon instantiation. This will not work if your game doesn't have ```SETTINGS.NPC_STORAGE``` set or your NPC model is not found inside ```SETTINGS.NPC_STORAGE```.
- If `respawnAtOrigin` is set to true upon instantiation, NPC respawns at their origin CFrame, if not, the position where they died.

### Wandering: 
- Wanders around during idle if ```canWander``` is set to ```true``` upon instantiation.

### Culling: 
- Active NPCs are paused temporarily when no nearby players are detected to reduce server load.
- NPC should correctly remember the state they were in.

## Basic Usage
```lua
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
```
Please make sure to change the SETTINGS ModuleScript if you wish to change any settings:
* `NPC_STORAGE`, the place where your NPC models are stored
* `NPC_TAG`, the tag needed to identify a model as NPC
* `NPC_AGGRESSIVE_TAG`, the tag needed to enable `isAggressive` for tagged NPC
* `NPC_RESPAWN_TAG`, the tag needed to enable `canRespawn` for tagged NPC
* `NPC_RESPAWN_AT_ORIGIN_TAG`, the tag needed to enable `respawnAtOrigin` for tagged NPC
* `NPC_WANDER_TAG`, the tag needed to enable `canWander` for tagged NPC
* `CULLING_FREQUENCY`, how often (per second) culling calls are often to check for players
* `CULLING_DISTANCE`, the maximum distance for NPC to be active

* `PATH_VISUALIZE`, set to true for waypoints visualization made from the created path

## APIs

Instantiates every model with a Humanoid tagged as `SETTINGS.NPC_TAG` and any custom tags in accordance to `SETTINGS`.
```lua
NPCService:Init()
```

Creates an NPC manually.  Optional arguments have default values if not specified. The recommended value for `WaypointSpacing` is above 2; otherwise, it won't work properly!
```lua
NPCService:AddNPC(
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
	}?
): NPCController
```
-  `isAggressive`: NPC chases players if true
- `canRespawn`: Respawns after death
- `respawnAtOrigin`: Determines respawn position 
- `canWander`: Enables wandering during idle
- `pathConfig`: The `AgentParams` table used in PathfindingService

Removes an existing NPC (destroys the NPC's Controller and Logic. Does not destroy the model).
```lua
NPCService:RemoveNPC(NPCModel: Model)
```

There is type checking implemented in this module, so you can easily check which methods are available. For example:
```lua
local NPCService = require(script.Parent)

local model: Model = workspace.testingnpcs.Aggressive
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
```

## Custom Logic (Inheritance)
You can extend `NPCLogic` by creating a new ModuleScript named your NPC's model. Be sure to parent it under `NPCLogic` ModuleScript. Example code:
```lua
local NPCLogic = require(script.Parent)

local InheritedLogic = {}
InheritedLogic.__index = InheritedLogic

export type InheritedLogic = typeof(setmetatable({}, InheritedLogic)) & NPCLogic.NPCLogic

function InheritedLogic.new(
	nameId: string,
	NPCController: Types.NPCController
): InheritedLogic
	
	local self = setmetatable(NPCLogic.new(nameId, NPCController) :: InheritedLogic, InheritedLogic)
	
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
```

## Credits
* [SimplePath by grayzscale](https://grayzcale.github.io/simplepath/): Used for NPC pathfinding. Modified with type checking for ease of use.

## Disclaimers
I did not use any Maid or Janitor library in this module because I wanted to keep it accessible for anyone who does not use them. All cleanup and resource management is handled manually, so there may be some issues with dereferencing or connection cleanup. If you notice any memory leaks or unexpected behaviour, let me know.