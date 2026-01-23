-- src/core/webcam.lua
-- Fake webcam window with animated character that comments on player actions

local Webcam = {}
local Constants = require("src.constants")
local WindowFrame = require("src.core.window_frame")
local ChasePortrait = require("src.core.chase_portrait")

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

-- Import Chase Paxton dialogue
local ChasePaxton = require("src.core.chase_paxton")

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
    
    -- Update portrait animation
    ChasePortrait.setTalking(characterState.isTalking)
    ChasePortrait.update(dt)
    
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
    local comment = ChasePaxton.getComment(eventType)
    if not comment then return end
    
    currentComment = comment
    commentTimer = commentDuration
    
    -- Trigger talking animation
    characterState.isTalking = true
    characterState.talkTimer = characterState.talkDuration
    characterState.frame = 1  -- Reset to first talking frame
end

-- Draw webcam window
function Webcam.draw()
    local titleBarHeight = 20
    local borderWidth = 3
    
    -- Draw transparent black background for content area
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", WEBCAM_X + borderWidth, WEBCAM_Y + borderWidth + titleBarHeight, 
        WEBCAM_WIDTH - (borderWidth * 2), WEBCAM_HEIGHT - (borderWidth * 2) - titleBarHeight)
    
    -- Draw Windows 95 style frame with title bar
    WindowFrame.draw(WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT, "Webcam")
    
    -- Draw character portrait - adjust for title bar
    local charX = WEBCAM_X + WEBCAM_WIDTH / 2
    local charY = WEBCAM_Y + titleBarHeight + borderWidth + (WEBCAM_HEIGHT - titleBarHeight - borderWidth) / 2
    
    -- Calculate available space (accounting for title bar and borders)
    local availableWidth = WEBCAM_WIDTH - (borderWidth * 2)
    local availableHeight = WEBCAM_HEIGHT - titleBarHeight - (borderWidth * 2)
    
    -- Calculate scale to fit within webcam window
    local portraitScale = ChasePortrait.calculateScale(availableWidth, availableHeight, 10)
    ChasePortrait.draw(charX, charY, portraitScale)
    
    -- Draw comment text if active
    if currentComment then
        -- Explicitly use 14px font (don't rely on getFont() which may return a different font from elsewhere)
        local commentFont = love.graphics.newFont(14)
        love.graphics.setFont(commentFont)
        local textWidth = commentFont:getWidth(currentComment)
        local textX = WEBCAM_X + (WEBCAM_WIDTH - textWidth) / 2
        local textY = WEBCAM_Y + WEBCAM_HEIGHT - 25 - titleBarHeight
        
        -- Text background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", textX - 5, textY - 2, textWidth + 10, 20)
        
        -- Text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(currentComment, textX, textY)
    end
end

return Webcam

