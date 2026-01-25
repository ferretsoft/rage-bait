-- src/core/godray.lua
-- Godray effect that follows the center of the top banner vigilant layer
-- Simple shader-based implementation

local Constants = require("src.constants")
local TopBanner = require("src.core.top_banner")
local DrawLayers = require("src.core.draw_layers")
local Engagement = require("src.core.engagement")

local Godray = {}

-- Internal state
local state = {
    timer = 0,  -- Animation timer
    rotationSpeed = 8.0,  -- Rotation speed (radians per second) - much faster
    numRays = 12,  -- Number of rays
    rayLength = 200,  -- Length of rays in pixels
    rayWidth = 3,  -- Width of rays in pixels
    blurStrength = 200.0,  -- Radial blur strength (temporarily high for testing)
    brightnessMultiplier = 4.0,  -- Brightness multiplier to fake additive glow (increased)
    glowStrength = 3.0,  -- Glow blur strength
    
    -- Shader and canvas
    shader = nil,
    glowShader = nil,  -- Gaussian blur shader for glow
    canvas = nil,  -- Canvas to draw rays to before applying blur
    glowCanvas = nil,  -- Canvas for glow pass
    compositeCanvas = nil,  -- Final composite canvas for all godray elements
}

-- Initialize godray (load shader and create canvas)
function Godray.load()
    -- Load godray shader
    local shaderCode = love.filesystem.read("shaders/godray.fs")
    if shaderCode then
        state.shader = love.graphics.newShader(shaderCode)
    else
        print("Warning: Could not load godray shader")
    end
    
    -- Load glow shader (Gaussian blur)
    local glowShaderCode = love.filesystem.read("shaders/gaussian_blur.fs")
    if glowShaderCode then
        state.glowShader = love.graphics.newShader(glowShaderCode)
    else
        print("Warning: Could not load glow shader")
    end
    
    -- Create canvas for drawing rays (with alpha channel)
    state.canvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, {
        format = "rgba8"  -- Ensure alpha channel is supported
    })
    state.canvas:setFilter("linear", "linear")
    
    -- Create canvas for glow pass
    state.glowCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, {
        format = "rgba8"
    })
    state.glowCanvas:setFilter("linear", "linear")
    
    -- Create composite canvas for final output
    state.compositeCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, {
        format = "rgba8"
    })
    state.compositeCanvas:setFilter("linear", "linear")
end

-- Update godray animation
function Godray.update(dt)
    state.timer = state.timer + dt
end

