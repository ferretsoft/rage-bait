-- src/core/popups.lua
-- In-game popup messages

local Popups = {}

-- Win condition messages
Popups.WIN_MESSAGES = {
    blue_only = "LEVEL COMPLETE! Only Blue Units Remain",
    red_only = "LEVEL COMPLETE! Only Red Units Remain",
    neutral_only = "LEVEL COMPLETE! All Units Returned to Neutral"
}

-- Level transition messages
Popups.getAdvancingMessage = function(level)
    return "ADVANCING TO LEVEL " .. level .. "..."
end

-- High score entry messages
Popups.HIGH_SCORE = {
    TITLE = "NEW HIGH SCORE!",
    ENTER_NAME = "ENTER YOUR NAME:",
    getScore = function(score)
        return "SCORE: " .. score
    end
}

-- Game over messages
Popups.getLivesRemaining = function(lives)
    return "LIVES REMAINING: " .. lives
end

-- Level complete screen messages
Popups.getStartingIn = function(timeLeft)
    return "Starting in " .. timeLeft .. "..."
end

-- Get win message by condition
function Popups.getWinMessage(winCondition)
    return Popups.WIN_MESSAGES[winCondition] or ""
end

return Popups














