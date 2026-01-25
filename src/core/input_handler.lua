-- src/core/input_handler.lua
-- Centralized input handling for keyboard and joystick

local Constants = require("src.constants")
local DemoMode = require("src.core.demo_mode")
local ChasePaxton = require("src.core.chase_paxton")
local Sound = require("src.core.sound")
local Screenshot = require("src.core.screenshot")
local Engagement = require("src.core.engagement")
local DynamicMusic = require("src.core.dynamic_music")
local TopBanner = require("src.core.top_banner")
local MonitorFrame = require("src.core.monitor_frame")

local InputHandler = {}

-- Helper function to submit high score name
local function submitNameEntry()
    local name = Game.nameEntryText:gsub("^%s+", ""):gsub("%s+$", "")  -- Trim whitespace
    if name == "" or name == "AAA" then
        name = "AAA"  -- Default name
    end
    addHighScore(name, Game.score)
    Game.nameEntryActive = false
    Game.nameEntryText = ""
    Game.nameEntryCursor = 1
    Game.nameEntryCharIndex = {}
    returnToAttractMode()
end

-- Helper function to update name entry character
local function updateNameEntryChar()
    local nameChars = {}
    for i = 1, Game.nameEntryMaxLength do
        local idx = Game.nameEntryCharIndex[i] or 1
        nameChars[i] = Game.nameEntryCharSet:sub(idx, idx)
    end
    Game.nameEntryText = table.concat(nameChars)
end

