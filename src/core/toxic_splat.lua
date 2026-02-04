-- src/core/toxic_splat.lua
-- Animated toxic splat system for more dynamic and irregular toxic zones

local ToxicSplat = {}

-- Easing function: Makes the splat "overshoot" its size and settle back
-- This gives it a jelly/viscous feeling.
function ToxicSplat.easeOutElastic(x)
    if x >= 1 then return 1 end
    local c4 = (2 * math.pi) / 3
    return math.pow(2, -10 * x) * math.sin((x * 10 - 0.75) * c4) + 1
end

-- Max shapes per splat (keeps draw calls and frame time under control)
local MAX_SPLAT_SHAPES = 72

-- Segment count by radius (small circles need fewer segments; keeps look, saves GPU)
local function segmentsForRadius(r)
    if r <= 3 then return 10
    elseif r <= 8 then return 16
    else return 24
    end
end

-- Generate splat geometry based on radius (capped for performance)
function ToxicSplat.generateSplatGeometry(radius)
    local shapes = {}
    local scale = radius / 60.0
    
    -- 1. Center Core
    local coreSize = (love.math.random(15, 25) * scale)
    table.insert(shapes, {type="core", x=0, y=0, r=coreSize})
    
    -- 2. Center Lumps (capped)
    local lumpCount = math.min(math.floor(20 * scale), 14)
    for i = 1, lumpCount do
        local angle = love.math.random() * math.pi * 2
        local dist = love.math.random(coreSize * 0.5, coreSize * 1.2)
        local size = love.math.random(5, 12) * scale
        table.insert(shapes, {type="lump", x=math.cos(angle)*dist, y=math.sin(angle)*dist, r=size})
    end
    
    -- 3. Streaks & Blobs (capped total and per-streak steps)
    local streakCount = math.min(math.floor(love.math.random(50, 90) * scale), 28)
    for i = 1, streakCount do
        if #shapes >= MAX_SPLAT_SHAPES then break end
        local angle = love.math.random() * math.pi * 2
        local thickness = (love.math.random(25, 50) / 10) * scale
        local curX, curY = 0, 0
        local decay = love.math.random(15, 30) / 100
        local shouldBlob = love.math.random() < 0.75
        local steps = 0
        local maxSteps = 12
        while thickness > 0.4 * scale and steps < maxSteps and #shapes < MAX_SPLAT_SHAPES do
            steps = steps + 1
            curX = curX + math.cos(angle) * 1.5
            curY = curY + math.sin(angle) * 1.5
            angle = angle + love.math.random(-30, 30) / 100
            thickness = thickness - decay * scale
            table.insert(shapes, {type="streak", x=curX, y=curY, r=thickness})
        end
        if shouldBlob and #shapes < MAX_SPLAT_SHAPES then
            local clusterCount = math.min(love.math.random(2, 4), MAX_SPLAT_SHAPES - #shapes)
            for j = 1, clusterCount do
                local blobSize = (love.math.random(10, 25) / 10) * scale
                local offA = love.math.random() * math.pi * 2
                local offD = love.math.random() * blobSize
                table.insert(shapes, {type="blob", x=curX + math.cos(offA)*offD, y=curY + math.sin(offA)*offD, r=blobSize})
            end
        end
    end
    return shapes
end

-- Create a new splat instance
function ToxicSplat.createSplat(x, y, radius, baseColor)
    baseColor = baseColor or {0.1, 0.7, 0.1} -- Dark green default
    
    local splat = {
        x = x,
        y = y,
        progress = 0,
        currentScale = 0,
        baseColor = baseColor,
        shapes = ToxicSplat.generateSplatGeometry(radius),
        radius = radius, -- Store original radius for reference
        isAnimating = true
    }
    
    return splat
end

-- Update splat animation
function ToxicSplat.update(splat, dt, animationSpeed)
    animationSpeed = animationSpeed or 4.0
    
    if not splat.isAnimating then
        return false -- Animation complete
    end
    
    -- Increase progress (0.0 to 1.0)
    splat.progress = splat.progress + dt * animationSpeed
    
    -- Calculate current scale using an easing function for "Pop" effect
    splat.currentScale = ToxicSplat.easeOutElastic(splat.progress)
    
    -- If animation is done, mark as complete and cache for fast drawing
    if splat.progress >= 1.0 then
        splat.currentScale = 1.0
        splat.isAnimating = false
        ToxicSplat._cacheSplatCanvas(splat)
        return false -- Animation complete
    end
    
    return true -- Still animating
end

-- One-time cache: render settled splat to a canvas so we draw 1 texture instead of many circles
function ToxicSplat._cacheSplatCanvas(splat)
    if splat.cachedCanvas then return end
    local r = splat.radius
    local size = math.ceil(r * 2 + 24)
    splat.cachedCanvas = love.graphics.newCanvas(size, size)
    splat.cachedCanvas:setFilter("linear", "linear")
    local cx, cy = size / 2, size / 2
    love.graphics.setCanvas(splat.cachedCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    -- Base layer
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(splat.baseColor[1], splat.baseColor[2], splat.baseColor[3], 1)
    for _, shape in ipairs(splat.shapes) do
        local seg = segmentsForRadius(shape.r)
        love.graphics.circle("fill", shape.x, shape.y, shape.r, seg)
    end
    -- Glow layer
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.2, 0.4, 0.0, 0.5)
    local lx, ly = -0.4 * 0.3, -0.4 * 0.3
    for _, shape in ipairs(splat.shapes) do
        if shape.type == "core" or shape.type == "lump" or (shape.type == "blob" and shape.r > 1.2) then
            local offX = lx * shape.r
            local offY = ly * shape.r
            love.graphics.circle("fill", shape.x + offX, shape.y + offY, shape.r * 0.7, segmentsForRadius(shape.r * 0.7))
        end
    end
    love.graphics.pop()
    love.graphics.setCanvas()
    splat.cachedOriginX = cx
    splat.cachedOriginY = cy
end

-- Draw a splat instance (uses cached canvas when settled for much lower cost)
function ToxicSplat.draw(splat, alpha, lightDirX, lightDirY)
    alpha = alpha or 1.0
    lightDirX = lightDirX or -0.4
    lightDirY = lightDirY or -0.4

    -- Settled splat: one draw call from cache (same look, minimal cost)
    if splat.cachedCanvas then
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.setBlendMode("alpha")
        love.graphics.draw(splat.cachedCanvas, splat.x - splat.cachedOriginX, splat.y - splat.cachedOriginY)
        return
    end

    love.graphics.push()
    love.graphics.translate(splat.x, splat.y)
    love.graphics.scale(splat.currentScale)

    -- PASS 1: Base Dark Layer (fewer segments for small circles)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(splat.baseColor[1], splat.baseColor[2], splat.baseColor[3], alpha)
    for _, shape in ipairs(splat.shapes) do
        love.graphics.circle("fill", shape.x, shape.y, shape.r, segmentsForRadius(shape.r))
    end

    -- PASS 2: Additive Highlights (skip when barely visible)
    if alpha >= 0.12 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(0.2, 0.4, 0.0, 0.5 * alpha)
        for _, shape in ipairs(splat.shapes) do
            if shape.type == "core" or shape.type == "lump" or (shape.type == "blob" and shape.r > 1.2) then
                local offX = lightDirX * shape.r * 0.3
                local offY = lightDirY * shape.r * 0.3
                love.graphics.circle("fill", shape.x + offX, shape.y + offY, shape.r * 0.7, segmentsForRadius(shape.r * 0.7))
            end
        end
    end

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return ToxicSplat

