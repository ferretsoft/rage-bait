local Constants = {}

-- === SCREEN & WORLD ===
Constants.SCREEN = {
    WIDTH = 1080,
    HEIGHT = 1920,
    PLAYFIELD_WIDTH = 960,
    PLAYFIELD_HEIGHT = 1280,
    -- Calculated Centers (Do not change)
    OFFSET_X = nil,  -- Calculated below
    OFFSET_Y = nil,  -- Calculated below
}

-- Calculate offsets
Constants.SCREEN.OFFSET_X = (Constants.SCREEN.WIDTH - Constants.SCREEN.PLAYFIELD_WIDTH) / 2
Constants.SCREEN.OFFSET_Y = (Constants.SCREEN.HEIGHT - Constants.SCREEN.PLAYFIELD_HEIGHT) / 2 - 90  -- Moved up 80 more pixels (was -10, now -90)

-- Backward compatibility (keep old names working)
Constants.SCREEN_WIDTH = Constants.SCREEN.WIDTH
Constants.SCREEN_HEIGHT = Constants.SCREEN.HEIGHT
Constants.PLAYFIELD_WIDTH = Constants.SCREEN.PLAYFIELD_WIDTH
Constants.PLAYFIELD_HEIGHT = Constants.SCREEN.PLAYFIELD_HEIGHT
Constants.OFFSET_X = Constants.SCREEN.OFFSET_X
Constants.OFFSET_Y = Constants.SCREEN.OFFSET_Y

-- === PHYSICS CATEGORIES ===
Constants.PHYSICS = {
    WALL = 1,
    UNIT = 2,
    PUCK = 3,
    SENSOR = 4,
    ZONE = 5,
    POWERUP = 6,
    BUMPER = 7,
    WEB = 8
}

-- === UNIT STATS ===
Constants.UNIT = {
    RADIUS = 9.375,  -- 7.5 * 1.25 (25% larger)
    HP = 5,
    SPEED_NEUTRAL = 50,
    SPEED_SEEK = 80,
    BURST_SPEED = 600,
    DAMPING = 1.5,
    ENRAGE_DURATION = 7.0,
}

-- Backward compatibility
Constants.UNIT_RADIUS = Constants.UNIT.RADIUS
Constants.UNIT_HP = Constants.UNIT.HP
Constants.UNIT_SPEED_NEUTRAL = Constants.UNIT.SPEED_NEUTRAL
Constants.UNIT_SPEED_SEEK = Constants.UNIT.SPEED_SEEK
Constants.UNIT_BURST_SPEED = Constants.UNIT.BURST_SPEED
Constants.UNIT_DAMPING = Constants.UNIT.DAMPING
Constants.UNIT_ENRAGE_DURATION = Constants.UNIT.ENRAGE_DURATION

-- === TOXIC HAZARDS ===
Constants.TOXIC = {
    RADIUS = 60,
    DURATION = 8.0,
    FEAR_FORCE = 1500,
    DECAY_MULTIPLIER = 0.5,  -- Each toxic hazard increases decay by 50% (1.0 = 100%, 0.5 = 50%)
    ISOLATION_INSANE_TIME = 10.0,  -- Time in seconds a grey unit must be isolated before going insane
    INSANE_EXPLOSION_RADIUS = 120,  -- Radius of explosion when unit goes insane (larger than normal)
    INSANE_TOXIC_RADIUS = 100,  -- Radius of toxic sludge from insane explosion (larger than normal)
    INSANE_TOXIC_DURATION = 12.0,  -- Duration of toxic sludge from insane explosion (longer than normal)
}

-- Backward compatibility
Constants.TOXIC_RADIUS = Constants.TOXIC.RADIUS
Constants.TOXIC_DURATION = Constants.TOXIC.DURATION
Constants.TOXIC_FEAR_FORCE = Constants.TOXIC.FEAR_FORCE
Constants.TOXIC_DECAY_MULTIPLIER = Constants.TOXIC.DECAY_MULTIPLIER
Constants.ISOLATION_INSANE_TIME = Constants.TOXIC.ISOLATION_INSANE_TIME
Constants.INSANE_EXPLOSION_RADIUS = Constants.TOXIC.INSANE_EXPLOSION_RADIUS
Constants.INSANE_TOXIC_RADIUS = Constants.TOXIC.INSANE_TOXIC_RADIUS
Constants.INSANE_TOXIC_DURATION = Constants.TOXIC.INSANE_TOXIC_DURATION