-- Handle keyboard key press
function InputHandler.handleKeyPressed(key)
    -- Handle matrix screen: space to continue to logo
    if Game.matrixMode then
        if key == "space" then
            Game.matrixMode = false
            Game.matrixTimer = 0
            Game.logoMode = true
            Game.logoTimer = 0
            Game.previousLogoTimer = 0
            Game.logoFanfarePlayed = false
            return true
        end
        -- Allow dynamic music sandbox to open during matrix screen
        if key == "m" then
            DynamicMusic.toggle()
            if DynamicMusic.isActive() then
                Sound.mute()
            else
                Sound.unmute()
            end
            return true
        elseif DynamicMusic.isActive() then
            -- Handle escape to close sandbox
            if key == "escape" then
                DynamicMusic.close()
                Sound.unmute()
                return true
            elseif key == "1" then
                DynamicMusic.switchToPart(1)
                return true
            elseif key == "2" then
                DynamicMusic.switchToPart(2)
                return true
            elseif key == "3" then
                DynamicMusic.switchToPart(3)
                return true
            elseif key == "4" then
                DynamicMusic.switchToPart(4)
                return true
            elseif key == "p" then
                DynamicMusic.cycleSyncMode()
                return true
            end
        end
        return false  -- Don't process other keys during matrix screen
    end
    
    -- Quick start: Press 'q' to skip directly to gameplay from any screen
    if key == "q" then
        -- Skip all intro screens and go straight to gameplay
        Game.bootingMode = false
        Game.logoMode = false
        Game.attractMode = false
        Game.videoMode = false
        Game.introMode = false
        Game.joystickTestMode = false
        Game.demoMode = false
        
        -- Stop video if playing
        if Game.introVideo then
            pcall(function()
                if Game.introVideo.pause then
                    Game.introVideo:pause()
                end
            end)
        end
        
        -- Unmute sounds
        Sound.unmute()
        
        -- Start gameplay directly (this will initialize everything)
        startGameplay()
        return true
    end
    
    -- Handle dynamic music player (only at logo or attract screen)
    if Game.logoMode or Game.attractMode then
        if key == "m" then
            DynamicMusic.toggle()
            -- Mute other sounds when opening sandbox
            if DynamicMusic.isActive() then
                Sound.mute()
            else
                Sound.unmute()
            end
            return true
        elseif DynamicMusic.isActive() then
            -- Handle escape to close sandbox
            if key == "escape" then
                DynamicMusic.close()
                Sound.unmute()
                return true
            elseif key == "1" then
                DynamicMusic.switchToPart(1)
                return true
            elseif key == "2" then
                DynamicMusic.switchToPart(2)
                return true
            elseif key == "3" then
                DynamicMusic.switchToPart(3)
                return true
            elseif key == "4" then
                DynamicMusic.switchToPart(4)
                return true
            elseif key == "p" then
                DynamicMusic.cycleSyncMode()
                return true
            end
        end
    end
    
    -- Handle name entry (arcade style)
    if Game.nameEntryActive then
        local charSet = Game.nameEntryCharSet
        local cursor = Game.nameEntryCursor
        local charIndex = Game.nameEntryCharIndex[cursor] or 1
        
        if key == "left" then
            -- Move cursor left
            Game.nameEntryCursor = math.max(1, cursor - 1)
        elseif key == "right" then
            -- Move cursor right
            Game.nameEntryCursor = math.min(Game.nameEntryMaxLength, cursor + 1)
        elseif key == "up" then
            -- Change character up
            charIndex = charIndex + 1
            if charIndex > #charSet then
                charIndex = 1  -- Wrap around
            end
            Game.nameEntryCharIndex[cursor] = charIndex
            updateNameEntryChar()
        elseif key == "down" then
            -- Change character down
            charIndex = charIndex - 1
            if charIndex < 1 then
                charIndex = #charSet  -- Wrap around
            end
            Game.nameEntryCharIndex[cursor] = charIndex
            updateNameEntryChar()
        elseif key == "return" or key == "enter" then
            -- Submit name
            submitNameEntry()
        end
        return true
    end
    
    -- Handle joystick test exit
    if Game.joystickTestMode then
        if key == "escape" or key == "space" or key == "return" or key == "enter" then
            Game.joystickTestMode = false
            Game.attractMode = true
            Game.attractModeTimer = 0
        end
        return true
    end

    -- Handle coin insertion and options in attract mode
    if Game.attractMode then
        if key == "space" or key == "return" or key == "enter" then
            startGame()
            return true
        elseif key == "j" then
            -- Open joystick test screen from attract mode
            Game.attractMode = false
            Game.joystickTestMode = true
            return true
        elseif key == "d" then
            -- Start demo mode
            DemoMode.start()
            return true
        end
    end
    
    -- Handle video mode input (allow skipping)
    if Game.videoMode then
        if key == "space" or key == "return" or key == "enter" or key == "escape" then
            -- Skip video and go directly to intro screen
            if Game.introVideo then
                -- Safely check if video is playing and pause it
                local success, isPlaying = pcall(function()
                    return Game.introVideo:isPlaying()
                end)
                if success and isPlaying then
                    pcall(function()
                        if Game.introVideo.pause then
                            Game.introVideo:pause()
                        end
                    end)
                end
            end
            Game.videoMode = false
            Game.introMode = true
            Game.introTimer = 0
            Game.introStep = 1
            Game.introMusicFadeActive = false
            return true
        end
    end
    
    -- Handle demo mode input
    if Game.demoMode then
        if DemoMode.keypressed(key) then
            return true
        end
    end
    
    -- Handle input during intro screen
    if Game.introMode then
        if key == "space" or key == "return" or key == "enter" then
            -- Skip to gameplay
            startGameplay()
            return true
        elseif key == "right" or key == "d" then
            -- Advance to next step
            if Game.introStep < #ChasePaxton.INTRO_MESSAGES then
                Game.introStep = Game.introStep + 1
                -- Reset timer for new step
                local stepStartTime = 0
                for i = 1, Game.introStep - 1 do
                    stepStartTime = stepStartTime + ChasePaxton.INTRO_MESSAGES[i].duration
                end
                Game.introTimer = stepStartTime
            end
            return true
        end
    end
    
    -- Toggle CRT shader
    if key == "c" then
        if Game.crtChain then
            Game.crtEnabled = not Game.crtEnabled
        end
        return true
    end
    
    -- Toggle background/foreground layers
    if key == "b" then
        Game.showBackgroundForeground = not Game.showBackgroundForeground
        return true
    end
    
    -- Toggle fullscreen on second monitor (F11)
    if key == "f11" then
        local isFullscreen = love.window.getFullscreen()
        local displayCount = love.window.getDisplayCount()
        
        if isFullscreen then
            -- Exit fullscreen: restore windowed mode on primary display
            love.window.setFullscreen(false)
            love.window.setMode(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
            -- Recreate CRT chain for windowed mode
            if Game.crtChain then
                -- Resize the chain (this recreates the buffer canvases)
                -- The glow effect will now automatically recreate its internal canvas
                Game.crtChain.resize(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
                
                -- Update CRT effect screen size
                if Game.crtEffect and Game.crtEffect.screenSize then
                    Game.crtEffect.screenSize = {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT}
                end
            end
        else
            -- Enter fullscreen using the monitor's full native resolution
            local width, height
            if displayCount > 1 then
                -- Get the native resolution of the second monitor
                width, height = love.window.getDesktopDimensions(2)
                -- Use exclusive fullscreen mode to ensure native resolution is used
                love.window.setMode(width, height, {
                    fullscreen = true,
                    fullscreentype = "exclusive",  -- Use exclusive fullscreen for native resolution
                    display = 2  -- Second monitor (1-indexed in LÖVE)
                })
            else
                -- Only one monitor, get its native resolution
                width, height = love.window.getDesktopDimensions(1)
                love.window.setMode(width, height, {
                    fullscreen = true,
                    fullscreentype = "exclusive"  -- Use exclusive fullscreen for native resolution
                })
            end
            -- Recreate CRT chain for fullscreen resolution
            if Game.crtChain then
                -- Resize the chain (this recreates the buffer canvases)
                -- The glow effect will now automatically recreate its internal canvas
                Game.crtChain.resize(width, height)
                
                -- Update CRT effect screen size - keep at original for proper scanline spacing
                if Game.crtEffect and Game.crtEffect.screenSize then
                    Game.crtEffect.screenSize = {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT}
                end
            end
        end
        return true
    end
    
    -- Take screenshot (F12 or PrintScreen)
    if key == "f12" or key == "printscreen" then
        Screenshot.capture()
        return true
    end
    
    -- Debug mode toggle (F1) - works from anywhere
    if key == "f1" then
        Game.debugMode = not Game.debugMode
        return true
    end
    
    -- Debug mode: Instant win (F2) - only when debug mode is active and game is playing
    if key == "f2" and Game.debugMode then
        if Game.gameState == "playing" and not Game.levelTransitionActive and not Game.gameOverActive then
            -- Trigger win condition by converting all units to blue
            for _, u in ipairs(Game.units) do
                if not u.isDead then
                    u.alignment = "blue"
                    u.state = "active"
                end
            end
            -- The win condition check in love.update() will detect this and call advanceToNextLevel
            return true
        end
    end
    
    -- Debug mode: Instant lose (F3) - only when debug mode is active and game is playing
    if key == "f3" and Game.debugMode then
        if Game.gameState == "playing" and not Game.levelTransitionActive and not Game.gameOverActive then
            -- Trigger lose condition by depleting engagement (same as natural life lost)
            Engagement.value = 0
            -- The engagement check in love.update() will detect this and call handleGameOver("engagement_depleted")
            return true
        end
    end
    
    -- Debug mode: Instant game over (F4) - only when debug mode is active and game is playing
    if key == "f4" and Game.debugMode then
        if Game.gameState == "playing" and not Game.levelTransitionActive and not Game.gameOverActive then
            -- Trigger game over by setting lives to 0 and calling handleGameOver
            Game.lives = 0
            handleGameOver("no_units")
            return true
        end
    end
    
    -- Don't allow charging if game state is not playing (prevents charging during win sequence)
    if Game.gameState ~= "playing" then return false end
    if key == "z" then 
        if Game.turret then
            Game.turret:startCharge("red")
        end
        return true
    elseif key == "x" then 
        if Game.turret then
            Game.turret:startCharge("blue")
        end
        return true
    elseif key == "2" then
        -- Debug: Give rapid fire powerup
        if Game.turret then
            Game.turret:activatePuckMode(Constants.POWERUP_DURATION)
        end
        return true
    elseif key == "0" then
        -- Debug: Set engagement to 50
        Engagement.value = 50
        return true
    end
    
    return false
end

-- Handle keyboard key release
function InputHandler.handleKeyReleased(key)
    if not Game.turret then return false end
    -- Don't allow releasing charge if game state is not playing
    if Game.gameState ~= "playing" then return false end
    if key == "z" or key == "x" then 
        Game.turret:releaseCharge(Game.projectiles)
        return true
    end
    return false
end

-- Handle joystick button press
function InputHandler.handleJoystickPressed(joystick, button)
    -- Handle name entry (arcade style)
    if Game.nameEntryActive then
        local cursor = Game.nameEntryCursor
        
        -- Button 3 = submit/commit at any time
        if button == 3 then
            submitNameEntry()
            return true
        -- Button 1 or 2 (fire buttons) = move cursor right or submit if at last position
        elseif button == 1 or button == 2 then
            -- If at last position, submit; otherwise move cursor right
            if cursor >= Game.nameEntryMaxLength then
                submitNameEntry()
            else
                -- Move cursor right
                Game.nameEntryCursor = math.min(Game.nameEntryMaxLength, cursor + 1)
            end
            return true
        end
    end
    
    -- Handle attract mode navigation
    if Game.attractMode and not Game.joystickTestMode then
        if button == 4 then
            -- Button 4 = start game (equivalent to SPACE/ENTER)
            startGame()
            return true
        elseif button == 3 then
            -- Button 3 = insert coin (placeholder for future implementation)
            -- TODO: Implement coin insertion logic when ready
            return true
        else
            -- Any other button opens joystick test screen
            Game.attractMode = false
            Game.joystickTestMode = true
            return true
        end
    end
    
    -- Handle joystick test mode exit
    if Game.joystickTestMode then
        if button == 4 then
            -- Button 4 = exit test mode and return to attract mode
            Game.joystickTestMode = false
            Game.attractMode = true
            Game.attractModeTimer = 0
            return true
        end
    end
    
    -- Handle intro screen (Chase Paxton onboarding)
    if Game.introMode then
        if button == 4 then
            -- Button 4 = skip to gameplay (equivalent to SPACE/ENTER)
            startGameplay()
            return true
        end
    end
    
    -- Handle gameplay firing (buttons 1 and 2)
    if Game.turret and Game.gameState == "playing" then
        if button == 1 then
            -- Button 1 = red fire
            Game.turret:startCharge("red")
            Game.joystickButton1Pressed = true
            return true
        elseif button == 2 then
            -- Button 2 = blue fire
            Game.turret:startCharge("blue")
            Game.joystickButton2Pressed = true
            return true
        end
    end
    
    return false
end

-- Handle joystick button release
function InputHandler.handleJoystickReleased(joystick, button)
    -- Don't process button releases during name entry
    if Game.nameEntryActive then return false end
    
    if not Game.turret then return false end
    -- Don't allow releasing charge if game state is not playing
    if Game.gameState ~= "playing" then return false end
    
    -- Handle button releases for firing
    if button == 1 then
        -- Button 1 released = release red charge
        Game.joystickButton1Pressed = false
        Game.turret:releaseCharge(Game.projectiles)
        return true
    elseif button == 2 then
        -- Button 2 released = release blue charge
        Game.joystickButton2Pressed = false
        Game.turret:releaseCharge(Game.projectiles)
        return true
    end
    
    return false
end

-- Handle joystick axis input (for DPad/analog stick in name entry)
function InputHandler.handleJoystickAxis(joystick, axis, value)
    -- Handle name entry with joystick axes (DPad/analog stick)
    if Game.nameEntryActive then
        local charSet = Game.nameEntryCharSet
        local cursor = Game.nameEntryCursor
        local charIndex = Game.nameEntryCharIndex[cursor] or 1
        
        -- Use deadzone to prevent drift
        local deadzone = 0.5
        
        -- Axis 2 = Y-axis (vertical movement for character selection)
        if axis == 2 then
            if value < -deadzone then
                -- Up: change character up
                charIndex = charIndex + 1
                if charIndex > #charSet then
                    charIndex = 1  -- Wrap around
                end
                Game.nameEntryCharIndex[cursor] = charIndex
                updateNameEntryChar()
                return true
            elseif value > deadzone then
                -- Down: change character down
                charIndex = charIndex - 1
                if charIndex < 1 then
                    charIndex = #charSet  -- Wrap around
                end
                Game.nameEntryCharIndex[cursor] = charIndex
                updateNameEntryChar()
                return true
            end
        end
    end
    
    return false
end

-- Handle joystick hat input (for DPad in name entry)
function InputHandler.handleJoystickHat(joystick, hat, direction)
    -- Handle name entry with joystick hat (DPad)
    if Game.nameEntryActive then
        local charSet = Game.nameEntryCharSet
        local cursor = Game.nameEntryCursor
        local charIndex = Game.nameEntryCharIndex[cursor] or 1
        
        if direction == "u" or direction == "lu" or direction == "ru" then
            -- Up: change character up
            charIndex = charIndex + 1
            if charIndex > #charSet then
                charIndex = 1  -- Wrap around
            end
            Game.nameEntryCharIndex[cursor] = charIndex
            updateNameEntryChar()
            return true
        elseif direction == "d" or direction == "ld" or direction == "rd" then
            -- Down: change character down
            charIndex = charIndex - 1
            if charIndex < 1 then
                charIndex = #charSet  -- Wrap around
            end
            Game.nameEntryCharIndex[cursor] = charIndex
            updateNameEntryChar()
            return true
        end
    end
    
    return false
end

return InputHandler
