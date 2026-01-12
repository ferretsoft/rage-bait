-- Standalone script to generate emoji sprites
-- Run with: love . --script gen_emojis.lua

local emojis = {
    neutral = "😐",
    angry = "😠"
}

function love.load()
    -- Don't load main.lua, just do our work
    local fontSize = 40
    local fontPaths = {
        "assets/NotoColorEmoji.ttf",
        "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
    }
    
    local font = nil
    local fontPath = nil
    for _, path in ipairs(fontPaths) do
        local success, f = pcall(love.graphics.newFont, path, fontSize)
        if success and f then
            font = f
            fontPath = path
            break
        end
    end
    
    if not font then
        print("ERROR: Could not load emoji font from any path")
        love.event.quit()
        return
    end
    
    print("Font loaded successfully from: " .. fontPath)
    love.graphics.setFont(font)
    
    -- Create sprites for each emoji
    for name, emoji in pairs(emojis) do
        local width = font:getWidth(emoji)
        local height = font:getHeight()
        
        print(string.format("Emoji %s: %dx%d", name, width, height))
        
        if width > 0 and height > 0 then
            local padding = 8
            local canvasWidth = math.ceil(width) + padding * 2
            local canvasHeight = math.ceil(height) + padding * 2
            
            local canvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
            love.graphics.setCanvas(canvas)
            love.graphics.clear(0, 0, 0, 0)  -- Transparent
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(emoji, padding, padding)
            love.graphics.setCanvas()
            
            -- Export
            local imageData = canvas:newImageData()
            local success, err = love.filesystem.write("assets/emoji_" .. name .. ".png", imageData:encode("png"))
            
            if success then
                print(string.format("SUCCESS: Generated assets/emoji_%s.png (%dx%d)", name, canvasWidth, canvasHeight))
            else
                print(string.format("ERROR: Failed to save: %s", err))
            end
        else
            print(string.format("WARNING: Emoji %s has zero width/height", name))
        end
    end
    
    print("Done!")
    love.event.quit()
end

function love.draw()
end

