-- src/core/drawing_helpers.lua
-- Common drawing helper functions used throughout the game

local Constants = require("src.constants")
local World = require("src.core.world")

local DrawingHelpers = {}

-- Draw frozen game state (used in game over, life lost, ready screens)
function DrawingHelpers.drawFrozenGameState()
    World.draw(function()
        for _, h in ipairs(Game.hazards) do
            local r,g,b = unpack(Constants.COLORS.TOXIC); local a = (h.timer/Constants.TOXIC_DURATION)*0.4
            love.graphics.setColor(r,g,b,a); love.graphics.circle("fill", h.x, h.y, h.radius)
            love.graphics.setColor(r,g,b,a+0.2); love.graphics.setLineWidth(2); love.graphics.circle("line", h.x, h.y, h.radius)
        end
        
        for _, u in ipairs(Game.units) do u:draw() end
        for _, p in ipairs(Game.projectiles) do p:draw() end
        for _, pup in ipairs(Game.powerups) do pup:draw() end
        
        for _, e in ipairs(Game.effects) do
            if e.type == "explosion" then
                love.graphics.setLineWidth(3)
                if e.color == "gold" then love.graphics.setColor(1, 0.8, 0.2, e.alpha)
                elseif e.color == "red" then love.graphics.setColor(1, 0.2, 0.2, e.alpha)
                else love.graphics.setColor(0.2, 0.2, 1, e.alpha) end
                love.graphics.circle("line", e.x, e.y, e.radius, 64); love.graphics.setColor(1, 1, 1, e.alpha * 0.2); love.graphics.circle("fill", e.x, e.y, e.radius, 64)
            end
        end
        
        if Game.turret then Game.turret:draw() end
    end)
end

-- Draw black overlay with fade
function DrawingHelpers.drawBlackOverlay(alpha)
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
end

-- Draw window content background (transparent black)
function DrawingHelpers.drawWindowContentBackground(x, y, width, height, titleBarHeight, borderWidth)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x + borderWidth, y + borderWidth + titleBarHeight, 
        width - (borderWidth * 2), height - (borderWidth * 2) - titleBarHeight)
end

-- Draw text with outline
function DrawingHelpers.drawTextWithOutline(text, x, y, colorR, colorG, colorB, colorA, outlineWidth, outlineAlpha)
    outlineWidth = outlineWidth or 4
    outlineAlpha = outlineAlpha or 0.8
    
    -- Draw outline
    love.graphics.setLineWidth(outlineWidth)
    love.graphics.setColor(0, 0, 0, colorA * outlineAlpha)
    for dx = -2, 2 do
        for dy = -2, 2 do
            if dx ~= 0 or dy ~= 0 then
                love.graphics.print(text, x + dx, y + dy)
            end
        end
    end
    
    -- Draw main text
    love.graphics.setColor(colorR, colorG, colorB, colorA)
    love.graphics.print(text, x, y)
end

-- Calculate pulsing value (0 to 1)
function DrawingHelpers.calculatePulse(speed, offset)
    offset = offset or 0
    return (math.sin((love.timer.getTime() + offset) * speed) + 1) / 2
end

-- Get screen center coordinates
function DrawingHelpers.getScreenCenter()
    return Constants.SCREEN_WIDTH / 2, Constants.SCREEN_HEIGHT / 2
end

-- Calculate plexi scale factors
function DrawingHelpers.calculatePlexiScale()
    if not Game.plexi then return 1, 1 end
    local plexiScaleX = (Constants.SCREEN_WIDTH / Game.plexi:getWidth()) * Constants.UI.PLEXI_SCALE_FACTOR
    local plexiScaleY = (Constants.SCREEN_HEIGHT / Game.plexi:getHeight()) * Constants.UI.PLEXI_SCALE_FACTOR
    return plexiScaleX, plexiScaleY
end

return DrawingHelpers


