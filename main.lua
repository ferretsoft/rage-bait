                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        local Constants = require("src.constants")
local Event = require("src.core.event")
local Engagement = require("src.core.engagement")
local World = require("src.core.world")
local Time = require("src.core.time")
local Sound = require("src.core.sound")
local EmojiSprites = require("src.core.emoji_sprites")
local Webcam = require("src.core.webcam")
local EngagementPlot = require("src.core.engagement_plot")
local Unit = require("src.entities.unit")
local Turret = require("src.entities.turret")
local Projectile = require("src.entities.projectile")
local PowerUp = require("src.entities.powerup")
local moonshine = require("libs.moonshine")
-- Set BASE so moonshine can find effects in libs directory
moonshine.BASE = "libs"

local Game = {
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
    showBackgroundForeground = false,  -- Toggle for background/foreground layers
    attractMode = true,  -- Start in attract mode
    attractModeTimer = 0,  -- Timer for attract mode animations
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
    lives = 3,  -- Player lives
    gameOverTimer = 0,  -- Timer for game over screen
    gameOverActive = false,  -- Whether game over screen is active
    pointMultiplier = 1,  -- Current point multiplier (incremental)
    pointMultiplierTimer = 0,  -- Timer for point multiplier (10 seconds)
    pointMultiplierActive = false,  -- Whether point multiplier is active
    pointMultiplierFlashTimer = 0,  -- Timer for flashy text animation
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
    
    Event.clear(); Engagement.init(); World.init(); Time.init(); Sound.init(); EmojiSprites.init(); Webcam.init(); EngagementPlot.init()
    World.physics:setCallbacks(beginContact, nil, preSolve, nil)
    
    -- Start in attract mode
    Game.attractMode = true
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
    -- Don't stop whistle sounds - let them continue until projectiles explode naturally
    -- First show level completion screen with Chase Paxton (5 seconds)
    Game.levelCompleteScreenActive = true
    Game.levelCompleteScreenTimer = 5.0  -- 5 second completion screen
    Game.winCondition = winCondition
    Game.gameState = "level_complete"
    Webcam.showComment("level_complete")
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

-- Draw attract mode screen
function drawAttractMode()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Title
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(1, 1, 1)
    local title = "RAGE BAIT"
    local titleWidth = Game.fonts.large:getWidth(title)
    love.graphics.print(title, (Constants.SCREEN_WIDTH - titleWidth) / 2, 50)
    
    -- High Scores
    if #Game.highScores > 0 then
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.setColor(1, 0.8, 0.2)
        local highScoreTitle = "HIGH SCORES"
        local titleWidth2 = Game.fonts.medium:getWidth(highScoreTitle)
        love.graphics.print(highScoreTitle, (Constants.SCREEN_WIDTH - titleWidth2) / 2, 120)
        
        love.graphics.setFont(Game.fonts.small)
        local startY = 150
        local lineHeight = 25
        local maxScores = math.min(10, #Game.highScores)
        
        for i = 1, maxScores do
            local entry = Game.highScores[i]
            local rank = tostring(i) .. "."
            local name = entry.name
            local score = tostring(entry.score)
            
            -- Rank color (gold for top 3)
            if i == 1 then
                love.graphics.setColor(1, 0.84, 0)  -- Gold
            elseif i == 2 then
                love.graphics.setColor(0.75, 0.75, 0.75)  -- Silver
            elseif i == 3 then
                love.graphics.setColor(0.8, 0.5, 0.2)  -- Bronze
            else
                love.graphics.setColor(0.7, 0.7, 0.7)  -- Gray
            end
            
            -- Calculate positions for aligned display
            local rankX = Constants.SCREEN_WIDTH / 2 - 150
            local nameX = Constants.SCREEN_WIDTH / 2 - 80
            local scoreX = Constants.SCREEN_WIDTH / 2 + 100
            
            love.graphics.print(rank, rankX, startY + (i - 1) * lineHeight)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.print(name, nameX, startY + (i - 1) * lineHeight)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(score, scoreX, startY + (i - 1) * lineHeight)
        end
    end
    
    -- Insert coin message (blinking)
    local blinkSpeed = 2.0
    local alpha = (math.sin(Game.attractModeTimer * blinkSpeed) + 1) / 2
    alpha = 0.3 + alpha * 0.7  -- Keep between 0.3 and 1.0
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 0.8, 0.2, alpha)
    local coinMsg = "INSERT COIN"
    local coinWidth = Game.fonts.medium:getWidth(coinMsg)
    local coinY = Constants.SCREEN_HEIGHT - 150
    love.graphics.print(coinMsg, (Constants.SCREEN_WIDTH - coinWidth) / 2, coinY)
    
    -- Instructions
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(Game.fonts.small)
    local inst1 = "Press SPACE or ENTER to start"
    local inst1Width = Game.fonts.small:getWidth(inst1)
    love.graphics.print(inst1, (Constants.SCREEN_WIDTH - inst1Width) / 2, coinY + 30)
    
    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    local inst2 = "Use Z/X to fire bombs, collect powerups for rapid fire"
    local inst2Width = Game.fonts.small:getWidth(inst2)
    love.graphics.print(inst2, (Constants.SCREEN_WIDTH - inst2Width) / 2, coinY + 50)
    
    -- Draw playfield frame in attract mode (optional visual)
    love.graphics.push()
    love.graphics.translate(Constants.OFFSET_X, Constants.OFFSET_Y)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 0, 0, Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT)
    love.graphics.pop()
