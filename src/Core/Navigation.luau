local Navigation = {}

local PathfindingService = game:GetService("PathfindingService")
local Config = require(script.Parent.Config)

local function MakeRayParams(excludeModel: Model): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { excludeModel }
	return params
end

local function HitBelongsToTarget(hitInstance: Instance, targetRoot: BasePart): boolean
	local hitModel = hitInstance:FindFirstAncestorOfClass("Model")
	return hitModel ~= nil and targetRoot:IsDescendantOf(hitModel)
end

local function IsTargetGrounded(targetRoot: BasePart, params: RaycastParams): boolean
	local groundHit = workspace:Raycast(
		targetRoot.Position,
		Vector3.new(0, Config.FLAT_GROUND_RAY_SIZE, 0),
		params
	)

	return groundHit ~= nil
end

local function HasFlatGroundLOS(aiPos: Vector3, targetPos: Vector3, params: RaycastParams): boolean
	local flatGoal = Vector3.new(targetPos.X, aiPos.Y, targetPos.Z)
	local flatDir = flatGoal - aiPos
	local flatDistance = flatDir.Magnitude

	if flatDistance > Config.MAX_RAY_DISTANCE then
		return false
	end

	if flatDistance == 0 then
		return true
	end

	local directionUnit = flatDir.Unit
	local checked = 0

	while checked < flatDistance do
		local remaining = flatDistance - checked

		if remaining <= Config.FLAT_GROUND_ESTIMATE then
			break
		end

		local samplePoint = aiPos + directionUnit * checked
		local groundHit = workspace:Raycast(
			samplePoint,
			Vector3.new(0, Config.FLAT_GROUND_RAY_SIZE, 0),
			params
		)

		if not groundHit then
			return false
		end

		checked += Config.FLAT_GROUND_RAY_FREQ
	end

	return true
end

function Navigation.getLOSResult(aiModel: Model, aiRoot: BasePart, targetRoot: BasePart): string
	local aiPos = aiRoot.Position
	local targetPos = targetRoot.Position
	local params = MakeRayParams(aiModel)

	local yDifference = targetPos.Y - aiPos.Y
	local yDifferenceAbs = math.abs(yDifference)

	local toTarget = targetPos - aiPos
	local targetDistance = toTarget.Magnitude

	if targetDistance == 0 then
		return "direct"
	end

	local rayDistance = math.min(targetDistance, Config.MAX_RAY_DISTANCE)
	local rayResult = workspace:Raycast(aiPos, toTarget.Unit * rayDistance, params)

	if not rayResult then
		return "pathfind"
	end

	if not HitBelongsToTarget(rayResult.Instance, targetRoot) then
		return "pathfind"
	end

	if yDifference > Config.Y_LEVEL_THRESHOLD then
		if not IsTargetGrounded(targetRoot, params) then
			return "pathfind"
		end

		return "below"
	end

	if yDifference >= -0.05 and yDifferenceAbs <= Config.Y_LEVEL_THRESHOLD then
		if HasFlatGroundLOS(aiPos, targetPos, params) then
			return "direct"
		end

		return "pathfind"
	end

	if yDifference < -0.05 then
		return "below"
	end

	return "pathfind"
end

function Navigation.computePath(aiRoot: BasePart, targetPos: Vector3): { PathWaypoint }?
	local path = PathfindingService:CreatePath(Config.PATHFIND_PARAMS)
	local ok = pcall(path.ComputeAsync, path, aiRoot.Position, targetPos)

	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	return path:GetWaypoints()
end

return Navigation