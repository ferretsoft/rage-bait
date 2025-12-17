-- VIRTUAL RESOLUTION (1080p Vertical)
local VIRTUAL_WIDTH = 1080
local VIRTUAL_HEIGHT = 1920

-- GAMEPLAY CONSTANTS
local COMBAT_RANGE_SQ = 30 * 30
local DAMAGE_PER_HIT = 1

local BASE_SPAWN_INTERVAL = 2.0 
local MAX_RELEVANCE = 100
local BASE_RELEVANCE_DECAY = 8         
local RELEVANCE_GAIN_HIT = 1      
local RELEVANCE_GAIN_KILL = 15    
local POINTS_PER_ELIMINATION = 10

-- SCORE CONSTANTS
local SCORE_POLARIZATION = 2000 
local SCORE_DOMINATION = 5000   
local SCORE_PACIFIST = 10000    
local SCORE_EXTINCTION = 15000 

-- GAME STATES
local STATE_ATTRACT = 1
local STATE_PLAY = 2
local STATE_GAMEOVER = 3 
local STATE_LEVEL_COMPLETE = 4 
local STATE_INITIALS_INPUT = 5 
local gameState = STATE_ATTRACT

-- OBJECTS
local users = {}
local canisters = {} 
local toxicZones = {} 
local particles = {} 
local floatingTexts = {} 

-- GLOBAL VARIABLES
local score = 0 
local currentLevel = 1
local difficulty = 1.0
local relevance = MAX_RELEVANCE
local spawnTimer = 0
local scale = 1 

-- VICTORY TRACKING
local victoryType = ""
local victoryScoreAwarded = 0
local hasConflictStarted = false 

-- AIMING VARIABLES
local aimAngle = 90             
local ANGLE_SPEED = 100         
local chargeLevel = 0           
local CHARGE_SPEED = 0.4        

local chargingTeam = nil        
local isCharging = false

-- PROGRESSION LIMITS (TIERED REACH)
local BASE_MAX_REACH = 0.30     
local REACH_STAGE_1 = 0.60  
local REACH_STAGE_2 = 0.90  
local REACH_STAGE_3 = 1.00  
local currentMaxReach = BASE_MAX_REACH
local currentReachStage = 0     

-- INFLUENCE EVENT
local influenceMessageTimer = 0

-- FONTS
local largeFont 
local titleFont 
local scoreFont 

-- HIGH SCORE DATA
local highscores = {}
local currentNewScoreIndex = -1 

-- INITIALS INPUT LOGIC
local charList = {}
local charIndex = 1             
local initialsInput = {"_", "_", "_"}
local initialsIndex = 1         
local inputMoveTimer = 0        

-- CLICKBAIT QUOTES
local CLICKBAIT_QUOTES = {
    "YOU WON'T BELIEVE WHAT HAPPENED NEXT!",
    "THEY TRIED TO KEEP THIS QUIET!",
    "THIS IS THE TRUTH THEY DON'T WANT YOU TO SEE!",
    "GEN Z HATES THIS ONE SIMPLE TRICK!",
    "SOCIETY COLLAPSES AFTER THIS VIRAL TWEET!",
    "BIG PHARMA FEARS THIS CANISTER!",
    "THE MEDIA IS LYING TO YOU!",
    "IS THIS THE END OF NEUTRALITY?",
    "THE ESTABLISHMENT IS SHOCKED!",
    "REDDITORS ARE LOSING THEIR MINDS!"
}

-- DEPENDENCIES
require("Particle")   
require("User")
require("Canister") 
require("ToxicZone") 

----------------------------------------------------------------------
-- SCORE UTILITIES
----------------------------------------------------------------------

-- Function to create a floating text object
function spawnFloatingText(text, x, y, color, duration, font)
    table.insert(floatingTexts, {
        text = text,
        x = x,
        y = y,
        color = color or {1, 1, 0, 1},
        vy = -100,                     
        life = duration or 1.0,        
        duration = duration or 1.0,    
        font = font or largeFont       
    })
end

