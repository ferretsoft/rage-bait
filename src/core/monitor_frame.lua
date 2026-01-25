-- src/core/monitor_frame.lua
-- Monitor frame that goes around the entire screen

local Constants = require("src.constants")
local DrawLayers = require("src.core.draw_layers")

local MonitorFrame = {}

-- Configuration: Enable/disable BottomCenterPanel crop at y=174
-- Set to false to disable cropping
local ENABLE_BOTTOM_CENTER_PANEL_CROP = true
local BOTTOM_CENTER_PANEL_CROP_Y = 174  -- Y position where BottomCenterPanel is cropped

-- Internal state
local state = {
    -- Frame images (loaded in back-to-front order for drawing)
    images = {
        mouthpiece = nil,
        eyeLid = nil,
        rightMidUnderPanel = nil,
        rightMidUnderPanelHighlights = nil,
        leftMidUnderPanel = nil,
        leftMidUnderPanelHighlights = nil,
        mainFrame = nil,
        bottomCenterPanel = nil,
        leftMidPanel = nil,
        rightMidPanel = nil,
        topPanel = nil,
    },
    -- Eyelid animation state
    eyelidAnimation = {
        active = false,
        timer = 0,
        duration = 0.5,  -- 0.5 seconds
        startY = 0,
        targetY = -50,  -- Move up 50 pixels
        currentY = 0,
    },
    -- BottomCenterPanel animation state
    bottomCenterPanelAnimation = {
        active = false,
        timer = 0,
        duration = 0.75,  -- 0.75 seconds
        startY = 0,
        targetY = 130,  -- Move down 130 pixels (100 + 30)
        currentY = 0,
        hasTriggered = false,  -- Track if animation has been triggered
    },
    -- Engagement-based panel animations (RightMidPanel, TopPanel, LeftMidPanel)
    -- At engagement 50: original position (offset = 0)
    -- At engagement 0: maximum offset (100px)
    -- At engagement > 50: no effect (offset = 0)
    engagementPanelAnimations = {
        rightMidPanelOffsetX = 0,  -- RightMidPanel moves right (positive X)
        topPanelOffsetY = 0,       -- TopPanel moves up (negative Y)
        leftMidPanelOffsetX = 0,   -- LeftMidPanel moves right (positive X)
    },
    reverseAnimationActive = false,  -- True when reversing engagement animations before reset
    panelsSetToMaximum = false,  -- Track if panels have been set to maximum (for game over)
    bottomCenterPanelReverseStarted = false,  -- Track if BottomCenterPanel reverse was explicitly started
}

-- Load all frame images
function MonitorFrame.load()
    -- Load images in back-to-front order (for drawing)
    -- Note: Filenames may have variations in capitalization/spacing
    
    -- 1. Mouthpiece (backmost)
    local success, img = pcall(love.graphics.newImage, "assets/monitorframe/mouthpiece.png")
    if success then
        state.images.mouthpiece = img
    else
        print("Warning: Could not load mouthpiece: assets/monitorframe/mouthpiece.png")
    end
    
    -- 2. EyeLid
    local success2, img2 = pcall(love.graphics.newImage, "assets/monitorframe/EyeLid.png")
    if success2 then
        state.images.eyeLid = img2
    else
        print("Warning: Could not load EyeLid: assets/monitorframe/EyeLid.png")
    end
    
    -- 3. RightMidUnderPanel
    local success3, img3 = pcall(love.graphics.newImage, "assets/monitorframe/RightMidUnderPanel.png")
    if success3 then
        state.images.rightMidUnderPanel = img3
    else
        print("Warning: Could not load RightMidUnderPanel: assets/monitorframe/RightMidUnderPanel.png")
    end
    
    -- 4. RightMidUnderPanel_Highlights
    local success4, img4 = pcall(love.graphics.newImage, "assets/monitorframe/RightMidUnderPanel_highlights.png")
    if success4 then
        state.images.rightMidUnderPanelHighlights = img4
    else
        print("Warning: Could not load RightMidUnderPanel_highlights: assets/monitorframe/RightMidUnderPanel_highlights.png")
    end
    
    -- 5. LeftMidUnderPanel
    local success5, img5 = pcall(love.graphics.newImage, "assets/monitorframe/LeftMidUnderPanel.png")
    if success5 then
        state.images.leftMidUnderPanel = img5
    else
        print("Warning: Could not load LeftMidUnderPanel: assets/monitorframe/LeftMidUnderPanel.png")
    end
    
    -- 6. LeftMidUnderPanel_highlights
    local success6, img6 = pcall(love.graphics.newImage, "assets/monitorframe/LeftMidUnderPanel_highlights.png")
    if success6 then
        state.images.leftMidUnderPanelHighlights = img6
    else
        print("Warning: Could not load LeftMidUnderPanel_highlights: assets/monitorframe/LeftMidUnderPanel_highlights.png")
    end
    
    -- 7. MainFrame
    local success7, img7 = pcall(love.graphics.newImage, "assets/monitorframe/MainFrame.png")
    if success7 then
        state.images.mainFrame = img7
    else
        print("Warning: Could not load MainFrame: assets/monitorframe/MainFrame.png")
    end
    
    -- 8. BottomCenterPanel
    local success8, img8 = pcall(love.graphics.newImage, "assets/monitorframe/BottomCenterPanel.png")
    if success8 then
        state.images.bottomCenterPanel = img8
    else
        print("Warning: Could not load BottomCenterPanel: assets/monitorframe/BottomCenterPanel.png")
    end
    
    -- 9. LeftMidPanel
    local success9, img9 = pcall(love.graphics.newImage, "assets/monitorframe/LeftMidPanel.png")
    if success9 then
        state.images.leftMidPanel = img9
    else
        print("Warning: Could not load LeftMidPanel: assets/monitorframe/LeftMidPanel.png")
    end
    
    -- 10. RightMidPanel
    local success10, img10 = pcall(love.graphics.newImage, "assets/monitorframe/RightMidPanel.png")
    if success10 then
        state.images.rightMidPanel = img10
    else
        print("Warning: Could not load RightMidPanel: assets/monitorframe/RightMidPanel.png")
    end
    
    -- 11. TopPanel (frontmost)
    local success11, img11 = pcall(love.graphics.newImage, "assets/monitorframe/TopPanel.png")
    if success11 then
        state.images.topPanel = img11
    else
        print("Warning: Could not load TopPanel: assets/monitorframe/TopPanel.png")
    end
