local Constants = require("src.constants")

local Engagement = {}

function Engagement.init()
    Engagement.value = Constants.ENGAGEMENT_MAX -- Start at 100%
end

function Engagement.update(dt, toxicHazardCount, level)
    -- Base decay rate
    local decayRate = Constants.ENGAGEMENT_DECAY_BASE
    
    -- Level-based decay scaling
    -- Level 1: 50% decay (easier), each level increases by 15%
    -- Level 1 = 0.5x, Level 2 = 0.65x, Level 3 = 0.8x, etc.
    level = level or 1
    local levelMultiplier = 0.5 + ((level - 1) * Constants.ENGAGEMENT_DECAY_LEVEL_MULTIPLIER)
    decayRate = decayRate * levelMultiplier
    
    -- Toxic sludge increases decay rate
    -- Each active toxic hazard increases decay by a multiplier
    -- Clean board = slow decay, dirty board = fast decay
    if toxicHazardCount and toxicHazardCount > 0 then
        -- Each hazard adds decay multiplier (exponential scaling for danger)
        -- Formula: base * (1 + hazardCount * TOXIC_DECAY_MULTIPLIER)
        local toxicMultiplier = 1 + (toxicHazardCount * Constants.TOXIC_DECAY_MULTIPLIER)
        decayRate = decayRate * toxicMultiplier
    end
    
    -- Apply decay
    Engagement.value = Engagement.value - (decayRate * dt)
    
    -- Clamp to 0
    if Engagement.value < 0 then 
        Engagement.value = 0 
        -- Logic for Game Over can be checked here or in main.lua
    end
end

-- NEW: Function to refill the meter
function Engagement.add(amount)
    Engagement.value = Engagement.value + amount
    if Engagement.value > Constants.ENGAGEMENT_MAX then
        Engagement.value = Constants.ENGAGEMENT_MAX
    end
end

return Engagement