end

-- Draw intro screen with centered webcam
function drawIntroScreen()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Intro messages (multiple steps) - Chase Paxton's onboarding
    local introMessages = {
        {
            title = "WELCOME TO RAGE BAIT!",
            message = "You're our new engagement specialist!\nYour job: maximize user conversion metrics!",
            duration = 3.0
        },
        {
            title = "CONTROLS",
            message = "Hold Z for RED data packets\nHold X for BLUE data packets\nCollect powerups to optimize throughput!",
            duration = 4.0
        },
        {
            title = "OBJECTIVE",
            message = "Keep engagement metrics in the green!\nConvert all units to one alignment to hit KPIs!\nWatch out for toxic sludge - it kills performance!",
            duration = 4.0
        },
        {
            title = "READY?",
            message = "Press SPACE or ENTER to start your shift!\nRemember: The Auditor is watching!",
            duration = 999.0  -- Wait for input
        }
    }
    
    local currentStep = math.min(Game.introStep, #introMessages)
    local currentMessage = introMessages[currentStep]
    local stepStartTime = 0
    for i = 1, currentStep - 1 do
        stepStartTime = stepStartTime + introMessages[i].duration
    end
    local stepElapsed = Game.introTimer - stepStartTime
    
    -- Auto-advance steps (except last one which waits for input)
    if currentStep < #introMessages and stepElapsed >= currentMessage.duration then
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
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    local dotSize = 8
    local dotSpacing = 15
    local totalWidth = (#introMessages - 1) * dotSpacing
    local dotsStartX = WEBCAM_X + (WEBCAM_WIDTH - totalWidth) / 2
    for i = 1, #introMessages - 1 do
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
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setFont(Game.fonts.large)
        local errorMsg = "CRITICAL_ERROR"
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
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 0, 0, 1)  -- Red text
        
        local lifeLostMsg = "LIFE LOST"
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
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setFont(Game.fonts.large)
        local errorMsg = "CRITICAL_ERROR"
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
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 0, 0, 1)  -- Red text
        
        local verdict1 = "YIELD INSUFFICIENT."
        local verdict2 = "LIQUIDATING ASSET."
        
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
    
    -- Draw congratulatory messages
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(1, 1, 0, 1)  -- Yellow
    local congratsMsg = "GREAT JOB!"
    local congratsWidth = Game.fonts.large:getWidth(congratsMsg)
    love.graphics.print(congratsMsg, WEBCAM_X + (WEBCAM_WIDTH - congratsWidth) / 2, WEBCAM_Y + 30)
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    local readyMsg = "Get ready for the next level!"
    local readyWidth = Game.fonts.medium:getWidth(readyMsg)
    love.graphics.print(readyMsg, WEBCAM_X + (WEBCAM_WIDTH - readyWidth) / 2, WEBCAM_Y + WEBCAM_HEIGHT - 60)
    
    -- Show countdown timer
    local timeLeft = math.ceil(Game.levelCompleteScreenTimer)
    local timerText = "Starting in " .. timeLeft .. "..."
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    local timerWidth = Game.fonts.medium:getWidth(timerText)
    love.graphics.print(timerText, WEBCAM_X + (WEBCAM_WIDTH - timerWidth) / 2, WEBCAM_Y + WEBCAM_HEIGHT - 30)
