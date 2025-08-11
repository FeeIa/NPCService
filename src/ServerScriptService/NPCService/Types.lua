-- Modules
local SimplePath = require(script.Parent.Dependencies.SimplePath)

local Types = {}

export type NPCLogic = {	
	new: (
		nameId: string,
		NPCController: NPCController,
		customLogic: {
			MaxSightDistance: number?,
			MaxSightAngle: number?,
			ChaseTimeout: number?,
			AttackRange: number?,
			AttackCooldown: number?,
			ChaseDetectionInterval: number?,
		}?
	) -> NPCLogic,
	
	NPCController: NPCController,
	NameId: string,
	
	MaxSightDistance: number,
	MaxSightAngle: number,
	ChaseTimeout: number,
	AttackRange: number,
	AttackCooldown: number,
	ChaseDetectionInterval: number,
	
	_status: string,
	_lastAttackTime: number,
	_timeChaseTargetLastSeen: number,
	_chaseTarget: BasePart,
	_detectedPlayerChars: {Model},
	_threads: {thread},
	_connections: {RBXScriptConnection},
	
	-- Methods
	InitLogic: (self: NPCLogic) -> (),
	InitCustomLogic: (self: NPCLogic) -> (),
	GetDefaultRaycastParams: (self: NPCLogic, include: {Instance}?) -> RaycastParams,
	IsPartInSight: (	
		self: NPCLogic, 
		part: BasePart, 
		raycastParams: RaycastParams?,
		includeSiblings: boolean?
	) -> boolean,
	GetClosestPlayerCharInSight: (self: NPCLogic) -> (Model, number),
	Attack: (self: NPCLogic, target: Model) -> (),
	ChasePart: (self: NPCLogic, part: BasePart) -> (),
	StartIdle: (self: NPCLogic, part: BasePart) -> (),
	ReturnToOrigin: (self: NPCLogic) -> (),
	StopChase: (self: NPCLogic) -> (),
	StartDetectPlayersThread: (self: NPCLogic) -> (),
	OnDeath: (self: NPCLogic) -> (),
	Destroy: (self: NPCLogic) -> (),
}

export type NPCController = {
	new: (
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
	) -> NPCController,
	
	NPCModel: Model,
	OldParent: Instance,
	OriginCFrame: CFrame,
	
	NPCLogic: NPCLogic,
	
	Path: SimplePath.SimplePath,
	
	_isSpawned: boolean,
	_threads: {thread},
	_connections: {RBXScriptConnection},
	
	_isAggressive: boolean,
	_canRespawn: boolean,
	_respawnAtOrigin: boolean,
	_canWander: boolean,
	
	-- Methods
	Spawn: (self: NPCController, spawnCFrame: CFrame?) -> (),
	Despawn: (self: NPCController) -> (),
	StartAutoSleepThread: (self: NPCController) -> thread,
	StopOtherActivePathExcept: (self: NPCController, exemptedStatus: string) -> (),
	Destroy: (self: NPCController) -> (),
}

return Types