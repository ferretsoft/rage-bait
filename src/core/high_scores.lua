-- src/core/high_scores.lua
-- High score management system

local HighScores = {}

-- Load high scores from file
function HighScores.load()
    local success, data = pcall(love.filesystem.read, "highscores.txt")
    if success and data then
        local scores = {}
        for line in data:gmatch("[^\r\n]+") do
            local name, score = line:match("([^,]+),([%d]+)")
            if name and score then
                table.insert(scores, {name = name, score = tonumber(score)})
            end
        end
        -- Sort by score descending
        table.sort(scores, function(a, b) return a.score > b.score end)
        Game.highScores = scores
    else
        Game.highScores = {}
    end
end

-- Save high scores to file
function HighScores.save()
    local data = ""
    for i, entry in ipairs(Game.highScores) do
        data = data .. entry.name .. "," .. entry.score .. "\n"
    end
    love.filesystem.write("highscores.txt", data)
end

-- Check if score qualifies as a high score
function HighScores.isHighScore(score)
    if #Game.highScores < 10 then
        return true  -- Always qualify if less than 10 scores
    end
    return score > Game.highScores[#Game.highScores].score
end

-- Add a high score entry
function HighScores.add(name, score)
    table.insert(Game.highScores, {name = name, score = score})
    table.sort(Game.highScores, function(a, b) return a.score > b.score end)
    -- Keep only top 10
    if #Game.highScores > 10 then
        table.remove(Game.highScores, 11)
    end
    HighScores.save()
end

-- Reset high scores (clear list and save)
function HighScores.reset()
    Game.highScores = {}
    HighScores.save()
    print("High scores reset")
end

return HighScores


