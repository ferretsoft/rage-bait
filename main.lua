                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        local Constants = require("src.constants")
local Event = require("src.core.event")
local Engagement = require("src.core.engagement")
local World = require("src.core.world")
local Time = require("src.core.time")
local Sound = require("src.core.sound")
local EmojiSprites = require("src.core.emoji_sprites")
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
    level = 1,  -- Current level
    levelTransitionTimer = 0,  -- Timer for level transition
    levelTransitionActive = false,  -- Whether level transition is active
    lives = 3,  -- Player lives
    gameOverTimer = 0,  -- Timer for game over screen
    gameOverActive = false,  -- Whether game over screen is active
    highScores = {},  -- List of high scores {name, score}
    nameEntryActive = false,  -- Whether name entry screen is active
    nameEntryText = "",  -- Current name being entered
    nameEntryMaxLength = 10,  -- Maximum name length
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
        Game.score = Game.score + (Constants.SCORE_HIT * 2)
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
    
    Event.clear(); Engagement.init(); World.init(); Time.init(); Sound.init(); EmojiSprites.init()
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
        Game.score = Game.score + Constants.SCORE_KILL; Engagement.add(Constants.ENGAGEMENT_REFILL_KILL); Game.shake = math.max(Game.shake, 0.2)
        local x, y = data.victim.body:getPosition()
        table.insert(Game.hazards, {x = x, y = y, radius = Constants.TOXIC_RADIUS, timer = Constants.TOXIC_DURATION})
    end)
end

-- Start the game (called when coin is inserted)
function startGame()
    -- Unmute sounds for new game
    Sound.unmute()
    Game.attractMode = false
    Game.attractModeTimer = 0
    
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
    Game.lives = 3
    Game.gameOverTimer = 0
    Game.gameOverActive = false
    Game.nameEntryActive = false
    Game.nameEntryText = ""
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
    Game.levelTransitionActive = true
    Game.levelTransitionTimer = 2.0  -- 2 second transition
    Game.winCondition = winCondition
    Game.gameState = "level_complete"
end

-- Handle game over (lose a life)
function handleGameOver(condition)
    -- Stop all sounds immediately when game over happens
    Sound.cleanup()
    
    -- Also stop any looping sounds from turret and projectiles (safety check)
    -- Use pcall to safely handle already-released sources
    if Game.turret and Game.turret.chargeSound then
        pcall(function()
            Game.turret.chargeSound:stop()
            Game.turret.chargeSound:release()
        end)
        Game.turret.chargeSound = nil
    end
    
    -- Stop all projectile whistle sounds
    for _, p in ipairs(Game.projectiles) do
        if p.whistleSound then
            pcall(function()
                p.whistleSound:stop()
                p.whistleSound:release()
            end)
            p.whistleSound = nil
        end
    end
    
    Game.gameOverActive = true
    Game.gameOverTimer = 2.0  -- 2 second game over screen
    Game.gameState = "lost"
    Game.winCondition = condition
    Game.lives = Game.lives - 1
end