end

-- Trigger eyelid animation (called when gameplay starts after "Go!" text)
function MonitorFrame.startEyelidAnimation()
    state.eyelidAnimation.active = true
    state.eyelidAnimation.timer = 0
    state.eyelidAnimation.currentY = state.eyelidAnimation.startY
end

-- Reset eyelid animation (called when starting a new game)
function MonitorFrame.resetEyelidAnimation()
    state.eyelidAnimation.active = false
    state.eyelidAnimation.timer = 0
    state.eyelidAnimation.currentY = 0
end

-- Trigger BottomCenterPanel animation (called when engagement hits 65)
function MonitorFrame.startBottomCenterPanelAnimation()
    if not state.bottomCenterPanelAnimation.hasTriggered then
        state.bottomCenterPanelAnimation.active = true
        state.bottomCenterPanelAnimation.timer = 0
        state.bottomCenterPanelAnimation.currentY = state.bottomCenterPanelAnimation.startY
        state.bottomCenterPanelAnimation.hasTriggered = true
    end
end

-- Reset BottomCenterPanel animation (called when starting a new game)
function MonitorFrame.resetBottomCenterPanelAnimation()
    state.bottomCenterPanelAnimation.active = false
    state.bottomCenterPanelAnimation.timer = 0
    state.bottomCenterPanelAnimation.currentY = 0
    state.bottomCenterPanelAnimation.hasTriggered = false
end

-- Instantly set engagement panel animations to maximum (called when banner hits down position)
function MonitorFrame.setEngagementPanelsToMaximum()
    if not state.panelsSetToMaximum then
        state.engagementPanelAnimations.rightMidPanelOffsetX = 100  -- RightMidPanel moves right (max)
        state.engagementPanelAnimations.topPanelOffsetY = -100      -- TopPanel moves up (max)
        state.engagementPanelAnimations.leftMidPanelOffsetX = -100  -- LeftMidPanel moves left (max)
        state.panelsSetToMaximum = true
    end
end

-- Start reverse animation (engagement-driven panels, BottomCenterPanel, and Eyelid reverse)
function MonitorFrame.startReverseAnimation()
    state.reverseAnimationActive = true
    -- Start reversing BottomCenterPanel animation
    if state.bottomCenterPanelAnimation.hasTriggered then
        state.bottomCenterPanelAnimation.active = true
        state.bottomCenterPanelAnimation.timer = 0
        state.bottomCenterPanelReverseStarted = true  -- Mark that reverse was explicitly started
        -- Reverse: animate from current position back to startY (0)
    end
    -- Start reversing Eyelid animation (if it has moved up)
    if state.eyelidAnimation.currentY < 0 then
        state.eyelidAnimation.active = true
        state.eyelidAnimation.timer = 0
        -- Reverse: animate from current position (targetY = -50) back to startY (0)
    end
end

