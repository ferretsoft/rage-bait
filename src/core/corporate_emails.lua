-- Corporate bullshit email scroll (same style as doom scroll, below webcam)

local Constants = require("src.constants")
local WindowFrame = require("src.core.window_frame")
local DrawingHelpers = require("src.core.drawing_helpers")

local CorporateEmails = {}

local EMAIL_CONTENT = {
    {"Synergy Enhancement Initiative", "Dear Team, following our recent strategic alignment, we're launching a synergy enhancement initiative to optimize cross-functional collaboration. Your active participation is crucial for fostering a culture of agile ideation and maximizing stakeholder value. Let's touch base offline to calibrate our deliverables."},
    {"Proactive Paradigm Shift", "All, it's time for a proactive paradigm shift. We need to leverage our core competencies to unbundle legacy thought processes and pivot towards a scalable, future-proof ecosystem. Remember, innovation thrives on disruption. Let's circle back on Q3 KPIs."},
    {"Leveraging Core Competencies", "Team, a quick update on leveraging our core competencies. Our deep dive into best-in-class methodologies indicates a clear runway for actionable insights. We must empower our verticals to drive impactful outcomes. Please ensure all bandwidth is allocated judiciously."},
    {"Optimizing Human Capital", "Greetings, we're focusing on optimizing human capital. By nurturing organic growth and fostering a robust talent pipeline, we aim to unlock unparalleled efficiencies. Remember to document your learnings in the shared repository. Your unique value proposition is key."},
    {"Streamlining Workflows", "Hi everyone, a reminder about streamlining workflows. Our objective is to minimize redundancies and maximize throughput across all operational silos. This requires a granular understanding of our value chain. Let's align our strategic objectives."},
    {"Accelerating Growth Vectors", "Good morning, we're accelerating our growth vectors. By focusing on market penetration and cultivating key partnerships, we're poised for exponential scalability. Remember, every touchpoint is an opportunity to amplify our brand narrative. Keep driving the needle!"},
    {"Engagement & Empowerment", "Team, I wanted to reiterate the importance of engagement and empowerment. By fostering a collaborative environment, we enable our associates to take ownership and champion innovation. Let's ensure our strategic pillars are reinforced at every level. Your input is vital."},
    {"Driving Thought Leadership", "Hi, as we drive thought leadership, it's paramount that our narratives resonate with evolving market dynamics. We must articulate our unique value proposition with clarity and conviction. Let's ensure our messaging is consistent across all channels. Keep pushing the envelope."},
    {"Holistic Ecosystem Development", "All, our focus remains on holistic ecosystem development. This involves cultivating robust partnerships and integrating seamless solutions that enhance user experience. Remember to keep an eye on emergent trends. Your forward-thinking contributions are valued."},
    {"Strategic Offsite Debrief", "Team, thanks for a productive strategic offsite. The whiteboard sessions yielded actionable insights. We're now tasked with operationalizing these learnings and ensuring our deliverables are aligned with our overarching mission. Let's hit the ground running!"},
    {"Cross-Functional Alignment", "Greetings, cross-functional alignment is key to our success. By breaking down silos and fostering open communication, we can achieve unparalleled efficiencies and drive collective impact. Your commitment to collaborative excellence is appreciated."},
    {"Value Proposition Reinforcement", "Team, a reminder about value proposition reinforcement. Every interaction is an opportunity to articulate our unique strengths and resonate with client needs. Let's ensure our messaging is consistently impactful. Keep up the great work!"},
    {"Q3 Synergy Metrics", "All, the Q3 synergy metrics review is approaching. Please ensure your departmental reports highlight areas of optimized collaboration and integrated efficiencies. Our goal is to demonstrate tangible ROI from our cross-functional efforts. Timely submission is appreciated."},
    {"Agile Transformation Update", "Hi team, a quick update on our agile transformation. We're making significant strides in adopting iterative development cycles and fostering a culture of continuous improvement. Your adaptability and commitment to best practices are commendable. Keep sprinting!"},
    {"Bandwidth Allocation Review", "Team, we're initiating a bandwidth allocation review. Our objective is to ensure resources are optimally distributed to maximize strategic impact and minimize bottlenecks. Please provide granular insights into your current project load. Your cooperation is vital for efficiency."},
    {"Disruptive Innovation Workshop", "Greetings, prepare for our disruptive innovation workshop. We'll be ideating on game-changing solutions that challenge industry norms and redefine market expectations. Bring your boldest ideas – no concept is too ambitious! Let's shake things up."},
}

local feedState = {
    scrollY = 0,
    scrollSpeed = 20,
    items = {},
    itemHeight = 100,
    spacing = 15,
    initialized = false,
}

