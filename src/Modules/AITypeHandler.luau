--!nocheck
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared

local AnimationModule = require(Shared.AnimationModule)

local Combat = require(script.Parent.Combat)
local Config = require(script.Parent.Config)
local DamageModule = require(script.Parent.DamageModule)
local FiniteStateMachine = require(script.Parent.FiniteStateMachine)
local SSM = require(Shared.ServerStateMachine)

local TypeModulesFolder = ServerStorage:WaitForChild("AITypes")

local TypeModules = {
	melee = require(TypeModulesFolder:WaitForChild("Melee")),
	gun = require(TypeModulesFolder:WaitForChild("Gun")),
	universal = require(TypeModulesFolder:WaitForChild("Universal")),
}

export type AIData = {
	Type: string,
	Health: number,
	WalkSpeed: number,
	DetectionRange: number,
	StunImmune: boolean,
	RecoveryTime: number,

	LightSwingSpeed: number,
	LightSwingInterval: number,
	LightDamage: number,
	HeavySwingSpeed: number,
	HeavyDamage: number,
	AttackRange: number,

	TargetTags: {string?}, -- what enemies will specifically target even if they are an AI or a possible Ally

	SwingHitbox: {
		Size: Vector3,
		Offset: Vector3,
		MultiHit: boolean,
	},

	Animations: {
		Idle: string,
		Death: string, -- for custom death anims i guess

		LightSwings: { {ID: string, HitTime :number?} },

		HeavySwing: {ID: string, HitTime :number?},
	},
    
	States: {
		[string]: {
			onEnter: () -> (),
			onUpdate: () -> (),
		},
	},

	Sounds: {
		LightSwing: string,
		HeavySwing: string,
		LightHitSound: string,
		HeavyHitSound: string,
		Death: string?,
	},

	Actor: {
		DefaultState: string,
		RepathInterval: number,


		MovementStates: {
			Hold: {
				Mode: string,
			},

			Default: {
				Mode: string,
				SharePath: boolean, -- to make it more optimised shares paths with other AIs if they are close enough
				DistanceTolerance: number, -- keeps the distance like this i hope
			},

			-- KeepDistance = {
			-- 	Mode = "KeepDistance",
			-- 	DesiredDistance = 18,
			-- 	DistanceTolerance = 4,
			-- 	SharePath = true,
			-- },

			-- StrafeLeft = {
			-- 	Mode = "StrafeLeft",
			-- 	StrafeDistance = 10,
			-- 	SharePath = false,
			-- },

			-- StrafeRight = {
			-- 	Mode = "StrafeRight",
			-- 	StrafeDistance = 10,
			-- 	SharePath = false,
			-- },

			-- CustomGoal = {
			-- 	Mode = "CustomGoal",
			-- 	SharePath = false,
			-- },
		},
	},

	OnDeath: {
		CustomStats: {}, -- can be really made of anything bro

		func: (character :Model, damage :number, customStats:{}) -> boolean,
	}
}


local AITypeHandler = {}
AITypeHandler.__index = AITypeHandler

function AITypeHandler.new(model: Model, data :AIData, callbacks)
	local self = setmetatable({}, AITypeHandler)

	self.Model = model
	self.Root = model.PrimaryPart or model:WaitForChild("HumanoidRootPart")
	self.Humanoid = model:FindFirstChildOfClass("Humanoid")
	self.Animator = self.Humanoid:WaitForChild("Animator")
	self.Data = data
self.Callbacks = callbacks or {}

