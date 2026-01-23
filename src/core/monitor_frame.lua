-- src/core/monitor_frame.lua
-- Monitor frame that goes around the entire screen

local Constants = require("src.constants")

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
    }
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

-- Update engagement-based panel animations
-- Called with current engagement value
function MonitorFrame.updateEngagementAnimations(engagementValue)
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
    -- Update eyelid animation
    if state.eyelidAnimation.active then
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
    
    -- Update BottomCenterPanel animation
    if state.bottomCenterPanelAnimation.active then
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

-- Draw the monitor frame (covers entire screen)
function MonitorFrame.draw()
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Draw all layers in back-to-front order
    -- Position at (0, 0) to cover entire screen
    local frameX = 0
    local frameY = 0
    
    -- 1. Mouthpiece (backmost)
    if state.images.mouthpiece then
        love.graphics.draw(state.images.mouthpiece, frameX, frameY)
    end
    
    -- 2. EyeLid (with animation offset)
    if state.images.eyeLid then
        local eyelidY = frameY + state.eyelidAnimation.currentY
        love.graphics.draw(state.images.eyeLid, frameX, eyelidY)
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
    
    -- 8. BottomCenterPanel (with animation and crop)
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

