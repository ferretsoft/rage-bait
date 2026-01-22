-- src/core/top_banner.lua
-- Top banner system with engagement-based animations and game over/life lost drops

local Constants = require("src.constants")

local TopBanner = {}

-- Internal state
local state = {
    -- Images
    base = nil,
    vigilant = nil,
    activated = nil,
    dormant = nil,
    
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
}

-- Load banner images
function TopBanner.load()
    -- Load base banner
    local success, img = pcall(love.graphics.newImage, "assets/OverlordTopBanner/overlord_top_banner_0003_Banner.png")
    if success then
        state.base = img
    else
        state.base = nil
        print("Warning: Could not load top banner: assets/OverlordTopBanner/overlord_top_banner_0003_Banner.png")
    end
    
    -- Load vigilant state layer
    local success2, img2 = pcall(love.graphics.newImage, "assets/OverlordTopBanner/overlord_top_banner_0000_Vigilant.png")
    if success2 then
        state.vigilant = img2
    else
        state.vigilant = nil
        print("Warning: Could not load vigilant banner: assets/OverlordTopBanner/overlord_top_banner_0000_Vigilant.png")
    end
    
    -- Load activated state layer
    local success3, img3 = pcall(love.graphics.newImage, "assets/OverlordTopBanner/overlord_top_banner_0001_Activated.png")
    if success3 then
        state.activated = img3
    else
        state.activated = nil
        print("Warning: Could not load activated banner: assets/OverlordTopBanner/overlord_top_banner_0001_Activated.png")
    end
    
    -- Load dormant state layer
    local success4, img4 = pcall(love.graphics.newImage, "assets/OverlordTopBanner/overlord_top_banner_0002_Dormant.png")
    if success4 then
        state.dormant = img4
    else
        state.dormant = nil
        print("Warning: Could not load dormant banner: assets/OverlordTopBanner/overlord_top_banner_0002_Dormant.png")
    end
end

-- Trigger banner drop animation (used for both game over and life lost)
function TopBanner.triggerDrop(dropDistance)
    state.gameOverDrop = true
    state.gameOverGreyFade = 0
    state.gameOverBannerDropped = false
    state.gameOverBannerStartY = state.yOffset
    state.gameOverBannerTargetY = state.yOffset + dropDistance
    state.animationState = "dropping"
    state.animationTimer = 0
    state.velocity = 0
end

-- Reset banner to original position
function TopBanner.reset()
    state.yOffset = 0
    state.velocity = 0
    state.animationState = "normal"
    state.gameOverDrop = false
    state.gameOverGreyFade = 0
    state.gameOverBannerDropped = false
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

-- Update banner animation and state
function TopBanner.update(dt, gameState, engagementValue, gameOverActive, lifeLostAuditorActive)
    -- Update game over/life lost drop animation
    if gameOverActive or lifeLostAuditorActive then
        if state.gameOverDrop then
            if state.animationState == "dropping" then
                -- Fall down with gravity
                local gravity = 800  -- pixels per second squared
                state.velocity = state.velocity + gravity * dt
                state.yOffset = state.yOffset + state.velocity * dt
                
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
        return  -- Don't update engagement-based animation during game over/life lost
    end
    
    -- Update engagement-based banner animation
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
            -- Calculate alpha: 1.0 at vigilant threshold engagement, 0.0 at 100% engagement
            -- Linear fade from 100% (alpha 0) to vigilant threshold (alpha 1)
            local fadeRange = Constants.TIMING.ENGAGEMENT_VIGILANT_THRESHOLD  -- Fade over this range (from 100% to threshold)
            local fadeProgress = (1.0 - engagementPct) / fadeRange  -- 0 at 100%, 1 at 50%
            fadeProgress = math.max(0, math.min(1, fadeProgress))  -- Clamp to 0-1
            state.vigilantAlpha = fadeProgress
            
            -- Check for critical state (at or below threshold) for additional effects
            state.criticalEffects = engagementPct <= Constants.TIMING.ENGAGEMENT_CRITICAL_THRESHOLD
        end
    end
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
    
    -- Draw base banner
    love.graphics.draw(state.base, bannerX, bannerY, 0, scale, scale)
    
    -- Draw banner layers: Activated always on, Vigilant composites over with fade
    -- Activated state stays on forever
    if state.activated then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(state.activated, bannerX, bannerY, 0, scale, scale)
    end
    
    -- Draw Vigilant layer on top with calculated alpha
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
    
    -- Draw critical effects (glow) when at 25% or below
    if state.criticalEffects then
        -- Draw glow effect around banner
        local glowAlpha = 0.4 * (math.sin(state.blinkTimer * math.pi * 2) + 1) / 2
        love.graphics.setColor(1, 0.2, 0.2, glowAlpha)  -- Red glow
        love.graphics.setLineWidth(8)
        local glowRectX = bannerX - 10
        local glowRectY = bannerY - 10
        local glowRectW = Constants.SCREEN_WIDTH + 20
        local glowRectH = scaledHeight + 20
        love.graphics.rectangle("line", glowRectX, glowRectY, glowRectW, glowRectH)
        
        -- Draw multiple glow layers for intensity
        love.graphics.setLineWidth(4)
        love.graphics.setColor(1, 0.4, 0.4, glowAlpha * 0.6)
        love.graphics.rectangle("line", glowRectX + 5, glowRectY + 5, glowRectW - 10, glowRectH - 10)
    end
    
    -- Reset color and line width
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
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
    
    local textY = bannerY + scaledHeight + 20
    local textX = Constants.SCREEN_WIDTH / 2
    return textX, textY
end

-- Internal function to draw glitchy terminal text
local function drawGlitchyTerminalText(text, x, y, fontSize, glitchTextTimer, glitchTextWriteProgress, terminalFont)
    if not terminalFont then return end
    
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
    local textWidth = terminalFont:getWidth(corruptedText)
    local centerX = x - fullTextWidth / 2
    
    -- Draw text with scaling and pulsing
    love.graphics.push()
    love.graphics.translate(centerX + fullTextWidth / 2, y)
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
end

-- Draw terminal text for game over
function TopBanner.drawGameOverText(glitchTextTimer, glitchTextWriteProgress, terminalFont)
    if not state.gameOverDrop then return end
    local textX, textY = getBannerTextPosition()
    if not textX then return end
    local text = "YIELD NOT SATISFACTORY - LIQUIDATING ASSET"
    drawGlitchyTerminalText(text, textX, textY, 32, glitchTextTimer, glitchTextWriteProgress, terminalFont)
end

-- Draw terminal text for life lost
function TopBanner.drawLifeLostText(glitchTextTimer, glitchTextWriteProgress, terminalFont)
    if not state.gameOverDrop then return end
    local textX, textY = getBannerTextPosition()
    if not textX then return end
    local text = "LOW PERFORMANCE DETECTED - INITIALIZE REASSIGNMENT"
    drawGlitchyTerminalText(text, textX, textY, 32, glitchTextTimer, glitchTextWriteProgress, terminalFont)
end

return TopBanner
