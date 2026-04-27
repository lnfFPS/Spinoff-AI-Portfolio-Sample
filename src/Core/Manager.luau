local Manager = {}

local SharedTableRegistry = game:GetService("SharedTableRegistry")
local ServerStorage = game:GetService("ServerStorage")

local AIModels = ServerStorage:WaitForChild("AIModels")
local Modules = script.Parent

local AIUnit = require(Modules.AIUnit)
local AIRegistry = require(Modules.AIRegistry)

local SPAWN_FOLDER = workspace.AIs

local nextAIId = 0

function Manager.spawn(actor: Actor, enemyName: string, position: Vector3)
	local model = AIModels:FindFirstChild(enemyName)
	assert(model, "[AIManager] Missing AI model: " .. enemyName)

	nextAIId += 1

	local clone = model:Clone()
	clone:SetAttribute("AIId", nextAIId)
	clone:SetAttribute("AIType", enemyName)
	clone:PivotTo(CFrame.new(position))
	clone.Parent = SPAWN_FOLDER

	local aiUnit = AIUnit.new(clone, actor, nextAIId)

	return clone, aiUnit
end

function Manager.cleanupAll(actor: Actor)
	if actor then
		actor:SendMessage("CleanupAll")
	end

	for _, unit in pairs(AIRegistry:GetUnits()) do
		if unit then
			unit:Cleanup()
		end
	end

	SharedTable.clear(pathShare)
end

return Manager