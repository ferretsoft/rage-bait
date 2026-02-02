-- Script to export spider turret graphics as PNGs
-- Run with: love . --export-spider
-- 
-- This script exports the procedurally drawn spider graphics as PNG files
-- to assets/spider_export/ for use as reference or for roundtrip editing.
--
-- Exported files:
--   - spider_complete.png: Complete spider with all components (1024x1024)
--   - body.png: Main body/cephalothorax (128x128)
--   - abdomen.png: Abdomen (84x84)
--   - barrel_upper.png: Upper barrel (70x16)
--   - barrel_lower.png: Lower barrel (70x16)
--   - leg_knee.png: Knee joint (16x16)
--   - leg_foot.png: Foot (20x20)
--   - web_platform.png: Web platform (640x640)
--   - leg_upper_long.png: Long upper leg segment (140x140, 65px length)
--   - leg_upper_short.png: Short upper leg segment (140x140, 45px length)
--   - leg_lower_long.png: Long lower leg segment (140x140, 70px length)
--   - leg_lower_short.png: Short lower leg segment (140x140, 50px length)

local Constants = require("src.constants")
local World = require("src.core.world")
local Turret = require("src.entities.turret")

-- Animation configuration (from turret.lua)
local ANIM_CONF = {
    BODY_RADIUS = 30,
    ABDOMEN_OFFSET = -38,
    ABDOMEN_WIDTH = 42,
    ABDOMEN_HEIGHT = 32,
}

-- Helper function to export canvas to PNG
local function exportCanvas(canvas, filename, outputDir)
    local imageData = canvas:newImageData()
    local fileData = imageData:encode("png")
    local fullPath = outputDir .. "/" .. filename
    
    -- Try to write to project directory first using io
    local file = io.open(fullPath, "wb")
    if file then
        file:write(fileData:getString())
        file:close()
        return true, fullPath
    else
        -- Fallback to love filesystem (save directory)
        local success = love.filesystem.write(fullPath, fileData:getString())
        if success then
            local saveDir = love.filesystem.getSaveDirectory()
            return true, saveDir .. "/" .. fullPath
        else
            return false, nil
        end
    end
end

