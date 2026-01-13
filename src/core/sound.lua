-- src/core/sound.lua
-- Sound generator and manager for game events

local Sound = {}
local activeSounds = {}  -- Track active sound sources
local loopingSounds = {}  -- Track looping sound sources separately
local musicSource = nil  -- Background music source
local masterVolume = 1.0
local soundsMuted = false  -- Flag to prevent new sounds from playing

-- Sound configuration
local SOUND_CONFIG = {
    -- Volume levels
    MASTER_VOLUME = 1.0,
    SFX_VOLUME = 0.8,
    
    -- Sound generation parameters (for procedural sounds)
    SAMPLE_RATE = 44100,
    BUFFER_SIZE = 1024,
    
    -- Sound mode: "procedural" or "prerecorded"
    -- Set to "prerecorded" to use sound files from assets/sounds/
    MODE = "procedural",
    
    -- Path to sound files (if using prerecorded mode)
    SOUND_PATH = "assets/sounds/",
    
    -- Music file path
    MUSIC_PATH = "assets/music.wav",  -- Background music file
    INTRO_MUSIC_PATH = "assets/intromusic.wav",  -- Intro/attract mode music file
    MUSIC_VOLUME = 0.6,  -- Music volume (lower than SFX to not overpower)
}

-- Helper: Generate a simple tone (sine wave)
local function generateTone(frequency, duration, sampleRate)
    sampleRate = sampleRate or SOUND_CONFIG.SAMPLE_RATE
    local samples = {}
    local numSamples = math.floor(duration * sampleRate)
    
    for i = 1, numSamples do
        local t = (i - 1) / sampleRate
        local value = math.sin(2 * math.pi * frequency * t)
        -- Apply envelope (fade out)
        local envelope = 1.0 - (t / duration)
        envelope = math.max(0, math.min(1, envelope))
        samples[i] = value * envelope
    end
    
    return samples
end

-- Helper: Generate noise
local function generateNoise(duration, sampleRate)
    sampleRate = sampleRate or SOUND_CONFIG.SAMPLE_RATE
    local samples = {}
    local numSamples = math.floor(duration * sampleRate)
    
    for i = 1, numSamples do
        local t = (i - 1) / sampleRate
        local value = (math.random() * 2 - 1)  -- Random between -1 and 1
        -- Apply envelope
        local envelope = 1.0 - (t / duration)
        envelope = math.max(0, math.min(1, envelope))
        samples[i] = value * envelope
    end
    
    return samples
end

-- Helper: Generate whistling sound (high frequency tone, no vibrato)
local function generateWhistle(duration, sampleRate)
    sampleRate = sampleRate or SOUND_CONFIG.SAMPLE_RATE
    local samples = {}
    local numSamples = math.floor(duration * sampleRate)
    local baseFreq = 1200  -- Base whistle frequency
    
    for i = 1, numSamples do
        local t = (i - 1) / sampleRate
        local value = math.sin(2 * math.pi * baseFreq * t)
        -- Add harmonics for richer whistle sound
        value = value + 0.3 * math.sin(2 * math.pi * baseFreq * 2 * t)  -- Second harmonic
        value = value + 0.1 * math.sin(2 * math.pi * baseFreq * 3 * t)  -- Third harmonic
        -- Normalize
        value = value / 1.4
        samples[i] = value
    end
    
    return samples
end

-- Helper: Generate vibrating/oscillating sound for charging
local function generateVibrate(duration, sampleRate)
    sampleRate = sampleRate or SOUND_CONFIG.SAMPLE_RATE
    local samples = {}
    local numSamples = math.floor(duration * sampleRate)
    local baseFreq = 100  -- Base frequency (lowered from 150)
    local vibrateFreq = 15  -- Vibration frequency (faster, increased from 8)
    local vibrateAmount = 30  -- Amount of frequency variation
    
    for i = 1, numSamples do
        local t = (i - 1) / sampleRate
        -- Create vibrating effect with frequency modulation
        local mod = math.sin(2 * math.pi * vibrateFreq * t) * vibrateAmount
        local freq = baseFreq + mod
        local value = math.sin(2 * math.pi * freq * t)
        -- Add some harmonics for richer sound
        value = value + 0.2 * math.sin(2 * math.pi * freq * 2 * t)
        -- Normalize
        value = value / 1.2
        samples[i] = value
    end
    
    return samples
