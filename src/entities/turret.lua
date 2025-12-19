local Constants = require("src.constants")
local Projectile = require("src.entities.projectile")

local Turret = {}
Turret.__index = Turret

function Turret.new()
    local self = setmetatable({}, Turret)
    
    self.x = Constants.PLAYFIELD_WIDTH / 2
    self.y = Constants.PLAYFIELD_HEIGHT - 60
    self.angle = -math.pi / 2
    
    self.rotationVelocity = 0
    self.rotationAccel = 8.0 
    self.rotationFriction = 50.0 
    self.maxRotationSpeed = 4.0
    
    self.fireRate = 0.15 
    self.fireTimer = 0
    self.puckModeTimer = 0 
    
    local success, img = pcall(love.graphics.newImage, "assets/turret.png")
    if success then
        self.sprite = img
        self.ox = self.sprite:getWidth() / 2
        self.oy = self.sprite:getHeight() / 2
        self.barrelLength = self.sprite:getWidth() / 2
    else
        self.sprite = nil
        self.barrelLength = 60
    end

    self.isCharging = false
    self.chargeTimer = 0
    self.chargeColor = "red"
    self.recoil = 0
    self.flashTimer = 0
    
    return self
end

function Turret:activatePuckMode(duration)
    self.puckModeTimer = duration
    self.isCharging = false 
    self.chargeTimer = 0
end

function Turret:update(dt, projectiles, isUpgraded)
    local turning = false
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        self.rotationVelocity = self.rotationVelocity - self.rotationAccel * dt
        turning = true
    elseif love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        self.rotationVelocity = self.rotationVelocity + self.rotationAccel * dt
        turning = true
    end
    
    if not turning then
        if self.rotationVelocity > 0 then
            self.rotationVelocity = math.max(0, self.rotationVelocity - self.rotationFriction * dt)
        elseif self.rotationVelocity < 0 then
            self.rotationVelocity = math.min(0, self.rotationVelocity + self.rotationFriction * dt)
        end
    end
    
    if self.rotationVelocity > self.maxRotationSpeed then self.rotationVelocity = self.maxRotationSpeed
    elseif self.rotationVelocity < -self.maxRotationSpeed then self.rotationVelocity = -self.maxRotationSpeed end
    
    self.angle = self.angle + self.rotationVelocity * dt
    self.angle = math.max(-math.pi + 0.2, math.min(-0.2, self.angle))

    if self.puckModeTimer > 0 then
        self.puckModeTimer = self.puckModeTimer - dt
    end

    if self.puckModeTimer > 0 and projectiles then
        self.fireTimer = math.max(0, self.fireTimer - dt)
        if self.fireTimer <= 0 then
            if love.keyboard.isDown("z") then
                self:firePuck("red", projectiles)
                self.fireTimer = self.fireRate
            elseif love.keyboard.isDown("x") then
                self:firePuck("blue", projectiles)
                self.fireTimer = self.fireRate
            end
        end
    end
    
    if self.isCharging then
        self.chargeTimer = self.chargeTimer + dt
        local maxRange = isUpgraded and Constants.BOMB_RANGE_MAX or Constants.BOMB_RANGE_BASE
        local maxTime = maxRange / 500 
        if self.chargeTimer > maxTime then self.chargeTimer = maxTime end
    end

    self.recoil = math.max(0, self.recoil - 200 * dt)
    self.flashTimer = math.max(0, self.flashTimer - dt)
end

function Turret:startCharge(color)
    if self.puckModeTimer <= 0 then
        self.isCharging = true
        self.chargeTimer = 0
        self.chargeColor = color
    end
end

function Turret:releaseCharge(projectiles)
    if not self.isCharging then return end
    
    local dist = self.chargeTimer * 500
    table.insert(projectiles, Projectile.new(self.x, self.y, self.angle, "bomb", self.chargeColor, dist))
    
    self.recoil = 25
    self.flashTimer = 0.12
    self.isCharging = false
    self.chargeTimer = 0