end

function love.update(dt)
    if love.keyboard.isDown("escape") then love.event.quit() end
    
    -- Handle attract mode
    if Game.attractMode then
        Game.attractModeTimer = Game.attractModeTimer + dt
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
        -- Phase 4: Crash to black (1 second), then return to attract mode
        elseif Game.auditorPhase == 4 and Game.auditorTimer >= 1.0 then
            returnToAttractMode()
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
    
    -- Handle level completion screen (Chase Paxton congratulation)
    if Game.levelCompleteScreenActive then
        Game.levelCompleteScreenTimer = Game.levelCompleteScreenTimer - dt
        if Game.levelCompleteScreenTimer <= 0 then
            -- Completion screen done, proceed to level transition
            Game.levelCompleteScreenActive = false
            Game.levelCompleteScreenTimer = 0
            Game.levelTransitionActive = true
            Game.levelTransitionTimer = 2.0  -- 2 second transition
        end
        return  -- Don't update game logic during completion screen
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
            
            -- Reset point multiplier for new level
            Game.pointMultiplier = 1
            Game.pointMultiplierTimer = 0
            Game.pointMultiplierActive = false
            Game.pointMultiplierFlashTimer = 0
            
            -- Clear all game entities
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
            
            -- Spawn new units for next level
            spawnUnitsForLevel()
        else
            -- Allow projectiles to continue updating during transition so they can explode and stop sounds naturally
            Time.checkRestore(dt); Time.update(dt); local gameDt = dt * Time.scale
            for i = #Game.projectiles, 1, -1 do 
                local p = Game.projectiles[i]
                p:update(gameDt)
                if p.isDead then 
                    table.remove(Game.projectiles, i) 
                end
            end
        end
        return  -- Don't update other game logic during transition
    end
    
    Game.powerupSpawnTimer = Game.powerupSpawnTimer - dt
    if Game.powerupSpawnTimer <= 0 then
        Game.powerupSpawnTimer = math.random(15, 25)
        local px = math.random(50, Constants.PLAYFIELD_WIDTH - 50)
        -- Only spawn puck powerups (bumpers removed)
        table.insert(Game.powerups, PowerUp.new(px, -50, "puck"))
    end

    if not Game.isUpgraded and Game.score >= Constants.UPGRADE_SCORE then
    Game.isUpgraded = true
    -- Only upgrade the Puck Lifetime. The Bomb Radius is already maxed!
    Constants.PUCK_LIFETIME = Constants.PUCK_LIFETIME_MAX
    Game.shake = 2.0
    end
    if Game.shake > 0 then Game.shake = math.max(0, Game.shake - 2.5 * dt) end

    Time.checkRestore(dt); Time.update(dt); local gameDt = dt * Time.scale
    
    -- Calculate toxic hazard count for engagement decay
    local toxicHazardCount = #Game.hazards
    
    Engagement.update(gameDt, toxicHazardCount, Game.level); World.update(gameDt); Sound.update(dt); Webcam.update(dt); EngagementPlot.update(dt)
    
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
        local isAtMax = Engagement.value >= Constants.ENGAGEMENT_MAX
        if isAtMax and not Game.previousEngagementAtMax and not Game.pointMultiplierActive then
            -- Activate point multiplier
            Game.pointMultiplier = Game.pointMultiplier + 1  -- Incremental multiplier
            Game.pointMultiplierActive = true
            Game.pointMultiplierTimer = 10.0  -- 10 seconds
            Game.pointMultiplierFlashTimer = 1.5  -- Flash animation duration
            Game.shake = math.max(Game.shake, 1.5)  -- Screen shake
            
            -- Play sound effect
            Sound.playTone(800, 0.3, 0.8, 1.5)  -- High pitch success sound
            Sound.playTone(600, 0.3, 0.8, 1.2)  -- Second tone for richness
            
            Webcam.showComment("engagement_high")
        end
        
        -- Update tracking flag for next frame
        Game.previousEngagementAtMax = isAtMax
        
        -- Update point multiplier timer
        if Game.pointMultiplierActive then
            Game.pointMultiplierTimer = Game.pointMultiplierTimer - dt
            if Game.pointMultiplierTimer <= 0 then
                Game.pointMultiplierActive = false
                Game.pointMultiplierFlashTimer = 0
            else
                -- Update flash timer
                if Game.pointMultiplierFlashTimer > 0 then
                    Game.pointMultiplierFlashTimer = Game.pointMultiplierFlashTimer - dt
                end
            end
            
            -- Reset multiplier if engagement drops below max (allows re-triggering)
            if Engagement.value < Constants.ENGAGEMENT_MAX then
                Game.pointMultiplierActive = false
                Game.pointMultiplierTimer = 0
                Game.pointMultiplierFlashTimer = 0
                Game.previousEngagementAtMax = false  -- Reset flag to allow re-triggering
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

    if Game.turret then Game.turret:update(dt, Game.projectiles, Game.isUpgraded) end
    
    for i = #Game.units, 1, -1 do local u = Game.units[i]; u:update(gameDt, Game.units, Game.hazards, Game.explosionZones); if u.isDead then table.remove(Game.units, i) end end
    for i = #Game.projectiles, 1, -1 do local p = Game.projectiles[i]; p:update(gameDt); if p.isDead then table.remove(Game.projectiles, i) end end
    
    -- Check win conditions
    if Game.gameState == "playing" then
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
        -- Win condition 4: Only neutral units left (but only if a unit has been converted)
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
            local introMessages = {
                {duration = 3.0},
                {duration = 4.0},
                {duration = 4.0},
                {duration = 999.0}
            }
            if Game.introStep < #introMessages then
                Game.introStep = Game.introStep + 1
                -- Reset timer for new step
                local stepStartTime = 0
                for i = 1, Game.introStep - 1 do
                    stepStartTime = stepStartTime + introMessages[i].duration
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
    if key == "z" or key == "x" then Game.turret:releaseCharge(Game.projectiles) end