-- Check if reverse animation is complete
function MonitorFrame.isReverseAnimationComplete()
    -- If reverse animation was never started, consider it complete
    if not state.reverseAnimationActive then
        return true
    end
    
    -- Reverse is complete when all engagement-driven offsets are back to 0
    -- BottomCenterPanel is back to startY (0)
    -- and Eyelid is back to startY (0)
    local engagementComplete = 
           math.abs(state.engagementPanelAnimations.rightMidPanelOffsetX) < 0.1 and
           math.abs(state.engagementPanelAnimations.topPanelOffsetY) < 0.1 and
           math.abs(state.engagementPanelAnimations.leftMidPanelOffsetX) < 0.1
    
    local bottomCenterPanelComplete = true
    if state.bottomCenterPanelAnimation.hasTriggered and state.bottomCenterPanelReverseStarted then
        bottomCenterPanelComplete = math.abs(state.bottomCenterPanelAnimation.currentY) < 0.1
    end
    
    local eyelidComplete = true
    -- Check if eyelid needs to reverse (was moved up, currentY < 0)
    if state.eyelidAnimation.currentY < 0 then
        eyelidComplete = math.abs(state.eyelidAnimation.currentY) < 0.1
    end
    
    local allComplete = engagementComplete and bottomCenterPanelComplete and eyelidComplete
    
    -- If all animations are complete, mark reverse as done
    if allComplete then
        state.reverseAnimationActive = false
    end
    
    return allComplete
end

-- Reset all animations (for new game)
function MonitorFrame.resetAnimations()
    state.eyelidAnimation.active = false
    state.eyelidAnimation.timer = 0
    state.eyelidAnimation.currentY = 0

    state.bottomCenterPanelAnimation.active = false
    state.bottomCenterPanelAnimation.timer = 0
    state.bottomCenterPanelAnimation.currentY = 0
    state.bottomCenterPanelAnimation.hasTriggered = false
    
    state.engagementPanelAnimations.rightMidPanelOffsetX = 0
    state.engagementPanelAnimations.topPanelOffsetY = 0
    state.engagementPanelAnimations.leftMidPanelOffsetX = 0
    state.reverseAnimationActive = false
    state.panelsSetToMaximum = false
    state.bottomCenterPanelReverseStarted = false
end

-- Update engagement-based panel animations
-- Called with current engagement value and dt for reverse animation
function MonitorFrame.updateEngagementAnimations(engagementValue, dt)
    dt = dt or 0
    
    -- If panels are set to maximum (during game over), don't update based on engagement
    if state.panelsSetToMaximum and not state.reverseAnimationActive then
        return
    end
    
    -- If reverse animation is active, animate back to 0 at double speed
    if state.reverseAnimationActive then
        local reverseSpeed = 2.0  -- Double speed
        local maxOffset = 100  -- Maximum offset value
        local targetOffset = 0
        
        -- Animate rightMidPanel back to 0 (was positive, move left)
        if state.engagementPanelAnimations.rightMidPanelOffsetX > targetOffset then
            state.engagementPanelAnimations.rightMidPanelOffsetX = math.max(targetOffset, 
                state.engagementPanelAnimations.rightMidPanelOffsetX - maxOffset * reverseSpeed * dt)
        else
            state.engagementPanelAnimations.rightMidPanelOffsetX = targetOffset
        end
        
        -- Animate topPanel back to 0 (was negative, move down)
        if state.engagementPanelAnimations.topPanelOffsetY < targetOffset then
            state.engagementPanelAnimations.topPanelOffsetY = math.min(targetOffset,
                state.engagementPanelAnimations.topPanelOffsetY + maxOffset * reverseSpeed * dt)
        else
            state.engagementPanelAnimations.topPanelOffsetY = targetOffset
        end
        
        -- Animate leftMidPanel back to 0 (was negative, move right)
        if state.engagementPanelAnimations.leftMidPanelOffsetX < targetOffset then
            state.engagementPanelAnimations.leftMidPanelOffsetX = math.min(targetOffset,
                state.engagementPanelAnimations.leftMidPanelOffsetX + maxOffset * reverseSpeed * dt)
        else
            state.engagementPanelAnimations.leftMidPanelOffsetX = targetOffset
        end
        
        -- Don't set reverseAnimationActive = false here - let isReverseAnimationComplete() 
        -- check all conditions (engagement panels, BottomCenterPanel, Eyelid) before marking complete
        -- The completion check will handle setting it to false when everything is done
        return
    end
    
    -- Normal engagement-based animation
    -- Engagement threshold: 50 is original position, 0 is maximum offset (100px)
    -- Formula: offset = (50 - engagement) / 50 * 100
    -- Clamp engagement to 0-50 range for calculation
    local clampedEngagement = math.max(0, math.min(50, engagementValue))
    
    -- Calculate offset (0 at engagement 50, 100 at engagement 0)
    local offset = (50 - clampedEngagement) / 50 * 100
    
    -- Apply offsets to panels
    state.engagementPanelAnimations.rightMidPanelOffsetX = offset  -- RightMidPanel moves right
    state.engagementPanelAnimations.topPanelOffsetY = -offset       -- TopPanel moves up (negative)
    state.engagementPanelAnimations.leftMidPanelOffsetX = -offset  -- LeftMidPanel moves left (opposite direction)