function love.load()
    -- Initialize world
    World.init()
    
    -- Create turret in neutral pose
    local turret = Turret.new()
    turret.visualX = turret.x
    turret.visualY = turret.y
    turret.visualAngle = turret.angle
    turret.lean = 0
    turret.barrelkick = 0
    turret.bodyRecoilX = 0
    turret.bodyRecoilY = 0
    turret.isCharging = false
    turret.puckModeTimer = 0
    turret.flashTimer = 0
    
    -- Update legs to neutral position
    turret:updateGait(0)
    
    -- Create output directory (in project root, not save directory)
    local outputDir = "assets/spider_export"
    -- Try to create directory using io (for project directory)
    os.execute("mkdir -p " .. outputDir)
    
    -- Also create in love filesystem (for save directory fallback)
    love.filesystem.createDirectory(outputDir)
    
    print("Exporting spider graphics...")
    
    -- Export 1: Complete spider (all components together)
    do
        local canvasSize = 1024  -- 2x resolution, plenty of room
        local centerX = canvasSize / 2
        local centerY = canvasSize / 2
        
        local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)  -- Transparent background
        
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        
        -- Draw web platform
        local platformRadius = turret.webRadius
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.circle("fill", 0, 0, platformRadius)
        love.graphics.setColor(0.9, 0.9, 0.85, 0.6)
        love.graphics.circle("fill", 0, 0, platformRadius)
        love.graphics.setColor(0.7, 0.7, 0.65, 0.8)
        love.graphics.setLineWidth(2)
        local numSpokes = 16
        for i = 0, numSpokes - 1 do
            local angle = (i / numSpokes) * math.pi * 2
            local endX = math.cos(angle) * platformRadius
            local endY = math.sin(angle) * platformRadius
            love.graphics.line(0, 0, endX, endY)
        end
        love.graphics.setColor(0.6, 0.6, 0.55, 0.7)
        love.graphics.setLineWidth(1.5)
        local numRings = 6
        for i = 1, numRings do
            local ringRadius = (platformRadius / numRings) * i
            love.graphics.circle("line", 0, 0, ringRadius)
        end
        love.graphics.setColor(0.5, 0.5, 0.45, 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", 0, 0, platformRadius)
        love.graphics.setColor(0.3, 0.3, 0.25, 0.8)
        love.graphics.circle("fill", 0, 0, 25)
        love.graphics.setColor(0.2, 0.2, 0.15, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, 25)
        
        -- Draw legs
        for i, leg in ipairs(turret.legs) do
            local legX = leg.hipX - turret.visualX
            local legY = leg.hipY - turret.visualY
            local kneeX = leg.kneeX - turret.visualX
            local kneeY = leg.kneeY - turret.visualY
            local footX = leg.footX - turret.visualX
            local footY = leg.footY - turret.visualY
            
            love.graphics.setLineWidth(4)
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.line(legX, legY + 5, kneeX, kneeY + 5)
            love.graphics.setColor(0.4, 0.4, 0.4)
            love.graphics.line(legX, legY, kneeX, kneeY)
            love.graphics.setColor(0.32, 0.32, 0.32)
            love.graphics.line(kneeX, kneeY, footX, footY)
            love.graphics.setColor(0.1, 0.1, 0.1)
            love.graphics.circle("fill", kneeX, kneeY, 4)
            love.graphics.circle("fill", footX, footY, 5)
        end
        
        -- Draw body and abdomen
        love.graphics.rotate(turret.visualAngle)
        
        local abdomenScale = 1.0
        local scaledW = ANIM_CONF.ABDOMEN_WIDTH * abdomenScale
        local scaledH = ANIM_CONF.ABDOMEN_HEIGHT * abdomenScale
        
        -- Abdomen
        love.graphics.setColor(0.25, 0.25, 0.35)
        love.graphics.ellipse("fill", ANIM_CONF.ABDOMEN_OFFSET, 0, scaledW, scaledH)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line", ANIM_CONF.ABDOMEN_OFFSET, 0, scaledW, scaledH)
        
        -- Main body
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.circle("fill", 0, 0, ANIM_CONF.BODY_RADIUS)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, ANIM_CONF.BODY_RADIUS)
        
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.circle("fill", 0, 0, ANIM_CONF.BODY_RADIUS * 0.7)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("line", 0, 0, ANIM_CONF.BODY_RADIUS * 0.7)
        
        -- Barrels
        local barrelLen = 35
        love.graphics.setColor(0.7, 0.2, 0.2)
        love.graphics.rectangle("fill", 10, -12, barrelLen, 8)
        love.graphics.rectangle("fill", 10, 4, barrelLen, 8)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", 10, -12, barrelLen, 8)
        love.graphics.rectangle("line", 10, 4, barrelLen, 8)
        
        love.graphics.pop()
        love.graphics.setCanvas()
        
        -- Export
        local success, path = exportCanvas(canvas, "spider_complete.png", outputDir)
        if success then
            print(string.format("✓ Exported: %s (%dx%d)", path, canvasSize, canvasSize))
        else
            print(string.format("✗ Failed to export spider_complete.png"))
        end
    end
    
    -- Export 2: Body only
    do
        local canvasSize = 128  -- 2x resolution
        local centerX = canvasSize / 2
        local centerY = canvasSize / 2
        
        local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        
        -- Main body
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.circle("fill", 0, 0, ANIM_CONF.BODY_RADIUS)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", 0, 0, ANIM_CONF.BODY_RADIUS)
        
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.circle("fill", 0, 0, ANIM_CONF.BODY_RADIUS * 0.7)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("line", 0, 0, ANIM_CONF.BODY_RADIUS * 0.7)
        
        love.graphics.pop()
        love.graphics.setCanvas()
        
        local success, path = exportCanvas(canvas, "body.png", outputDir)
        if success then
            print(string.format("✓ Exported: %s (%dx%d)", path, canvasSize, canvasSize))
        else
            print(string.format("✗ Failed to export body.png"))
        end
    end
    
    -- Export 3: Abdomen only
    do
        local canvasSize = 84  -- 2x resolution
        local centerX = canvasSize / 2
        local centerY = canvasSize / 2
        
        local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        
        local scaledW = ANIM_CONF.ABDOMEN_WIDTH
        local scaledH = ANIM_CONF.ABDOMEN_HEIGHT
        
        love.graphics.setColor(0.25, 0.25, 0.35)
        love.graphics.ellipse("fill", 0, 0, scaledW, scaledH)
        love.graphics.setColor(0, 0, 0)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line", 0, 0, scaledW, scaledH)
        
        love.graphics.pop()
        love.graphics.setCanvas()
        
        local success, path = exportCanvas(canvas, "abdomen.png", outputDir)
        if success then
            print(string.format("✓ Exported: %s (%dx%d)", path, canvasSize, canvasSize))
        else
            print(string.format("✗ Failed to export abdomen.png"))
        end
    end
    
    -- Export 4: Barrels (upper and lower)
    do
        local canvasSize = 70  -- 2x resolution
        local centerX = canvasSize / 2
        local centerY = canvasSize / 2
        
        -- Upper barrel
        local canvas = love.graphics.newCanvas(canvasSize, 16)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        local barrelLen = 35
        love.graphics.setColor(0.7, 0.2, 0.2)
        love.graphics.rectangle("fill", 0, 0, barrelLen, 8)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", 0, 0, barrelLen, 8)
        
        love.graphics.setCanvas()
        
        local success, path = exportCanvas(canvas, "barrel_upper.png", outputDir)
        if success then
            print(string.format("✓ Exported: %s (%dx%d)", path, canvasSize, 16))
        else
            print(string.format("✗ Failed to export barrel_upper.png"))
        end
        
        -- Lower barrel (same as upper)
        local canvas2 = love.graphics.newCanvas(canvasSize, 16)
        love.graphics.setCanvas(canvas2)
        love.graphics.clear(0, 0, 0, 0)
        
        love.graphics.setColor(0.7, 0.2, 0.2)
        love.graphics.rectangle("fill", 0, 0, barrelLen, 8)
        love.graphics.setColor(0, 0, 0)
        love.graphics.rectangle("line", 0, 0, barrelLen, 8)
        
        love.graphics.setCanvas()
        
        local success2, path2 = exportCanvas(canvas2, "barrel_lower.png", outputDir)
        if success2 then
            print(string.format("✓ Exported: %s (%dx%d)", path2, canvasSize, 16))
        else
            print(string.format("✗ Failed to export barrel_lower.png"))
        end
    end
    
    -- Export 5: Leg components (knee and foot)
    do
        -- Knee joint
        local canvas = love.graphics.newCanvas(16, 16)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.circle("fill", 8, 8, 4)
        
        love.graphics.setCanvas()
        
        local success, path = exportCanvas(canvas, "leg_knee.png", outputDir)
        if success then
            print(string.format("✓ Exported: %s (%dx%d)", path, 16, 16))
        else
            print(string.format("✗ Failed to export leg_knee.png"))
        end
        
        -- Foot
        local canvas2 = love.graphics.newCanvas(20, 20)
        love.graphics.setCanvas(canvas2)
        love.graphics.clear(0, 0, 0, 0)
        
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.circle("fill", 10, 10, 5)
        
        love.graphics.setCanvas()
        
        local success2, path2 = exportCanvas(canvas2, "leg_foot.png", outputDir)
        if success2 then
            print(string.format("✓ Exported: %s (%dx%d)", path2, 20, 20))
        else
            print(string.format("✗ Failed to export leg_foot.png"))
        end
    end
    
    -- Export 6: Web platform
    do
        local canvasSize = 640  -- 2x resolution
        local centerX = canvasSize / 2
        local centerY = canvasSize / 2
        
        local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        local platformRadius = turret.webRadius
        
        -- Web shadow
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.circle("fill", centerX, centerY + 3, platformRadius)
        
        -- Web base
        love.graphics.setColor(0.9, 0.9, 0.85, 0.6)
        love.graphics.circle("fill", centerX, centerY, platformRadius)
        
        -- Radial lines
        love.graphics.setColor(0.7, 0.7, 0.65, 0.8)
        love.graphics.setLineWidth(2)
        local numSpokes = 16
        for i = 0, numSpokes - 1 do
            local angle = (i / numSpokes) * math.pi * 2
            local endX = centerX + math.cos(angle) * platformRadius
            local endY = centerY + math.sin(angle) * platformRadius
            love.graphics.line(centerX, centerY, endX, endY)
        end
        
        -- Spiral pattern
        love.graphics.setColor(0.6, 0.6, 0.55, 0.7)
        love.graphics.setLineWidth(1.5)
        local numRings = 6
        for i = 1, numRings do
            local ringRadius = (platformRadius / numRings) * i
            love.graphics.circle("line", centerX, centerY, ringRadius)
        end
        
        -- Web border
        love.graphics.setColor(0.5, 0.5, 0.45, 0.9)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", centerX, centerY, platformRadius)
        
        -- Center hub
        love.graphics.setColor(0.3, 0.3, 0.25, 0.8)
        love.graphics.circle("fill", centerX, centerY, 25)
        love.graphics.setColor(0.2, 0.2, 0.15, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", centerX, centerY, 25)
        
        love.graphics.setCanvas()
        
        local success, path = exportCanvas(canvas, "web_platform.png", outputDir)
        if success then
            print(string.format("✓ Exported: %s (%dx%d)", path, canvasSize, canvasSize))
        else
            print(string.format("✗ Failed to export web_platform.png"))
        end
    end
    
    -- Export 7: Leg segments (all variants)
    -- Leg lengths from turret.lua:
    -- LONG_L1 = 65, LONG_L2 = 70 (long upper, long lower)
    -- SHORT_L1 = 45, SHORT_L2 = 50 (short upper, short lower)
    do
        local canvasSize = 140  -- Canvas size with padding
        
        -- Upper leg segment - LONG (65px)
        local canvas = love.graphics.newCanvas(canvasSize, canvasSize)
        love.graphics.setCanvas(canvas)
        love.graphics.clear(0, 0, 0, 0)
        
        love.graphics.push()
        love.graphics.translate(70, 70)
        
        love.graphics.setLineWidth(4)
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.line(0, 0, 65, 0)  -- Long upper segment
        
        love.graphics.pop()
        love.graphics.setCanvas()
        
        local success, path = exportCanvas(canvas, "leg_upper_long.png", outputDir)
        if success then
            print(string.format("✓ Exported: %s (%dx%d, 65px length)", path, canvasSize, canvasSize))
        else
            print(string.format("✗ Failed to export leg_upper_long.png"))
        end
        
        -- Upper leg segment - SHORT (45px)
        local canvas2 = love.graphics.newCanvas(canvasSize, canvasSize)
        love.graphics.setCanvas(canvas2)
        love.graphics.clear(0, 0, 0, 0)
        
        love.graphics.push()
        love.graphics.translate(70, 70)
        
        love.graphics.setLineWidth(4)
        love.graphics.setColor(0.4, 0.4, 0.4)
        love.graphics.line(0, 0, 45, 0)  -- Short upper segment
        
        love.graphics.pop()
        love.graphics.setCanvas()
        
        local success2, path2 = exportCanvas(canvas2, "leg_upper_short.png", outputDir)
        if success2 then
            print(string.format("✓ Exported: %s (%dx%d, 45px length)", path2, canvasSize, canvasSize))
        else
            print(string.format("✗ Failed to export leg_upper_short.png"))
        end
        
        -- Lower leg segment - LONG (70px)
        local canvas3 = love.graphics.newCanvas(canvasSize, canvasSize)
        love.graphics.setCanvas(canvas3)
        love.graphics.clear(0, 0, 0, 0)
        
        love.graphics.push()
        love.graphics.translate(70, 70)
        
        love.graphics.setLineWidth(4)
        love.graphics.setColor(0.32, 0.32, 0.32)
        love.graphics.line(0, 0, 70, 0)  -- Long lower segment
        
        love.graphics.pop()
        love.graphics.setCanvas()
        
        local success3, path3 = exportCanvas(canvas3, "leg_lower_long.png", outputDir)
        if success3 then
            print(string.format("✓ Exported: %s (%dx%d, 70px length)", path3, canvasSize, canvasSize))
        else
            print(string.format("✗ Failed to export leg_lower_long.png"))
        end
        
        -- Lower leg segment - SHORT (50px)
        local canvas4 = love.graphics.newCanvas(canvasSize, canvasSize)
        love.graphics.setCanvas(canvas4)
        love.graphics.clear(0, 0, 0, 0)
        
        love.graphics.push()
        love.graphics.translate(70, 70)
        
        love.graphics.setLineWidth(4)
        love.graphics.setColor(0.32, 0.32, 0.32)
        love.graphics.line(0, 0, 50, 0)  -- Short lower segment
        
        love.graphics.pop()
        love.graphics.setCanvas()
        
        local success4, path4 = exportCanvas(canvas4, "leg_lower_short.png", outputDir)
        if success4 then
            print(string.format("✓ Exported: %s (%dx%d, 50px length)", path4, canvasSize, canvasSize))
        else
            print(string.format("✗ Failed to export leg_lower_short.png"))
        end
    end
    
    print(string.format("\nAll exports complete! Files saved to: %s/", outputDir))
    print("Note: Legs are drawn procedurally with IK.")
    print("Leg segment lengths:")
    print("  - Upper: LONG (65px) and SHORT (45px)")
    print("  - Lower: LONG (70px) and SHORT (50px)")
    print("The complete spider shows all 8 legs in their natural positions with different combinations.")
    
    love.event.quit()
end

function love.draw()
    -- Nothing to draw
end

