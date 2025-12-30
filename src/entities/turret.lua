local Constants = require("src.constants")
local Projectile = require("src.entities.projectile")
local Sound = require("src.core.sound")

local Turret = {}
Turret.__index = Turret

-- Animation configuration
local ANIM_CONF = {
    BODY_RADIUS = 30,
    
    -- Abdomen
    ABDOMEN_OFFSET = -38,   
    ABDOMEN_WIDTH = 42,     
    ABDOMEN_HEIGHT = 32,
    ABDOMEN_SCALE_REDUCTION = 0.4,
    
    -- Gait
    STEP_TRIGGER_DIST = 30,
    STEP_SPEED = 10,
    
    -- Physics
    BODY_SMOOTHING = 5.0,
    TURN_SPEED = 8.0,
    
    -- Visuals
    LEAN_MAX_DIST = 250,
    LEAN_PHYSICAL_OFFSET = 30,
    LEAN_VISUAL_TILT = 20,
    BARREL_SHORTEN = 25,
    
    -- Weapons
    BARREL_RECOIL = 12,
    BARREL_RETURN_SPEED = 10,
    BODY_RECOIL_FORCE = 40,  -- Body recoil force when firing (rapid fire)
    BODY_RECOIL_RECOVERY_SPEED = 8.0  -- How fast body recoil recovers
}

-- Helper functions
local function dist(x1, y1, x2, y2) 
    return math.sqrt((x2-x1)^2 + (y2-y1)^2) 
end

local function lerp(a, b, t) 
    return a + (b - a) * t 
end

local function angleLerp(current, target, dt, speed)
    local diff = target - current
    diff = (diff + math.pi) % (2 * math.pi) - math.pi
    return current + diff * math.min(1, dt * speed)
end

local function solveIK(hx, hy, fx, fy, l1, l2, bendDir)
    local dx = fx - hx
    local dy = fy - hy
    local d = math.sqrt(dx*dx + dy*dy)
    d = math.min(d, l1 + l2 - 0.001)
    d = math.max(d, math.abs(l1 - l2) + 0.001)
    
    local angleToTarget = math.atan2(dy, dx)
    local cosHip = (l1*l1 + d*d - l2*l2) / (2 * l1 * d)
    cosHip = math.max(-1, math.min(1, cosHip))
    
    local hipAngle = angleToTarget + (math.acos(cosHip) * bendDir)
    return hx + math.cos(hipAngle) * l1, hy + math.sin(hipAngle) * l1
end

