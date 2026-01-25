-- Matrix-style falling text effect
-- Creates columns of falling green characters

local Constants = require("src.constants")
local MatrixEffect = {}

local state = {
    layers = {},  -- Multiple parallax layers
    charPool = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()[]{}|;:,.<>?/~`",
    charHeight = 0,
    fontSize = 16,
    font = nil,
    timer = 0,
    fadeSpeed = 0.015,  -- How fast characters fade (0-1 per second)
    fallSpeedMin = 640,  -- Minimum pixels per second (for slowest layer) - doubled again
    fallSpeedMax = 2000,  -- Maximum pixels per second (for fastest layer) - doubled again
    spawnRate = 0.15,  -- New column spawn rate (columns per second) - increased for more density
    minColumnLength = 12,  -- Minimum characters in a column (increased)
    maxColumnLength = 40,  -- Maximum characters in a column (increased)
    columnSpacing = 0.7,  -- Multiplier for spacing between columns (reduced for more columns on x-axis)
    charSpacing = 1.1,  -- Multiplier for spacing between characters in a column (reduced)
    randomSpawnDelay = 2.0,  -- Maximum random delay before first spawn (reduced for faster start)
    layerCount = 4,  -- Number of parallax layers (added very close layer)
    layerDepth = {0.5, 0.75, 1.0, 1.5},  -- Depth multipliers for each layer (0.5 = slowest/far, 1.5 = very close)
    layerAlpha = {0.3, 0.5, 0.8, 1.0},  -- Alpha for each layer (dimmer = further away, 1.0 = very close)
    layerFontSize = {18, 21, 24, 32},  -- Font sizes for each layer (smaller = further away, 32 = very close)
    layerColumnDensity = {1.0, 1.0, 1.0, 0.5},  -- Column density multiplier per layer (0.5 = fewer columns for close layer)
    motionBlurTrails = 5,  -- Number of trailing copies for motion blur
    motionBlurFade = 0.3,  -- Opacity fade per trail (0.3 = each trail is 30% of previous)
    transitionActive = false,  -- Whether matrix is being used as a transition
    transitionDuration = 1.0,  -- Duration of transition in seconds
    transitionTimer = 0,  -- Timer for transition
    transitionCallback = nil,  -- Callback to execute when transition completes
    scanlineHeight = 20,  -- Base height of each scanline in pixels (larger)
    scanlineSpacing = 8,  -- Base spacing between scanlines in pixels
    scanlineSpeed = 200,  -- Base speed of scanlines moving down (pixels per second)
    scanlineAlpha = 0.6,  -- Alpha of scanlines
    scanlineRandomSeed = 0,  -- Seed for random scanline generation
}

function MatrixEffect.load()
    -- Initialize multiple parallax layers
    for layerIndex = 1, state.layerCount do
        local layer = {
            columns = {},
            fontSize = state.layerFontSize[layerIndex],
            font = nil,
            depth = state.layerDepth[layerIndex],
            alpha = state.layerAlpha[layerIndex],
            columnCount = 0,
            charHeight = 0,
        }
        
        -- Create font for this layer using DOS font
        local success, font = pcall(love.graphics.newFont, "assets/ModernDOS9x16.ttf", layer.fontSize)
        if success and font then
            layer.font = font
        else
            -- Fallback to default font if DOS font doesn't load
            layer.font = love.graphics.newFont(layer.fontSize)
        end
        layer.charHeight = layer.font:getHeight()
        
        -- Calculate how many columns we need to fill the screen with spacing
        local charWidth = layer.font:getWidth("A")
        local columnWidth = charWidth * state.columnSpacing
        local density = state.layerColumnDensity[layerIndex] or 1.0
        layer.columnCount = math.ceil((Constants.SCREEN_WIDTH / columnWidth) * density)
        
        -- Initialize columns with random spacing for this layer
        for i = 1, layer.columnCount do
            -- Calculate fall speed based on layer depth (clamp depth to reasonable range)
            local clampedDepth = math.min(layer.depth, 2.0)  -- Cap at 2x speed
            local baseSpeed = state.fallSpeedMin + (state.fallSpeedMax - state.fallSpeedMin) * clampedDepth
            local speedVariation = (state.fallSpeedMax - state.fallSpeedMin) * 0.2  -- 20% variation
            local fallSpeed = baseSpeed + (math.random() - 0.5) * speedVariation
            
            table.insert(layer.columns, {
                x = (i - 1) * columnWidth,
                chars = {},
                spawnTimer = math.random() * state.randomSpawnDelay,  -- Random initial delay
                fallSpeed = fallSpeed,
            })
        end
        
        table.insert(state.layers, layer)
    end
end

function MatrixEffect.update(dt)
    state.timer = state.timer + dt
    
    -- Update transition timer
    if state.transitionActive then
        state.transitionTimer = state.transitionTimer + dt
        if state.transitionTimer >= state.transitionDuration then
            state.transitionActive = false
            if state.transitionCallback then
                state.transitionCallback()
                state.transitionCallback = nil
            end
        end
    end
    
    -- Update each parallax layer
    for _, layer in ipairs(state.layers) do
        -- Update each column in this layer
        for _, column in ipairs(layer.columns) do
            -- Update spawn timer
            column.spawnTimer = column.spawnTimer - dt
            
            -- Spawn new column if timer expired
            if column.spawnTimer <= 0 then
                -- Create a new column of characters with random length
                local length = math.random(state.minColumnLength, state.maxColumnLength)
                column.chars = {}
                
                for i = 1, length do
                    -- Random character selection (more randomness)
                    local charIndex = math.random(1, #state.charPool)
                    local char = state.charPool:sub(charIndex, charIndex)
                    
                    -- Add spacing between characters
                    local charSpacing = layer.charHeight * state.charSpacing
                    
                table.insert(column.chars, {
                    char = char,
                    y = -i * charSpacing,  -- Start above screen with spacing
                    brightness = 1.0 - (i / length) * 0.7,  -- Brighter at head, dimmer at tail
                    age = 0,
                    previousY = {},  -- Store previous positions for motion blur
                    previousTime = 0,  -- Track time for motion blur
                })
                end
                
                -- Reset spawn timer (random interval with more variation)
                column.spawnTimer = (1.0 / state.spawnRate) + math.random() * 4.0
            end
            
            -- Update existing characters
            for i = #column.chars, 1, -1 do
                local char = column.chars[i]
                
                -- Store previous position for motion blur (keep last N positions)
                if not char.previousY then
                    char.previousY = {}
                    char.previousTime = 0
                end
                
                -- Store current position in history
                table.insert(char.previousY, 1, char.y)
                if #char.previousY > state.motionBlurTrails then
                    table.remove(char.previousY)
                end
                
                -- Use column-specific fall speed (already adjusted for layer depth)
                char.y = char.y + column.fallSpeed * dt
                char.age = char.age + dt
                char.previousTime = char.previousTime + dt
                
                -- Fade out as it ages (with slight randomness)
                local fadeRate = state.fadeSpeed * (0.8 + math.random() * 0.4)  -- 20% variation
                char.brightness = char.brightness - fadeRate * dt
                char.brightness = math.max(0, char.brightness)
                
                -- Randomly change character occasionally (5% chance per frame)
                if math.random() < 0.05 then
                    local charIndex = math.random(1, #state.charPool)
                    char.char = state.charPool:sub(charIndex, charIndex)
                end
                
                -- Remove if off screen or fully faded
                if char.y > Constants.SCREEN_HEIGHT + layer.charHeight or char.brightness <= 0 then
                    table.remove(column.chars, i)
                end
            end
        end
    end
end

function MatrixEffect.draw()
    -- Use additive blending during transitions
    local oldBlendMode = love.graphics.getBlendMode()
    if state.transitionActive then
        love.graphics.setBlendMode("add")
    end
    
    -- Draw each parallax layer (back to front for proper depth)
    for _, layer in ipairs(state.layers) do
        love.graphics.setFont(layer.font)
        
        -- Draw each column in this layer
        for _, column in ipairs(layer.columns) do
            for _, char in ipairs(column.chars) do
                -- Draw motion blur trails (from oldest to newest)
                if char.previousY and #char.previousY > 0 then
                    for trailIndex = #char.previousY, 1, -1 do
                        local trailY = char.previousY[trailIndex]
                        local trailAlpha = math.pow(state.motionBlurFade, trailIndex)  -- Exponential fade
                        local green = 0.2 + char.brightness * 0.8  -- Range from 0.2 to 1.0
                        local finalAlpha = char.brightness * layer.alpha * trailAlpha  -- Apply layer alpha and trail fade
                        love.graphics.setColor(0, green, 0, finalAlpha)
                        love.graphics.print(char.char, column.x, trailY)
                    end
                end
                
                -- Draw main character (brightest)
                local green = 0.2 + char.brightness * 0.8  -- Range from 0.2 to 1.0
                local finalAlpha = char.brightness * layer.alpha  -- Apply layer alpha
                love.graphics.setColor(0, green, 0, finalAlpha)
                love.graphics.print(char.char, column.x, char.y)
            end
        end
    end
    
    -- Reset blend mode and color
    love.graphics.setBlendMode(oldBlendMode)
    love.graphics.setColor(1, 1, 1, 1)
end

function MatrixEffect.reset()
    state.timer = 0
    -- Reset all columns in all layers
    for _, layer in ipairs(state.layers) do
        for _, column in ipairs(layer.columns) do
            column.chars = {}
            column.spawnTimer = math.random() * state.randomSpawnDelay
        end
    end
end

-- Start matrix transition (wipe effect)
function MatrixEffect.startTransition(duration, callback)
    state.transitionActive = true
    state.transitionDuration = duration or 1.0
    state.transitionTimer = 0
    state.transitionCallback = callback
    -- Random seed for scanline randomness (different each transition)
    state.scanlineRandomSeed = math.random(10000)
    -- Reset matrix to start fresh
    MatrixEffect.reset()
    -- Immediately spawn columns to fill screen quickly
    for _, layer in ipairs(state.layers) do
        for _, column in ipairs(layer.columns) do
            column.spawnTimer = 0  -- Spawn immediately
        end
    end
end

-- Stop matrix transition
function MatrixEffect.stopTransition()
    state.transitionActive = false
    state.transitionTimer = 0
    state.transitionCallback = nil
end

-- Check if transition is active
function MatrixEffect.isTransitionActive()
    return state.transitionActive
end

-- Draw animated scanlines during transition
function MatrixEffect.drawScanlines()
    if not state.transitionActive then
        return
    end
    
    local oldColor = {love.graphics.getColor()}
    
    -- Use timer-based seed for consistent randomness per frame
    math.randomseed(math.floor(state.timer * 100) + state.scanlineRandomSeed)
    
    -- Draw scanlines with randomness
    local y = -state.scanlineHeight * 2
    while y < Constants.SCREEN_HEIGHT + state.scanlineHeight * 2 do
        -- Random variation in height (50% to 150% of base)
        local heightVariation = 0.5 + math.random() * 1.0
        local scanlineHeight = state.scanlineHeight * heightVariation
        
        -- Random variation in spacing (50% to 150% of base)
        local spacingVariation = 0.5 + math.random() * 1.0
        local scanlineSpacing = state.scanlineSpacing * spacingVariation
        
        -- Random speed variation per scanline (80% to 120% of base)
        local speedVariation = 0.8 + math.random() * 0.4
        local scanlineSpeed = state.scanlineSpeed * speedVariation
        local scanlineOffset = (state.timer * scanlineSpeed) % (scanlineHeight + scanlineSpacing)
        
        -- Random horizontal offset (some scanlines start slightly offset)
        local horizontalOffset = (math.random() - 0.5) * 20
        
        local scanlineY = y + scanlineOffset
        if scanlineY >= -scanlineHeight and scanlineY <= Constants.SCREEN_HEIGHT then
            -- Random alpha variation (70% to 100% of base)
            local alphaVariation = 0.7 + math.random() * 0.3
            love.graphics.setColor(0, 0, 0, state.scanlineAlpha * alphaVariation)
            love.graphics.rectangle("fill", horizontalOffset, scanlineY, Constants.SCREEN_WIDTH, scanlineHeight)
        end
        
        -- Move to next scanline position with random spacing
        y = y + scanlineHeight + scanlineSpacing + (math.random() - 0.5) * 10
    end
    
    love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
end

return MatrixEffect