self.SSM = SSM:RegisterCharacter(model, {
	StunImmune = data.StunImmune == true,
	RecoveryTime = data.RecoveryTime,
	WalkSpeed = data.WalkSpeed,
})

	self.TypeName = string.lower(data.Type or "melee")
	self.TypeModule = TypeModules[self.TypeName]

	assert(self.TypeModule, "[AITypeHandler] Unsupported AI type: " .. tostring(self.TypeName))

	self.State = "None"
	self.IsBusy = false
	self.IsDead = false
	self.Destroyed = false
	self.exceededLightLimit = false
	self.LightSwingIndex = 1
	self.ActionToken = 0
	self.CustomTicks = {}

	self.Target = nil
	self.SeenTarget = nil
	self.LastSyncedTarget = nil

	self.Tracks = {}
	self.SoundData = table.clone(data.Sounds or {})
	self.FSM = nil
	self.SSM = nil

	self.OnDeathFunc = nil
	self.CustomStats = nil
	self.MechanicalStats = {} -- put whatever in here bro I like striking lightning at people btw i'm cooler

	if data.OnDeath then
		self.OnDeathFunc = data.OnDeath.func
		self.CustomStats = table.clone(data.OnDeath.CustomStats or {})
	end

	local animator = AnimationModule.getAnimator(model)

	local function LoadTrack(id: string, name: string)
		local track = AnimationModule.load(animator, id, true)
		self.Tracks[name] = track
		return track
	end

	for name, value in pairs(data.Animations or {}) do
		if name == "LightSwings" then
			for i, swingData in ipairs(value) do
				local track = LoadTrack(swingData.ID, "LightSwing" .. i)
				track.Priority = Enum.AnimationPriority.Action
			end
			continue
		elseif name == "HeavySwing" then
			local track = LoadTrack(value.ID, "HeavySwing")
			track.Priority = Enum.AnimationPriority.Action
			continue
		end

		if name ~= "Action" and name ~= "Action2" then
			local track = LoadTrack(value, name)



			if name == "Idle" then
				track.Looped = true
				track.Priority = Enum.AnimationPriority.Movement
				track.Name = "Idle"
			
			elseif name == "Death" then
				track.Priority = Enum.AnimationPriority.Action4
			elseif name == "Shoot" then
				track.Priority = Enum.AnimationPriority.Action
			elseif name == "Reload" then
				track.Priority = Enum.AnimationPriority.Action2
			end
		elseif name == "Action2" then
			for actionName, actionId in pairs(value) do
				if actionName == "LightSwings" then
			        for i, swingData in ipairs(actionId) do
			        	local track = LoadTrack(swingData.ID, "LightSwing" .. i)
			        	track.Priority = Enum.AnimationPriority.Action2
			        end
					continue
			    end
				
				local track = LoadTrack(actionId, actionName)
				track.Priority = Enum.AnimationPriority.Action2
			end
		else
			for actionName, actionId in pairs(value) do
				if actionName == "LightSwings" then
			        for i, swingData in ipairs(actionId) do
			        	local track = LoadTrack(swingData.ID, "LightSwing" .. i)
			        	track.Priority = Enum.AnimationPriority.Action
			        end
					continue
			    end
				
				local track = LoadTrack(actionId, actionName)
				track.Priority = Enum.AnimationPriority.Action
			end
		end
	end

	LoadTrack(Config.DEFAULT_STUN_ANIM, "Stunned")

	if not self.Tracks.Death then
		LoadTrack(Config.DEFAULT_DEATH_ANIM, "Death")
	end

	if not self.SoundData.Death then
		self.SoundData.Death = Config.DEFAULT_DEATH_SOUND
	end

	if self.Tracks.Idle then
		self:Play("Idle", 1, 0.1, 55)
	end

	return self
end

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local ignorePlayersParams = RaycastParams.new()
ignorePlayersParams.FilterType = Enum.RaycastFilterType.Exclude


local function UpdateRaycastFilter(self)
	raycastParams.FilterDescendantsInstances = {
		self.Model,
		workspace.AIs,
	}

	ignorePlayersParams.FilterDescendantsInstances = {
		self.Model,
		workspace.AIs,
		workspace.Players,
	}
end


function AITypeHandler:HasLineOfSight(): boolean
	if self.Target == nil then 
		return false
	end
	local origin = self.Model.HumanoidRootPart.Position
	local offset = self.Target.Position - origin
	local distance = offset.Magnitude

	if distance <= 0 then
		return false
	end

	UpdateRaycastFilter(self)

	local result = workspace:Raycast(origin, offset, raycastParams)
	if not result then
		return false
	end

	if result.Instance.Parent == self.Target.Parent  then
		return true
	end
	

	return false
end

function AITypeHandler:Start()
	local states = self.TypeModule.GetStates(self) -- grabs a state from AITypes (assigned in AIData)
	
	
	states.Dead = {
		onEnter = function()
			self.Humanoid:MoveTo(self.Root.Position)
			self:SetMovementState("Hold")
			self:ResetPathBrain()

			local onDeadEntered = self.Callbacks.OnDeadEntered
			if onDeadEntered then
				onDeadEntered()
			end

			task.delay(3, function()
				if self.Destroyed then
					return
				end

				local cleanup = self.Callbacks.Cleanup
				if cleanup then
					cleanup()
				end
			end)
		end,
	}

	self.FSM = FiniteStateMachine.new({
	    InitialState = "Idle",
	    States = states,
		Context = self,
	})
