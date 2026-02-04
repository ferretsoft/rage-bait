-- src/core/top_banner.lua
-- Top banner system with engagement-based animations and game over/life lost drops

local Constants = require("src.constants")
local DrawLayers = require("src.core.draw_layers")
local Auditor = require("src.core.auditor")

local TopBanner = {}

-- Configuration: Enable/disable head layer cropping at y=160
-- Set to false to disable cropping
local ENABLE_HEAD_CROP = true
local HEAD_CROP_Y = 160  -- Y position where head layers end

-- Internal state
local state = {
    -- Images
    base = nil,
    vigilant = nil,
    activated = nil,
    dormant = nil,
    normalMap = nil,      -- Overlord head normal map for welding light
    normalMapBanner = nil, -- Full banner normal map
    weldingShader = nil,
    
    -- Animation state
    vigilantAlpha = 0,
    criticalEffects = false,
    blinkTimer = 0,
    animationState = "normal",  -- "normal", "dropping", "rising"
    animationTimer = 0,
    waitTimer = 0,
    hasDropped = false,
    yOffset = 0,
    velocity = 0,
    originalY = 0,
    above25Timer = 0,
    
    -- Game over/life lost state
    gameOverDrop = false,
    gameOverGreyFade = 0,
    gameOverBannerDropped = false,
    gameOverBannerStartY = 0,
    gameOverBannerTargetY = 0,
    gameOverRisingPhase = false,  -- True when moving up 600px first
    gameOverRisingTargetY = -600,  -- Target Y offset for rising phase (-600 = up 600px)
    gameOverCropDisabled = false,  -- Track if crop should be disabled
    gameOverDrawOnTop = false,  -- Track if banner should draw on top of everything
    reverseAnimationActive = false,  -- True when reversing animation before reset
    reverseAnimationSpeed = 2.0,  -- Double speed for reverse
    textAnimationStartY = nil,  -- Starting Y position for text animation (ray center)
    textAnimationActive = false,  -- Whether text Y animation is active
    lastGlitchSeed = nil,  -- Cache to avoid math.randomseed every frame (performance)
}

-- Load banner images
function TopBanner.load()
    -- Load base banner
    local success, img = pcall(love.graphics.newImage, "assets/OverlordTopBanner/Banner.png")
    if success then
        state.base = img
    else
        state.base = nil
        print("Warning: Could not load top banner: assets/OverlordTopBanner/Banner.png")
    end
    
    -- Load vigilant state layer
    local success2, img2 = pcall(love.graphics.newImage, "assets/OverlordTopBanner/Vigilant.png")
    if success2 then
        state.vigilant = img2
    else
        state.vigilant = nil
        print("Warning: Could not load vigilant banner: assets/OverlordTopBanner/Vigilant.png")
    end
    
    -- Load activated state layer
    local success3, img3 = pcall(love.graphics.newImage, "assets/OverlordTopBanner/Activated.png")
    if success3 then
        state.activated = img3
    else
        state.activated = nil
        print("Warning: Could not load activated banner: assets/OverlordTopBanner/Activated.png")
    end
    
    -- Load dormant state layer
    local success4, img4 = pcall(love.graphics.newImage, "assets/OverlordTopBanner/Dormant.png")
    if success4 then
        state.dormant = img4
    else
        state.dormant = nil
        print("Warning: Could not load dormant banner: assets/OverlordTopBanner/Dormant.png")
    end
    
    -- Load overlord head normal map and full banner normal map for welding light
    local success5, img5 = pcall(love.graphics.newImage, "assets/OverlordTopBanner/normalmapoverlord.png")
    if success5 then
        state.normalMap = img5
    else
        state.normalMap = nil
    end
    local success6, img6 = pcall(love.graphics.newImage, "assets/OverlordTopBanner/normalmapbanner.png")
    if success6 then
        state.normalMapBanner = img6
    else
        state.normalMapBanner = nil
    end
    local weldCode = love.filesystem.read("shaders/overlord_welding.fs")
    if weldCode then
        state.weldingShader = love.graphics.newShader(weldCode)
    else
        state.weldingShader = nil
    end
end