end

function love.draw()
    -- Draw attract mode screen
    if Game.attractMode then
        drawAttractMode()
        return
    end
    
    -- Draw intro screen (check before AUDITOR to prevent showing CRITICAL_ERROR on new game)
    if Game.introMode then
        drawIntroScreen()
        return
    end
    
    -- Draw level completion screen (Chase Paxton)
    if Game.levelCompleteScreenActive then
        drawLevelCompleteScreen()
        return
    end
    
    -- Draw life lost auditor screen (engagement depleted but lives remain)
    if Game.lifeLostAuditorActive then
        drawLifeLostAuditor()
        return
    end
    
    -- Draw THE AUDITOR sequence (final game over - all lives lost)
    -- Only show if not in intro mode (safety check)
    if Game.auditorActive and not Game.introMode then
        drawAuditor()
        return
    end
    
    -- Drawing function that will be wrapped by Moonshine if CRT is enabled
    local function drawGame()
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
                        local fontSize = 12
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
        
        love.graphics.pop()
        
        -- CRITICAL: Reset color to white before Moonshine processes the canvas
        -- Otherwise, any color set by effects (like gold explosion) will tint the entire screen
        love.graphics.setColor(1, 1, 1, 1)
    end
    
    -- Apply CRT effect if enabled, otherwise draw normally
    if Game.crtEnabled and Game.crtChain then
        Game.crtChain.draw(drawGame)
    else
        drawGame()
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
    
    -- Draw point multiplier announcement (flashy text)
    if Game.pointMultiplierActive then
        local flashAlpha = 1.0
        if Game.pointMultiplierFlashTimer > 0 then
            -- Flash animation during first 1.5 seconds
            flashAlpha = 0.5 + 0.5 * (math.sin(Game.pointMultiplierFlashTimer * 10) + 1) / 2
        end
        
        love.graphics.setFont(Game.fonts.large)
        local multiplierText = "x" .. Game.pointMultiplier .. " POINT MULTIPLIER!"
        local multiplierWidth = Game.fonts.large:getWidth(multiplierText)
        local multiplierX = (Constants.SCREEN_WIDTH - multiplierWidth) / 2
        local multiplierY = Constants.SCREEN_HEIGHT / 2 - 100
        
        -- Flashy colors (gold/yellow pulsing)
        local flash = (math.sin(love.timer.getTime() * 5) + 1) / 2
        love.graphics.setColor(1, 0.8 + flash * 0.2, 0.2, flashAlpha)
        
        -- Draw text with outline for visibility
        love.graphics.setLineWidth(4)
        love.graphics.setColor(0, 0, 0, flashAlpha * 0.8)
        for dx = -2, 2 do
            for dy = -2, 2 do
                if dx ~= 0 or dy ~= 0 then
                    love.graphics.print(multiplierText, multiplierX + dx, multiplierY + dy)
                end
            end
        end
        love.graphics.setColor(1, 0.8 + flash * 0.2, 0.2, flashAlpha)
        love.graphics.print(multiplierText, multiplierX, multiplierY)
        
        -- Show timer
        love.graphics.setFont(Game.fonts.medium)
        local timerText = math.ceil(Game.pointMultiplierTimer) .. "s"
        local timerWidth = Game.fonts.medium:getWidth(timerText)
        love.graphics.setColor(1, 1, 1, flashAlpha)
        love.graphics.print(timerText, multiplierX + (multiplierWidth - timerWidth) / 2, multiplierY + 40)
    end
    
    if Game.turret and Game.turret.puckModeTimer > 0 then
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.print("RAPID FIRE ACTIVE: " .. math.ceil(Game.turret.puckModeTimer), barX + 80, barY + 110)
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Game.fonts.small)
        love.graphics.print("Hold Z/X to charge Bomb. Collect Powerup for Rapid Fire.", barX + 50, barY + 110)
    end
    
    -- Display level transition message
    if Game.levelTransitionActive then
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(0, 1, 0)
        local message = ""
        if Game.winCondition == "blue_only" then
            message = "LEVEL COMPLETE! Only Blue Units Remain"
        elseif Game.winCondition == "red_only" then
            message = "LEVEL COMPLETE! Only Red Units Remain"
        elseif Game.winCondition == "neutral_only" then
            message = "LEVEL COMPLETE! All Units Returned to Neutral"
        end
        local textWidth = Game.fonts.large:getWidth(message)
        love.graphics.print(message, (Constants.SCREEN_WIDTH - textWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 100)
        
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.setColor(1, 1, 0)
        local nextLevelMsg = "ADVANCING TO LEVEL " .. (Game.level + 1) .. "..."
        local nextLevelWidth = Game.fonts.medium:getWidth(nextLevelMsg)
        love.graphics.print(nextLevelMsg, (Constants.SCREEN_WIDTH - nextLevelWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
    elseif Game.gameOverActive and Game.lives > 0 then
        -- Display "LIFE LOST" message when player loses a life but still has lives remaining
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 0.2, 0.2)  -- Red color
        local lifeLostMsg = "LIFE LOST"
        local lifeLostWidth = Game.fonts.large:getWidth(lifeLostMsg)
        love.graphics.print(lifeLostMsg, (Constants.SCREEN_WIDTH - lifeLostWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
        
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.setColor(1, 1, 1)
        local livesRemainingMsg = "LIVES REMAINING: " .. Game.lives
        local livesRemainingWidth = Game.fonts.medium:getWidth(livesRemainingMsg)
        love.graphics.print(livesRemainingMsg, (Constants.SCREEN_WIDTH - livesRemainingWidth) / 2, Constants.SCREEN_HEIGHT / 2 + 20)
    elseif Game.nameEntryActive then
        -- Draw name entry screen (check this before game over screen)
        -- Draw name entry screen
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 1, 0)
        local titleMsg = "NEW HIGH SCORE!"
        local titleWidth = Game.fonts.large:getWidth(titleMsg)
        love.graphics.print(titleMsg, (Constants.SCREEN_WIDTH - titleWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 150)
        
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.setColor(1, 1, 1)
        local scoreMsg = "SCORE: " .. Game.score
        local scoreWidth = Game.fonts.medium:getWidth(scoreMsg)
        love.graphics.print(scoreMsg, (Constants.SCREEN_WIDTH - scoreWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 100)
        
        love.graphics.setColor(0.8, 0.8, 0.8)
        local enterMsg = "ENTER YOUR NAME:"
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