end

function AITypeHandler:Destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self:Cancel()
	self:StopAll(0)

	if self.FSM then
		self.FSM:Destroy()
		self.FSM = nil
	end

	for _, track in pairs(self.Tracks) do
		track:Destroy()
	end

	table.clear(self.Tracks)

	self.Model = nil
	self.Root = nil
	self.Humanoid = nil
	self.Animator = nil
	self.Data = nil
	self.Callbacks = nil
	self.Target = nil
	self.LastSyncedTarget = nil
	self.TypeModule = nil
	self.OnDeathFunc = nil
	self.CustomStats = nil
end

function AITypeHandler:IsStunned(): boolean
	local isStunned = self.Callbacks.IsStunned
	if isStunned then
		return isStunned()
	end

	return false
end

function AITypeHandler:TransitionState(newState: string, bypassStun: boolean?)
	if self.Destroyed or not self.FSM then
		return
	end

	if self:IsStunned() and not bypassStun and newState ~= "Dead" then -- problem line
		return
	end

	self.FSM:Transition(newState)
end

function AITypeHandler:Cancel(stopAnimations: boolean?)
	self.ActionToken += 1
	self.IsBusy = false

	if not self.IsDead then
		self.State = "None"
	end

	if stopAnimations then
		self:StopAll(0.05, true)
	end
end

function AITypeHandler:IsActionLocked(ignoreBusy :boolean, ignoreStun): boolean
	

	if ignoreBusy and ignoreStun then
		return self.IsDead or SSM:GetState(self.Model) == "Dead"
	end

	if ignoreStun then
		return self.IsDead or SSM:GetState(self.Model) == "Dead"
	end

	if ignoreBusy then
		
		return self.IsDead or self:IsStunned() or SSM:GetState(self.Model) == "Dead"
	end

	return self.IsBusy or self.IsDead or self:IsStunned() or SSM:GetState(self.Model) == "Dead"
end

function AITypeHandler:CanContinue(token: number): boolean

	return
		not self.Destroyed
		and token == self.ActionToken
		and not self.IsDead
		and not self:IsStunned()
		and SSM:GetState(self.Model) ~= "Dead"
end

function AITypeHandler:AcquireTarget()
	local acquireTarget = self.Callbacks.AcquireTarget
	if not acquireTarget then
		self.Target = nil
		return nil
	end

	self.Target = acquireTarget()
	return self.Target
end

function AITypeHandler:SyncTarget(customTarget :Model, force: boolean?)
	local syncTarget = self.Callbacks.SyncTarget
	if not syncTarget then
		return
	end

	syncTarget(customTarget or self.Target, force)
	self.LastSyncedTarget = customTarget or self.Target
end

function AITypeHandler:SetMovementState(stateName: string, goalPosition: Vector3?)
	local setMovementState = self.Callbacks.SetMovementState
	if setMovementState then
		setMovementState(stateName, goalPosition)
	end
end

function AITypeHandler:ResetPathBrain()
	local resetPath = self.Callbacks.ResetPath
	if resetPath then
		resetPath()
	end
end

function AITypeHandler:RequestStun(stunTime: number)
	local requestStun = self.Callbacks.RequestStun
	if requestStun then
		requestStun(stunTime)
	end
end

function AITypeHandler:Play(name: string, speed: number?, fadeTime: number?, weight: number?, restartIfPlaying: boolean?)
	local track = self.Tracks[name]
	if not track then
		return
	end

	if track.IsPlaying then
		AnimationModule.setSpeed(track, speed or 1)

		if restartIfPlaying then
			track:Stop(0.05)
			track:Play(fadeTime or 0.1, weight or 1)
			AnimationModule.setSpeed(track, speed or 1)
		end

		return
	end

	track:Play(fadeTime or 0.1, weight or 1)
	AnimationModule.setSpeed(track, speed or 1)
end


function AITypeHandler:StopAll(fadeTime: number?, includeIdle: boolean?)
	for _, track in ipairs(self.Tracks) do
		if not includeIdle and track.Name == "Idle" then
			continue
		end

		track:Stop(fadeTime or 0.1)
	end

	self.SSM.StunAnimation:Stop(fadeTime or 0.1)
