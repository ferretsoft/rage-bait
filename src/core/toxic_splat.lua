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

-- Generate splat geometry based on radius
function ToxicSplat.generateSplatGeometry(radius)
    local shapes = {}
    
    -- Scale factors based on radius (normalize to ~60 radius)
    local scale = radius / 60.0
    
    -- 1. Center Core
    local coreSize = (love.math.random(15, 25) * scale)
    table.insert(shapes, {type="core", x=0, y=0, r=coreSize})
    
    -- 2. Center Lumps
    local lumpCount = math.floor(20 * scale)
    for i = 1, lumpCount do
        local angle = love.math.random() * math.pi * 2
        local dist = love.math.random(coreSize * 0.5, coreSize * 1.2)
        local size = love.math.random(5, 12) * scale
        table.insert(shapes, {
            type="lump", 
            x=math.cos(angle)*dist, 
            y=math.sin(angle)*dist, 
            r=size
        })
    end
    
    -- 3. Streaks & Blobs
    local streakCount = math.floor(love.math.random(50, 90) * scale)
    for i = 1, streakCount do
        local angle = love.math.random() * math.pi * 2
        local thickness = (love.math.random(25, 50) / 10) * scale
        local curX, curY = 0, 0 -- Relative to center
        local decay = love.math.random(15, 30) / 100 
        local shouldBlob = love.math.random() < 0.75 
        
        while thickness > 0.4 * scale do
            curX = curX + math.cos(angle) * 1.5
            curY = curY + math.sin(angle) * 1.5
            angle = angle + love.math.random(-30, 30) / 100 
            thickness = thickness - decay * scale
            
            table.insert(shapes, {type="streak", x=curX, y=curY, r=thickness})
        end
        
        if shouldBlob then
            local clusterCount = love.math.random(2, 4)
            for j = 1, clusterCount do
                local blobSize = (love.math.random(10, 25) / 10) * scale
                local offA = love.math.random() * math.pi * 2
                local offD = love.math.random() * blobSize
                local bx = curX + math.cos(offA)*offD
                local by = curY + math.sin(offA)*offD
                
                table.insert(shapes, {type="blob", x=bx, y=by, r=blobSize})
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
    
    -- If animation is done, mark as complete
    if splat.progress >= 1.0 then
        splat.currentScale = 1.0
        splat.isAnimating = false
        return false -- Animation complete
    end
    
    return true -- Still animating
end

-- Draw a splat instance
function ToxicSplat.draw(splat, alpha, lightDirX, lightDirY)
    alpha = alpha or 1.0
    lightDirX = lightDirX or -0.4
    lightDirY = lightDirY or -0.4
    
    love.graphics.push()
    love.graphics.translate(splat.x, splat.y)
    love.graphics.scale(splat.currentScale) -- Grow the splat!
    
    -- PASS 1: Base Dark Layer
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(splat.baseColor[1], splat.baseColor[2], splat.baseColor[3], alpha)
    
    for _, shape in ipairs(splat.shapes) do
        love.graphics.circle("fill", shape.x, shape.y, shape.r)
    end
    
    -- PASS 2: Additive Highlights (Toxic Glow)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(0.2, 0.4, 0.0, 0.5 * alpha) -- Neon glow
    
    -- Only highlight blobs/lumps, streaks are too thin to notice
    for _, shape in ipairs(splat.shapes) do
        if shape.type == "core" or shape.type == "lump" or (shape.type == "blob" and shape.r > 1.2) then
            local offX = lightDirX * shape.r * 0.3
            local offY = lightDirY * shape.r * 0.3
            -- Scale highlight down slightly
            love.graphics.circle("fill", shape.x + offX, shape.y + offY, shape.r * 0.7)
        end
    end
    
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

return ToxicSplat

