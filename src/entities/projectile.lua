local Constants = require("src.constants")
local World = require("src.core.world")
local Event = require("src.core.event")
local Sound = require("src.core.sound")

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
    
    local speed = (weaponType == "puck") and 1200 or 500
    local radius = (weaponType == "puck") and 5 or 15
    if weaponType == "shotgun" and Constants.SHOTGUN then
        speed = Constants.SHOTGUN.PELLET_SPEED
        radius = Constants.SHOTGUN.PELLET_RADIUS
    elseif weaponType == "viral" and Constants.VIRAL then
        speed = Constants.VIRAL.PROJECTILE_SPEED
        radius = Constants.VIRAL.PROJECTILE_RADIUS
    elseif weaponType == "rage_bait" and Constants.RAGE_BAIT then
        radius = Constants.RAGE_BAIT.CANISTER_RADIUS
    end
    
    if weaponType == "puck" or weaponType == "shotgun" or weaponType == "viral" then
        self.body = love.physics.newBody(World.physics, x, y, "dynamic")
        self.body:setLinearDamping(0) 
        self.body:setBullet(true)
        if weaponType == "shotgun" then
            self.body:setMass(0.5)
        end
    elseif weaponType == "bomb" or weaponType == "hashtag_canister" or weaponType == "rage_bait" then
        local maxRange = Constants.BOMB_RANGE_MAX or 900
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
    
    if weaponType == "bomb" or weaponType == "hashtag_canister" or weaponType == "rage_bait" then
        self.fixture:setSensor(true)
        local maxRange = Constants.BOMB_RANGE_MAX or 900
        local dist = math.min(chargeDist or 100, maxRange)
        local normalizedDist = math.min(dist / maxRange, 1.0)
        local initialPitch = 0.5 + normalizedDist * 1.0
        self.whistleSound = Sound.playWhistle(0.4, initialPitch, true)
    else
        self.body:setLinearVelocity(math.cos(angle) * speed, math.sin(angle) * speed)
        self.whistleSound = nil
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
            local vx, vy = self.body:getLinearVelocity()
            if vy > 0 then
                self.body:setY(Constants.PLAYFIELD_HEIGHT - margin)
                self.body:setLinearVelocity(vx, -vy * 0.9)
            end
        end
    end

    if self.weaponType == "puck" or self.weaponType == "shotgun" or self.weaponType == "viral" then
        local limit = Constants.PUCK_LIFETIME or 4.0
        if self.timer > limit then self:die() end
    elseif self.weaponType == "bomb" or self.weaponType == "hashtag_canister" or self.weaponType == "rage_bait" then
        -- Clamp target position to be within playfield bounds
        self.targetX = math.max(margin, math.min(Constants.PLAYFIELD_WIDTH - margin, self.targetX))
        self.targetY = math.max(margin, math.min(Constants.PLAYFIELD_HEIGHT - margin, self.targetY))
        
        local dx = self.targetX - bx
        local dy = self.targetY - by
        local distSq = dx*dx + dy*dy
        local dist = math.sqrt(distSq)
        
        -- Update whistle pitch based on distance to target
        if self.whistleSound then
            local success, isPlaying = pcall(function()
                if not self.whistleSound then return false end
                return self.whistleSound:isPlaying()
            end)
            if success and isPlaying then
                local maxDist = Constants.BOMB_RANGE_MAX or 900
                local normalizedDist = math.min(dist / maxDist, 1.0)
                local pitch = 0.5 + normalizedDist * 1.0
                pcall(function()
                    if self.whistleSound then self.whistleSound:setPitch(pitch) end
                end)
            else
                self.whistleSound = nil
            end
        end
        
        if distSq < 15*15 then
            if self.weaponType == "hashtag_canister" then
                Event.emit("hashtag_landed", { x = self.targetX, y = self.targetY, color = self.color })
                self:die()
            elseif self.weaponType == "rage_bait" then
                Event.emit("rage_bait_landed", { x = self.targetX, y = self.targetY })
                self:die()
            else
                self:explode()
            end
        else
            local angle = math.atan2(dy, dx)
            local s = 500
            if self.weaponType == "hashtag_canister" and Constants.VIRAL and Constants.VIRAL.CANISTER_SPEED then s = Constants.VIRAL.CANISTER_SPEED
            elseif self.weaponType == "rage_bait" and Constants.RAGE_BAIT and Constants.RAGE_BAIT.CANISTER_SPEED then s = Constants.RAGE_BAIT.CANISTER_SPEED
            end
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
    
    -- Stop whistling sound if playing (safely handle released sounds)
    if self.whistleSound then
        local success = pcall(function()
            if self.whistleSound:isPlaying() then
                self.whistleSound:stop()
                self.whistleSound:release()
            end
        end)
        self.whistleSound = nil
    end
    
    if self.body then self.body:destroy() end
end

function Projectile:draw()
    if self.isDead then return end
    
    local r, g, b = 0.2, 0.2, 1
    if self.color == "red" then r, g, b = 1, 0.2, 0.2 end
    if self.weaponType == "rage_bait" then r, g, b = 1, 0.6, 0.1 end
    
    local px, py = self.body:getPosition()
    local trailW = 4
    if self.weaponType == "bomb" then trailW = 10
    elseif self.weaponType == "rage_bait" then trailW = 6
    elseif self.weaponType == "viral" or self.weaponType == "hashtag_canister" then trailW = 8
    end
    for i, t in ipairs(self.trail) do
        if t.alpha > 0 then
            love.graphics.setLineWidth(trailW * t.alpha)
            love.graphics.setColor(r, g, b, t.alpha * 0.5)
            love.graphics.line(px, py, t.x, t.y)
            px, py = t.x, t.y
        end
    end
    
    if self.weaponType == "viral" or self.weaponType == "hashtag_canister" then
        -- Hashtag symbol (in-flight canister uses smaller visual)
        local px, py = self.body:getX(), self.body:getY()
        local R = (self.weaponType == "hashtag_canister" and 20) or (Constants.VIRAL and Constants.VIRAL.CONVERT_RADIUS) or 28
        local bulge = 1.0 + 0.12 * math.sin(love.timer.getTime() * 8)  -- Bulging pulse
        R = R * bulge
        local W = math.max(4, 6 * bulge)
        love.graphics.setLineWidth(W)
        love.graphics.setColor(r, g, b, 1)
        -- Two horizontal bars
        love.graphics.line(px - R, py - R * 0.4, px + R, py - R * 0.4)
        love.graphics.line(px - R, py + R * 0.4, px + R, py + R * 0.4)
        -- Two vertical bars
        love.graphics.line(px - R * 0.45, py - R, px - R * 0.45, py + R)
        love.graphics.line(px + R * 0.45, py - R, px + R * 0.45, py + R)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setLineWidth(math.max(2, W - 2))
        love.graphics.line(px - R, py - R * 0.4, px + R, py - R * 0.4)
        love.graphics.line(px - R, py + R * 0.4, px + R, py + R * 0.4)
        love.graphics.line(px - R * 0.45, py - R, px - R * 0.45, py + R)
        love.graphics.line(px + R * 0.45, py - R, px + R * 0.45, py + R)
    else
        love.graphics.setColor(r, g, b, 1)
        love.graphics.circle("fill", self.body:getX(), self.body:getY(), self.shape:getRadius())
        if self.weaponType == "rage_bait" then
            love.graphics.setColor(0.3, 0.2, 0.1, 0.8)
            love.graphics.circle("line", self.body:getX(), self.body:getY(), self.shape:getRadius())
        end
    end
end

return Projectile