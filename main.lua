                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        local Constants = require("src.constants")
local Event = require("src.core.event")
local Engagement = require("src.core.engagement")
local World = require("src.core.world")
local Time = require("src.core.time")
local Sound = require("src.core.sound")
local EmojiSprites = require("src.core.emoji_sprites")
local Webcam = require("src.core.webcam")
local EngagementPlot = require("src.core.engagement_plot")
local AttractMode = require("src.core.attract_mode")
local DemoMode = require("src.core.demo_mode")
local Unit = require("src.entities.unit")
local Turret = require("src.entities.turret")
local Projectile = require("src.entities.projectile")
local PowerUp = require("src.entities.powerup")
local moonshine = require("libs.moonshine")
-- Set BASE so moonshine can find effects in libs directory
moonshine.BASE = "libs"

Game = {
    units = {},
    projectiles = {},
    powerups = {},
    effects = {}, 
    hazards = {},
    explosionZones = {}, 
    turret = nil,
    score = 0,
    shake = 0,
    logicTimer = 0,
    isUpgraded = false,
    powerupSpawnTimer = 0,
    background = nil,
    foreground = nil,
    logo = nil,  -- Company logo image
    logoBlink = nil,  -- Company logo blink image
    splash = nil,  -- Splash screen image for attract mode
    showBackgroundForeground = false,  -- Toggle for background/foreground layers
    logoMode = true,  -- Start with logo screen
    logoTimer = 0,  -- Timer for logo animation
    logoFanfarePlayed = false,  -- Track if fanfare has been played
    previousLogoTimer = 0,  -- Track previous timer value to detect threshold crossings
    attractMode = false,  -- Attract mode (after logo)
    attractModeTimer = 0,  -- Timer for attract mode animations
    demoMode = false,  -- Demo mode (AI-controlled gameplay with tutorial)
    demoTimer = 0,  -- Timer for demo mode
    demoStep = 1,  -- Current tutorial step
    demoAITimer = 0,  -- Timer for AI actions
    demoTargetUnit = nil,  -- Current target unit for AI
    demoCharging = false,  -- Whether AI is currently charging
    demoActionComplete = false,  -- Whether current step's action is complete
    demoWaitingForMessage = true,  -- Whether waiting for message to be shown
    demoUnitConverted = false,  -- Track if a unit was converted (for verification)
    demoUnitEnraged = false,  -- Track if a unit was enraged (for verification)
    demoUnitsFighting = false,  -- Track if units are fighting (for verification)
    introMode = false,  -- Intro screen mode
    introTimer = 0,  -- Timer for intro screen
    introStep = 1,  -- Current intro step/page
    auditorActive = false,  -- Whether THE AUDITOR sequence is active (final game over only)
    auditorTimer = 0,  -- Timer for THE AUDITOR sequence
    auditorPhase = 1,  -- Current phase of THE AUDITOR sequence (1=freeze, 2=fade, 3=verdict, 4=crash)
    lifeLostAuditorActive = false,  -- Whether life lost auditor screen is active (engagement depleted but lives remain)
    lifeLostAuditorTimer = 0,  -- Timer for life lost auditor screen
    lifeLostAuditorPhase = 1,  -- Current phase of life lost auditor (1=freeze, 2=fade, 3=life lost, 4=restart)
    level = 1,  -- Current level
    levelTransitionTimer = 0,  -- Timer for level transition
    levelTransitionActive = false,  -- Whether level transition is active
    levelCompleteScreenActive = false,  -- Whether level completion screen is active
    levelCompleteScreenTimer = 0,  -- Timer for level completion screen (5 seconds)
    winTextActive = false,  -- Whether win text is showing (before webcam)
    winTextTimer = 0,  -- Timer for win text display (5 seconds)
    slowMoActive = false,  -- Whether slow-motion ramp is active
    slowMoTimer = 0,  -- Timer for slow-motion ramp
    slowMoDuration = 1.5,  -- Duration of slow-motion ramp (1.5 seconds)
    timeScale = 1.0,  -- Current time scale (1.0 = normal, 0.0 = frozen)
    lives = 3,  -- Player lives
    gameOverTimer = 0,  -- Timer for game over screen
    gameOverActive = false,  -- Whether game over screen is active
    pointMultiplier = 1,  -- Current point multiplier (incremental)
    pointMultiplierTimer = 0,  -- Timer for point multiplier (10 seconds)
    pointMultiplierActive = false,  -- Whether point multiplier is active
    pointMultiplierFlashTimer = 0,  -- Timer for flashy text animation
    pointMultiplierTextTimer = 0,  -- Timer for text display (fades out after 3s)
    pointMultiplierSparks = {},  -- Spark particles for multiplier effect
    rapidFireTextTimer = 0,  -- Timer for rapid fire text display (fades out after 3s)
    rapidFireSparks = {},  -- Spark particles for rapid fire effect
    previousEngagementAtMax = false,  -- Track if engagement was at max last frame (prevents retriggering)
    highScores = {},  -- List of high scores {name, score}
    nameEntryActive = false,  -- Whether name entry screen is active
    nameEntryText = "",  -- Current name being entered (array of characters)
    nameEntryCursor = 1,  -- Current cursor position (1-based)
    nameEntryMaxLength = 3,  -- Maximum name length (arcade style, usually 3)
    nameEntryCharSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",  -- Available characters
    nameEntryCharIndex = {},  -- Current character index for each position
    fonts = {
        small = nil,
        medium = nil,
        large = nil
    }
}

-- --- HELPER: ACTIVATE POWERUP ---
local function collectPowerUp(powerup)
    if powerup.isDead then return end
    local px, py = powerup.body:getPosition()
    powerup:hit() -- Destroy powerup entity
    
    if powerup.powerupType == "puck" then
        -- Puck mode powerup
        if Game.turret then
            Game.turret:activatePuckMode(Constants.POWERUP_DURATION)
            
            -- Activate rapid fire text effect
            Game.rapidFireTextTimer = 3.0  -- Text display duration (3 seconds before fade)
            Game.shake = math.max(Game.shake, 1.5)  -- Screen shake
            
            -- Create spark particles for the rapid fire effect
            Game.rapidFireSparks = {}
            local centerX = Constants.SCREEN_WIDTH / 2
            local centerY = Constants.SCREEN_HEIGHT / 2 - 100
            local numSparks = 30  -- Number of sparks
            for i = 1, numSparks do
                local angle = (i / numSparks) * math.pi * 2
                local speed = 200 + math.random() * 300  -- Random speed between 200-500
                table.insert(Game.rapidFireSparks, {
                    x = centerX,
                    y = centerY,
                    vx = math.cos(angle) * speed,
                    vy = math.sin(angle) * speed,
                    life = 1.0,  -- Full life
                    maxLife = 1.0,
                    size = 3 + math.random() * 4  -- Random size between 3-7
                })
            end
            
            -- Visual effect (Gold Explosion)
            table.insert(Game.effects, {
                type = "explosion",
                x = px, y = py,
                radius = 0, maxRadius = 100,
                color = "gold", alpha = 1.0, timer = 0.5
            })
            
            -- Sound effect
            Sound.powerupCollect("puck")
            Webcam.showComment("powerup_collected")
            Webcam.showComment("powerup_collected")
        end
    end
end

-- --- PHYSICS COLLISION CALLBACKS ---

local function beginContact(a, b, coll)
    local objA = a:getUserData()
    local objB = b:getUserData()
    if not objA or not objB then return end

    -- CASE 1: UNIT vs UNIT (Bouncing & Damage)
    if objA.type == "unit" and objB.type == "unit" then
        if objA.state == "neutral" or objB.state == "neutral" then return end
        if objA.alignment == objB.alignment then return end
        
        objA:takeDamage(1, objB); objB:takeDamage(1, objA)
        Game.score = Game.score + (Constants.SCORE_HIT * 2 * Game.pointMultiplier)
        Engagement.add(Constants.ENGAGEMENT_REFILL_HIT * 2)
        Sound.unitHit()
        
        local vxA, vyA = objA.body:getLinearVelocity()
        local vxB, vyB = objB.body:getLinearVelocity()
        local speedA = math.sqrt(vxA^2 + vyA^2)
        local speedB = math.sqrt(vxB^2 + vyB^2)
        if speedA > speedB + 150 then objA.body:setLinearVelocity(-vxA*0.3, -vyA*0.3)
        elseif speedB > speedA + 150 then objB.body:setLinearVelocity(-vxB*0.3, -vyB*0.3) end
        return
    end
    
    -- CASE 2: PROJECTILE vs UNIT
    local unit, proj
    if objA.type == "unit" and objB.type == "projectile" then unit = objA; proj = objB
    elseif objB.type == "unit" and objA.type == "projectile" then unit = objB; proj = objA end
    
    if unit and proj then
        if proj.weaponType == "puck" then
            local wasNeutral = unit.state == "neutral"
            unit:hit("puck", proj.color)
            -- Track if a unit was converted from neutral
            if wasNeutral and unit.state == "passive" then
                Game.hasUnitBeenConverted = true
            end
            Sound.unitHit()
            proj:die()
        end
    end
    
    -- CASE 3: PROJECTILE vs POWERUP (Direct Hit)
    local powerup, p2
    if objA.type == "powerup" and objB.type == "projectile" then powerup = objA; p2 = objB
    elseif objB.type == "powerup" and objA.type == "projectile" then powerup = objB; p2 = objA end
    
    if powerup and p2 then
        collectPowerUp(powerup)
        p2:die() -- Destroy the projectile that hit it
    end

    -- [NEW] CASE 4: ZONE (Explosion) vs POWERUP
    local zone, p3
    if objA.type == "powerup" and objB.type == "zone" then p3 = objA; zone = objB
    elseif objB.type == "powerup" and objA.type == "zone" then p3 = objB; zone = objA end
    
    if p3 and zone then
        collectPowerUp(p3)
        -- We do NOT destroy the zone, so it can still damage units
    end
    
end

local function preSolve(a, b, coll)
    local objA = a:getUserData()
    local objB = b:getUserData()
    if not objA or not objB then return end
    
    -- PROJECTILE vs WALL (bottom wall - allow entry from below)
    local wall, proj
    if objA.type == "wall" and objB.type == "projectile" then wall = objA; proj = objB
    elseif objB.type == "wall" and objA.type == "projectile" then wall = objB; proj = objA end
    
    if wall and proj then
        local px, py = proj.body:getPosition()
        local vx, vy = proj.body:getLinearVelocity()
        
        -- Allow projectiles to pass through bottom wall if entering from below
        -- Check if projectile is below playfield and moving upward
        if py > Constants.PLAYFIELD_HEIGHT and vy < 0 then
            -- Projectile is below playfield and moving upward - allow through bottom wall
            coll:setEnabled(false)
            return
        end
    end
    
    -- Zone interactions
    local zone, proj2
    if objA.type == "zone" and objB.type == "projectile" then zone = objA; proj2 = objB
    elseif objB.type == "zone" and objA.type == "projectile" then zone = objB; proj2 = objA end
    
    if zone and proj2 then
        if proj2.weaponType == "bomb" then coll:setEnabled(false)
        else
            if zone.color == proj2.color then coll:setEnabled(false) 
            else coll:setEnabled(true) end
        end
    end
    
    -- Powerup interactions (Ghost physics)
    if objA.type == "powerup" or objB.type == "powerup" then
        coll:setEnabled(false)
    end
end


-- Load high scores from file
function loadHighScores()
    local success, data = pcall(love.filesystem.read, "highscores.txt")
    if success and data then
        local scores = {}
        for line in data:gmatch("[^\r\n]+") do
            local name, score = line:match("([^,]+),([%d]+)")
            if name and score then
                table.insert(scores, {name = name, score = tonumber(score)})
            end
        end
        -- Sort by score descending
        table.sort(scores, function(a, b) return a.score > b.score end)
        Game.highScores = scores
    else
        Game.highScores = {}
    end
end

-- Save high scores to file
function saveHighScores()
    local data = ""
    for i, entry in ipairs(Game.highScores) do
        data = data .. entry.name .. "," .. entry.score .. "\n"
    end
    love.filesystem.write("highscores.txt", data)
end

