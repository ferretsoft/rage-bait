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
    
    -- TRAIL DATA
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
        -- [FIX] Use the Constant directly. 
        -- If main.lua updates Constants.BOMB_RANGE_MAX, this works automatically.
        local maxRange = Constants.BOMB_RANGE_MAX or 900
        -- If we haven't reached 1000 points yet, we cap it at 300
        if Constants.PUCK_LIFETIME < 1.0 then -- This is a clever way to check "Upgrade" state
            maxRange = 300
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
    
    -- Update Trail
    self.trailTimer = self.trailTimer + dt
    if self.trailTimer > 0.01 then 
        self.trailTimer = 0
        local bx, by = self.body:getPosition()
        table.insert(self.trail, 1, {x = bx, y = by, alpha = 1.0})
        if #self.trail > self.maxTrail then table.remove(self.trail) end
    end
    
    -- Fade Trail
    for i, t in ipairs(self.trail) do
        t.alpha = t.alpha - (dt * 0.3) 
    end

    if self.weaponType == "puck" then
        if self.timer > Constants.PUCK_LIFETIME then self:die() end
    elseif self.weaponType == "bomb" then
        local bx, by = self.body:getPosition()
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
        radius = Constants.EXPLOSION_RADIUS, 
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
    
    -- Draw Trail Line
    local px, py = self.body:getPosition()
    for i, t in ipairs(self.trail) do
        if t.alpha > 0 then
            love.graphics.setLineWidth((self.weaponType == "puck" and 4 or 10) * t.alpha)
            love.graphics.setColor(r, g, b, t.alpha * 0.5)
            love.graphics.line(px, py, t.x, t.y)
            px, py = t.x, t.y
        end
    end
    
    -- Draw Projectile Head
    love.graphics.setColor(r, g, b, 1)
    love.graphics.circle("fill", self.body:getX(), self.body:getY(), self.shape:getRadius())
end

return Projectile