-- Trigger banner drop animation (used for both game over and life lost)
function TopBanner.triggerDrop(dropDistance)
    -- Reset any previous animation state
    state.reverseAnimationActive = false
    state.gameOverDrop = true
    state.gameOverGreyFade = 0
    state.gameOverBannerDropped = false
    state.gameOverBannerStartY = state.yOffset
    -- Increase drop distance by 300px
    state.gameOverBannerTargetY = state.yOffset + dropDistance + 300
    state.gameOverRisingPhase = true  -- Start with rising phase
    state.gameOverRisingTargetY = state.yOffset - 600  -- Move up 600px from current position
    state.gameOverCropDisabled = false  -- Don't disable crop yet (will change after rising)
    state.gameOverDrawOnTop = false  -- Don't draw on top yet (will change after rising)
    state.animationState = "rising"  -- Start with rising animation
    state.animationTimer = 0
    state.velocity = 0
    -- Ensure we're not stuck in reverse animation
    if state.yOffset < 0 then
        state.yOffset = 0  -- Reset to 0 if somehow negative
    end
end

-- Start reverse animation (runs drop animation in reverse at double speed)
function TopBanner.startReverseAnimation()
    state.reverseAnimationActive = true
    state.animationState = "reversing"
    state.velocity = 0
    -- Switch back to original draw order (draw before monitor frame)
    state.gameOverDrawOnTop = false
    -- Keep crop disabled during reverse so banner is visible while moving up
    state.gameOverCropDisabled = true
    -- Reset text animation state for reverse
    state.textAnimationStartY = nil
    state.textAnimationActive = false
    -- Will reverse from current dropped position back to original
end

-- Check if reverse animation is complete
function TopBanner.isReverseAnimationComplete()
    -- If reverse animation was never started, consider it complete
    if not state.reverseAnimationActive then
        return true
    end
    
    -- Reverse is complete when banner has returned to original position (yOffset <= 0) and animation state is normal
    return state.yOffset <= 0 and state.animationState == "normal"
end

-- Reset banner to original position
function TopBanner.reset()
    state.yOffset = 0
    state.velocity = 0
    state.animationState = "normal"
    state.gameOverDrop = false
    state.gameOverGreyFade = 0
    state.gameOverBannerDropped = false
    state.gameOverRisingPhase = false
    state.gameOverCropDisabled = false
    state.gameOverDrawOnTop = false
    state.reverseAnimationActive = false
    state.textAnimationStartY = nil
    state.textAnimationActive = false
end

-- Get game over grey fade value (for black overlay)
function TopBanner.getGameOverGreyFade()
    return state.gameOverGreyFade
end

-- Check if banner has finished dropping (for game over/life lost)
function TopBanner.isGameOverBannerDropped()
    return state.gameOverBannerDropped
end

-- Check if banner drop is active (for compatibility)
function TopBanner.isGameOverDropActive()
    return state.gameOverDrop
end

-- Check if banner should draw on top of everything (during game over/life lost)
function TopBanner.shouldDrawOnTop()
    return state.gameOverDrawOnTop
end

-- Get current z-depth for top banner
function TopBanner.getZDepth()
    if state.gameOverDrawOnTop then
        return Constants.Z_DEPTH.TOP_BANNER_ON_TOP
    else
        return Constants.Z_DEPTH.TOP_BANNER_NORMAL
    end
end

-- Register top banner with z-depth system
function TopBanner.registerLayer()
    local zDepth = TopBanner.getZDepth()
    DrawLayers.register(zDepth, function()
        TopBanner.draw()
    end, "TopBanner")
end