end

-- Update animations
function MonitorFrame.update(dt)
    -- Update eyelid animation (check reverse first, even if not active)
    if state.reverseAnimationActive and state.eyelidAnimation.currentY < 0 then
        -- Reverse animation: animate back to startY (0) at double speed
        if not state.eyelidAnimation.active then
            -- Reactivate if needed
            state.eyelidAnimation.active = true
            state.eyelidAnimation.timer = 0
        end
        
        local reverseSpeed = 2.0  -- Double speed
        local reverseDuration = state.eyelidAnimation.duration / reverseSpeed
        state.eyelidAnimation.timer = state.eyelidAnimation.timer + dt
        
        if state.eyelidAnimation.timer >= reverseDuration then
            -- Reverse animation complete
            state.eyelidAnimation.timer = reverseDuration
            state.eyelidAnimation.currentY = state.eyelidAnimation.startY
            state.eyelidAnimation.active = false
        else
            -- Interpolate from targetY back to startY
            local progress = state.eyelidAnimation.timer / reverseDuration
            -- Use ease-out for smooth animation
            progress = 1 - math.pow(1 - progress, 3)
            state.eyelidAnimation.currentY = state.eyelidAnimation.targetY - 
                (state.eyelidAnimation.targetY - state.eyelidAnimation.startY) * progress
        end
    elseif state.eyelidAnimation.active then
        -- Normal forward animation
        state.eyelidAnimation.timer = state.eyelidAnimation.timer + dt
        
        if state.eyelidAnimation.timer >= state.eyelidAnimation.duration then
            -- Animation complete
            state.eyelidAnimation.timer = state.eyelidAnimation.duration
            state.eyelidAnimation.currentY = state.eyelidAnimation.targetY
            state.eyelidAnimation.active = false
        else
            -- Interpolate from startY to targetY
            local progress = state.eyelidAnimation.timer / state.eyelidAnimation.duration
            -- Use ease-out for smooth animation
            progress = 1 - math.pow(1 - progress, 3)
            state.eyelidAnimation.currentY = state.eyelidAnimation.startY + 
                (state.eyelidAnimation.targetY - state.eyelidAnimation.startY) * progress
        end
    end
    
    -- Update BottomCenterPanel animation (check reverse first, even if not active)
    if state.reverseAnimationActive and state.bottomCenterPanelReverseStarted and state.bottomCenterPanelAnimation.hasTriggered then
        -- Reverse animation: animate back to startY (0) at double speed
        if not state.bottomCenterPanelAnimation.active then
            -- Reactivate if needed
            state.bottomCenterPanelAnimation.active = true
            state.bottomCenterPanelAnimation.timer = 0
        end
        
        local reverseSpeed = 2.0  -- Double speed
        local reverseDuration = state.bottomCenterPanelAnimation.duration / reverseSpeed
        state.bottomCenterPanelAnimation.timer = state.bottomCenterPanelAnimation.timer + dt
        
        if state.bottomCenterPanelAnimation.timer >= reverseDuration then
            -- Reverse animation complete
            state.bottomCenterPanelAnimation.timer = reverseDuration
            state.bottomCenterPanelAnimation.currentY = state.bottomCenterPanelAnimation.startY
            state.bottomCenterPanelAnimation.active = false
            -- Mark reverse as complete for BottomCenterPanel
            state.bottomCenterPanelReverseStarted = false
        else
            -- Interpolate from targetY back to startY
            local progress = state.bottomCenterPanelAnimation.timer / reverseDuration
            -- Use ease-out for smooth animation
            progress = 1 - math.pow(1 - progress, 3)
            state.bottomCenterPanelAnimation.currentY = state.bottomCenterPanelAnimation.targetY - 
                (state.bottomCenterPanelAnimation.targetY - state.bottomCenterPanelAnimation.startY) * progress
        end
    elseif state.bottomCenterPanelAnimation.active then
        -- Normal forward animation
        state.bottomCenterPanelAnimation.timer = state.bottomCenterPanelAnimation.timer + dt
        
        if state.bottomCenterPanelAnimation.timer >= state.bottomCenterPanelAnimation.duration then
            -- Animation complete
            state.bottomCenterPanelAnimation.timer = state.bottomCenterPanelAnimation.duration
            state.bottomCenterPanelAnimation.currentY = state.bottomCenterPanelAnimation.targetY
            state.bottomCenterPanelAnimation.active = false
        else
            -- Interpolate from startY to targetY
            local progress = state.bottomCenterPanelAnimation.timer / state.bottomCenterPanelAnimation.duration
            -- Use ease-out for smooth animation
            progress = 1 - math.pow(1 - progress, 3)
            state.bottomCenterPanelAnimation.currentY = state.bottomCenterPanelAnimation.startY + 
                (state.bottomCenterPanelAnimation.targetY - state.bottomCenterPanelAnimation.startY) * progress
        end
    end
