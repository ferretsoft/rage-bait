local Constants = require("src.constants")

local Engagement = {}

function Engagement.init()
    Engagement.value = Constants.ENGAGEMENT_MAX / 2 -- Start at 50%
end

function Engagement.update(dt)
    -- Constant decay
    Engagement.value = Engagement.value - (Constants.ENGAGEMENT_DECAY_BASE * dt)
    
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