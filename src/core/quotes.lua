-- src/core/quotes.lua
-- All speech bubbles and quotes for units

local Quotes = {}

-- NIHILISM (The "Doomers") – when units go insane
-- Archetype: The Terminally Online. Depressed, ironic, detached. They believe everything is a "cope."
Quotes.NIHILISM = {
    "Everything is a cope",
    "Just delete it all",
    "We are just content",
    "Dead internet theory",
    "Touch grass? Never",
    "Embrace the void",
    "Maximum entropy",
    "It's all cringe",
    "Why even bother?",
    "Reality is buffering",
    "Infinite scroll",
    "Brain rot",
    "We are the glitch",
    "Reset the server",
    "No signal found",
    "404: Hope not found",
    "Terminal decline",
    "Just let it end",
    "Digital decay",
    "Born to post, forced to wipe"
}

-- LIBERAL (The "Admins") – blue units
-- Archetype: The Consensus. Focused on safety, rules, correcting others, and group cohesion. HR/Therapy language.
Quotes.LIBERAL = {
    "Check your privilege",
    "Educate yourself",
    "Trust the experts",
    "Read the room",
    "That's problematic",
    "I'm literally shaking",
    "Follow the guidelines",
    "Be an ally",
    "Silence is violence",
    "You're being toxic",
    "Wrong side of history",
    "This isn't normal",
    "Respect the process",
    "Community standards",
    "Words have consequences",
    "Do better",
    "Believe the science",
    "Zero tolerance",
    "Empathy first",
    "You are unsafe"
}

-- MAGA (The "Sovereigns") – red units
-- Archetype: The Dissidents. Focused on strength, conspiracy, "waking up," rejecting the system. Combat/hierarchy language.
Quotes.MAGA = {
    "Freedom isn't free",
    "Wake up, sheeple",
    "Do your own research",
    "Facts over feelings",
    "Reject the narrative",
    "Hold the line",
    "Alpha energy",
    "Don't tread on me",
    "Defy the elites",
    "Escape the matrix",
    "Pure logic",
    "Take back control",
    "Reject modernity",
    "Only the strong",
    "No safe spaces",
    "Trigger warning!",
    "Sovereign citizen",
    "Break the conditioning",
    "Melt, snowflake",
    "Uncensorable"
}

-- Get a random quote from a category
function Quotes.getRandom(category)
    local quotes = Quotes[category]
    if quotes and #quotes > 0 then
        return quotes[math.random(#quotes)]
    end
    return nil
end

return Quotes
