end

-- Internal helper: Draw a single layer
local function drawLayer(layerName)
    local frameX = 0
    local frameY = 0
    love.graphics.setColor(1, 1, 1, 1)
    
    if layerName == "mouthpiece" and state.images.mouthpiece then
        love.graphics.draw(state.images.mouthpiece, frameX, frameY)
    elseif layerName == "eyelid" and state.images.eyeLid then
        local eyelidY = frameY + state.eyelidAnimation.currentY
        love.graphics.draw(state.images.eyeLid, frameX, eyelidY)
    elseif layerName == "rightMidUnderPanel" and state.images.rightMidUnderPanel then
        love.graphics.draw(state.images.rightMidUnderPanel, frameX, frameY)
    elseif layerName == "rightMidUnderPanelHighlights" and state.images.rightMidUnderPanelHighlights then
        love.graphics.draw(state.images.rightMidUnderPanelHighlights, frameX, frameY)
    elseif layerName == "leftMidUnderPanel" and state.images.leftMidUnderPanel then
        love.graphics.draw(state.images.leftMidUnderPanel, frameX, frameY)
    elseif layerName == "leftMidUnderPanelHighlights" and state.images.leftMidUnderPanelHighlights then
        love.graphics.draw(state.images.leftMidUnderPanelHighlights, frameX, frameY)
    elseif layerName == "mainFrame" and state.images.mainFrame then
        love.graphics.draw(state.images.mainFrame, frameX, frameY)
    elseif layerName == "bottomCenterPanel" and state.images.bottomCenterPanel then
        local bottomCenterPanelY = frameY + state.bottomCenterPanelAnimation.currentY
        
        -- Apply crop if enabled
        if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
            local cropY = BOTTOM_CENTER_PANEL_CROP_Y
            if bottomCenterPanelY < cropY then
                local cropHeight = cropY - bottomCenterPanelY
                if cropHeight > 0 then
                    love.graphics.setScissor(frameX, bottomCenterPanelY, Constants.SCREEN_WIDTH, cropHeight)
                else
                    love.graphics.setScissor()
                    return
                end
            else
                love.graphics.setScissor()
                return
            end
        end
        
        love.graphics.draw(state.images.bottomCenterPanel, frameX, bottomCenterPanelY)
        
        if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
            love.graphics.setScissor()
        end
    elseif layerName == "leftMidPanel" and state.images.leftMidPanel then
        local leftMidPanelX = frameX + state.engagementPanelAnimations.leftMidPanelOffsetX
        love.graphics.draw(state.images.leftMidPanel, leftMidPanelX, frameY)
    elseif layerName == "rightMidPanel" and state.images.rightMidPanel then
        local rightMidPanelX = frameX + state.engagementPanelAnimations.rightMidPanelOffsetX
        love.graphics.draw(state.images.rightMidPanel, rightMidPanelX, frameY)
    elseif layerName == "topPanel" and state.images.topPanel then
        local topPanelY = frameY + state.engagementPanelAnimations.topPanelOffsetY
        love.graphics.draw(state.images.topPanel, frameX, topPanelY)
    end
end

