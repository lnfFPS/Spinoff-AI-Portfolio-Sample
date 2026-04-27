--!nocheck
-- the core premis of 'ignoreBusy' is that it allows other actions to be commited aka shooting while ignoreBusy is active
-- like if you swing isBusy will be active for the duration of the lightswinginterval if it was a lightswing
-- that would just make the AI stare at you if ignoreBusy wasn't added
-- not the same thing with reloading as it there is no 'reloading' state to track whether an AI is reloading
-- if ignoreBusy was applied to reloading then the AI would just be reloading like 5 times in a row even though its still reloading before that
-- add a reload mechanical state if you want to apply ignoreBusy to it you would have to anyway

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local DamageModule = require(ServerStorage.Modules.DamageModule)
local SSM = require(ReplicatedStorage.Shared.ServerStateMachine)

local Gun = {}

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude


local function GetFirePosition(self): Vector3
	local gunModel = self.Root.Parent:FindFirstChild("Gun")
	if gunModel and gunModel:FindFirstChild("FirePosition") then
		return gunModel.FirePosition.WorldPosition
	end

	return self.Root.Position
end


local function MakeAttachment(position: Vector3): Attachment
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	return attachment
end


function Gun.GetStates(self)
	return {
		Idle = {
			onEnter = function()
				if self.IsDead then
					return
				end

				if self.MechanicalStats.AmmoCount == nil then
					self.MechanicalStats.AmmoCount = self.Data.AmmoAmount
				end

				

				self:MakeTick("ShootIntervalTick")
				self:MakeTick("reactionTime", true)


				-- should stay outside of this but i'll keep it here for now
				task.delay(1, function()
					self:SetMovementState("KeepDistance")
				end)
				

				if self.Tracks.Idle and not self:IsPlaying("Idle") then
					self:Play("Idle", 1, 0.1, 55)
				end
			end,

			onUpdate = function()
				if self.IsDead then
					return
				end

				if self:IsActionLocked() then
					return
				end

				self:AcquireTarget()

				if self.Target then
					self:TransitionState("Chase")
				end
			end,
		},

		Chase = {

			onEnter = function()
				raycastParams.FilterDescendantsInstances = {self.Model}
			end,

			onUpdate = function()
				
				if self.IsDead then 
					return
				end

				if SSM:GetState(self.Model) == "Dead" then
		            return
	            end

				if self:IsActionLocked() then
					return
				end

				self:AcquireTarget()

				if not self.Target then
					self.SeenTarget = nil
					self:TransitionState("Idle")
					return
				end

				local distance = (self.Target.Position - self.Root.Position).Magnitude
				if distance >= self.Data.ShootRange then
					self.SeenTarget = nil
					return
				end

				if not self:HasLineOfSight() then
					self.SeenTarget = nil
					self:MakeTick("reactionTime", true)
					return
				end

				if self.MechanicalStats.FaceTowards then
					self.MechanicalStats.FaceTowards:Disconnect()
					self.MechanicalStats.FaceTowards = nil
				end
				self.MechanicalStats.FaceTowards = self:FaceTarget(self.Target)

				local reactionTimeTick = self:MakeTick("reactionTime")
				
				local elapsed = tick() - reactionTimeTick

				if not self.SeenTarget then
					if elapsed >= self.Data.ReactionTime then
						self.SeenTarget = self.Target
					end
					return
				end

				local needToReload = self:TryAttack(self.Target)

				self:TransitionState("ActionLocked")

				if needToReload == "Reload" then
					self.SeenTarget = nil
					self:MakeTick("reactionTime", true)

					Gun.Reload(self)
					self:TransitionState("Chase")
				end
			end,
		},

		ActionLocked = {
			onUpdate = function()
				if self.IsDead and not self.FSM:Is("Dead") then
					self:TransitionState("Dead", true)
					return
				end

				self:AcquireTarget()

				if not self.Target then
					self:TransitionState("Idle")
					return
				end

				self:TransitionState("Chase")
			end,
		},
	}