function Turret.new()
    local self = setmetatable({}, Turret)
    
    self.x = Constants.PLAYFIELD_WIDTH / 2
    self.y = Constants.PLAYFIELD_HEIGHT + 155
    self.angle = -math.pi / 2
    
    -- Animation properties
    self.visualX = self.x
    self.visualY = self.y
    self.visualAngle = self.angle
    self.lean = 0
    self.barrelkick = 0
    self.bodyRecoilX = 0  -- Body recoil offset X
    self.bodyRecoilY = 0  -- Body recoil offset Y
    
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
        self.barrelLength = self.sprite:getWidth() / 2 * 2
    else
        self.sprite = nil
        self.barrelLength = 60 * 2
    end

    self.isCharging = false
    self.chargeTimer = 0
    self.chargeColor = "red"
    self.recoil = 0
    self.flashTimer = 0
    self.chargeSound = nil  -- Sound source for charging vibration
    
    -- Initialize legs
    local LONG_L1, LONG_L2 = 65, 70 
    local SHORT_L1, SHORT_L2 = 45, 50 
    
    local legConfigs = {
        -- LEFT
        { angle = math.rad(-18.5),  dist = 130, bend = -1, l1=SHORT_L1, l2=LONG_L2 },
        { angle = math.rad(-70.5),  dist = 120, bend = -1, l1=SHORT_L1, l2=SHORT_L2 },
        { angle = math.rad(-122.5), dist = 120, bend = 1,  l1=SHORT_L1, l2=SHORT_L2 },
        { angle = math.rad(-157.5), dist = 140, bend = 1,  l1=LONG_L1, l2=SHORT_L2 },
        -- RIGHT
        { angle = math.rad(157.5),  dist = 140, bend = -1, l1=LONG_L1, l2=SHORT_L2 },
        { angle = math.rad(124.5),  dist = 120, bend = -1, l1=SHORT_L1, l2=SHORT_L2 },
        { angle = math.rad(70.5),   dist = 120, bend = 1,  l1=SHORT_L1, l2=SHORT_L2 },
        { angle = math.rad(18.5),   dist = 130, bend = 1,  l1=SHORT_L1, l2=LONG_L2 },
    }

    self.legs = {}
    for i, config in ipairs(legConfigs) do
        local reach = config.dist
        self.legs[i] = {
            id = i,
            mountAngleLocal = config.angle,
            bendDir = config.bend,
            l1 = config.l1, l2 = config.l2,
            mountRadius = ANIM_CONF.BODY_RADIUS - 5,
            footX = self.x + math.cos(config.angle) * reach,
            footY = self.y + math.sin(config.angle) * reach,
            idealDist = reach,
            idealX = 0, idealY = 0, distToIdeal = 0,
            isStepping = false,
            stepT = 0, stepStartX = 0, stepStartY = 0, stepTargetX = 0, stepTargetY = 0,
            hipX = 0, hipY = 0, kneeX = 0, kneeY = 0
        }
    end
    
    return self
end

function Turret:activatePuckMode(duration)
    self.puckModeTimer = duration
    self.isCharging = false 
    self.chargeTimer = 0
    
    -- Stop charging sound if playing
    if self.chargeSound and self.chargeSound:isPlaying() then
        self.chargeSound:stop()
        self.chargeSound:release()
        self.chargeSound = nil
    end
end

function Turret:updateGait(dt)
    for i, leg in ipairs(self.legs) do
        local currentMountAngle = self.visualAngle + leg.mountAngleLocal
        leg.hipX = self.visualX + math.cos(currentMountAngle) * leg.mountRadius
        leg.hipY = self.visualY + math.sin(currentMountAngle) * leg.mountRadius
        leg.idealX = self.visualX + math.cos(currentMountAngle) * leg.idealDist
        leg.idealY = self.visualY + math.sin(currentMountAngle) * leg.idealDist
        leg.distToIdeal = dist(leg.footX, leg.footY, leg.idealX, leg.idealY)
    end

    for i, leg in ipairs(self.legs) do
        if leg.isStepping then
            leg.stepT = math.min(leg.stepT + ANIM_CONF.STEP_SPEED * dt, 1.0)
            local t = leg.stepT
            local easeT = t * t * (3 - 2 * t)
            leg.footX = lerp(leg.stepStartX, leg.stepTargetX, easeT)
            leg.footY = lerp(leg.stepStartY, leg.stepTargetY, easeT)
            if leg.stepT >= 1.0 then leg.isStepping = false end
        else
            if leg.distToIdeal > ANIM_CONF.STEP_TRIGGER_DIST then
                local prevIdx = (i - 2) % 8 + 1
                local nextIdx = (i % 8) + 1
                if not (self.legs[prevIdx].isStepping or self.legs[nextIdx].isStepping) then
                    leg.isStepping = true
                    leg.stepT = 0
                    leg.stepStartX, leg.stepStartY = leg.footX, leg.footY
                    leg.stepTargetX, leg.stepTargetY = leg.idealX, leg.idealY
                end
            end
        end
        leg.kneeX, leg.kneeY = solveIK(leg.hipX, leg.hipY, leg.footX, leg.footY, leg.l1, leg.l2, leg.bendDir)
    end
end