end

function AITypeHandler:IsPlaying(name: string): boolean
	local track = self.Tracks[name]
	return track ~= nil and track.IsPlaying
end

function AITypeHandler:PlaySound(name: string)
	local id = self.SoundData[name]
	if not id then
		return
	end

	ReplicatedStorage.Events.SoundEvent:FireAllClients(id, 1, 1, self.Root)
end

function AITypeHandler:GetFlatDirection(fromPos: Vector3, toPos: Vector3): Vector3
	local flat = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
	if flat.Magnitude <= 0.001 then
		return Vector3.zero
	end

	return flat.Unit
end


function AITypeHandler:SafeWait(waitTime: number,   ignoreStun :boolean): boolean
	local startTime = os.clock()

	while os.clock() - startTime < waitTime do
		if self.Destroyed then
			return false
		end

		if self:IsActionLocked(true, ignoreStun) then
			return false
		end

		RunService.Heartbeat:Wait()
	end

	return true
end

function AITypeHandler:WaitForHit(track: AnimationTrack, hitTime: number?): boolean
	if hitTime then
		task.wait(hitTime)
		return track.IsPlaying
	end

	local thread = coroutine.running()
	local reached = false
	local finished = false

	local hitConnection
	local stoppedConnection

	hitConnection = track:GetMarkerReachedSignal("hit"):Connect(function()
		if finished then
			return
		end

		reached = true
		finished = true

		if hitConnection then
			hitConnection:Disconnect()
		end

		if stoppedConnection then
			stoppedConnection:Disconnect()
		end

		task.spawn(thread)
	end)

	stoppedConnection = track.Stopped:Connect(function()
		if finished then
			return
		end

		finished = true

		if hitConnection then
			hitConnection:Disconnect()
		end

		if stoppedConnection then
			stoppedConnection:Disconnect()
		end

		task.spawn(thread)
	end)

	coroutine.yield()

	return reached
end


-- if updatetick is false then doesn't update it duhh
function AITypeHandler:MakeTick(name :string, updateTick :boolean)
	if self.CustomTicks[name] then
		if updateTick then
			self.CustomTicks[name] = tick()
		end

		return self.CustomTicks[name]
	end

	self.CustomTicks[name] = tick()
	return self.CustomTicks[name]
end

function AITypeHandler:ResolveHit(damage: number, isHeavy: boolean)

	local hits = Combat.resolveHitbox(self.Model, self.Root, self.Data.SwingHitbox)

	for _, hit in ipairs(hits) do
		
		if hit.Humanoid and hit.Humanoid.Health > 0 then
			local parryCheck = ReplicatedStorage.Events.Check:Invoke(hit.Humanoid.Parent)

			if parryCheck then
				
				self:RequestStun(self.Data.RecoveryTime)

				local playerCheck = Players:GetPlayerFromCharacter(hit.Humanoid.Parent)
				if playerCheck then
					local parrySuccessFunction: RemoteFunction = ReplicatedStorage.SSM.ParrySuccessFunction
					parrySuccessFunction:InvokeClient(playerCheck)
				end

				return
			end

			DamageModule.Damage(hit.Humanoid, damage)
			self:PlaySound(isHeavy and "HeavyHitSound" or "LightHitSound")
		end
	end


end

function AITypeHandler:BulletSpread(origin: Vector3, goal: Vector3, spread: number): Vector3
	self.RandomObject = self.RandomObject or Random.new()

	local direction = goal - origin
	if direction.Magnitude <= 0.001 then
		return Vector3.new(0, 0, -1)
	end

	local normalizedDirection = direction.Unit

	local xAngle = math.rad(self.RandomObject:NextNumber(-spread, spread))
	local yAngle = math.rad(self.RandomObject:NextNumber(-spread, spread))

	local lookCFrame = CFrame.lookAt(origin, origin + normalizedDirection)
	local spreadCFrame = lookCFrame * CFrame.Angles(xAngle, yAngle, 0)

	return spreadCFrame.LookVector
end
-- currently used in melee AI framework
function AITypeHandler:TryAttack(ignoreBusy :boolean): boolean
	if not self.TypeModule.TryAttack then
		return false
	end

	return self.TypeModule.TryAttack(self, ignoreBusy)
end

