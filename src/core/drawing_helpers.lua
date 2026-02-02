-- src/core/drawing_helpers.lua
-- Common drawing helper functions used throughout the game

local Constants = require("src.constants")
local World = require("src.core.world")
local ToxicSplat = require("src.core.toxic_splat")

local DrawingHelpers = {}

-- Draw frozen game state (used in game over, life lost, ready screens)
function DrawingHelpers.drawFrozenGameState()
    World.draw(function()
        for _, h in ipairs(Game.hazards) do
            if h.splat then
                -- Use animated splat
                local a = (h.timer / (h.radius == Constants.INSANE_TOXIC_RADIUS and Constants.INSANE_TOXIC_DURATION or Constants.TOXIC_DURATION)) * 0.4
                ToxicSplat.draw(h.splat, a)
            else
                -- Fallback to simple circle if splat not initialized
                local r,g,b = unpack(Constants.COLORS.TOXIC); local a = (h.timer/Constants.TOXIC_DURATION)*0.4
                love.graphics.setColor(r,g,b,a); love.graphics.circle("fill", h.x, h.y, h.radius)
                love.graphics.setColor(r,g,b,a+0.2); love.graphics.setLineWidth(2); love.graphics.circle("line", h.x, h.y, h.radius)
            end
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
            elseif e.type == "orange_splat" then
                -- Draw orange explosion splat with fiery orange colors
                if e.splat then
                    love.graphics.push()
                    love.graphics.translate(e.splat.x, e.splat.y)
                    love.graphics.scale(e.splat.currentScale)
                    
                    -- PASS 1: Base Orange Layer
                    love.graphics.setBlendMode("alpha")
                    love.graphics.setColor(0.8, 0.3, 0.1, e.alpha)
                    
                    for _, shape in ipairs(e.splat.shapes) do
                        love.graphics.circle("fill", shape.x, shape.y, shape.r)
                    end
                    
                    -- PASS 2: Additive Highlights (Fiery Glow)
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(0.6, 0.4, 0.1, 0.6 * e.alpha)  -- Fiery orange glow
                    
                    -- Only highlight blobs/lumps, streaks are too thin to notice
                    for _, shape in ipairs(e.splat.shapes) do
                        if shape.type == "core" or shape.type == "lump" or (shape.type == "blob" and shape.r > 1.2) then
                            local offX = -0.4 * shape.r * 0.3
                            local offY = -0.4 * shape.r * 0.3
                            -- Scale highlight down slightly
                            love.graphics.circle("fill", shape.x + offX, shape.y + offY, shape.r * 0.7)
                        end
                    end
                    
                    love.graphics.setBlendMode("alpha")
                    love.graphics.pop()
                end
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

-- Draw teal wallpaper covering entire screen (like Windows desktop wallpaper)
function DrawingHelpers.drawTealWallpaper()
    -- Draw teal wallpaper covering entire screen
    love.graphics.setColor(0, 0.5, 0.5, 1)  -- Teal color
    love.graphics.rectangle("fill", 0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    
    -- Draw black rectangle over playfield area to keep it black
    love.graphics.setColor(0, 0, 0, 1)  -- Black
    love.graphics.rectangle("fill", Constants.OFFSET_X, Constants.OFFSET_Y, 
        Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT)
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


