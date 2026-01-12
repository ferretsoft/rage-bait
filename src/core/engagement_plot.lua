-- src/core/engagement_plot.lua
-- Engagement plot diagram showing engagement over time

local EngagementPlot = {}
local Constants = require("src.constants")
local Engagement = require("src.core.engagement")

-- Plot window dimensions and position
local PLOT_WIDTH = 300
local PLOT_HEIGHT = 200
-- Position on the left side, webcam will be on the right
local PLOT_X = Constants.OFFSET_X + 20  -- Left side
local PLOT_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + 20  -- Same Y as webcam

-- Data storage
local engagementHistory = {}
local maxHistoryLength = 200  -- Store last 200 data points
local updateTimer = 0
local updateInterval = 0.1  -- Update every 0.1 seconds

-- Initialize plot
function EngagementPlot.init()
    engagementHistory = {}
    updateTimer = 0
end

-- Update plot data
function EngagementPlot.update(dt)
    updateTimer = updateTimer + dt
    
    if updateTimer >= updateInterval then
        updateTimer = 0
        
        -- Add current engagement value to history
        local currentEngagement = Engagement.value
        table.insert(engagementHistory, currentEngagement)
        
        -- Limit history length
        if #engagementHistory > maxHistoryLength then
            table.remove(engagementHistory, 1)
        end
    end
end

-- Draw plot window
function EngagementPlot.draw()
    -- Draw plot window frame
    love.graphics.setColor(0.2, 0.2, 0.2, 1)
    love.graphics.rectangle("fill", PLOT_X, PLOT_Y, PLOT_WIDTH, PLOT_HEIGHT)
    
    -- Draw border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", PLOT_X, PLOT_Y, PLOT_WIDTH, PLOT_HEIGHT)
    
    -- Draw inner border
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", PLOT_X + 5, PLOT_Y + 5, PLOT_WIDTH - 10, PLOT_HEIGHT - 10)
    
    -- Draw plot area (with padding)
    local plotPadding = 15
    local plotX = PLOT_X + plotPadding
    local plotY = PLOT_Y + plotPadding + 20  -- Extra space for title
    local plotW = PLOT_WIDTH - plotPadding * 2
    local plotH = PLOT_HEIGHT - plotPadding * 2 - 20
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.getFont() or love.graphics.newFont(14))
    local title = "ENGAGEMENT"
    local titleWidth = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, PLOT_X + (PLOT_WIDTH - titleWidth) / 2, PLOT_Y + 8)
    
    -- Draw grid lines
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.setLineWidth(1)
    
    -- Horizontal grid lines (engagement levels)
    for i = 0, 4 do
        local y = plotY + (plotH / 4) * i
        love.graphics.line(plotX, y, plotX + plotW, y)
    end
    
    -- Vertical grid lines (time)
    for i = 0, 4 do
        local x = plotX + (plotW / 4) * i
        love.graphics.line(x, plotY, x, plotY + plotH)
    end
    
    -- Draw axis labels
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.setFont(love.graphics.getFont() or love.graphics.newFont(10))
    
    -- Y-axis labels (engagement values)
    for i = 0, 4 do
        local value = Constants.ENGAGEMENT_MAX - (Constants.ENGAGEMENT_MAX / 4) * i
        local label = tostring(math.floor(value))
        local labelY = plotY + (plotH / 4) * i - 5
        love.graphics.print(label, plotX - 25, labelY)
    end
    
    -- Draw engagement line graph
    if #engagementHistory > 1 then
        love.graphics.setLineWidth(2)
        
        -- Draw line segments
        for i = 2, #engagementHistory do
            local x1 = plotX + ((i - 2) / (#engagementHistory - 1)) * plotW
            local y1 = plotY + plotH - (engagementHistory[i - 1] / Constants.ENGAGEMENT_MAX) * plotH
            
            local x2 = plotX + ((i - 1) / (#engagementHistory - 1)) * plotW
            local y2 = plotY + plotH - (engagementHistory[i] / Constants.ENGAGEMENT_MAX) * plotH
            
            -- Color based on engagement level
            local engagementPct = engagementHistory[i] / Constants.ENGAGEMENT_MAX
            if engagementPct < 0.25 then
                love.graphics.setColor(1, 0, 0, 1)  -- Red for low
            elseif engagementPct < 0.5 then
                love.graphics.setColor(1, 1, 0, 1)  -- Yellow for medium
            else
                love.graphics.setColor(0, 1, 0, 1)  -- Green for high
            end
            
            love.graphics.line(x1, y1, x2, y2)
        end
        
        -- Draw current value indicator
        if #engagementHistory > 0 then
            local currentValue = engagementHistory[#engagementHistory]
            local currentX = plotX + plotW
            local currentY = plotY + plotH - (currentValue / Constants.ENGAGEMENT_MAX) * plotH
            
            -- Draw dot at current value
            local engagementPct = currentValue / Constants.ENGAGEMENT_MAX
            if engagementPct < 0.25 then
                love.graphics.setColor(1, 0, 0, 1)
            elseif engagementPct < 0.5 then
                love.graphics.setColor(1, 1, 0, 1)
            else
                love.graphics.setColor(0, 1, 0, 1)
            end
            
            love.graphics.circle("fill", currentX, currentY, 4)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("line", currentX, currentY, 4)
        end
    end
    
    -- Draw current value text
    if #engagementHistory > 0 then
        local currentValue = engagementHistory[#engagementHistory]
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(love.graphics.getFont() or love.graphics.newFont(12))
        local valueText = string.format("%.0f", currentValue)
        local valueWidth = love.graphics.getFont():getWidth(valueText)
        love.graphics.print(valueText, PLOT_X + PLOT_WIDTH - valueWidth - 10, PLOT_Y + PLOT_HEIGHT - 20)
    end
end

return EngagementPlot

