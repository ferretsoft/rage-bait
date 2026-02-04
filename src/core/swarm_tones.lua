-- src/core/swarm_tones.lua
-- Experimental: red/blue unit swarms generate tones in F pentatonic, synced to music BPM (16th notes).
-- Pitch is derived from average height (Y) on the playfield.

local Constants = require("src.constants")
local DynamicMusic = require("src.core.dynamic_music")
local Sound = require("src.core.sound")

local SwarmTones = {}

-- F (major) pentatonic (F, G, A, C, D) in Hz, one octave starting from F3
local F_PENT = { 174.61, 196.00, 220.00, 261.63, 293.66 }

local lastSixteenthIndex = -1
local fallbackMusicTime = 0  -- When playback position unavailable, advance by dt to keep 16ths
local lastKnownBPM = 110     -- Used when DynamicMusic.getBPM() is nil during a switch
local enabled = true  -- Set to false to disable the effect

-- Per-swarm lifetime tracking: each swarm (red/blue) only generates tones for 1 bar after it appears
local redSwarmStartTime = nil
local blueSwarmStartTime = nil

function SwarmTones.setEnabled(on)
    enabled = on
end

function SwarmTones.isEnabled()
    return enabled
end

-- Map Y position (0 = top, PLAYFIELD_HEIGHT = bottom) to scale index 0..9 (two octaves).
-- Higher on screen (smaller Y) = higher pitch.
local function heightToScaleIndex(y)
    local norm = 1.0 - (y / Constants.PLAYFIELD_HEIGHT)
    norm = math.max(0, math.min(1, norm))
    return math.floor(norm * 10) % 10
end

local function scaleIndexToFrequency(index)
    local degree = index % 5
    local octave = math.floor(index / 5)
    return F_PENT[degree + 1] * (2 ^ octave)
end

-- Get average Y of units by alignment (only non-dead, with body).
local function getAverageY(units, alignment)
    local sum, count = 0, 0
    for _, u in ipairs(units or {}) do
        if not u.isDead and u.body and u.alignment == alignment then
            local _, y = u.body:getPosition()
            sum = sum + y
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return sum / count
end

-- Get average X of units by alignment (only non-dead, with body).
local function getAverageX(units, alignment)
    local sum, count = 0, 0
    for _, u in ipairs(units or {}) do
        if not u.isDead and u.body and u.alignment == alignment then
            local x, _ = u.body:getPosition()
            sum = sum + x
            count = count + 1
        end
    end
    if count == 0 then return nil end
    return sum / count
end

-- Map playfield X (0..PLAYFIELD_WIDTH) to stereo pan (-1..1)
local function xToPan(x)
    local halfW = Constants.PLAYFIELD_WIDTH * 0.5
    if halfW <= 0 then return 0 end
    local centered = x - halfW
    local pan = centered / halfW
    if pan < -1 then pan = -1 elseif pan > 1 then pan = 1 end
    return pan
end

-- Whether any unit of this alignment is currently enraged.
local function hasEnraged(units, alignment)
    for _, u in ipairs(units or {}) do
        if not u.isDead and u.alignment == alignment and u.state == "enraged" then
            return true
        end
    end
    return false
end

-- Update: when we cross a new 16th note, trigger one tone per swarm (red and blue) from current unit positions.
-- Stays active across dynamic music switches: uses cached BPM and handles position jumps.
function SwarmTones.update(dt)
    if not enabled or not Game or not Game.units then return end

    local bpm = DynamicMusic.getBPM()
    if bpm and bpm > 0 then
        lastKnownBPM = bpm
    end
    bpm = lastKnownBPM

    local beatDuration = 60 / bpm
    local sixteenthDuration = beatDuration / 4

    -- Use real playback position when available; when nil (e.g. during music switch), keep advancing fallback
    local pos = DynamicMusic.getPlaybackPosition()
    if pos then
        -- If position jumped backward (music switched to new track), sync so we don't skip 16ths
        if pos < fallbackMusicTime - 0.5 then
            lastSixteenthIndex = math.floor(pos / sixteenthDuration) - 1
        end
        fallbackMusicTime = pos
    else
        fallbackMusicTime = fallbackMusicTime + dt
        if fallbackMusicTime > 3600 then fallbackMusicTime = 0 end
    end

    local currentSixteenth = math.floor(fallbackMusicTime / sixteenthDuration)

    if currentSixteenth <= lastSixteenthIndex then return end
    lastSixteenthIndex = currentSixteenth

    -- 16th-note triggers; each tone fades out over 1 bar then is removed (faster decay)
    local barDuration = beatDuration * 4
    local duration = barDuration * 1  -- 1 bar: faster decay, notes gone sooner
    local vol = 0.10  -- slightly lower global swarm tone level

    -- RED SWARM: start generating when it first appears, stop 1 bar after start
    local redY = getAverageY(Game.units, "red")
    local redX = getAverageX(Game.units, "red")
    if redY then
        if not redSwarmStartTime then
            redSwarmStartTime = fallbackMusicTime
        end
        local elapsed = fallbackMusicTime - redSwarmStartTime
        if elapsed <= barDuration then
            local idx = heightToScaleIndex(redY)
            local freq = scaleIndexToFrequency(idx)
            local degree = idx % 5
            local kind = hasEnraged(Game.units, "red") and "enraged" or "red"
            local thisVol = (kind == "enraged") and (vol * 0.12) or vol
            local pan = redX and xToPan(redX) or 0
            local useFifth = (degree ~= 2)  -- only add fifth when resulting note is in the F pentatonic scale
            Sound.playSwarmTone(freq, duration, thisVol, 1.0, kind, pan, useFifth)
        end
    else
        -- Swarm disappeared; next time it appears it gets a fresh 1-bar window
        redSwarmStartTime = nil
    end

    -- BLUE SWARM: same 1-bar window after it appears
    local blueY = getAverageY(Game.units, "blue")
    local blueX = getAverageX(Game.units, "blue")
    if blueY then
        if not blueSwarmStartTime then
            blueSwarmStartTime = fallbackMusicTime
        end
        local elapsed = fallbackMusicTime - blueSwarmStartTime
        if elapsed <= barDuration then
            local idx = heightToScaleIndex(blueY)
            local freq = scaleIndexToFrequency(idx)
            local degree = idx % 5
            local kind = hasEnraged(Game.units, "blue") and "enraged" or "blue"
            local thisVol = (kind == "enraged") and (vol * 0.12) or vol
            local pan = blueX and xToPan(blueX) or 0
            local useFifth = (degree ~= 2)  -- only add fifth when resulting note is in the F pentatonic scale
            Sound.playSwarmTone(freq, duration, thisVol, 1.0, kind, pan, useFifth)
        end
    else
        blueSwarmStartTime = nil
    end
end

-- Reset 16th index and fallback time when music restarts so we don't trigger a burst
function SwarmTones.reset()
    lastSixteenthIndex = -1
    fallbackMusicTime = 0
    redSwarmStartTime = nil
    blueSwarmStartTime = nil
end

return SwarmTones
