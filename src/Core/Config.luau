local Config = {}

Config.Y_LEVEL_THRESHOLD    = 2
Config.MAX_RAY_DISTANCE     = 60
Config.FLAT_GROUND_RAY_FREQ = 3
Config.FLAT_GROUND_RAY_SIZE = -3.1
Config.FLAT_GROUND_ESTIMATE = 5

Config.PATHFIND_PARAMS = {
	AgentRadius     = 2,
	AgentHeight     = 5,
	AgentCanJump    = false,
	AgentCanClimb   = true,
	WaypointSpacing = 4,
	Costs           = {},
}

Config.WAYPOINT_REACH_DIST = 6
Config.PATH_SHARE_RANGE    = 5.5
Config.PATH_SHARE_TTL      = 4
Config.STUCK_TIME          = 3
Config.STUCK_THRESHOLD     = 1.5
Config.TURN_LERP_ALPHA     = 0.15
Config.NAV_TICK            = 0.05

Config.DEFAULT_DEATH_ANIM  = "rbxassetid://104106768287672"
Config.DEFAULT_DEATH_SOUND = "rbxassetid://100109664701398"
Config.DEFAULT_STUN_ANIM   = "rbxassetid://125245253560996"

return Config