-- Draw godray effect
function Godray.draw()
    -- Only draw during gameplay
    if Engagement.value == nil then
        return
    end
    
    -- Allow drawing during life lost and game over as well (when banner moves)
    if not Game then
        return
    end
    
    -- Draw during playing, life lost, or game over states
    if Game.gameState ~= "playing" and not Game.modes.lifeLostAuditor and not Game.modes.gameOver then
        return
    end
    
    -- Get center point from top banner
    local centerX, centerY = TopBanner.getVigilantCenter()
    
    -- Allow center point to be off-screen - rays should continue even when center is out of frame
    if not centerX or not centerY then
        return
    end
    
    -- Ensure shader and canvas are initialized
    if not state.shader or not state.canvas or not state.glowShader or not state.glowCanvas then
        Godray.load()
    end
    
    if not state.shader or not state.canvas or not state.glowShader or not state.glowCanvas then
        return
    end
    
    -- Move center point 47 pixels up and 4 pixels left
    centerY = centerY - 47
    centerX = centerX - 4
    
    -- Calculate opacity: engagement 100 = 0 opacity, engagement 0 = 0.5 opacity
    local engagementValue = Engagement.value or 100
    local engagementPct = engagementValue / Constants.ENGAGEMENT_MAX
    -- Invert: 1.0 at engagement 0, 0.0 at engagement 100
    local invertedPct = 1.0 - engagementPct
    -- Scale to 0.0 - 0.5 range
    local finalOpacity = invertedPct * 0.5
    finalOpacity = math.max(0.0, math.min(0.5, finalOpacity))  -- Clamp to valid range
    
    -- If opacity is 0, don't draw
    if finalOpacity <= 0.001 then
        return
    end
    
    -- Calculate rotation angle
    local rotation = state.timer * state.rotationSpeed
    
    -- Save current state
    local oldCanvas = love.graphics.getCanvas()
    local oldShader = love.graphics.getShader()
    
    -- Step 1: Draw rays to canvas (without blur shader)
    love.graphics.setCanvas(state.canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader()  -- No shader for initial drawing
    love.graphics.setBlendMode("alpha")  -- Use regular alpha, not premultiplied
    
    -- Draw rays at full opacity - we'll apply opacity when drawing the final composite
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw each ray as a line
    for i = 0, state.numRays - 1 do
        local angle = rotation + (i * (2 * math.pi / state.numRays))
        local endX = centerX + math.cos(angle) * state.rayLength
        local endY = centerY + math.sin(angle) * state.rayLength
        
        love.graphics.setLineWidth(state.rayWidth)
        love.graphics.line(centerX, centerY, endX, endY)
    end
    
    -- Step 2: Apply radial blur shader to create the main rays
    love.graphics.setCanvas(state.glowCanvas)  -- Store radially blurred result here
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(state.shader)
    
    -- Convert center to UV coordinates (0-1) for shader
    local centerUVX = centerX / Constants.SCREEN_WIDTH
    local centerUVY = centerY / Constants.SCREEN_HEIGHT
    
    -- Set shader parameters
    state.shader:send("center", {centerUVX, centerUVY})
    state.shader:send("blurStrength", state.blurStrength)
    state.shader:send("opacity", finalOpacity)
    state.shader:send("brightness", state.brightnessMultiplier)
    
    -- Draw the radially blurred rays to glowCanvas (this is our main rays)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.canvas, 0, 0)
    
    -- Save the radially blurred result to main canvas before applying glow blur
    love.graphics.setCanvas(state.canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader()  -- No shader, just copy
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.glowCanvas, 0, 0)  -- Copy radially blurred result
    
    -- Step 3: Apply Gaussian blur for glow effect (blur the saved radially blurred result)
    -- Horizontal blur pass - blur the saved result (which is in canvas)
    love.graphics.setCanvas(state.glowCanvas)  -- Use glowCanvas for horizontal blur result
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(state.glowShader)
    state.glowShader:send("radius", state.glowStrength)
    state.glowShader:send("direction", {1.0, 0.0})  -- Horizontal
    state.glowShader:send("textureSize", {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT})
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.canvas, 0, 0)  -- Blur the saved radially blurred result from canvas
    
    -- Vertical blur pass (blur the already horizontally blurred result)
    -- We need to blur glowCanvas (horizontal blur) vertically, but can't draw to itself
    -- Use a temp canvas to avoid overwriting the main rays in canvas
    local tempBlurCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, {format = "rgba8"})
    love.graphics.setCanvas(tempBlurCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader()  -- No shader, just copy
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.glowCanvas, 0, 0)  -- Copy horizontal blur to temp
    
    -- Now apply vertical blur from temp to glowCanvas
    love.graphics.setCanvas(state.glowCanvas)  -- Store final glow
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(state.glowShader)
    state.glowShader:send("direction", {0.0, 1.0})  -- Vertical
    -- radius and textureSize are already set
    love.graphics.draw(tempBlurCanvas, 0, 0)  -- Blur the horizontal blur result
    tempBlurCanvas:release()
    
    -- Note: canvas still has the main rays (saved at line 170), so we don't need to restore them
    
    -- Step 4: Composite everything onto a single canvas with black background
    -- At this point: canvas has main rays (radially blurred), glowCanvas has the glow (Gaussian blurred)
    -- We need to composite on black background so additive blend works correctly
    love.graphics.setCanvas(state.compositeCanvas)
    love.graphics.clear(0, 0, 0, 1)  -- Clear to black (opaque black background)
    love.graphics.setShader()  -- No shader
    
    -- Draw glow first (with alpha blend onto black background)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)  -- Full opacity
    love.graphics.draw(state.glowCanvas, 0, 0)
    
    -- Draw main rays on top (with additive blend to combine with glow)
    love.graphics.setBlendMode("add")  -- Additive to combine with glow
    love.graphics.setColor(1, 1, 1, 1)  -- Full opacity
    love.graphics.draw(state.canvas, 0, 0)
    
    -- Apply 12px Gaussian blur to the composite before drawing to screen
    -- Use canvas as temp for blur passes
    -- Horizontal blur pass
    love.graphics.setCanvas(state.canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(state.glowShader)
    state.glowShader:send("radius", 12.0)  -- 12px blur
    state.glowShader:send("direction", {1.0, 0.0})  -- Horizontal
    state.glowShader:send("textureSize", {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT})
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(state.compositeCanvas, 0, 0)
    
    -- Vertical blur pass
    love.graphics.setCanvas(state.compositeCanvas)
    love.graphics.clear(0, 0, 0, 1)  -- Clear to black again
    state.glowShader:send("direction", {0.0, 1.0})  -- Vertical
    -- radius and textureSize are already set
    love.graphics.draw(state.canvas, 0, 0)
    
    -- Step 5: Draw composite canvas to screen with additive blend and opacity control
    -- The composite has black background, so additive blend will work correctly
    love.graphics.setCanvas()  -- Draw to screen
    love.graphics.setShader()  -- No shader
    love.graphics.setBlendMode("add")  -- Additive blend for glow effect
    love.graphics.setColor(1, 1, 1, finalOpacity)  -- Control opacity here for fade in/out
    love.graphics.draw(state.compositeCanvas, 0, 0)
    
    -- Restore previous state
    love.graphics.setCanvas(oldCanvas)
    love.graphics.setShader(oldShader)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Register godray with z-depth system (draw on top of everything)
function Godray.registerLayer()
    DrawLayers.register(Constants.Z_DEPTH.GODRAY, function()
        Godray.draw()
    end, "Godray")
end

return Godray
