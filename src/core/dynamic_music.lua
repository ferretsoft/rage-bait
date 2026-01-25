-- src/core/dynamic_music.lua
-- Dynamic music player with beat/bar sync

local Constants = require("src.constants")

local DynamicMusic = {}

-- Internal state
local state = {
    active = false,  -- Whether the sandbox is open
    automatic = false,  -- Whether automatic gameplay music is active
    parts = {},  -- Array of arrays: parts[1] = {all Part1 sources}, etc.
    currentPart = nil,  -- Currently active part number (1-4) or nil
    syncMode = "direct",  -- "direct", "beat", or "bar"
    syncModes = {"direct", "beat", "bar"},
    syncModeIndex = 1,
    
    -- Timing
    BPM = 110,
    beatDuration = 60 / 110,  -- ~0.545 seconds
    barDuration = (60 / 110) * 4,  -- ~2.181 seconds (4/4 time)
    nextBeatTime = 0,
    nextBarTime = 0,
    pendingPart = nil,  -- Part to switch to on next beat/bar
    currentPlaybackPosition = 0,  -- Current playback position in seconds
    
    -- Visual
    buttonColors = {
        {0.2, 0.8, 0.3},  -- Part 1: Green
        {0.3, 0.2, 0.8},  -- Part 2: Blue
        {0.8, 0.3, 0.2},  -- Part 3: Red
        {0.8, 0.6, 0.2},  -- Part 4: Orange
    },
    backgroundColors = {
        {0.05, 0.15, 0.05},  -- Part 1: Dark green
        {0.05, 0.05, 0.15},  -- Part 2: Dark blue
        {0.15, 0.05, 0.05},  -- Part 3: Dark red
        {0.15, 0.1, 0.05},   -- Part 4: Dark orange
    },
}

-- Load all audio files
function DynamicMusic.load()
    -- Find all Part files
    local partFiles = {}
    for i = 1, 4 do
        partFiles[i] = {}
    end
    
    -- Scan for files
    local files = love.filesystem.getDirectoryItems("assets/dynamicMusic")
    for _, filename in ipairs(files) do
        if filename:match("%.wav$") then
            -- Check which part it belongs to
            for partNum = 1, 4 do
                if filename:match("Part" .. partNum) then
                    local path = "assets/dynamicMusic/" .. filename
                    local success, source = pcall(love.audio.newSource, path, "stream")
                    if success and source then
                        source:setLooping(true)
                        -- Set LiveGuitar track to 50% volume
                        if filename:match("LiveGuitar") then
                            source:setVolume(0.5)
                        end
                        table.insert(partFiles[partNum], source)
                        print("Loaded: " .. filename .. " for Part" .. partNum)
                    else
                        print("Warning: Could not load " .. path)
                    end
                    break
                end
            end
        end
    end
    
    state.parts = partFiles
    
    -- Initialize timing
    state.nextBeatTime = love.timer.getTime() + state.beatDuration
    state.nextBarTime = love.timer.getTime() + state.barDuration
end

-- Open/close sandbox
function DynamicMusic.toggle()
    state.active = not state.active
    if not state.active then
        -- Stop all music when closing
        DynamicMusic.stopAll()
    end
end

-- Close sandbox (called from escape key)
function DynamicMusic.close()
    if state.active then
        state.active = false
        DynamicMusic.stopAll()
    end
end

-- Check if sandbox is active
function DynamicMusic.isActive()
    return state.active
end

-- Check if automatic music is active
function DynamicMusic.isAutomatic()
    return state.automatic
end

-- Start automatic gameplay music (part 1, bar mode)
function DynamicMusic.startAutomatic()
    state.automatic = true
    state.syncMode = "bar"
    state.syncModeIndex = 3  -- "bar" is index 3 in syncModes
    state.currentPlaybackPosition = 0  -- Start from beginning
    DynamicMusic.startPart(1)  -- Start with part 1
    print("DynamicMusic: Started automatic music with part 1")
end

-- Stop automatic gameplay music
function DynamicMusic.stopAutomatic()
    state.automatic = false
    DynamicMusic.stopAll()
end