local function canCollide(character :Model)
	for i, v in pairs(character:GetChildren()) do
		if v:IsA("BasePart") then
			v.CanCollide = false
		end
	end
end

function AITypeHandler:OnDie(damage: number)
	if SSM:GetState(self.Model) == "Dead" then
		return false
	end
	
	if self.Destroyed or self.State == "Dead" then
		return false
	end

	if self.OnDeathFunc then
		local newStats = self.OnDeathFunc(self.Model, damage, self.CustomStats)
		if newStats then
			self.CustomStats = newStats
			return false
		end
	end

	if self.IsDead then
		return false
	end

	
	SSM:SetState(self.Model, "Dead")

	-- wrapping a function so it doesn't delay or soetmhing though i could just like wrap that task.wait in
	-- a task.delay i like this method more i guess it might be a bit more expensive but it just feels cleaner to me ngl
	task.spawn(function()
	    
	    self.Tracks.Idle:Stop(0)
	    self.Tracks.Idle:Destroy()
	    self.Tracks.Idle = nil
    
	    self:Cancel()
	    self.State = "Dead"
    
	    self:PlaySound("Death")
    
	    self.Humanoid:MoveTo(self.Root.Position)
	    self.Humanoid.WalkSpeed = 0
    
	    if self.Root then
	    	self.Root.Anchored = true
	    end
    
	    self:StopAll(0, true)
	    self.Tracks.Death:Play(0, 100) -- had to play it directly because it was doing smth weird
	    

	    task.wait(self.Tracks.Death.Length * .985)

	    if self.Destroyed then
		    return false
	    end

	    AnimationModule.setSpeed(self.Tracks.Death, 0)
	    self.IsDead = true

	    self:TransitionState("Dead", true)
		self.FSM:Destroy()

		return
	end)
	
	
	return true
end

-- Type Helper Tools:
-- by types i mean like Gun, Melee AI types


function  AITypeHandler:FaceTarget(targetPart: BasePart)
	local humanoid = self.Model:FindFirstChildOfClass("Humanoid")
	local rootPart = self.Model:FindFirstChild("HumanoidRootPart")
	if not targetPart.Parent then
		return 
	end

	if not humanoid or not rootPart then
		return
	end

	humanoid.AutoRotate = false

	local attachment = rootPart:FindFirstChild("FaceAttachment") or Instance.new("Attachment")
	attachment.Name = "FaceAttachment"
	attachment.Parent = rootPart

	local alignOrientation = rootPart:FindFirstChild("FaceAlign") or Instance.new("AlignOrientation")
	alignOrientation.Name = "FaceAlign"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.Responsiveness = 100
	alignOrientation.MaxTorque = 50000
	alignOrientation.Parent = rootPart
	self:MakeTick("safeCheckTick")
	return RunService.Heartbeat:Connect(function()
		
		if not targetPart.Parent then
			return
		end

		if not self:HasLineOfSight(targetPart) or self:IsStunned() then 
			self:MakeTick("safeCheckTick", true)
			alignOrientation.Enabled = false
            humanoid.AutoRotate = true
		    return
		else
			if tick() - self:MakeTick("safeCheckTick") <= self.Data.ReactionTime then return end
			
			humanoid.AutoRotate = false
            alignOrientation.Enabled = true
	    end

		-- checks the left side of the HRP and see if there is a wall blocking the way i guess
		local ray1 = workspace:Raycast(rootPart.Position + rootPart.CFrame.RightVector * -1, rootPart.CFrame.LookVector * 2, ignorePlayersParams)
		-- checks the right side of the HRP
		local ray2 = workspace:Raycast(rootPart.Position + rootPart.CFrame.RightVector * 1, rootPart.CFrame.LookVector * 2, ignorePlayersParams)
		if ray1 then -- when stuck on a wall it will try to set them slightly into the right position so people just dont softlock them lol olol ol
			self.Model:PivotTo(rootPart.CFrame * CFrame.new(0.01, 0, 0))
		elseif ray2 then
			self.Model:PivotTo(rootPart.CFrame * CFrame.new(-0.01, 0, 0))
		end


		local rootPosition = rootPart.Position
		local targetPosition = targetPart.Position
		local flatTarget = Vector3.new(targetPosition.X, rootPosition.Y, targetPosition.Z)

		alignOrientation.CFrame = CFrame.lookAt(rootPosition, flatTarget)
	end)
end

return AITypeHandler
