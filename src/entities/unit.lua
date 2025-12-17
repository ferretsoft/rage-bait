local Constants = require("src.constants")
local Event = require("src.core.event")

local Unit = {}
Unit.__index = Unit

function Unit.new(world, x, y)
    local self = setmetatable({}, Unit)
    
    self.type = "unit"
    self.state = "neutral" 
    self.alignment = "none"
    
    self.hp = Constants.UNIT_HP 
    self.isDead = false
    
    self.enrageTimer = 0 
    self.flashTimer = 0  
    
    -- PHYSICS SETUP
    self.body = love.physics.newBody(world, x, y, "dynamic")
    self.shape = love.physics.newCircleShape(Constants.UNIT_RADIUS)
    -- Density 8 keeps them heavy despite small size
    self.fixture = love.physics.newFixture(self.body, self.shape, 8) 
    self.fixture:setRestitution(0.5) 
    self.fixture:setCategory(Constants.PHYSICS.UNIT)
    self.fixture:setMask(Constants.PHYSICS.ZONE) 
    self.fixture:setUserData(self)
    
    self.body:setLinearDamping(Constants.UNIT_DAMPING)
    
    self.wanderTimer = 0
    self.currentMoveAngle = math.random() * math.pi * 2
    
    return self
end

function Unit:update(dt, allUnits, hazards, explosionZones)
    if self.isDead then return end
    
    if self.state == "enraged" then
        self.enrageTimer = self.enrageTimer - dt
        self.flashTimer = self.flashTimer + dt
        
        if self.enrageTimer <= 0 then
            self.state = "passive"
        end
        
        self:updateEnraged(dt, allUnits)
    else
        -- NEUTRAL / PASSIVE BEHAVIOR
        local isAttracted = false
        if self.state == "neutral" and explosionZones then
            isAttracted = self:seekAttractions(dt, explosionZones)
        end
        
        if not isAttracted then
            self:updateWander(dt)
        end
        
        self:avoidNeighbors(dt, allUnits)
        
        if hazards then self:avoidHazards(dt, hazards) end
        
        -- [REMOVED] avoidProjectiles logic
    end
    
    self:avoidWalls(dt)
end

function Unit:seekAttractions(dt, zones)
    local myX, myY = self.body:getPosition()
    local bestZone = nil
    local minDist = 999999
    
    for _, z in ipairs(zones) do
        local distSq = (z.x - myX)^2 + (z.y - myY)^2
        local range = Constants.EXPLOSION_ATTRACTION_RADIUS
        
        if distSq < range^2 and distSq < minDist then
            minDist = distSq
            bestZone = z
        end
    end
    
    if bestZone then
        local angle = math.atan2(bestZone.y - myY, bestZone.x - myX)
        local force = self.body:getMass() * 300 
        self.body:applyForce(math.cos(angle) * force, math.sin(angle) * force)
        return true 
    end
    
    return false
end

function Unit:avoidHazards(dt, hazards)
    local myX, myY = self.body:getPosition()
    local mass = self.body:getMass()
    
    for _, hazard in ipairs(hazards) do
        local dx = myX - hazard.x
        local dy = myY - hazard.y
        local distSq = dx*dx + dy*dy
        
        local fearRadius = Constants.TOXIC_RADIUS + 20
        
        if distSq < fearRadius^2 and distSq > 0 then
            local dist = math.sqrt(distSq)
            local force = mass * 1500 
            self.body:applyForce((dx/dist) * force, (dy/dist) * force)
            self.currentMoveAngle = math.atan2(dy, dx)
        end
    end
end

function Unit:updateEnraged(dt, allUnits)
    if not self.target or self.target.isDead then
        self.target = self:findClosestEnemy(allUnits)
    end
    
    if self.target then
        local myX, myY = self.body:getPosition()
        local tX, tY = self.target.body:getPosition()
        local dx = tX - myX
        local dy = tY - myY
        local dist = math.sqrt(dx^2 + dy^2)
        
        if dist > 0 then
            local vx, vy = self.body:getLinearVelocity()
            local currentSpeed = math.sqrt(vx^2 + vy^2)
            
            if currentSpeed < Constants.UNIT_SPEED_SEEK then
                local force = self.body:getMass() * 1000
                local dirX = dx / dist
                local dirY = dy / dist
                self.body:applyForce(dirX * force, dirY * force)
            end
        end
    else
        self:updateWander(dt) 
    end
end

function Unit:hit(weaponType, color)
    if self.isDead then return end

    if self.state == "neutral" then
        self.alignment = color
        self.state = "passive"
        local vx, vy = self.body:getLinearVelocity()
        self.body:setLinearVelocity(vx * 1.2, vy * 1.2)

    elseif self.state == "passive" then
        if self.alignment ~= color then
            self:enrage()
        end
    elseif self.state == "enraged" then
        if self.alignment ~= color then
            self.enrageTimer = Constants.UNIT_ENRAGE_DURATION
        end
    end
end