-- Stop all currently playing parts
function DynamicMusic.stopAll()
    if state.currentPart and state.parts[state.currentPart] then
        for _, source in ipairs(state.parts[state.currentPart]) do
            source:stop()
        end
    end
    state.currentPart = nil
    state.pendingPart = nil
end

-- Check if any part is currently playing
function DynamicMusic.isPlaying()
    if state.currentPart and state.parts[state.currentPart] then
        for _, source in ipairs(state.parts[state.currentPart]) do
            if source:isPlaying() then
                return true
            end
        end
    end
    return false
end

-- Start playing a part (immediate)
function DynamicMusic.startPart(partNum)
    -- Get current playback position before stopping (unless switching to part 4, which should start from beginning)
    if partNum ~= 4 then
        if state.currentPart and state.parts[state.currentPart] and #state.parts[state.currentPart] > 0 then
            local firstSource = state.parts[state.currentPart][1]
            if firstSource:isPlaying() then
                state.currentPlaybackPosition = firstSource:tell("seconds")
            end
        end
    else
        -- Part 4 should always start from the beginning
        state.currentPlaybackPosition = 0
    end
    
    -- Stop current part
    DynamicMusic.stopAll()
    
    -- Start new part
    if partNum >= 1 and partNum <= 4 and state.parts[partNum] then
        local currentTime = love.timer.getTime()
        state.currentPart = partNum
        
        -- Ensure we have a valid playback position
        if not state.currentPlaybackPosition or state.currentPlaybackPosition < 0 then
            state.currentPlaybackPosition = 0
        end
        
        -- Start all sources for this part from the same position
        -- Since all files are in sync, we can seek them all to the same position
        print("DynamicMusic: Starting part " .. partNum .. " at position " .. state.currentPlaybackPosition .. "s")
        print("DynamicMusic: Number of sources for part " .. partNum .. ": " .. #state.parts[partNum])
        for i, source in ipairs(state.parts[partNum]) do
            -- Stop source first in case it was stopped by Sound.cleanup()
            source:stop()
            source:seek(state.currentPlaybackPosition)  -- Seek before playing
            source:play()
            print("DynamicMusic: Started source " .. i .. " for part " .. partNum .. ", isPlaying: " .. tostring(source:isPlaying()))
        end
        
        -- Update next beat/bar times based on current playback position
        -- Calculate how far into the current beat/bar we are
        local positionInBar = state.currentPlaybackPosition % state.barDuration
        local positionInBeat = state.currentPlaybackPosition % state.beatDuration
        state.nextBeatTime = currentTime + (state.beatDuration - positionInBeat)
        state.nextBarTime = currentTime + (state.barDuration - positionInBar)
        
        -- Verify music is actually playing
        local allPlaying = true
        for _, source in ipairs(state.parts[partNum]) do
            if not source:isPlaying() then
                allPlaying = false
                print("DynamicMusic: WARNING - Source not playing for part " .. partNum)
            end
        end
        if allPlaying then
            print("DynamicMusic: All sources playing for part " .. partNum)
        end
    end
end

-- Switch to a part (respects sync mode)
function DynamicMusic.switchToPart(partNum)
    -- Allow switching if either sandbox is active or automatic music is active
    if not state.active and not state.automatic then
        return
    end
    
    if state.syncMode == "direct" then
        DynamicMusic.startPart(partNum)
    else
        -- Queue the switch for next beat or bar
        state.pendingPart = partNum
        
        -- Initialize nextBarTime or nextBeatTime if not set
        local currentTime = love.timer.getTime()
        if state.syncMode == "bar" then
            if state.currentPart and state.parts[state.currentPart] and #state.parts[state.currentPart] > 0 then
                local firstSource = state.parts[state.currentPart][1]
                if firstSource:isPlaying() then
                    state.currentPlaybackPosition = firstSource:tell("seconds")
                    local positionInBar = state.currentPlaybackPosition % state.barDuration
                    state.nextBarTime = currentTime + (state.barDuration - positionInBar)
                    print("DynamicMusic: Set nextBarTime to " .. state.nextBarTime .. " (currentTime: " .. currentTime .. ", positionInBar: " .. positionInBar .. ", barDuration: " .. state.barDuration .. ")")
                else
                    -- Music not playing, set to next bar
                    state.nextBarTime = currentTime + state.barDuration
                    print("DynamicMusic: Music not playing, set nextBarTime to " .. state.nextBarTime)
                end
            else
                -- No current part, set to next bar
                state.nextBarTime = currentTime + state.barDuration
                print("DynamicMusic: No current part, set nextBarTime to " .. state.nextBarTime)
            end
        elseif state.syncMode == "beat" then
            if state.currentPart and state.parts[state.currentPart] and #state.parts[state.currentPart] > 0 then
                local firstSource = state.parts[state.currentPart][1]
                if firstSource:isPlaying() then
                    state.currentPlaybackPosition = firstSource:tell("seconds")
                    local positionInBeat = state.currentPlaybackPosition % state.beatDuration
                    state.nextBeatTime = currentTime + (state.beatDuration - positionInBeat)
                else
                    state.nextBeatTime = currentTime + state.beatDuration
                end
            else
                state.nextBeatTime = currentTime + state.beatDuration
            end
        end
    end
end

-- Cycle sync mode
function DynamicMusic.cycleSyncMode()
    state.syncModeIndex = (state.syncModeIndex % #state.syncModes) + 1
    state.syncMode = state.syncModes[state.syncModeIndex]
    
    -- If we have a pending part and switch to direct, apply it immediately
    if state.syncMode == "direct" and state.pendingPart then
        DynamicMusic.startPart(state.pendingPart)
        state.pendingPart = nil
    end
end

-- Update (check for beat/bar sync)
function DynamicMusic.update(dt)
    -- Update automatic music even if sandbox is not active
    if state.automatic then
        local currentTime = love.timer.getTime()
        
        -- Get game state (access global Game, require Engagement)
        local Engagement = require("src.core.engagement")
        -- Game is a global, access it directly
        
        -- Determine target part based on game state
        local targetPart = nil
        
        -- Check win condition first (highest priority)
        -- Keep playing part 2 during win sequence and level transition
        if Game.winCondition then
            print("DynamicMusic: Win condition detected: " .. tostring(Game.winCondition) .. ", gameState: " .. tostring(Game.gameState))
            targetPart = 2
        -- Check powerup active (puck mode)
        elseif Game.turret and Game.turret.puckModeTimer and Game.turret.puckModeTimer > 0 then
            targetPart = 4
        -- Check engagement < 50%
        elseif Engagement.value < 50 then
            targetPart = 3
        -- Default: part 1 (only when actually playing, not during win/transition)
        else
            -- Only switch to part 1 if we're actually playing or ready (not in win sequence or transition)
            -- "ready" state means the new level is starting, so we can switch to part 1
            if Game.gameState == "playing" or Game.gameState == "ready" then
                targetPart = 1
            else
                -- Keep current part during win/transition sequences
                targetPart = state.currentPart or 1
            end
        end
        
        -- Switch to target part if different from current
        if targetPart ~= state.currentPart then
            -- Use bar sync mode for automatic music
            state.syncMode = "bar"
            print("DynamicMusic: Switching to part " .. targetPart .. " (current: " .. tostring(state.currentPart) .. ")")
            DynamicMusic.switchToPart(targetPart)
        end
        
        -- Update beat/bar timing (but don't overwrite nextBarTime if we have a pending part)
        if state.currentPart and state.parts[state.currentPart] and #state.parts[state.currentPart] > 0 then
            local firstSource = state.parts[state.currentPart][1]
            if firstSource:isPlaying() then
                state.currentPlaybackPosition = firstSource:tell("seconds")
                
                -- Calculate next beat/bar times based on current playback position
                -- But preserve nextBarTime if we have a pending part (waiting for bar sync)
                local positionInBar = state.currentPlaybackPosition % state.barDuration
                local positionInBeat = state.currentPlaybackPosition % state.beatDuration
                state.nextBeatTime = currentTime + (state.beatDuration - positionInBeat)
                
                -- Only update nextBarTime if we don't have a pending part
                -- (if we have a pending part, we're waiting for a specific bar time)
                if not state.pendingPart then
                    state.nextBarTime = currentTime + (state.barDuration - positionInBar)
                end
            elseif state.currentPart and not state.pendingPart then
                -- If music stopped but we have a current part, restart it
                -- This can happen if music was stopped externally
                DynamicMusic.startPart(state.currentPart)
            end
        end
        
        -- If we have a pending part but nextBarTime isn't set or is in the past, initialize it
        if state.pendingPart and (state.nextBarTime == 0 or state.nextBarTime < currentTime) then
            if state.currentPart and state.parts[state.currentPart] and #state.parts[state.currentPart] > 0 then
                local firstSource = state.parts[state.currentPart][1]
                if firstSource:isPlaying() then
                    state.currentPlaybackPosition = firstSource:tell("seconds")
                    local positionInBar = state.currentPlaybackPosition % state.barDuration
                    state.nextBarTime = currentTime + (state.barDuration - positionInBar)
                else
                    -- Music not playing yet, set next bar to happen soon
                    state.nextBarTime = currentTime + state.barDuration
                end
            else
                -- No current part, set next bar to happen soon
                state.nextBarTime = currentTime + state.barDuration
            end
            print("DynamicMusic: Initialized nextBarTime to " .. state.nextBarTime .. " (currentTime: " .. currentTime .. ")")
        end
        
        -- Check if we need to switch on next beat
        if state.syncMode == "beat" and state.pendingPart then
            if currentTime >= state.nextBeatTime then
                DynamicMusic.startPart(state.pendingPart)
                state.pendingPart = nil
            end
        end
        
        -- Check if we need to switch on next bar
        if state.syncMode == "bar" and state.pendingPart then
            -- Use music playback position to determine bar boundaries more accurately
            if state.currentPart and state.parts[state.currentPart] and #state.parts[state.currentPart] > 0 then
                local firstSource = state.parts[state.currentPart][1]
                if firstSource:isPlaying() then
                    local playbackPos = firstSource:tell("seconds")
                    local positionInBar = playbackPos % state.barDuration
                    local nextBarPosition = (math.floor(playbackPos / state.barDuration) + 1) * state.barDuration
                    
                    -- Check if we've crossed a bar boundary (with small tolerance for timing)
                    if playbackPos >= nextBarPosition - 0.05 then  -- 50ms tolerance
                        print("DynamicMusic: EXECUTING bar sync switch to part " .. state.pendingPart .. " (playbackPos: " .. string.format("%.3f", playbackPos) .. ", nextBarPosition: " .. string.format("%.3f", nextBarPosition) .. ")")
                        DynamicMusic.startPart(state.pendingPart)
                        state.pendingPart = nil
                    else
                        local timeUntilBar = nextBarPosition - playbackPos
                        -- Only print occasionally to avoid spam
                        if math.floor(timeUntilBar * 10) % 5 == 0 then
                            print("DynamicMusic: Waiting for bar sync... " .. string.format("%.3f", timeUntilBar) .. "s until next bar (playbackPos: " .. string.format("%.3f", playbackPos) .. ", positionInBar: " .. string.format("%.3f", positionInBar) .. ")")
                        end
                    end
                else
                    -- Music not playing, fall back to time-based check
                    local timeUntilSwitch = state.nextBarTime - currentTime
                    if timeUntilSwitch <= 0 then
                        print("DynamicMusic: EXECUTING bar sync switch (music not playing, using time-based)")
                        DynamicMusic.startPart(state.pendingPart)
                        state.pendingPart = nil
                    end
                end
            else
                -- No current part, use time-based check
                local timeUntilSwitch = state.nextBarTime - currentTime
                if timeUntilSwitch <= 0 then
                    print("DynamicMusic: EXECUTING bar sync switch (no current part, using time-based)")
                    DynamicMusic.startPart(state.pendingPart)
                    state.pendingPart = nil
                end
            end
        end
    end
    
    -- Update sandbox if active
    if not state.active then
        return
    end
    
    local currentTime = love.timer.getTime()
    
    -- Check if we need to switch on next beat
    if state.syncMode == "beat" and state.pendingPart then
        if currentTime >= state.nextBeatTime then
            DynamicMusic.startPart(state.pendingPart)
            state.pendingPart = nil
            state.nextBeatTime = currentTime + state.beatDuration
        end
    end
    
    -- Check if we need to switch on next bar
    if state.syncMode == "bar" and state.pendingPart then
        if currentTime >= state.nextBarTime then
            DynamicMusic.startPart(state.pendingPart)
            state.pendingPart = nil
            state.nextBarTime = currentTime + state.barDuration
        end
    end
    
    -- Update next beat/bar times if we're playing
    if state.currentPart and state.parts[state.currentPart] and #state.parts[state.currentPart] > 0 then
        -- Get current playback position from the first source
        local firstSource = state.parts[state.currentPart][1]
        if firstSource:isPlaying() then
            state.currentPlaybackPosition = firstSource:tell("seconds")
            
            -- Calculate next beat/bar times based on current playback position
            local positionInBar = state.currentPlaybackPosition % state.barDuration
            local positionInBeat = state.currentPlaybackPosition % state.beatDuration
            state.nextBeatTime = currentTime + (state.beatDuration - positionInBeat)
            state.nextBarTime = currentTime + (state.barDuration - positionInBar)
        end
    end
end

-- Draw the sandbox UI
function DynamicMusic.draw()
    if not state.active then
        return
    end
    
    local width = Constants.SCREEN_WIDTH
    local height = Constants.SCREEN_HEIGHT
    
    -- Draw background with color based on current part
    local bgColor = {0.05, 0.05, 0.05}  -- Default dark gray
    if state.currentPart and state.backgroundColors[state.currentPart] then
        bgColor = state.backgroundColors[state.currentPart]
    end
    
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 0.9)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(love.graphics.newFont(48))
    love.graphics.printf("DYNAMIC MUSIC PLAYER", 0, 50, width, "center")
    
    -- Draw sync mode indicator
    love.graphics.setFont(love.graphics.newFont(24))
    local syncText = "SYNC: " .. string.upper(state.syncMode)
    if state.pendingPart then
        syncText = syncText .. " (PENDING: PART " .. state.pendingPart .. ")"
    end
    love.graphics.printf(syncText, 0, 120, width, "center")
    love.graphics.printf("Press P to change sync mode", 0, 150, width, "center")
    
    -- Draw buttons for each part
    local buttonWidth = 200
    local buttonHeight = 200
    local buttonSpacing = 50
    local totalWidth = (buttonWidth * 4) + (buttonSpacing * 3)
    local startX = (width - totalWidth) / 2
    local buttonY = height / 2 - buttonHeight / 2
    
    for partNum = 1, 4 do
        local buttonX = startX + (partNum - 1) * (buttonWidth + buttonSpacing)
        local color = state.buttonColors[partNum]
        local isActive = state.currentPart == partNum
        local isPending = state.pendingPart == partNum
        
        -- Draw button background
        if isActive then
            -- Bright when active
            love.graphics.setColor(color[1], color[2], color[3], 1.0)
        elseif isPending then
            -- Pulsing when pending
            local pulse = (math.sin(love.timer.getTime() * 4) + 1) / 2
            love.graphics.setColor(color[1] * 0.5 + pulse * 0.5, color[2] * 0.5 + pulse * 0.5, color[3] * 0.5 + pulse * 0.5, 0.8)
        else
            -- Dim when inactive
            love.graphics.setColor(color[1] * 0.3, color[2] * 0.3, color[3] * 0.3, 0.6)
        end
        
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 10, 10)
        
        -- Draw button border
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 10, 10)
        
        -- Draw part number
        love.graphics.setFont(love.graphics.newFont(72))
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(tostring(partNum), buttonX, buttonY + 20, buttonWidth, "center")
        
        -- Draw part label
        love.graphics.setFont(love.graphics.newFont(20))
        love.graphics.printf("PART " .. partNum, buttonX, buttonY + buttonHeight - 50, buttonWidth, "center")
        
        -- Draw file count
        local fileCount = #state.parts[partNum]
        if fileCount > 0 then
            love.graphics.setFont(love.graphics.newFont(16))
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.printf(fileCount .. " files", buttonX, buttonY + buttonHeight - 30, buttonWidth, "center")
        end
    end
    
    -- Draw instructions
    love.graphics.setFont(love.graphics.newFont(18))
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("Press 1-4 to play parts | Press ESCAPE to close", 0, height - 80, width, "center")
end

return DynamicMusic