-- === GAME PROGRESSION ===
Constants.PROGRESSION = {
    UPGRADE_SCORE = 1000,
}

-- Backward compatibility
Constants.UPGRADE_SCORE = Constants.PROGRESSION.UPGRADE_SCORE

-- === POWERUPS ===
Constants.POWERUP = {
    RADIUS = 20,
    DURATION = 8.0,
    SPEED = 100,
}

-- Backward compatibility
Constants.POWERUP_RADIUS = Constants.POWERUP.RADIUS
Constants.POWERUP_DURATION = Constants.POWERUP.DURATION
Constants.POWERUP_SPEED = Constants.POWERUP.SPEED

-- === BUMPERS ===
Constants.BUMPER = {
    WIDTH = 48,
    HEIGHT = 229,
    CORNER_RADIUS = 15,
    FORCE = 400,
    RESTITUTION = 1.2,
    ACTIVATION_WINDOW = 10.0,  -- Time to fire on bumpers after powerup
    ACTIVE_DURATION = 10.0,   -- How long bumpers stay active
    FORCEFIELD_RADIUS = 200,   -- Radius of attraction around active bumpers
    CENTER_FORCE = 75,       -- Force pushing towards center
    CENTER_FORCEFIELD_DURATION = 1.5,  -- Duration of one-time forcefield
}

-- Backward compatibility
Constants.BUMPER_WIDTH = Constants.BUMPER.WIDTH
Constants.BUMPER_HEIGHT = Constants.BUMPER.HEIGHT
Constants.BUMPER_CORNER_RADIUS = Constants.BUMPER.CORNER_RADIUS
Constants.BUMPER_FORCE = Constants.BUMPER.FORCE
Constants.BUMPER_RESTITUTION = Constants.BUMPER.RESTITUTION
Constants.BUMPER_ACTIVATION_WINDOW = Constants.BUMPER.ACTIVATION_WINDOW
Constants.BUMPER_ACTIVE_DURATION = Constants.BUMPER.ACTIVE_DURATION
Constants.BUMPER_FORCEFIELD_RADIUS = Constants.BUMPER.FORCEFIELD_RADIUS
Constants.BUMPER_CENTER_FORCE = Constants.BUMPER.CENTER_FORCE
Constants.BUMPER_CENTER_FORCEFIELD_DURATION = Constants.BUMPER.CENTER_FORCEFIELD_DURATION

-- === WEAPON: BOMB ===
Constants.BOMB = {
    EXPLOSION_RADIUS = 80,  -- The Area of Effect (AoE) is always large
    EXPLOSION_DURATION = 2.5,
    EXPLOSION_ATTRACTION_RADIUS = 300,  -- The "Suction" range for units
    RANGE_BASE = 600,  -- Throwing Range (Changes with Upgrade)
    RANGE_MAX = 900,
}

-- Backward compatibility
Constants.EXPLOSION_RADIUS = Constants.BOMB.EXPLOSION_RADIUS
Constants.EXPLOSION_DURATION = Constants.BOMB.EXPLOSION_DURATION
Constants.EXPLOSION_ATTRACTION_RADIUS = Constants.BOMB.EXPLOSION_ATTRACTION_RADIUS
Constants.BOMB_RANGE_BASE = Constants.BOMB.RANGE_BASE
Constants.BOMB_RANGE_MAX = Constants.BOMB.RANGE_MAX

-- === WEAPON: PUCK ===
Constants.PUCK = {
    LIFETIME = 2.5,  -- Always shoots full screen (Speed 1200 * 2.5s = 3000px)
    LIFETIME_MAX = 8.0,
}

-- Backward compatibility
Constants.PUCK_LIFETIME = Constants.PUCK.LIFETIME
Constants.PUCK_LIFETIME_MAX = Constants.PUCK.LIFETIME_MAX

-- === ENGAGEMENT & SCORE ===
Constants.ENGAGEMENT = {
    MAX = 100,
    DECAY_BASE = 5,
    DECAY_RATE = 5,  -- Added duplicate just in case logic uses this name
    DECAY_LEVEL_MULTIPLIER = 0.15,  -- Each level increases decay by 15%
    REFILL_HIT = 2,
    REFILL_KILL = 10,
}

