-- src/core/chase_paxton.lua
-- Chase Paxton dialogue lines
-- Middle manager from hell, tech bro lingo, panicky

local ChasePaxton = {}

-- Comment pool organized by event type
ChasePaxton.COMMENTS = {
    game_start = {
        "Let's maximize engagement!",
        "Time to hit those KPIs!",
        "Show me those metrics!",
        "Let's optimize this workflow!"
    },
    unit_killed = {
        "Great conversion rate!",
        "That's a quality engagement!",
        "Synergy achieved!",
        "Disrupting the status quo!"
    },
    multiple_kills = {
        "Viral growth!",
        "Exponential scaling!",
        "Network effects in action!",
        "That's leverage!"
    },
    powerup_collected = {
        "Performance boost acquired!",
        "Upgrading your stack!",
        "That's a game-changer!",
        "Optimization unlocked!"
    },
    engagement_low = {
        "Watch those metrics!",
        "Engagement is tanking!",
        "We're bleeding users!",
        "The Auditor will see this!"
    },
    engagement_high = {
        "Crushing those KPIs!",
        "We're in the green!",
        "Metrics are off the charts!",
        "This is what I'm talking about!"
    },
    level_complete = {
        "Quarterly goals achieved!",
        "We're crushing it!",
        "That's a win-win!",
        "Moving the needle!"
    },
    game_over = {
        "We're in deep trouble!",
        "The Auditor will not be happy!",
        "This is a critical failure!",
        "We need to pivot NOW!"
    },
    combo = {
        "Compound growth!",
        "That's a multiplier!",
        "Cascading engagement!",
        "Momentum building!"
    },
    near_miss = {
        "Almost optimized!",
        "Close to peak performance!",
        "We need better targeting!",
        "A/B test that approach!"
    }
}

-- Intro screen messages (Chase Paxton's onboarding)
ChasePaxton.INTRO_MESSAGES = {
    {
        title = "WELCOME TO RAGE BAIT!",
        message = "You're our new engagement specialist!\nYour job: maximize user engagement metrics!",
        duration = 3.0
    },
    {
        title = "CONTROLS",
        message = "Hold Z for RED data packets\nHold X for BLUE data packets\nCollect powerups to optimize throughput!",
        duration = 4.0
    },
    {
        title = "OBJECTIVE",
        message = "Convert units by firing content on them, \nand hit them with the opposite to enrage them!\nMake sure they fight each other!",
        duration = 4.0
    },
    {
        title = "READY?",
        message = "Press SPACE or ENTER to start your shift!\nRemember: The Boss is watching!",
        duration = 999.0  -- Wait for input
    }
}

-- Level complete screen messages (context-aware based on win condition)
ChasePaxton.LEVEL_COMPLETE_MESSAGES = {
    blue_only = {
        title = "EXCELLENT WORK!",
        message = "You've successfully converted all units to BLUE alignment!\nThis shows strong user segmentation and targeted engagement.\nThe metrics are looking great - let's keep this momentum going!"
    },
    red_only = {
        title = "OUTSTANDING PERFORMANCE!",
        message = "All units are now RED aligned - that's aggressive user conversion!\nYou've created a highly engaged user base with maximum retention.\nThis is exactly the kind of results we need to see!"
    },
    neutral_only = {
        title = "STRATEGIC WIN!",
        message = "You've returned all units to NEUTRAL state - excellent crowd control!\nSometimes the best engagement strategy is maintaining balance.\nThis shows real tactical thinking. Ready to level up?"
    }
}

-- Get level complete message based on win condition
function ChasePaxton.getLevelCompleteMessage(winCondition)
    local messages = ChasePaxton.LEVEL_COMPLETE_MESSAGES[winCondition]
    if messages then
        return messages
    end
    -- Fallback
    return {
        title = "GREAT JOB!",
        message = "You've completed the level!\nKeep up the excellent work and let's push forward to the next challenge!"
    }
end

-- Demo mode tutorial messages
ChasePaxton.DEMO_MESSAGES = {
    {
        message = "Welcome to the demo! Watch how to control the A.R.A.C.",
        duration = 3.0
    },
    {
        message = "See how it targets neutral units and converts them with matching colors.",
        duration = 4.0
    },
    {
        message = "Red bombs convert units to red, blue bombs convert to blue!",
        duration = 3.5
    },
    {
        message = "Hitting a unit with the opposite color enrages them - watch out!",
        duration = 4.0
    },
    {
        message = "When units die, they leave toxic sludge that lowers engagement!",
        duration = 4.0
    },
    {
        message = "Neutral units that are isolated too long will go insane and explode!",
        duration = 4.0
    },
    {
        message = "Converted units form groups and fight each other automatically.",
        duration = 3.5
    },
    {
        message = "Toxic sludge from explosions lowers engagement - keep the board clean!",
        duration = 4.0
    },
    {
        message = "Keep engagement high by making the users fight each other!",
        duration = 4.0
    },
    {
        message = "Press SPACE to exit demo and play yourself!",
        duration = 10.0  -- Wait for input
    }
}

-- Get a random comment for an event type
function ChasePaxton.getComment(eventType)
    local commentList = ChasePaxton.COMMENTS[eventType]
    if not commentList or #commentList == 0 then return nil end
    return commentList[math.random(#commentList)]
end

-- Get intro message by step index
function ChasePaxton.getIntroMessage(step)
    if step and step >= 1 and step <= #ChasePaxton.INTRO_MESSAGES then
        return ChasePaxton.INTRO_MESSAGES[step]
    end
    return nil
end

return ChasePaxton