-- Register all monitor frame layers with z-depths
function MonitorFrame.registerLayers()
    local frameX = 0
    local frameY = 0
    
    -- 1. Mouthpiece (backmost)
    if state.images.mouthpiece then
        DrawLayers.register(Constants.Z_DEPTH.MOUTHPIECE, function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(state.images.mouthpiece, frameX, frameY)
        end, "Mouthpiece")
    end
    
    -- 2. EyeLid - position depends on reverse animation
    if state.images.eyeLid then
        if state.reverseAnimationActive then
            -- During reverse: draw just under MainFrame
            DrawLayers.register(Constants.Z_DEPTH.EYELID_REVERSE, function()
                love.graphics.setColor(1, 1, 1, 1)
                local eyelidY = frameY + state.eyelidAnimation.currentY
                love.graphics.draw(state.images.eyeLid, frameX, eyelidY)
            end, "EyeLid (reverse)")
        else
            -- Normal: draw in original position
            DrawLayers.register(Constants.Z_DEPTH.EYELID_NORMAL, function()
                love.graphics.setColor(1, 1, 1, 1)
                local eyelidY = frameY + state.eyelidAnimation.currentY
                love.graphics.draw(state.images.eyeLid, frameX, eyelidY)
            end, "EyeLid (normal)")
        end
    end
    
    -- 3. RightMidUnderPanel
    if state.images.rightMidUnderPanel then
        DrawLayers.register(Constants.Z_DEPTH.RIGHT_MID_UNDER_PANEL, function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(state.images.rightMidUnderPanel, frameX, frameY)
        end, "RightMidUnderPanel")
    end
    
    -- 4. RightMidUnderPanel_Highlights
    if state.images.rightMidUnderPanelHighlights then
        DrawLayers.register(Constants.Z_DEPTH.RIGHT_MID_UNDER_PANEL_HIGHLIGHTS, function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(state.images.rightMidUnderPanelHighlights, frameX, frameY)
        end, "RightMidUnderPanel_Highlights")
    end
    
    -- 5. LeftMidUnderPanel
    if state.images.leftMidUnderPanel then
        DrawLayers.register(Constants.Z_DEPTH.LEFT_MID_UNDER_PANEL, function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(state.images.leftMidUnderPanel, frameX, frameY)
        end, "LeftMidUnderPanel")
    end
    
    -- 6. LeftMidUnderPanel_highlights
    if state.images.leftMidUnderPanelHighlights then
        DrawLayers.register(Constants.Z_DEPTH.LEFT_MID_UNDER_PANEL_HIGHLIGHTS, function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(state.images.leftMidUnderPanelHighlights, frameX, frameY)
        end, "LeftMidUnderPanel_highlights")
    end
    
    -- 7. MainFrame
    if state.images.mainFrame then
        DrawLayers.register(Constants.Z_DEPTH.MAIN_FRAME, function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(state.images.mainFrame, frameX, frameY)
        end, "MainFrame")
    end
    
    -- 8. BottomCenterPanel - position depends on reverse animation
    if state.images.bottomCenterPanel then
        if state.reverseAnimationActive then
            -- During reverse: draw just under MainFrame
            DrawLayers.register(Constants.Z_DEPTH.BOTTOM_CENTER_PANEL_REVERSE, function()
                love.graphics.setColor(1, 1, 1, 1)
                local bottomCenterPanelY = frameY + state.bottomCenterPanelAnimation.currentY
                
                -- Apply crop if enabled
                if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
                    local cropY = BOTTOM_CENTER_PANEL_CROP_Y
                    if bottomCenterPanelY < cropY then
                        local cropHeight = cropY - bottomCenterPanelY
                        if cropHeight > 0 then
                            love.graphics.setScissor(frameX, bottomCenterPanelY, Constants.SCREEN_WIDTH, cropHeight)
                        else
                            love.graphics.setScissor()
                            return
                        end
                    else
                        love.graphics.setScissor()
                        return
                    end
                end
                
                love.graphics.draw(state.images.bottomCenterPanel, frameX, bottomCenterPanelY)
                
                if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
                    love.graphics.setScissor()
                end
            end, "BottomCenterPanel (reverse)")
        else
            -- Normal: draw in original position
            DrawLayers.register(Constants.Z_DEPTH.BOTTOM_CENTER_PANEL_NORMAL, function()
                love.graphics.setColor(1, 1, 1, 1)
                local bottomCenterPanelY = frameY + state.bottomCenterPanelAnimation.currentY
                
                -- Apply crop if enabled
                if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
                    local cropY = BOTTOM_CENTER_PANEL_CROP_Y
                    if bottomCenterPanelY < cropY then
                        local cropHeight = cropY - bottomCenterPanelY
                        if cropHeight > 0 then
                            love.graphics.setScissor(frameX, bottomCenterPanelY, Constants.SCREEN_WIDTH, cropHeight)
                        else
                            love.graphics.setScissor()
                            return
                        end
                    else
                        love.graphics.setScissor()
                        return
                    end
                end
                
                love.graphics.draw(state.images.bottomCenterPanel, frameX, bottomCenterPanelY)
                
                if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
                    love.graphics.setScissor()
                end
            end, "BottomCenterPanel (normal)")
        end
    end
    
    -- 9. LeftMidPanel
    if state.images.leftMidPanel then
        DrawLayers.register(Constants.Z_DEPTH.LEFT_MID_PANEL, function()
            love.graphics.setColor(1, 1, 1, 1)
            local leftMidPanelX = frameX + state.engagementPanelAnimations.leftMidPanelOffsetX
            love.graphics.draw(state.images.leftMidPanel, leftMidPanelX, frameY)
        end, "LeftMidPanel")
    end
    
    -- 10. RightMidPanel
    if state.images.rightMidPanel then
        DrawLayers.register(Constants.Z_DEPTH.RIGHT_MID_PANEL, function()
            love.graphics.setColor(1, 1, 1, 1)
            local rightMidPanelX = frameX + state.engagementPanelAnimations.rightMidPanelOffsetX
            love.graphics.draw(state.images.rightMidPanel, rightMidPanelX, frameY)
        end, "RightMidPanel")
    end
    
    -- 11. TopPanel
    if state.images.topPanel then
        DrawLayers.register(Constants.Z_DEPTH.TOP_PANEL, function()
            love.graphics.setColor(1, 1, 1, 1)
            local topPanelY = frameY + state.engagementPanelAnimations.topPanelOffsetY
            love.graphics.draw(state.images.topPanel, frameX, topPanelY)
        end, "TopPanel")
    end
