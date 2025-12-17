local Constants = {}

-- SCREEN DIMENSIONS
Constants.SCREEN_WIDTH = 1080
Constants.SCREEN_HEIGHT = 1920
Constants.PLAYFIELD_WIDTH = 720
Constants.PLAYFIELD_HEIGHT = 1280
Constants.OFFSET_X = (Constants.SCREEN_WIDTH - Constants.PLAYFIELD_WIDTH) / 2
Constants.OFFSET_Y = (Constants.SCREEN_HEIGHT - Constants.PLAYFIELD_HEIGHT) / 2

-- PHYSICS CATEGORIES
Constants.PHYSICS = {
    WALL = 1,
    UNIT = 2,
    PUCK = 3,
    SENSOR = 4,
    ZONE = 5 
}

-- UNIT STATS
Constants.UNIT_RADIUS = 7.5         
Constants.UNIT_HP = 5               
Constants.UNIT_SPEED_NEUTRAL = 50   
Constants.UNIT_SPEED_SEEK = 80      
Constants.UNIT_BURST_SPEED = 600    
Constants.UNIT_DAMPING = 1.5        
Constants.UNIT_ENRAGE_DURATION = 7.0 

-- TOXIC FIELDS
Constants.TOXIC_RADIUS = 60      
Constants.TOXIC_DURATION = 8.0   
Constants.TOXIC_FEAR_FORCE = 1500 

-- WEAPON UPGRADES
Constants.UPGRADE_SCORE = 1000           -- Score needed to upgrade

-- DYNAMIC STATS (These start weak and get updated by main.lua)
Constants.EXPLOSION_RADIUS = 50          -- [CHANGED] Starts small
Constants.PUCK_LIFETIME = 0.6            -- [NEW] Short range (0.6s * 800px/s = ~480px range)

Constants.EXPLOSION_RADIUS_MAX = 100     -- Upgraded Size
Constants.PUCK_LIFETIME_MAX = 4.0        -- Upgraded Range (Fence capability)

Constants.EXPLOSION_DURATION = 2.5 
Constants.EXPLOSION_ATTRACTION_RADIUS = 300 

-- ENGAGEMENT & SCORE
Constants.ENGAGEMENT_MAX = 100
Constants.ENGAGEMENT_DECAY_BASE = 5 
Constants.ENGAGEMENT_REFILL_HIT = 2 
Constants.ENGAGEMENT_REFILL_KILL = 10 
Constants.SCORE_HIT = 10
Constants.SCORE_KILL = 100

-- Add these to src/constants.lua

Constants.BOMB_RANGE_START = 300    -- Short range for early game
Constants.BOMB_RANGE_MAX = 900      -- Long range after upgrade

-- COLORS
Constants.COLORS = {
    GREY = {0.7, 0.7, 0.7, 1},
    RED = {1, 0.2, 0.2, 1},
    BLUE = {0.2, 0.2, 1, 1},
    BACKGROUND = {0.1, 0.1, 0.12, 1},
    TOXIC = {0.2, 0.8, 0.2} 
}

return Constants