end

-- Helper: Create a sound source from samples
local function createSourceFromSamples(samples, sampleRate)
    sampleRate = sampleRate or SOUND_CONFIG.SAMPLE_RATE
    local soundData = love.sound.newSoundData(#samples, sampleRate, 16, 1)
    
    for i = 1, #samples do
        soundData:setSample(i - 1, samples[i])
    end
    
    local source = love.audio.newSource(soundData, "static")
    return source
end

-- Play a procedural sound
function Sound.playTone(frequency, duration, volume, pitch)
    if soundsMuted then return nil end
    volume = volume or 1.0
    pitch = pitch or 1.0
    local samples = generateTone(frequency, duration)
    local source = createSourceFromSamples(samples, SOUND_CONFIG.SAMPLE_RATE)
    source:setVolume(volume * SOUND_CONFIG.SFX_VOLUME * masterVolume)
    source:setPitch(pitch)
    source:play()
    
    -- Track and clean up when done
    table.insert(activeSounds, {
        source = source,
        duration = duration
    })
    
    return source
end

-- Play noise
function Sound.playNoise(duration, volume, pitch)
    volume = volume or 1.0
    pitch = pitch or 1.0
    local samples = generateNoise(duration)
    local source = createSourceFromSamples(samples, SOUND_CONFIG.SAMPLE_RATE)
    source:setVolume(volume * SOUND_CONFIG.SFX_VOLUME * masterVolume)
    source:setPitch(pitch)
    source:play()
    
    table.insert(activeSounds, {
        source = source,
        duration = duration
    })
    
    return source
end

-- Play whistling sound (looping)
function Sound.playWhistle(volume, pitch, loop)
    if soundsMuted then return nil end
    volume = volume or 1.0
    pitch = pitch or 1.0
    loop = loop or true
    
    if SOUND_CONFIG.MODE == "prerecorded" then
        local file = SOUND_CONFIG.SOUND_PATH .. "bomb_whistle.ogg"
        return Sound.playFile(file, volume, pitch, loop)
    else
        -- Generate a short whistle loop (0.5 seconds, will loop)
        local duration = 0.5
        local samples = generateWhistle(duration)
        local source = createSourceFromSamples(samples, SOUND_CONFIG.SAMPLE_RATE)
        source:setVolume(volume * SOUND_CONFIG.SFX_VOLUME * masterVolume)
        source:setPitch(pitch)
        source:setLooping(loop)
        source:play()
        
        if loop then
            -- Track looping sounds separately
            table.insert(loopingSounds, source)
        else
            table.insert(activeSounds, {
                source = source,
                duration = duration
            })
        end
        
        return source
    end
end

-- Play vibrating/oscillating sound (looping, for bomb charging)
function Sound.playVibrate(volume, pitch, loop)
    if soundsMuted then return nil end
    volume = volume or 1.0
    pitch = pitch or 1.0
    loop = loop or true
    
    if SOUND_CONFIG.MODE == "prerecorded" then
        local file = SOUND_CONFIG.SOUND_PATH .. "bomb_charge.ogg"
        return Sound.playFile(file, volume, pitch, loop)
    else
        -- Generate a short vibrate loop (0.5 seconds, will loop)
        local duration = 0.5
        local samples = generateVibrate(duration)
        local source = createSourceFromSamples(samples, SOUND_CONFIG.SAMPLE_RATE)
        source:setVolume(volume * SOUND_CONFIG.SFX_VOLUME * masterVolume)
        source:setPitch(pitch)
        source:setLooping(loop)
        source:play()
        
        if loop then
            -- Track looping sounds separately
            table.insert(loopingSounds, source)
        else
            table.insert(activeSounds, {
                source = source,
                duration = duration
            })
        end
        
        return source
    end
end

-- Play a sound from a file (if you want to use pre-recorded sounds)
function Sound.playFile(path, volume, pitch, loop)
    if soundsMuted then return nil end
    volume = volume or 1.0
    pitch = pitch or 1.0
    loop = loop or false
    
    local success, source = pcall(love.audio.newSource, path, "static")
    if not success then
        print("Warning: Could not load sound file: " .. tostring(path))
        return nil
    end
    
    source:setVolume(volume * SOUND_CONFIG.SFX_VOLUME * masterVolume)
    source:setPitch(pitch)
    source:setLooping(loop)
    source:play()
    
    if loop then
        -- Track looping sounds separately
        table.insert(loopingSounds, source)
    else
        table.insert(activeSounds, {
            source = source,
            duration = source:getDuration() or 1.0
        })
    end
    
    return source
end

-- Sound effect functions for game events
-- These functions automatically switch between procedural and prerecorded based on MODE
function Sound.firePuck(color)
    if SOUND_CONFIG.MODE == "prerecorded" then
        local file = SOUND_CONFIG.SOUND_PATH .. "fire_puck_" .. color .. ".ogg"
        Sound.playFile(file, 0.6, 1.0, false)
    else
        -- Short, sharp tone for puck firing
        local freq = color == "red" and 400 or 350
        Sound.playTone(freq, 0.05, 0.6, 1.0)
    end
end

function Sound.fireBomb(color)
    if SOUND_CONFIG.MODE == "prerecorded" then
        local file = SOUND_CONFIG.SOUND_PATH .. "fire_bomb_" .. color .. ".ogg"
        Sound.playFile(file, 0.7, 0.8, false)
    else
        -- Deeper, longer tone for bomb charging/release
        local freq = color == "red" and 200 or 180
        Sound.playTone(freq, 0.1, 0.7, 0.8)
    end
end

function Sound.bombExplode(color)
    if SOUND_CONFIG.MODE == "prerecorded" then
        local file = SOUND_CONFIG.SOUND_PATH .. "bomb_explode_" .. color .. ".ogg"
        Sound.playFile(file, 0.8, 1.0, false)
    else
        -- Explosive sound: noise burst with low frequency
        Sound.playNoise(0.2, 0.8, 0.5)
        Sound.playTone(80, 0.3, 0.6, 0.7)  -- Low rumble
    end
end

function Sound.unitHit()
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "unit_hit.ogg", 0.5, 1.2, false)
    else
        -- Quick impact sound
        Sound.playTone(300, 0.03, 0.5, 1.2)
    end
