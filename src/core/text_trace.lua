-- src/core/text_trace.lua
-- Traces lines from text elements to the godray center point

local Constants = require("src.constants")
local TopBanner = require("src.core.top_banner")
local DrawLayers = require("src.core.draw_layers")
local Engagement = require("src.core.engagement")

local TextTrace = {}

-- Internal state
local state = {
    shader = nil,  -- Radial blur shader (same as godrays)
    glowShader = nil,  -- Gaussian blur shader for glow
    canvas = nil,  -- Canvas for drawing lines
    glowCanvas = nil,  -- Canvas for glow pass
    compositeCanvas = nil,  -- Final composite canvas
    textCanvas = nil,  -- Canvas for rendering text to sample pixels
    textImageData = nil,  -- ImageData for reading text pixels
    textPositions = {},  -- Array of {x, y} positions in screen coordinates
    rayLength = 200,  -- Length of rays in pixels (same as godrays)
    rayWidth = 1,  -- Width of trace lines (thin)
    blurStrength = 200.0,  -- Radial blur strength (same as godrays)
    brightnessMultiplier = 4.0,  -- Brightness multiplier (same as godrays)
    glowStrength = 3.0,  -- Glow blur strength (same as godrays)
    lineColor = {0.2, 1.0, 0.3},  -- Green, matching godrays
    opacity = 1.0,  -- Full opacity
    pixelSampleRate = 8,  -- Sample every Nth pixel (8 = every 8th pixel)
}

-- Initialize text trace (load shader and create canvas)
function TextTrace.load()
    -- Load godray shader (same as godrays for consistency)
    local shaderCode = love.filesystem.read("shaders/godray.fs")
    if shaderCode then
        state.shader = love.graphics.newShader(shaderCode)
    else
        print("Warning: Could not load godray shader for text trace")
    end
    
    -- Load glow shader (Gaussian blur)
    local glowShaderCode = love.filesystem.read("shaders/gaussian_blur.fs")
    if glowShaderCode then
        state.glowShader = love.graphics.newShader(glowShaderCode)
    else
        print("Warning: Could not load glow shader")
    end
    
    -- Create canvases for drawing trace lines
    state.canvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, {
        format = "rgba8"
    })
    state.canvas:setFilter("linear", "linear")
    
    state.glowCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, {
        format = "rgba8"
    })
    state.glowCanvas:setFilter("linear", "linear")
    
    state.compositeCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, {
        format = "rgba8"
    })
    state.compositeCanvas:setFilter("linear", "linear")
    
    -- Create canvas for rendering text to sample pixels
    state.textCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, {
        format = "rgba8"
    })
    state.textCanvas:setFilter("nearest", "nearest")  -- Nearest for pixel-perfect sampling
end

-- Add a text position to trace from
function TextTrace.addTextPosition(x, y)
    table.insert(state.textPositions, {x = x, y = y})
end

-- Clear all text positions
function TextTrace.clearTextPositions()
    state.textPositions = {}
end

