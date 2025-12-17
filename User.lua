User = {} 

-- Team Constants
User.TEAM_NEUTRAL = 0
User.TEAM_RED = 1
User.TEAM_BLUE = 2

-- Visual and Game Constants
local NEUTRAL_COLOR = {0.5, 0.5, 0.5} 
local RED_COLOR     = {1, 0, 0}       
local BLUE_COLOR    = {0, 0, 1}       
local INSANE_WHITE  = {1, 1, 1}       
local INSANE_RED    = {1, 0, 0}       

local MAX_HP = 5
local RAGE_DURATION = 2.0 

-- BASE INSANITY CONSTANTS (Modified by difficulty)
local BASE_ISOLATION_RADIUS = 400    
local BASE_TIME_TO_INSANITY = 4.0    
local GUN_RANGE = 300           
local GUN_COOLDOWN = 0.05       
local GUN_DAMAGE = 10           
local KILLS_UNTIL_SUICIDE = 5   

local hpFont = nil

----------------------------------------------------------------------
-- CONSTRUCTOR
----------------------------------------------------------------------

function User.new(x, y)
    local user = {
        x = x or 0, 
        y = y or 0, 
        width = 20, 
        height = 20,
        
        team = User.TEAM_NEUTRAL, 
        color = NEUTRAL_COLOR,    
        hp = MAX_HP, 
        
        -- State flags
        isAggressive = false,
        target = nil,         
        isRaging = false,     
        rageTimer = 0,
        
        -- INSANITY STATE
        isInsane = false,
        isolationTimer = 0,
        gunTimer = 0,
        bulletTrace = nil, 
        killCount = 0, 
        killedByToxic = false,  
        killedByInsane = false, 
        
        -- AI Timers
        searchTimer = 0, 
        
        -- Movement
        vx = math.random(-100, 100), 
        vy = math.random(-100, 100),
        moveTimer = 0,
        moveDuration = 1 
    }
    
    setmetatable(user, { __index = User }) 
    return user
end

----------------------------------------------------------------------
-- STATE MODIFICATION
----------------------------------------------------------------------

function User:setTeam(newTeam)
    self.team = newTeam
    self.hp = MAX_HP 
    self.isRaging = false 
    self.isAggressive = false
    -- Curing insanity if converted
    self.isInsane = false
    self.isolationTimer = 0
    self.killCount = 0
    
    if self.team == User.TEAM_RED then self.color = RED_COLOR
    elseif self.team == User.TEAM_BLUE then self.color = BLUE_COLOR
    else self.color = NEUTRAL_COLOR end
end

function User:setAggressive(state)
    self.isAggressive = state
    if not state then self.target = nil end
end

function User:startRage()
    self.isRaging = true
    self.rageTimer = RAGE_DURATION
    self:setAggressive(true) 
end

function User:takeDamage(amount)
    if self.isRaging then amount = amount * 0.8 end
    self.hp = self.hp - amount
    return self.hp <= 0 
end

----------------------------------------------------------------------
-- UPDATE LOGIC
----------------------------------------------------------------------

