-- src/screens/intro_video_screen.lua
-- Intro video screen drawing (background only - video is drawn separately after CRT)

local IntroVideoScreen = {}

function IntroVideoScreen.draw()
    love.graphics.clear(0, 0, 0, 1)  -- Black background
    
    -- Video is drawn separately after CRT effect in love.draw()
    -- This function just provides the background
end

return IntroVideoScreen