-- Render text to canvas and sample pixels
local function renderTextToCanvas(text, textX, textY, terminalFont, glitchTextTimer, glitchTextWriteProgress)
    if not state.textCanvas or not terminalFont then
        return nil
    end
    
    -- Save current state
    local oldCanvas = love.graphics.getCanvas()
    local oldColor = {love.graphics.getColor()}
    
    -- Render text to canvas (full screen canvas, text rendered at its actual position)
    love.graphics.setCanvas(state.textCanvas)
    love.graphics.clear(0, 0, 0, 0)  -- Clear to transparent
    love.graphics.setColor(1, 1, 1, 1)  -- White for visibility
    
    -- Replicate the text rendering logic from TopBanner
    love.graphics.setFont(terminalFont)
    
    -- Calculate how many characters to show based on write progress
    local charsToShow = math.floor(glitchTextWriteProgress * #text)
    local displayText = text:sub(1, charsToShow)
    
    -- Subtle glitch: only corrupt 3% of characters (much less glitchy)
    local glitchChars = {"█", "▓", "▒"}
    local corruptedText = ""
    
    -- Use timer-based seed for consistent corruption per frame
    math.randomseed(math.floor(glitchTextTimer * 100))
    
    for i = 1, #displayText do
        local char = displayText:sub(i, i)
        -- Randomly corrupt some characters (much less frequent)
        if math.random() < 0.03 then  -- 3% chance of corruption
            corruptedText = corruptedText .. glitchChars[math.random(#glitchChars)]
        else
            corruptedText = corruptedText .. char
        end
    end
    
    -- Pulsing effect (alpha pulses smoothly)
    local pulse = (math.sin(glitchTextTimer * 3) + 1) / 2  -- 0 to 1
    local alpha = 0.6 + pulse * 0.4  -- Pulse between 0.6 and 1.0
    
    -- Scaling effect (starts small, scales up during write-on, then pulses slightly)
    local baseScale = 1.0
    if glitchTextWriteProgress < 1.0 then
        -- Scale up during write-on (from 0.5 to 1.0)
        baseScale = 0.5 + glitchTextWriteProgress * 0.5
    else
        -- Slight pulse after write-on completes
        baseScale = 1.0 + math.sin(glitchTextTimer * 4) * 0.05  -- Pulse between 0.95 and 1.05
    end
    
    -- Get text width for centering (use full text for width calculation)
    local fullTextWidth = terminalFont:getWidth(text)
    local centerX = textX - fullTextWidth / 2
    
    -- Draw text with scaling and pulsing
    love.graphics.push()
    love.graphics.translate(centerX + fullTextWidth / 2, textY)
    love.graphics.scale(baseScale, baseScale)
    love.graphics.translate(-fullTextWidth / 2, 0)
    
    -- Main text with green terminal color, pulsing alpha
    love.graphics.setColor(0, 1, 0, alpha)  -- Green terminal text with pulsing alpha
    love.graphics.print(corruptedText, 0, 0)
    
    -- Subtle red glitch overlay (much less frequent)
    if math.random() < 0.1 then
        love.graphics.setColor(1, 0, 0, alpha * 0.2)
        love.graphics.print(corruptedText, 1, 1)
    end
    
    love.graphics.pop()
    
    -- Restore canvas BEFORE calling newImageData (can't call it on active canvas)
    love.graphics.setCanvas(oldCanvas)
    love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
    
    -- Get ImageData from canvas (now that it's not active)
    state.textImageData = state.textCanvas:newImageData()
    
    return state.textImageData
end

-- Draw text trace lines
function TextTrace.draw()
    -- Only draw during life lost or game over
    if not Game then
        return
    end
    
    if not Game.modes.lifeLostAuditor and not Game.modes.gameOver then
        return
    end
    
    -- For life lost, only draw when text is visible (same flicker logic as text)
    if Game.modes.lifeLostAuditor then
        if not TopBanner.isLifeLostTextVisible(Game.timers.glitchText) then
            return
        end
    end
    
    -- For game over, only draw when text is visible (same flicker logic as text)
    if Game.modes.gameOver then
        if not TopBanner.isGameOverTextVisible(Game.timers.glitchText) then
            return
        end
    end
    
    -- Get center point from top banner (same as godrays) - this follows the banner
    local centerX, centerY = TopBanner.getVigilantCenter()
    
    if not centerX or not centerY then
        return
    end
    
    -- Move center point 47 pixels up and 4 pixels left (same offset as godrays)
    centerY = centerY - 47
    centerX = centerX - 4
    
    -- Get text position from TopBanner (this follows the banner when it moves)
    local textX, textY = TopBanner.getTextPosition()
    if not textX or not textY then
        return
    end
    
    -- Get the text and font from Game
    local text = ""
    if Game.modes.lifeLostAuditor then
        text = "LOW PERFORMANCE DETECTED - INITIALIZE REASSIGNMENT"
    elseif Game.modes.gameOver then
        text = "YIELD NOT SATISFACTORY - LIQUIDATING ASSET"
    end
    
    if not text or not Game.fonts or not Game.fonts.terminal then
        return
    end
    
    -- Render text to canvas and get ImageData
    local imageData = renderTextToCanvas(
        text, 
        textX, 
        textY, 
        Game.fonts.terminal, 
        Game.timers.glitchText, 
        Game.visualEffects.glitchTextWriteProgress
    )
    
    if not imageData then
        return
    end
    
    -- For life lost/game over, use full opacity (engagement is already low)
    -- We want the lines to be visible during these screens
    local finalOpacity = 1.0  -- Full opacity for visibility
    
    -- Save current state
    local oldBlendMode = love.graphics.getBlendMode()
    local oldColor = {love.graphics.getColor()}
    local oldLineWidth = love.graphics.getLineWidth()
    
    -- Draw thin lines from text pixels to center
    love.graphics.setBlendMode("add")  -- Additive blend for glow effect
    love.graphics.setColor(state.lineColor[1], state.lineColor[2], state.lineColor[3], finalOpacity)
    love.graphics.setLineWidth(state.rayWidth)
    
    -- Sample pixels from the text ImageData
    local width = imageData:getWidth()
    local height = imageData:getHeight()
    
    -- Calculate text rendering parameters (same as in renderTextToCanvas)
    local terminalFont = Game.fonts.terminal
    local fullTextWidth = terminalFont:getWidth(text)
    local baseScale = 1.0
    if Game.visualEffects.glitchTextWriteProgress < 1.0 then
        baseScale = 0.5 + Game.visualEffects.glitchTextWriteProgress * 0.5
    else
        baseScale = 1.0 + math.sin(Game.timers.glitchText * 4) * 0.05
    end
    
    -- Calculate text bounds in screen space
    local textCenterX = textX
    local textCenterY = textY
    local textLeft = textCenterX - fullTextWidth / 2
    local textTop = textCenterY - (terminalFont:getHeight() * baseScale) / 2
    
    -- Sample pixels and draw lines from visible text pixels to center
    for y = 0, height - 1, state.pixelSampleRate do
        for x = 0, width - 1, state.pixelSampleRate do
            local r, g, b, a = imageData:getPixel(x, y)
            
            -- If pixel has alpha (is part of text), draw a line to center
            if a > 0.1 then  -- Threshold for visibility
                -- Convert canvas coordinates to screen coordinates
                -- Canvas is full screen, so x,y are already in screen coordinates
                local screenX = x
                local screenY = y
                
                -- Calculate brightness from the sampled pixel (use green channel as it's green text)
                -- Use half the brightness of the sampled text pixel
                local pixelBrightness = g * a  -- Green channel multiplied by alpha
                local lineBrightness = pixelBrightness * 0.5  -- Half brightness
                
                -- Set color with half brightness
                love.graphics.setColor(
                    state.lineColor[1] * lineBrightness,
                    state.lineColor[2] * lineBrightness,
                    state.lineColor[3] * lineBrightness,
                    finalOpacity
                )
                
                -- Draw thin line from this pixel to center
                love.graphics.line(screenX, screenY, centerX, centerY)
            end
        end
    end
    
    -- Restore previous state
    love.graphics.setBlendMode(oldBlendMode)
    love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
    love.graphics.setLineWidth(oldLineWidth)
end

-- Register text trace with z-depth system (draw on top, same as godrays)
function TextTrace.registerLayer()
    DrawLayers.register(Constants.Z_DEPTH.GODRAY, function()
        TextTrace.draw()
    end, "TextTrace")
end

return TextTrace