function Unit:enrage()
    self.state = "enraged"
    self.hp = self.hp + 2
    self.enrageTimer = Constants.UNIT_ENRAGE_DURATION
    
    local angle = math.random() * math.pi * 2
    local burst = Constants.UNIT_SPEED_SEEK * 2 
    self.body:setLinearVelocity(math.cos(angle) * burst, math.sin(angle) * burst)
end

function Unit:draw()
    if self.isDead then return end
    
    local x, y = self.body:getPosition()
    
    if self.state == "enraged" then
        local shakeAmount = 2
        x = x + love.math.random(-shakeAmount, shakeAmount)
        y = y + love.math.random(-shakeAmount, shakeAmount)
    end
    
    local r, g, b, a = 1, 1, 1, 1
    
    if self.state == "neutral" then 
        r, g, b = unpack(Constants.COLORS.GREY)
    elseif self.alignment == "red" then 
        r, g, b = unpack(Constants.COLORS.RED)
    elseif self.alignment == "blue" then 
        r, g, b = unpack(Constants.COLORS.BLUE)
    end
    
    local healthPct = self.hp / Constants.UNIT_HP
    r = r * healthPct
    g = g * healthPct
    b = b * healthPct

    if self.state == "enraged" then
        local flash = (math.sin(self.flashTimer * 15) + 1) / 2 
        r = r + (1 - r) * flash * 0.6 
        g = g + (1 - g) * flash * 0.6
        b = b + (1 - b) * flash * 0.6
    end
    
    love.graphics.setColor(r, g, b, a)
    love.graphics.circle("fill", x, y, Constants.UNIT_RADIUS)
    
    if self.state == "enraged" then
        local fadeAlpha = self.enrageTimer / Constants.UNIT_ENRAGE_DURATION
        love.graphics.setColor(1, 1, 1, fadeAlpha)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", x, y, Constants.UNIT_RADIUS + 4)
    end
end

function Unit:avoidNeighbors(dt, allUnits)
    local separationRadius = 30
    local mass = self.body:getMass()
    local separationForce = mass * 500 
    
    local myX, myY = self.body:getPosition()
    local count = 0
    local pushX, pushY = 0, 0
    
    for _, other in ipairs(allUnits) do
        if other ~= self and not other.isDead then
            local ox, oy = other.body:getPosition()
            local dx = myX - ox
            local dy = myY - oy
            local distSq = dx*dx + dy*dy
            if distSq < separationRadius^2 and distSq > 0 then
                local dist = math.sqrt(distSq)
                pushX = pushX + (dx / dist) / dist
                pushY = pushY + (dy / dist) / dist
                count = count + 1
            end
        end
    end
    
    if count > 0 then
        self.body:applyForce(pushX * separationForce, pushY * separationForce)
    end
end

function Unit:updateWander(dt)
    self.wanderTimer = self.wanderTimer - dt
    if self.wanderTimer <= 0 then
        self.wanderTimer = math.random(0.1, 0.4)
        local change = math.rad(math.random(-45, 45))
        self.currentMoveAngle = self.currentMoveAngle + change
    end
    
    local vx, vy = self.body:getLinearVelocity()
    local currentSpeed = math.sqrt(vx^2 + vy^2)
    
    if currentSpeed < Constants.UNIT_SPEED_NEUTRAL then
        local forceMag = self.body:getMass() * 300 
        self.body:applyForce(math.cos(self.currentMoveAngle)*forceMag, math.sin(self.currentMoveAngle)*forceMag)
    end
end

function Unit:avoidWalls(dt)
    local x, y = self.body:getPosition()
    local pushBack = self.body:getMass() * 2000 
    local margin = 60 
    
    if x < margin then 
        self.body:applyForce(pushBack*dt, 0)
        self.currentMoveAngle = 0 
    end
    if x > Constants.PLAYFIELD_WIDTH - margin then 
        self.body:applyForce(-pushBack*dt, 0)
        self.currentMoveAngle = math.pi 
    end
    if y < margin then 
        self.body:applyForce(0, pushBack*dt)
        self.currentMoveAngle = math.pi/2 
    end
    if y > Constants.PLAYFIELD_HEIGHT - margin then 
        self.body:applyForce(0, -pushBack*dt)
        self.currentMoveAngle = -math.pi/2 
    end
end

function Unit:findClosestEnemy(allUnits)
    local closest = nil
    local minDist = 999999
    local myX, myY = self.body:getPosition()
    
    for _, other in ipairs(allUnits) do
        if not other.isDead and other ~= self then
            local isEnemy = false
            if self.alignment == "red" and other.alignment == "blue" then isEnemy = true end
            if self.alignment == "blue" and other.alignment == "red" then isEnemy = true end
            
            if isEnemy then
                local ox, oy = other.body:getPosition()
                local dist = (ox - myX)^2 + (oy - myY)^2 
                if dist < minDist then
                    minDist = dist
                    closest = other
                end
            end
        end
    end
    return closest
end

function Unit:takeDamage(amount, source)
    if self.isDead then return end
    self.hp = self.hp - amount
    if self.hp <= 0 then
        self:die(source)
    end
end

function Unit:die(killer)
    if self.isDead then return end
    self.isDead = true
    self.body:destroy() 
    Event.emit("unit_killed", {victim = self, killer = killer})
end

return Unit