end

function Sound.unitKilled()
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "unit_killed.ogg", 0.6, 0.5, false)
    else
        -- Death sound: descending tone
        Sound.playTone(200, 0.2, 0.6, 0.5)
    end
end

function Sound.powerupCollect(powerupType)
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "powerup_" .. powerupType .. ".ogg", 0.7, 1.5, false)
    else
        -- Collect sound: ascending tone
        Sound.playTone(600, 0.15, 0.7, 1.5)
    end
end

function Sound.bumperActivate()
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "bumper_activate.ogg", 0.6, 1.0, false)
    else
        -- Bumper activation: metallic ping
        Sound.playTone(800, 0.1, 0.6, 1.0)
    end
end

function Sound.bumperHit()
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "bumper_hit.ogg", 0.5, 1.0, false)
    else
        -- Bumper hit: sharp click
        Sound.playTone(1000, 0.05, 0.5, 1.0)
    end
end

-- Play a fanfare (victory sound)
function Sound.playFanfare()
    if soundsMuted then return end
    
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "fanfare.ogg", 0.8, 1.0, false)
    else
        -- Procedural fanfare: ascending notes in a major chord
        -- C major chord: C (523Hz), E (659Hz), G (784Hz), C (1047Hz)
        -- Play notes in quick succession for a celebratory sound
        Sound.playTone(523, 0.2, 0.6, 1.0)  -- C
        Sound.playTone(659, 0.2, 0.6, 1.0)  -- E
        Sound.playTone(784, 0.2, 0.6, 1.0)  -- G
        Sound.playTone(1047, 0.3, 0.8, 1.0) -- High C (longer, louder)
    end