function Turret:update(dt, projectiles, isUpgraded)
    dt = math.min(dt, 0.1)
    
    -- GAME LOGIC (preserved)
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
    
    -- ANIMATION LOGIC (new)
    -- Calculate target angle for visual system (use current angle)
    self.visualAngle = angleLerp(self.visualAngle, self.angle, dt, ANIM_CONF.TURN_SPEED)
    
    -- Calculate lean based on bomb reticule distance when charging
    -- Neutral lean by default, lean back more when reticule is closer
    local targetLean = 0.0  -- Default neutral lean
    
    if self.isCharging then
        -- Calculate distance to bomb target (reticule position)
        local currentDist = self.chargeTimer * 500
        local targetX = self.x + math.cos(self.angle) * currentDist
        local targetY = self.y + math.sin(self.angle) * currentDist
        local distToTarget = dist(self.x, self.y, targetX, targetY)
        
        -- Closer reticule = more lean back (inverse relationship)
        -- Map distance to lean: closer (smaller dist) = higher lean
        -- Use inverse relationship: lean increases as distance decreases
        local normalizedDist = math.min(distToTarget / ANIM_CONF.LEAN_MAX_DIST, 1.0)
        targetLean = 1.0 - normalizedDist  -- Invert: close = high lean, far = low lean
        targetLean = math.max(0.0, math.min(1.0, targetLean))  -- Clamp to 0-1
    end
    
    self.lean = lerp(self.lean, targetLean, dt * 5)
    
    local offsetDist = self.lean * ANIM_CONF.LEAN_PHYSICAL_OFFSET
    local targetX = self.x - math.cos(self.visualAngle) * offsetDist
    local targetY = self.y - math.sin(self.visualAngle) * offsetDist

    -- Apply body recoil to visual position
    targetX = targetX + self.bodyRecoilX
    targetY = targetY + self.bodyRecoilY

    self.visualX = lerp(self.visualX, targetX, dt * ANIM_CONF.BODY_SMOOTHING)
    self.visualY = lerp(self.visualY, targetY, dt * ANIM_CONF.BODY_SMOOTHING)
    
    -- Recover barrel kick
    self.barrelkick = lerp(self.barrelkick, 0, dt * ANIM_CONF.BARREL_RETURN_SPEED)
    
    -- Recover body recoil
    self.bodyRecoilX = lerp(self.bodyRecoilX, 0, dt * ANIM_CONF.BODY_RECOIL_RECOVERY_SPEED)
    self.bodyRecoilY = lerp(self.bodyRecoilY, 0, dt * ANIM_CONF.BODY_RECOIL_RECOVERY_SPEED)
    
    -- Update gait
    self:updateGait(dt)
end

function Turret:startCharge(color)
    if self.puckModeTimer <= 0 then
        self.isCharging = true
        self.chargeTimer = 0
        self.chargeColor = color
        
        -- Start vibrating sound for charging
        if not self.chargeSound or not self.chargeSound:isPlaying() then
            self.chargeSound = Sound.playVibrate(0.3, 1.0, true)  -- Lower volume (0.3 instead of 0.5)
        end
    end
end

function Turret:releaseCharge(projectiles)
    if not self.isCharging then return end
    
    local dist = self.chargeTimer * 500
    
    -- Calculate muzzle position with animation
    local visualSlide = -self.lean * ANIM_CONF.LEAN_VISUAL_TILT
    local forwardOffset = visualSlide - self.barrelkick + 30
    local cos = math.cos(self.visualAngle)
    local sin = math.sin(self.visualAngle)
    local muzzleX = self.visualX + (forwardOffset * cos)
    local muzzleY = self.visualY + (forwardOffset * sin)
    
    table.insert(projectiles, Projectile.new(muzzleX, muzzleY, self.angle, "bomb", self.chargeColor, dist))
    
    -- Stop charging sound
    if self.chargeSound and self.chargeSound:isPlaying() then
        self.chargeSound:stop()
        self.chargeSound:release()
        self.chargeSound = nil
    end
    
    -- Sound effect
    Sound.fireBomb(self.chargeColor)
    
    self.barrelkick = ANIM_CONF.BARREL_RECOIL
    self.recoil = 25
    self.flashTimer = 0.12
    self.isCharging = false
    self.chargeTimer = 0