function CorporateEmails.init()
    if feedState.initialized then return end

    feedState.items = {}
    for i = 1, #EMAIL_CONTENT do
        table.insert(feedState.items, {
            subject = EMAIL_CONTENT[i][1],
            body = EMAIL_CONTENT[i][2],
            id = i,
            timestamp = os.date("%H:%M"),
        })
    end
    for i = 1, #EMAIL_CONTENT do
        table.insert(feedState.items, {
            subject = EMAIL_CONTENT[i][1],
            body = EMAIL_CONTENT[i][2],
            id = i + #EMAIL_CONTENT,
            timestamp = os.date("%H:%M"),
        })
    end

    for i = #feedState.items, 2, -1 do
        local j = math.random(i)
        feedState.items[i], feedState.items[j] = feedState.items[j], feedState.items[i]
    end

    feedState.initialized = true
end

function CorporateEmails.update(dt, gameState)
    if not feedState.initialized then
        CorporateEmails.init()
    end

    local shouldScroll = true
    if gameState then
        if gameState.gameState == "level_complete" or gameState.winCondition or gameState.modes.winText or gameState.modes.gameOver then
            shouldScroll = false
        end
    end

    if shouldScroll then
        feedState.scrollY = feedState.scrollY + feedState.scrollSpeed * dt
        local totalContentHeight = #feedState.items * (feedState.itemHeight + feedState.spacing)
        if feedState.scrollY > totalContentHeight then
            feedState.scrollY = feedState.scrollY - totalContentHeight
        end
    end
end

function CorporateEmails.draw(fonts)
    if not feedState.initialized then
        CorporateEmails.init()
    end

    local ui = Constants.UI
    local WEBCAM_WIDTH = ui.WEBCAM_GAMEPLAY_WIDTH
    local WEBCAM_HEIGHT = ui.WEBCAM_GAMEPLAY_HEIGHT
    local WEBCAM_X = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH - WEBCAM_WIDTH - ui.WEBCAM_GAMEPLAY_OFFSET_X
    local WEBCAM_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + ui.WEBCAM_GAMEPLAY_OFFSET_Y

    local EMAIL_WIDTH = WEBCAM_WIDTH
    local EMAIL_HEIGHT = 200
    local EMAIL_X = WEBCAM_X
    local EMAIL_Y = WEBCAM_Y + WEBCAM_HEIGHT + ui.WINDOW_SPACING

    local titleBarHeight = ui.TITLE_BAR_HEIGHT
    local borderWidth = ui.BORDER_WIDTH

    DrawingHelpers.drawWindowContentBackground(EMAIL_X, EMAIL_Y, EMAIL_WIDTH, EMAIL_HEIGHT, titleBarHeight, borderWidth)
    WindowFrame.draw(EMAIL_X, EMAIL_Y, EMAIL_WIDTH, EMAIL_HEIGHT, "Corporate Inbox")

    local contentX = EMAIL_X + borderWidth
    local contentY = EMAIL_Y + titleBarHeight + borderWidth
    local contentWidth = EMAIL_WIDTH - (borderWidth * 2)
    local contentHeight = EMAIL_HEIGHT - titleBarHeight - (borderWidth * 2)

    love.graphics.setScissor(contentX, contentY, contentWidth, contentHeight)

    local font = fonts.small or fonts.medium or fonts.large
    local lineHeight = font:getHeight() * 1.2
    local y = contentY - feedState.scrollY

    for i, item in ipairs(feedState.items) do
        local itemY = y + (i - 1) * (feedState.itemHeight + feedState.spacing)

        if itemY + feedState.itemHeight >= contentY and itemY <= contentY + contentHeight then
            love.graphics.setColor(0.3, 0.3, 0.3, 1)
            love.graphics.setLineWidth(1)
            love.graphics.line(contentX + 5, itemY, contentX + contentWidth - 5, itemY)

            love.graphics.setFont(font)
            love.graphics.setColor(0.5, 0.5, 0.5, 1)
            love.graphics.print(item.timestamp, contentX + 10, itemY + 5)

            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            love.graphics.print(item.subject, contentX + 10, itemY + 20)

            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            local bodyX = contentX + 10
            local bodyY = itemY + 40
            local maxWidth = contentWidth - 20

            local words = {}
            for word in item.body:gmatch("%S+") do
                table.insert(words, word)
            end

            local currentLine = ""
            local currentLineY = bodyY

            for _, word in ipairs(words) do
                local testLine = currentLine == "" and word or currentLine .. " " .. word
                local testWidth = font:getWidth(testLine)

                if testWidth > maxWidth and currentLine ~= "" then
                    love.graphics.print(currentLine, bodyX, currentLineY)
                    currentLineY = currentLineY + lineHeight
                    currentLine = word
                else
                    currentLine = testLine
                end
                if currentLineY + lineHeight > itemY + feedState.itemHeight - 5 then break end
            end
            if currentLine ~= "" then
                love.graphics.print(currentLine, bodyX, currentLineY)
            end
        end
    end

    love.graphics.setScissor()
end

return CorporateEmails