Constants.SCORE = {
    HIT = 10,
    KILL = 100,
}

-- Backward compatibility
Constants.ENGAGEMENT_MAX = Constants.ENGAGEMENT.MAX
Constants.ENGAGEMENT_DECAY_BASE = Constants.ENGAGEMENT.DECAY_BASE
Constants.ENGAGEMENT_DECAY_RATE = Constants.ENGAGEMENT.DECAY_RATE
Constants.ENGAGEMENT_DECAY_LEVEL_MULTIPLIER = Constants.ENGAGEMENT.DECAY_LEVEL_MULTIPLIER
Constants.ENGAGEMENT_REFILL_HIT = Constants.ENGAGEMENT.REFILL_HIT
Constants.ENGAGEMENT_REFILL_KILL = Constants.ENGAGEMENT.REFILL_KILL
Constants.SCORE_HIT = Constants.SCORE.HIT
Constants.SCORE_KILL = Constants.SCORE.KILL

-- === COLORS ===
Constants.COLORS = {
    GREY = {0.7, 0.7, 0.7, 1},
    RED = {1, 0.2, 0.2, 1},
    BLUE = {0.2, 0.2, 1, 1},
    BACKGROUND = {0.1, 0.1, 0.12, 1},
    TOXIC = {0.2, 0.8, 0.2},
    GOLD = {1, 0.8, 0.2, 1}
}

-- === TIMING & DURATIONS ===
Constants.TIMING = {
    -- Screen transitions
    BOOTING_DURATION = 10.0,
    LOGO_DURATION = 5.75,
    LOGO_BLINK_START = 2.5,
    LOGO_BLINK_DURATION = 0.25,
    INTRO_MUSIC_FADE_DURATION = 3.0,
    INTRO_MUSIC_FADE_TARGET_RATIO = 0.5,  -- 50% of start volume
    
    -- Game over / Life lost
    LIFE_LOST_BANNER_DROP = 120,  -- pixels
    GAME_OVER_BANNER_DROP = 320,  -- pixels
    
    -- Ready sequence (get ready / go!)
    READY_FADE_OUT_DURATION = 0.5,  -- Time to fade out black overlay
    READY_GET_READY_DURATION = 1.5,  -- Time to show "GET READY" text
    READY_GO_DURATION = 0.5,  -- Time to show "GO!" text
    GAME_OVER_WAIT_TIME = 2.0,  -- seconds at dropped banner position
    LIFE_LOST_WAIT_TIME = 5.5,  -- seconds at dropped banner position
    
    -- Auditor sequence
    AUDITOR_PHASE_1_FREEZE = 1.0,  -- seconds
    AUDITOR_PHASE_2_FADE = 2.0,  -- seconds
    AUDITOR_PHASE_3_VERDICT = 3.0,  -- seconds
    AUDITOR_PHASE_4_CRASH = 1.0,  -- seconds
    
    -- Level transitions
    LEVEL_TRANSITION_DURATION = 2.0,
    LEVEL_COMPLETE_SCREEN_DURATION = 5.0,
    WIN_TEXT_DURATION = 5.0,
    
    -- Slow motion
    SLOW_MO_DURATION = 1.5,
    
    -- Banner animation
    BANNER_DROP_DISTANCE = 330,  -- pixels from original position
    BANNER_WAIT_AT_ORIGINAL = 15.0,  -- seconds before re-checking engagement
    BANNER_ABOVE_25_RESET_TIME = 6.0,  -- seconds above 25% before reset
    
    -- Text effects
    RAPID_FIRE_TEXT_DURATION = 3.0,
    GLITCH_TEXT_WRITE_SPEED = 1.5,  -- multiplier for write-on effect
    
    -- Engagement thresholds
    ENGAGEMENT_CRITICAL_THRESHOLD = 0.25,  -- 25%
    ENGAGEMENT_VIGILANT_THRESHOLD = 0.5,  -- 50%
}

