-- src/core/drawing_helpers.lua
-- Common drawing helper functions used throughout the game

local Constants = require("src.constants")
local World = require("src.core.world")
local ToxicSplat = require("src.core.toxic_splat")

local DrawingHelpers = {}

-- Set to false to disable playfield grid entirely (improves frame rate during gameplay)
local ENABLE_PLAYFIELD_GRID = true

function DrawingHelpers.isPlayfieldGridEnabled()
    return ENABLE_PLAYFIELD_GRID
end

-- State for tracking fading grid lightening effects
local fadingEffects = {}
local previousEffects = {}  -- Track effects that existed last frame (zones, hazards, effects, units)
-- Reused each frame to avoid allocating in drawPlayfieldGrid (reduces GC / framedrops)
local _areaEffects = {}
local _feetPositions = {}

-- Draw frozen game state (used in game over, life lost, win, ready screens) - playfield as-is until reset
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
        
        -- Explosion zones (same as drawGame - only draw if timer > 0 so expired zones are never visible)
        if #Game.explosionZones > 0 then
            love.graphics.stencil(function()
                love.graphics.rectangle("fill", -50, -50, Constants.PLAYFIELD_WIDTH + 100, Constants.PLAYFIELD_HEIGHT + 100)
            end, "replace", 0)
            for _, z in ipairs(Game.explosionZones) do
                if z and type(z.timer) == "number" and z.timer > 0 then
                    love.graphics.setStencilTest("equal", 0)
                    if z.color == "red" then love.graphics.setColor(1, 0, 0, 0.3) else love.graphics.setColor(0, 0, 1, 0.3) end
                    love.graphics.circle("fill", z.x, z.y, z.radius, 64)
                    love.graphics.setLineWidth(3); love.graphics.setColor(1, 1, 1, 0.5); love.graphics.circle("line", z.x, z.y, z.radius, 64)
                    love.graphics.setStencilTest(); love.graphics.stencil(function() love.graphics.circle("fill", z.x, z.y, z.radius, 64) end, "replace", 1)
                end
            end
            love.graphics.setStencilTest()
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

-- ========== Grid system (efficient rewrite) ==========
local GRID_SPACING = 40
local GRID_CROSS_SIZE = 8
local GRID_FADE_DURATION = 0.25
local GRID_MAX_LIGHTS = 128
local GRID_MAX_FADING = 64  -- cap fading list so stuck/missing removal can't grow unbounded

local _lightX, _lightY, _lightR, _lightG, _lightB, _lightA, _lightRadius
local _lightCount = 0

local function addLight(x, y, radius, r, g, b, a)
    if _lightCount >= GRID_MAX_LIGHTS then return end
    _lightCount = _lightCount + 1
    _lightX[_lightCount] = x
    _lightY[_lightCount] = y
    _lightRadius[_lightCount] = radius
    _lightR[_lightCount] = r
    _lightG[_lightCount] = g
    _lightB[_lightCount] = b
    _lightA[_lightCount] = a
end

-- Generate unique key for an effect (integer position for stability). No table allocation.
local function getEffectKeyByFields(typ, x, y, radius, color)
    local ix = math.floor((x or 0) + 0.5)
    local iy = math.floor((y or 0) + 0.5)
    local ir = math.floor((radius or 0) + 0.5)
    if typ == "explosion" or typ == "orange_explosion" then
        return string.format("%s_%d_%d", typ, ix, iy)
    end
    if typ == "explosion_zone" then
        return string.format("%s_%d_%d_%d_%s", typ, ix, iy, ir, color or "blue")
    end
    return string.format("%s_%d_%d_%d", typ, ix, iy, ir)
end