end

function Gun:VisualiseBullet(origin: Vector3, hitPosition: Vector3)
	local attachment0 = MakeAttachment(origin)
	local attachment1 = MakeAttachment(hitPosition)

	local beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(Color3.fromHSV(0.16, 0.84, 0.96))
	beam.Width0 = 0.1
	beam.Width1 = 0.1
	beam.Transparency = NumberSequence.new(0.15)
	beam.Brightness = 5
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.FaceCamera = true
	beam.Parent = workspace.Terrain

	Debris:AddItem(attachment0, .1)
	Debris:AddItem(attachment1, .1)
	Debris:AddItem(beam, .054)
end

function Gun.TryAttack(self, ignoreBusy :boolean): boolean
	
	if SSM:GetState(self.Model) == "Dead" then
		return
	end
	
	if self.MechanicalStats.AmmoCount <= 0 then
		return "Reload"
	end

	if self:IsActionLocked(ignoreBusy) then -- for compability
		return false
	end

	
	local lastShotTick = self:MakeTick("ShootIntervalTick")

	if tick() - lastShotTick < self.Data.ShootInterval then
		return false
	end

	self:MakeTick("ShootIntervalTick", true)
	
	if not ignoreBusy then
		self:Cancel() -- systems are interlinked with gun and melee (with rattrick) so putting it here is crucial 
		-- to that the melee can actually deal damage
		self.IsBusy = true
	end

	local origin = GetFirePosition(self)

	ReplicatedStorage.Events.SoundEvent:FireAllClients(self.Data.Sounds.Shoot, 1, 1, self.Root)
	self.MechanicalStats.AmmoCount -= 1
	self:MakeTick("ShootIntervalTick", true)
	self:Play("Shoot")
	

	local bulletRange = self.Data.ShootRange or self.Data.DetectionRange or 500

	for _ = 1, self.Data.PelletAmount do
		if SSM:GetState(self.Model) == "Dead" then
		    return false
	    end
		local direction = self:BulletSpread(origin, self.Target.Position, self.Data.BulletSpread)
		local castDirection = direction * bulletRange
		local result = workspace:Raycast(origin, castDirection, raycastParams)

		if result then
			Gun:VisualiseBullet(origin, result.Position)

			local model = result.Instance:FindFirstAncestorOfClass("Model")
			if model then
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid then
					DamageModule.Damage(humanoid, self.Data.BulletDamage)
				end
			end
		else
			Gun:VisualiseBullet(origin, origin + castDirection)
		end
	end

	if not ignoreBusy then
		self.IsBusy = false
	end

	return true
end

function Gun.Reload(self, ignoreBusy :boolean)
	if SSM:GetState(self.Model) == "Dead" then
		return
	end
	
	if self:IsActionLocked(ignoreBusy) then
		return
	end

	

	if self.MechanicalStats.Reloading then
		return
	
	end

	if self.MechanicalStats.Reloading  == false then
		self.MechanicalStats.Reloading = true
	end

	self.IsBusy = true

	ReplicatedStorage.Events.SoundEvent:FireAllClients(self.Data.Sounds.Reload, 1, 1, self.Root)
	self.Humanoid.WalkSpeed = 5

	local reloadSpeed = self.Data.ReloadSpeed / 100

	self:Play("Reload", reloadSpeed)

	if self.Tracks.Reload then
		self:SafeWait(self.Tracks.Reload.Length / reloadSpeed, true)
	end

	if self.MechanicalStats.Reloading then
		self.MechanicalStats.Reloading = false
	end

	if self:IsActionLocked(true, true) then
		self.Tracks.Reload:Stop()
		return
	end

	self.Humanoid.WalkSpeed = self.Data.WalkSpeed
	self.MechanicalStats.AmmoCount = self.Data.AmmoAmount
	self.IsBusy = false

	return true
end

return Gun