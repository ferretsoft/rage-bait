local Constants = require("src.constants")
local Event = require("src.core.event")
local Engagement = require("src.core.engagement")
local World = require("src.core.world")
local Time = require("src.core.time")
local Unit = require("src.entities.unit")
local Turret = require("src.entities.turret")
local Projectile = require("src.entities.projectile")
local PowerUp = require("src.entities.powerup")
local Bumper = require("src.entities.bumper")

local Game = {
    units = {},
    projectiles = {},
    powerups = {},
    effects = {}, 
    hazards = {},
    explosionZones = {}, 
    bumpers = {},
    turret = nil,
    score = 0,
    shake = 0,
    logicTimer = 0,
    isUpgraded = false,
    powerupSpawnTimer = 0,
    bumperActivationWindow = 0,  -- Timer for activation window
    bumperForcefieldActive = false,  -- One-time forcefield trigger
    background = nil,
    foreground = nil,
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
    
    if powerup.powerupType == "bumper" then
        -- Check if any bumpers are already activated
        local anyBumperActive = false
        for _, b in ipairs(Game.bumpers) do
            if b.activated then
                anyBumperActive = true
                break
            end
        end
        
        -- Give new activation window unless any bumper is already active
        if not anyBumperActive then
            -- Reset activation window to full duration
            Game.bumperActivationWindow = Constants.BUMPER_ACTIVATION_WINDOW
        end
        
        -- Always trigger one-time forcefield from all bumpers
        Game.bumperForcefieldActive = true
        Game.bumperForcefieldTimer = Constants.BUMPER_CENTER_FORCEFIELD_DURATION
        
        -- Visual effect (Blue Explosion at powerup location)
        table.insert(Game.effects, {
            type = "explosion",
            x = px, y = py,
            radius = 0, maxRadius = 100,
            color = "blue", alpha = 1.0, timer = 0.5
        })
        
        -- Visual effect (Forcefield pulse from all bumpers)
        for _, b in ipairs(Game.bumpers) do
            local bx, by = b.body:getPosition()
            table.insert(Game.effects, {
                type = "forcefield",
                x = bx, y = by,
                radius = 0, maxRadius = Constants.BUMPER_FORCEFIELD_RADIUS * 2,
                alpha = 1.0, timer = Constants.BUMPER_CENTER_FORCEFIELD_DURATION
            })
        end
    else
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
            unit:hit("puck", proj.color)
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
    
    -- CASE 5: BUMPER vs PROJECTILE (activation)
    local bumper, proj
    if objA.type == "bumper" and objB.type == "projectile" then bumper = objA; proj = objB
    elseif objB.type == "bumper" and objA.type == "projectile" then bumper = objB; proj = objA end
    
    if bumper and proj then
        -- Only activate if within activation window and projectile is puck or bomb
        if Game.bumperActivationWindow > 0 and (proj.weaponType == "puck" or proj.weaponType == "bomb") then
            -- Activate all bumpers of the same color
            for _, b in ipairs(Game.bumpers) do
                if b.color == bumper.color then
                    b:activate()
                end
            end
            proj:die()  -- Destroy projectile that activated it
        end
        -- Normal physics restitution handles the bounce
    end
    
    -- CASE 6: BUMPER vs UNIT (removed - now handled in update loop for attraction)
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


function love.load()
    love.window.setMode(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    love.window.setTitle("RageBait!")
    Game.fonts.small = love.graphics.newFont(12)
    Game.fonts.medium = love.graphics.newFont(14)
    Game.fonts.large = love.graphics.newFont(24)
    
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
    
    Event.clear(); Engagement.init(); World.init(); Time.init()
    World.physics:setCallbacks(beginContact, nil, preSolve, nil)
    
    Game.turret = Turret.new()
    Game.score = 0
    Game.powerupSpawnTimer = 5.0
    
    Game.isUpgraded = false;
    Game.hazards = {}; Game.explosionZones = {}; Game.units = {}; Game.projectiles = {}; Game.effects = {}; Game.powerups = {}; Game.bumpers = {}
    
    -- Initialize bumpers aligned with playfield edges
    -- Bumpers are 48x194, positioned so their edges align with playfield boundaries
    local bumperHalfWidth = Constants.BUMPER_WIDTH / 2
    local bumperHalfHeight = Constants.BUMPER_HEIGHT / 2
    
    -- Left edge bumpers (top and bottom) - Blue
    table.insert(Game.bumpers, Bumper.new(bumperHalfWidth, bumperHalfHeight + 123, nil, "blue"))  -- Top-left
    table.insert(Game.bumpers, Bumper.new(bumperHalfWidth, Constants.PLAYFIELD_HEIGHT - bumperHalfHeight - 613, Constants.BUMPER_HEIGHT + 84, "blue"))  -- Bottom-left
    
    -- Right edge bumpers (top and bottom) - Red
    table.insert(Game.bumpers, Bumper.new(Constants.PLAYFIELD_WIDTH - bumperHalfWidth, bumperHalfHeight + 123, nil, "red"))  -- Top-right
    table.insert(Game.bumpers, Bumper.new(Constants.PLAYFIELD_WIDTH - bumperHalfWidth, Constants.PLAYFIELD_HEIGHT - bumperHalfHeight - 613, Constants.BUMPER_HEIGHT + 84, "red"))  -- Bottom-right 
    
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

function love.update(dt)
    if love.keyboard.isDown("escape") then love.event.quit() end
    
    -- Update bumper activation window
    if Game.bumperActivationWindow > 0 then
        Game.bumperActivationWindow = Game.bumperActivationWindow - dt
    end
    
    -- Update bumper forcefield timer
    if Game.bumperForcefieldActive and Game.bumperForcefieldTimer then
        Game.bumperForcefieldTimer = Game.bumperForcefieldTimer - dt
        if Game.bumperForcefieldTimer <= 0 then
            Game.bumperForcefieldActive = false
        end
    end
    
    Game.powerupSpawnTimer = Game.powerupSpawnTimer - dt
    if Game.powerupSpawnTimer <= 0 then
        Game.powerupSpawnTimer = math.random(15, 25)
        local px = math.random(50, Constants.PLAYFIELD_WIDTH - 50)
        -- Randomly spawn either puck or bumper powerup
        local powerupType = math.random() < 0.5 and "bumper" or "puck"
        table.insert(Game.powerups, PowerUp.new(px, -50, powerupType))
    end

    if not Game.isUpgraded and Game.score >= Constants.UPGRADE_SCORE then
    Game.isUpgraded = true
    -- Only upgrade the Puck Lifetime. The Bomb Radius is already maxed!
    Constants.PUCK_LIFETIME = Constants.PUCK_LIFETIME_MAX
    Game.shake = 2.0
    end
    if Game.shake > 0 then Game.shake = math.max(0, Game.shake - 2.5 * dt) end

    Time.checkRestore(dt); Time.update(dt); local gameDt = dt * Time.scale
    Engagement.update(gameDt); World.update(gameDt)
    
    for i = #Game.hazards, 1, -1 do local h = Game.hazards[i]; h.timer = h.timer - dt; if h.timer <= 0 then table.remove(Game.hazards, i) end end
    for i = #Game.explosionZones, 1, -1 do local z = Game.explosionZones[i]; z.timer = z.timer - dt; if z.timer <= 0 then z.body:destroy(); table.remove(Game.explosionZones, i) end end
    for i = #Game.powerups, 1, -1 do local p = Game.powerups[i]; p:update(gameDt); if p.isDead then table.remove(Game.powerups, i) end end
    for _, b in ipairs(Game.bumpers) do b:update(dt) end

    Game.logicTimer = Game.logicTimer + dt
    if Game.logicTimer > 0.1 then
        Game.logicTimer = 0
        
        -- One-time bumper forcefield: push everything towards center
        if Game.bumperForcefieldActive then
            local centerX = Constants.PLAYFIELD_WIDTH / 2
            local centerY = Constants.PLAYFIELD_HEIGHT / 2
            
            -- Push all units towards center
            for _, u in ipairs(Game.units) do
                if not u.isDead then
                    local ux, uy = u.body:getPosition()
                    local dx = centerX - ux
                    local dy = centerY - uy
                    local dist = math.sqrt(dx*dx + dy*dy)
                    
                    if dist > 0 then
                        local force = Constants.BUMPER_CENTER_FORCE
                        local fx = (dx / dist) * force
                        local fy = (dy / dist) * force
                        u.body:applyLinearImpulse(fx, fy)
                    end
                end
            end
            
            -- Push all projectiles towards center
            for _, p in ipairs(Game.projectiles) do
                if not p.isDead then
                    local px, py = p.body:getPosition()
                    local dx = centerX - px
                    local dy = centerY - py
                    local dist = math.sqrt(dx*dx + dy*dy)
                    
                    if dist > 0 then
                        local force = Constants.BUMPER_CENTER_FORCE
                        local fx = (dx / dist) * force
                        local fy = (dy / dist) * force
                        p.body:applyLinearImpulse(fx, fy)
                    end
                end
            end
        end
        
        -- Check units for explosion zones
        for _, u in ipairs(Game.units) do
            if not u.isDead then
                local ux, uy = u.body:getPosition(); local activeZone = nil
                for _, z in ipairs(Game.explosionZones) do
                    local dx = ux - z.x; local dy = uy - z.y
                    if (dx*dx + dy*dy) < (z.radius * z.radius) then activeZone = z; break end
                end
                if activeZone then u:hit("bomb", activeZone.color) end
            end
        end
        
        -- Check units for active bumper attractors
        for _, b in ipairs(Game.bumpers) do
            if b.activated then
                local bx, by = b.body:getPosition()
                local attractRadius = Constants.BUMPER_FORCEFIELD_RADIUS
                
                -- Attract units of matching color toward bumper
                for _, u in ipairs(Game.units) do
                    if not u.isDead and u.alignment == b.color then
                        local ux, uy = u.body:getPosition()
                        local dx = bx - ux  -- Direction toward bumper
                        local dy = by - uy
                        local distSq = dx*dx + dy*dy
                        
                        if distSq < attractRadius * attractRadius and distSq > 0 then
                            local dist = math.sqrt(distSq)
                            -- Attract unit toward bumper (stronger force)
                            -- Use applyForce for continuous attraction instead of impulse
                            local force = Constants.BUMPER_FORCE * 8.0
                            local fx = (dx / dist) * force
                            local fy = (dy / dist) * force
                            u.body:applyForce(fx, fy)
                        end
                    end
                end
            end
        end
    end

    if Game.turret then Game.turret:update(dt, Game.projectiles, Game.isUpgraded) end
    
    -- Apply bumper attraction every frame for smoother effect
    for _, b in ipairs(Game.bumpers) do
        if b.activated then
            local bx, by = b.body:getPosition()
            local centerX = Constants.PLAYFIELD_WIDTH / 2
            local centerY = Constants.PLAYFIELD_HEIGHT / 2
            
            -- Calculate max range: distance from bumper to center of playfield (doubled)
            local dxToCenter = centerX - bx
            local dyToCenter = centerY - by
            local maxRange = math.sqrt(dxToCenter*dxToCenter + dyToCenter*dyToCenter) * 2.0
            
            -- Attract units of matching color toward bumper
            for _, u in ipairs(Game.units) do
                if not u.isDead and u.alignment == b.color and u.alignment ~= "none" then
                    local ux, uy = u.body:getPosition()
                    local dx = bx - ux  -- Direction toward bumper
                    local dy = by - uy
                    local distSq = dx*dx + dy*dy
                    local dist = math.sqrt(distSq)
                    
                    -- Check if unit is within range (from bumper to center)
                    if dist > 0 and dist <= maxRange then
                        -- Calculate falloff: stronger when closer to bumper, weaker near center
                        -- Falloff factor: 1.0 at bumper, 0.0 at center
                        local falloff = 1.0 - (dist / maxRange)
                        falloff = falloff * falloff  -- Quadratic falloff for smoother transition
                        
                        -- Attract unit toward bumper with falloff
                        local baseForce = Constants.BUMPER_FORCE * 10.0 * gameDt
                        local force = baseForce * falloff
                        local fx = (dx / dist) * force
                        local fy = (dy / dist) * force
                        u.body:applyForce(fx, fy)
                    end
                end
            end
        end
    end
    
    for i = #Game.units, 1, -1 do local u = Game.units[i]; u:update(gameDt, Game.units, Game.hazards, Game.explosionZones); if u.isDead then table.remove(Game.units, i) end end
    for i = #Game.projectiles, 1, -1 do local p = Game.projectiles[i]; p:update(gameDt); if p.isDead then table.remove(Game.projectiles, i) end end
    
    for i = #Game.effects, 1, -1 do
        local e = Game.effects[i]; e.timer = e.timer - dt
        if e.type == "explosion" then
            e.radius = e.radius + (e.maxRadius * 8 * dt); if e.radius > e.maxRadius then e.radius = e.maxRadius end; e.alpha = e.timer / 0.5
        elseif e.type == "forcefield" then
            e.radius = e.radius + (e.maxRadius * 4 * dt); if e.radius > e.maxRadius then e.radius = e.maxRadius end
            e.alpha = e.timer / Constants.BUMPER_CENTER_FORCEFIELD_DURATION
        end
        if e.timer <= 0 then table.remove(Game.effects, i) end
    end
end

function love.keypressed(key)
    if not Game.turret then return end
    if key == "z" then Game.turret:startCharge("red")
    elseif key == "x" then Game.turret:startCharge("blue")
    elseif key == "2" then
        -- Debug: Give rapid fire powerup
        Game.turret:activatePuckMode(Constants.POWERUP_DURATION)
    elseif key == "3" then
        -- Debug: Give bumper powerup
        -- Check if any bumpers are already activated
        local anyBumperActive = false
        for _, b in ipairs(Game.bumpers) do
            if b.activated then
                anyBumperActive = true
                break
            end
        end
        
        -- Give new activation window unless any bumper is already active
        if not anyBumperActive then
            Game.bumperActivationWindow = Constants.BUMPER_ACTIVATION_WINDOW
        end
        
        -- Trigger one-time forcefield from all bumpers
        Game.bumperForcefieldActive = true
        Game.bumperForcefieldTimer = Constants.BUMPER_CENTER_FORCEFIELD_DURATION
        
        -- Visual effect (Forcefield pulse from all bumpers)
        for _, b in ipairs(Game.bumpers) do
            local bx, by = b.body:getPosition()
            table.insert(Game.effects, {
                type = "forcefield",
                x = bx, y = by,
                radius = 0, maxRadius = Constants.BUMPER_FORCEFIELD_RADIUS * 2,
                alpha = 1.0, timer = Constants.BUMPER_CENTER_FORCEFIELD_DURATION
            })
        end
    end
end

function love.keyreleased(key)
    if not Game.turret then return end
    if key == "z" or key == "x" then Game.turret:releaseCharge(Game.projectiles) end
end

function love.draw()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw background image if loaded (full screen)
    if Game.background then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Game.background, 0, 0, 0, 
            Constants.SCREEN_WIDTH / Game.background:getWidth(),
            Constants.SCREEN_HEIGHT / Game.background:getHeight())
    end
    
    love.graphics.push()
    if Game.shake > 0 then
        local s = Game.shake * Game.shake * 15; love.graphics.translate(love.math.random(-s, s), love.math.random(-s, s))
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
        
        for _, b in ipairs(Game.bumpers) do b:draw() end
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
    love.graphics.pop()
    
    -- Draw foreground image if loaded (full screen, on top of game elements)
    if Game.foreground then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Game.foreground, 0, 0, 0, 
            Constants.SCREEN_WIDTH / Game.foreground:getWidth(),
            Constants.SCREEN_HEIGHT / Game.foreground:getHeight())
    end
    
    drawHUD()
