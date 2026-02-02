-- src/screens/booting_screen.lua
-- Booting screen drawing

local BootingScreen = {}

function BootingScreen.draw()
    love.graphics.clear(0, 0, 0)  -- Black background
    
    -- Draw "Booting..." text centered
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(1, 1, 1, 1)  -- White text
    local text = "Booting..."
    local textWidth = Game.fonts.large:getWidth(text)
    local textHeight = Game.fonts.large:getHeight()
    local centerX = Constants.SCREEN_WIDTH / 2
    local centerY = Constants.SCREEN_HEIGHT / 2
    love.graphics.print(text, centerX - textWidth / 2, centerY - textHeight / 2)
end

return BootingScreen