-- Global function called directly from Canister.lua on AOE creation
_G.spawnClickbaitQuote = function(x, y, team)
    local quote = CLICKBAIT_QUOTES[math.random(1, #CLICKBAIT_QUOTES)]
    
    local r, g, b = 1, 1, 1
    if team == User.TEAM_RED then r, g, b = 1, 0.2, 0.2  -- Bright Red
    elseif team == User.TEAM_BLUE then r, g, b = 0.2, 0.2, 1 end -- Bright Blue

    -- 1. Calculate width using largeFont (size 24)
    local textWidth = largeFont:getWidth(quote)
    local textHeight = largeFont:getHeight()
    
    -- 2. X Position Calculation: Start centered on hit spot (x), then clamp.
    local startX = x 
    local finalX = startX
    local margin = 10
    
    -- Check left boundary (position of text start: finalX - textWidth/2)
    if (startX - textWidth/2) < margin then
        finalX = margin + textWidth/2
    -- Check right boundary (position of text end: finalX + textWidth/2)
    elseif (startX + textWidth/2) > VIRTUAL_WIDTH - margin then
        finalX = VIRTUAL_WIDTH - margin - textWidth/2
    end
    
    -- 3. Y Position Calculation: Center of AOE (y), lifted up by 150 (AOE radius) + text height buffer (20).
    local verticalLift = 170 
    local targetY = y - verticalLift
    
    -- Clamp Y position to ensure it's below the HUD (e.g., below Y=100)
    local HUD_LIMIT = 100 
    local clampedY = math.max(targetY, HUD_LIMIT)
    
    -- spawnFloatingText expects the X coordinate to be the center point of the text
    spawnFloatingText(quote, finalX, clampedY, {r, g, b}, 2.5, largeFont)
end


----------------------------------------------------------------------
-- HIGH SCORE LOGIC (Omitted for brevity, unchanged from V87)
----------------------------------------------------------------------
function setupCharList()
    charList = {}
    for i = 65, 90 do table.insert(charList, string.char(i)) end
    for i = 48, 57 do table.insert(charList, string.char(i)) end
    table.insert(charList, "END")
end

function loadHighScores(useDefaultsOnly)
    highscores = {
        {initials = "CHA", score = 1000, level = 2},
        {initials = "OSM", score = 750, level = 1},
        {initials = "NPC", score = 250, level = 1}
    }
    
    if not useDefaultsOnly and love.filesystem.getInfo("highscore.dat", "file") then
        local data = love.filesystem.read("highscore.dat")
        if data then
            local loaded = assert(loadstring("return "..data))()
            if loaded and type(loaded) == "table" and #loaded >= 3 then
                highscores = loaded
            end
        end
    end
end

function saveHighScores()
    table.sort(highscores, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.level > b.level
    end)
    
    while #highscores > 3 do table.remove(highscores) end
    
    local scoreStrings = {}
    for _, s in ipairs(highscores) do
         table.insert(scoreStrings, string.format('{initials="%s", score=%d, level=%d}', s.initials, s.score, s.level))
    end
    
    local data = "{\n"..table.concat(scoreStrings, ",\n").."\n}"
    
    love.filesystem.write("highscore.dat", data)
    currentNewScoreIndex = -1 
end

function checkHighScores()
    if score > 0 then
        local minScore = highscores[#highscores].score
        if #highscores < 3 or score > minScore then
            local tempEntry = {initials = "???", score = score, level = currentLevel}
            table.insert(highscores, tempEntry)
            
            table.sort(highscores, function(a, b)
                if a.score ~= b.score then return a.score > b.score end
                return a.level > b.level
            end)
            
            for i, entry in ipairs(highscores) do
                if entry == tempEntry then
                    currentNewScoreIndex = i
                    break
                end
            end

            while #highscores > 3 do table.remove(highscores) end
            
            initialsInput = {"_", "_", "_"}
            initialsIndex = 1
            charIndex = 1
            gameState = STATE_INITIALS_INPUT
            return true
        end
    end
    return false
end

function resetHighScoresToDefault()
    loadHighScores(true) 
    saveHighScores()
end

----------------------------------------------------------------------
-- CORE LOGIC
----------------------------------------------------------------------

function clearAndSpawnBoard()
    users = {}
    canisters = {}
    toxicZones = {}
    particles = {}
    floatingTexts = {} 
    
    relevance = MAX_RELEVANCE 
    spawnTimer = 0 
    
    aimAngle = 90
    chargeLevel = 0
    isCharging = false
    chargingTeam = nil
    
    hasConflictStarted = false 
    currentMaxReach = BASE_MAX_REACH
    currentReachStage = 0 
    
    for i = 1, 50 do
        table.insert(users, User.new(math.random(20, VIRTUAL_WIDTH - 20), math.random(20, VIRTUAL_HEIGHT - 20)))
    end
end

function initGame()
    score = 0
    currentLevel = 1
    difficulty = 1.0
    clearAndSpawnBoard() 
    gameState = STATE_PLAY
end

function advanceToNextLevel()
    currentLevel = currentLevel + 1
    difficulty = difficulty + 0.2 
    clearAndSpawnBoard()
    gameState = STATE_PLAY
end


----------------------------------------------------------------------
-- LOVE CALLBACKS
----------------------------------------------------------------------

function love.load()
    love.window.setTitle("Rage Bait")
    love.window.setMode(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, { resizable = true })
    math.randomseed(os.time())
    
    largeFont = love.graphics.newFont(24) 
    titleFont = love.graphics.newFont(80) 
    scoreFont = love.graphics.newFont(36) 
    
    -- === TO RESET SCORES TO DEFAULT, UNCOMMENT THE FOLLOWING LINE (Then run once) ===
    -- resetHighScoresToDefault() 
    -- ===============================================================
    
    loadHighScores()
    setupCharList() 
    
    local w, h = love.graphics.getDimensions()
    scale = math.min(w/VIRTUAL_WIDTH, h/VIRTUAL_HEIGHT)
    if scale == 0 then scale = 1 end
    
    clearAndSpawnBoard() 
    gameState = STATE_ATTRACT 
end

function love.update(dt)
    if gameState == STATE_PLAY then
        -- 1. RELEVANCE DECAY
        local decay = BASE_RELEVANCE_DECAY * difficulty
        relevance = relevance - decay * dt
        
        -- CHECK LOSS: ONLY WAY TO GAME OVER
        if relevance <= 0 then 
            checkHighScores() 
            if gameState ~= STATE_INITIALS_INPUT then
                gameState = STATE_GAMEOVER 
            end
            return 
        end
        
        -- 2. TIERED PROGRESSION UNLOCK
        local updatedReach = false
        
        if score >= 750 and currentReachStage < 3 then
            currentMaxReach = REACH_STAGE_3
            currentReachStage = 3
            updatedReach = true
        elseif score >= 500 and currentReachStage < 2 then
            currentMaxReach = REACH_STAGE_2
            currentReachStage = 2
            updatedReach = true
        elseif score >= 250 and currentReachStage < 1 then
            currentMaxReach = REACH_STAGE_1
            currentReachStage = 1
            updatedReach = true
        end

        if updatedReach then
             influenceMessageTimer = 3.0
        end

        if influenceMessageTimer > 0 then influenceMessageTimer = influenceMessageTimer - dt end

        -- 3. VICTORY CHECK
        local redC = 0; local blueC = 0; local greyC = 0; local total = 0
        for _, u in ipairs(users) do
            if u.hp > 0 then
                total = total + 1
                if u.team == User.TEAM_RED then redC = redC + 1
                elseif u.team == User.TEAM_BLUE then blueC = blueC + 1
                else greyC = greyC + 1 end
            end
        end
        
        if redC > 0 or blueC > 0 then hasConflictStarted = true end
        
        local victory = false
        
        if total > 0 then
            -- Win 1-3: Domination/Polarization
            if greyC == 0 then
                if redC > 0 and blueC > 0 then
                    victoryType = "POLARIZATION COMPLETE"
                    victoryScoreAwarded = SCORE_POLARIZATION
                    victory = true
                elseif redC == total then
                    victoryType = "RED DOMINANCE"
                    victoryScoreAwarded = SCORE_DOMINATION
                    victory = true
                elseif blueC == total then
                    victoryType = "BLUE DOMINANCE"
                    victoryScoreAwarded = SCORE_DOMINATION
                    victory = true
                end
            -- Win 4: Peace Restored
            elseif greyC == total and hasConflictStarted then
                victoryType = "PEACE RESTORED"
                victoryScoreAwarded = SCORE_PACIFIST
                victory = true
            end
            
        elseif total == 0 then
            -- Win 5: TOTAL ANNIHILATION
            victoryType = "TOTAL ANNIHILATION"
            victoryScoreAwarded = SCORE_EXTINCTION
            victory = true
        end
        
        if victory then
            score = score + victoryScoreAwarded
            gameState = STATE_LEVEL_COMPLETE
            return 
        end

        -- 4. PLAYER INPUTS & SPAWNING
        if love.keyboard.isDown("right") or love.keyboard.isDown("d") then aimAngle = aimAngle - ANGLE_SPEED * dt end
        if love.keyboard.isDown("left") or love.keyboard.isDown("a") then aimAngle = aimAngle + ANGLE_SPEED * dt end
        aimAngle = math.max(10, math.min(170, aimAngle)) 

        if isCharging then
            chargeLevel = chargeLevel + CHARGE_SPEED * dt
            if chargeLevel > currentMaxReach then chargeLevel = currentMaxReach end
        else
            chargeLevel = 0
        end

        spawnTimer = spawnTimer + dt
        local currentSpawnInterval = BASE_SPAWN_INTERVAL / difficulty 
        if spawnTimer >= currentSpawnInterval then
            spawnTimer = 0
            table.insert(users, User.new(math.random(20, VIRTUAL_WIDTH-20), math.random(20, VIRTUAL_HEIGHT/2)))
        end
    
    elseif gameState == STATE_INITIALS_INPUT then
        inputMoveTimer = inputMoveTimer - dt
        if inputMoveTimer <= 0 then
            local moved = false
            if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
                charIndex = charIndex - 1
                moved = true
            elseif love.keyboard.isDown("down") or love.keyboard.isDown("s") then
                charIndex = charIndex + 1
                moved = true
            end

            if charIndex < 1 then charIndex = #charList end
            if charIndex > #charList then charIndex = 1 end
            
            if moved then inputMoveTimer = 0.1 end
        end
    end

    -- SHARED LOGIC
    local usersToKill = {} 
    
    for i, user in ipairs(users) do
        if user.hp <= 0 then table.insert(usersToKill, user) end
        
        if user.team ~= User.TEAM_NEUTRAL and user.hp > 0 then 
            for j = i + 1, #users do 
                local uB = users[j]
                local isEnemyTeam = (user.team == 1 and uB.team == 2) or (user.team == 2 and uB.team == 1)
                local attackingInsane = (user.team ~= User.TEAM_NEUTRAL and uB.isInsane)
                
                if isEnemyTeam or attackingInsane then
                    local dist = (user.x - uB.x)^2 + (user.y - uB.y)^2
                    if dist < COMBAT_RANGE_SQ then
                        if attackingInsane then
                            if uB:takeDamage(DAMAGE_PER_HIT) then 
                                table.insert(usersToKill, uB)
                                if gameState==STATE_PLAY then relevance = math.min(relevance+RELEVANCE_GAIN_HIT, MAX_RELEVANCE) end
                            end
                        elseif isEnemyTeam then
                            if math.random() > 0.5 then 
                                if uB:takeDamage(DAMAGE_PER_HIT) then table.insert(usersToKill, uB)
                                else if gameState==STATE_PLAY then relevance = math.min(relevance+RELEVANCE_GAIN_HIT, MAX_RELEVANCE) end end
                            else
                                if user:takeDamage(DAMAGE_PER_HIT) then table.insert(usersToKill, user)
                                else if gameState==STATE_PLAY then relevance = math.min(relevance+RELEVANCE_GAIN_HIT, MAX_RELEVANCE) end end
                            end
                        end
                    end
                end
            end
        end
    end
    
    for _, dead in ipairs(usersToKill) do
        for i, u in ipairs(users) do
            if u == dead then
                table.remove(users, i)
                table.insert(toxicZones, ToxicZone.new(dead.x, dead.y))
                
                -- Spawn floating text upon user elimination for points awarded
                if gameState == STATE_PLAY then
                    if not dead.killedByToxic and not dead.killedByInsane then
                        score = score + POINTS_PER_ELIMINATION
                        relevance = math.min(relevance + RELEVANCE_GAIN_KILL, MAX_RELEVANCE)
                        
                        -- Points are drawn relative to the object's center (x, y)
                        spawnFloatingText("+" .. POINTS_PER_ELIMINATION, u.x + u.width/2, u.y + u.height/2, {1, 1, 0})
                    end
                end
                break
            end
        end
    end
    
    -- Update floating texts (move up and decay)
    for i = #floatingTexts, 1, -1 do
        local ft = floatingTexts[i]
        ft.y = ft.y + ft.vy * dt
        ft.life = ft.life - dt
        if ft.life <= 0 then
            table.remove(floatingTexts, i)
        end
    end
    
    if gameState ~= STATE_INITIALS_INPUT then
        for _, u in ipairs(users) do u:update(dt, VIRTUAL_WIDTH, VIRTUAL_HEIGHT, users, toxicZones, canisters, difficulty) end
        
        -- Check canisters for explosion event (now relying on Canister.lua to call _G.spawnClickbaitQuote)
        for i=#canisters,1,-1 do 
            local canister = canisters[i]
            local exploded = canister:update(dt, VIRTUAL_WIDTH, VIRTUAL_HEIGHT, users, canisters, particles)
            
            -- Remove the canister if Canister:update returns true
            if exploded then 
                table.remove(canisters, i) 
            end
        end
        for i=#particles,1,-1 do if particles[i]:update(dt) then table.remove(particles, i) end end
        for i=#toxicZones,1,-1 do if toxicZones[i]:update(dt, users) then table.remove(toxicZones, i) end end
    end
    
    if gameState == STATE_ATTRACT and #users < 5 then clearAndSpawnBoard() end
end

function love.draw()
    love.graphics.push()
    love.graphics.scale(scale, scale)
    love.graphics.setFont(largeFont) 
    
    if gameState ~= STATE_INITIALS_INPUT then
        for _, z in ipairs(toxicZones) do z:draw() end
        for _, c in ipairs(canisters) do c:draw() end
        for _, u in ipairs(users) do u:draw() end
        for _, p in ipairs(particles) do p:draw() end 
    end
    
    local function shadowText(txt, x, y, r, g, b, f)
        local font = f or largeFont
        love.graphics.setFont(font)
        love.graphics.setColor(0,0,0,1)
        love.graphics.print(txt, x+3, y+3)
        love.graphics.setColor(r,g,b,1)
        love.graphics.print(txt, x, y)
    end
    
    -- High Score Display Helper
    local function drawHighScores(yStart)
        local titleText = (gameState == STATE_INITIALS_INPUT) and "ENTER YOUR INITIALS" or "HIGH SCORES"
        local titleW = titleFont:getWidth(titleText)
        shadowText(titleText, (VIRTUAL_WIDTH - titleW)/2, yStart, 1, 1, 1, titleFont)
        
        local yOffset = yStart + titleFont:getHeight() + 20
        
        for i, entry in ipairs(highscores) do
            local rankText = "#"..i
            local initialsText = (i == currentNewScoreIndex and gameState == STATE_INITIALS_INPUT) and table.concat(initialsInput) or entry.initials
            local scoreText = entry.score
            local levelText = "(L: "..entry.level..")"
            
            local yPos = yOffset + i * scoreFont:getHeight() * 1.5
            
            -- Rank
            shadowText(rankText, VIRTUAL_WIDTH*0.15, yPos, 0.7, 0.7, 0.7, scoreFont)
            -- Initials (Flashes if current rank is being entered)
            local r, g, b = 1, 1, 1
            if i == currentNewScoreIndex and gameState == STATE_INITIALS_INPUT and (love.timer.getTime()*8)%2 > 1 then
                r, g, b = 1, 0.8, 0 -- Flash yellow
            end
            
            shadowText(initialsText, VIRTUAL_WIDTH*0.35 - scoreFont:getWidth(initialsText)/2, yPos, r, g, b, scoreFont)
            -- Score
            shadowText(scoreText, VIRTUAL_WIDTH*0.60 - scoreFont:getWidth(tostring(scoreText))/2, yPos, 1, 0.8, 0, scoreFont)
            -- Level
            shadowText(levelText, VIRTUAL_WIDTH*0.85, yPos, 0.7, 0.7, 0.7, scoreFont)
        end
    end
    
    if gameState == STATE_PLAY then
        -- TARGETING
        local startX = VIRTUAL_WIDTH / 2
        local startY = VIRTUAL_HEIGHT
        local rad = math.rad(aimAngle)
        local MAX_LINE_LENGTH = VIRTUAL_HEIGHT * 1.1 
        local dist = MAX_LINE_LENGTH * chargeLevel
        local tx = startX + math.cos(rad) * dist
        local ty = startY - math.sin(rad) * dist 
        
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        local lineEndX = startX + math.cos(rad) * (MAX_LINE_LENGTH * currentMaxReach)
        local lineEndY = startY - math.sin(rad) * (MAX_LINE_LENGTH * currentMaxReach)
        love.graphics.line(startX, startY, lineEndX, lineEndY)
        
        if isCharging then
            if chargingTeam == User.TEAM_RED then love.graphics.setColor(1, 0, 0, 1)
            else love.graphics.setColor(0, 0, 1, 1) end
        else
            love.graphics.setColor(1, 1, 1, 0.5)
        end
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", tx, ty, 20)
        love.graphics.line(tx-10, ty, tx+10, ty)
        love.graphics.line(tx, ty-10, tx, ty+10)
        
        -- METER
        local meterW, meterH = 20, 600
        local meterX = VIRTUAL_WIDTH - 50
        local meterY = VIRTUAL_HEIGHT - 300 - meterH
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", meterX, meterY, meterW, meterH)
        local limitY = meterY + meterH * (1 - currentMaxReach)
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.line(meterX - 10, limitY, meterX + meterW + 10, limitY)
        local fillH = meterH * chargeLevel
        local fillY = meterY + meterH - fillH
        if chargingTeam == User.TEAM_RED then love.graphics.setColor(1, 0, 0)
        elseif chargingTeam == User.TEAM_BLUE then love.graphics.setColor(0, 0, 1)
        else love.graphics.setColor(1, 1, 1) end
        love.graphics.rectangle("fill", meterX, fillY, meterW, fillH)

        -- HUD
        shadowText("LEVEL " .. currentLevel, 30, 40, 1, 1, 1, scoreFont)
        
        local scoreText = "SCORE: " .. score
        local sw = scoreFont:getWidth(scoreText)
        shadowText(scoreText, VIRTUAL_WIDTH - sw - 30, 40, 1, 0.8, 0, scoreFont)
        
        local redC = 0; local blueC = 0; local greyC = 0; local total = 0
        for _, u in ipairs(users) do 
            if u.hp > 0 then 
                total = total + 1
                if u.team == 1 then redC = redC+1 elseif u.team == 2 then blueC = blueC+1 else greyC = greyC+1 end 
            end 
        end
        if total > 0 then
            local balW, balH = 400, 20
            local balX = (VIRTUAL_WIDTH - balW)/2
            local balY = 50
            local rW = (redC/total) * balW
            local nW = (greyC/total) * balW
            local bW = (blueC/total) * balW
            love.graphics.setColor(1, 0, 0); love.graphics.rectangle("fill", balX, balY, rW, balH)
            love.graphics.setColor(0.5, 0.5, 0.5); love.graphics.rectangle("fill", balX+rW, balY, nW, balH)
            love.graphics.setColor(0, 0, 1); love.graphics.rectangle("fill", balX+rW+nW, balY, bW, balH)
            love.graphics.setColor(1,1,1); love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", balX, balY, balW, balH)
        end
        
        -- Relevance
        local barW, barH = 600, 30
        local bx = (VIRTUAL_WIDTH - barW)/2
        love.graphics.setColor(0.2,0.2,0.2)
        love.graphics.rectangle("fill", bx, 40, barW, barH)
        love.graphics.setColor(1 - (relevance/MAX_RELEVANCE), relevance/MAX_RELEVANCE, 0)
        love.graphics.rectangle("fill", bx, 40, barW * (relevance/MAX_RELEVANCE), barH)
        shadowText("RELEVANCE", bx+220, 44, 1,1,1)
        
        if influenceMessageTimer > 0 and (love.timer.getTime()*10)%2 > 1 then
             local m = "INFLUENCE EXPANDED!"
             local w = titleFont:getWidth(m)
             shadowText(m, (VIRTUAL_WIDTH-w)/2, VIRTUAL_HEIGHT*0.4, 0,1,1, titleFont)
        end
        
    elseif gameState == STATE_ATTRACT then
        love.graphics.setColor(0,0,0,0.6)
        love.graphics.rectangle("fill",0,0,VIRTUAL_WIDTH,VIRTUAL_HEIGHT)
        local t = "RAGE BAIT"
        local w = titleFont:getWidth(t)
        shadowText(t, (VIRTUAL_WIDTH-w)/2, VIRTUAL_HEIGHT*0.1, 1,0.3,0, titleFont)
        
        drawHighScores(VIRTUAL_HEIGHT * 0.25)
        
        if (love.timer.getTime()*2)%2 > 1 then
            local i = "INSERT COIN"
            local iw = titleFont:getWidth(i)
            shadowText(i, (VIRTUAL_WIDTH-iw)/2, VIRTUAL_HEIGHT*0.65, 0,1,0, titleFont)
        end
        local s = "PRESS [ENTER] TO START"
        local sw = largeFont:getWidth(s)
        shadowText(s, (VIRTUAL_WIDTH-sw)/2, VIRTUAL_HEIGHT*0.75, 1,1,1, largeFont)
        
    elseif gameState == STATE_GAMEOVER then
        love.graphics.setColor(0,0,0,0.7)
        love.graphics.rectangle("fill",0,0,VIRTUAL_WIDTH,VIRTUAL_HEIGHT)
        local t = "IRRELEVANT"
        local w = titleFont:getWidth(t)
        shadowText(t, (VIRTUAL_WIDTH-w)/2, VIRTUAL_HEIGHT*0.1, 0.5,0.5,0.5, titleFont)
        
        local s = "FINAL SCORE: "..score
        local sw = scoreFont:getWidth(s)
        shadowText(s, (VIRTUAL_WIDTH-sw)/2, VIRTUAL_HEIGHT*0.2, 1,1,0, scoreFont)
        
        local l = "REACHED LEVEL " .. currentLevel
        local lw = scoreFont:getWidth(l)
        shadowText(l, (VIRTUAL_WIDTH-lw)/2, VIRTUAL_HEIGHT*0.25, 1,1,1, scoreFont)
        
        drawHighScores(VIRTUAL_HEIGHT * 0.35)
        
        local r = "PRESS [ENTER] TO RESET"
        local rw = largeFont:getWidth(r)
        shadowText(r, (VIRTUAL_WIDTH-rw)/2, VIRTUAL_HEIGHT*0.85, 1,1,1, largeFont)
        
    elseif gameState == STATE_LEVEL_COMPLETE then
        love.graphics.setColor(0, 0, 0, 0.8) 
        love.graphics.rectangle("fill", 0, 0, VIRTUAL_WIDTH, VIRTUAL_HEIGHT)
        
        local t = victoryType
        local w = titleFont:getWidth(t)
        shadowText(t, (VIRTUAL_WIDTH-w)/2, VIRTUAL_HEIGHT*0.3, 0,1,0, titleFont)
        
        local s = "BONUS: +"..victoryScoreAwarded
        local sw = largeFont:getWidth(s)
        shadowText(s, (VIRTUAL_WIDTH-sw)/2, VIRTUAL_HEIGHT*0.45, 1,1,0, largeFont)
        
        local l = "STARTING LEVEL "..(currentLevel + 1)
        local lw = largeFont:getWidth(l)
        shadowText(l, (VIRTUAL_WIDTH-lw)/2, VIRTUAL_HEIGHT*0.6, 1,1,1, largeFont)
        
        local p = "PRESS [ENTER] TO CONTINUE"
        local pw = largeFont:getWidth(p)
        shadowText(p, (VIRTUAL_WIDTH-pw)/2, VIRTUAL_HEIGHT*0.7, 1,1,1, largeFont)
    
    elseif gameState == STATE_INITIALS_INPUT then
        love.graphics.setColor(0,0,0,0.9)
        love.graphics.rectangle("fill",0,0,VIRTUAL_WIDTH,VIRTUAL_HEIGHT)

        drawHighScores(VIRTUAL_HEIGHT * 0.1)

        -- Draw the character selection list
        local listY = VIRTUAL_HEIGHT * 0.6
        local listX = VIRTUAL_WIDTH / 2
        local charSpacing = 50
        
        shadowText("SELECT LETTER (UP/DOWN + R/B/ENTER)", listX, listY - 100, 1, 1, 1, largeFont)

        for i = 1, #charList do
            local char = charList[i]
            local charY = listY + (i - charIndex) * charSpacing
            
            local r, g, b = 0.5, 0.5, 0.5
            local f = largeFont
            
            if charY > listY - 150 and charY < listY + 150 then
                if i == charIndex then
                    r, g, b = 1, 1, 1 
                    f = scoreFont
                    love.graphics.setColor(1, 0.8, 0, 0.5) 
                    love.graphics.rectangle("fill", listX - 100, charY - 20, 200, 40)
                end
                
                shadowText(char, listX, charY, r, g, b, f)
            end
        end

        local instruction = (initialsIndex <= 3) and 
                            ("SELECT INITIAL #" .. initialsIndex .. ": " .. charList[charIndex]) or 
                            "PRESS R/B/ENTER TO FINISH"
                            
        shadowText(instruction, listX, VIRTUAL_HEIGHT * 0.9, 0, 1, 0, largeFont)
    end

    -- Draw Floating Texts (AOE/Points)
    if gameState == STATE_PLAY then
        for _, ft in ipairs(floatingTexts) do
            local alpha = ft.life / ft.duration
            local r, g, b = unpack(ft.color)
            
            love.graphics.setFont(ft.font)
            
            local textWidth = ft.font:getWidth(ft.text)
            
            -- Draw Shadow (Text centered on ft.x, ft.y)
            local drawX = ft.x - textWidth/2
            local drawY = ft.y
            
            love.graphics.setColor(0, 0, 0, alpha)
            love.graphics.print(ft.text, drawX + 2, drawY + 2)
            
            -- Draw Text
            love.graphics.setColor(r, g, b, alpha)
            love.graphics.print(ft.text, drawX, drawY)
        end
    end
    
    love.graphics.pop()
    love.graphics.setFont(largeFont)
    love.graphics.setColor(1,1,1)
    love.graphics.print("FPS: "..love.timer.getFPS(), 10, 10)
end

function love.keypressed(key)
    if gameState == STATE_INITIALS_INPUT then
        -- Handle Selection
        if key == "r" or key == "b" or key == "return" or key == " " then
            local selectedChar = charList[charIndex]
            
            if initialsIndex <= 3 then
                if selectedChar == "END" then
                    while initialsIndex <= 3 do
                        initialsInput[initialsIndex] = "_"
                        initialsIndex = initialsIndex + 1
                    end
                else
                    initialsInput[initialsIndex] = selectedChar
                    initialsIndex = initialsIndex + 1
                    charIndex = 1 
                end
            end
            
            if initialsIndex > 3 then
                local finalInitials = table.concat(initialsInput)
                highscores[currentNewScoreIndex].initials = finalInitials
                saveHighScores()
                gameState = STATE_GAMEOVER
            end
        end
        return
    end

    if key == "return" then
        if gameState == STATE_ATTRACT or gameState == STATE_GAMEOVER then 
            initGame() 
        elseif gameState == STATE_LEVEL_COMPLETE then
            advanceToNextLevel()
        end
    end
    
    if gameState == STATE_PLAY then
        if key == "r" and not isCharging then
            isCharging = true
            chargingTeam = User.TEAM_RED
            chargeLevel = 0.05 
        elseif key == "b" and not isCharging then
            isCharging = true
            chargingTeam = User.TEAM_BLUE
            chargeLevel = 0.05
        end
    end
end

function love.keyreleased(key)
    if gameState == STATE_PLAY then
        if isCharging then
            if (key == "r" and chargingTeam == User.TEAM_RED) or 
               (key == "b" and chargingTeam == User.TEAM_BLUE) then
                
                local startX = VIRTUAL_WIDTH / 2
                local startY = VIRTUAL_HEIGHT
                local rad = math.rad(aimAngle)
                local MAX_LINE_LENGTH = VIRTUAL_HEIGHT * 1.1 
                local dist = MAX_LINE_LENGTH * chargeLevel
                
                local tx = startX + math.cos(rad) * dist
                local ty = startY - math.sin(rad) * dist
                
                table.insert(canisters, Canister.new(startX, startY, tx, ty, chargingTeam))
                
                isCharging = false
                chargingTeam = nil
                chargeLevel = 0
            end
        end
    end
end

function love.resize(w, h)
    scale = math.min(w/VIRTUAL_WIDTH, h/VIRTUAL_HEIGHT)
end