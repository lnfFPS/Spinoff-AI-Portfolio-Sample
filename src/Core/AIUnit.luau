--!nocheck
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local AITypeHandler = require(script.Parent.AITypeHandler)
local AIRegistry = require(script.Parent.AIRegistry)
local SSM = require(ReplicatedStorage.Shared.ServerStateMachine)

local AIUnit = {}
AIUnit.__index = AIUnit

local function GetAIData(model: Model)
	local aiType = model:GetAttribute("AIType") or model.Name
	return require(ServerStorage.AIData:FindFirstChild(aiType))
end

local function GetRootAndHumanoid(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

local function SameGoal(a: Vector3?, b: Vector3?): boolean
	if a == nil and b == nil then
		return true
	end

	if a == nil or b == nil then
		return false
	end

	return a == b
end

function AIUnit.new(model: Model, actor: Actor, aiId: number)
	local self = setmetatable({}, AIUnit)

	local data = GetAIData(model)

	self.AIId = aiId
	self.Model = model
	self.Root = model.PrimaryPart or model:WaitForChild("HumanoidRootPart")
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.Actor = actor
	self.Data = data

	self.TargetResolver = nil
	self.LastSentTarget = nil
	self.LastMovementState = nil
	self.LastMovementGoal = nil
	self.Destroyed = false

	self.Root:SetNetworkOwner(nil)

	self.Humanoid.MaxHealth = data.Health
	self.Humanoid.Health = data.Health
	self.Humanoid.WalkSpeed = data.WalkSpeed

	self.Actions = AITypeHandler.new(model, data, {
		AcquireTarget = function()
			return self:AcquireTarget()
		end,

		SyncTarget = function(targetRoot: BasePart?, force: boolean?)
			self:SyncTarget(targetRoot, force)
		end,

		SetMovementState = function(stateName: string, goalPosition: Vector3?)
			self:SetMovementState(stateName, goalPosition)
		end,

		ResetPath = function()
			self:ResetPathBrain()
		end,

		TurnTowards = function(targetPos: Vector3)
			self:TurnTowards(targetPos)
		end,

		RequestStun = function(stunTime: number)
			self:RequestStun(stunTime)
		end,

		IsStunned = function()
			return self:IsStunned()
		end,

		OnDeadEntered = function()
			self:DestroyPathBrain()
		end,

		Cleanup = function()
			self:Cleanup()
		end,
	})

	AIRegistry:Register(model, self, self.Actions)

	-- SSM stands for ServerStateMachine and is here because it allows the player to stun the AI (basically an init)
	self.Actions.SSM = SSM:new(self.Model, {
	    StunImmune = self.Data.StunImmune,
	    RecoveryTime = self.Data.RecoveryTime,
	    WalkSpeed = self.Data.WalkSpeed,
    })

	self.Actor:SendMessage("New", self.AIId, model, self.Data.DetectionRange)

	self.Actions:Start()

	return self
end

function AIUnit:SetTargetResolver(resolver)
	self.TargetResolver = resolver
end

function AIUnit:GetDefaultTarget(customModel, detectionRange :number, ignoreTargetTags :boolean): BasePart?
	local best = nil
	local bestDistance = detectionRange or self.Data.DetectionRange
	local seen = {}

	local owner = customModel or self.Model

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character ~= owner and not seen[character] then
			seen[character] = true

			local root, humanoid = GetRootAndHumanoid(character)
			if root and humanoid and humanoid.Health > 0 then
				local distance = (root.Position - owner.HumanoidRootPart.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					best = root
				end
			end
		end
	end
	

	return best
end

function AIUnit:AcquireTarget(): BasePart?
	if self.TargetResolver then
		return self.TargetResolver(self)
	end

	return self:GetDefaultTarget()
end

function AIUnit:SyncTarget(targetRoot: BasePart?, force: boolean?)
	if self.Destroyed then
		return
	end

	if not force and targetRoot == self.LastSentTarget then
		return
	end

	self.LastSentTarget = targetRoot
	self.Actor:SendMessage("Target", self.AIId, targetRoot)
end

function AIUnit:SetMovementState(stateName: string, goalPosition: Vector3?)
	if self.Destroyed then
		return
	end

	if self.LastMovementState == stateName and SameGoal(self.LastMovementGoal, goalPosition) then
		return
	end

	self.LastMovementState = stateName
	self.LastMovementGoal = goalPosition

	if goalPosition then
		self.Actor:SendMessage(
			"SetMovementState",
			self.AIId,
			stateName,
			goalPosition
		)
	else
		self.Actor:SendMessage("SetMovementState", self.AIId, stateName)
	end
end

function AIUnit:ResetPathBrain()
	if self.Destroyed then
		return
	end



	self.Actor:SendMessage("ResetPath", self.AIId)
end

function AIUnit:DestroyPathBrain()
	if self.Destroyed then
		return
	end

	self.LastSentTarget = nil
	self.LastMovementState = nil
	self.LastMovementGoal = nil
	self.Destroyed = true
	self.Actor:SendMessage("Destroy", self.AIId)
end

function AIUnit:IsStunned(): boolean
	return SSM:GetState(self.Model) == "Stunned"
end

function AIUnit:RequestStun(stunTime: number)
	if self.Destroyed then
		return
	end

	self.Actions:Cancel()
	self.Actions:StopAll(0.05)
	self:SetMovementState("Hold")
	self:ResetPathBrain()

	SSM:StunRecovery(self.Model, stunTime)
end

function AIUnit:Cleanup()

	local actor = self.Actor
	local model = self.Model

	if actor then
		actor:SendMessage("Destroy", self.AIId)
	end

	self.Destroyed = true

	AIRegistry:Unregister(model)

	if self.Actions then
		self.Actions:Destroy()
		self.Actions = nil
	end

	self.Model = nil
	self.Root = nil
	self.Humanoid = nil
	self.Actor = nil

	task.defer(function()
		if model and model.Parent then
			model:Destroy()
		end
	end)
end

return AIUnit