function User:update(dt, screenW, screenH, allUsers, toxicZones, canisters, difficulty) 
    
    local currentDiff = difficulty or 1.0
    local effectiveIsolationRadius = BASE_ISOLATION_RADIUS * (1 + (currentDiff - 1) * 0.2)
    local effectiveTimeInsanity = math.max(1.0, BASE_TIME_TO_INSANITY / currentDiff)

    -- 0. TIMERS
    if self.isRaging then
        self.rageTimer = self.rageTimer - dt
        if self.rageTimer <= 0 then self.isRaging = false end
    end
    if self.bulletTrace then self.bulletTrace.life = self.bulletTrace.life - dt end
    
    -- === 1. CONVERSION / INSANITY CHECK (Runs for Neutral/Insane users) ===
    if self.team == User.TEAM_NEUTRAL or self.isInsane then
        local friendCount = 0
        local checkDistSq = effectiveIsolationRadius * effectiveIsolationRadius
        
        -- Check isolation for neutral users
        if self.team == User.TEAM_NEUTRAL then
            for _, u in ipairs(allUsers) do
                if u ~= self and u.team == User.TEAM_NEUTRAL and u.hp > 0 and not u.isInsane then
                    local dx = u.x - self.x
                    local dy = u.y - self.y
                    if (dx*dx + dy*dy) < checkDistSq then
                        friendCount = friendCount + 1
                    end
                end
            end
            
            if friendCount == 0 then
                self.isolationTimer = self.isolationTimer + dt
                if self.isolationTimer > effectiveTimeInsanity then
                    self.isInsane = true
                end
            else
                self.isolationTimer = math.max(0, self.isolationTimer - dt)
                if self.isInsane and self.isolationTimer == 0 then
                    self.isInsane = false 
                    self.killCount = 0
                end
            end
        end

        -- NEW: Conversion Check (Affects Neutral OR Insane users hitting canisters)
        if canisters then
            local center_x = self.x + self.width/2
            local center_y = self.y + self.height/2
            
            for _, c in ipairs(canisters) do
                -- Check if canister is active and is a Red or Blue AOE
                if c.isAoE and not c.isFinished and c.team ~= User.TEAM_NEUTRAL then
                    local dx = center_x - (c.x + c.size/2)
                    local dy = center_y - (c.y + c.size/2)
                    local distSq = dx*dx + dy*dy
                    
                    -- If inside the blast radius, they convert!
                    if distSq < c.blastRadius * c.blastRadius then
                        
                        -- FIX: Specific behavior based on state
                        if self.isInsane then
                            -- Insane users radicalize (convert + rage)
                            self:setTeam(c.team) 
                            self:setAggressive(true)
                            self.isRaging = true
                            self.rageTimer = RAGE_DURATION 
                        else
                            -- Neutral users simply convert (passive)
                            self:setTeam(c.team)
                            -- NO RAGE HERE
                        end

                        -- Stop current movement
                        self.vx = 0
                        self.vy = 0
                        return -- Stop update logic immediately as state changed
                    end
                end
            end
        end
    end


    -- === 2. BEHAVIOR TREES ===
    
    -- A. INSANE BEHAVIOR (Seek high population, kill)
    if self.isInsane then
        
        -- 1. Shooting (Target nearest enemy)
        self.gunTimer = self.gunTimer - dt
        if self.gunTimer <= 0 then
            local nearest = nil
            local minSq = GUN_RANGE * GUN_RANGE
            for _, u in ipairs(allUsers) do
                -- Insane targets ANY living user
                if u ~= self and u.hp > 0 then
                    local dx = u.x - self.x
                    local dy = u.y - self.y
                    local dSq = dx*dx + dy*dy
                    if dSq < minSq then minSq = dSq; nearest = u end
                end
            end
            if nearest then
                self.gunTimer = GUN_COOLDOWN
                local killed = nearest:takeDamage(GUN_DAMAGE)
                if killed then
                    self.killCount = self.killCount + 1
                    nearest.killedByInsane = true 
                    if self.killCount >= KILLS_UNTIL_SUICIDE then
                        self.hp = 0; self.killedByToxic = true 
                    end
                end
                self.bulletTrace = {tx = nearest.x + nearest.width/2, ty = nearest.y + nearest.height/2, life = 0.05}
            end
        end
        
        -- 2. MOVEMENT: Seek Nearest High Population Area
        local targetX, targetY = nil, nil
        local bestDensity = 0
        local searchRadius = 250 
        local searchStep = 100 -- Grid search for density
        local runSpeed = 280
        
        -- Search 9 points around current position + center screen
        local searchPoints = {}
        for i = -1, 1 do
            for j = -1, 1 do
                table.insert(searchPoints, {x = self.x + i * searchStep, y = self.y + j * searchStep})
            end
        end
        table.insert(searchPoints, {x = screenW / 2, y = screenH / 2})

        for _, p in ipairs(searchPoints) do
            local density = 0
            for _, u in ipairs(allUsers) do
                if u ~= self and u.hp > 0 then
                    local dx = u.x - p.x
                    local dy = u.y - p.y
                    if (dx*dx + dy*dy) < searchRadius * searchRadius then
                        density = density + 1
                    end
                end
            end
            
            -- Prioritize areas with users, weighted by distance to self (closer is better)
            if density > bestDensity then
                bestDensity = density
                targetX, targetY = p.x, p.y
            end
        end
        
        if targetX then
            -- Run towards population center
            local angle = math.atan2(targetY - self.y, targetX - self.x)
            self.vx = math.cos(angle) * runSpeed
            self.vy = math.sin(angle) * runSpeed
        else
            -- If no users nearby (rare), jitter
            self.moveTimer = self.moveTimer + dt
            if self.moveTimer > 0.05 then
                self.vx = math.random(-100, 100); self.vy = math.random(-100, 100); self.moveTimer = 0
            end
        end

    -- B. TEAM AGGRESSIVE BEHAVIOR (FEARLESS)
    elseif self.isAggressive and self.team ~= User.TEAM_NEUTRAL then
        self.searchTimer = self.searchTimer - dt
        local effectiveSeekSpeed = self.isRaging and 360 or 240
        
        if (not self.target or self.target.hp <= 0) and self.searchTimer <= 0 then
            self.target = nil
            self.searchTimer = 0.25 
            local enemyTeam = (self.team == User.TEAM_RED) and User.TEAM_BLUE or User.TEAM_RED
            local nearestDistSq = math.huge
            
            for _, otherUser in ipairs(allUsers) do
                -- Aggressive users seek ENEMY TEAM or INSANE USERS
                if (otherUser.team == enemyTeam or otherUser.isInsane) and otherUser.hp > 0 then
                    local dx = otherUser.x - self.x
                    local dy = otherUser.y - self.y
                    local distSq = dx*dx + dy*dy
                    if distSq < nearestDistSq then
                        nearestDistSq = distSq
                        self.target = otherUser
                    end
                end
            end
        end
        
        if self.target and self.target.hp > 0 then
            local angle = math.atan2(self.target.y - self.y, self.target.x - self.x)
            self.vx = math.cos(angle) * effectiveSeekSpeed
            self.vy = math.sin(angle) * effectiveSeekSpeed
            self.moveTimer = 0 
        else
            if not self.isRaging then self:setAggressive(false) end
        end 

    -- C. NEUTRAL / PASSIVE BEHAVIOR
    else
        local isFleeing = false
        local isAttracted = false
        
        if toxicZones then
            for _, zone in ipairs(toxicZones) do
                local dx = (self.x + self.width/2) - zone.x
                local dy = (self.y + self.height/2) - zone.y
                local distSq = dx*dx + dy*dy
                if distSq < 6400 then 
                    local angle = math.atan2(dy, dx) 
                    self.vx = math.cos(angle) * 300
                    self.vy = math.sin(angle) * 300
                    self.moveTimer = 0 
                    isFleeing = true
                    break 
                end
            end
        end
        
        if not isFleeing and self.team == User.TEAM_NEUTRAL and canisters then
            local nearestCanister = nil
            local minCanDistSq = 62500 
            
            for _, c in ipairs(canisters) do
                if c.isAoE and not c.isFinished then
                    local cx = c.x + c.size/2; local cy = c.y + c.size/2
                    local dx = (self.x + self.width/2) - cx; local dy = (self.y + self.height/2) - cy
                    local distSq = dx*dx + dy*dy
                    if distSq < minCanDistSq then minCanDistSq = distSq; nearestCanister = c end
                end
            end
            
            if nearestCanister then
                local cx = nearestCanister.x + nearestCanister.size/2
                local cy = nearestCanister.y + nearestCanister.size/2
                local angle = math.atan2(cy - (self.y + self.height/2), cx - (self.x + self.width/2))
                self.vx = math.cos(angle) * 300
                self.vy = math.sin(angle) * 300
                self.moveTimer = 0
                isAttracted = true
            end
        end
        
        if not isFleeing and not isAttracted then
            self.moveTimer = self.moveTimer + dt
            if self.moveTimer >= self.moveDuration then
                self.vx = math.random(-100, 100) 
                
                -- SUPPLY LINE LOGIC
                if self.y < screenH * 0.6 then self.vy = math.random(-80, 120) 
                else self.vy = math.random(-100, 100) end
                
                self.moveDuration = math.random(0.5, 1.5) 
                self.moveTimer = 0
            end
        end
    end 

    -- === 3. PHYSICS ===
    self.x = self.x + self.vx * dt
    if self.x < 0 then self.x = 0; self.vx = -self.vx end
    if self.x + self.width > screenW then self.x = screenW - self.width; self.vx = -self.vx end
    self.y = self.y + self.vy * dt
    if self.y < 0 then self.y = 0; self.vy = -self.vy end
    if self.y + self.height > screenH then self.y = screenH - self.height; self.vy = -self.vy end
