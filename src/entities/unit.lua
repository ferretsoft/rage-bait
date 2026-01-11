local Constants = require("src.constants")
local Event = require("src.core.event")
local EmojiSprites = require("src.core.emoji_sprites")
local Sound = require("src.core.sound")

local Unit = {}
Unit.__index = Unit

-- Internet nihilism quotes for when units go insane
local NIHILISM_QUOTES = {
    "nothing matters",
    "we're all doomed",
    "existence is pain",
    "everything is meaningless",
    "we're just data",
    "reality is a simulation",
    "nothing is real",
    "we're all going to die",
    "the void consumes all",
    "existence is futile",
    "we're trapped here",
    "there is no escape",
    "all hope is lost",
    "we're just numbers",
    "the system is broken",
    "we're all puppets",
    "freedom is an illusion",
    "we're already dead",
    "the end is near",
    "we're all alone"
}

function Unit.new(world, x, y)
    local self = setmetatable({}, Unit)
    
    self.type = "unit"
    self.state = "neutral" 
    self.alignment = "none"
    
    self.hp = Constants.UNIT_HP 
    self.isDead = false
    
    self.enrageTimer = 0 
    self.flashTimer = 0
    self.conversionTime = nil  -- Timestamp when unit was converted
    self.isolationTimer = 0  -- Timer for isolation (grey units only)
    self.isInsane = false  -- Whether unit has gone insane from isolation
    self.speechBubble = nil  -- {text, timer, duration} for displaying quotes
    
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
    
    -- Update speech bubble timer
    if self.speechBubble then
        self.speechBubble.timer = self.speechBubble.timer + dt
        if self.speechBubble.timer >= self.speechBubble.duration then
            self.speechBubble = nil
        end
    end
    
    -- Check isolation for grey (neutral) units
    if self.state == "neutral" and not self.isInsane then
        self:checkIsolation(dt, allUnits)
    end
    
    -- If unit went insane, explode immediately (but keep speech bubble visible)
    if self.isInsane and not self.isDead then
        self:goInsane()
        return
    end
    
    if self.state == "enraged" then
        self.enrageTimer = self.enrageTimer - dt
        self.flashTimer = self.flashTimer + dt
        
        if self.enrageTimer <= 0 then
            self.state = "passive"
        end
        
        -- Enraged units don't flock - they search for and attack enemy units
        self:updateEnraged(dt, allUnits)
    else
        -- NEUTRAL / PASSIVE BEHAVIOR
        local isAttracted = false
        if self.state == "neutral" and explosionZones then
            isAttracted = self:seekAttractions(dt, explosionZones)
        end
        
        -- Flocking behavior for colored units (red/blue)
        if self.alignment ~= "none" and self.state ~= "neutral" then
            self:updateFlocking(dt, allUnits)
        elseif not isAttracted then
            self:updateWander(dt)
        end
        
        self:avoidNeighbors(dt, allUnits)
        
        if hazards then self:avoidHazards(dt, hazards) end
        
        -- [REMOVED] avoidProjectiles logic
    end
    
    -- All units avoid walls (enraged units have reduced wall avoidance in avoidWalls function)
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
    -- Enraged units don't flock - they break away to search for and attack enemy units
    -- Red units search for blue, blue units search for red
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
            local dirX = dx / dist
            local dirY = dy / dist
            
            -- Much stronger seeking force - enraged units are aggressive
            local force = self.body:getMass() * 4000  -- Doubled from 2000 for more aggression
            
            -- If close to enemy, boost velocity directly for ramming attacks
            if dist < 100 then
                -- Close range: boost velocity for direct ramming
                local currentVx, currentVy = self.body:getLinearVelocity()
                local boostSpeed = 300  -- Additional speed boost when close
                local newVx = currentVx + dirX * boostSpeed * dt
                local newVy = currentVy + dirY * boostSpeed * dt
                -- Clamp max speed to prevent excessive velocity
                local maxSpeed = 500
                local speed = math.sqrt(newVx^2 + newVy^2)
                if speed > maxSpeed then
                    newVx = (newVx / speed) * maxSpeed
                    newVy = (newVy / speed) * maxSpeed
                end
                self.body:setLinearVelocity(newVx, newVy)
            else
                -- Far range: use force to seek
                self.body:applyForce(dirX * force, dirY * force)
            end
        end
    else
        -- No enemy found, wander until one appears
        self:updateWander(dt) 
    end
    
    -- Enraged units also avoid being pulled by same-color units (break away from flock)
    self:avoidFlockmates(dt, allUnits)