-- Update banner animation and state
function TopBanner.update(dt, gameState, engagementValue, gameOverActive, lifeLostAuditorActive)
    -- Update reverse animation (runs before reset)
    if state.reverseAnimationActive then
        -- Reverse the drop animation at double speed
        -- Move upward (negative velocity) to return to original position
        local upwardForce = -800 * state.reverseAnimationSpeed  -- Double speed upward force
        state.velocity = state.velocity + upwardForce * dt
        state.yOffset = state.yOffset + state.velocity * dt
        
        -- Also reverse the grey fade
        if state.gameOverGreyFade > 0 then
            state.gameOverGreyFade = math.max(0, state.gameOverGreyFade - dt * state.reverseAnimationSpeed)
        end
        
        -- Check if we've returned to original position
        if state.yOffset <= 0 then
            state.yOffset = 0
            state.velocity = 0
            state.animationState = "normal"
            -- Re-enable crop and normal drawing order
            state.gameOverCropDisabled = false
            state.gameOverDrawOnTop = false
            -- Mark reverse animation as complete (set to false so completion check works)
            state.reverseAnimationActive = false
        end
        return  -- Don't update other animations during reverse
    end
    
    -- Update game over/life lost drop animation
    if gameOverActive or lifeLostAuditorActive then
        if state.gameOverDrop then
            if state.gameOverRisingPhase then
                -- Phase 1: Move up 600px first (using same gravity/timing as drop)
                -- Use upward force (negative gravity) to move up
                local upwardForce = -800  -- pixels per second squared (negative = upward)
                state.velocity = state.velocity + upwardForce * dt  -- Negative velocity = upward
                state.yOffset = state.yOffset + state.velocity * dt
                
                -- Target: move up 600px from original position (negative offset)
                local targetOffset = state.gameOverRisingTargetY
                
                -- Check if we've reached target (moving up, so yOffset should be <= targetOffset)
                if state.yOffset <= targetOffset then
                    state.yOffset = targetOffset  -- Clamp to target
                    state.gameOverRisingPhase = false  -- Finished rising, now drop
                    state.animationState = "dropping"
                    state.velocity = 0  -- Reset velocity for drop phase
                end
            elseif state.animationState == "dropping" then
                -- Phase 2: Fall down with gravity (same as original drop animation)
                local gravity = 800  -- pixels per second squared
                state.velocity = state.velocity + gravity * dt
                state.yOffset = state.yOffset + state.velocity * dt
                
                -- Change drawing order when banner has moved down from top position
                -- Wait until banner has moved down at least 200px from the top (-600) to ensure it's fully out of frame
                if not state.gameOverDrawOnTop then
                    local topPosition = state.gameOverRisingTargetY  -- -600
                    local distanceFromTop = state.yOffset - topPosition  -- How far down from top
                    if distanceFromTop >= 200 then  -- Wait until banner has moved 200px down from top
                        state.gameOverCropDisabled = true  -- Disable crop
                        state.gameOverDrawOnTop = true  -- Draw on top of everything
                    end
                end
                
                -- Target: drop distance from starting position
                local targetOffset = state.gameOverBannerTargetY
                
                -- Add shake while dropping
                local shakeAmount = 3
                state.yOffset = state.yOffset + (math.random() - 0.5) * shakeAmount * dt * 10
                
                -- Check if we've reached target
                if state.yOffset >= targetOffset then
                    state.yOffset = targetOffset  -- Clamp to target
                    state.animationState = "normal"  -- Stay at dropped position
                    state.velocity = 0
                    state.gameOverBannerDropped = true
                end
            end
            
            -- Fade in black overlay (fade over 1 second)
            if state.gameOverGreyFade < 1.0 then
                state.gameOverGreyFade = math.min(1.0, state.gameOverGreyFade + dt)
            end
        end
                -- Still update vigilant alpha based on engagement during game over/life lost
        if gameState == "playing" or gameOverActive or lifeLostAuditorActive then
            if engagementValue and state.vigilant then
                local engagementPct = engagementValue / Constants.ENGAGEMENT_MAX
                -- Calculate alpha: 1.0 at 0% engagement, 0.0 at 100% engagement (inverted)
                -- Linear fade from 100% (alpha 0) to 0% (alpha 1)
                -- Inverted: lower engagement = higher opacity
                state.vigilantAlpha = 1.0 - engagementPct  -- 0 at 100%, 1 at 0%
                state.vigilantAlpha = math.max(0, math.min(1, state.vigilantAlpha))  -- Clamp to 0-1
                
                -- Check for critical state (at or below threshold) for additional effects
                state.criticalEffects = engagementPct <= Constants.TIMING.ENGAGEMENT_CRITICAL_THRESHOLD
            end
        end
        return  -- Don't update engagement-based animation during game over/life lost
    end
    
    -- Update engagement-based banner animation
    -- DISABLED: Top banner stays at original position until life lost or game over
    --[[
    if gameState == "playing" and engagementValue then
        local engagementPct = engagementValue / Constants.ENGAGEMENT_MAX
        
        if engagementPct <= Constants.TIMING.ENGAGEMENT_CRITICAL_THRESHOLD then
            -- Reset above 25% timer when engagement drops to 25% or below
            state.above25Timer = 0
            
            -- Update blink timer for flashing effect
            state.blinkTimer = state.blinkTimer + dt * 3  -- Fast blink (3x speed)
            
            -- Update banner animation
            state.animationTimer = state.animationTimer + dt
            
            -- Animation states
            if state.animationState == "normal" then
                -- Only allow dropping if engagement was above 25% for 6 seconds (reset flag)
                if not state.hasDropped then
                    -- First time hitting 25% - drop immediately (no wait)
                    state.animationState = "dropping"
                    state.animationTimer = 0
                    state.waitTimer = 0
                    state.velocity = 0
                    state.yOffset = 0
                    state.hasDropped = true
                else
                    -- Wait at original position for 15 seconds before checking again
                    state.waitTimer = state.waitTimer + dt
                    if state.waitTimer >= Constants.TIMING.BANNER_WAIT_AT_ORIGINAL then
                        -- 15 seconds passed, check engagement and drop if still at 25% or below
                        if engagementPct <= Constants.TIMING.ENGAGEMENT_CRITICAL_THRESHOLD then
                            state.animationState = "dropping"
                            state.animationTimer = 0
                            state.waitTimer = 0
                            state.velocity = 0
                            state.yOffset = 0
                        else
                            -- Engagement went above 25%, reset wait timer
                            state.waitTimer = 0
                        end
                    end
                end
            elseif state.animationState == "dropping" then
                -- Check if engagement went above 25% - if so, start rising immediately
                if engagementPct > Constants.TIMING.ENGAGEMENT_CRITICAL_THRESHOLD then
                    state.animationState = "rising"
                    state.animationTimer = 0
                    state.velocity = -150  -- Start rising slowly (negative = upward)
                else
                    -- Fall down to above center screen with gravity
                    local gravity = 800  -- pixels per second squared
                    state.velocity = state.velocity + gravity * dt
                    state.yOffset = state.yOffset + state.velocity * dt
                    
                    -- Target: stop at a reasonable distance down (about 330 pixels from original position)
                    local targetOffset = Constants.TIMING.BANNER_DROP_DISTANCE
                    
                    -- Add shake while dropping
                    local shakeAmount = 3
                    state.yOffset = state.yOffset + (math.random() - 0.5) * shakeAmount * dt * 10
                    
                    -- Check if we've reached target - stay at lower position
                    if state.yOffset >= targetOffset then
                        state.yOffset = targetOffset  -- Clamp to target
                        state.animationState = "normal"  -- Stay at lower position, don't rise yet
                        state.animationTimer = 0
                        state.velocity = 0
                    end
                end
            end
        else
            -- Engagement is above 25%
            -- Track how long engagement has been above 25%
            state.above25Timer = state.above25Timer + dt
            
            if state.animationState == "dropping" then
                -- If engagement went above 25% while dropping, stop dropping and stay at current position
                state.animationState = "normal"
                state.animationTimer = 0
                state.velocity = 0
            elseif state.animationState == "normal" and state.yOffset >= Constants.TIMING.BANNER_DROP_DISTANCE then
                -- Banner is at lower position - wait for required time above 25% before rising
                if state.above25Timer >= Constants.TIMING.BANNER_ABOVE_25_RESET_TIME then
                    -- 6 seconds passed, start rising
                    state.animationState = "rising"
                    state.animationTimer = 0
                    state.velocity = -150  -- Start rising slowly (negative = upward)
                end
            elseif state.animationState == "rising" then
                -- Rise back up slowly with upward force
                local upwardForce = -400  -- Negative = upward acceleration
                state.velocity = state.velocity + upwardForce * dt
                state.yOffset = state.yOffset + state.velocity * dt
                
                -- Check if we've returned to original position
                if state.yOffset <= 0 then
                    state.yOffset = 0
                    state.velocity = 0
                    state.animationState = "normal"  -- Stay at original position
                    state.animationTimer = 0
                    state.waitTimer = 0
                    state.hasDropped = false
                    state.blinkTimer = 0
                    state.above25Timer = 0  -- Reset timer
                end
            else
                -- Engagement is above 25% and banner is at normal position (YOffset = 0) - reset everything
                state.animationState = "normal"
                state.animationTimer = 0
                state.waitTimer = 0
                state.yOffset = 0
                state.velocity = 0
                state.blinkTimer = 0
                -- Only reset drop flag if engagement has been above 25% for required time
                if state.above25Timer >= Constants.TIMING.BANNER_ABOVE_25_RESET_TIME then
                    state.hasDropped = false
                    state.above25Timer = 0
                end
            end
        end
        
        -- Update vigilant alpha based on engagement (only when playing)
        if state.vigilant then
            -- Calculate alpha: 1.0 at 0% engagement, 0.0 at 100% engagement (inverted)
            -- Linear fade from 100% (alpha 0) to 0% (alpha 1)
            -- Inverted: lower engagement = higher opacity
            state.vigilantAlpha = 1.0 - engagementPct  -- 0 at 100%, 1 at 0%
            state.vigilantAlpha = math.max(0, math.min(1, state.vigilantAlpha))  -- Clamp to 0-1
            
            -- Check for critical state (at or below threshold) for additional effects
            state.criticalEffects = engagementPct <= Constants.TIMING.ENGAGEMENT_CRITICAL_THRESHOLD
        end
    end
    --]]  -- Disabled engagement-based animation
