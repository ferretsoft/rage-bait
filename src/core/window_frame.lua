-- src/core/window_frame.lua
-- Shared Windows 95 style window frame drawing utility

local WindowFrame = {}

-- Draw Windows 95 style window frame with title bar and controls
function WindowFrame.draw(x, y, width, height, title)
    local borderWidth = 3
    local titleBarHeight = 20
    
    -- Outer border (thick grey)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Top and left edges (highlight - light gray/white)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.setLineWidth(2)
    -- Top edge
    love.graphics.line(x + borderWidth, y + borderWidth, x + width - borderWidth, y + borderWidth)
    -- Left edge
    love.graphics.line(x + borderWidth, y + borderWidth, x + borderWidth, y + height - borderWidth)
    
    -- Inner highlight (lighter)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + borderWidth + 1, y + borderWidth + 1, x + width - borderWidth - 1, y + borderWidth + 1)
    love.graphics.line(x + borderWidth + 1, y + borderWidth + 1, x + borderWidth + 1, y + height - borderWidth - 1)
    
    -- Bottom and right edges (shadow - dark gray/black)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.setLineWidth(2)
    -- Bottom edge
    love.graphics.line(x + borderWidth, y + height - borderWidth, x + width - borderWidth, y + height - borderWidth)
    -- Right edge
    love.graphics.line(x + width - borderWidth, y + borderWidth, x + width - borderWidth, y + height - borderWidth)
    
    -- Inner shadow (darker)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + borderWidth + 1, y + height - borderWidth - 1, x + width - borderWidth - 1, y + height - borderWidth - 1)
    love.graphics.line(x + width - borderWidth - 1, y + borderWidth + 1, x + width - borderWidth - 1, y + height - borderWidth - 1)
    
    -- Title bar background (Windows 95 blue gradient effect)
    local titleBarY = y + borderWidth
    love.graphics.setColor(0.2, 0.4, 0.6, 1)  -- Windows 95 blue
    love.graphics.rectangle("fill", x + borderWidth, titleBarY, width - (borderWidth * 2), titleBarHeight)
    
    -- Title bar highlight line
    love.graphics.setColor(0.4, 0.6, 0.8, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + borderWidth, titleBarY, x + width - borderWidth, titleBarY)
    
    -- Title text
    if title then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(Game.fonts.small)
        local titleX = x + borderWidth + 5
        local titleTextY = titleBarY + (titleBarHeight - Game.fonts.small:getHeight()) / 2
        love.graphics.print(title, titleX, titleTextY)
    end
    
    -- Window controls (minimize, maximize, close buttons) on the right
    -- Order: Minimize (left), Maximize (middle), Close (right)
    local buttonSize = 16
    local buttonSpacing = 2
    local controlsX = x + width - borderWidth - (buttonSize * 3) - (buttonSpacing * 2) - 3
    local controlsY = titleBarY + 2
    
    -- Minimize button (dash) - leftmost
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", controlsX, controlsY, buttonSize, buttonSize)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(controlsX + 4, controlsY + buttonSize / 2, controlsX + buttonSize - 4, controlsY + buttonSize / 2)
    
    -- Maximize button (square) - middle
    controlsX = controlsX + buttonSize + buttonSpacing
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", controlsX, controlsY, buttonSize, buttonSize)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", controlsX + 3, controlsY + 3, buttonSize - 6, buttonSize - 6)
    
    -- Close button (X) - rightmost
    controlsX = controlsX + buttonSize + buttonSpacing
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", controlsX, controlsY, buttonSize, buttonSize)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(controlsX + 4, controlsY + 4, controlsX + buttonSize - 4, controlsY + buttonSize - 4)
    love.graphics.line(controlsX + buttonSize - 4, controlsY + 4, controlsX + 4, controlsY + buttonSize - 4)
end

return WindowFrame












