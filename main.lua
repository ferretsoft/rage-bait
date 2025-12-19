local Constants = require("src.constants")
local Event = require("src.core.event")
local Engagement = require("src.core.engagement")
local World = require("src.core.world")
local Time = require("src.core.time")
local Unit = require("src.entities.unit")
local Turret = require("src.entities.turret")
local Projectile = require("src.entities.projectile")

local Game = {
    units = {},
    projectiles = {},
    effects = {}, 
    hazards = {},
    explosionZones = {}, 
    turret = nil,
    score = 0,
    shake = 0,
    logicTimer = 0,
    isUpgraded = false,
    fonts = {
        small = nil,
        medium = nil,
        large = nil
    }
}

-- --- PHYSICS COLLISION CALLBACKS ---

local function beginContact(a, b, coll)
    local objA = a:getUserData()
    local objB = b:getUserData()
    if not objA or not objB then return end

    -- CASE 1: UNIT vs UNIT
    if objA.type == "unit" and objB.type == "unit" then
        if objA.state == "neutral" or objB.state == "neutral" then return end
        if objA.alignment == objB.alignment then return end
        
        objA:takeDamage(1, objB)
        objB:takeDamage(1, objA)
        
        Game.score = Game.score + (Constants.SCORE_HIT * 2)
        Engagement.add(Constants.ENGAGEMENT_REFILL_HIT * 2)
        
        -- Bounce logic
        local vxA, vyA = objA.body:getLinearVelocity()
        local vxB, vyB = objB.body:getLinearVelocity()
        local speedA = math.sqrt(vxA^2 + vyA^2)
        local speedB = math.sqrt(vxB^2 + vyB^2)
        local advantageThreshold = 150 
        
        if speedA > speedB + advantageThreshold then
            objA.body:setLinearVelocity(-vxA * 0.3, -vyA * 0.3)
        elseif speedB > speedA + advantageThreshold then
            objB.body:setLinearVelocity(-vxB * 0.3, -vyB * 0.3)
        end
        return
    end
    
    -- CASE 2: PROJECTILE vs UNIT
    local unit, proj
    if objA.type == "unit" and objB.type == "projectile" then
        unit = objA; proj = objB
    elseif objB.type == "unit" and objA.type == "projectile" then
        unit = objB; proj = objA
    end
    
    if unit and proj then
        if proj.weaponType == "puck" then
            unit:hit("puck", proj.color)
            proj:die() 
        end
    end
end

local function preSolve(a, b, coll)
    local objA = a:getUserData()
    local objB = b:getUserData()
    if not objA or not objB then return end
    
    local zone, proj
    if objA.type == "zone" and objB.type == "projectile" then
        zone = objA; proj = objB
    elseif objB.type == "zone" and objA.type == "projectile" then
        zone = objB; proj = objA
    end
    
    if zone and proj then
        if proj.weaponType == "bomb" then
            coll:setEnabled(false)
        else
            -- Pucks pass through SAME color zones, collide with DIFFERENT color
            if zone.color == proj.color then
                coll:setEnabled(false) 
            else
                coll:setEnabled(true)  
            end
        end
    end
end

-- --- LOVE CALLBACKS ---