end

-- Draw the banner
function TopBanner.draw()
    if not state.base then return end
    
    local bannerX = 0  -- Start at left edge of screen
    local bannerWidth = Constants.SCREEN_WIDTH  -- Full screen width
    
    -- Scale banner to fill full screen width, maintaining aspect ratio
    local bannerImgWidth = state.base:getWidth()
    local bannerImgHeight = state.base:getHeight()
    local scaleX = bannerWidth / bannerImgWidth
    local scale = scaleX  -- Use same scale for Y to maintain aspect ratio
    
    -- Calculate actual height after scaling
    local scaledHeight = bannerImgHeight * scale
    
    -- Position banner to overlap ARAC window (frame starts at OFFSET_Y - borderWidth - titleBarHeight)
    -- Move it down so it overlaps the window frame
    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local borderWidth = Constants.UI.BORDER_WIDTH
    local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
    local baseBannerY = frameY - scaledHeight + Constants.UI.BANNER_OVERLAP_OFFSET
    
    -- Store original Y position on first draw
    if state.originalY == 0 then
        state.originalY = baseBannerY
    end
    
    -- Apply animation offset (only Y axis)
    local bannerY = baseBannerY + state.yOffset
    
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Optionally crop head layers at specified Y position
    -- Scissor is applied in screen space, so it crops the final scaled result
    -- Disable crop during game over/life lost
    if ENABLE_HEAD_CROP and not state.gameOverCropDisabled then
        local cropY = HEAD_CROP_Y
        local cropHeight = cropY - bannerY
        
        -- Set scissor to crop head layers (applied after scaling transformation)
        -- Only draw if banner starts above the crop line
        if bannerY < cropY then
            -- Calculate how much of the banner to show (from bannerY to cropY)
            local visibleHeight = math.min(cropHeight, scaledHeight)
            if visibleHeight > 0 then
                -- Scissor coordinates are in screen space, so this crops the scaled result
                love.graphics.setScissor(bannerX, bannerY, bannerWidth, visibleHeight)
            else
                love.graphics.setScissor()
                return
            end
        else
            -- Banner is entirely below crop line, don't draw head
            return
        end
    end
    
    -- Draw base banner (scissor crops this if ENABLE_HEAD_CROP is true)
    -- The scissor is applied after the scale transformation, so it crops the final scaled result
    love.graphics.draw(state.base, bannerX, bannerY, 0, scale, scale)
    
    -- Draw banner layers: Activated always on
    -- Activated state stays on forever
    if state.activated then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(state.activated, bannerX, bannerY, 0, scale, scale)
    end
    
    -- Dormant layer disabled
    
    -- Draw Vigilant layer on top of all banner layers with calculated alpha
    if state.vigilant and state.vigilantAlpha > 0 then
        -- Apply blinking effect when at 25% or below
        local blinkAlpha = state.vigilantAlpha
        if state.criticalEffects then
            -- Fast blinking: on/off every 0.2 seconds
            local blinkPhase = math.sin(state.blinkTimer * math.pi) * 0.5 + 0.5
            blinkAlpha = blinkAlpha * (0.3 + blinkPhase * 0.7)  -- Blink between 30% and 100% of base alpha
        end
        
        love.graphics.setColor(1, 1, 1, blinkAlpha)
        love.graphics.draw(state.vigilant, bannerX, bannerY, 0, scale, scale)
    end
    
    -- Green welding light when lose text is projected: banner then head on top (head uses head alpha)
    local showWelding = state.gameOverDrop and state.yOffset > 0 and not state.reverseAnimationActive
    if not state.weldingShader or not showWelding then
        -- skip
    else
        local oldShader = love.graphics.getShader()
        local oldBlend = love.graphics.getBlendMode()
        love.graphics.setShader(state.weldingShader)
        love.graphics.setBlendMode("add", "alphamultiply")
        local t = love.timer.getTime()
        state.weldingShader:send("time", t)
        -- Light from center below (Y down = below, no X = centered)
        state.weldingShader:send("lightDir", { 0, 1, 0.25 })
        state.weldingShader:send("lightColor", {0.22, 0.5, 0.28})
        state.weldingShader:send("intensity", 0.72)
        state.weldingShader:send("ambient", 0.0)
        state.weldingShader:send("baseWash", 0.0)
        state.weldingShader:send("specPower", 18.0)
        state.weldingShader:send("specStrength", 0.26)
        love.graphics.setColor(1, 1, 1, 1)
        -- 1) Banner normal map: light only where base has alpha, and exclude head (Vigilant) so head is not lit by banner map
        if state.normalMapBanner and state.base then
            state.weldingShader:send("maskTexture", state.base)
            state.weldingShader:send("excludeTexture", state.vigilant or state.base)
            state.weldingShader:send("useExclude", state.vigilant and 1 or 0)
            love.graphics.draw(state.normalMapBanner, bannerX, bannerY, 0, scale, scale)
        end
        -- 2) Head normal map: light only where Vigilant has alpha. Zero ambient so not washed out.
        if state.normalMap and state.vigilant then
            state.weldingShader:send("maskTexture", state.vigilant)
            state.weldingShader:send("excludeTexture", state.vigilant)
            state.weldingShader:send("useExclude", 0)
            state.weldingShader:send("ambient", 0.0)
            state.weldingShader:send("baseWash", 0.0)
            state.weldingShader:send("intensity", 0.88)
            state.weldingShader:send("specStrength", 0.26)
            local vW, vH = state.vigilant:getDimensions()
            local nW, nH = state.normalMap:getDimensions()
            local headSx = scale * vW / nW
            local headSy = scale * vH / nH
            love.graphics.draw(state.normalMap, bannerX, bannerY, 0, headSx, headSy)
        end
        love.graphics.setBlendMode(oldBlend)
        love.graphics.setShader(oldShader)
    end
    
    -- Reset scissor after drawing head layers (if it was enabled)
    if ENABLE_HEAD_CROP and not state.gameOverCropDisabled then
        love.graphics.setScissor()
    end
    
    -- Glow effect removed
    -- (Previously drew red glow around banner when at 25% or below)
    
    -- Reset color and line width
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Internal function to get vigilant center (used internally)
local function getVigilantCenter()
    if not state.vigilant or not state.base then
        return nil, nil
    end
    
    local bannerX = 0
    local bannerWidth = Constants.SCREEN_WIDTH
    local bannerImgWidth = state.base:getWidth()
    local bannerImgHeight = state.base:getHeight()
    local scaleX = bannerWidth / bannerImgWidth
    local scale = scaleX
    local scaledHeight = bannerImgHeight * scale
    
    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local borderWidth = Constants.UI.BORDER_WIDTH
    local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
    local baseBannerY = frameY - scaledHeight + Constants.UI.BANNER_OVERLAP_OFFSET
    local bannerY = baseBannerY + state.yOffset
    
    -- Center X is always screen center
    local centerX = Constants.SCREEN_WIDTH / 2
    
    -- Center Y is the center of the vigilant layer (which is drawn at the same position as base)
    -- The vigilant image center is at bannerY + (vigilantImageHeight * scale / 2)
    local vigilantImgHeight = state.vigilant:getHeight()
    local centerY = bannerY + (vigilantImgHeight * scale / 2)
    
    return centerX, centerY