function DrawingHelpers.updateFadingEffects(dt)
    for i = #fadingEffects, 1, -1 do
        if dt > 0 then
            fadingEffects[i].timer = fadingEffects[i].timer - dt
        end
        if fadingEffects[i].timer <= 0 then
            fadingEffects[i] = fadingEffects[#fadingEffects]
            fadingEffects[#fadingEffects] = nil
        end
    end
end

-- Build current frame's effects; reuse tables from previousEffects when key exists (update in place).
-- Returns new map key -> effect. Only allocates for new keys; persisting effects reuse and update in place.
local function buildCurrentEffects(prev)
    local current = {}
    local ox, oy = Constants.OFFSET_X, Constants.OFFSET_Y

    local function put(key, x, y, radius, t, extra)
        local e = prev[key]
        if e then
            e.x, e.y, e.radius, e.type = x, y, radius, t
            for k, v in pairs(extra or {}) do e[k] = v end
        else
            e = { x = x, y = y, radius = radius, type = t }
            if extra then for k, v in pairs(extra) do e[k] = v end end
        end
        current[key] = e
    end

    if Game.explosionZones then
        for _, z in ipairs(Game.explosionZones) do
            if z.x and z.y and z.radius and z.timer and z.timer > 0 then
                local x, y, r, c = z.x + ox, z.y + oy, z.radius, z.color or "blue"
                put(getEffectKeyByFields("explosion_zone", x, y, r, c), x, y, r, "explosion_zone", { color = c })
            end
        end
    end
    if Game.hazards then
        for _, h in ipairs(Game.hazards) do
            if h.x and h.y and h.radius and h.timer and h.timer > 0 then
                local x, y, r = h.x + ox, h.y + oy, h.radius
                put(getEffectKeyByFields("toxic", x, y, r), x, y, r, "toxic")
            end
        end
    end
    if Game.effects then
        for _, e in ipairs(Game.effects) do
            if e.type == "explosion" and e.x and e.y and e.timer and e.timer > 0 then
                local r = e.maxRadius or e.radius or 80
                local x, y, c = e.x + ox, e.y + oy, e.color or "blue"
                put(getEffectKeyByFields("explosion", x, y, r), x, y, r, "explosion", { color = c })
            elseif e.type == "orange_splat" and e.x and e.y then
                local r = Constants.INSANE_EXPLOSION_RADIUS or 120
                local x, y = e.x + ox, e.y + oy
                put(getEffectKeyByFields("orange_explosion", x, y, r), x, y, r, "orange_explosion")
            end
        end
    end
    if Game.units then
        local ur = Constants.UNIT_RADIUS or 9.375
        for _, u in ipairs(Game.units) do
            if not u.isDead and u.body then
                local ux, uy = u.body:getPosition()
                local r, g, b = 1, 1, 1
                if u.state == "neutral" then r, g, b = unpack(Constants.COLORS.GREY)
                elseif u.alignment == "red" then r, g, b = unpack(Constants.COLORS.RED)
                else r, g, b = unpack(Constants.COLORS.BLUE) end
                local hp = (u.hp or Constants.UNIT_HP) / Constants.UNIT_HP
                r, g, b = r * hp, g * hp, b * hp
                local x, y, rad = ux + ox, uy + oy, ur * 4
                local st = u.state or "neutral"
                put(getEffectKeyByFields("unit", x, y, rad), x, y, rad, "unit", { colorR = r, colorG = g, colorB = b, state = st })
            end
        end
    end
    return current
end

-- Snapshot effect so fading list never shares a table with previousEffects (avoids reuse/mutation bugs).
local function snapshotEffect(prev)
    return {
        x = prev.x, y = prev.y, radius = prev.radius, type = prev.type or "unknown",
        color = prev.color, colorR = prev.colorR, colorG = prev.colorG, colorB = prev.colorB,
        state = prev.state, weaponType = prev.weaponType, alpha = prev.alpha,
    }
end

function DrawingHelpers.updateGridEffectState()
    local current = buildCurrentEffects(previousEffects)
    for key, prev in pairs(previousEffects) do
        if not current[key] then
            if prev.type == "explosion_zone" or prev.type == "explosion" then
                -- do not add red/blue explosion lights to fading (grid never draws them from fading; avoids stuck lights)
            else
                if #fadingEffects >= GRID_MAX_FADING then
                    fadingEffects[1] = fadingEffects[#fadingEffects]
                    fadingEffects[#fadingEffects] = nil
                end
                fadingEffects[#fadingEffects + 1] = { effect = snapshotEffect(prev), timer = GRID_FADE_DURATION }
            end
        end
    end
    previousEffects = current
end

function DrawingHelpers.resetGridState()
    for i = #fadingEffects, 1, -1 do fadingEffects[i] = nil end
    for k in pairs(previousEffects) do previousEffects[k] = nil end
end

local function pushLightFromEffect(e, baseAlpha)
    baseAlpha = baseAlpha or 1.0
    local x, y, radius = e.x, e.y, e.radius
    local lr = radius * 1.5
    if e.type == "projectile_trail" then lr = radius * 1.2
    elseif e.type == "unit" then lr = radius * 2.0
    end
    local r, g, b, a
    if e.type == "toxic" then
        r, g, b, a = 0.2, 0.8, 0.2, 0.7 * baseAlpha
    elseif e.type == "explosion_zone" or e.type == "explosion" then
        if e.color == "red" then r, g, b, a = 0.8, 0.3, 0.2, 0.7 * baseAlpha
        else r, g, b, a = 0.2, 0.4, 0.8, 0.7 * baseAlpha end
    elseif e.type == "orange_explosion" then
        r, g, b, a = 0.9, 0.5, 0.1, 0.7 * baseAlpha
    elseif e.type == "unit" then
        r, g, b = e.colorR or 0.7, e.colorG or 0.7, e.colorB or 0.7
        if r > g and r > b then r = math.min(1, r * 1.3); g = g * 0.8; b = b * 0.8 end
        a = (e.state == "enraged" and 0.9 or 0.7) * baseAlpha
    elseif e.type == "reticule" then
        local pulse = math.sin(love.timer.getTime() * 20) * 0.2 + 0.8
        if e.color == "red" then r, g, b, a = 1, 0.3, 0.3, 0.7 * pulse * baseAlpha
        else r, g, b, a = 0.3, 0.4, 1, 0.7 * pulse * baseAlpha end
    elseif e.type == "projectile" then
        if e.weaponType == "puck" then
            if e.color == "red" then r, g, b, a = 0.9, 0.5, 0.4, 0.7 * baseAlpha
            else r, g, b, a = 0.4, 0.6, 1, 0.7 * baseAlpha end
        else
            if e.color == "red" then r, g, b, a = 0.9, 0.4, 0.3, 0.6 * baseAlpha
            else r, g, b, a = 0.3, 0.5, 0.9, 0.6 * baseAlpha end
        end
    elseif e.type == "projectile_trail" then
        local ta = e.alpha or 0.5
        if e.weaponType == "puck" then
            if e.color == "red" then r, g, b, a = 0.9, 0.5, 0.4, 0.5 * ta
            else r, g, b, a = 0.4, 0.6, 1, 0.5 * ta end
        else
            if e.color == "red" then r, g, b, a = 0.9, 0.4, 0.3, 0.4 * ta
            else r, g, b, a = 0.3, 0.5, 0.9, 0.4 * ta end
        end
    else
        r, g, b, a = 0, 0.7, 0, 0.8 * baseAlpha
    end
    addLight(x, y, lr, r, g, b, a)
end

local function fillLightArrays()
    _lightCount = 0
    local ox, oy = Constants.OFFSET_X, Constants.OFFSET_Y
    if Game.turret and Game.turret.legs then
        for _, leg in ipairs(Game.turret.legs) do
            if leg.footX and leg.footY then
                addLight(leg.footX + ox, leg.footY + oy, 100, 0, 0.7, 0, 0.8)
            end
        end
    end
    if Game.turret and Game.turret.isCharging then
        local dist = Game.turret.chargeTimer * 500
        local tx = Game.turret.visualX + math.cos(Game.turret.visualAngle) * dist
        local ty = Game.turret.visualY + math.sin(Game.turret.visualAngle) * dist
        tx = math.max(20, math.min(Constants.PLAYFIELD_WIDTH - 20, tx))
        ty = math.max(20, math.min(Constants.PLAYFIELD_HEIGHT - 20, ty))
        local pulse = math.sin(love.timer.getTime() * 20) * 0.2 + 0.8
        local c = Game.turret.chargeColor or "blue"
        if c == "red" then addLight(tx + ox, ty + oy, 30, 1, 0.3, 0.3, 0.7 * pulse)
        else addLight(tx + ox, ty + oy, 30, 0.3, 0.4, 1, 0.7 * pulse) end
    end
    if Game.explosionZones then
        for _, z in ipairs(Game.explosionZones) do
            if z.x and z.y and z.radius and z.timer and z.timer > 0 then
                pushLightFromEffect({ x = z.x + ox, y = z.y + oy, radius = z.radius, type = "explosion_zone", color = z.color or "blue" })
            end
        end
    end
    if Game.hazards then
        for _, h in ipairs(Game.hazards) do
            if h.x and h.y and h.radius and h.timer and h.timer > 0 then
                pushLightFromEffect({ x = h.x + ox, y = h.y + oy, radius = h.radius, type = "toxic" })
            end
        end
    end
    if Game.effects then
        for _, e in ipairs(Game.effects) do
            if e.type == "explosion" and e.x and e.y and e.timer and e.timer > 0 then
                pushLightFromEffect({ x = e.x + ox, y = e.y + oy, radius = e.maxRadius or e.radius or 80, type = "explosion", color = e.color or "blue" })
            elseif e.type == "orange_splat" and e.x and e.y then
                pushLightFromEffect({ x = e.x + ox, y = e.y + oy, radius = Constants.INSANE_EXPLOSION_RADIUS or 120, type = "orange_explosion" })
            end
        end
    end
    if Game.units then
        local ur = Constants.UNIT_RADIUS or 9.375
        for _, u in ipairs(Game.units) do
            if not u.isDead and u.body then
                local ux, uy = u.body:getPosition()
                local r, g, b = 1, 1, 1
                if u.state == "neutral" then r, g, b = unpack(Constants.COLORS.GREY)
                elseif u.alignment == "red" then r, g, b = unpack(Constants.COLORS.RED)
                else r, g, b = unpack(Constants.COLORS.BLUE) end
                local hp = (u.hp or Constants.UNIT_HP) / Constants.UNIT_HP
                r, g, b = r * hp, g * hp, b * hp
                pushLightFromEffect({ x = ux + ox, y = uy + oy, radius = ur * 4, type = "unit", colorR = r, colorG = g, colorB = b, state = u.state or "neutral" })
            end
        end
    end
    if Game.projectiles then
        for _, p in ipairs(Game.projectiles) do
            if not p.isDead and p.body then
                local px, py = p.body:getPosition()
                local rad = p.shape and p.shape:getRadius() or 15
                local lr = (p.weaponType == "puck") and (rad * 4) or (rad * 2)
                pushLightFromEffect({ x = px + ox, y = py + oy, radius = lr, type = "projectile", color = p.color or "blue", weaponType = p.weaponType or "puck" })
                if p.trail then
                    for i = 1, #p.trail, 3 do
                        local pt = p.trail[i]
                        if pt and pt.alpha and pt.alpha > 0.1 then
                            local tr = (p.weaponType == "puck") and (rad * 2) or (rad * 1.5)
                            pushLightFromEffect({ x = pt.x + ox, y = pt.y + oy, radius = tr, type = "projectile_trail", color = p.color or "blue", weaponType = p.weaponType or "puck", alpha = pt.alpha })
                        end
                    end
                end
            end
        end
    end
    for _, f in ipairs(fadingEffects) do
        if f.timer > 0 then
            local e = f.effect
            if e.type == "explosion_zone" or e.type == "explosion" then
                -- Never draw red/blue explosion lights from fading (avoids stuck lights; active path only)
            else
                local fa = f.timer / GRID_FADE_DURATION
                pushLightFromEffect({ x = e.x, y = e.y, radius = e.radius, type = e.type, color = e.color, colorR = e.colorR, colorG = e.colorG, colorB = e.colorB, state = e.state, weaponType = e.weaponType, alpha = e.alpha }, fa)
            end
        end
    end
end

-- Fill playfield light arrays (units, projectiles, hazards, etc.) for use by other systems (e.g. MainFrame normal map).
function DrawingHelpers.ensurePlayfieldLightsFilled()
    if not _lightX then
        _lightX, _lightY, _lightR, _lightG, _lightB, _lightA, _lightRadius = {}, {}, {}, {}, {}, {}, {}
    end
    fillLightArrays()
end

-- Return current light data after ensurePlayfieldLightsFilled(): count, x, y, r, g, b, a, radius arrays.
function DrawingHelpers.getPlayfieldLightData()
    return _lightCount or 0, _lightX, _lightY, _lightR, _lightG, _lightB, _lightA, _lightRadius
end

function DrawingHelpers.drawPlayfieldGrid(skipGridLights)
    if not ENABLE_PLAYFIELD_GRID then return end
    local startX = Constants.OFFSET_X
    local startY = Constants.OFFSET_Y
    local endX = startX + Constants.PLAYFIELD_WIDTH
    local endY = startY + Constants.PLAYFIELD_HEIGHT

    if skipGridLights then
        love.graphics.setColor(0.12, 0.12, 0.12, 0.3)
    else
        love.graphics.setColor(0, 0.25, 0, 0.3)
    end
    love.graphics.setLineWidth(1)
    local x = startX
    while x <= endX do
        love.graphics.line(x, startY, x, endY)
        x = x + GRID_SPACING
    end
    local y = startY
    while y <= endY do
        love.graphics.line(startX, y, endX, y)
        y = y + GRID_SPACING
    end

    if skipGridLights then return end

    if not _lightX then
        _lightX, _lightY, _lightR, _lightG, _lightB, _lightA, _lightRadius = {}, {}, {}, {}, {}, {}, {}
    end
    fillLightArrays()
    if _lightCount == 0 then return end

    local baseR, baseG, baseB, baseA = 0, 0.25, 0, 0.3
    local crossSize = GRID_CROSS_SIZE
    love.graphics.setLineWidth(1.5)
    x = startX
    while x <= endX do
        y = startY
        while y <= endY do
            local bestI, bestR, bestG, bestB, bestA = 0, baseR, baseG, baseB, baseA
            for k = 1, _lightCount do
                local lx, ly = _lightX[k], _lightY[k]
                local rad = _lightRadius[k]
                local dx, dy = x - lx, y - ly
                if dx * dx + dy * dy < rad * rad then
                    local d = math.sqrt(dx * dx + dy * dy)
                    local intensity = 1 - d / rad
                    if intensity > bestI then
                        bestI = intensity
                        local lr, lg, lb, la = _lightR[k], _lightG[k], _lightB[k], _lightA[k]
                        bestR = baseR + (lr - baseR) * intensity
                        bestG = baseG + (lg - baseG) * intensity
                        bestB = baseB + (lb - baseB) * intensity
                        bestA = baseA + (la - baseA) * intensity
                    end
                end
            end
            if bestI > 0 then
                love.graphics.setColor(bestR, bestG, bestB, bestA)
                love.graphics.line(x - crossSize, y, x + crossSize, y)
                love.graphics.line(x, y - crossSize, x, y + crossSize)
            end
            y = y + GRID_SPACING
        end
        x = x + GRID_SPACING
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


