-- src/core/drawing_helpers.lua
-- Common drawing helper functions used throughout the game

local Constants = require("src.constants")
local World = require("src.core.world")
local ToxicSplat = require("src.core.toxic_splat")

local DrawingHelpers = {}

-- State for tracking fading grid lightening effects
local fadingEffects = {}
local previousEffects = {}  -- Track effects that existed last frame (full data)

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

-- Helper function to calculate distance
local function dist(x1, y1, x2, y2)
    return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

-- Helper function to generate a unique key for an effect
local function getEffectKey(effect)
    return string.format("%s_%.1f_%.1f_%.1f", effect.type or "unknown", effect.x or 0, effect.y or 0, effect.radius or 0)
end

-- Update fading effects (called each frame)
function DrawingHelpers.updateFadingEffects(dt)
    -- Update existing fading effects
    for i = #fadingEffects, 1, -1 do
        local fading = fadingEffects[i]
        fading.timer = fading.timer - dt
        if fading.timer <= 0 then
            table.remove(fadingEffects, i)
        end
    end
end

-- Draw faint grid on playfield with lighter green
function DrawingHelpers.drawPlayfieldGrid()
    -- Update fading effects (need dt, but we'll approximate with a small value)
    -- Actually, we need to call this from update loop, but for now we'll handle it here
    -- by checking if we have a dt available
    local dt = love.timer and love.timer.getDelta() or (1/60)  -- Default to 60fps if not available
    DrawingHelpers.updateFadingEffects(dt)
    
    local gridSpacing = 40  -- Grid spacing in pixels
    local startX = Constants.OFFSET_X
    local startY = Constants.OFFSET_Y
    local endX = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH
    local endY = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT
    
    -- Collect spider feet positions if turret exists
    -- Convert from world coordinates to screen coordinates
    local feetPositions = {}
    if Game.turret and Game.turret.legs then
        for _, leg in ipairs(Game.turret.legs) do
            if leg.footX and leg.footY then
                -- Convert from world coordinates to screen coordinates
                table.insert(feetPositions, {
                    x = leg.footX + Constants.OFFSET_X,
                    y = leg.footY + Constants.OFFSET_Y,
                    type = "foot"
                })
            end
        end
    end
    
    -- Collect area effect positions (explosion zones, hazards, effects)
    local areaEffects = {}
    
    -- Collect bomb reticule position if turret is charging
    if Game.turret and Game.turret.isCharging then
        local currentDist = Game.turret.chargeTimer * 500
        local targetX = Game.turret.visualX + math.cos(Game.turret.visualAngle) * currentDist
        local targetY = Game.turret.visualY + math.sin(Game.turret.visualAngle) * currentDist
        
        -- Clamp reticule to playfield bounds (same as in turret draw)
        local margin = 20
        targetX = math.max(margin, math.min(Constants.PLAYFIELD_WIDTH - margin, targetX))
        targetY = math.max(margin, math.min(Constants.PLAYFIELD_HEIGHT - margin, targetY))
        
        local reticuleEffect = {
            x = targetX + Constants.OFFSET_X,
            y = targetY + Constants.OFFSET_Y,
            radius = 30,  -- Reticule radius for grid lightening
            type = "reticule",
            color = Game.turret.chargeColor or "blue"
        }
        table.insert(areaEffects, reticuleEffect)
        -- Note: reticules don't need fade tracking since they disappear instantly when charging stops
    end
    local currentEffects = {}  -- Track current effects for fade detection
    
    -- Explosion zones
    if Game.explosionZones then
        for _, zone in ipairs(Game.explosionZones) do
            if zone.x and zone.y and zone.radius and zone.timer and zone.timer > 0 then
                local effect = {
                    x = zone.x + Constants.OFFSET_X,
                    y = zone.y + Constants.OFFSET_Y,
                    radius = zone.radius,
                    type = "explosion_zone",
                    color = zone.color or "blue"
                }
                table.insert(areaEffects, effect)
                currentEffects[getEffectKey(effect)] = effect
            end
        end
    end
    
    -- Toxic hazards
    if Game.hazards then
        for _, hazard in ipairs(Game.hazards) do
            if hazard.x and hazard.y and hazard.radius and hazard.timer and hazard.timer > 0 then
                local effect = {
                    x = hazard.x + Constants.OFFSET_X,
                    y = hazard.y + Constants.OFFSET_Y,
                    radius = hazard.radius,
                    type = "toxic"
                }
                table.insert(areaEffects, effect)
                currentEffects[getEffectKey(effect)] = effect
            end
        end
    end
    
    -- Explosion effects (visual explosions)
    if Game.effects then
        for _, effect in ipairs(Game.effects) do
            if effect.type == "explosion" and effect.x and effect.y then
                local effectRadius = effect.maxRadius or effect.radius or 80
                local gridEffect = {
                    x = effect.x + Constants.OFFSET_X,
                    y = effect.y + Constants.OFFSET_Y,
                    radius = effectRadius,
                    type = "explosion",
                    color = effect.color or "blue"
                }
                table.insert(areaEffects, gridEffect)
                currentEffects[getEffectKey(gridEffect)] = gridEffect
            elseif effect.type == "orange_splat" and effect.x and effect.y then
                -- Orange explosion from insane units
                local gridEffect = {
                    x = effect.x + Constants.OFFSET_X,
                    y = effect.y + Constants.OFFSET_Y,
                    radius = Constants.INSANE_EXPLOSION_RADIUS or 120,
                    type = "orange_explosion"
                }
                table.insert(areaEffects, gridEffect)
                currentEffects[getEffectKey(gridEffect)] = gridEffect
            end
        end
    end
    
    -- Units
    if Game.units then
        for _, unit in ipairs(Game.units) do
            if not unit.isDead and unit.body then
                local ux, uy = unit.body:getPosition()
                local unitRadius = Constants.UNIT_RADIUS or 9.375
                
                -- Calculate actual unit color (matching unit drawing logic)
                local r, g, b = 1, 1, 1
                if unit.state == "neutral" then
                    r, g, b = unpack(Constants.COLORS.GREY)
                elseif unit.alignment == "red" then
                    r, g, b = unpack(Constants.COLORS.RED)
                elseif unit.alignment == "blue" then
                    r, g, b = unpack(Constants.COLORS.BLUE)
                end
                
                -- Apply health-based dimming (same as unit drawing)
                local healthPct = (unit.hp or Constants.UNIT_HP) / Constants.UNIT_HP
                r = r * healthPct
                g = g * healthPct
                b = b * healthPct
                
                -- Store actual RGB color for grid lightening
                local unitEffect = {
                    x = ux + Constants.OFFSET_X,
                    y = uy + Constants.OFFSET_Y,
                    radius = unitRadius * 4,  -- Larger radius for more visible grid lightening
                    type = "unit",
                    colorR = r,
                    colorG = g,
                    colorB = b,
                    state = unit.state or "neutral"
                }
                table.insert(areaEffects, unitEffect)
                currentEffects[getEffectKey(unitEffect)] = unitEffect
            end
        end
    end
    
    -- Projectiles (including pucks and bombs)
    if Game.projectiles then
        for _, projectile in ipairs(Game.projectiles) do
            if not projectile.isDead and projectile.body then
                local px, py = projectile.body:getPosition()
                local radius = projectile.shape and projectile.shape:getRadius() or 15
                local weaponType = projectile.weaponType or "puck"
                
                -- Use different lightening radius based on weapon type
                -- Pucks are smaller, so give them a larger relative glow
                local lightenRadius
                if weaponType == "puck" then
                    lightenRadius = radius * 4  -- Larger glow for small pucks
                else
                    lightenRadius = radius * 2  -- Standard glow for bombs
                end
                
                -- Add current projectile position
                local projEffect = {
                    x = px + Constants.OFFSET_X,
                    y = py + Constants.OFFSET_Y,
                    radius = lightenRadius,
                    type = "projectile",
                    color = projectile.color or "blue",
                    weaponType = weaponType
                }
                table.insert(areaEffects, projEffect)
                -- Note: projectiles move too fast to track for fading, so we skip them
                
                -- Add trail positions (sample every few points to avoid too many)
                if projectile.trail then
                    local trailSampleRate = 3  -- Sample every 3rd point to reduce computation
                    for i = 1, #projectile.trail, trailSampleRate do
                        local trailPoint = projectile.trail[i]
                        if trailPoint and trailPoint.alpha and trailPoint.alpha > 0.1 then
                            -- Use smaller radius for trail points, fade with alpha
                            local trailRadius = (weaponType == "puck" and radius * 2 or radius * 1.5)
                            table.insert(areaEffects, {
                                x = trailPoint.x + Constants.OFFSET_X,
                                y = trailPoint.y + Constants.OFFSET_Y,
                                radius = trailRadius,
                                type = "projectile_trail",
                                color = projectile.color or "blue",
                                weaponType = weaponType,
                                alpha = trailPoint.alpha  -- Use trail alpha for fading
                            })
                        end
                    end
                end
            end
        end
    end
    
    -- Base grid color
    love.graphics.setColor(0, 0.25, 0, 0.3)  -- Lighter green, faint
    love.graphics.setLineWidth(1)
    
    -- Draw vertical lines
    local x = startX
    while x <= endX do
        love.graphics.line(x, startY, x, endY)
        x = x + gridSpacing
    end
    
    -- Draw horizontal lines
    local y = startY
    while y <= endY do
        love.graphics.line(startX, y, endX, y)
        y = y + gridSpacing
    end
    
    -- Check for effects that disappeared and add them to fading list
    for key, prevEffect in pairs(previousEffects) do
        if not currentEffects[key] then
            -- This effect disappeared, add it to fading list
            table.insert(fadingEffects, {
                effect = prevEffect,
                timer = 0.25  -- 0.25 seconds fade time
            })
        end
    end
    
    -- Add fading effects to area effects with reduced alpha
    for _, fading in ipairs(fadingEffects) do
        local fadeAlpha = fading.timer / 0.25  -- Fade from 1.0 to 0.0 over 0.25 seconds
        if fadeAlpha > 0 then
            local fadedEffect = {}
            for k, v in pairs(fading.effect) do
                fadedEffect[k] = v
            end
            fadedEffect.fadeAlpha = fadeAlpha
            fadedEffect.isFading = true
            table.insert(areaEffects, fadedEffect)
        end
    end
    
    -- Update previous effects for next frame (deep copy)
    previousEffects = {}
    for key, effect in pairs(currentEffects) do
        local copy = {}
        for k, v in pairs(effect) do
            copy[k] = v
        end
        previousEffects[key] = copy
    end
    
    -- Lighten grid intersections near spider feet and area effects
    local allLightSources = {}
    for _, foot in ipairs(feetPositions) do
        table.insert(allLightSources, {pos = foot, lightenRadius = 100, lightColor = {0, 0.7, 0, 0.8}})
    end
    
    for _, effect in ipairs(areaEffects) do
        local lightenRadius = effect.radius * 1.5  -- Extend beyond effect radius
        -- For trails, use smaller radius multiplier
        if effect.type == "projectile_trail" then
            lightenRadius = effect.radius * 1.2  -- Smaller radius for trail points
        elseif effect.type == "unit" then
            lightenRadius = effect.radius * 2.0  -- Larger radius for units to light up more grid
        end
        
        local lightColor
        local baseAlpha = 1.0
        if effect.isFading and effect.fadeAlpha then
            baseAlpha = effect.fadeAlpha  -- Apply fade multiplier
        end
        
        if effect.type == "toxic" then
            lightColor = {0.2, 0.8, 0.2, 0.7 * baseAlpha}  -- Green for toxic
        elseif effect.type == "explosion_zone" or effect.type == "explosion" then
            if effect.color == "red" then
                lightColor = {0.8, 0.3, 0.2, 0.7 * baseAlpha}  -- Reddish for red explosions
            else
                lightColor = {0.2, 0.4, 0.8, 0.7 * baseAlpha}  -- Blue for blue explosions
            end
        elseif effect.type == "orange_explosion" then
            lightColor = {0.9, 0.5, 0.1, 0.7 * baseAlpha}  -- Orange for insane explosions
        elseif effect.type == "unit" then
            -- Units - use their actual color (from unit drawing, including health dimming)
            local r = effect.colorR or 0.7
            local g = effect.colorG or 0.7
            local b = effect.colorB or 0.7
            
            -- Boost red intensity for red units to make them stand out more
            if r > g and r > b then
                -- This is a red unit - boost red intensity
                r = math.min(1.0, r * 1.3)  -- Increase red by 30%, cap at 1.0
                -- Slightly reduce other channels to make red more pure
                g = g * 0.8
                b = b * 0.8
            end
            
            -- Boost intensity for grid visibility (but keep the unit's color)
            local intensity = 0.7
            if effect.state == "enraged" then
                intensity = 0.9  -- Brighter for enraged units
            end
            
            lightColor = {r, g, b, intensity * baseAlpha}
        elseif effect.type == "reticule" then
            -- Bomb reticule - pulsing effect
            local pulse = math.sin(love.timer.getTime() * 20) * 0.2 + 0.8  -- Pulse between 0.6 and 1.0
            if effect.color == "red" then
                lightColor = {1.0, 0.3, 0.3, 0.7 * pulse * baseAlpha}  -- Pulsing red for red reticule
            else
                lightColor = {0.3, 0.4, 1.0, 0.7 * pulse * baseAlpha}  -- Pulsing blue for blue reticule
            end
        elseif effect.type == "projectile" then
            -- Different colors/intensity for pucks vs bombs
            if effect.weaponType == "puck" then
                if effect.color == "red" then
                    lightColor = {0.9, 0.5, 0.4, 0.7 * baseAlpha}  -- Bright red for red pucks
                else
                    lightColor = {0.4, 0.6, 1.0, 0.7 * baseAlpha}  -- Bright blue for blue pucks
                end
            else
                -- Bombs
                if effect.color == "red" then
                    lightColor = {0.9, 0.4, 0.3, 0.6 * baseAlpha}  -- Bright red for red bombs
                else
                    lightColor = {0.3, 0.5, 0.9, 0.6 * baseAlpha}  -- Bright blue for blue bombs
                end
            end
        elseif effect.type == "projectile_trail" then
            -- Trail points - use alpha from trail for fading
            local trailAlpha = effect.alpha or 0.5
            if effect.weaponType == "puck" then
                if effect.color == "red" then
                    lightColor = {0.9, 0.5, 0.4, 0.5 * trailAlpha}  -- Faded red for red puck trails
                else
                    lightColor = {0.4, 0.6, 1.0, 0.5 * trailAlpha}  -- Faded blue for blue puck trails
                end
            else
                -- Bomb trails
                if effect.color == "red" then
                    lightColor = {0.9, 0.4, 0.3, 0.4 * trailAlpha}  -- Faded red for red bomb trails
                else
                    lightColor = {0.3, 0.5, 0.9, 0.4 * trailAlpha}  -- Faded blue for blue bomb trails
                end
            end
        else
            lightColor = {0, 0.7, 0, 0.8}  -- Default green
        end
        table.insert(allLightSources, {pos = effect, lightenRadius = lightenRadius, lightColor = lightColor})
    end
    
    if #allLightSources > 0 then
        local baseColor = {0, 0.25, 0, 0.3}
        
        -- Draw lighter crosses at intersections near light sources
        x = startX
        while x <= endX do
            y = startY
            while y <= endY do
                -- Check distance to nearest light source and find the brightest one
                local bestIntensity = 0
                local bestColor = baseColor
                
                for _, lightSource in ipairs(allLightSources) do
                    local d = dist(x, y, lightSource.pos.x, lightSource.pos.y)
                    if d < lightSource.lightenRadius then
                        local intensity = 1 - (d / lightSource.lightenRadius)  -- 1.0 at center, 0.0 at edge
                        if intensity > bestIntensity then
                            bestIntensity = intensity
                            -- Blend base color with light color based on intensity
                            local r = baseColor[1] + (lightSource.lightColor[1] - baseColor[1]) * intensity
                            local g = baseColor[2] + (lightSource.lightColor[2] - baseColor[2]) * intensity
                            local b = baseColor[3] + (lightSource.lightColor[3] - baseColor[3]) * intensity
                            local a = baseColor[4] + (lightSource.lightColor[4] - baseColor[4]) * intensity
                            bestColor = {r, g, b, a}
                        end
                    end
                end
                
                -- If close to any light source, draw lighter cross
                if bestIntensity > 0 then
                    love.graphics.setColor(bestColor[1], bestColor[2], bestColor[3], bestColor[4])
                    love.graphics.setLineWidth(1.5)
                    -- Draw cross at intersection
                    local crossSize = 8
                    love.graphics.line(x - crossSize, y, x + crossSize, y)
                    love.graphics.line(x, y - crossSize, x, y + crossSize)
                end
                
                y = y + gridSpacing
            end
            x = x + gridSpacing
        end
    end
end

-- Draw teal wallpaper covering entire screen (like Windows desktop wallpaper)
function DrawingHelpers.drawTealWallpaper()
    -- Draw teal wallpaper covering entire screen
    love.graphics.setColor(0, 0.5, 0.5, 1)  -- Teal color
    love.graphics.rectangle("fill", 0, 0, Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    
    -- Draw dark green rectangle over playfield area
    love.graphics.setColor(0, 0.05, 0, 1)  -- Darker green
    love.graphics.rectangle("fill", Constants.OFFSET_X, Constants.OFFSET_Y, 
        Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT)
    
    -- Note: Grid is drawn separately inside shake transform
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