-- === UI CONSTANTS ===
Constants.UI = {
    -- Font sizes
    FONT_SMALL = 12,
    FONT_MEDIUM = 14,
    FONT_LARGE = 24,
    FONT_TERMINAL = 32,
    FONT_SPEECH_BUBBLE = 18,
    FONT_MULTIPLIER_GIANT = 80,
    FONT_ANNOUNCEMENT_GIANT = 120,  -- For "2X" and "RAPID FIRE" announcements
    
    -- Window frame dimensions
    TITLE_BAR_HEIGHT = 20,
    BORDER_WIDTH = 3,
    
    -- Webcam window (intro screen)
    WEBCAM_WIDTH = 400,
    WEBCAM_HEIGHT = 300,
    WEBCAM_OFFSET_Y = -50,  -- Offset from center
    
    -- Banner positioning
    BANNER_OVERLAP_OFFSET = 120,  -- Pixels banner overlaps into window
    
    -- Window dimensions
    WINDOW_BACKGROUND_ALPHA = 0.7,  -- Alpha for window content background
    SCORE_WINDOW_WIDTH = 300,
    SCORE_WINDOW_HEIGHT = 80,
    PLOT_WINDOW_WIDTH = 300,
    PLOT_WINDOW_HEIGHT = 200,
    MULTIPLIER_WINDOW_HEIGHT = 60,
    WINDOW_SPACING = 20,  -- Spacing between windows
    WINDOW_OFFSET_X = 20,  -- X offset for windows from playfield edge
    
    -- Spark particle effects
    SPARK_COUNT_MULTIPLIER = 30,  -- Number of sparks for multiplier effect
    SPARK_COUNT_READY = 30,  -- Number of sparks for ready screen
    SPARK_COUNT_LEVEL_COMPLETE = 40,  -- Number of sparks for level complete
    SPARK_SPEED_MIN = 200,  -- Minimum spark speed
    SPARK_SPEED_MAX = 500,  -- Maximum spark speed
    SPARK_SPEED_MIN_LEVEL_COMPLETE = 250,  -- Minimum spark speed for level complete
    SPARK_SPEED_MAX_LEVEL_COMPLETE = 600,  -- Maximum spark speed for level complete
    SPARK_SIZE_MIN = 3,  -- Minimum spark size
    SPARK_SIZE_MAX = 7,  -- Maximum spark size
    SPARK_LIFETIME = 1.0,  -- Spark lifetime in seconds
    SPARK_GRAVITY = 200,  -- Gravity effect on sparks
    SPARK_FADE_RATE_MULTIPLIER = 0.8,  -- Fade rate for multiplier sparks
    SPARK_FADE_RATE_READY = 0.5,  -- Fade rate for ready screen sparks
}

-- === VISUAL EFFECTS ===
Constants.EFFECTS = {
    SCREEN_SHAKE_POWERUP = 1.5,
    SCREEN_SHAKE_INSANE = 2.0,
    GLOW_STRENGTH_NORMAL = 5.25,
    GLOW_STRENGTH_VIDEO_RATIO = 0.75,  -- 75% of normal during video
}

-- === Z-DEPTH (draw order) ===
-- Higher numbers draw on top. All layers use these constants for consistent draw order.
Constants.Z_DEPTH = {
    -- Monitor frame layers (back to front)
    MOUTHPIECE = 100,
    EYELID_NORMAL = 200,  -- Normal position (before MainFrame)
    EYELID_REVERSE = 750,  -- During reverse (just under MainFrame)
    RIGHT_MID_UNDER_PANEL = 300,
    RIGHT_MID_UNDER_PANEL_HIGHLIGHTS = 400,
    LEFT_MID_UNDER_PANEL = 500,
    LEFT_MID_UNDER_PANEL_HIGHLIGHTS = 600,
    MAIN_FRAME = 700,
    BOTTOM_CENTER_PANEL_NORMAL = 800,  -- Normal position (after MainFrame)
    BOTTOM_CENTER_PANEL_REVERSE = 750,  -- During reverse (just under MainFrame)
    LEFT_MID_PANEL = 900,
    RIGHT_MID_PANEL = 1000,
    TOP_PANEL = 1100,
    
    -- Top banner
    TOP_BANNER_NORMAL = 1200,  -- Normal position (before monitor frame)
    TOP_BANNER_ON_TOP = 2000,  -- When banner is on top of everything
    
    -- Animated panels on top (when banner is at down position)
    ANIMATED_PANELS_ON_TOP = 2100,  -- MainFrame, LeftMidPanel, RightMidPanel, TopPanel on top of banner
    
    -- Text overlays
    TEXT_OVERLAYS = 3000,  -- Life lost text, game over text, etc.
    
    -- Godray effect (on top of everything)
    GODRAY = 4000,  -- Godray effect following vigilant layer
}

return Constants