function love.load()
    love.window.setMode(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    love.window.setTitle("Arcade War")
    
    Game.fonts.small = love.graphics.newFont(12)
    Game.fonts.medium = love.graphics.newFont(14)
    Game.fonts.large = love.graphics.newFont(24)
    
    Event.clear() 
    Engagement.init()
    World.init()
    World.physics:setCallbacks(beginContact, nil, preSolve, nil)
    Time.init()
    
    Game.turret = Turret.new()
    Game.score = 0
    Game.shake = 0
    
    -- Reset Logic
    Game.isUpgraded = false
    -- Reset Constants to weak start values
    Constants.EXPLOSION_RADIUS = 30
    Constants.PUCK_LIFETIME = 0.6
    
    Game.hazards = {}
    Game.explosionZones = {}
    Game.units = {}
    Game.projectiles = {}
    Game.effects = {}
    
    -- Initial Spawn
    for i=1, 20 do
        local x = math.random(50, Constants.PLAYFIELD_WIDTH - 50)
        local y = math.random(50, Constants.PLAYFIELD_HEIGHT - 300)
        table.insert(Game.units, Unit.new(World.physics, x, y))
    end
    
    -- EVENT: BOMB EXPLODED
    Event.on("bomb_exploded", function(data)
        Time.slowDown(0.1, 0.5)
        Game.shake = 1.0
        
        -- Visual Explosion
        table.insert(Game.effects, {
            type = "explosion",
            x = data.x, y = data.y,
            radius = 0, maxRadius = data.radius,
            color = data.color, alpha = 1.0, timer = 0.5
        })
        
        -- Logic: Create Persistent Zone
        local blocked = false
        for _, z in ipairs(Game.explosionZones) do
            local dx = data.x - z.x
            local dy = data.y - z.y
            local distSq = dx*dx + dy*dy
            if distSq < (z.radius * z.radius) then
                if z.color ~= data.color then
                    blocked = true
                    break
                end
            end
        end
        
        if blocked then return end
        
        -- Cap max zones to prevent clutter (Max 5)
        if #Game.explosionZones >= 5 then
            local oldZ = table.remove(Game.explosionZones, 1)
            if oldZ and oldZ.body then oldZ.body:destroy() end
        end
        
        local body = love.physics.newBody(World.physics, data.x, data.y, "static")
        local shape = love.physics.newCircleShape(data.radius)
        local fixture = love.physics.newFixture(body, shape)
        fixture:setCategory(Constants.PHYSICS.ZONE)
        fixture:setUserData({ type = "zone", color = data.color })
        
        table.insert(Game.explosionZones, {
            x = data.x, 
            y = data.y, 
            radius = data.radius, 
            color = data.color, 
            timer = Constants.EXPLOSION_DURATION,
            body = body 
        })
    end)
    
    -- EVENT: UNIT KILLED
    Event.on("unit_killed", function(data)
        Game.score = Game.score + Constants.SCORE_KILL
        Engagement.add(Constants.ENGAGEMENT_REFILL_KILL)
        Game.shake = math.max(Game.shake, 0.2)
        
        local x, y = data.victim.body:getPosition()
        table.insert(Game.hazards, {
            x = x, y = y, radius = Constants.TOXIC_RADIUS, timer = Constants.TOXIC_DURATION
        })
    end)
end

function love.update(dt)
    if love.keyboard.isDown("escape") then love.event.quit() end

    -- [UPGRADE LOGIC]
    if not Game.isUpgraded and Game.score >= Constants.UPGRADE_SCORE then
        Game.isUpgraded = true
        Constants.EXPLOSION_RADIUS = Constants.EXPLOSION_RADIUS_MAX
        Constants.PUCK_LIFETIME = Constants.PUCK_LIFETIME_MAX
        Game.shake = 2.0 -- Big shake on upgrade
    end

    if Game.shake > 0 then
        Game.shake = Game.shake - (2.5 * dt)
        if Game.shake < 0 then Game.shake = 0 end
    end

    Time.checkRestore(dt)
    Time.update(dt)
    local gameDt = dt * Time.scale

    Engagement.update(gameDt)
    World.update(gameDt)
    
    -- Cleanup Hazards
    for i = #Game.hazards, 1, -1 do
        local h = Game.hazards[i]
        h.timer = h.timer - dt
        if h.timer <= 0 then table.remove(Game.hazards, i) end
    end
    
    -- Cleanup Zones
    for i = #Game.explosionZones, 1, -1 do
        local z = Game.explosionZones[i]
        z.timer = z.timer - dt
        if z.timer <= 0 then
            z.body:destroy() 
            table.remove(Game.explosionZones, i)
        end
    end
    
    -- Throttled Zone Damage Logic (Optimization)
    Game.logicTimer = Game.logicTimer + dt
    if Game.logicTimer > 0.1 then
        Game.logicTimer = 0
        for _, u in ipairs(Game.units) do
            if not u.isDead then
                local ux, uy = u.body:getPosition()
                local activeZone = nil
                for _, z in ipairs(Game.explosionZones) do
                    local dx = ux - z.x
                    local dy = uy - z.y
                    local distSq = dx*dx + dy*dy
                    if distSq < (z.radius * z.radius) then
                        activeZone = z
                        break 
                    end
                end
                if activeZone then
                    u:hit("bomb", activeZone.color)
                end
            end
        end
    end

    -- [UPDATE TURRET] Passing projectiles list for rapid fire
    if Game.turret then 
        Game.turret:update(dt, Game.projectiles) 
    end
    
    -- Update Units
    for i = #Game.units, 1, -1 do
        local u = Game.units[i]
        u:update(gameDt, Game.units, Game.hazards, Game.explosionZones)
        if u.isDead then table.remove(Game.units, i) end
    end
    
    -- Update Projectiles
    for i = #Game.projectiles, 1, -1 do
        local p = Game.projectiles[i]
        p:update(gameDt)
        if p.isDead then table.remove(Game.projectiles, i) end
    end
    
    -- Update Effects
    for i = #Game.effects, 1, -1 do
        local e = Game.effects[i]
        e.timer = e.timer - dt
        if e.type == "explosion" then
            e.radius = e.radius + (e.maxRadius * 8 * dt)
            if e.radius > e.maxRadius then e.radius = e.maxRadius end
            e.alpha = e.timer / 0.5
        end
        if e.timer <= 0 then table.remove(Game.effects, i) end
    end
end

function love.keypressed(key)
    if not Game.turret then return end
    
    -- [BOMB LOGIC ONLY] 
    -- Pucks are now handled in Turret:update() for rapid fire.
    local isModDown = love.keyboard.isDown("down") or love.keyboard.isDown("s")
    
    if key == "z" then
        if isModDown then Game.turret:startCharge("red") end
    elseif key == "x" then
        if isModDown then Game.turret:startCharge("blue") end
    end
end

function love.keyreleased(key)
    if not Game.turret then return end
    if key == "z" or key == "x" then 
        Game.turret:releaseCharge(Game.projectiles) 
    end
end

function love.draw()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    love.graphics.push()
    
    -- Screen Shake
    if Game.shake > 0 then
        local maxOffset = 15
        local shakeAmount = Game.shake * Game.shake * maxOffset
        love.graphics.translate(love.math.random(-shakeAmount, shakeAmount), love.math.random(-shakeAmount, shakeAmount))
    end
    
    -- DRAW WORLD (Handles centering translation internally via src/core/world.lua)
    World.draw(function()
        -- 1. Hazards
        for _, h in ipairs(Game.hazards) do
            local r, g, b = unpack(Constants.COLORS.TOXIC)
            local alpha = (h.timer / Constants.TOXIC_DURATION) * 0.4
            love.graphics.setColor(r, g, b, alpha)
            love.graphics.circle("fill", h.x, h.y, h.radius)
            love.graphics.setLineWidth(2)
            love.graphics.setColor(r, g, b, alpha + 0.2)
            love.graphics.circle("line", h.x, h.y, h.radius)
        end
        
        -- 2. Stencil Zones (Overlapping explosions)
        if #Game.explosionZones > 0 then
            love.graphics.clear(false, true, false) 
            
            for _, z in ipairs(Game.explosionZones) do
                love.graphics.setStencilTest("equal", 0)
                if z.color == "red" then love.graphics.setColor(1, 0, 0, 0.3)
                else love.graphics.setColor(0, 0, 1, 0.3) end
                
                love.graphics.circle("fill", z.x, z.y, z.radius, 64)
                love.graphics.setLineWidth(3)
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.circle("line", z.x, z.y, z.radius, 64)
                
                love.graphics.setStencilTest()
                love.graphics.stencil(function()
                    love.graphics.circle("fill", z.x, z.y, z.radius, 64)
                end, "replace", 1)
            end
            love.graphics.setStencilTest()
        end
        
        -- 3. Game Objects
        for _, u in ipairs(Game.units) do u:draw() end
        for _, p in ipairs(Game.projectiles) do p:draw() end
        
        -- 4. Effects
        for _, e in ipairs(Game.effects) do
            if e.type == "explosion" then
                love.graphics.setLineWidth(3)
                if e.color == "red" then love.graphics.setColor(1, 0.2, 0.2, e.alpha)
                else love.graphics.setColor(0.2, 0.2, 1, e.alpha) end
                
                love.graphics.circle("line", e.x, e.y, e.radius, 64)
                love.graphics.setColor(1, 1, 1, e.alpha * 0.2)
                love.graphics.circle("fill", e.x, e.y, e.radius, 64)
            end
        end
        
        -- 5. Turret (Always on top)
        if Game.turret then Game.turret:draw() end
    end)
    
    love.graphics.pop()
    
    drawHUD()
end

function drawHUD()
    -- FPS
    love.graphics.setColor(0, 1, 0)
    love.graphics.setFont(Game.fonts.medium) 
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)

    -- ENGAGEMENT BAR
    local barW, barH = 400, 40
    local barX = (Constants.SCREEN_WIDTH - barW)/2
    local barY = 80
    local pct = Engagement.value / Constants.ENGAGEMENT_MAX
    
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", barX, barY, barW, barH)
    
    if pct < 0.25 then love.graphics.setColor(1, 0, 0)
    elseif pct < 0.5 then love.graphics.setColor(1, 1, 0)
    else love.graphics.setColor(0, 1, 0) end
    
    love.graphics.rectangle("fill", barX+2, barY+2, (barW-4)*pct, barH-4)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("ENGAGEMENT", barX, barY - 20)
    
    -- SCORE
    love.graphics.setFont(Game.fonts.large)
    love.graphics.print("SCORE: " .. Game.score, barX, barY + 50)
    
    -- UPGRADE NOTIFICATION
    if Game.isUpgraded then
        love.graphics.setColor(1, 1, 0)
        love.graphics.print("WEAPONS UPGRADED!", barX + 60, barY + 80)
    end
    
    -- CONTROLS
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Game.fonts.small)
    love.graphics.print("Z: Red Puck (Hold) | X: Blue Puck (Hold) | Down+Z/X: Charge Bomb", 50, Constants.SCREEN_HEIGHT - 50)
    love.graphics.print("Units: " .. #Game.units, 50, 150)
end