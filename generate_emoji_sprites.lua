-- Script to generate emoji sprites from font
-- Run with: love generate_emoji_sprites.lua

local emojis = {
    neutral = "😐",
    angry = "😠"
}

function love.load()
    local fontSize = 30  -- Make them large for good quality
    local font = love.graphics.newFont("assets/NotoColorEmoji.ttf", fontSize)
    
    if not font then
        print("Failed to load font!")
        love.event.quit()
        return
    end
    
    love.graphics.setFont(font)
    
    -- Create canvas for each emoji
    for name, emoji in pairs(emojis) do
        local width = font:getWidth(emoji)
        local height = font:getHeight()
        
        -- Add padding
        local padding = 4
        local canvasWidth = width + padding * 2
        local canvasHeight = height + padding * 2
        
        local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)  -- Transparent background
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(emoji, padding, padding)
        love.graphics.setCanvas()
        
        -- Export to image
        local imageData = canvas:newImageData()
        local success = love.filesystem.write("assets/emoji_" .. name .. ".png", imageData:encode("png"))
        
        if success then
            print("Generated: assets/emoji_" .. name .. ".png (" .. canvasWidth .. "x" .. canvasHeight .. ")")
        else
            print("Failed to save: assets/emoji_" .. name .. ".png")
        end
    end
    
    print("Done generating emoji sprites!")
    love.event.quit()
end

function love.draw()
    -- Nothing to draw
end
