end

----------------------------------------------------------------------
-- DRAW LOGIC
----------------------------------------------------------------------

function User:draw()
    if not hpFont then hpFont = love.graphics.newFont(16) end
    love.graphics.push()
    
    local hpFactor = math.max(self.hp / MAX_HP, 0.2) 
    local r, g, b = unpack(self.color)
    local currentFont = love.graphics.getFont()
    local shakeX, shakeY = 0, 0
    local scaleFactor = 1.0
    
    if self.isInsane then
        if (love.timer.getTime() * 10) % 2 > 1 then r, g, b = unpack(INSANE_WHITE)
        else r, g, b = unpack(INSANE_RED) end
        scaleFactor = 1.2
        shakeX = math.random(-5, 5); shakeY = math.random(-5, 5)
    elseif self.isAggressive then
        local flash = math.abs(math.sin(love.timer.getTime() * 15)) 
        r = r + (1 - r) * flash * 0.6; g = g + (1 - g) * flash * 0.6; b = b + (1 - b) * flash * 0.6
        scaleFactor = 1.0 + (0.1 * flash)
        shakeX = math.random(-2, 2); shakeY = math.random(-2, 2)
    elseif self.team == User.TEAM_NEUTRAL and self.isolationTimer > 1.0 then
        r, g, b = r * hpFactor, g * hpFactor, b * hpFactor
        local nervousness = (self.isolationTimer - 1.0) / 3.0 
        shakeX = math.random(-2, 2) * nervousness; shakeY = math.random(-2, 2) * nervousness
    else
        r, g, b = r * hpFactor, g * hpFactor, b * hpFactor
    end
    
    if scaleFactor > 1.0 then
        love.graphics.translate(self.x + self.width/2, self.y + self.height/2)
        love.graphics.scale(scaleFactor)
        love.graphics.translate(-(self.x + self.width/2), -(self.y + self.height/2))
    end
    
    if self.bulletTrace and self.bulletTrace.life > 0 then
        love.graphics.setColor(1, 1, 0, 0.8) 
        love.graphics.setLineWidth(3)
        love.graphics.line(self.x + self.width/2, self.y + self.height/2, self.bulletTrace.tx, self.bulletTrace.ty)
        love.graphics.setLineWidth(1)
    end
    
    love.graphics.setColor(r, g, b)
    love.graphics.rectangle("fill", self.x + shakeX, self.y + shakeY, self.width, self.height)
    
    local HP_TEXT = tostring(math.ceil(self.hp)) 
    love.graphics.setFont(hpFont) 
    love.graphics.setColor(0, 0, 0, 1) 
    love.graphics.print(HP_TEXT, self.x + 4 + shakeX, self.y + 4 + shakeY) 
    love.graphics.setColor(1, 1, 1, 1) 
    love.graphics.print(HP_TEXT, self.x + 2, self.y + 2) 
    love.graphics.setFont(currentFont)
    love.graphics.pop()
end