end

-- Update function to clean up finished sounds
function Sound.update(dt)
    for i = #activeSounds, 1, -1 do
        local sound = activeSounds[i]
        if not sound.source:isPlaying() then
            sound.source:stop()
            sound.source:release()
            table.remove(activeSounds, i)
        end
    end
end

-- Set master volume
function Sound.setMasterVolume(volume)
    masterVolume = math.max(0, math.min(1, volume))
    Sound.updateMusicVolume()  -- Update music volume when master volume changes
end

-- Get master volume
function Sound.getMasterVolume()
    return masterVolume
end

-- Initialize sound system
function Sound.init()
    -- Set up event listeners
    local Event = require("src.core.event")
    
    Event.on("bomb_exploded", function(data)
        Sound.bombExplode(data.color)
    end)
    
    Event.on("unit_killed", function(data)
        Sound.unitKilled()
    end)
    
    -- Note: Direct calls for firing will be added in turret.lua
    -- Powerup collection will be added in main.lua
end

-- Clean up all sounds
function Sound.cleanup()
    -- Mute all new sounds first
    soundsMuted = true
    
    -- Stop music
    Sound.stopMusic()
    
    -- First, aggressively stop ALL audio sources immediately
    love.audio.stop()
    
    -- Then stop and release all active sounds
    for _, sound in ipairs(activeSounds) do
        local source = sound.source
        if source then
            pcall(function()
                source:stop()
                source:release()
            end)
        end
    end
    activeSounds = {}
    
    -- Stop and release all looping sounds
    for _, source in ipairs(loopingSounds) do
        if source then
            pcall(function()
                source:stop()
                source:release()
            end)
        end
    end
    loopingSounds = {}
end

-- Unmute sounds (call when starting a new game)
function Sound.unmute()
    soundsMuted = false
end

-- Play background music (looping)
function Sound.playMusic()
    -- Stop existing music if playing
    if musicSource then
        pcall(function()
            musicSource:stop()
            musicSource:release()
        end)
        musicSource = nil
    end
    
    -- Try to load and play music file
    local success, source = pcall(love.audio.newSource, SOUND_CONFIG.MUSIC_PATH, "stream")
    if success and source then
        musicSource = source
        musicSource:setLooping(true)
        musicSource:setVolume(SOUND_CONFIG.MUSIC_VOLUME * masterVolume)
        musicSource:play()
        return musicSource
    else
        print("Warning: Could not load music file: " .. tostring(SOUND_CONFIG.MUSIC_PATH))
        return nil
    end
end

-- Play intro/attract mode music (looping)
function Sound.playIntroMusic()
    -- Ensure sounds are not muted
    soundsMuted = false
    
    -- Stop existing music if playing
    if musicSource then
        pcall(function()
            musicSource:stop()
            musicSource:release()
        end)
        musicSource = nil
    end
    
    -- Try to load and play intro music file
    local success, source = pcall(love.audio.newSource, SOUND_CONFIG.INTRO_MUSIC_PATH, "stream")
    if success and source then
        musicSource = source
        musicSource:setLooping(true)
        musicSource:setVolume(SOUND_CONFIG.MUSIC_VOLUME * masterVolume)
        musicSource:play()
        return musicSource
    else
        print("Warning: Could not load intro music file: " .. tostring(SOUND_CONFIG.INTRO_MUSIC_PATH))
        return nil
    end
end

-- Stop background music
function Sound.stopMusic()
    if musicSource then
        pcall(function()
            musicSource:stop()
            musicSource:release()
        end)
        musicSource = nil
    end
end

-- Update music volume if master volume changes
function Sound.updateMusicVolume()
    if musicSource then
        musicSource:setVolume(SOUND_CONFIG.MUSIC_VOLUME * masterVolume)
    end
end

return Sound