-- Check if score qualifies as a high score
function isHighScore(score)
    if #Game.highScores < 10 then
        return true  -- Always qualify if less than 10 scores
    end
    return score > Game.highScores[#Game.highScores].score
end

-- Add a high score entry
function addHighScore(name, score)
    table.insert(Game.highScores, {name = name, score = score})
    table.sort(Game.highScores, function(a, b) return a.score > b.score end)
    -- Keep only top 10
    if #Game.highScores > 10 then
        table.remove(Game.highScores, 11)
    end
    saveHighScores()
end

function love.load()
    love.window.setMode(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    love.window.setTitle("RageBait!")
    Game.fonts.small = love.graphics.newFont(12)
    Game.fonts.medium = love.graphics.newFont(14)
    Game.fonts.large = love.graphics.newFont(24)
    
    -- Load high scores
    loadHighScores()
    
    -- Load background image
    local success, img = pcall(love.graphics.newImage, "assets/background.png")
    if success then
        Game.background = img
    else
        Game.background = nil
    end
    
    -- Load foreground image
    local success2, img2 = pcall(love.graphics.newImage, "assets/foreground.png")
    if success2 then
        Game.foreground = img2
    else
        Game.foreground = nil
    end
    
    -- Load company logo
    local success3, img3 = pcall(love.graphics.newImage, "assets/ferretlogo.png")
    if success3 then
        Game.logo = img3
    else
        Game.logo = nil
        print("Warning: Could not load logo: assets/ferretlogo.png")
    end
    
    -- Load company logo blink version
    local success5, img5 = pcall(love.graphics.newImage, "assets/ferretlogo_blink.png")
    if success5 then
        Game.logoBlink = img5
    else
        Game.logoBlink = nil
        print("Warning: Could not load logo blink: assets/ferretlogo_blink.png")
    end
    
    -- Load splash screen image
    local success4, img4 = pcall(love.graphics.newImage, "assets/splash.png")
    if success4 then
        Game.splash = img4
    else
        Game.splash = nil
        print("Warning: Could not load splash: assets/splash.png")
    end
    
    Event.clear(); Engagement.init(); World.init(); Time.init(); Sound.init(); EmojiSprites.init(); Webcam.init(); EngagementPlot.init()
    World.physics:setCallbacks(beginContact, nil, preSolve, nil)
    
    -- Start with logo screen
    Game.logoMode = true
    Game.logoTimer = 0
    Game.previousLogoTimer = 0
    Game.logoFanfarePlayed = false
    Game.attractMode = false
    Game.attractModeTimer = 0
    
    -- Don't initialize game entities until coin is inserted
    Game.turret = nil
    Game.score = 0
    Game.powerupSpawnTimer = 5.0
    
    Game.isUpgraded = false;
    Game.hasUnitBeenConverted = false;
    Game.gameState = "playing";
    Game.winCondition = nil;
    Game.hazards = {}; Game.explosionZones = {}; Game.units = {}; Game.projectiles = {}; Game.effects = {}; Game.powerups = {}
    
    -- Initialize Moonshine CRT effect
    Game.crtEnabled = false
    -- Create CRT effect (moonshine.BASE is already set to "libs")
    local crtEffect = require("libs.crt")(moonshine)
    
    -- Configure CRT appearance parameters:
    -- distortionFactor: Controls barrel distortion/curvature (default: {1.06, 1.065})
    --   Higher values = more curvature. Try {1.1, 1.1} for strong curve, {1.02, 1.02} for subtle
    crtEffect.distortionFactor = {1.02, 1.02}
    
    -- feather: Controls edge feathering/masking (default: 0.02)
    --   Higher values = softer edges. Try 0.05 for softer, 0.01 for sharper
    crtEffect.feather = 0.02  
    
    -- scaleFactor: Controls overall scale (default: 1)
    --   Values < 1 = zoom out, > 1 = zoom in. Usually keep at 1
    crtEffect.scaleFactor = 1
    
    -- scanlineIntensity: Controls scanline visibility (default: 0.3)
    --   Higher values = more visible scanlines (0.0 = off, 1.0 = very strong)
    --   Try 0.5 for strong scanlines, 0.1 for subtle
    crtEffect.scanlineIntensity = 0.3
    
    -- chromaIntensity: Controls chromatic aberration (color separation) (default: 0.5)
    --   Higher values = more color separation. Try 0.8 for strong, 0.2 for subtle
    --   0.0 = no chromatic aberration
    crtEffect.chromaIntensity = 0.3
    
    -- screenSize: Screen dimensions (needed for scanlines)
    crtEffect.screenSize = {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT}
    
    -- Create glow effect
    local glowEffect = require("libs.glow")(moonshine)
    
    -- Configure glow parameters:
    -- min_luma: Minimum brightness threshold (default: 0.7)
    --   Lower values = more things glow. Try 0.3 for more glow, 0.9 for less
    glowEffect.min_luma = 0.65
    
    -- strength: Glow blur radius/intensity (default: 5)
    --   Higher values = stronger blur/glow. Try 10 for strong, 2 for subtle
    glowEffect.strength = 7
    
    -- Create effect chain: glow first, then CRT
    Game.crtChain = moonshine.chain(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, glowEffect)
    Game.crtChain.next(crtEffect)
    
    for i=1, 20 do
        local x = math.random(50, Constants.PLAYFIELD_WIDTH - 50)
        local y = math.random(50, Constants.PLAYFIELD_HEIGHT - 300)
        table.insert(Game.units, Unit.new(World.physics, x, y))
    end
    
    Event.on("bomb_exploded", function(data)
        Time.slowDown(0.1, 0.5); Game.shake = 1.0
        
        -- [NOTE] The radius comes from data.radius, which is set by Constants.EXPLOSION_RADIUS
        -- This ensures the size is constant regardless of throw distance.
        table.insert(Game.effects, {type = "explosion", x = data.x, y = data.y, radius = 0, maxRadius = data.radius, color = data.color, alpha = 1.0, timer = 0.5})
        
        local blocked = false
        for _, z in ipairs(Game.explosionZones) do
            local dx = data.x - z.x; local dy = data.y - z.y
            if (dx*dx + dy*dy) < (z.radius * z.radius) then if z.color ~= data.color then blocked = true break end end
        end
        if blocked then return end
        if #Game.explosionZones >= 5 then local oldZ = table.remove(Game.explosionZones, 1); if oldZ.body then oldZ.body:destroy() end end
        local body = love.physics.newBody(World.physics, data.x, data.y, "static")
        local shape = love.physics.newCircleShape(data.radius)
        local fixture = love.physics.newFixture(body, shape)
        fixture:setCategory(Constants.PHYSICS.ZONE); fixture:setUserData({ type = "zone", color = data.color })
        table.insert(Game.explosionZones, {x = data.x, y = data.y, radius = data.radius, color = data.color, timer = Constants.EXPLOSION_DURATION, body = body})
    end)
    Event.on("unit_killed", function(data)
        Game.score = Game.score + (Constants.SCORE_KILL * Game.pointMultiplier); Engagement.add(Constants.ENGAGEMENT_REFILL_KILL); Game.shake = math.max(Game.shake, 0.2)
        -- Use position from event data (captured before body destruction)
        local x, y = data.x, data.y
        if not x or not y then
            -- Fallback: try to get from body if still available (shouldn't happen)
            if data.victim and data.victim.body then
                x, y = data.victim.body:getPosition()
            else
                return  -- Can't get position, skip
            end
        end
        table.insert(Game.hazards, {x = x, y = y, radius = Constants.TOXIC_RADIUS, timer = Constants.TOXIC_DURATION})
        Webcam.showComment("unit_killed")
    end)
    Event.on("unit_insane_exploded", function(data)
        local x, y = data.x, data.y  -- Use position from event data (captured before body destruction)
        -- Massive explosion effect
        table.insert(Game.effects, {
            type = "explosion",
            x = x, y = y,
            radius = 0,
            maxRadius = Constants.INSANE_EXPLOSION_RADIUS,
            color = "red",  -- Red for insanity
            alpha = 1.0,
            timer = 0.8,  -- Longer explosion animation
            speechBubble = data.speechBubble  -- Preserve speech bubble for drawing
        })
        -- Massive toxic sludge (larger radius and longer duration)
        table.insert(Game.hazards, {
            x = x, y = y,
            radius = Constants.INSANE_TOXIC_RADIUS,
            timer = Constants.INSANE_TOXIC_DURATION
        })
        Game.shake = math.max(Game.shake, 2.0)  -- Strong screen shake
        Webcam.showComment("unit_killed")  -- Use same comment for now
    end)
end

-- Start the game (called when coin is inserted)
function startGame()
    -- Unmute sounds for new game
    Sound.unmute()
    Game.attractMode = false
    Game.attractModeTimer = 0
    
    -- Reset all game over states
    Game.gameOverActive = false
    Game.gameOverTimer = 0
    Game.auditorActive = false
    Game.auditorTimer = 0
    Game.auditorPhase = 1
    Game.nameEntryActive = false
    Game.nameEntryText = ""
    Game.nameEntryCursor = 1
    Game.nameEntryCharIndex = {}
    
    -- Start intro screen instead of immediately starting gameplay
    Game.introMode = true
    Game.introTimer = 0
    Game.introStep = 1
end


-- Actually start gameplay (called after intro screen)
function startGameplay()
    Game.introMode = false
    Game.introTimer = 0
    Game.introStep = 1
    Webcam.showComment("game_start")
    Webcam.showComment("game_start")
    
    -- Start background music
    Sound.playMusic()
    
    -- Reset engagement to starting value (critical - prevents immediate game over)
    Engagement.init()
    
    -- Initialize game entities
    Game.turret = Turret.new()
    Game.score = 0
    Game.powerupSpawnTimer = 5.0
    
    Game.isUpgraded = false
    Game.hasUnitBeenConverted = false
    Game.gameState = "playing"
    Game.winCondition = nil
    Game.level = 1
    Game.levelTransitionTimer = 0
    Game.levelTransitionActive = false
    Game.levelCompleteScreenActive = false
    Game.levelCompleteScreenTimer = 0
    Game.winTextActive = false
    Game.winTextTimer = 0
    Game.slowMoActive = false
    Game.slowMoTimer = 0
    Game.timeScale = 1.0
    Game.lives = 3
    Game.gameOverTimer = 0
    Game.gameOverActive = false
    Game.shouldRestartLevel = false
    Game.auditorActive = false
    Game.auditorTimer = 0
    Game.auditorPhase = 1
    Game.lifeLostAuditorActive = false
    Game.lifeLostAuditorTimer = 0
    Game.lifeLostAuditorPhase = 1
    Game.nameEntryActive = false
    Game.nameEntryText = ""
    Game.nameEntryCursor = 1
    Game.nameEntryCharIndex = {}
    Game.pointMultiplier = 1
    Game.pointMultiplierTimer = 0
    Game.pointMultiplierActive = false
    Game.pointMultiplierFlashTimer = 0
    Game.pointMultiplierTextTimer = 0
    Game.pointMultiplierSparks = {}
    Game.rapidFireTextTimer = 0
    Game.rapidFireSparks = {}
    Game.previousEngagementAtMax = false
    Game.hazards = {}
    Game.explosionZones = {}
    Game.units = {}
    Game.projectiles = {}
    Game.effects = {}
    Game.powerups = {}
    
    -- Spawn initial units
    spawnUnitsForLevel()
end

-- Spawn units for the current level
function spawnUnitsForLevel()
    -- Base number of units, increases with level
    local baseUnits = 20
    local unitsToSpawn = baseUnits + (Game.level - 1) * 5  -- 5 more units per level
    
    for i=1, unitsToSpawn do
        local x = math.random(50, Constants.PLAYFIELD_WIDTH - 50)
        local y = math.random(50, Constants.PLAYFIELD_HEIGHT - 300)
        table.insert(Game.units, Unit.new(World.physics, x, y))
    end
end

-- Advance to the next level
function advanceToNextLevel(winCondition)
    -- Stop turret charging immediately (prevents charge sound from continuing)
    if Game.turret then
        Game.turret.isCharging = false
        Game.turret.chargeTimer = 0
        if Game.turret.chargeSound then
            local success, isPlaying = pcall(function()
                return Game.turret.chargeSound:isPlaying()
            end)
            if success and isPlaying then
                pcall(function()
                    Game.turret.chargeSound:stop()
                    Game.turret.chargeSound:release()
                end)
            end
            Game.turret.chargeSound = nil
        end
    end
    
    -- Clean up all game sounds first (stops all active sounds)
    Sound.cleanup()
    
    -- Unmute sounds so fanfare can play
    Sound.unmute()
    
    -- Play fanfare for victory
    Sound.playFanfare()
    
    -- Start slow-motion ramp to freeze
    Game.slowMoActive = true
    Game.slowMoTimer = 0
    Game.timeScale = 1.0
    Game.winCondition = winCondition
    Game.gameState = "level_complete"
    -- Don't show level complete screen yet - wait for freeze
    Game.levelCompleteScreenActive = false
    Game.levelCompleteScreenTimer = 0
end

-- Handle game over (lose a life)
function handleGameOver(condition)
    -- Stop turret charge sound (but don't stop projectile whistles - let them continue)
    if Game.turret and Game.turret.chargeSound then
        pcall(function()
            Game.turret.chargeSound:stop()
            Game.turret.chargeSound:release()
        end)
        Game.turret.chargeSound = nil
    end
    
    -- Don't call Sound.cleanup() here - it stops ALL sounds including whistle sounds
    -- Let projectiles continue playing their whistle sounds until they explode naturally
    
    -- Check if we have lives remaining BEFORE decrementing
    local hasLivesRemaining = Game.lives > 1  -- Will have lives after decrement if currently > 1
    Game.lives = Game.lives - 1
    
    -- If engagement was depleted and we have lives remaining, show life lost auditor screen
    if condition == "engagement_depleted" and hasLivesRemaining then
        Game.lifeLostAuditorActive = true
        Game.lifeLostAuditorTimer = 0
        Game.lifeLostAuditorPhase = 1  -- Start with system freeze
        Game.gameState = "life_lost_auditor"
        Sound.cleanup()  -- Stop all sounds for the auditor sequence
        return
    end
    
    -- If all lives are lost, show THE AUDITOR (final game over)
    if not hasLivesRemaining then
        Game.auditorActive = true
        Game.auditorTimer = 0
        Game.auditorPhase = 1  -- Start with system freeze
        Game.gameState = "auditor"
        Sound.cleanup()  -- Stop all sounds for THE AUDITOR sequence
        return
    end
    
    -- Normal game over (lose a life, but not engagement depletion)
    Game.gameOverActive = true
    Game.gameOverTimer = 2.0  -- 2 second game over screen
    Game.gameState = "lost"
    Game.winCondition = condition
    -- Store whether we should restart (have lives remaining after this loss)
    Game.shouldRestartLevel = hasLivesRemaining
end

-- Restart the current level after losing a life
-- Note: Score and level are preserved (not reset)
function restartLevel()
    Game.gameOverActive = false
    Game.gameOverTimer = 0
    Game.shouldRestartLevel = false
    Game.auditorActive = false  -- Make sure THE AUDITOR is not active
    Game.auditorTimer = 0
    Game.auditorPhase = 1
    Game.lifeLostAuditorActive = false  -- Make sure life lost auditor is not active
    Game.lifeLostAuditorTimer = 0
    Game.lifeLostAuditorPhase = 1
    Game.gameState = "playing"
    Game.winCondition = nil
    Game.hasUnitBeenConverted = false
    
    -- Unmute sounds so they can play again after restart
    Sound.unmute()
    
    -- Restart background music
    Sound.playMusic()
    
    -- Reset engagement to 100% (same as new level/game start)
    -- Score and level are NOT reset - they are preserved
    Engagement.value = Constants.ENGAGEMENT_MAX
    
    -- Clear all game entities
    for i = #Game.units, 1, -1 do
        local u = Game.units[i]
        if u.body and not u.isDead then
            u.body:destroy()
        end
        table.remove(Game.units, i)
    end
    for i = #Game.projectiles, 1, -1 do
        local p = Game.projectiles[i]
        -- Stop whistle sound before destroying
        if p.whistleSound then
            pcall(function()
                p.whistleSound:stop()
                p.whistleSound:release()
            end)
            p.whistleSound = nil
        end
        if p.body then
            p.body:destroy()
        end
        table.remove(Game.projectiles, i)
    end
    for i = #Game.powerups, 1, -1 do
        local p = Game.powerups[i]
        if p.body then
            p.body:destroy()
        end
        table.remove(Game.powerups, i)
    end
    for i = #Game.explosionZones, 1, -1 do
        local z = Game.explosionZones[i]
        if z.body then
            z.body:destroy()
        end
        table.remove(Game.explosionZones, i)
    end
    Game.hazards = {}
    Game.effects = {}
    
    -- Spawn units for current level
    spawnUnitsForLevel()
end

-- Return to attract mode
function returnToAttractMode()
    Game.logoMode = false
    Game.logoTimer = 0
    Game.previousLogoTimer = 0
    Game.attractMode = true
    Game.attractModeTimer = 0
    Game.gameOverActive = false
    Game.gameOverTimer = 0
    Game.auditorActive = false
    Game.auditorTimer = 0
    Game.auditorPhase = 1
    Game.nameEntryActive = false
    Game.nameEntryText = ""
    Game.nameEntryCursor = 1
    Game.nameEntryCharIndex = {}
    Game.gameState = "attract"
    Game.winCondition = nil
    
    -- Stop all sounds
    Sound.cleanup()
    
    -- Stop turret charge sound if active
    if Game.turret and Game.turret.chargeSound then
        if Game.turret.chargeSound:isPlaying() then
            Game.turret.chargeSound:stop()
            Game.turret.chargeSound:release()
        end
        Game.turret.chargeSound = nil
    end
    
    -- Stop all projectile whistle sounds
    for _, p in ipairs(Game.projectiles) do
        if p.whistleSound and p.whistleSound:isPlaying() then
            p.whistleSound:stop()
            p.whistleSound:release()
        end
        p.whistleSound = nil
    end
    
    -- Clear all game entities
    if Game.turret and Game.turret.body then
        Game.turret.body:destroy()
    end
    Game.turret = nil
    
    for i = #Game.units, 1, -1 do
        local u = Game.units[i]
        if u.body and not u.isDead then
            u.body:destroy()
        end
        table.remove(Game.units, i)
    end
    for i = #Game.projectiles, 1, -1 do
        local p = Game.projectiles[i]
        -- Stop whistle sound before destroying
        if p.whistleSound then
            pcall(function()
                p.whistleSound:stop()
                p.whistleSound:release()
            end)
            p.whistleSound = nil
        end
        if p.body then
            p.body:destroy()
        end
        table.remove(Game.projectiles, i)
    end
    for i = #Game.powerups, 1, -1 do
        local p = Game.powerups[i]
        if p.body then
            p.body:destroy()
        end
        table.remove(Game.powerups, i)
    end
    for i = #Game.explosionZones, 1, -1 do
        local z = Game.explosionZones[i]
        if z.body then
            z.body:destroy()
        end
        table.remove(Game.explosionZones, i)
    end
    Game.hazards = {}
    Game.effects = {}
end

-- Draw logo screen with slide-in animation
function drawLogoScreen()
    love.graphics.clear(0, 0, 0)  -- Black background
    
    if not Game.logo then
        -- Fallback if logo didn't load
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("LOGO", Constants.SCREEN_WIDTH / 2 - 50, Constants.SCREEN_HEIGHT / 2)
        return
    end
    
    local logoWidth = Game.logo:getWidth()
    local logoHeight = Game.logo:getHeight()
    local centerX = Constants.SCREEN_WIDTH / 2
    local centerY = Constants.SCREEN_HEIGHT / 2
    
    -- Calculate scale to fit logo within screen (with some padding)
    local maxWidth = Constants.SCREEN_WIDTH * 0.8  -- 80% of screen width
    local maxHeight = Constants.SCREEN_HEIGHT * 0.8  -- 80% of screen height
    local scaleX = maxWidth / logoWidth
    local scaleY = maxHeight / logoHeight
    local scale = math.min(scaleX, scaleY)  -- Maintain aspect ratio
    
    -- Scaled dimensions for animation calculations
    local scaledWidth = logoWidth * scale
    local scaledHeight = logoHeight * scale
    
    -- Animation phases:
    -- 0-1s: Slide in from left (silently, no sound)
    -- 1-4s: Hold at center (3 seconds)
    -- 4-4.25s: Show blink version (0.25 seconds)
    -- 4.25-7.25s: Show normal version (3 seconds)
    -- 7.25s+: Transition to attract mode
    
    local t = Game.logoTimer
    local x, y = centerX, centerY
    
    -- Phase 1: Slide in (0-1 second) - silently, no sound
    if t < 1.0 then
        local progress = t / 1.0
        -- Ease out cubic for smooth deceleration
        progress = 1 - math.pow(1 - progress, 3)
        x = -scaledWidth + (centerX + scaledWidth) * progress
    end
    
    -- Determine which logo to show (blink or normal)
    local logoToShow = Game.logo
    if Game.logoBlink and t >= 4.0 and t < 4.25 then
        logoToShow = Game.logoBlink
    end
    
    -- Enable alpha blending for compositing
    love.graphics.setBlendMode("alpha")
    
    -- Draw logo with transformations
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(logoToShow, -logoWidth / 2, -logoHeight / 2)
    love.graphics.pop()
    
    -- Reset blend mode
    love.graphics.setBlendMode("alpha")
end


-- Draw intro screen with centered webcam
function drawIntroScreen()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Intro messages (multiple steps) - Chase Paxton's onboarding
    local ChasePaxton = require("src.core.chase_paxton")
    local currentStep = math.min(Game.introStep, #ChasePaxton.INTRO_MESSAGES)
    local currentMessage = ChasePaxton.getIntroMessage(currentStep)
    local stepStartTime = 0
    for i = 1, currentStep - 1 do
        stepStartTime = stepStartTime + ChasePaxton.INTRO_MESSAGES[i].duration
    end
    local stepElapsed = Game.introTimer - stepStartTime
    
    -- Auto-advance steps (except last one which waits for input)
    if currentStep < #ChasePaxton.INTRO_MESSAGES and stepElapsed >= currentMessage.duration then
        Game.introStep = currentStep + 1
    end
    
    -- Draw centered webcam window
    local WEBCAM_WIDTH = 400
    local WEBCAM_HEIGHT = 300
    local WEBCAM_X = (Constants.SCREEN_WIDTH - WEBCAM_WIDTH) / 2
    local WEBCAM_Y = (Constants.SCREEN_HEIGHT - WEBCAM_HEIGHT) / 2 - 50
    
    -- Webcam window frame
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT)
    
    -- Inner border
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", WEBCAM_X + 5, WEBCAM_Y + 5, WEBCAM_WIDTH - 10, WEBCAM_HEIGHT - 10)
    
    -- Draw character (animated)
    local charX = WEBCAM_X + WEBCAM_WIDTH / 2
    local charY = WEBCAM_Y + WEBCAM_HEIGHT / 2 - 40
    
    -- Character head
    love.graphics.setColor(0.9, 0.8, 0.7, 1)
    love.graphics.circle("fill", charX, charY, 50)
    love.graphics.setColor(0.7, 0.6, 0.5, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", charX, charY, 50)
    
    -- Eyes (animated - talking)
    local eyeBlink = math.floor(Game.introTimer * 3) % 2
    local eyeSize = eyeBlink == 0 and 8 or 2
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.circle("fill", charX - 15, charY - 8, eyeSize)
    love.graphics.circle("fill", charX + 15, charY - 8, eyeSize)
    
    -- Mouth (talking animation)
    local mouthOpen = math.floor(Game.introTimer * 4) % 2
    if mouthOpen == 0 then
        -- Open mouth
        love.graphics.setColor(0.3, 0.2, 0.2, 1)
        love.graphics.ellipse("fill", charX, charY + 12, 12, 10)
    else
        -- Closed mouth
        love.graphics.setColor(0.4, 0.3, 0.3, 1)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", charX, charY + 12, 10, 0, math.pi)
    end
    
    -- Draw title
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(1, 1, 0, 1)
    local titleWidth = Game.fonts.large:getWidth(currentMessage.title)
    love.graphics.print(currentMessage.title, WEBCAM_X + (WEBCAM_WIDTH - titleWidth) / 2, WEBCAM_Y + 20)
    
    -- Draw message
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    local lines = {}
    for line in currentMessage.message:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    local lineHeight = Game.fonts.medium:getHeight() + 5
    local startY = WEBCAM_Y + WEBCAM_HEIGHT - 80 - (#lines * lineHeight)
    for i, line in ipairs(lines) do
        local lineWidth = Game.fonts.medium:getWidth(line)
        love.graphics.print(line, WEBCAM_X + (WEBCAM_WIDTH - lineWidth) / 2, startY + (i - 1) * lineHeight)
    end
    
    -- Draw progress indicator (dots)
    local ChasePaxton = require("src.core.chase_paxton")
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    local dotSize = 8
    local dotSpacing = 15
    local totalWidth = (#ChasePaxton.INTRO_MESSAGES - 1) * dotSpacing
    local dotsStartX = WEBCAM_X + (WEBCAM_WIDTH - totalWidth) / 2
    for i = 1, #ChasePaxton.INTRO_MESSAGES - 1 do
        local dotX = dotsStartX + (i - 1) * dotSpacing
        local dotY = WEBCAM_Y + WEBCAM_HEIGHT - 15
        if i < currentStep then
            love.graphics.setColor(1, 1, 1, 1)  -- Completed
        elseif i == currentStep then
            love.graphics.setColor(1, 1, 0, 1)  -- Current
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)  -- Not reached
        end
        love.graphics.circle("fill", dotX, dotY, dotSize)
    end
end

-- Draw life lost auditor screen (engagement depleted but lives remain)
function drawLifeLostAuditor()
    -- Phase 1: System freeze - show frozen game state
    if Game.lifeLostAuditorPhase == 1 then
        -- Draw frozen game state (no updates, but visible)
        love.graphics.clear(Constants.COLORS.BACKGROUND)
        
        -- Draw frozen game elements
        World.draw(function()
            for _, h in ipairs(Game.hazards) do
                local r,g,b = unpack(Constants.COLORS.TOXIC); local a = (h.timer/Constants.TOXIC_DURATION)*0.4
                love.graphics.setColor(r,g,b,a); love.graphics.circle("fill", h.x, h.y, h.radius)
                love.graphics.setColor(r,g,b,a+0.2); love.graphics.setLineWidth(2); love.graphics.circle("line", h.x, h.y, h.radius)
            end
            
            for _, u in ipairs(Game.units) do u:draw() end
            for _, p in ipairs(Game.projectiles) do p:draw() end
            for _, pup in ipairs(Game.powerups) do pup:draw() end
            
            for _, e in ipairs(Game.effects) do
                if e.type == "explosion" then
                    love.graphics.setLineWidth(3)
                    if e.color == "gold" then love.graphics.setColor(1, 0.8, 0.2, e.alpha)
                    elseif e.color == "red" then love.graphics.setColor(1, 0.2, 0.2, e.alpha)
                    else love.graphics.setColor(0.2, 0.2, 1, e.alpha) end
                    love.graphics.circle("line", e.x, e.y, e.radius, 64); love.graphics.setColor(1, 1, 1, e.alpha * 0.2); love.graphics.circle("fill", e.x, e.y, e.radius, 64)
                end
            end
            
            if Game.turret then Game.turret:draw() end
        end)
        
        -- Show webcam with CRITICAL_ERROR
        local Auditor = require("src.core.auditor")
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setFont(Game.fonts.large)
        local errorMsg = Auditor.CRITICAL_ERROR
        local errorWidth = Game.fonts.large:getWidth(errorMsg)
        love.graphics.print(errorMsg, Constants.SCREEN_WIDTH / 2 - errorWidth / 2, Constants.SCREEN_HEIGHT / 2)
        
    -- Phase 2: Fade to black, show THE AUDITOR
    elseif Game.lifeLostAuditorPhase == 2 then
        local fadeProgress = Game.lifeLostAuditorTimer / 2.0
        local fadeAlpha = math.min(fadeProgress, 1.0)
        
        -- Fade to black
        love.graphics.setColor(0, 0, 0, fadeAlpha)
        love.graphics.rectangle("fill", 0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
        
        -- Show THE AUDITOR (hooded figure with red camera lens)
        if fadeAlpha >= 0.5 then
            local auditorAlpha = (fadeAlpha - 0.5) * 2  -- Fade in during second half
            drawAuditorFigure(auditorAlpha)
        end
        
    -- Phase 3: Show "LIFE LOST" message
    elseif Game.lifeLostAuditorPhase == 3 then
        -- Black background
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
        
        -- Draw THE AUDITOR
        drawAuditorFigure(1.0)
        
        -- Show "LIFE LOST" text
        local Auditor = require("src.core.auditor")
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 0, 0, 1)  -- Red text
        
        local lifeLostMsg = Auditor.LIFE_LOST
        local msgWidth = Game.fonts.large:getWidth(lifeLostMsg)
        love.graphics.print(lifeLostMsg, Constants.SCREEN_WIDTH / 2 - msgWidth / 2, Constants.SCREEN_HEIGHT / 2)
        
    -- Phase 4: Transition back to game
    elseif Game.lifeLostAuditorPhase == 4 then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    end
end

-- Draw THE AUDITOR game over sequence
function drawAuditor()
    -- Phase 1: System freeze - show frozen game state
    if Game.auditorPhase == 1 then
        -- Draw frozen game state (no updates, but visible)
        love.graphics.clear(Constants.COLORS.BACKGROUND)
        
        -- Draw frozen game elements
        World.draw(function()
            for _, h in ipairs(Game.hazards) do
                local r,g,b = unpack(Constants.COLORS.TOXIC); local a = (h.timer/Constants.TOXIC_DURATION)*0.4
                love.graphics.setColor(r,g,b,a); love.graphics.circle("fill", h.x, h.y, h.radius)
                love.graphics.setColor(r,g,b,a+0.2); love.graphics.setLineWidth(2); love.graphics.circle("line", h.x, h.y, h.radius)
            end
            
            for _, u in ipairs(Game.units) do u:draw() end
            for _, p in ipairs(Game.projectiles) do p:draw() end
            for _, pup in ipairs(Game.powerups) do pup:draw() end
            
            for _, e in ipairs(Game.effects) do
                if e.type == "explosion" then
                    love.graphics.setLineWidth(3)
                    if e.color == "gold" then love.graphics.setColor(1, 0.8, 0.2, e.alpha)
                    elseif e.color == "red" then love.graphics.setColor(1, 0.2, 0.2, e.alpha)
                    else love.graphics.setColor(0.2, 0.2, 1, e.alpha) end
                    love.graphics.circle("line", e.x, e.y, e.radius, 64); love.graphics.setColor(1, 1, 1, e.alpha * 0.2); love.graphics.circle("fill", e.x, e.y, e.radius, 64)
                end
            end
            
            if Game.turret then Game.turret:draw() end
        end)
        
        -- Show webcam with CRITICAL_ERROR
        local Auditor = require("src.core.auditor")
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setFont(Game.fonts.large)
        local errorMsg = Auditor.CRITICAL_ERROR
        local errorWidth = Game.fonts.large:getWidth(errorMsg)
        love.graphics.print(errorMsg, Constants.SCREEN_WIDTH / 2 - errorWidth / 2, Constants.SCREEN_HEIGHT / 2)
        
    -- Phase 2: Fade to black, show THE AUDITOR
    elseif Game.auditorPhase == 2 then
        local fadeProgress = Game.auditorTimer / 2.0
        local fadeAlpha = math.min(fadeProgress, 1.0)
        
        -- Fade to black
        love.graphics.setColor(0, 0, 0, fadeAlpha)
        love.graphics.rectangle("fill", 0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
        
        -- Show THE AUDITOR (hooded figure with red camera lens)
        if fadeAlpha >= 0.5 then
            local auditorAlpha = (fadeAlpha - 0.5) * 2  -- Fade in during second half
            drawAuditorFigure(auditorAlpha)
        end
        
    -- Phase 3: Show verdict text
    elseif Game.auditorPhase == 3 then
        -- Black background
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
        
        -- Draw THE AUDITOR
        drawAuditorFigure(1.0)
        
        -- Show verdict text
        local Auditor = require("src.core.auditor")
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 0, 0, 1)  -- Red text
        
        local verdict1 = Auditor.VERDICT[1]
        local verdict2 = Auditor.VERDICT[2]
        
        local v1Width = Game.fonts.large:getWidth(verdict1)
        local v2Width = Game.fonts.large:getWidth(verdict2)
        
        love.graphics.print(verdict1, Constants.SCREEN_WIDTH / 2 - v1Width / 2, Constants.SCREEN_HEIGHT / 2 - 50)
        love.graphics.print(verdict2, Constants.SCREEN_WIDTH / 2 - v2Width / 2, Constants.SCREEN_HEIGHT / 2 + 50)
        
    -- Phase 4: Crash to black
    elseif Game.auditorPhase == 4 then
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", 0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    end
end

-- Draw THE AUDITOR figure (hooded figure with red camera lens)
function drawAuditorFigure(alpha)
    local centerX = Constants.SCREEN_WIDTH / 2
    local centerY = Constants.SCREEN_HEIGHT / 2
    
    -- Hood (dark shape)
    love.graphics.setColor(0.1, 0.1, 0.1, alpha)
    love.graphics.ellipse("fill", centerX, centerY - 100, 200, 250)
    
    -- Hood outline
    love.graphics.setColor(0.05, 0.05, 0.05, alpha)
    love.graphics.setLineWidth(3)
    love.graphics.ellipse("line", centerX, centerY - 100, 200, 250)
    
    -- Red camera lens (glowing eye)
    love.graphics.setColor(1, 0, 0, alpha)
    love.graphics.circle("fill", centerX, centerY - 80, 40)
    
    -- Inner glow
    love.graphics.setColor(1, 0.3, 0.3, alpha * 0.6)
    love.graphics.circle("fill", centerX, centerY - 80, 30)
    
    -- Bright center
    love.graphics.setColor(1, 1, 1, alpha * 0.8)
    love.graphics.circle("fill", centerX, centerY - 80, 15)
    
    -- Outer glow ring
    love.graphics.setColor(1, 0, 0, alpha * 0.3)
    love.graphics.setLineWidth(5)
    love.graphics.circle("line", centerX, centerY - 80, 50)
end

-- Draw level completion screen with Chase Paxton
function drawWinTextScreen()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw the game frozen in the background (faded)
    if Game.turret then
        local function drawGameFrozen()
            World.draw(function()
                -- Draw units (frozen)
                for _, u in ipairs(Game.units) do
                    if not u.isDead then
                        u:draw()
                    end
                end
                
                -- Draw projectiles (frozen)
                for _, p in ipairs(Game.projectiles) do
                    if not p.isDead then
                        p:draw()
                    end
                end
                
                -- Draw effects (frozen)
                for _, e in ipairs(Game.effects) do
                    if e.type == "explosion" and e.duration and e.duration > 0 then
                        local t = e.timer / e.duration
                        local alpha = 1.0 - t
                        local radius = e.radius * (1.0 - t * 0.5)
                        love.graphics.setColor(1, 1, 0, alpha * 0.5)
                        love.graphics.circle("fill", e.x, e.y, radius, 32)
                    elseif e.type == "explosion" then
                        -- Fallback if duration is missing - just draw at current state
                        love.graphics.setColor(1, 1, 0, 0.5)
                        love.graphics.circle("fill", e.x, e.y, e.radius or 50, 32)
                    end
                end
                
                -- Draw turret (frozen)
                if Game.turret then
                    Game.turret:draw()
                end
            end)
        end
        
        love.graphics.setColor(1, 1, 1, 0.3)  -- Fade the game
        drawGameFrozen()
        
        -- Add color tint overlay based on win condition
        if Game.winCondition == "blue_only" then
            -- Blue tint overlay
            love.graphics.setColor(0.2, 0.4, 1.0, 0.4)  -- Blue with transparency
            love.graphics.rectangle("fill", Constants.OFFSET_X, Constants.OFFSET_Y, 
                Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT)
        elseif Game.winCondition == "red_only" then
            -- Red tint overlay
            love.graphics.setColor(1.0, 0.2, 0.2, 0.4)  -- Red with transparency
            love.graphics.rectangle("fill", Constants.OFFSET_X, Constants.OFFSET_Y, 
                Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT)
        end
    end
    
    -- Draw win text
    local Popups = require("src.core.popups")
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(0, 1, 0)  -- Green
    local message = Popups.getWinMessage(Game.winCondition)
    local textWidth = Game.fonts.large:getWidth(message)
    love.graphics.print(message, (Constants.SCREEN_WIDTH - textWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
end

function drawLevelCompleteScreen()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw centered, larger webcam window for Chase Paxton
    local WEBCAM_WIDTH = 600
    local WEBCAM_HEIGHT = 450
    local WEBCAM_X = (Constants.SCREEN_WIDTH - WEBCAM_WIDTH) / 2
    local WEBCAM_Y = (Constants.SCREEN_HEIGHT - WEBCAM_HEIGHT) / 2 - 100
    
    -- Webcam window frame
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT)
    
    -- Border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT)
    
    -- Inner border
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", WEBCAM_X + 5, WEBCAM_Y + 5, WEBCAM_WIDTH - 10, WEBCAM_HEIGHT - 10)
    
    -- Draw Chase Paxton character (larger)
    local charX = WEBCAM_X + WEBCAM_WIDTH / 2
    local charY = WEBCAM_Y + WEBCAM_HEIGHT / 2 - 40
    
    -- Character head (larger circle)
    love.graphics.setColor(0.9, 0.8, 0.7, 1)  -- Skin tone
    love.graphics.circle("fill", charX, charY, 80)
    love.graphics.setColor(0.7, 0.6, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.circle("line", charX, charY, 80)
    
    -- Eyes (animated - talking)
    local eyeBlink = math.floor(love.timer.getTime() * 3) % 2
    local eyeSize = eyeBlink == 0 and 12 or 3
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.circle("fill", charX - 20, charY - 10, eyeSize)
    love.graphics.circle("fill", charX + 20, charY - 10, eyeSize)
    
    -- Mouth (talking animation)
    local mouthOpen = math.floor(love.timer.getTime() * 4) % 2
    if mouthOpen == 0 then
        -- Open mouth
        love.graphics.setColor(0.3, 0.2, 0.2, 1)
        love.graphics.ellipse("fill", charX, charY + 20, 18, 15)
    else
        -- Closed mouth (smile)
        love.graphics.setColor(0.4, 0.3, 0.3, 1)
        love.graphics.setLineWidth(3)
        love.graphics.arc("line", "open", charX, charY + 20, 15, 0, math.pi)
    end
    
    -- Draw congratulatory messages (from Chase Paxton dialogue)
    local ChasePaxton = require("src.core.chase_paxton")
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(1, 1, 0, 1)  -- Yellow
    local congratsMsg = ChasePaxton.LEVEL_COMPLETE_MESSAGES[1] or "GREAT JOB!"
    local congratsWidth = Game.fonts.large:getWidth(congratsMsg)
    love.graphics.print(congratsMsg, WEBCAM_X + (WEBCAM_WIDTH - congratsWidth) / 2, WEBCAM_Y + 30)
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    local readyMsg = ChasePaxton.LEVEL_COMPLETE_MESSAGES[2] or "Get ready for the next level!"
    local readyWidth = Game.fonts.medium:getWidth(readyMsg)
    love.graphics.print(readyMsg, WEBCAM_X + (WEBCAM_WIDTH - readyWidth) / 2, WEBCAM_Y + WEBCAM_HEIGHT - 60)
    
    -- Show countdown timer
    local Popups = require("src.core.popups")
    local timeLeft = math.ceil(Game.levelCompleteScreenTimer)
    local timerText = Popups.getStartingIn(timeLeft)
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local timerWidth = Game.fonts.medium:getWidth(timerText)
    love.graphics.print(timerText, WEBCAM_X + (WEBCAM_WIDTH - timerWidth) / 2, WEBCAM_Y + WEBCAM_HEIGHT - 30)
end


function love.update(dt)
    if love.keyboard.isDown("escape") then love.event.quit() end
    
    -- Handle logo screen
    if Game.logoMode then
        Game.previousLogoTimer = Game.logoTimer
        Game.logoTimer = Game.logoTimer + dt
        
        -- Play fanfare exactly when the blink animation starts (at 4.0 seconds)
        -- This happens when the logo image changes to the blink version
        if Game.previousLogoTimer < 4.0 and Game.logoTimer >= 4.0 then
            Sound.playFanfare()
        end
        
        -- After 7.25 seconds (1s slide + 3s wait + 0.25s blink + 3s wait), transition to attract mode
        if Game.logoTimer >= 7.25 then
            Game.logoMode = false
            Game.logoTimer = 0
            Game.previousLogoTimer = 0
            Game.logoFanfarePlayed = false
            Game.attractMode = true
            Game.attractModeTimer = 0
            -- Start playing intro music when transitioning to attract mode
            Sound.playIntroMusic()
        end
        
        return  -- Don't update game logic during logo screen
    end
    
    -- Handle demo mode
    if Game.demoMode then
        DemoMode.update(dt)
        -- Update game normally in demo mode
        -- (AI will control turret, but game logic runs)
    end
    
    -- Handle attract mode
    if Game.attractMode then
        AttractMode.update(dt)
        return  -- Don't update game logic in attract mode
    end
    
    -- Handle intro screen
    if Game.introMode then
        Game.introTimer = Game.introTimer + dt
        return  -- Don't update game logic during intro
    end
    
    -- Handle name entry
    if Game.nameEntryActive then
        return  -- Don't update game logic during name entry
    end
    
    -- Handle life lost auditor screen (engagement depleted but lives remain)
    if Game.lifeLostAuditorActive then
        Game.lifeLostAuditorTimer = Game.lifeLostAuditorTimer + dt
        
        -- Phase 1: System freeze (1 second)
        if Game.lifeLostAuditorPhase == 1 and Game.lifeLostAuditorTimer >= 1.0 then
            Game.lifeLostAuditorPhase = 2
            Game.lifeLostAuditorTimer = 0
        -- Phase 2: Fade to black and show THE AUDITOR (2 seconds)
        elseif Game.lifeLostAuditorPhase == 2 and Game.lifeLostAuditorTimer >= 2.0 then
            Game.lifeLostAuditorPhase = 3
            Game.lifeLostAuditorTimer = 0
        -- Phase 3: Show "LIFE LOST" message (2 seconds)
        elseif Game.lifeLostAuditorPhase == 3 and Game.lifeLostAuditorTimer >= 2.0 then
            Game.lifeLostAuditorPhase = 4
            Game.lifeLostAuditorTimer = 0
        -- Phase 4: Restart level (keep points, same level)
        elseif Game.lifeLostAuditorPhase == 4 and Game.lifeLostAuditorTimer >= 0.5 then
            -- Restart the level, keeping score and level
            Game.lifeLostAuditorActive = false
            Game.lifeLostAuditorTimer = 0
            Game.lifeLostAuditorPhase = 1
            restartLevel()
        end
        
        return  -- Don't update game logic during life lost auditor sequence
    end
    
    -- Handle THE AUDITOR sequence (final game over - all lives lost)
    -- Only process if not in intro mode (safety check)
    if Game.auditorActive and not Game.introMode then
        Game.auditorTimer = Game.auditorTimer + dt
        
        -- Phase 1: System freeze (1 second)
        if Game.auditorPhase == 1 and Game.auditorTimer >= 1.0 then
            Game.auditorPhase = 2
            Game.auditorTimer = 0
        -- Phase 2: Fade to black and show THE AUDITOR (2 seconds)
        elseif Game.auditorPhase == 2 and Game.auditorTimer >= 2.0 then
            Game.auditorPhase = 3
            Game.auditorTimer = 0
        -- Phase 3: Show verdict (3 seconds)
        elseif Game.auditorPhase == 3 and Game.auditorTimer >= 3.0 then
            Game.auditorPhase = 4
            Game.auditorTimer = 0
        -- Phase 4: Crash to black (1 second), then check for high score
        elseif Game.auditorPhase == 4 and Game.auditorTimer >= 1.0 then
            -- Check for high score before returning to attract mode
            if isHighScore(Game.score) then
                -- Start name entry (arcade style)
                Game.auditorActive = false  -- Clear auditor sequence
                Game.auditorTimer = 0
                Game.auditorPhase = 1
                Game.nameEntryActive = true
                Game.nameEntryText = "AAA"  -- Initialize with 'A' in all positions
                Game.nameEntryCursor = 1
                Game.nameEntryCharIndex = {1, 1, 1}  -- Initialize all positions to 'A' (index 1)
            else
                -- No high score, return to attract mode
                returnToAttractMode()
            end
        end
        
        return  -- Don't update game logic during THE AUDITOR sequence
    end
    
    -- Handle game over screen
    if Game.gameOverActive then
        -- Don't stop sounds here - let projectile whistles continue until they explode
        Game.gameOverTimer = Game.gameOverTimer - dt
        if Game.gameOverTimer <= 0 then
            -- Game over screen complete
            if Game.shouldRestartLevel and Game.lives > 0 then
                -- Restart the level (we had lives remaining after losing this one)
                restartLevel()
            elseif Game.lives == 0 then
                -- All lives lost - check for high score
                if isHighScore(Game.score) then
                    -- Start name entry (arcade style)
                    Game.gameOverActive = false  -- Clear game over screen
                    Game.nameEntryActive = true
                    Game.nameEntryText = "AAA"  -- Initialize with 'A' in all positions
                    Game.nameEntryCursor = 1
                    Game.nameEntryCharIndex = {1, 1, 1}  -- Initialize all positions to 'A' (index 1)
                else
                    -- No high score, return to attract mode
                    returnToAttractMode()
                end
            else
                -- Safety fallback: if somehow we have lives but shouldn't restart, restart anyway
                restartLevel()
            end
        end
        
        -- Allow projectiles to continue updating so they can explode and stop sounds naturally
        Time.checkRestore(dt); Time.update(dt); local gameDt = dt * Time.scale
        for i = #Game.projectiles, 1, -1 do 
            local p = Game.projectiles[i]
            p:update(gameDt)
            if p.isDead then 
                table.remove(Game.projectiles, i) 
            end
        end
        
        return  -- Don't update other game logic during game over
    end
    
    -- Handle slow-motion ramp to freeze
    local gameDt = dt
    if Game.slowMoActive then
        Game.slowMoTimer = Game.slowMoTimer + dt
        local progress = math.min(Game.slowMoTimer / Game.slowMoDuration, 1.0)
        -- Ramp from 1.0 to 0.0 (smooth ease-out)
        Game.timeScale = 1.0 - (progress * progress)  -- Quadratic ease-out
        
        -- Apply time scale to game updates during slow-mo
        gameDt = dt * Game.timeScale
        
        -- Update sound system with normal dt (sounds should not be affected by slow-mo)
        Sound.update(dt)
        
        -- When fully frozen, handle differently in demo mode vs normal gameplay
        if Game.timeScale <= 0.0 then
            Game.timeScale = 0.0
            if Game.demoMode and Game.demoStep == 8 then
                -- In demo mode step 8, just freeze - don't show win text
                -- The freeze will be released when step completes
            else
                -- Normal gameplay: show win text
                Game.slowMoActive = false
                Game.winTextActive = true
                Game.winTextTimer = 5.0  -- 5 second pause on win text
                -- Clean up any remaining game sounds when frozen (fanfare should be done by now)
                Sound.cleanup()
                Sound.unmute()  -- Re-enable for any UI sounds
                Sound.update(dt)
                return
            end
        end
    else
        -- Normal time handling
        Time.checkRestore(dt)
        Time.update(dt)
        gameDt = dt * Time.scale
    end
    
    -- Handle win text display (pause before webcam)
    if Game.winTextActive then
        Game.winTextTimer = Game.winTextTimer - dt
        -- Update sound system during win text display
        Sound.update(dt)
        if Game.winTextTimer <= 0 then
            -- Win text done, show webcam screen
            Game.winTextActive = false
            Game.winTextTimer = 0
            Game.levelCompleteScreenActive = true
            Game.levelCompleteScreenTimer = 5.0  -- 5 second completion screen
            Webcam.showComment("level_complete")
        end
        return  -- Don't update game logic during win text display
    end
    
    -- Handle level completion screen (Chase Paxton congratulation)
    if Game.levelCompleteScreenActive then
        Game.levelCompleteScreenTimer = Game.levelCompleteScreenTimer - dt
        -- Update sound system during completion screen
        Sound.update(dt)
        if Game.levelCompleteScreenTimer <= 0 then
            -- Completion screen done, clean up any remaining sounds before transition
            Sound.cleanup()
            Sound.unmute()  -- Re-enable sounds for next level
            -- Proceed to level transition
            Game.levelCompleteScreenActive = false
            Game.levelCompleteScreenTimer = 0
            Game.levelTransitionActive = true
            Game.levelTransitionTimer = 2.0  -- 2 second transition
            Game.timeScale = 1.0  -- Reset time scale
            
            -- Clear all game entities immediately when transition starts
            -- This prevents showing the last frame of the previous level
            for i = #Game.units, 1, -1 do
                local u = Game.units[i]
                if u.body and not u.isDead then
                    u.body:destroy()
                end
                table.remove(Game.units, i)
            end
            -- Stop any remaining projectile whistle sounds before destroying
            for i = #Game.projectiles, 1, -1 do
                local p = Game.projectiles[i]
                if p.whistleSound then
                    pcall(function()
                        p.whistleSound:stop()
                        p.whistleSound:release()
                    end)
                    p.whistleSound = nil
                end
                if p.body then
                    p.body:destroy()
                end
                table.remove(Game.projectiles, i)
            end
            for i = #Game.powerups, 1, -1 do
                local p = Game.powerups[i]
                if p.body then
                    p.body:destroy()
                end
                table.remove(Game.powerups, i)
            end
            for i = #Game.explosionZones, 1, -1 do
                local z = Game.explosionZones[i]
                if z.body then
                    z.body:destroy()
                end
                table.remove(Game.explosionZones, i)
            end
            Game.hazards = {}
            Game.effects = {}
            
            -- Clear multiplier and rapid fire immediately when transition starts
            Game.pointMultiplier = 1
            Game.pointMultiplierTimer = 0
            Game.pointMultiplierActive = false
            Game.pointMultiplierFlashTimer = 0
            Game.pointMultiplierTextTimer = 0
            Game.pointMultiplierSparks = {}
            Game.rapidFireTextTimer = 0
            Game.rapidFireSparks = {}
            
            -- Clear turret rapid fire mode
            if Game.turret then
                Game.turret.puckModeTimer = 0
            end
            
            -- Reset powerup spawn timer
            Game.powerupSpawnTimer = 5.0
        end
        -- Don't update game logic during completion screen (frozen)
        return
    end
    
    -- Handle level transition
    if Game.levelTransitionActive then
        Game.levelTransitionTimer = Game.levelTransitionTimer - dt
        if Game.levelTransitionTimer <= 0 then
            -- Transition complete, start next level
            Game.level = Game.level + 1
            Game.levelTransitionActive = false
            Game.levelTransitionTimer = 0
            Game.gameState = "playing"
            Game.winCondition = nil
            Game.hasUnitBeenConverted = false
            
            -- Reset engagement to 100% for new level
            Engagement.init()
            
            -- Multiplier and rapid fire were already cleared when transition started
            -- Entities were already cleared when transition started
            -- Now spawn new units for next level
            spawnUnitsForLevel()
            
            -- Restart music for new level
            Sound.playMusic()
        end
        return  -- Don't update other game logic during transition
    end
    
    -- Don't spawn powerups in demo mode
    if not Game.demoMode then
        Game.powerupSpawnTimer = Game.powerupSpawnTimer - dt
        if Game.powerupSpawnTimer <= 0 then
            Game.powerupSpawnTimer = math.random(15, 25)
            local px = math.random(50, Constants.PLAYFIELD_WIDTH - 50)
            -- Only spawn puck powerups (bumpers removed)
            table.insert(Game.powerups, PowerUp.new(px, -50, "puck"))
        end
    end

    if not Game.isUpgraded and Game.score >= Constants.UPGRADE_SCORE then
    Game.isUpgraded = true
    -- Only upgrade the Puck Lifetime. The Bomb Radius is already maxed!
    Constants.PUCK_LIFETIME = Constants.PUCK_LIFETIME_MAX
    Game.shake = 2.0
    end
    -- Always update shake decay (even in demo mode) to prevent it from getting stuck
    if Game.shake > 0 then Game.shake = math.max(0, Game.shake - 2.5 * dt) end

    -- Skip main game updates during slow-mo or when game state is not playing
    -- This prevents new sounds from being created during win sequence
    -- Exception: In demo mode, allow updates during slow-mo (for step 7 toxic sludge demo)
    if (Game.slowMoActive or Game.gameState ~= "playing") and not Game.demoMode then
        -- Sound is already updated above during slow-mo handling
        if not Game.slowMoActive then
            Sound.update(dt)
        end
        Webcam.update(dt)
        EngagementPlot.update(dt)
        return  -- Don't update game entities during slow-mo or non-playing states
    end
    
    -- Use gameDt from slow-mo handling (already calculated above)
    -- Normal time handling
    Time.checkRestore(dt)
    Time.update(dt)
    gameDt = dt * Time.scale
    
    -- Calculate toxic hazard count for engagement decay
    local toxicHazardCount = #Game.hazards
    
    -- Don't update engagement decay in demo mode
    if not Game.demoMode then
        Engagement.update(gameDt, toxicHazardCount, Game.level)
    end
    World.update(gameDt); Sound.update(dt); Webcam.update(dt); EngagementPlot.update(dt)
    
    -- Check if engagement ran out (game over)
    -- Only check if we're actually playing and not already in a game over state
    if Game.gameState == "playing" and Engagement.value <= 0 then
        if not Game.gameOverActive and not Game.auditorActive and not Game.lifeLostAuditorActive then
            handleGameOver("engagement_depleted")
            Webcam.showComment("game_over")
        end
    end
    
    -- Check engagement level for comments and point multiplier
    if Game.gameState == "playing" then
        local engagementPct = Engagement.value / Constants.ENGAGEMENT_MAX
        
        -- Check if engagement reached 100% (activate point multiplier)
        -- Only trigger when crossing the threshold from below, not when already at 100%
        -- Skip multipliers in demo mode
        local isAtMax = Engagement.value >= Constants.ENGAGEMENT_MAX
        if isAtMax and not Game.previousEngagementAtMax and not Game.pointMultiplierActive and not Game.demoMode then
            -- Activate point multiplier
            Game.pointMultiplier = Game.pointMultiplier + 1  -- Incremental multiplier
            Game.pointMultiplierActive = true
            Game.pointMultiplierTimer = 10.0  -- 10 seconds
            Game.pointMultiplierFlashTimer = 2.0  -- Flash animation duration (increased for spark effect)
            Game.pointMultiplierTextTimer = 3.0  -- Text display duration (3 seconds before fade)
            Game.shake = math.max(Game.shake, 1.5)  -- Screen shake
            
            -- Create spark particles for the multiplier effect
            Game.pointMultiplierSparks = {}
            local centerX = Constants.SCREEN_WIDTH / 2
            local centerY = Constants.SCREEN_HEIGHT / 2 - 100
            local numSparks = 30  -- Number of sparks
            for i = 1, numSparks do
                local angle = (i / numSparks) * math.pi * 2
                local speed = 200 + math.random() * 300  -- Random speed between 200-500
                table.insert(Game.pointMultiplierSparks, {
                    x = centerX,
                    y = centerY,
                    vx = math.cos(angle) * speed,
                    vy = math.sin(angle) * speed,
                    life = 1.0,  -- Full life
                    maxLife = 1.0,
                    size = 3 + math.random() * 4  -- Random size between 3-7
                })
            end
            
            -- Play sound effect
            Sound.playTone(800, 0.3, 0.8, 1.5)  -- High pitch success sound
            Sound.playTone(600, 0.3, 0.8, 1.2)  -- Second tone for richness
            
            Webcam.showComment("engagement_high")
        end
        
        -- Update tracking flag for next frame
        Game.previousEngagementAtMax = isAtMax
        
        -- Update point multiplier timer (skip in demo mode)
        if Game.pointMultiplierActive and not Game.demoMode then
            Game.pointMultiplierTimer = Game.pointMultiplierTimer - dt
            if Game.pointMultiplierTimer <= 0 then
                -- Timer expired - deactivate multiplier
                Game.pointMultiplierActive = false
                Game.pointMultiplierFlashTimer = 0
                Game.pointMultiplierSparks = {}  -- Clear sparks
                Game.previousEngagementAtMax = false  -- Reset flag to allow re-triggering
            else
                -- Update flash timer
                if Game.pointMultiplierFlashTimer > 0 then
                    Game.pointMultiplierFlashTimer = Game.pointMultiplierFlashTimer - dt
                end
                
                -- Update text timer (fades out after 3 seconds)
                if Game.pointMultiplierTextTimer > 0 then
                    Game.pointMultiplierTextTimer = Game.pointMultiplierTextTimer - dt
                end
                
                -- Update spark particles
                for i = #Game.pointMultiplierSparks, 1, -1 do
                    local spark = Game.pointMultiplierSparks[i]
                    spark.x = spark.x + spark.vx * dt
                    spark.y = spark.y + spark.vy * dt
                    spark.vy = spark.vy + 200 * dt  -- Gravity effect
                    spark.life = spark.life - dt * 0.8  -- Fade out
                    if spark.life <= 0 then
                        table.remove(Game.pointMultiplierSparks, i)
                    end
                end
            end
            -- Note: Multiplier stays active for full duration regardless of engagement level
        end
        
        -- Update rapid fire text timer and sparks
        if Game.rapidFireTextTimer > 0 then
            Game.rapidFireTextTimer = Game.rapidFireTextTimer - dt
            
            -- Update rapid fire spark particles
            for i = #Game.rapidFireSparks, 1, -1 do
                local spark = Game.rapidFireSparks[i]
                spark.x = spark.x + spark.vx * dt
                spark.y = spark.y + spark.vy * dt
                spark.vy = spark.vy + 200 * dt  -- Gravity effect
                spark.life = spark.life - dt * 0.8  -- Fade out
                if spark.life <= 0 then
                    table.remove(Game.rapidFireSparks, i)
                end
            end
        end
        
        if engagementPct < 0.25 and math.random() < 0.01 then  -- 1% chance per frame when low
            Webcam.showComment("engagement_low")
        elseif engagementPct > 0.75 and math.random() < 0.005 then  -- 0.5% chance per frame when high
            Webcam.showComment("engagement_high")
        end
    end
    
    for i = #Game.hazards, 1, -1 do local h = Game.hazards[i]; h.timer = h.timer - dt; if h.timer <= 0 then table.remove(Game.hazards, i) end end
    for i = #Game.explosionZones, 1, -1 do local z = Game.explosionZones[i]; z.timer = z.timer - dt; if z.timer <= 0 then z.body:destroy(); table.remove(Game.explosionZones, i) end end
    for i = #Game.powerups, 1, -1 do local p = Game.powerups[i]; p:update(gameDt); if p.isDead then table.remove(Game.powerups, i) end end

    Game.logicTimer = Game.logicTimer + dt
    if Game.logicTimer > 0.1 then
        Game.logicTimer = 0
        
        -- Check units for explosion zones
        for _, u in ipairs(Game.units) do
            if not u.isDead then
                local ux, uy = u.body:getPosition(); local activeZone = nil
                for _, z in ipairs(Game.explosionZones) do
                    local dx = ux - z.x; local dy = uy - z.y
                    if (dx*dx + dy*dy) < (z.radius * z.radius) then activeZone = z; break end
                end
                if activeZone then 
                    local wasNeutral = u.state == "neutral"
                    u:hit("bomb", activeZone.color)
                    -- Track if a unit was converted from neutral
                    if wasNeutral and u.state == "passive" then
                        Game.hasUnitBeenConverted = true
                    end
                end
            end
        end
    end

    if Game.turret then 
        -- In demo mode, AI controls the turret
        if Game.demoMode then
            DemoMode.updateAI(dt)
        end
        Game.turret:update(dt, Game.projectiles, Game.isUpgraded) 
    end
    
    -- Update units (freeze movement in demo mode to prevent random wandering, except step 4 for enrage demo)
    for i = #Game.units, 1, -1 do 
        local u = Game.units[i]
        if Game.demoMode then
            -- Step 4: Allow full unit updates to show enraged unit attacking
            if Game.demoStep == 4 then
                u:update(gameDt, Game.units, Game.hazards, Game.explosionZones, Game.turret)
            -- In demo mode, freeze unit movement but allow state changes
            elseif not u.isDead then
                -- Freeze unit velocity to prevent wandering
                u.body:setLinearVelocity(0, 0)
                
                -- Update speech bubbles
                if u.speechBubble then
                    u.speechBubble.timer = u.speechBubble.timer + gameDt
                    if u.speechBubble.timer >= u.speechBubble.duration then
                        u.speechBubble = nil
                    end
                end
                if u.groupSpeechBubble then
                    u.groupSpeechBubble.timer = u.groupSpeechBubble.timer + gameDt
                    if u.groupSpeechBubble.timer >= u.groupSpeechBubble.duration then
                        u.groupSpeechBubble = nil
                    end
                end
                
                -- Only update isolation timer for insane units demo steps
                if (Game.demoStep == 6 or Game.demoStep == 8) and u.state == "neutral" then
                    u:checkIsolation(gameDt, Game.units)
                end
                
                -- Check if unit went insane
                if u.isInsane and not u.isDead then
                    u:goInsane()
                end
                
                -- Update enrage timer if enraged
                if u.state == "enraged" then
                    u.enrageTimer = u.enrageTimer - gameDt
                    if u.enrageTimer <= 0 then
                        u.state = "passive"
                    end
                end
            end
        else
            -- Normal gameplay: full unit update
            u:update(gameDt, Game.units, Game.hazards, Game.explosionZones, Game.turret)
        end
        if u.isDead then table.remove(Game.units, i) end 
    end
    for i = #Game.projectiles, 1, -1 do local p = Game.projectiles[i]; p:update(gameDt); if p.isDead then table.remove(Game.projectiles, i) end end
    
    -- Check win conditions (skip in demo mode)
    if Game.gameState == "playing" and not Game.demoMode then
        local blueCount = 0
        local redCount = 0
        local neutralCount = 0
        
        for _, u in ipairs(Game.units) do
            if not u.isDead then
                if u.alignment == "blue" then
                    blueCount = blueCount + 1
                elseif u.alignment == "red" then
                    redCount = redCount + 1
                elseif u.state == "neutral" then
                    neutralCount = neutralCount + 1
                end
            end
        end
        
        local totalUnits = blueCount + redCount + neutralCount
        
        -- Win condition 1: Only blue units left
        if totalUnits > 0 and blueCount > 0 and redCount == 0 and neutralCount == 0 then
            if not Game.levelTransitionActive then
                advanceToNextLevel("blue_only")
            end
        -- Win condition 2: Only red units left
        elseif totalUnits > 0 and redCount > 0 and blueCount == 0 and neutralCount == 0 then
            if not Game.levelTransitionActive then
                advanceToNextLevel("red_only")
            end
        -- Win condition 3: No units left
        elseif totalUnits == 0 then
            if not Game.levelTransitionActive and not Game.gameOverActive then
                handleGameOver("no_units")
            end
        -- Win condition 4: Only neutral units left (grey win condition)
        -- IMPORTANT: This win condition is ONLY active if at least one unit has been converted on this stage
        -- This prevents winning immediately if all units start as neutral and none are converted
        elseif totalUnits > 0 and neutralCount == totalUnits and Game.hasUnitBeenConverted then
            if not Game.levelTransitionActive then
                advanceToNextLevel("neutral_only")
            end
        end
    end
    
    for i = #Game.effects, 1, -1 do
        local e = Game.effects[i]; e.timer = e.timer - dt
        if e.type == "explosion" then
            e.radius = e.radius + (e.maxRadius * 8 * dt); if e.radius > e.maxRadius then e.radius = e.maxRadius end; e.alpha = e.timer / 0.5
            -- Update speech bubble timer if present
            if e.speechBubble then
                e.speechBubble.timer = (e.speechBubble.timer or 0) + dt
            end
        end
        if e.timer <= 0 then table.remove(Game.effects, i) end
    end
end

function love.keypressed(key)
    -- Handle name entry (arcade style)
    if Game.nameEntryActive then
        local charSet = Game.nameEntryCharSet
        local cursor = Game.nameEntryCursor
        local charIndex = Game.nameEntryCharIndex[cursor] or 1
        
        if key == "left" then
            -- Move cursor left
            Game.nameEntryCursor = math.max(1, cursor - 1)
        elseif key == "right" then
            -- Move cursor right
            Game.nameEntryCursor = math.min(Game.nameEntryMaxLength, cursor + 1)
        elseif key == "up" then
            -- Change character up
            charIndex = charIndex + 1
            if charIndex > #charSet then
                charIndex = 1  -- Wrap around
            end
            Game.nameEntryCharIndex[cursor] = charIndex
            -- Update the character at cursor position
            local nameChars = {}
            for i = 1, Game.nameEntryMaxLength do
                local idx = Game.nameEntryCharIndex[i] or 1
                nameChars[i] = charSet:sub(idx, idx)
            end
            Game.nameEntryText = table.concat(nameChars)
        elseif key == "down" then
            -- Change character down
            charIndex = charIndex - 1
            if charIndex < 1 then
                charIndex = #charSet  -- Wrap around
            end
            Game.nameEntryCharIndex[cursor] = charIndex
            -- Update the character at cursor position
            local nameChars = {}
            for i = 1, Game.nameEntryMaxLength do
                local idx = Game.nameEntryCharIndex[i] or 1
                nameChars[i] = charSet:sub(idx, idx)
            end
            Game.nameEntryText = table.concat(nameChars)
        elseif key == "return" or key == "enter" then
            -- Submit name
            local name = Game.nameEntryText:gsub("^%s+", ""):gsub("%s+$", "")  -- Trim whitespace
            if name == "" or name == "AAA" then
                name = "AAA"  -- Default name
            end
            addHighScore(name, Game.score)
            Game.nameEntryActive = false
            Game.nameEntryText = ""
            Game.nameEntryCursor = 1
            Game.nameEntryCharIndex = {}
            returnToAttractMode()
        end
        return
    end
    
    -- Handle coin insertion in attract mode
    if Game.attractMode then
        if key == "space" or key == "return" or key == "enter" then
            startGame()
            return
        elseif key == "d" then
            -- Start demo mode
            DemoMode.start()
            return
        end
    end
    
    -- Handle demo mode input
    if Game.demoMode then
        if DemoMode.keypressed(key) then
            return
        end
    end
    
    -- Handle input during intro screen
    if Game.introMode then
        if key == "space" or key == "return" or key == "enter" then
            -- Skip to gameplay
            startGameplay()
            return
        elseif key == "right" or key == "d" then
            -- Advance to next step
            local ChasePaxton = require("src.core.chase_paxton")
            if Game.introStep < #ChasePaxton.INTRO_MESSAGES then
                Game.introStep = Game.introStep + 1
                -- Reset timer for new step
                local stepStartTime = 0
                for i = 1, Game.introStep - 1 do
                    stepStartTime = stepStartTime + ChasePaxton.INTRO_MESSAGES[i].duration
                end
                Game.introTimer = stepStartTime
            end
            return
        end
    end
    
    -- Toggle CRT shader
    if key == "c" then
        if Game.crtChain then
            Game.crtEnabled = not Game.crtEnabled
        end
        return
    end
    
    -- Toggle background/foreground layers
    if key == "b" then
        Game.showBackgroundForeground = not Game.showBackgroundForeground
        return
    end
    
    if not Game.turret then return end
    -- Don't allow charging if game state is not playing (prevents charging during win sequence)
    if Game.gameState ~= "playing" then return end
    if key == "z" then Game.turret:startCharge("red")
    elseif key == "x" then Game.turret:startCharge("blue")
    elseif key == "2" then
        -- Debug: Give rapid fire powerup
        Game.turret:activatePuckMode(Constants.POWERUP_DURATION)
    end
end

-- Text input disabled for arcade-style name entry (uses arrow keys instead)

function love.keyreleased(key)
    if not Game.turret then return end
    -- Don't allow releasing charge if game state is not playing
    if Game.gameState ~= "playing" then return end
    if key == "z" or key == "x" then Game.turret:releaseCharge(Game.projectiles) end
end

-- Drawing function that will be wrapped by Moonshine if CRT is enabled
function drawGame()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Apply shake transform to everything (background, game, foreground, HUD)
    love.graphics.push()
        if Game.shake > 0 then
            local s = Game.shake * Game.shake * 15; love.graphics.translate(love.math.random(-s, s), love.math.random(-s, s))
        end
        
    -- Draw background image if loaded and enabled (full screen) - now affected by shake
    if Game.showBackgroundForeground and Game.background then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Game.background, 0, 0, 0, 
            Constants.SCREEN_WIDTH / Game.background:getWidth(),
            Constants.SCREEN_HEIGHT / Game.background:getHeight())
    end
    
    World.draw(function()
        for _, h in ipairs(Game.hazards) do
            local r,g,b = unpack(Constants.COLORS.TOXIC); local a = (h.timer/Constants.TOXIC_DURATION)*0.4
            love.graphics.setColor(r,g,b,a); love.graphics.circle("fill", h.x, h.y, h.radius)
            love.graphics.setColor(r,g,b,a+0.2); love.graphics.setLineWidth(2); love.graphics.circle("line", h.x, h.y, h.radius)
        end
        
        if #Game.explosionZones > 0 then
            love.graphics.clear(false, true, false) 
            for _, z in ipairs(Game.explosionZones) do
                love.graphics.setStencilTest("equal", 0)
                if z.color == "red" then love.graphics.setColor(1, 0, 0, 0.3) else love.graphics.setColor(0, 0, 1, 0.3) end
                love.graphics.circle("fill", z.x, z.y, z.radius, 64)
                love.graphics.setLineWidth(3); love.graphics.setColor(1, 1, 1, 0.5); love.graphics.circle("line", z.x, z.y, z.radius, 64)
                love.graphics.setStencilTest(); love.graphics.stencil(function() love.graphics.circle("fill", z.x, z.y, z.radius, 64) end, "replace", 1)
            end
            love.graphics.setStencilTest()
        end
        
        for _, u in ipairs(Game.units) do u:draw() end
        for _, p in ipairs(Game.projectiles) do p:draw() end
        for _, pup in ipairs(Game.powerups) do pup:draw() end
        
        for _, e in ipairs(Game.effects) do
            if e.type == "explosion" then
                love.graphics.setLineWidth(3)
                if e.color == "gold" then love.graphics.setColor(1, 0.8, 0.2, e.alpha)
                elseif e.color == "red" then love.graphics.setColor(1, 0.2, 0.2, e.alpha)
                else love.graphics.setColor(0.2, 0.2, 1, e.alpha) end
                love.graphics.circle("line", e.x, e.y, e.radius, 64); love.graphics.setColor(1, 1, 1, e.alpha * 0.2); love.graphics.circle("fill", e.x, e.y, e.radius, 64)
                
                -- Draw speech bubble if present (for insane units)
                if e.speechBubble and e.speechBubble.text then
                    local bubbleX = e.x
                    local bubbleY = e.y - Constants.UNIT_RADIUS - 40
                    local padding = 10
                    local fontSize = 18  -- Larger font for dialogue
                    local font = love.graphics.newFont(fontSize)
                    
                    local textWidth = font:getWidth(e.speechBubble.text)
                    local textHeight = font:getHeight()
                    local bubbleWidth = textWidth + padding * 2
                    local bubbleHeight = textHeight + padding * 2
                    
                    -- Fade out with explosion (timer is updated in update loop)
                    local bubbleAlpha = math.max(e.alpha, 0.5)  -- Keep it visible even during explosion
                    if e.speechBubble and e.speechBubble.timer and e.speechBubble.duration then
                        if e.speechBubble.timer > e.speechBubble.duration * 0.7 then
                            bubbleAlpha = bubbleAlpha * (1.0 - ((e.speechBubble.timer - e.speechBubble.duration * 0.7) / (e.speechBubble.duration * 0.3)))
                        end
                    end
                    
                    -- Draw speech bubble background (more opaque)
                    love.graphics.setColor(0, 0, 0, bubbleAlpha * 0.9)
                    love.graphics.rectangle("fill", bubbleX - bubbleWidth / 2, bubbleY - bubbleHeight, bubbleWidth, bubbleHeight, 4)
                    
                    -- Draw speech bubble border (brighter)
                    love.graphics.setColor(0.8, 0.8, 0.8, bubbleAlpha)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", bubbleX - bubbleWidth / 2, bubbleY - bubbleHeight, bubbleWidth, bubbleHeight, 4)
                    
                    -- Draw speech bubble tail
                    love.graphics.setColor(0, 0, 0, bubbleAlpha * 0.9)
                    love.graphics.polygon("fill", 
                        bubbleX - 10, bubbleY - 6,
                        bubbleX + 10, bubbleY - 6,
                        bubbleX, bubbleY + 6
                    )
                    love.graphics.setColor(0.8, 0.8, 0.8, bubbleAlpha)
                    love.graphics.setLineWidth(2)
                    love.graphics.polygon("line", 
                        bubbleX - 10, bubbleY - 6,
                        bubbleX + 10, bubbleY - 6,
                        bubbleX, bubbleY + 6
                    )
                    
                    -- Draw text (brighter)
                    love.graphics.setColor(1, 0.5, 0.5, bubbleAlpha)
                    love.graphics.setFont(font)
                    love.graphics.print(e.speechBubble.text, bubbleX - textWidth / 2, bubbleY - bubbleHeight + padding)
                end
            elseif e.type == "forcefield" then
                love.graphics.setLineWidth(4)
                love.graphics.setColor(0.2, 0.6, 1, e.alpha * 0.6)
                love.graphics.circle("line", e.x, e.y, e.radius, 32)
                love.graphics.setColor(0.3, 0.7, 1, e.alpha * 0.3)
                love.graphics.circle("fill", e.x, e.y, e.radius, 32)
            end
        end
        
        if Game.turret then Game.turret:draw() end
    end)
    
    -- Draw foreground image if loaded and enabled (full screen, on top of game elements) - now affected by shake
    if Game.showBackgroundForeground and Game.foreground then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Game.foreground, 0, 0, 0, 
            Constants.SCREEN_WIDTH / Game.foreground:getWidth(),
            Constants.SCREEN_HEIGHT / Game.foreground:getHeight())
    end
    
    -- Draw HUD - now affected by shake and CRT
    drawHUD()
    
    -- Draw webcam window (below playfield, affected by shake)
    Webcam.draw()
    
    -- Draw engagement plot (next to webcam, affected by shake)
    EngagementPlot.draw()
    
    -- Draw multiplier window (below engagement plot) - skip in demo mode
    if not Game.demoMode then
        drawMultiplierWindow()
    end
    
    love.graphics.pop()
    
    -- CRITICAL: Reset color to white before Moonshine processes the canvas
    -- Otherwise, any color set by effects (like gold explosion) will tint the entire screen
    love.graphics.setColor(1, 1, 1, 1)
end

function love.draw()
    -- Helper function to apply CRT shader to any drawing function
    local function drawWithCRT(drawFunc)
        if Game.crtEnabled and Game.crtChain then
            Game.crtChain.draw(drawFunc)
        else
            drawFunc()
        end
    end
    
    -- Draw logo screen (before attract mode)
    if Game.logoMode then
        drawWithCRT(drawLogoScreen)
        return
    end
    
    -- Draw attract mode screen
    if Game.attractMode then
        drawWithCRT(AttractMode.draw)
        return
    end
    
    -- Draw demo mode screen
    if Game.demoMode then
        drawWithCRT(DemoMode.draw)
        return
    end
    
    -- Draw intro screen (check before AUDITOR to prevent showing CRITICAL_ERROR on new game)
    if Game.introMode then
        drawWithCRT(drawIntroScreen)
        return
    end
    
    -- Draw level completion screen (Chase Paxton)
    if Game.winTextActive then
        drawWithCRT(drawWinTextScreen)
        return
    end
    
    if Game.levelCompleteScreenActive then
        drawWithCRT(drawLevelCompleteScreen)
        return
    end
    
    -- Draw life lost auditor screen (engagement depleted but lives remain)
    if Game.lifeLostAuditorActive then
        drawWithCRT(drawLifeLostAuditor)
        return
    end
    
    -- Draw THE AUDITOR sequence (final game over - all lives lost)
    -- Only show if not in intro mode (safety check)
    if Game.auditorActive and not Game.introMode then
        drawWithCRT(drawAuditor)
        return
    end
    
    -- Apply CRT effect if enabled, otherwise draw normally
    drawWithCRT(drawGame)
end

function drawMultiplierWindow()
    -- Multiplier window dimensions and position (below engagement plot)
    local PLOT_WIDTH = 300
    local PLOT_HEIGHT = 200
    local PLOT_X = Constants.OFFSET_X + 20
    local PLOT_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + 20
    
    local MULTIPLIER_WIDTH = PLOT_WIDTH
    local MULTIPLIER_HEIGHT = 60
    local MULTIPLIER_X = PLOT_X
    local MULTIPLIER_Y = PLOT_Y + PLOT_HEIGHT + 10
    
    -- Draw multiplier window frame
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", MULTIPLIER_X, MULTIPLIER_Y, MULTIPLIER_WIDTH, MULTIPLIER_HEIGHT)
    
    -- Draw border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", MULTIPLIER_X, MULTIPLIER_Y, MULTIPLIER_WIDTH, MULTIPLIER_HEIGHT)
    
    -- Draw inner border
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", MULTIPLIER_X + 5, MULTIPLIER_Y + 5, MULTIPLIER_WIDTH - 10, MULTIPLIER_HEIGHT - 10)
    
    if Game.pointMultiplierActive then
        -- Draw multiplier content
        love.graphics.setFont(Game.fonts.medium)
        
        -- Multiplier value with gold/yellow pulsing
        local flash = (math.sin(love.timer.getTime() * 3) + 1) / 2
        love.graphics.setColor(1, 0.8 + flash * 0.2, 0.2, 1)
        local multiplierText = "x" .. Game.pointMultiplier .. " POINT MULTIPLIER"
        local multiplierWidth = Game.fonts.medium:getWidth(multiplierText)
        love.graphics.print(multiplierText, MULTIPLIER_X + (MULTIPLIER_WIDTH - multiplierWidth) / 2, MULTIPLIER_Y + 10)
        
        -- Timer
        love.graphics.setColor(1, 1, 1, 0.9)
        local timerText = math.ceil(Game.pointMultiplierTimer) .. "s remaining"
        local timerWidth = Game.fonts.medium:getWidth(timerText)
        love.graphics.print(timerText, MULTIPLIER_X + (MULTIPLIER_WIDTH - timerWidth) / 2, MULTIPLIER_Y + 35)
    else
        -- Show inactive state
        love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
        love.graphics.setFont(Game.fonts.medium)
        local inactiveText = "MULTIPLIER: INACTIVE"
        local inactiveWidth = Game.fonts.medium:getWidth(inactiveText)
        love.graphics.print(inactiveText, MULTIPLIER_X + (MULTIPLIER_WIDTH - inactiveWidth) / 2, MULTIPLIER_Y + 20)
    end
end

function drawHUD()
    love.graphics.setColor(0, 1, 0); love.graphics.setFont(Game.fonts.medium); love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    
    -- Show CRT status
    if Game.crtEnabled then
        love.graphics.setColor(0.8, 0.8, 0.2)
        love.graphics.print("CRT: ON (Press C to toggle)", 10, 30)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("CRT: OFF (Press C to toggle)", 10, 30)
    end

    local barW, barH = 400, 40; local barX = (Constants.SCREEN_WIDTH - barW)/2; local barY = 80
    local pct = Engagement.value / Constants.ENGAGEMENT_MAX
    love.graphics.setColor(0.2, 0.2, 0.2); love.graphics.rectangle("fill", barX, barY, barW, barH)
    if pct < 0.25 then love.graphics.setColor(1, 0, 0) elseif pct < 0.5 then love.graphics.setColor(1, 1, 0) else love.graphics.setColor(0, 1, 0) end
    love.graphics.rectangle("fill", barX+2, barY+2, (barW-4)*pct, barH-4)
    love.graphics.setColor(1, 1, 1); love.graphics.print("ENGAGEMENT", barX, barY - 20)
    love.graphics.setFont(Game.fonts.large); love.graphics.print("SCORE: " .. Game.score, barX, barY + 50)
    love.graphics.setColor(0.8, 0.8, 0.8); love.graphics.setFont(Game.fonts.medium); love.graphics.print("LEVEL: " .. Game.level, barX, barY - 50)
    love.graphics.setColor(1, 0.2, 0.2); love.graphics.print("LIVES: " .. Game.lives, barX + 300, barY - 50)
    
    if Game.isUpgraded then love.graphics.setColor(1, 1, 0); love.graphics.print("WEAPONS UPGRADED!", barX + 60, barY + 80) end
    
    -- Draw point multiplier announcement (giant flashing "2X" with sparks) - skip in demo mode
    if Game.pointMultiplierActive and not Game.demoMode then
        local centerX = Constants.SCREEN_WIDTH / 2
        local centerY = Constants.SCREEN_HEIGHT / 2 - 100
        
        -- Draw spark particles
        for _, spark in ipairs(Game.pointMultiplierSparks) do
            local alpha = spark.life / spark.maxLife
            -- Gold/yellow sparks with fade
            local sparkColor = 0.3 + (spark.life / spark.maxLife) * 0.7  -- Fade from bright to dim
            love.graphics.setColor(1, 0.8 + sparkColor * 0.2, 0.2, alpha)
            love.graphics.circle("fill", spark.x, spark.y, spark.size)
            -- Add glow effect
            love.graphics.setColor(1, 0.9, 0.3, alpha * 0.3)
            love.graphics.circle("fill", spark.x, spark.y, spark.size * 2)
        end
        
        -- Calculate flash alpha
        local flashAlpha = 1.0
        if Game.pointMultiplierFlashTimer > 0 then
            -- Flash animation during first 2 seconds
            flashAlpha = 0.6 + 0.4 * (math.sin(Game.pointMultiplierFlashTimer * 12) + 1) / 2
        end
        
        -- Create giant font for "2X" text (much larger than large font)
        local giantFontSize = 120
        local giantFont = love.graphics.newFont(giantFontSize)
        love.graphics.setFont(giantFont)
        
        local multiplierText = Game.pointMultiplier .. "X"
        local multiplierWidth = giantFont:getWidth(multiplierText)
        local multiplierX = centerX - multiplierWidth / 2
        local multiplierY = centerY - giantFontSize / 2
        
        -- Flashy colors (gold/yellow pulsing)
        local flash = (math.sin(love.timer.getTime() * 8) + 1) / 2
        local r = 1
        local g = 0.7 + flash * 0.3
        local b = 0.1
        
        -- Draw text with thick outline for visibility
        love.graphics.setLineWidth(8)
        love.graphics.setColor(0, 0, 0, flashAlpha * 0.9)
        for dx = -4, 4, 2 do
            for dy = -4, 4, 2 do
                if dx ~= 0 or dy ~= 0 then
                    love.graphics.print(multiplierText, multiplierX + dx, multiplierY + dy)
                end
            end
        end
        
        -- Draw main text with pulsing color
        love.graphics.setColor(r, g, b, flashAlpha)
        love.graphics.print(multiplierText, multiplierX, multiplierY)
        
        -- Add extra glow effect
        love.graphics.setColor(r, g, b, flashAlpha * 0.3)
        for i = 1, 3 do
            love.graphics.print(multiplierText, multiplierX, multiplierY)
        end
    end
    
    -- Draw rapid fire announcement (giant flashing "RAPID FIRE" with sparks)
    if Game.rapidFireTextTimer > 0 then
        local centerX = Constants.SCREEN_WIDTH / 2
        -- Position rapid fire text above multiplier text if multiplier is active
        local centerY
        if Game.pointMultiplierActive then
            -- Place above multiplier text (multiplier is at SCREEN_HEIGHT/2 - 100, with 120px font)
            -- Rapid fire should be about 150px above the multiplier text center
            centerY = Constants.SCREEN_HEIGHT / 2 - 250
        else
            -- Same position as multiplier when multiplier is not active
            centerY = Constants.SCREEN_HEIGHT / 2 - 100
        end
        
        -- Draw spark particles (adjust their visual position if multiplier is active)
        local sparkOffsetY = 0
        if Game.pointMultiplierActive then
            -- Adjust spark positions to match the rapid fire text position above multiplier
            sparkOffsetY = -150  -- Move sparks up by 150px to match text position
        end
        for _, spark in ipairs(Game.rapidFireSparks) do
            local alpha = spark.life / spark.maxLife
            -- Gold/yellow sparks with fade
            local sparkColor = 0.3 + (spark.life / spark.maxLife) * 0.7  -- Fade from bright to dim
            love.graphics.setColor(1, 0.8 + sparkColor * 0.2, 0.2, alpha)
            love.graphics.circle("fill", spark.x, spark.y + sparkOffsetY, spark.size)
            -- Add glow effect
            love.graphics.setColor(1, 0.9, 0.3, alpha * 0.3)
            love.graphics.circle("fill", spark.x, spark.y + sparkOffsetY, spark.size * 2)
        end
        
        -- Calculate flash alpha and fade out after 3 seconds
        local flashAlpha = 1.0
        local flashTimer = 3.0 - Game.rapidFireTextTimer
        if flashTimer < 2.0 then
            -- Flash animation during first 2 seconds
            flashAlpha = 0.6 + 0.4 * (math.sin(flashTimer * 12) + 1) / 2
        end
        -- Fade out after 3 seconds
        if Game.rapidFireTextTimer < 1.0 then
            -- Fade out over last second
            flashAlpha = flashAlpha * (Game.rapidFireTextTimer / 1.0)
        end
        
        -- Create giant font for "RAPID FIRE" text
        local giantFontSize = 120
        local giantFont = love.graphics.newFont(giantFontSize)
        love.graphics.setFont(giantFont)
        
        local rapidFireText = "RAPID FIRE"
        local textWidth = giantFont:getWidth(rapidFireText)
        local textX = centerX - textWidth / 2
        local textY = centerY - giantFontSize / 2
        
        -- Flashy colors (gold/yellow pulsing)
        local flash = (math.sin(love.timer.getTime() * 8) + 1) / 2
        local r = 1
        local g = 0.7 + flash * 0.3
        local b = 0.1
        
        -- Draw text with thick outline for visibility
        love.graphics.setLineWidth(8)
        love.graphics.setColor(0, 0, 0, flashAlpha * 0.9)
        for dx = -4, 4, 2 do
            for dy = -4, 4, 2 do
                if dx ~= 0 or dy ~= 0 then
                    love.graphics.print(rapidFireText, textX + dx, textY + dy)
                end
            end
        end
        
        -- Draw main text with pulsing color
        love.graphics.setColor(r, g, b, flashAlpha)
        love.graphics.print(rapidFireText, textX, textY)
        
        -- Add extra glow effect
        love.graphics.setColor(r, g, b, flashAlpha * 0.3)
        for i = 1, 3 do
            love.graphics.print(rapidFireText, textX, textY)
        end
    end
    
    
    -- Display level transition message
    if Game.levelTransitionActive then
        local Popups = require("src.core.popups")
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(0, 1, 0)
        local message = Popups.getWinMessage(Game.winCondition)
        local textWidth = Game.fonts.large:getWidth(message)
        love.graphics.print(message, (Constants.SCREEN_WIDTH - textWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 100)
        
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.setColor(1, 1, 0)
        local nextLevelMsg = Popups.getAdvancingMessage(Game.level + 1)
        local nextLevelWidth = Game.fonts.medium:getWidth(nextLevelMsg)
        love.graphics.print(nextLevelMsg, (Constants.SCREEN_WIDTH - nextLevelWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
    elseif Game.gameOverActive and Game.lives > 0 then
        -- Display "LIFE LOST" message when player loses a life but still has lives remaining
        local Auditor = require("src.core.auditor")
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 0.2, 0.2)  -- Red color
        local lifeLostMsg = Auditor.LIFE_LOST
        local lifeLostWidth = Game.fonts.large:getWidth(lifeLostMsg)
        love.graphics.print(lifeLostMsg, (Constants.SCREEN_WIDTH - lifeLostWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
        
        local Popups = require("src.core.popups")
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.setColor(1, 1, 1)
        local livesRemainingMsg = Popups.getLivesRemaining(Game.lives)
        local livesRemainingWidth = Game.fonts.medium:getWidth(livesRemainingMsg)
        love.graphics.print(livesRemainingMsg, (Constants.SCREEN_WIDTH - livesRemainingWidth) / 2, Constants.SCREEN_HEIGHT / 2 + 20)
    elseif Game.nameEntryActive then
        -- Draw name entry screen (check this before game over screen)
        local Popups = require("src.core.popups")
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 1, 0)
        local titleMsg = Popups.HIGH_SCORE.TITLE
        local titleWidth = Game.fonts.large:getWidth(titleMsg)
        love.graphics.print(titleMsg, (Constants.SCREEN_WIDTH - titleWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 150)
        
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.setColor(1, 1, 1)
        local scoreMsg = Popups.HIGH_SCORE.getScore(Game.score)
        local scoreWidth = Game.fonts.medium:getWidth(scoreMsg)
        love.graphics.print(scoreMsg, (Constants.SCREEN_WIDTH - scoreWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 100)
        
        love.graphics.setColor(0.8, 0.8, 0.8)
        local enterMsg = Popups.HIGH_SCORE.ENTER_NAME
        local enterWidth = Game.fonts.medium:getWidth(enterMsg)
        love.graphics.print(enterMsg, (Constants.SCREEN_WIDTH - enterWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
        
        -- Draw name input box
        local boxWidth = 400
        local boxHeight = 50
        local boxX = (Constants.SCREEN_WIDTH - boxWidth) / 2
        local boxY = Constants.SCREEN_HEIGHT / 2
        
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", boxX, boxY, boxWidth, boxHeight)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", boxX, boxY, boxWidth, boxHeight)
        
        -- Draw name text with arcade-style cursor
        love.graphics.setFont(Game.fonts.large)
        local charWidth = Game.fonts.large:getWidth("A")
        local startX = boxX + (boxWidth - (charWidth * Game.nameEntryMaxLength)) / 2
        local textY = boxY + (boxHeight - Game.fonts.large:getHeight()) / 2
        
        -- Draw each character
        for i = 1, Game.nameEntryMaxLength do
            local char = Game.nameEntryText:sub(i, i) or "A"
            local charX = startX + (i - 1) * charWidth
            
            -- Highlight current cursor position
            if i == Game.nameEntryCursor then
                -- Draw blinking cursor background
                if math.floor(love.timer.getTime() * 2) % 2 == 0 then
                    love.graphics.setColor(1, 1, 0, 0.3)
                    love.graphics.rectangle("fill", charX - 5, textY - 5, charWidth + 10, Game.fonts.large:getHeight() + 10)
                end
                love.graphics.setColor(1, 1, 0)  -- Yellow for current position
            else
                love.graphics.setColor(1, 1, 1)  -- White for other positions
            end
            
            love.graphics.print(char, charX, textY)
        end
        
        -- Instructions
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(Game.fonts.small)
        local hintMsg = "ARROWS: Move/Change  ENTER: Confirm"
        local hintWidth = Game.fonts.small:getWidth(hintMsg)
        love.graphics.print(hintMsg, (Constants.SCREEN_WIDTH - hintWidth) / 2, Constants.SCREEN_HEIGHT / 2 + 70)
    end
end