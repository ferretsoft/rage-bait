local Constants = require("src.constants")
local Projectile = require("src.entities.projectile")

local Turret = {}
Turret.__index = Turret

function Turret.new()
    local self = setmetatable({}, Turret)
    
    -- Using Playfield coordinates to stay inside the game borders
    self.x = Constants.PLAYFIELD_WIDTH / 2
    self.y = Constants.PLAYFIELD_HEIGHT - 60
    
    self.angle = -math.pi / 2
    self.rotationSpeed = 3.5
    
    self.isCharging = false
    self.chargeTimer = 0
    self.chargeColor = "red"
    
    self.recoil = 0
    self.barrelLength = 60
    self.flashTimer = 0 
    
    return self
end

function Turret:update(dt)
    -- KEYBOARD CONTROLS
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        self.angle = self.angle - self.rotationSpeed * dt
    elseif love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        self.angle = self.angle + self.rotationSpeed * dt
    end
    
    -- Limit rotation (Prevent aiming down/backwards)
    self.angle = math.max(-math.pi + 0.2, math.min(-0.2, self.angle))

    if self.isCharging then
        self.chargeTimer = self.chargeTimer + dt
        -- Global upgrade check
        local maxRange = (_G.Game and _G.Game.isUpgraded) and 900 or 300
        local maxTime = maxRange / 500
        if self.chargeTimer > maxTime then self.chargeTimer = maxTime end
    end

    self.recoil = math.max(0, self.recoil - 200 * dt)
    self.flashTimer = math.max(0, self.flashTimer - dt)
end

function Turret:startCharge(color)
    self.isCharging = true
    self.chargeTimer = 0
    self.chargeColor = color
end

function Turret:releaseCharge(projectiles)
    if not self.isCharging then return end
    local dist = self.chargeTimer * 500
    table.insert(projectiles, Projectile.new(self.x, self.y, self.angle, "bomb", self.chargeColor, dist))
    self.recoil = 25
    self.flashTimer = 0.1
    self.isCharging = false
    self.chargeTimer = 0
end

function Turret:firePuck(color, projectiles)
    table.insert(projectiles, Projectile.new(self.x, self.y, self.angle, "puck", color))
    self.recoil = 12
    self.flashTimer = 0.07
    self.chargeColor = color 
end

function Turret:draw()
    -- Calculate barrel position with recoil
    local bLen = self.barrelLength - self.recoil
    local bx = self.x + math.cos(self.angle) * bLen
    local by = self.y + math.sin(self.angle) * bLen

    -- 1. LASER SIGHT (Fixed Drawing Logic)
    if self.isCharging then
        local currentDist = self.chargeTimer * 500
        local tx = self.x + math.cos(self.angle) * currentDist
        local ty = self.y + math.sin(self.angle) * currentDist
        
        -- Set Laser Color
        if self.chargeColor == "red" then 
            love.graphics.setColor(1, 0.2, 0.2, 0.6)
        else 
            love.graphics.setColor(0.2, 0.2, 1, 0.6) 
        end
        
        -- Draw the Laser Beam Line
        love.graphics.setLineWidth(2)
        love.graphics.line(self.x, self.y, tx, ty)

        -- Energy "Dust" / Particles
        for i = 0, currentDist, 4 do
            local px = self.x + math.cos(self.angle) * i
            local py = self.y + math.sin(self.angle) * i
            
            -- Noise-based jitter for the "shimmer" effect
            local noise = love.math.noise(i * 0.1, love.timer.getTime() * 5)
            local offsetX = (noise - 0.5) * 12
            local offsetY = (noise - 0.5) * 12
            
            love.graphics.circle("fill", px + offsetX, py + offsetY, 1.5 + (noise * 2))
        end
        
        -- Target Reticle (Pulsing)
        local pulse = math.sin(love.timer.getTime() * 15) * 4
        love.graphics.circle("line", tx, ty, 12 + pulse)
    end

    -- 2. TURRET BODY DRAWING
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.circle("fill", self.x, self.y + 4, 42)
    
    -- Barrel
    love.graphics.setLineWidth(14)
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.line(self.x, self.y, bx, by)
    
    -- Muzzle Flash
    if self.flashTimer > 0 then
        love.graphics.setColor(self.chargeColor == "red" and {1,0.5,0} or {0,0.5,1}, self.flashTimer * 8)
        love.graphics.circle("fill", bx, by, 20 + self.recoil)
        love.graphics.setColor(1, 1, 1, self.flashTimer * 10)
        love.graphics.circle("fill", bx, by, 10 + self.recoil * 0.5)
    end

    -- Charging Tip Glow
    if self.isCharging then
        love.graphics.setColor(self.chargeColor == "red" and {1,0,0,0.8} or {0,0,1,0.8})
        love.graphics.circle("fill", bx, by, 8 + math.sin(love.timer.getTime()*20)*2)
    end

    -- Base Pivot
    love.graphics.setColor(0.25, 0.25, 0.28)
    love.graphics.circle("fill", self.x, self.y, 40)
    love.graphics.setColor(0.6, 0.6, 0.65)
    love.graphics.circle("fill", self.x, self.y, 18)
end

return Turret