-- Module to load and cache unit sprites with fallback drawing
local EmojiSprites = {}

local sprites = {
    neutral = nil,
    converted = nil,
    angry = nil
}

local spritesLoaded = {
    neutral = false,
    converted = false,
    angry = false
}

function EmojiSprites.init()
    -- Try to load sprites from assets folder
    local success, img = pcall(love.graphics.newImage, "assets/unit_neutral.png")
    if success and img then
        sprites.neutral = img
        spritesLoaded.neutral = true
    else
        sprites.neutral = nil
        spritesLoaded.neutral = false
    end
    
    local success2, img2 = pcall(love.graphics.newImage, "assets/unit_converted.png")
    if success2 and img2 then
        sprites.converted = img2
        spritesLoaded.converted = true
    else
        sprites.converted = nil
        spritesLoaded.converted = false
    end
    
    local success3, img3 = pcall(love.graphics.newImage, "assets/unit_angry.png")
    if success3 and img3 then
        sprites.angry = img3
        spritesLoaded.angry = true
    else
        sprites.angry = nil
        spritesLoaded.angry = false
    end
end

function EmojiSprites.getNeutral()
    return sprites.neutral
end

function EmojiSprites.getConverted()
    return sprites.converted
end

function EmojiSprites.getAngry()
    return sprites.angry
end

function EmojiSprites.isNeutralLoaded()
    return spritesLoaded.neutral
end

function EmojiSprites.isConvertedLoaded()
    return spritesLoaded.converted
end

function EmojiSprites.isAngryLoaded()
    return spritesLoaded.angry
end

return EmojiSprites