end

-- Get the center position of the vigilant layer (for godray effect)
function TopBanner.getVigilantCenter()
    return getVigilantCenter()
end

-- Helper function to calculate banner position (used by both text drawing functions)
local function getBannerTextPosition()
    if not state.base then return nil, nil end
    
    local bannerWidth = Constants.SCREEN_WIDTH
    local bannerImgWidth = state.base:getWidth()
    local bannerImgHeight = state.base:getHeight()
    local scaleX = bannerWidth / bannerImgWidth
    local scale = scaleX
    local scaledHeight = bannerImgHeight * scale
    local titleBarHeight = 20
    local borderWidth = 3
    local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
    local baseBannerY = frameY - scaledHeight + 120
    local bannerY = baseBannerY + state.yOffset
    
    local targetTextY = bannerY + scaledHeight + 20
    local textX = Constants.SCREEN_WIDTH / 2  -- Center of screen
    
    -- For life lost text, animate from ray center to target position
    -- Only animate during drop phase, not during reverse (text is hidden during reverse anyway)
    if state.gameOverDrop and state.yOffset > 0 and not state.reverseAnimationActive and state.animationState ~= "reversing" then
        -- Get ray center Y position (vigilant center - 47)
        local centerX, centerY = getVigilantCenter()
        if centerY then
            local rayCenterY = centerY - 47
            
            -- Initialize animation start position on first frame text becomes visible
            if not state.textAnimationActive then
                state.textAnimationStartY = rayCenterY
                state.textAnimationActive = true
            end
            
            -- Calculate animation progress based on banner drop
            -- Start animating when yOffset > 0, complete when banner reaches lowest position
            local startOffset = 0  -- Animation starts when yOffset > 0
            local endOffset = state.gameOverBannerTargetY or (state.yOffset)  -- Complete at target position
            local currentProgress = 0
            
            if state.gameOverBannerDropped then
                -- Banner has reached lowest position, text should be at target
                currentProgress = 1.0
            else
                -- Interpolate based on current yOffset vs target
                if endOffset > startOffset then
                    currentProgress = math.min(1.0, (state.yOffset - startOffset) / (endOffset - startOffset))
                end
            end
            
            -- Interpolate from ray center Y to target text Y
            local animatedTextY = state.textAnimationStartY + (targetTextY - state.textAnimationStartY) * currentProgress
            return textX, animatedTextY
        end
    end
    
    -- Default: return target position (for game over or when not animating)
    return textX, targetTextY
