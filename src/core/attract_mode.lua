-- src/core/attract_mode.lua
-- Attract mode screen and logic

local AttractMode = {}
local Constants = require("src.constants")
local WindowFrame = require("src.core.window_frame")
local MonitorFrame = require("src.core.monitor_frame")

-- Draw attract mode screen
function AttractMode.draw()
    -- Clear screen
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
    local DrawingHelpers = require("src.core.drawing_helpers")
    DrawingHelpers.drawTealWallpaper()
    
    -- Draw splash screen as background (on top of wallpaper)
    if Game.assets.splash then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Game.assets.splash, 0, 0, 0, 
            Constants.SCREEN_WIDTH / Game.assets.splash:getWidth(),
            Constants.SCREEN_HEIGHT / Game.assets.splash:getHeight())
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
        WindowFrame.draw(boxX, boxY, boxWidth, boxHeight, "High Scores")
        
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
    local alpha = (math.sin(Game.timers.attract * blinkSpeed) + 1) / 2
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
    WindowFrame.draw(bottomBoxX, bottomBoxY, bottomBoxWidth, bottomBoxHeight, "Game Controls")
    
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
    Game.timers.attract = Game.timers.attract + dt
end

return AttractMode


