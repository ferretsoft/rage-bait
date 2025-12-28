local Constants = require("src.constants")
local World = require("src.core.world")
local Event = require("src.core.event")

local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(x, y, angle, weaponType, color, chargeDist)
    local self = setmetatable({}, Projectile)
    
    self.type = "projectile"
    self.weaponType = weaponType 
    self.color = color
    self.isDead = false
    self.timer = 0
    
    self.trail = {} 
    self.maxTrail = 300 
    self.trailTimer = 0
    
    local speed = (weaponType == "puck") and 800 or 500
    local radius = (weaponType == "puck") and 5 or 15
    
    if weaponType == "puck" then
        self.body = love.physics.newBody(World.physics, x, y, "dynamic")
        self.body:setLinearDamping(0) 
        self.body:setBullet(true) 
    elseif weaponType == "bomb" then
        local maxRange = Constants.BOMB_RANGE_MAX or 900
        
        -- [FIX] Safe check with fallback
        local lifetime = Constants.PUCK_LIFETIME or 4.0
        if lifetime < 1.0 then 
            maxRange = Constants.BOMB_RANGE_BASE or 300
        end
        
        local dist = math.min(chargeDist or 100, maxRange)
        self.targetX = x + math.cos(angle) * dist
        self.targetY = y + math.sin(angle) * dist
        self.body = love.physics.newBody(World.physics, x, y, "kinematic")
    end
    
    self.shape = love.physics.newCircleShape(radius)
    self.fixture = love.physics.newFixture(self.body, self.shape, 1)
    self.fixture:setRestitution(0.8)
    self.fixture:setCategory(Constants.PHYSICS.PUCK)
    self.fixture:setUserData(self)
    
    if weaponType == "bomb" then
        self.fixture:setSensor(true)
    else
        self.body:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
    end
    
    return self
end

function Projectile:update(dt)
    if self.isDead then return end
    self.timer = self.timer + dt
    
    self.trailTimer = self.trailTimer + dt
    if self.trailTimer > 0.01 then 
        self.trailTimer = 0
        local bx, by = self.body:getPosition()
        table.insert(self.trail, 1, {x = bx, y = by, alpha = 1.0})
        if #self.trail > self.maxTrail then table.remove(self.trail) end
    end
    
    for i, t in ipairs(self.trail) do
        t.alpha = t.alpha - (dt * 0.3) 
    end

    -- Boundary checking - keep projectiles within playfield
    local bx, by = self.body:getPosition()
    local radius = self.shape:getRadius()
    local margin = radius + 5  -- Small margin to prevent edge cases
    
    -- Only apply boundary checks if projectile is inside playfield (0 < y < PLAYFIELD_HEIGHT)
    -- This allows projectiles to enter from below without interference
    if by >= 0 and by <= Constants.PLAYFIELD_HEIGHT then
        -- Check boundaries and bounce back if outside
        if bx < margin then
            self.body:setX(margin)
            local vx, vy = self.body:getLinearVelocity()
            self.body:setLinearVelocity(-vx * 0.9, vy)  -- Bounce off left wall
        elseif bx > Constants.PLAYFIELD_WIDTH - margin then
            self.body:setX(Constants.PLAYFIELD_WIDTH - margin)
            local vx, vy = self.body:getLinearVelocity()
            self.body:setLinearVelocity(-vx * 0.9, vy)  -- Bounce off right wall
        end
        
        if by < margin then
            self.body:setY(margin)
            local vx, vy = self.body:getLinearVelocity()
            self.body:setLinearVelocity(vx, -vy * 0.9)  -- Bounce off top wall
        elseif by > Constants.PLAYFIELD_HEIGHT - margin then
            -- Bottom barrier: only apply if projectile is moving downward (trying to exit)
            local vx, vy = self.body:getLinearVelocity()
            if vy > 0 then
                -- Projectile is moving downward - apply barrier
                self.body:setY(Constants.PLAYFIELD_HEIGHT - margin)
                self.body:setLinearVelocity(vx, -vy * 0.9)  -- Bounce off bottom wall
            end
        end
    end

    if self.weaponType == "puck" then
        -- [FIX] Added 'or 4.0' to prevent nil crash
        local limit = Constants.PUCK_LIFETIME or 4.0
        if self.timer > limit then self:die() end
    elseif self.weaponType == "bomb" then
        -- Clamp target position to be within playfield bounds
        self.targetX = math.max(margin, math.min(Constants.PLAYFIELD_WIDTH - margin, self.targetX))
        self.targetY = math.max(margin, math.min(Constants.PLAYFIELD_HEIGHT - margin, self.targetY))
        
        local dx = self.targetX - bx
        local dy = self.targetY - by
        local distSq = dx*dx + dy*dy
        
        if distSq < 15*15 then
            self:explode()
        else
            local angle = math.atan2(dy, dx)
            local s = 500
            self.body:setLinearVelocity(math.cos(angle)*s, math.sin(angle)*s)
        end
    end
end

function Projectile:explode()
    if self.isDead then return end
    self:die()
    Event.emit("bomb_exploded", {
        x = self.targetX, 
        y = self.targetY, 
        radius = Constants.EXPLOSION_RADIUS or 75, -- [FIX] Added safety fallback
        color = self.color
    })
end

function Projectile:die()
    if self.isDead then return end
    self.isDead = true
    if self.body then self.body:destroy() end
end

function Projectile:draw()
    if self.isDead then return end
    
    local r, g, b = 0.2, 0.2, 1
    if self.color == "red" then r, g, b = 1, 0.2, 0.2 end
    
    local px, py = self.body:getPosition()
    for i, t in ipairs(self.trail) do
        if t.alpha > 0 then
            love.graphics.setLineWidth((self.weaponType == "puck" and 4 or 10) * t.alpha)
            love.graphics.setColor(r, g, b, t.alpha * 0.5)
            love.graphics.line(px, py, t.x, t.y)
            px, py = t.x, t.y
        end
    end
    
    love.graphics.setColor(r, g, b, 1)
    love.graphics.circle("fill", self.body:getX(), self.body:getY(), self.shape:getRadius())
end

return Projectile