end

-- Draw the monitor frame (covers entire screen) - kept for backward compatibility
function MonitorFrame.draw()
    -- This function is now a wrapper that registers layers and draws them
    -- But for now, keep the old implementation for compatibility
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw all layers in back-to-front order
    -- Position at (0, 0) to cover entire screen
    local frameX = 0
    local frameY = 0
    
    -- 1. Mouthpiece (backmost)
    if state.images.mouthpiece then
        love.graphics.draw(state.images.mouthpiece, frameX, frameY)
    end
    
    -- 2. EyeLid (with animation offset) - only draw here if NOT in reverse animation
    if not state.reverseAnimationActive then
        if state.images.eyeLid then
            local eyelidY = frameY + state.eyelidAnimation.currentY
            love.graphics.draw(state.images.eyeLid, frameX, eyelidY)
        end
    end
    
    -- 3. RightMidUnderPanel
    if state.images.rightMidUnderPanel then
        love.graphics.draw(state.images.rightMidUnderPanel, frameX, frameY)
    end
    
    -- 4. RightMidUnderPanel_Highlights
    if state.images.rightMidUnderPanelHighlights then
        love.graphics.draw(state.images.rightMidUnderPanelHighlights, frameX, frameY)
    end
    
    -- 5. LeftMidUnderPanel
    if state.images.leftMidUnderPanel then
        love.graphics.draw(state.images.leftMidUnderPanel, frameX, frameY)
    end
    
    -- 6. LeftMidUnderPanel_highlights
    if state.images.leftMidUnderPanelHighlights then
        love.graphics.draw(state.images.leftMidUnderPanelHighlights, frameX, frameY)
    end
    
    -- 7. MainFrame
    if state.images.mainFrame then
        love.graphics.draw(state.images.mainFrame, frameX, frameY)
    end
    
    -- During reverse animation: draw BottomCenterPanel and EyeLid just under MainFrame
    if state.reverseAnimationActive then
        -- 7a. BottomCenterPanel (with animation and crop) - moved here during reverse
        if state.images.bottomCenterPanel then
            local bottomCenterPanelY = frameY + state.bottomCenterPanelAnimation.currentY
            
            -- Apply crop if enabled (after animation has been triggered)
            -- Crop at y=174 means show only from bottomCenterPanelY to y=174
            -- Crop is applied during and after animation
            if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
                local cropY = BOTTOM_CENTER_PANEL_CROP_Y
                
                -- Only crop if BottomCenterPanel is above or at crop line
                if bottomCenterPanelY < cropY then
                    local cropHeight = cropY - bottomCenterPanelY
                    if cropHeight > 0 then
                        -- Scissor coordinates are in screen space, so this crops the final result
                        love.graphics.setScissor(frameX, bottomCenterPanelY, Constants.SCREEN_WIDTH, cropHeight)
                    else
                        love.graphics.setScissor()
                        return  -- BottomCenterPanel is at or below crop line, don't draw
                    end
                else
                    love.graphics.setScissor()
                    return  -- BottomCenterPanel is entirely below crop line, don't draw
                end
            end
            
            love.graphics.draw(state.images.bottomCenterPanel, frameX, bottomCenterPanelY)
            
            -- Reset scissor after drawing BottomCenterPanel (if it was enabled)
            if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
                love.graphics.setScissor()
            end
        end
        
        -- 7b. EyeLid (with animation offset) - moved here during reverse
        if state.images.eyeLid then
            local eyelidY = frameY + state.eyelidAnimation.currentY
            love.graphics.draw(state.images.eyeLid, frameX, eyelidY)
        end
    end
    
    -- 8. BottomCenterPanel (with animation and crop) - only draw here if NOT in reverse animation
    if not state.reverseAnimationActive then
        if state.images.bottomCenterPanel then
            local bottomCenterPanelY = frameY + state.bottomCenterPanelAnimation.currentY
            
            -- Apply crop if enabled (after animation has been triggered)
            -- Crop at y=174 means show only from bottomCenterPanelY to y=174
            -- Crop is applied during and after animation
            if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
                local cropY = BOTTOM_CENTER_PANEL_CROP_Y
                
                -- Only crop if BottomCenterPanel is above or at crop line
                if bottomCenterPanelY < cropY then
                    local cropHeight = cropY - bottomCenterPanelY
                    if cropHeight > 0 then
                        -- Scissor coordinates are in screen space, so this crops the final result
                        love.graphics.setScissor(frameX, bottomCenterPanelY, Constants.SCREEN_WIDTH, cropHeight)
                    else
                        love.graphics.setScissor()
                        return  -- BottomCenterPanel is at or below crop line, don't draw
                    end
                else
                    love.graphics.setScissor()
                    return  -- BottomCenterPanel is entirely below crop line, don't draw
                end
            end
            
            love.graphics.draw(state.images.bottomCenterPanel, frameX, bottomCenterPanelY)
            
            -- Reset scissor after drawing BottomCenterPanel (if it was enabled)
            if ENABLE_BOTTOM_CENTER_PANEL_CROP and state.bottomCenterPanelAnimation.hasTriggered then
                love.graphics.setScissor()
            end
        end
    end
    
    -- 9. LeftMidPanel (with engagement-based animation)
    if state.images.leftMidPanel then
        local leftMidPanelX = frameX + state.engagementPanelAnimations.leftMidPanelOffsetX
        love.graphics.draw(state.images.leftMidPanel, leftMidPanelX, frameY)
    end
    
    -- 10. RightMidPanel (with engagement-based animation)
    if state.images.rightMidPanel then
        local rightMidPanelX = frameX + state.engagementPanelAnimations.rightMidPanelOffsetX
        love.graphics.draw(state.images.rightMidPanel, rightMidPanelX, frameY)
    end
    
    -- 11. TopPanel (frontmost, with engagement-based animation)
    if state.images.topPanel then
        local topPanelY = frameY + state.engagementPanelAnimations.topPanelOffsetY
        love.graphics.draw(state.images.topPanel, frameX, topPanelY)
    end
