-- src/core/chase_portrait.lua
-- Shared module for drawing Chase Paxton portrait with layered animations

local ChasePortrait = {}
local Constants = require("src.constants")
local Engagement = require("src.core.engagement")

-- Portrait images
local portraitImages = {
    base = nil,           -- FullFace_Neutral_happy.png (base portrait)
    mouthOpen = nil,      -- Mouth_Open.png
    mouthSmile = nil,     -- Mouth_Smile.png
    angry = nil,          -- Angry.png
    worried = nil,        -- worried.png
    layer1 = nil          -- Layer-1.png
}

-- Animation state
local animationState = {
    mouthOpenTimer = 0,
    mouthOpenSpeed = 0.15,  -- Time between mouth open/close (for talking animation)
    isTalking = false
}

-- Load all portrait images
function ChasePortrait.load()
    local success
    
    -- Base portrait
    success, portraitImages.base = pcall(love.graphics.newImage, 
        "assets/ChasePaxtonPortait/FullFace_Neutral_happy.png")
    if not success then
        print("Warning: Could not load Chase Paxton base portrait")
    end
    
    -- Mouth layers
    success, portraitImages.mouthOpen = pcall(love.graphics.newImage,
        "assets/ChasePaxtonPortait/Mouth_Open.png")
    if not success then
        print("Warning: Could not load Chase Paxton mouth open")
    end
    
    success, portraitImages.mouthSmile = pcall(love.graphics.newImage,
        "assets/ChasePaxtonPortait/Mouth_Smile.png")
    if not success then
        print("Warning: Could not load Chase Paxton mouth smile")
    end
    
    -- Emotion layers
    success, portraitImages.angry = pcall(love.graphics.newImage,
        "assets/ChasePaxtonPortait/Angry.png")
    if not success then
        print("Warning: Could not load Chase Paxton angry")
    end
    
    success, portraitImages.worried = pcall(love.graphics.newImage,
        "assets/ChasePaxtonPortait/worried.png")
    if not success then
        print("Warning: Could not load Chase Paxton worried")
    end
    
    -- Additional layer
    success, portraitImages.layer1 = pcall(love.graphics.newImage,
        "assets/ChasePaxtonPortait/Layer-1.png")
    if not success then
        print("Warning: Could not load Chase Paxton layer 1")
    end
end

-- Update animation
function ChasePortrait.update(dt)
    if animationState.isTalking then
        animationState.mouthOpenTimer = animationState.mouthOpenTimer + dt
    end
end

-- Set talking state
function ChasePortrait.setTalking(talking)
    animationState.isTalking = talking
    if not talking then
        animationState.mouthOpenTimer = 0
    end
end

-- Calculate appropriate scale to fit portrait within given dimensions
-- Parameters:
--   availableWidth: Available width in pixels
--   availableHeight: Available height in pixels
--   padding: Optional padding on all sides (default 10)
-- Returns: Scale factor
function ChasePortrait.calculateScale(availableWidth, availableHeight, padding)
    if not portraitImages.base then
        return 1.0
    end
    
    padding = padding or 10
    local baseWidth = portraitImages.base:getWidth()
    local baseHeight = portraitImages.base:getHeight()
    
    -- Calculate scale based on both width and height, use the smaller one to ensure it fits
    local scaleX = (availableWidth - padding * 2) / baseWidth
    local scaleY = (availableHeight - padding * 2) / baseHeight
    
    -- Use the smaller scale to ensure it fits in both dimensions
    return math.min(scaleX, scaleY)
end

-- Draw the portrait with proper layering
-- Parameters:
--   x, y: Position to draw (center of portrait)
--   scale: Scale factor (default 1.0)
--   emotion: Optional emotion layer override ("angry", "worried", nil for auto-detect from engagement)
function ChasePortrait.draw(x, y, scale, emotion)
    scale = scale or 1.0
    
    if not portraitImages.base then
        -- Fallback: draw a simple circle if images aren't loaded
        love.graphics.setColor(0.9, 0.8, 0.7, 1)
        love.graphics.circle("fill", x, y, 40 * scale)
        return
    end
    
    -- Auto-determine emotion from engagement if not explicitly provided
    if emotion == nil and Engagement and Engagement.value ~= nil then
        local engagementValue = Engagement.value
        if engagementValue <= 30 then
            emotion = "angry"
        elseif engagementValue <= 50 then
            emotion = "worried"
        end
    end
    
    -- Reset color to white for proper image rendering
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Get image dimensions for centering
    local baseWidth = portraitImages.base:getWidth()
    local baseHeight = portraitImages.base:getHeight()
    local drawX = x - (baseWidth * scale) / 2
    local drawY = y - (baseHeight * scale) / 2
    
    -- 1. Draw base portrait (FullFace_Neutral_happy)
    love.graphics.draw(portraitImages.base, drawX, drawY, 0, scale, scale)
    
    -- 2. Draw emotion layer directly above base (if determined from engagement or explicitly set)
    if emotion == "angry" and portraitImages.angry then
        love.graphics.draw(portraitImages.angry, drawX, drawY, 0, scale, scale)
    elseif emotion == "worried" and portraitImages.worried then
        love.graphics.draw(portraitImages.worried, drawX, drawY, 0, scale, scale)
    end
    
    -- 3. Draw mouth layer (always on top, animated when talking)
    if animationState.isTalking then
        -- Animate mouth open/close rapidly
        local mouthCycle = math.floor(animationState.mouthOpenTimer / animationState.mouthOpenSpeed) % 2
        if mouthCycle == 0 and portraitImages.mouthOpen then
            love.graphics.draw(portraitImages.mouthOpen, drawX, drawY, 0, scale, scale)
        elseif portraitImages.mouthSmile then
            love.graphics.draw(portraitImages.mouthSmile, drawX, drawY, 0, scale, scale)
        end
    else
        -- Not talking: show smile
        if portraitImages.mouthSmile then
            love.graphics.draw(portraitImages.mouthSmile, drawX, drawY, 0, scale, scale)
        end
    end
end

return ChasePortrait

