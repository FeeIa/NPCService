local UtilityFunctions = {}
UtilityFunctions.__index = UtilityFunctions

export type Type = typeof(setmetatable({}, UtilityFunctions))

function UtilityFunctions:AddThread(threadList: {thread}, threadName: string, threadCallback: () -> ()): thread
	assert(threadList)
	assert(threadName)
	assert(threadCallback)
	
	UtilityFunctions:StopThread(threadList, threadName)
	
	threadList[threadName] = task.spawn(threadCallback)
end

function UtilityFunctions:StopThread(threadList: {thread}, threadName: string)
	assert(threadList)
	assert(threadName)
	
	if threadList[threadName] then
		task.cancel(threadList[threadName])
		threadList[threadName] = nil
	end
end

function UtilityFunctions:AddConnection(
	connectionList: {RBXScriptConnection},
	connectionName: string,
	connectionSignal: RBXScriptSignal, 
	connectionCallback: () -> ()
): RBXScriptConnection
	
	assert(connectionList)
	assert(connectionName)
	assert(connectionSignal)
	assert(connectionCallback)
	
	UtilityFunctions:DisconnectConnection(connectionList, connectionName)
	
	connectionList[connectionName] = connectionSignal:Connect(connectionCallback)
end

function UtilityFunctions:DisconnectConnection(connectionList: {RBXScriptConnection}, connectionName: string)
	assert(connectionList)
	assert(connectionName)
	
	if connectionList[connectionName] then
		connectionList[connectionName]:Disconnect()
		connectionList[connectionName] = nil
	end
end

return UtilityFunctions