end

function Turret:firePuck(color, projectiles)
    table.insert(projectiles, Projectile.new(self.x, self.y, self.angle, "puck", color))
    self.recoil = 12
    self.flashTimer = 0.08
    self.chargeColor = color 
end

function Turret:draw()
    local bLen = self.barrelLength - self.recoil
    local bx = self.x + math.cos(self.angle) * bLen
    local by = self.y + math.sin(self.angle) * bLen

    -- GUIDE
    if not self.isCharging then
        if self.puckModeTimer > 0 then
            local life = Constants.PUCK_LIFETIME or 4.0
            local laserDist = 800 * life
            
            local tx = self.x + math.cos(self.angle) * laserDist
            local ty = self.y + math.sin(self.angle) * laserDist
            love.graphics.setColor(1, 0.8, 0.2, 0.3)
            love.graphics.setLineWidth(2)
            love.graphics.line(self.x, self.y, tx, ty)
        else
            love.graphics.setColor(1, 1, 1, 0.1)
            love.graphics.setLineWidth(1)
            love.graphics.line(self.x, self.y, self.x + math.cos(self.angle)*100, self.y + math.sin(self.angle)*100)
        end
    end

    -- [RESTORED] OLD STYLE BOMB RETICLE
    if self.isCharging then
        local currentDist = self.chargeTimer * 500
        local targetX = self.x + math.cos(self.angle) * currentDist
        local targetY = self.y + math.sin(self.angle) * currentDist
        
        if self.chargeColor == "red" then love.graphics.setColor(1, 0.2, 0.2, 0.8)
        else love.graphics.setColor(0.2, 0.2, 1, 0.8) end
        
        -- The pulsing small circle
        local pulse = math.sin(love.timer.getTime() * 20) * 4
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", targetX, targetY, 15 + pulse)
        love.graphics.circle("fill", targetX, targetY, 3) -- Center dot
        
        -- The rotating orbiting dots (Corner brackets)
        for i = 0, 3 do
            local angle = (math.pi/2) * i + (love.timer.getTime() * 2)
            local rx = targetX + math.cos(angle) * (20 + pulse)
            local ry = targetY + math.sin(angle) * (20 + pulse)
            love.graphics.circle("fill", rx, ry, 2)
        end
    end

    -- SPRITE
    if self.sprite then
        love.graphics.setColor(1, 1, 1) 
        local recoilX = math.cos(self.angle) * -self.recoil
        local recoilY = math.sin(self.angle) * -self.recoil
        love.graphics.draw(self.sprite, self.x + recoilX, self.y + recoilY, self.angle, 1, 1, self.ox, self.oy)
    else
        love.graphics.setColor(0.25, 0.25, 0.28)
        love.graphics.circle("fill", self.x, self.y, 40)
        love.graphics.setLineWidth(14)
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.line(self.x, self.y, bx, by)
        love.graphics.setColor(0.7, 0.7, 0.75)
        love.graphics.circle("fill", self.x, self.y, 16)
    end
    
    if self.puckModeTimer > 0 then
        love.graphics.setColor(1, 0.8, 0.2, 0.5 + math.sin(love.timer.getTime()*10)*0.2)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", self.x, self.y, 30)
    end

    if self.flashTimer > 0 then
        local r, g, b = (self.chargeColor == "red") and {1, 0.5, 0} or {0, 0.5, 1}
        love.graphics.setColor(r[1], r[2], r[3], self.flashTimer * 8)
        love.graphics.circle("fill", bx, by, 25)
    end

    if self.isCharging then
        local r, g, b = (self.chargeColor == "red") and {1, 0, 0} or {0, 0, 1}
        love.graphics.setColor(r[1], r[2], r[3], 0.8)
        love.graphics.circle("fill", bx, by, 8)
    end
end

return Turret