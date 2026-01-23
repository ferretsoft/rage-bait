-- src/core/screenshot.lua
-- Screenshot functionality for capturing game frames

local Screenshot = {}

-- Screenshot dimensions
local SCREENSHOT_WIDTH = 1080
local SCREENSHOT_HEIGHT = 1920

-- Take a screenshot at 1080x1920 resolution
function Screenshot.capture()
    -- Capture current framebuffer
    love.graphics.captureScreenshot(function(imageData)
        -- Get current window dimensions
        local windowWidth, windowHeight = love.graphics.getDimensions()
        
        local targetImageData
        
        -- If window is already 1080x1920, use directly
        if windowWidth == SCREENSHOT_WIDTH and windowHeight == SCREENSHOT_HEIGHT then
            targetImageData = imageData
        else
            -- Otherwise, scale to target resolution
            targetImageData = love.image.newImageData(SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT)
            
            -- Calculate scale to fit window into screenshot (maintaining aspect ratio)
            local scaleX = SCREENSHOT_WIDTH / windowWidth
            local scaleY = SCREENSHOT_HEIGHT / windowHeight
            local scale = math.min(scaleX, scaleY)
            
            -- Calculate scaled dimensions and centering
            local scaledWidth = math.floor(windowWidth * scale)
            local scaledHeight = math.floor(windowHeight * scale)
            local offsetX = math.floor((SCREENSHOT_WIDTH - scaledWidth) / 2)
            local offsetY = math.floor((SCREENSHOT_HEIGHT - scaledHeight) / 2)
            
            -- Fill background with black
            for y = 0, SCREENSHOT_HEIGHT - 1 do
                for x = 0, SCREENSHOT_WIDTH - 1 do
                    targetImageData:setPixel(x, y, 0, 0, 0, 255)
                end
            end
            
            -- Scale and copy pixels from source to target
            for y = 0, scaledHeight - 1 do
                for x = 0, scaledWidth - 1 do
                    local srcX = math.floor(x / scale)
                    local srcY = math.floor(y / scale)
                    
                    -- Clamp source coordinates
                    srcX = math.max(0, math.min(windowWidth - 1, srcX))
                    srcY = math.max(0, math.min(windowHeight - 1, srcY))
                    
                    local r, g, b, a = imageData:getPixel(srcX, srcY)
                    local targetX = offsetX + x
                    local targetY = offsetY + y
                    
                    if targetX >= 0 and targetX < SCREENSHOT_WIDTH and targetY >= 0 and targetY < SCREENSHOT_HEIGHT then
                        targetImageData:setPixel(targetX, targetY, r, g, b, a)
                    end
                end
            end
        end
        
        -- Generate filename with timestamp
        local timestamp = os.date("%Y%m%d_%H%M%S")
        local filename = string.format("screenshot_%s.png", timestamp)
        
        -- Encode image data to PNG format (returns FileData object)
        local fileData = targetImageData:encode("png")
        
        -- Save to LÖVE's save directory (same place as highscores.txt)
        -- The save directory is: ~/.local/share/love/RageBait/ on Linux
        local success = pcall(function()
            love.filesystem.write(filename, fileData:getString())
        end)
        
        local saveDir = love.filesystem.getSaveDirectory()
        if success then
            print(string.format("Screenshot saved: %s/%s (%dx%d)", saveDir, filename, SCREENSHOT_WIDTH, SCREENSHOT_HEIGHT))
        else
            print(string.format("Error saving screenshot. Save directory: %s", saveDir))
        end
    end)
end

return Screenshot

