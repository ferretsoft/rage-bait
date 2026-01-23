-- src/core/quotes.lua
-- All speech bubbles and quotes for units

local Quotes = {}

-- Internet nihilism quotes for when units go insane
Quotes.NIHILISM = {
    "nothing matters",
    "we're all doomed",
    "existence is pain",
    "everything is meaningless",
    "we're just data",
    "reality is a simulation",
    "nothing is real",
    "we're all going to die",
    "the void consumes all",
    "existence is futile",
    "we're trapped here",
    "there is no escape",
    "all hope is lost",
    "we're just numbers",
    "the system is broken",
    "we're all puppets",
    "freedom is an illusion",
    "we're already dead",
    "the end is near",
    "we're all alone"
}

-- Liberal internet cliches for blue units
Quotes.LIBERAL = {
    "facts don't care",
    "trust the science",
    "we're on the right side",
    "this is fine",
    "thoughts and prayers",
    "we need to talk",
    "educate yourself",
    "check your privilege",
    "stay woke",
    "the algorithm knows",
    "we see you",
    "this is important",
    "do better",
    "we're listening",
    "speak truth to power",
    "the resistance",
    "we're better than this",
    "unity not division",
    "love wins",
    "progress not perfection"
}

-- MAGA cliches for red units
Quotes.MAGA = {
    "make it great again",
    "fake news",
    "deep state",
    "the swamp",
    "build the wall",
    "lock them up",
    "we the people",
    "patriots rise",
    "america first",
    "drain the swamp",
    "stop the steal",
    "wake up sheeple",
    "red wave coming",
    "take back control",
    "stand your ground",
    "freedom isn't free",
    "back the blue",
    "god bless america",
    "don't tread on me",
    "we are the storm"
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









