Canister = {}

local FLIGHT_TIME = 0.6 
local ARC_HEIGHT = 400  
local AOE_DURATION = 8.0 
local PEAK_SCALE = 2.5  

-- AOE Visual Constants
local MIN_AOE_ALPHA = 0.2
local MAX_AOE_ALPHA = 0.8

-- Team constants required for logic
local TEAM_NEUTRAL = 0
local TEAM_RED     = 1
local TEAM_BLUE    = 2

function Canister.new(startX, startY, targetX, targetY, team)
    local canister = {
        startX = startX, startY = startY,
        targetX = targetX, targetY = targetY,
        x = startX, y = startY,
        team = team,
        size = 10,
        
        progress = 0, 
        currentScale = 1.0, 
        
        isAoE = false,           
        isFinished = false,      
        timer = 0,               
        blastRadius = 160, 
        
        aoeSpawned = false, -- Track for quote trigger
    }
    
    if team == User.TEAM_RED then
        canister.color = {1, 0, 0} 
        canister.aoeColor = {0.5, 0, 0} 
    else
        canister.color = {0, 0, 1}
        canister.aoeColor = {0, 0, 0.5} 
    end
    
    setmetatable(canister, { __index = Canister })
    return canister
end

function Canister:startAoE(particles)
    if self.blastRadius <= 20 then
        self.isFinished = true
        return
    end

    self.isAoE = true
    self.timer = 0
    self.size = 30
    self.currentScale = 1.0 
    
    -- === 1. POSITIONING FIX ===
    -- Snap center of AOE to exactly the target coordinates
    self.x = self.targetX 
    self.y = self.targetY 
    
    -- === 2. PARTICLES RESTORED ===
    if particles and Particle then
        for i = 1, 15 do
            -- Spawn random particles near center
            local px = self.x + math.random(-10, 10)
            local py = self.y + math.random(-10, 10)
            table.insert(particles, Particle.new(px, py, self.color))
        end
    end

    -- === 3. TRIGGER CLICKBAIT QUOTE ===
    if not self.aoeSpawned and _G.spawnClickbaitQuote then
        _G.spawnClickbaitQuote(self.x, self.y, self.team)
        self.aoeSpawned = true
    end
end

function Canister:resolveZoneConflicts(allCanisters)
    -- Using x/y as center now
    local myCx = self.x
    local myCy = self.y
    
    for _, other in ipairs(allCanisters) do
        if other ~= self and other.isAoE and other.team ~= self.team and not other.isFinished then
            -- Assume other.x/y is also center
            local otherCx = other.x 
            local otherCy = other.y 
            
            local distSq = (myCx - otherCx)^2 + (myCy - otherCy)^2
            local combinedRadius = self.blastRadius + other.blastRadius
            
            if distSq < combinedRadius * combinedRadius then
                local dist = math.sqrt(distSq)
                local overlap = math.max(0, combinedRadius - dist)
                local reduction = overlap * 1.5 
                self.blastRadius = self.blastRadius - reduction
                other.currentScale = 1.1 
            end
        end
    end
end

function Canister:update(dt, screenW, screenH, users, allCanisters, particles)
    if self.isFinished then return true end

    -- === 1. AOE PHASE ===
    if self.isAoE then
        self.timer = self.timer + dt
        
        if self.currentScale > 1.0 then
            self.currentScale = math.max(1.0, self.currentScale - dt * 2)
        end
        
        if self.blastRadius < 20 then self.isFinished = true return true end
        
        if self.timer >= AOE_DURATION then
            self.isFinished = true
            -- End of AOE: Calm everyone down in radius
            for _, user in ipairs(users) do
                 local dx = self.x - (user.x + user.width/2)
                 local dy = self.y - (user.y + user.height/2)
                 if (dx*dx + dy*dy) < self.blastRadius^2 then
                     user:setAggressive(false)
                 end
            end
            return true
        end

        local cx, cy = self.x, self.y -- Center is self.x/y
        local enemyTeam = (self.team == User.TEAM_RED) and User.TEAM_BLUE or User.TEAM_RED
        
        for _, user in ipairs(users) do
            local ux, uy = user.x + user.width/2, user.y + user.height/2
            local dx = cx - ux
            local dy = cy - uy
            
            if (dx*dx + dy*dy) < self.blastRadius^2 then
                -- RULE: Enemy -> Rage
                if user.team == enemyTeam then 
                    user:setAggressive(true) 
                    user.isRaging = true -- Explicitly rage
                    user.rageTimer = 2.0
                end
                
                -- RULE: Neutral -> Convert (Passive)
                if user.team == User.TEAM_NEUTRAL and not user.isInsane then 
                    user:setTeam(self.team) 
                    -- No Rage here
                end
                
                -- RULE: Insane -> Radicalize (Convert + Rage)
                if user.isInsane then
                    user:setTeam(self.team)
                    user:startRage()
                end
            end
        end
        return false

    -- === 2. FLIGHT PHASE ===
    else
        self.progress = self.progress + (dt / FLIGHT_TIME)
        
        if self.progress >= 1.0 then
            self.progress = 1.0
            
            -- FIX: Force position to target before starting AOE
            self.x = self.targetX
            self.y = self.targetY

            if allCanisters then self:resolveZoneConflicts(allCanisters) end
            self:startAoE(particles)
            return false
        end
        
        local arcFactor = math.sin(self.progress * math.pi)
        self.currentScale = 1.0 + (PEAK_SCALE - 1.0) * arcFactor
        
        -- Flight movement
        local linearX = self.startX + (self.targetX - self.startX) * self.progress
        local linearY = self.startY + (self.targetY - self.startY) * self.progress
        local arcOffset = arcFactor * ARC_HEIGHT
        
        self.x = linearX
        self.y = linearY - arcOffset
        
        return false
    end
end

function Canister:draw()
    if self.isAoE then
        love.graphics.push()
        local r, g, b = unpack(self.aoeColor)
        local drawRadius = self.blastRadius * self.currentScale
        
        -- Alpha Calculation: 0.8 -> 0.2
        local timerFactor = 1 - (self.timer / AOE_DURATION) 
        local alpha = MIN_AOE_ALPHA + (MAX_AOE_ALPHA - MIN_AOE_ALPHA) * timerFactor
        
        love.graphics.setColor(r, g, b, alpha * 0.3) -- Fill is lighter
        love.graphics.circle("fill", self.x, self.y, drawRadius)
        
        love.graphics.setColor(r*2, g*2, b*2, alpha) 
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", self.x, self.y, drawRadius)
        love.graphics.setLineWidth(1)
        love.graphics.pop()
        
        -- Draw canister center
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", self.x - self.size/2, self.y - self.size/2, self.size, self.size)
    else
        -- Flight draw
        local r, g, b = unpack(self.color)
        love.graphics.setColor(r, g, b)
        local drawnSize = self.size * self.currentScale
        -- Center drawing on current self.x/y
        local drawX = self.x - drawnSize/2
        local drawY = self.y - drawnSize/2
        love.graphics.rectangle("fill", drawX, drawY, drawnSize, drawnSize)
    end
end