-- Restart the current level after losing a life
function restartLevel()
    Game.gameOverActive = false
    Game.gameOverTimer = 0
    Game.gameState = "playing"
    Game.winCondition = nil
    Game.hasUnitBeenConverted = false
    
    -- Reset engagement to half
    Engagement.value = Constants.ENGAGEMENT_MAX / 2
    
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
    Game.nameEntryActive = false
    Game.nameEntryText = ""
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
    love.graphics.print(title, (Constants.SCREEN_WIDTH - titleWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 200)
    
    -- Insert coin message (blinking)
    local blinkSpeed = 2.0
    local alpha = (math.sin(Game.attractModeTimer * blinkSpeed) + 1) / 2
    alpha = 0.3 + alpha * 0.7  -- Keep between 0.3 and 1.0
    
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 0.8, 0.2, alpha)
    local coinMsg = "INSERT COIN"
    local coinWidth = Game.fonts.medium:getWidth(coinMsg)
    love.graphics.print(coinMsg, (Constants.SCREEN_WIDTH - coinWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
    
    -- Instructions
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(Game.fonts.small)
    local inst1 = "Press SPACE or ENTER to start"
    local inst1Width = Game.fonts.small:getWidth(inst1)
    love.graphics.print(inst1, (Constants.SCREEN_WIDTH - inst1Width) / 2, Constants.SCREEN_HEIGHT / 2 + 50)
    
    -- High score or instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    local inst2 = "Use Z/X to fire bombs, collect powerups for rapid fire"
    local inst2Width = Game.fonts.small:getWidth(inst2)
    love.graphics.print(inst2, (Constants.SCREEN_WIDTH - inst2Width) / 2, Constants.SCREEN_HEIGHT / 2 + 100)
    
    -- Draw playfield frame in attract mode (optional visual)
    love.graphics.push()
    love.graphics.translate(Constants.OFFSET_X, Constants.OFFSET_Y)
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", 0, 0, Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT)
    love.graphics.pop()
end

function love.update(dt)
    if love.keyboard.isDown("escape") then love.event.quit() end
    
    -- Handle attract mode
    if Game.attractMode then
        Game.attractModeTimer = Game.attractModeTimer + dt
        return  -- Don't update game logic in attract mode
    end
    
    -- Handle name entry
    if Game.nameEntryActive then
        return  -- Don't update game logic during name entry
    end
    
    -- Handle game over screen
    if Game.gameOverActive then
        -- Ensure all sounds are stopped during game over
        Sound.cleanup()
        Game.gameOverTimer = Game.gameOverTimer - dt
        if Game.gameOverTimer <= 0 then
            -- Game over screen complete
            if Game.lives > 0 then
                -- Restart the level
                restartLevel()
            else
                -- No lives left, check for high score
                if isHighScore(Game.score) then
                    -- Start name entry
                    Game.nameEntryActive = true
                    Game.nameEntryText = ""
                else
                    -- No high score, return to attract mode
                    returnToAttractMode()
                end
            end
        end
        return  -- Don't update game logic during game over
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
        end
        return  -- Don't update game logic during transition
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
    Engagement.update(gameDt); World.update(gameDt); Sound.update(dt)
    
    -- Check if engagement ran out (game over)
    if Game.gameState == "playing" and Engagement.value <= 0 then
        if not Game.gameOverActive then
            handleGameOver("engagement_depleted")
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
        end
        if e.timer <= 0 then table.remove(Game.effects, i) end
    end
end

function love.keypressed(key)
    -- Handle name entry
    if Game.nameEntryActive then
        if key == "backspace" then
            Game.nameEntryText = Game.nameEntryText:sub(1, -2)
        elseif key == "return" or key == "enter" then
            -- Submit name
            local name = Game.nameEntryText:gsub("^%s+", ""):gsub("%s+$", "")  -- Trim whitespace
            if name == "" then
                name = "PLAYER"  -- Default name
            end
            addHighScore(name, Game.score)
            Game.nameEntryActive = false
            Game.nameEntryText = ""
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

-- Handle text input for name entry
function love.textinput(text)
    if Game.nameEntryActive then
        if #Game.nameEntryText < Game.nameEntryMaxLength then
            Game.nameEntryText = Game.nameEntryText .. text
        end
    end
end

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
    elseif Game.gameState == "lost" and Game.gameOverActive then
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 0, 0)
        local message = ""
        if Game.winCondition == "no_units" then
            message = "DEFEAT! No Units Remain"
        elseif Game.winCondition == "engagement_depleted" then
            message = "GAME OVER! Engagement Depleted"
        else
            message = "GAME OVER!"
        end
        local textWidth = Game.fonts.large:getWidth(message)
        love.graphics.print(message, (Constants.SCREEN_WIDTH - textWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 100)
        
        -- Show lives remaining or final game over
        love.graphics.setFont(Game.fonts.medium)
        if Game.lives > 0 then
            love.graphics.setColor(1, 1, 0)
            local livesMsg = "LIVES REMAINING: " .. Game.lives .. " - RESTARTING LEVEL..."
            local livesWidth = Game.fonts.medium:getWidth(livesMsg)
            love.graphics.print(livesMsg, (Constants.SCREEN_WIDTH - livesWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
        else
            love.graphics.setColor(1, 0, 0)
            local finalMsg = "NO LIVES REMAINING - GAME OVER"
            local finalWidth = Game.fonts.medium:getWidth(finalMsg)
            love.graphics.print(finalMsg, (Constants.SCREEN_WIDTH - finalWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
            
            -- Optionally show return to attract mode message
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.setFont(Game.fonts.small)
            local returnMsg = "Press ESC to quit"
            local returnWidth = Game.fonts.small:getWidth(returnMsg)
            love.graphics.print(returnMsg, (Constants.SCREEN_WIDTH - returnWidth) / 2, Constants.SCREEN_HEIGHT / 2 + 20)
        end
    elseif Game.nameEntryActive then
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
        
        -- Draw name text with cursor
        love.graphics.setColor(1, 1, 1)
        local displayText = Game.nameEntryText
        if math.floor(love.timer.getTime() * 2) % 2 == 0 then
            displayText = displayText .. "_"  -- Blinking cursor
        end
        local textWidth = Game.fonts.medium:getWidth(displayText)
        love.graphics.print(displayText, boxX + (boxWidth - textWidth) / 2, boxY + (boxHeight - Game.fonts.medium:getHeight()) / 2)
        
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(Game.fonts.small)
        local hintMsg = "Press ENTER to submit"
        local hintWidth = Game.fonts.small:getWidth(hintMsg)
        love.graphics.print(hintMsg, (Constants.SCREEN_WIDTH - hintWidth) / 2, Constants.SCREEN_HEIGHT / 2 + 70)
    end
end