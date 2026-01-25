-- src/screens/logo_screen.lua
-- Logo screen drawing with slide-in animation

local Constants = require("src.constants")

local LogoScreen = {}

function LogoScreen.draw()
    love.graphics.clear(0, 0, 0)  -- Black background
    
    if not Game.assets.logo then
        -- Fallback if logo didn't load
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("LOGO", Constants.SCREEN_WIDTH / 2 - 50, Constants.SCREEN_HEIGHT / 2)
        return
    end
    
    local logoWidth = Game.assets.logo:getWidth()
    local logoHeight = Game.assets.logo:getHeight()
    local centerX = Constants.SCREEN_WIDTH / 2
    local centerY = Constants.SCREEN_HEIGHT / 2
    
    -- Calculate scale to fit logo within screen (with some padding)
    local maxWidth = Constants.SCREEN_WIDTH * 0.8  -- 80% of screen width
    local maxHeight = Constants.SCREEN_HEIGHT * 0.8  -- 80% of screen height
    local scaleX = maxWidth / logoWidth
    local scaleY = maxHeight / logoHeight
    local scale = math.min(scaleX, scaleY)  -- Maintain aspect ratio
    
    -- Scaled dimensions for animation calculations
    local scaledWidth = logoWidth * scale
    local scaledHeight = logoHeight * scale
    
    -- Animation phases:
    -- 0-1s: Slide in from left (silently, no sound)
    -- 1-2.5s: Hold at center (1.5 seconds)
    -- 2.5-2.75s: Show blink version (0.25 seconds)
    -- 2.75-5.75s: Show normal version (3 seconds)
    -- 5.75s+: Transition to attract mode
    
    local t = Game.timers.logo
    local x, y = centerX, centerY
    
    -- Phase 1: Slide in (0-1 second) - silently, no sound
    if t < 1.0 then
        local progress = t / 1.0
        -- Ease out cubic for smooth deceleration
        progress = 1 - math.pow(1 - progress, 3)
        x = -scaledWidth + (centerX + scaledWidth) * progress
    end
    
    -- Determine which logo to show (blink or normal)
    local logoToShow = Game.assets.logo
    if Game.assets.logoBlink and t >= 2.5 and t < 2.75 then
        logoToShow = Game.assets.logoBlink
    end
    
    -- Enable alpha blending for compositing
    love.graphics.setBlendMode("alpha")
    
    -- Draw logo with transformations
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(logoToShow, -logoWidth / 2, -logoHeight / 2)
    love.graphics.pop()
    
    -- Reset blend mode
    love.graphics.setBlendMode("alpha")
end

return LogoScreen


