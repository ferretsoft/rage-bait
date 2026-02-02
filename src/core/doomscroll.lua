local Constants = require("src.constants")
local WindowFrame = require("src.core.window_frame")
local DrawingHelpers = require("src.core.drawing_helpers")

local Doomscroll = {}

-- Depressing newspaper headlines
local HEADLINES = {
    "ECONOMY COLLAPSES: MILLIONS JOBLESS",
    "CLIMATE DISASTER: CITIES UNDERWATER",
    "WAR ESCALATES: NO END IN SIGHT",
    "PANDEMIC RETURNS: HOSPITALS OVERWHELMED",
    "HOUSING CRISIS: HOMELESSNESS SOARS",
    "FOOD SHORTAGES: FAMINE SPREADS",
    "SOCIAL UNREST: RIOTS IN MAJOR CITIES",
    "TECHNOLOGY FAILS: INFRASTRUCTURE CRUMBLES",
    "MENTAL HEALTH CRISIS: SUICIDE RATES UP",
    "EDUCATION COLLAPSE: SCHOOLS CLOSED",
    "WATER SCARCITY: MILLIONS THIRSTY",
    "ENERGY CRISIS: BLACKOUTS NATIONWIDE",
    "POLITICAL CORRUPTION: TRUST ERASED",
    "INEQUALITY GROWS: RICH GET RICHER",
    "ENVIRONMENTAL COLLAPSE: SPECIES EXTINCT",
    "CYBER ATTACKS: CRITICAL SYSTEMS DOWN",
    "INFLATION SPIRALS: MONEY WORTHLESS",
    "HEALTHCARE FAILS: DOCTORS QUIT",
    "TRANSPORTATION BREAKS: NO WAY OUT",
    "COMMUNICATION DOWN: WORLD ISOLATED",
    "RESOURCES DEPLETED: NO HOPE LEFT",
    "SOCIETY BREAKS: LAWLESS CHAOS",
    "FUTURE BLEAK: GENERATIONS LOST",
    "HUMANITY FAILS: EXTINCTION NEAR"
}

-- Feed state
local feedState = {
    scrollY = 0,
    scrollSpeed = 30,  -- pixels per second
    items = {},
    itemHeight = 50,
    spacing = 10,
    initialized = false
}

function Doomscroll.init()
    if feedState.initialized then return end
    
    -- Initialize feed with headlines
    feedState.items = {}
    for i = 1, #HEADLINES do
        table.insert(feedState.items, {
            headline = HEADLINES[i],
            timestamp = os.date("%H:%M"),
            id = i
        })
    end
    
    -- Add more items by duplicating to create infinite scroll effect
    for i = 1, #HEADLINES do
        table.insert(feedState.items, {
            headline = HEADLINES[i],
            timestamp = os.date("%H:%M"),
            id = i + #HEADLINES
        })
    end
    
    feedState.initialized = true
end

function Doomscroll.update(dt, gameState)
    if not feedState.initialized then
        Doomscroll.init()
    end
    
    -- Stop scrolling on win or lose
    local shouldScroll = true
    if gameState then
        -- Check for win conditions
        if gameState.gameState == "level_complete" or gameState.winCondition or gameState.modes.winText then
            shouldScroll = false
        end
        -- Check for lose conditions
        if gameState.modes.gameOver then
            shouldScroll = false
        end
    end
    
    -- Auto-scroll upward (like a social media feed) only if not won/lost
    if shouldScroll then
        feedState.scrollY = feedState.scrollY + feedState.scrollSpeed * dt
        
        -- Reset scroll when we've scrolled past all items
        local totalHeight = (#feedState.items * (feedState.itemHeight + feedState.spacing))
        if feedState.scrollY > totalHeight then
            feedState.scrollY = feedState.scrollY - totalHeight
        end
    end
end

function Doomscroll.draw(fonts)
    if not feedState.initialized then
        Doomscroll.init()
    end
    
    -- Doomscroll window dimensions and position (below score window, centered)
    local DOOMSCROLL_WIDTH = Constants.UI.SCORE_WINDOW_WIDTH
    local DOOMSCROLL_HEIGHT = 200
    local DOOMSCROLL_X = (Constants.SCREEN_WIDTH - DOOMSCROLL_WIDTH) / 2  -- Centered
    local SCORE_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + Constants.UI.WINDOW_SPACING
    local SCORE_HEIGHT = Constants.UI.SCORE_WINDOW_HEIGHT
    local DOOMSCROLL_Y = SCORE_Y + SCORE_HEIGHT + Constants.UI.WINDOW_SPACING
    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local borderWidth = Constants.UI.BORDER_WIDTH
    
    -- Draw transparent black background for content area
    DrawingHelpers.drawWindowContentBackground(DOOMSCROLL_X, DOOMSCROLL_Y, DOOMSCROLL_WIDTH, DOOMSCROLL_HEIGHT, titleBarHeight, borderWidth)
    
    -- Draw Windows 95 style frame with title bar
    WindowFrame.draw(DOOMSCROLL_X, DOOMSCROLL_Y, DOOMSCROLL_WIDTH, DOOMSCROLL_HEIGHT, "The Daily Doomscroll")
    
    -- Set up clipping for feed content area
    local contentX = DOOMSCROLL_X + borderWidth
    local contentY = DOOMSCROLL_Y + titleBarHeight + borderWidth
    local contentWidth = DOOMSCROLL_WIDTH - (borderWidth * 2)
    local contentHeight = DOOMSCROLL_HEIGHT - titleBarHeight - (borderWidth * 2)
    
    love.graphics.setScissor(contentX, contentY, contentWidth, contentHeight)
    
    -- Draw feed items
    local font = fonts.medium or fonts.small or fonts.large
    local smallFont = fonts.small or font
    local y = contentY - feedState.scrollY
    
    for i, item in ipairs(feedState.items) do
        local itemY = y + (i - 1) * (feedState.itemHeight + feedState.spacing)
        
        -- Only draw if item is visible in the content area
        if itemY + feedState.itemHeight >= contentY and itemY <= contentY + contentHeight then
            -- Draw divider line
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.setLineWidth(1)
            love.graphics.line(contentX + 5, itemY, contentX + contentWidth - 5, itemY)
            
            -- Draw timestamp
            love.graphics.setFont(smallFont)
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            love.graphics.print(item.timestamp, contentX + 10, itemY + 5)
            
            -- Draw headline
            love.graphics.setFont(font)
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            local headlineX = contentX + 10
            local headlineY = itemY + 20
            local maxWidth = contentWidth - 20
            
            -- Word wrap headline
            local words = {}
            for word in item.headline:gmatch("%S+") do
                table.insert(words, word)
            end
            
            local currentLine = ""
            local lineY = headlineY
            local lineHeight = 16
            
            for j, word in ipairs(words) do
                local testLine = currentLine == "" and word or currentLine .. " " .. word
                local testWidth = font:getWidth(testLine)
                
                if testWidth > maxWidth and currentLine ~= "" then
                    love.graphics.print(currentLine, headlineX, lineY)
                    lineY = lineY + lineHeight
                    currentLine = word
                else
                    currentLine = testLine
                end
            end
            
            if currentLine ~= "" then
                love.graphics.print(currentLine, headlineX, lineY)
            end
        end
        
        -- If we've scrolled past the bottom, wrap to top
        if itemY > contentY + contentHeight + feedState.itemHeight then
            break
        end
    end
    
    love.graphics.setScissor()
end

return Doomscroll

