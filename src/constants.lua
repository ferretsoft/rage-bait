local Constants = {}

-- === SCREEN & WORLD ===
Constants.SCREEN_WIDTH = 1080
Constants.SCREEN_HEIGHT = 1920
Constants.PLAYFIELD_WIDTH = 720
Constants.PLAYFIELD_HEIGHT = 1280

-- Calculated Centers (Do not change)
Constants.OFFSET_X = (Constants.SCREEN_WIDTH - Constants.PLAYFIELD_WIDTH) / 2
Constants.OFFSET_Y = (Constants.SCREEN_HEIGHT - Constants.PLAYFIELD_HEIGHT) / 2 + 30

-- === PHYSICS CATEGORIES ===
Constants.PHYSICS = {
    WALL = 1,
    UNIT = 2,
    PUCK = 3,
    SENSOR = 4,
    ZONE = 5,
    POWERUP = 6,
    BUMPER = 7
}

-- === UNIT STATS ===
Constants.UNIT_RADIUS = 9.375  -- 7.5 * 1.25 (25% larger)
Constants.UNIT_HP = 5
Constants.UNIT_SPEED_NEUTRAL = 50
Constants.UNIT_SPEED_SEEK = 80
Constants.UNIT_BURST_SPEED = 600
Constants.UNIT_DAMPING = 1.5
Constants.UNIT_ENRAGE_DURATION = 7.0 

-- === TOXIC HAZARDS ===
Constants.TOXIC_RADIUS = 60
Constants.TOXIC_DURATION = 8.0
Constants.TOXIC_FEAR_FORCE = 1500

-- === GAME PROGRESSION ===
Constants.UPGRADE_SCORE = 1000

-- === POWERUPS ===
Constants.POWERUP_RADIUS = 20
Constants.POWERUP_DURATION = 8.0 
Constants.POWERUP_SPEED = 100

-- === BUMPERS ===
Constants.BUMPER_WIDTH = 48
Constants.BUMPER_HEIGHT = 229
Constants.BUMPER_CORNER_RADIUS = 15
Constants.BUMPER_FORCE = 400
Constants.BUMPER_RESTITUTION = 1.2
Constants.BUMPER_ACTIVATION_WINDOW = 10.0  -- Time to fire on bumpers after powerup
Constants.BUMPER_ACTIVE_DURATION = 10.0   -- How long bumpers stay active
Constants.BUMPER_FORCEFIELD_RADIUS = 200   -- Radius of attraction around active bumpers
Constants.BUMPER_CENTER_FORCE = 75       -- Force pushing towards center
Constants.BUMPER_CENTER_FORCEFIELD_DURATION = 1.5  -- Duration of one-time forcefield

-- === WEAPON: BOMB ===
-- The Area of Effect (AoE) is always large.
Constants.EXPLOSION_RADIUS = 80 
Constants.EXPLOSION_DURATION = 2.5
-- The "Suction" range for units.
Constants.EXPLOSION_ATTRACTION_RADIUS = 300 

-- Throwing Range (Changes with Upgrade)
Constants.BOMB_RANGE_BASE = 600 
Constants.BOMB_RANGE_MAX = 900

-- === WEAPON: PUCK ===
-- Always shoots full screen (Speed 800 * 4.0s = 3200px)
Constants.PUCK_LIFETIME = 4.0
Constants.PUCK_LIFETIME_MAX = 8.0 

-- === ENGAGEMENT & SCORE ===
Constants.ENGAGEMENT_MAX = 100
Constants.ENGAGEMENT_DECAY_BASE = 5 
Constants.ENGAGEMENT_DECAY_RATE = 5 -- Added duplicate just in case logic uses this name
Constants.ENGAGEMENT_REFILL_HIT = 2
Constants.ENGAGEMENT_REFILL_KILL = 10
Constants.SCORE_HIT = 10
Constants.SCORE_KILL = 100

-- === COLORS ===
Constants.COLORS = {
    GREY = {0.7, 0.7, 0.7, 1},
    RED = {1, 0.2, 0.2, 1},
    BLUE = {0.2, 0.2, 1, 1},
    BACKGROUND = {0.1, 0.1, 0.12, 1},
    TOXIC = {0.2, 0.8, 0.2},
    GOLD = {1, 0.8, 0.2, 1}
}

return Constants