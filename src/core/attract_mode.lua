-- src/core/attract_mode.lua
-- Attract mode screen and logic

local AttractMode = {}
local Constants = require("src.constants")

-- Draw Windows 95 style window frame with title bar and controls
local function drawWin95Frame(x, y, width, height, title)
    local borderWidth = 3
    local titleBarHeight = 20
    
    -- Outer border (thick grey)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Top and left edges (highlight - light gray/white)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.setLineWidth(2)
    -- Top edge
    love.graphics.line(x + borderWidth, y + borderWidth, x + width - borderWidth, y + borderWidth)
    -- Left edge
    love.graphics.line(x + borderWidth, y + borderWidth, x + borderWidth, y + height - borderWidth)
    
    -- Inner highlight (lighter)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + borderWidth + 1, y + borderWidth + 1, x + width - borderWidth - 1, y + borderWidth + 1)
    love.graphics.line(x + borderWidth + 1, y + borderWidth + 1, x + borderWidth + 1, y + height - borderWidth - 1)
    
    -- Bottom and right edges (shadow - dark gray/black)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.setLineWidth(2)
    -- Bottom edge
    love.graphics.line(x + borderWidth, y + height - borderWidth, x + width - borderWidth, y + height - borderWidth)
    -- Right edge
    love.graphics.line(x + width - borderWidth, y + borderWidth, x + width - borderWidth, y + height - borderWidth)
    
    -- Inner shadow (darker)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + borderWidth + 1, y + height - borderWidth - 1, x + width - borderWidth - 1, y + height - borderWidth - 1)
    love.graphics.line(x + width - borderWidth - 1, y + borderWidth + 1, x + width - borderWidth - 1, y + height - borderWidth - 1)
    
    -- Title bar background (Windows 95 blue gradient effect)
    local titleBarY = y + borderWidth
    love.graphics.setColor(0.2, 0.4, 0.6, 1)  -- Windows 95 blue
    love.graphics.rectangle("fill", x + borderWidth, titleBarY, width - (borderWidth * 2), titleBarHeight)
    
    -- Title bar highlight line
    love.graphics.setColor(0.4, 0.6, 0.8, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(x + borderWidth, titleBarY, x + width - borderWidth, titleBarY)
    
    -- Title text
    if title then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(Game.fonts.small)
        local titleX = x + borderWidth + 5
        local titleTextY = titleBarY + (titleBarHeight - Game.fonts.small:getHeight()) / 2
        love.graphics.print(title, titleX, titleTextY)
    end
    
    -- Window controls (minimize, maximize, close buttons) on the right
    local buttonSize = 16
    local buttonSpacing = 2
    local controlsX = x + width - borderWidth - (buttonSize * 3) - (buttonSpacing * 2) - 3
    local controlsY = titleBarY + 2
    
    -- Close button (red X)
    love.graphics.setColor(0.8, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", controlsX, controlsY, buttonSize, buttonSize)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(controlsX + 4, controlsY + 4, controlsX + buttonSize - 4, controlsY + buttonSize - 4)
    love.graphics.line(controlsX + buttonSize - 4, controlsY + 4, controlsX + 4, controlsY + buttonSize - 4)
    
    -- Maximize button (square)
    controlsX = controlsX + buttonSize + buttonSpacing
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", controlsX, controlsY, buttonSize, buttonSize)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", controlsX + 3, controlsY + 3, buttonSize - 6, buttonSize - 6)
    
    -- Minimize button (dash)
    controlsX = controlsX + buttonSize + buttonSpacing
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.rectangle("fill", controlsX, controlsY, buttonSize, buttonSize)
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(controlsX + 4, controlsY + buttonSize / 2, controlsX + buttonSize - 4, controlsY + buttonSize / 2)
end

-- Draw attract mode screen
function AttractMode.draw()
    -- Draw splash screen as background
    if Game.splash then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Game.splash, 0, 0, 0, 
            Constants.SCREEN_WIDTH / Game.splash:getWidth(),
            Constants.SCREEN_HEIGHT / Game.splash:getHeight())
    else
        -- Fallback to background color if splash image not loaded
        love.graphics.clear(Constants.COLORS.BACKGROUND)
    end
    
    -- High Scores (moved down 50px more, increased font size)
    if #Game.highScores > 0 then
        love.graphics.setFont(Game.fonts.large)  -- Increased from medium
        love.graphics.setColor(1, 0.8, 0.2)
        local highScoreTitle = "HIGH SCORES"
        local titleWidth2 = Game.fonts.large:getWidth(highScoreTitle)
        local titleY = 370  -- Moved down 50px from 320
        
        love.graphics.setFont(Game.fonts.large)  -- Increased from medium
        local lineHeight = 35  -- Increased for larger font
        local maxScores = math.min(10, #Game.highScores)
        
        -- Calculate box dimensions for high scores
        local boxPadding = 20
        local titleBarHeight = 20
        local boxWidth = 500
        local boxHeight = (maxScores * lineHeight) + 80 + titleBarHeight  -- Title + scores + padding + title bar
        local boxX = (Constants.SCREEN_WIDTH - boxWidth) / 2
        local boxY = titleY - 10 - titleBarHeight  -- Adjust for title bar
        
        -- Draw transparent black background box for high scores
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", boxX + 3, boxY + 3 + titleBarHeight, boxWidth - 6, boxHeight - 6 - titleBarHeight)
        
        -- Draw Windows 95 style frame with title bar
        drawWin95Frame(boxX, boxY, boxWidth, boxHeight, "High Scores")
        
        -- Draw title (inside the window, below title bar)
        local contentY = boxY + titleBarHeight + 10
        local startY = contentY + 40  -- Adjusted for larger font and title bar
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.print(highScoreTitle, (Constants.SCREEN_WIDTH - titleWidth2) / 2, contentY)
        
        -- Draw scores
        local startY = contentY + 40  -- Adjusted for larger font and title bar
        for i = 1, maxScores do
            local entry = Game.highScores[i]
            local rank = tostring(i) .. "."
            local name = entry.name
            local score = tostring(entry.score)
            
            -- Rank color (gold for top 3)
            if i == 1 then
                love.graphics.setColor(1, 0.84, 0)  -- Gold
            elseif i == 2 then
                love.graphics.setColor(0.75, 0.75, 0.75)  -- Silver
            elseif i == 3 then
                love.graphics.setColor(0.8, 0.5, 0.2)  -- Bronze
            else
                love.graphics.setColor(0.7, 0.7, 0.7)  -- Gray
            end
            
            -- Calculate positions for aligned display
            local rankX = Constants.SCREEN_WIDTH / 2 - 150
            local nameX = Constants.SCREEN_WIDTH / 2 - 80
            local scoreX = Constants.SCREEN_WIDTH / 2 + 100
            
            love.graphics.setFont(Game.fonts.large)
            love.graphics.print(rank, rankX, startY + (i - 1) * lineHeight)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.print(name, nameX, startY + (i - 1) * lineHeight)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(score, scoreX, startY + (i - 1) * lineHeight)
        end
    end
    
    -- Insert coin message (blinking) with transparent black background
    local blinkSpeed = 2.0
    local alpha = (math.sin(Game.attractModeTimer * blinkSpeed) + 1) / 2
    alpha = 0.3 + alpha * 0.7  -- Keep between 0.3 and 1.0
    
    love.graphics.setFont(Game.fonts.large)  -- Increased from medium
    local coinMsg = "INSERT COIN"
    local coinWidth = Game.fonts.large:getWidth(coinMsg)
    local coinY = Constants.SCREEN_HEIGHT - 250  -- Moved up 100px from 150
    
    -- Instructions
    love.graphics.setFont(Game.fonts.medium)  -- Increased from small
    local inst1 = "Press SPACE to start, or D for DEMO"
    local inst1Width = Game.fonts.medium:getWidth(inst1)
    local inst2 = "Use Z/X to fire bombs, collect powerups for rapid fire"
    local inst2Width = Game.fonts.medium:getWidth(inst2)
    
    -- Calculate box dimensions for bottom section
    local bottomBoxPadding = 20  -- Increased padding for larger fonts
    local titleBarHeight = 20
    local bottomBoxWidth = math.max(coinWidth, inst1Width, inst2Width) + (bottomBoxPadding * 2)
    local bottomBoxHeight = 110 + titleBarHeight  -- Increased for larger fonts + title bar
    local bottomBoxX = (Constants.SCREEN_WIDTH - bottomBoxWidth) / 2
    local bottomBoxY = coinY - 10 - titleBarHeight  -- Adjust for title bar
    
    -- Draw transparent black background box for bottom section
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", bottomBoxX + 3, bottomBoxY + 3 + titleBarHeight, bottomBoxWidth - 6, bottomBoxHeight - 6 - titleBarHeight)
    
    -- Draw Windows 95 style frame with title bar
    drawWin95Frame(bottomBoxX, bottomBoxY, bottomBoxWidth, bottomBoxHeight, "Game Controls")
    
    -- Draw insert coin message (inside the window, below title bar)
    local contentStartY = bottomBoxY + titleBarHeight + 10
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(1, 0.8, 0.2, alpha)
    love.graphics.print(coinMsg, (Constants.SCREEN_WIDTH - coinWidth) / 2, contentStartY)
    
    -- Draw instructions
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.print(inst1, (Constants.SCREEN_WIDTH - inst1Width) / 2, contentStartY + 35)
    
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(inst2, (Constants.SCREEN_WIDTH - inst2Width) / 2, contentStartY + 60)
end

-- Update attract mode
function AttractMode.update(dt)
    Game.attractModeTimer = Game.attractModeTimer + dt
end

return AttractMode


