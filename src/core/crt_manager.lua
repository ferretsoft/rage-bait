-- src/core/crt_manager.lua
-- CRT shader and fullscreen management

local Constants = require("src.constants")
local moonshine = require("libs.moonshine")
local crt = require("libs.crt")

local CRTManager = {}

-- Initialize CRT system
function CRTManager.init()
    -- Create CRT effect (moonshine.BASE is already set to "libs")
    local crtEffect = require("libs.crt")(moonshine)
    
    -- Configure CRT appearance parameters
    crtEffect.distortionFactor = {1.02, 1.02}  -- Barrel distortion/curvature
    crtEffect.feather = 0.02  -- Edge feathering/masking
    crtEffect.scaleFactor = 1  -- Overall scale
    crtEffect.scanlineIntensity = 0.3  -- Scanline visibility
    crtEffect.chromaIntensity = 0.0  -- Disabled to fix glow coverage issue
    crtEffect.screenSize = {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT}
    
    -- Create glow effect
    local glowEffect = require("libs.glow")(moonshine)
    glowEffect.min_luma = 0.65  -- Minimum brightness threshold
    glowEffect.strength = Constants.EFFECTS.GLOW_STRENGTH_NORMAL  -- Glow blur radius/intensity
    
    -- Create effect chain: glow first, then CRT
    Game.crtChain = moonshine.chain(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, glowEffect)
    Game.crtChain.next(crtEffect)
    
    Game.crtEnabled = false
    Game.glowEffect = glowEffect
    Game.crtEffect = crtEffect  -- Store for screen size updates
end

-- Toggle CRT effect
function CRTManager.toggle()
    if Game.crtChain then
        Game.crtEnabled = not Game.crtEnabled
    end
end

-- Resize CRT chain (for fullscreen)
function CRTManager.resize(width, height)
    if Game.crtChain then
        Game.crtChain.resize(width, height)
    end
end

-- Draw with CRT effect applied
function CRTManager.draw(drawFunc)
    if not drawFunc then return end
    
    local isFullscreen = love.window.getFullscreen()
    
    if Game.crtEnabled and Game.crtChain then
        if isFullscreen then
            -- Get fullscreen dimensions
            local windowWidth, windowHeight = love.graphics.getDimensions()
            
            -- Draw scene directly at fullscreen resolution (scaled) so glow processes full area
            -- The CRT chain is already resized to fullscreen, so it will process at fullscreen resolution
            love.graphics.setColor(1, 1, 1, 1)
            Game.crtChain.draw(function()
                love.graphics.setColor(1, 1, 1, 1)
                -- Apply scaling transformation inside the chain
                local scaleX = windowWidth / Constants.SCREEN_WIDTH
                local scaleY = windowHeight / Constants.SCREEN_HEIGHT
                love.graphics.push()
                love.graphics.scale(scaleX, scaleY)
                drawFunc()
                love.graphics.pop()
            end)
        else
            -- Windowed mode: normal CRT
            Game.crtChain.draw(drawFunc)
        end
    else
        -- CRT disabled: draw normally with scaling if fullscreen
        if isFullscreen then
            local windowWidth, windowHeight = love.graphics.getDimensions()
            local scaleX = windowWidth / Constants.SCREEN_WIDTH
            local scaleY = windowHeight / Constants.SCREEN_HEIGHT
            love.graphics.push()
            love.graphics.scale(scaleX, scaleY)
            drawFunc()
            love.graphics.pop()
        else
            drawFunc()
        end
    end
end

return CRTManager