end

function drawHUD()
    love.graphics.setColor(0, 1, 0); love.graphics.setFont(Game.fonts.medium); love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)

    local barW, barH = 400, 40; local barX = (Constants.SCREEN_WIDTH - barW)/2; local barY = 80
    local pct = Engagement.value / Constants.ENGAGEMENT_MAX
    love.graphics.setColor(0.2, 0.2, 0.2); love.graphics.rectangle("fill", barX, barY, barW, barH)
    if pct < 0.25 then love.graphics.setColor(1, 0, 0) elseif pct < 0.5 then love.graphics.setColor(1, 1, 0) else love.graphics.setColor(0, 1, 0) end
    love.graphics.rectangle("fill", barX+2, barY+2, (barW-4)*pct, barH-4)
    love.graphics.setColor(1, 1, 1); love.graphics.print("ENGAGEMENT", barX, barY - 20)
    love.graphics.setFont(Game.fonts.large); love.graphics.print("SCORE: " .. Game.score, barX, barY + 50)
    
    if Game.isUpgraded then love.graphics.setColor(1, 1, 0); love.graphics.print("WEAPONS UPGRADED!", barX + 60, barY + 80) end
    
    if Game.turret and Game.turret.puckModeTimer > 0 then
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.print("RAPID FIRE ACTIVE: " .. math.ceil(Game.turret.puckModeTimer), barX + 80, barY + 110)
    elseif Game.bumperActivationWindow > 0 then
        love.graphics.setColor(0.2, 0.6, 1)
        love.graphics.print("FIRE ON BUMPERS: " .. math.ceil(Game.bumperActivationWindow) .. "s", barX + 80, barY + 110)
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Game.fonts.small)
        love.graphics.print("Hold Z/X to charge Bomb. Collect Powerup for Rapid Fire.", barX + 50, barY + 110)
    end
end