end

function Turret:firePuck(color, projectiles)
    -- Calculate muzzle position with animation
    local visualSlide = -self.lean * ANIM_CONF.LEAN_VISUAL_TILT
    local forwardOffset = visualSlide - self.barrelkick + 30
    local cos = math.cos(self.visualAngle)
    local sin = math.sin(self.visualAngle)
    local muzzleX = self.visualX + (forwardOffset * cos)
    local muzzleY = self.visualY + (forwardOffset * sin)
    
    table.insert(projectiles, Projectile.new(muzzleX, muzzleY, self.angle, "puck", color))
    
    -- Sound effect
    Sound.firePuck(color)
    
    -- Apply body recoil (push back opposite to firing direction)
    self.bodyRecoilX = self.bodyRecoilX - math.cos(self.visualAngle) * ANIM_CONF.BODY_RECOIL_FORCE
    self.bodyRecoilY = self.bodyRecoilY - math.sin(self.visualAngle) * ANIM_CONF.BODY_RECOIL_FORCE
    
    self.barrelkick = ANIM_CONF.BARREL_RECOIL
    self.recoil = 12
    self.flashTimer = 0.08
    self.chargeColor = color 
end

function Turret:draw()
    -- Calculate barrel end position for effects
    local visualSlide = -self.lean * ANIM_CONF.LEAN_VISUAL_TILT
    local barrelPos = visualSlide - self.barrelkick
    local forwardOffset = barrelPos + 30
    local cos = math.cos(self.visualAngle)
    local sin = math.sin(self.visualAngle)
    local bx = self.visualX + (forwardOffset * cos)
    local by = self.visualY + (forwardOffset * sin)
    
    -- GUIDE LINES (preserved)
    if not self.isCharging then
        if self.puckModeTimer > 0 then
            local life = Constants.PUCK_LIFETIME or 4.0
            local laserDist = 800 * life
            
            local tx = self.visualX + math.cos(self.visualAngle) * laserDist
            local ty = self.visualY + math.sin(self.visualAngle) * laserDist
            love.graphics.setColor(1, 0.8, 0.2, 0.3)
            love.graphics.setLineWidth(2 * 2)
            love.graphics.line(self.visualX, self.visualY, tx, ty)
        else
            love.graphics.setColor(1, 1, 1, 0.1)
            love.graphics.setLineWidth(1 * 2)
            love.graphics.line(self.visualX, self.visualY, self.visualX + math.cos(self.visualAngle)*100, self.visualY + math.sin(self.visualAngle)*100)
        end
    end

    -- BOMB RETICLE (preserved)
    if self.isCharging then
        local currentDist = self.chargeTimer * 500
        local targetX = self.visualX + math.cos(self.visualAngle) * currentDist
        local targetY = self.visualY + math.sin(self.visualAngle) * currentDist
        
        if self.chargeColor == "red" then love.graphics.setColor(1, 0.2, 0.2, 0.8)
        else love.graphics.setColor(0.2, 0.2, 1, 0.8) end
        
        local pulse = math.sin(love.timer.getTime() * 20) * 4
        love.graphics.setLineWidth(2 * 2)
        love.graphics.circle("line", targetX, targetY, (15 + pulse) * 2)
        love.graphics.circle("fill", targetX, targetY, 3 * 2)
        
        for i = 0, 3 do
            local angle = (math.pi/2) * i + (love.timer.getTime() * 2)
            local rx = targetX + math.cos(angle) * (20 + pulse) * 2
            local ry = targetY + math.sin(angle) * (20 + pulse) * 2
            love.graphics.circle("fill", rx, ry, 2 * 2)
        end
    end

    -- LEGS (new animation)
    for i, leg in ipairs(self.legs) do
        love.graphics.setLineWidth(4)
        local c = 0.4
        if leg.isStepping then c = 0.55 end
        love.graphics.setColor(0,0,0,0.3)
        love.graphics.line(leg.hipX, leg.hipY+5, leg.kneeX, leg.kneeY+5)
        love.graphics.setColor(c, c, c)
        love.graphics.line(leg.hipX, leg.hipY, leg.kneeX, leg.kneeY)
        love.graphics.setColor(c*0.8, c*0.8, c*0.8)
        love.graphics.line(leg.kneeX, leg.kneeY, leg.footX, leg.footY)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.circle("fill", leg.kneeX, leg.kneeY, 4)
        love.graphics.circle("fill", leg.footX, leg.footY, 5)
    end

    -- TURRET BODY (new animation)
    love.graphics.push()
    love.graphics.translate(self.visualX, self.visualY)
    love.graphics.rotate(self.visualAngle)
    
    local abdomenScale = 1.0 - (self.lean * ANIM_CONF.ABDOMEN_SCALE_REDUCTION)

    -- Draw abdomen
    love.graphics.setColor(0.25, 0.25, 0.35)
    local scaledW = ANIM_CONF.ABDOMEN_WIDTH * abdomenScale
    local scaledH = ANIM_CONF.ABDOMEN_HEIGHT * abdomenScale
    love.graphics.ellipse("fill", ANIM_CONF.ABDOMEN_OFFSET, 0, scaledW, scaledH)
    love.graphics.setColor(0, 0, 0)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("line", ANIM_CONF.ABDOMEN_OFFSET, 0, scaledW, scaledH)

    -- Draw main body
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.circle("fill", 0, 0, ANIM_CONF.BODY_RADIUS)
    love.graphics.setColor(0,0,0)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, ANIM_CONF.BODY_RADIUS)
    
    love.graphics.translate(visualSlide, 0)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.circle("fill", 0, 0, ANIM_CONF.BODY_RADIUS * 0.7)
    love.graphics.setColor(0,0,0)
    love.graphics.circle("line", 0, 0, ANIM_CONF.BODY_RADIUS * 0.7)
    
    -- Draw barrels with recoil
    love.graphics.translate(-self.barrelkick, 0)
    
    local barrelLen = 35 - (self.lean * ANIM_CONF.BARREL_SHORTEN)
    love.graphics.setColor(0.7, 0.2, 0.2)
    love.graphics.rectangle("fill", 10, -12, barrelLen, 8)
    love.graphics.rectangle("fill", 10, 4, barrelLen, 8)
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("line", 10, -12, barrelLen, 8)
    love.graphics.rectangle("line", 10, 4, barrelLen, 8)
    
    love.graphics.pop()
    
    -- PUCK MODE INDICATOR (preserved)
    if self.puckModeTimer > 0 then
        love.graphics.setColor(1, 0.8, 0.2, 0.5 + math.sin(love.timer.getTime()*10)*0.2)
        love.graphics.setLineWidth(3 * 2)
        love.graphics.circle("line", self.visualX, self.visualY, 30 * 2)
    end

    -- FLASH EFFECTS (preserved)
    if self.flashTimer > 0 then
        local r, g, b = (self.chargeColor == "red") and {1, 0.5, 0} or {0, 0.5, 1}
        love.graphics.setColor(r[1], r[2], r[3], self.flashTimer * 8)
        love.graphics.circle("fill", bx, by, 25 * 2)
    end

    if self.isCharging then
        local r, g, b = (self.chargeColor == "red") and {1, 0, 0} or {0, 0, 1}
        love.graphics.setColor(r[1], r[2], r[3], 0.8)
        love.graphics.circle("fill", bx, by, 8 * 2)
    end
end

return Turret