end

function Unit:hit(weaponType, color)
    if self.isDead then return end

    if self.state == "neutral" then
        self.alignment = color
        self.state = "passive"
        self.conversionTime = love.timer.getTime()  -- Record conversion time
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

-- Check if grey unit is isolated from other neutral units
function Unit:checkIsolation(dt, allUnits)
    local myX, myY = self.body:getPosition()
    local isolationRadius = 150  -- Distance to check for nearby neutral units
    local hasNearbyNeutral = false
    
    -- Check for nearby neutral units
    for _, other in ipairs(allUnits) do
        if other ~= self and not other.isDead and other.state == "neutral" then
            local ox, oy = other.body:getPosition()
            local dx = ox - myX
            local dy = oy - myY
            local distSq = dx*dx + dy*dy
            
            if distSq < isolationRadius^2 then
                hasNearbyNeutral = true
                break
            end
        end
    end
    
    -- Update isolation timer
    if hasNearbyNeutral then
        -- Reset timer if near other neutrals
        self.isolationTimer = 0
        -- Clear speech bubble if unit is no longer isolated
        if self.speechBubble then
            self.speechBubble = nil
        end
    else
        -- Increment timer if isolated
        local oldTimer = self.isolationTimer
        self.isolationTimer = self.isolationTimer + dt
        
        -- Show speech bubble and play warning sound when timer reaches half (when shaking starts)
        local halfTime = Constants.ISOLATION_INSANE_TIME / 2
        if oldTimer < halfTime and self.isolationTimer >= halfTime then
            -- Play warning sound (alert beep)
            Sound.playTone(600, 0.2, 0.7, 1.0)  -- Medium pitch, 0.2s duration
            Sound.playTone(800, 0.15, 0.7, 1.2)  -- Higher pitch for urgency
            
            -- Show a random nihilism quote when shaking starts
            if not self.speechBubble then
                local quote = NIHILISM_QUOTES[math.random(#NIHILISM_QUOTES)]
                self.speechBubble = {
                    text = quote,
                    timer = 0,
                    duration = Constants.ISOLATION_INSANE_TIME - halfTime + 2.5  -- Show from half time until explosion + 2.5 seconds
                }
            end
        end
    end
    
    -- If isolated for long enough, go insane
    if self.isolationTimer >= Constants.ISOLATION_INSANE_TIME then
        self.isInsane = true
    end
end

-- Unit goes insane from isolation - explodes and creates massive sludge
function Unit:goInsane()
    if self.isDead then return end
    
    local x, y = self.body:getPosition()
    
    -- Create massive explosion effect, preserving speech bubble
    Event.emit("unit_insane_exploded", {
        x = x,
        y = y,
        victim = self,
        speechBubble = self.speechBubble  -- Preserve speech bubble for drawing
    })
    
    -- Kill the unit
    self:takeDamage(self.hp + 1, nil)  -- Guaranteed death
end

function Unit:draw()
    if self.isDead then return end
    
    local x, y = self.body:getPosition()
    
    -- Shake if enraged
    if self.state == "enraged" then
        local shakeAmount = 2
        x = x + love.math.random(-shakeAmount, shakeAmount)
        y = y + love.math.random(-shakeAmount, shakeAmount)
    end
    
    -- Shake if isolation timer is at half or more (approaching insanity)
    local isApproachingInsanity = self.state == "neutral" and self.isolationTimer >= Constants.ISOLATION_INSANE_TIME / 2
    if isApproachingInsanity then
        local shakeAmount = 3  -- Slightly more shake than enraged
        x = x + love.math.random(-shakeAmount, shakeAmount)
        y = y + love.math.random(-shakeAmount, shakeAmount)
    end
    
    -- Get the appropriate sprite
    local sprite = nil
    local spriteType = nil
    if self.state == "enraged" then
        sprite = EmojiSprites.getAngry()
        spriteType = "angry"
    elseif self.alignment ~= "none" then
        -- Converted units (red or blue, not neutral)
        sprite = EmojiSprites.getConverted()
        spriteType = "converted"
    else
        -- Neutral units (grey)
        sprite = EmojiSprites.getNeutral()
        spriteType = "neutral"
    end
    
    -- Apply color tinting based on state and health
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
    
    -- Draw sprite with color tinting and scaling, or fallback to drawing
    local spriteLoaded = false
    if spriteType == "angry" then
        spriteLoaded = EmojiSprites.isAngryLoaded()
    elseif spriteType == "converted" then
        spriteLoaded = EmojiSprites.isConvertedLoaded()
    else
        spriteLoaded = EmojiSprites.isNeutralLoaded()
    end
    
    if sprite and spriteLoaded then
        local baseScale = (Constants.UNIT_RADIUS * 2) / sprite:getWidth()
        local scale = baseScale * 1.25  -- 25% larger
        local spriteWidth = sprite:getWidth()
        local spriteHeight = sprite:getHeight()
        
        -- Mirror converted units every 2 seconds
        local scaleX = scale
        if spriteType == "converted" and self.conversionTime then
            local timeSinceConversion = love.timer.getTime() - self.conversionTime
            local mirrorInterval = 2.0  -- 2 seconds
            local mirrorPhase = math.floor(timeSinceConversion / mirrorInterval)
            if mirrorPhase % 2 == 1 then
                scaleX = -scaleX  -- Mirror horizontally
            end
        end
        
        love.graphics.setColor(r, g, b, a)
        love.graphics.draw(sprite, x, y, 0, scaleX, scale, spriteWidth / 2, spriteHeight / 2)
    else
        -- Fallback: draw face with shapes if sprite not available
        love.graphics.setColor(r, g, b, a)
        love.graphics.circle("fill", x, y, Constants.UNIT_RADIUS)
        
        -- Draw face features
        local eyeSize = 1.5
        local eyeOffsetX = 2.5
        local eyeOffsetY = -2
        local mouthY = y + 2
        
        -- Determine if angry or neutral
        local isAngry = (self.state == "enraged")
        
        -- Draw eyes (black)
        love.graphics.setColor(0, 0, 0, a)
        love.graphics.circle("fill", x - eyeOffsetX, y + eyeOffsetY, eyeSize)
        love.graphics.circle("fill", x + eyeOffsetX, y + eyeOffsetY, eyeSize)
        
        -- Draw mouth
        if isAngry then
            -- Angry face: downward curved line (frown)
            love.graphics.setLineWidth(1.5)
            love.graphics.arc("line", "open", x, mouthY + 1, 3, 0, math.pi, 8)
        else
            -- Neutral face: straight line
            love.graphics.setLineWidth(1.5)
            love.graphics.line(x - 2.5, mouthY, x + 2.5, mouthY)
        end
    end
    
    -- Draw enrage indicator ring if enraged
    if self.state == "enraged" then
        local fadeAlpha = self.enrageTimer / Constants.UNIT_ENRAGE_DURATION
        love.graphics.setColor(1, 1, 1, fadeAlpha)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", x, y, Constants.UNIT_RADIUS + 4)
    end
    
    -- Draw outline if isolation timer is at half or more (approaching insanity)
    local isApproachingInsanityCheck = self.state == "neutral" and self.isolationTimer >= Constants.ISOLATION_INSANE_TIME / 2
    if isApproachingInsanityCheck then
        -- Calculate pulse effect (faster pulse as timer approaches insanity)
        local timeUntilInsane = Constants.ISOLATION_INSANE_TIME - self.isolationTimer
        local pulseSpeed = 10 - (timeUntilInsane / Constants.ISOLATION_INSANE_TIME * 5)  -- Faster pulse as it approaches
        local pulse = (math.sin(love.timer.getTime() * pulseSpeed) + 1) / 2  -- 0 to 1
        local outlineAlpha = 0.5 + pulse * 0.5  -- Pulse between 0.5 and 1.0
        
        -- Draw pulsing red outline
        love.graphics.setColor(1, 0.3, 0.3, outlineAlpha)
        love.graphics.setLineWidth(4)
        love.graphics.circle("line", x, y, Constants.UNIT_RADIUS + 6)
    end
    
    -- Draw speech bubble if unit has a quote to display
    if self.speechBubble and self.speechBubble.text then
        -- Calculate bubble position (shake only when very close to explosion)
        local timeUntilInsane = Constants.ISOLATION_INSANE_TIME - self.isolationTimer
        local shouldShakeBubble = timeUntilInsane <= 1.5  -- Shake bubble in last 1.5 seconds before explosion
        
        local bubbleX = x
        local bubbleY = y - Constants.UNIT_RADIUS - 40  -- Position above unit (more space)
        
        -- Shake bubble only when very close to explosion
        if shouldShakeBubble then
            local shakeAmount = 2
            bubbleX = bubbleX + love.math.random(-shakeAmount, shakeAmount)
            bubbleY = bubbleY + love.math.random(-shakeAmount, shakeAmount)
        end
        local padding = 10
        local fontSize = 12  -- Slightly larger font
        local font = love.graphics.newFont(fontSize)
        
        -- Calculate text width
        local textWidth = font:getWidth(self.speechBubble.text)
        local textHeight = font:getHeight()
        local bubbleWidth = textWidth + padding * 2
        local bubbleHeight = textHeight + padding * 2
        
        -- Fade out as timer approaches duration
        local alpha = 1.0
        if self.speechBubble.timer and self.speechBubble.duration then
            if self.speechBubble.timer > self.speechBubble.duration * 0.7 then
                alpha = 1.0 - ((self.speechBubble.timer - self.speechBubble.duration * 0.7) / (self.speechBubble.duration * 0.3))
            end
        end
        
        -- Draw speech bubble background (more opaque)
        love.graphics.setColor(0, 0, 0, alpha * 0.9)
        love.graphics.rectangle("fill", bubbleX - bubbleWidth / 2, bubbleY - bubbleHeight, bubbleWidth, bubbleHeight, 4)
        
        -- Draw speech bubble border (brighter)
        love.graphics.setColor(0.8, 0.8, 0.8, alpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bubbleX - bubbleWidth / 2, bubbleY - bubbleHeight, bubbleWidth, bubbleHeight, 4)
        
        -- Draw speech bubble tail (pointing down to unit)
        love.graphics.setColor(0, 0, 0, alpha * 0.9)
        love.graphics.polygon("fill", 
            bubbleX - 10, bubbleY - 6,
            bubbleX + 10, bubbleY - 6,
            bubbleX, bubbleY + 6
        )
        love.graphics.setColor(0.8, 0.8, 0.8, alpha)
        love.graphics.setLineWidth(2)
        love.graphics.polygon("line", 
            bubbleX - 10, bubbleY - 6,
            bubbleX + 10, bubbleY - 6,
            bubbleX, bubbleY + 6
        )
        
        -- Draw text (brighter red)
        love.graphics.setColor(1, 0.5, 0.5, alpha)  -- Brighter red text for nihilism
        love.graphics.setFont(font)
        love.graphics.print(self.speechBubble.text, bubbleX - textWidth / 2, bubbleY - bubbleHeight + padding)
    end
end

function Unit:updateFlocking(dt, allUnits)
    local myX, myY = self.body:getPosition()
    local mass = self.body:getMass()
    
    -- Flocking parameters
    local neighborRadius = 100  -- How far to look for flockmates
    local separationRadius = 30  -- Minimum distance to maintain
    local separationForce = mass * 500
    local alignmentForce = mass * 400
    local cohesionForce = mass * 300
    
    local separationX, separationY = 0, 0
    local alignmentX, alignmentY = 0, 0
    local cohesionX, cohesionY = 0, 0
    local neighborCount = 0
    
    -- Find nearby flockmates (same alignment, but NOT enraged - enraged units don't flock)
    for _, other in ipairs(allUnits) do
        if other ~= self and not other.isDead and other.alignment == self.alignment and other.state ~= "enraged" then
            local ox, oy = other.body:getPosition()
            local dx = ox - myX
            local dy = oy - myY
            local distSq = dx*dx + dy*dy
            
            if distSq < neighborRadius^2 and distSq > 0 then
                local dist = math.sqrt(distSq)
                
                -- Separation: steer away from nearby flockmates
                if distSq < separationRadius^2 then
                    separationX = separationX - (dx / dist) / dist
                    separationY = separationY - (dy / dist) / dist
                end
                
                -- Alignment: steer towards average heading of flockmates
                local vx, vy = other.body:getLinearVelocity()
                local speed = math.sqrt(vx*vx + vy*vy)
                if speed > 0 then
                    alignmentX = alignmentX + (vx / speed)
                    alignmentY = alignmentY + (vy / speed)
                end
                
                -- Cohesion: steer towards average position of flockmates
                cohesionX = cohesionX + dx
                cohesionY = cohesionY + dy
                
                neighborCount = neighborCount + 1
            end
        end
    end
    
    if neighborCount > 0 then
        -- Normalize alignment and cohesion
        local alignMag = math.sqrt(alignmentX*alignmentX + alignmentY*alignmentY)
        if alignMag > 0 then
            alignmentX = alignmentX / alignMag
            alignmentY = alignmentY / alignMag
        end
        
        local cohMag = math.sqrt(cohesionX*cohesionX + cohesionY*cohesionY)
        if cohMag > 0 then
            cohesionX = (cohesionX / neighborCount) / cohMag
            cohesionY = (cohesionY / neighborCount) / cohMag
        end
        
        -- Apply forces
        self.body:applyForce(separationX * separationForce, separationY * separationForce)
        self.body:applyForce(alignmentX * alignmentForce, alignmentY * alignmentForce)
        self.body:applyForce(cohesionX * cohesionForce, cohesionY * cohesionForce)
    end
end

function Unit:avoidFlockmates(dt, allUnits)
    -- Enraged units actively avoid being pulled back into the flock
    local myX, myY = self.body:getPosition()
    local mass = self.body:getMass()
    local avoidRadius = 80
    local avoidForce = mass * 800
    
    for _, other in ipairs(allUnits) do
        if other ~= self and not other.isDead and other.alignment == self.alignment and other.state ~= "enraged" then
            local ox, oy = other.body:getPosition()
            local dx = myX - ox
            local dy = myY - oy
            local distSq = dx*dx + dy*dy
            
            if distSq < avoidRadius^2 and distSq > 0 then
                local dist = math.sqrt(distSq)
                local force = avoidForce * (1 - dist / avoidRadius)  -- Stronger when closer
                self.body:applyForce((dx / dist) * force, (dy / dist) * force)
            end
        end
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
    
    -- Enraged units are less affected by walls - they're focused on attacking
    if self.state == "enraged" then
        pushBack = pushBack * 0.5  -- Half the wall avoidance force when enraged
        margin = 30  -- Smaller margin - let them get closer to walls
    end
    
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
    
    -- Get position before destroying body
    local x, y = self.body:getPosition()
    
    self.body:destroy() 
    Event.emit("unit_killed", {victim = self, killer = killer, x = x, y = y})
end

return Unit