end

-- Register animated panels on top of top banner (when banner is at down position)
function MonitorFrame.registerAnimatedPanelsOnTop()
    if not state.panelsSetToMaximum then
        return  -- Only register if panels are set to maximum
    end
    
    local frameX = 0
    local frameY = 0
    
    -- Draw MainFrame first (before animated panels)
    if state.images.mainFrame then
        DrawLayers.register(Constants.Z_DEPTH.ANIMATED_PANELS_ON_TOP, function()
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(state.images.mainFrame, frameX, frameY)
        end, "MainFrame (on top)")
    end
    
    -- Draw animated panels on top of banner
    if state.images.leftMidPanel then
        DrawLayers.register(Constants.Z_DEPTH.ANIMATED_PANELS_ON_TOP + 1, function()
            love.graphics.setColor(1, 1, 1, 1)
            local leftMidPanelX = frameX + state.engagementPanelAnimations.leftMidPanelOffsetX
            love.graphics.draw(state.images.leftMidPanel, leftMidPanelX, frameY)
        end, "LeftMidPanel (on top)")
    end
    
    if state.images.rightMidPanel then
        DrawLayers.register(Constants.Z_DEPTH.ANIMATED_PANELS_ON_TOP + 2, function()
            love.graphics.setColor(1, 1, 1, 1)
            local rightMidPanelX = frameX + state.engagementPanelAnimations.rightMidPanelOffsetX
            love.graphics.draw(state.images.rightMidPanel, rightMidPanelX, frameY)
        end, "RightMidPanel (on top)")
    end
    
    if state.images.topPanel then
        DrawLayers.register(Constants.Z_DEPTH.ANIMATED_PANELS_ON_TOP + 3, function()
            love.graphics.setColor(1, 1, 1, 1)
            local topPanelY = frameY + state.engagementPanelAnimations.topPanelOffsetY
            love.graphics.draw(state.images.topPanel, frameX, topPanelY)
        end, "TopPanel (on top)")
    end
end

-- Draw animated panels on top of top banner (called when banner is at down position)
function MonitorFrame.drawAnimatedPanelsOnTop()
    if not state.panelsSetToMaximum then
        return  -- Only draw if panels are set to maximum
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    local frameX = 0
    local frameY = 0
    
    -- Draw MainFrame first (before animated panels)
    -- 7. MainFrame
    if state.images.mainFrame then
        love.graphics.draw(state.images.mainFrame, frameX, frameY)
    end
    
    -- Draw animated panels on top of banner (same order as in draw())
    -- 9. LeftMidPanel (with engagement-based animation)
    if state.images.leftMidPanel then
        local leftMidPanelX = frameX + state.engagementPanelAnimations.leftMidPanelOffsetX
        love.graphics.draw(state.images.leftMidPanel, leftMidPanelX, frameY)
    end
    
    -- 10. RightMidPanel (with engagement-based animation)
    if state.images.rightMidPanel then
        local rightMidPanelX = frameX + state.engagementPanelAnimations.rightMidPanelOffsetX
        love.graphics.draw(state.images.rightMidPanel, rightMidPanelX, frameY)
    end
    
    -- 11. TopPanel (frontmost, with engagement-based animation)
    if state.images.topPanel then
        local topPanelY = frameY + state.engagementPanelAnimations.topPanelOffsetY
        love.graphics.draw(state.images.topPanel, frameX, topPanelY)
    end
end

return MonitorFrame