end

-- Internal function to draw a single character with terminal text style (for name entry)
local function drawGlitchyTerminalChar(char, x, y, glitchTextTimer, terminalFont, alpha)
    if not terminalFont then return end
    
    love.graphics.setFont(terminalFont)
    
    -- Apply glitch corruption (3% chance). Reseed only when tick changes (performance).
    local glitchChars = {"█", "▓", "▒"}
    local displayChar = char
    local seed = math.floor(glitchTextTimer * 100)
    if state.lastGlitchSeed ~= seed then
        state.lastGlitchSeed = seed
        math.randomseed(seed)
    end
    if math.random() < 0.03 then
        displayChar = glitchChars[math.random(#glitchChars)]
    end
    
    -- Scaling effect (slight pulse)
    local baseScale = 1.0 + math.sin(glitchTextTimer * 4) * 0.05  -- Pulse between 0.95 and 1.05
    
    -- Get character width for centering
    local charWidth = terminalFont:getWidth(char)
    
    -- Draw character with scaling and pulsing
    love.graphics.push()
    love.graphics.translate(x + charWidth / 2, y)
    love.graphics.scale(baseScale, baseScale)
    love.graphics.translate(-charWidth / 2, 0)
    
    -- Main text with green terminal color, pulsing alpha
    love.graphics.setColor(0, 1, 0, alpha)  -- Green terminal text with pulsing alpha
    love.graphics.print(displayChar, 0, 0)
    
    -- Subtle red glitch overlay (much less frequent)
    if math.random() < 0.1 then
        love.graphics.setColor(1, 0, 0, alpha * 0.2)
        love.graphics.print(displayChar, 1, 1)
    end
    
    love.graphics.pop()
end

-- Internal function to draw glitchy terminal text
-- useWhite: optional, when true use white instead of green (avoids green flicker on fullscreen lose)
local function drawGlitchyTerminalText(text, x, y, fontSize, glitchTextTimer, glitchTextWriteProgress, terminalFont, useWhite)
    if not terminalFont then return end
    
    love.graphics.setFont(terminalFont)
    
    -- Calculate how many characters to show based on write progress
    local charsToShow = math.floor(glitchTextWriteProgress * #text)
    local displayText = text:sub(1, charsToShow)
    
    -- Subtle glitch: only corrupt 3% of characters. Reseed only when tick changes (performance).
    local glitchChars = {"█", "▓", "▒"}
    local seed = math.floor(glitchTextTimer * 100)
    if state.lastGlitchSeed ~= seed then
        state.lastGlitchSeed = seed
        math.randomseed(seed)
    end
    local corruptedParts = {}
    for i = 1, #displayText do
        local char = displayText:sub(i, i)
        if math.random() < 0.03 then
            corruptedParts[#corruptedParts + 1] = glitchChars[math.random(#glitchChars)]
        else
            corruptedParts[#corruptedParts + 1] = char
        end
    end
    local corruptedText = table.concat(corruptedParts)
    
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
    local textWidth = terminalFont:getWidth(corruptedText)
    local centerX = x - fullTextWidth / 2
    
    -- Draw text with scaling and pulsing
    love.graphics.push()
    love.graphics.translate(centerX + fullTextWidth / 2, y)
    love.graphics.scale(baseScale, baseScale)
    love.graphics.translate(-fullTextWidth / 2, 0)
    
    -- Main text: green terminal color, or white when useWhite (avoids fullscreen green flicker)
    if useWhite then
        love.graphics.setColor(1, 1, 1, alpha)
    else
        love.graphics.setColor(0, 1, 0, alpha)  -- Green terminal text with pulsing alpha
    end
    love.graphics.print(corruptedText, 0, 0)
    
    -- Subtle red glitch overlay (much less frequent)
    if math.random() < 0.1 then
        love.graphics.setColor(1, 0, 0, alpha * 0.2)
        love.graphics.print(corruptedText, 1, 1)
    end
    
    love.graphics.pop()
end

-- Draw terminal text for game over
-- Check if game over text should be visible (same logic as life lost text)
function TopBanner.isGameOverTextVisible(glitchTextTimer)
    if not state.gameOverDrop then return false end
    
    -- Only show text when banner has dropped past original position (yOffset > 0)
    if state.yOffset <= 0 then return false end
    
    -- Flicker off when reverse animation starts (don't show at all during reverse)
    if state.reverseAnimationActive then return false end
    
    -- Add flicker effect: rapid on/off flickering
    -- Use glitchTextTimer for flicker timing
    -- Flicker rate: 8 times per second (faster flicker)
    local flickerRate = 8
    local flickerTime = glitchTextTimer * flickerRate
    local flickerPhase = flickerTime % 1.0  -- 0 to 1 cycle
    -- Show for 60% of the cycle, off for 40% (more visible)
    return flickerPhase < 0.6
end

function TopBanner.drawGameOverText(glitchTextTimer, glitchTextWriteProgress, terminalFont, useWhite)
    if not TopBanner.isGameOverTextVisible(glitchTextTimer) then return end
    
    local textX, textY = getBannerTextPosition()
    if not textX then return end
    local text = Auditor.GAME_OVER_TEXT
    drawGlitchyTerminalText(text, textX, textY, 32, glitchTextTimer, glitchTextWriteProgress, terminalFont, useWhite)
end

-- Check if life lost text should be visible (for use by TextTrace)
function TopBanner.isLifeLostTextVisible(glitchTextTimer)
    if not state.gameOverDrop then return false end
    
    -- Only show text when banner has dropped past original position (yOffset > 0)
    if state.yOffset <= 0 then return false end
    
    -- Flicker off when reverse animation starts (don't show at all during reverse)
    if state.reverseAnimationActive then return false end
    
    -- Add flicker effect: rapid on/off flickering
    -- Use glitchTextTimer for flicker timing
    -- Flicker rate: 8 times per second (faster flicker)
    local flickerRate = 8
    local flickerTime = glitchTextTimer * flickerRate
    local flickerPhase = flickerTime % 1.0  -- 0 to 1 cycle
    -- Show for 60% of the cycle, off for 40% (more visible)
    return flickerPhase < 0.6
end

-- Check if name entry text should be visible (same logic as life lost text)
function TopBanner.isNameEntryTextVisible(glitchTextTimer)
    if not state.gameOverDrop then return false end
    
    -- Only show text when banner has dropped past original position (yOffset > 0)
    if state.yOffset <= 0 then return false end
    
    -- Flicker off when reverse animation starts (don't show at all during reverse)
    if state.reverseAnimationActive then return false end
    
    -- Add flicker effect: rapid on/off flickering
    -- Use glitchTextTimer for flicker timing
    -- Flicker rate: 8 times per second (faster flicker)
    local flickerRate = 8
    local flickerTime = glitchTextTimer * flickerRate
    local flickerPhase = flickerTime % 1.0  -- 0 to 1 cycle
    -- Show for 60% of the cycle, off for 40% (more visible)
    return flickerPhase < 0.6
end

-- Draw terminal text for life lost
function TopBanner.drawLifeLostText(glitchTextTimer, glitchTextWriteProgress, terminalFont, useWhite)
    if not TopBanner.isLifeLostTextVisible(glitchTextTimer) then return end
    
    local textX, textY = getBannerTextPosition()
    if not textX then return end
    local text = Auditor.LIFE_LOST_TEXT
    
    drawGlitchyTerminalText(text, textX, textY, 32, glitchTextTimer, glitchTextWriteProgress, terminalFont, useWhite)
end

-- Get text position for text trace (export the internal function)
function TopBanner.getTextPosition()
    return getBannerTextPosition()
end

-- Draw a single character with terminal text style (for name entry)
function TopBanner.drawGlitchyTerminalChar(char, x, y, glitchTextTimer, terminalFont, alpha)
    drawGlitchyTerminalChar(char, x, y, glitchTextTimer, terminalFont, alpha)
end

-- Draw glitchy terminal text (for name entry instruction text)
function TopBanner.drawGlitchyTerminalText(text, x, y, fontSize, glitchTextTimer, glitchTextWriteProgress, terminalFont)
    drawGlitchyTerminalText(text, x, y, fontSize, glitchTextTimer, glitchTextWriteProgress, terminalFont)
end

return TopBanner
