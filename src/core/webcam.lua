-- src/core/webcam.lua
-- Fake webcam window with animated character that comments on player actions

local Webcam = {}
local Constants = require("src.constants")

-- Webcam window dimensions and position
local WEBCAM_WIDTH = 300
local WEBCAM_HEIGHT = 200
-- Position webcam on the right side, plot will be on the left
local WEBCAM_X = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH - WEBCAM_WIDTH - 20
local WEBCAM_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + 20

-- Character animation
local characterState = {
    frame = 1,
    frameTimer = 0,
    frameTime = 0.15,  -- Time between frames
    idleFrames = 4,    -- Number of idle animation frames
    talkingFrames = 3, -- Number of talking animation frames
    isTalking = false,
    talkTimer = 0,
    talkDuration = 2.0  -- How long to show talking animation
}

-- Current comment
local currentComment = nil
local commentTimer = 0
local commentDuration = 3.0  -- How long to show a comment

-- Comment pool organized by event type
-- Chase Paxton: Middle manager from hell, tech bro lingo, panicky
local comments = {
    game_start = {
        "Let's maximize engagement!",
        "Time to hit those KPIs!",
        "Show me those metrics!",
        "Let's optimize this workflow!"
    },
    unit_killed = {
        "Great conversion rate!",
        "That's a quality engagement!",
        "Synergy achieved!",
        "Disrupting the status quo!"
    },
    multiple_kills = {
        "Viral growth!",
        "Exponential scaling!",
        "Network effects in action!",
        "That's leverage!"
    },
    powerup_collected = {
        "Performance boost acquired!",
        "Upgrading your stack!",
        "That's a game-changer!",
        "Optimization unlocked!"
    },
    engagement_low = {
        "Watch those metrics!",
        "Engagement is tanking!",
        "We're bleeding users!",
        "The Auditor will see this!"
    },
    engagement_high = {
        "Crushing those KPIs!",
        "We're in the green!",
        "Metrics are off the charts!",
        "This is what I'm talking about!"
    },
    level_complete = {
        "Quarterly goals achieved!",
        "We're crushing it!",
        "That's a win-win!",
        "Moving the needle!"
    },
    game_over = {
        "We're in deep trouble!",
        "The Auditor will not be happy!",
        "This is a critical failure!",
        "We need to pivot NOW!"
    },
    combo = {
        "Compound growth!",
        "That's a multiplier!",
        "Cascading engagement!",
        "Momentum building!"
    },
    near_miss = {
        "Almost optimized!",
        "Close to peak performance!",
        "We need better targeting!",
        "A/B test that approach!"
    }
}

-- Initialize webcam
function Webcam.init()
    characterState.frame = 1
    characterState.frameTimer = 0
    characterState.isTalking = false
    characterState.talkTimer = 0
    currentComment = nil
    commentTimer = 0
end

-- Update webcam animation
function Webcam.update(dt)
    -- Update character animation
    characterState.frameTimer = characterState.frameTimer + dt
    
    local frames = characterState.isTalking and characterState.talkingFrames or characterState.idleFrames
    
    if characterState.frameTimer >= characterState.frameTime then
        characterState.frameTimer = 0
        characterState.frame = characterState.frame + 1
        if characterState.frame > frames then
            characterState.frame = 1
        end
    end
    
    -- Update talking state
    if characterState.isTalking then
        characterState.talkTimer = characterState.talkTimer - dt
        if characterState.talkTimer <= 0 then
            characterState.isTalking = false
        end
    end
    
    -- Update comment display
    if currentComment then
        commentTimer = commentTimer - dt
        if commentTimer <= 0 then
            currentComment = nil
        end
    end
end

-- Show a comment
function Webcam.showComment(eventType, count)
    local commentList = comments[eventType]
    if not commentList or #commentList == 0 then return end
    
    -- Select random comment from the list
    local index = math.random(1, #commentList)
    currentComment = commentList[index]
    commentTimer = commentDuration
    
    -- Trigger talking animation
    characterState.isTalking = true
    characterState.talkTimer = characterState.talkDuration
    characterState.frame = 1  -- Reset to first talking frame
end

-- Draw webcam window
function Webcam.draw()
    -- Draw webcam window frame
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT)
    
    -- Draw border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT)
    
    -- Draw inner border (webcam style)
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", WEBCAM_X + 5, WEBCAM_Y + 5, WEBCAM_WIDTH - 10, WEBCAM_HEIGHT - 10)
    
    -- Draw character (simple animated face)
    local charX = WEBCAM_X + WEBCAM_WIDTH / 2
    local charY = WEBCAM_Y + WEBCAM_HEIGHT / 2 - 20
    
    -- Character head (circle)
    love.graphics.setColor(0.9, 0.8, 0.7, 1)  -- Skin tone
    love.graphics.circle("fill", charX, charY, 40)
    love.graphics.setColor(0.7, 0.6, 0.5, 1)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", charX, charY, 40)
    
    -- Eyes (animate based on frame)
    local eyeOffset = characterState.isTalking and 3 or 0
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.circle("fill", charX - 12, charY - 5, 5 + eyeOffset)
    love.graphics.circle("fill", charX + 12, charY - 5, 5 + eyeOffset)
    
    -- Mouth (changes when talking)
    if characterState.isTalking then
        -- Open mouth (oval)
        local mouthHeight = 8 + (characterState.frame % 2) * 3  -- Animate open/close
        love.graphics.setColor(0.3, 0.2, 0.2, 1)
        love.graphics.ellipse("fill", charX, charY + 10, 10, mouthHeight)
    else
        -- Closed mouth (line or small smile)
        love.graphics.setColor(0.4, 0.3, 0.3, 1)
        love.graphics.setLineWidth(2)
        love.graphics.arc("line", "open", charX, charY + 10, 8, 0, math.pi)
    end
    
    -- Draw comment text if active
    if currentComment then
        love.graphics.setFont(love.graphics.getFont() or love.graphics.newFont(14))
        local textWidth = love.graphics.getFont():getWidth(currentComment)
        local textX = WEBCAM_X + (WEBCAM_WIDTH - textWidth) / 2
        local textY = WEBCAM_Y + WEBCAM_HEIGHT - 25
        
        -- Text background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", textX - 5, textY - 2, textWidth + 10, 20)
        
        -- Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(currentComment, textX, textY)
    end
end

return Webcam

