-- src/core/sound.lua
-- Sound generator and manager for game events

local Sound = {}
local activeSounds = {}  -- Track active sound sources (oldest at index 1)
local loopingSounds = {}  -- Track looping sound sources separately
local musicSource = nil  -- Background music source
local writehumSource = nil  -- Looping hum when auditor text trace is active (starts at 10s)
local WRITEHUM_SEEK = 10.0  -- Start playback from 10 seconds into the file
local masterVolume = 1.0
local soundsMuted = false  -- Flag to prevent new sounds from playing
local scheduledSounds = {}  -- { { delay, fn }, ... } for delayed playback (e.g. click-clack)

-- LÖVE has a limit on simultaneous sources (~64). Keep under cap so new sounds (e.g. swarm tones) always play.
local MAX_ACTIVE_SOUNDS = 52
local TARGET_ACTIVE_BEFORE_PLAY = 56  -- Cull until active count is below this before adding (if getActiveSourceCount available)

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
    -- SoundFX folder (mixed formats: coin, shotgun, rapidfire)
    SOUNDFX_PATH = "assets/soundfx/",
    
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

-- Swarm tone variants: blue = rounder (sine + soft 2nd harmonic), enraged = aggressive (harmonics + punchy envelope)
local function generateToneBlue(frequency, duration, sampleRate)
    sampleRate = sampleRate or SOUND_CONFIG.SAMPLE_RATE
    local samples = {}
    local numSamples = math.floor(duration * sampleRate)
    for i = 1, numSamples do
        local t = (i - 1) / sampleRate
        local s1 = math.sin(2 * math.pi * frequency * t)
        local s2 = math.sin(2 * math.pi * frequency * 2 * t)
        local value = s1 + 0.22 * s2
        local envelope = 1.0 - (t / duration)
        envelope = math.max(0, math.min(1, envelope))
        samples[i] = (value / 1.22) * envelope
    end
    return samples
end

local function generateToneEnraged(frequency, duration, sampleRate, useFifth)
    sampleRate = sampleRate or SOUND_CONFIG.SAMPLE_RATE
    local samples = {}
    local numSamples = math.floor(duration * sampleRate)
    local fifthFreq = frequency * 1.5  -- perfect fifth above
    local enableFifth = (useFifth ~= false)
    for i = 1, numSamples do
        local t = (i - 1) / sampleRate
        -- Sawtooth for base (always) and its fifth (optional)
        local phase1 = (t * frequency) % 1
        local saw1 = 2 * phase1 - 1
        local value = saw1
        if enableFifth then
            local phase2 = (t * fifthFreq) % 1
            local saw2 = 2 * phase2 - 1
            value = value + 0.8 * saw2
        end
        -- Aggressive envelope: fast attack, quicker decay than linear
        local x = t / duration
        local envelope = 1.0 - x * x
        envelope = math.max(0, math.min(1, envelope))
        -- Small noise for extra grit
        local noise = (math.random() * 2 - 1) * 0.04 * envelope
        samples[i] = (value / (enableFifth and 1.8 or 1.2)) * envelope + noise
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

-- Helper: Create a stereo source from mono samples with pan (-1 = left, 0 = center, 1 = right)
local function createSourceFromSamplesStereo(samples, sampleRate, pan)
    sampleRate = sampleRate or SOUND_CONFIG.SAMPLE_RATE
    pan = math.max(-1, math.min(1, pan or 0))
    local numSamples = #samples
    local soundData = love.sound.newSoundData(numSamples, sampleRate, 16, 2)
    -- Equal-power panning
    local angle = (pan + 1) * (math.pi / 4)
    local leftGain = math.cos(angle)
    local rightGain = math.sin(angle)
    for i = 1, numSamples do
        local v = samples[i]
        soundData:setSample(i - 1, 1, v * leftGain)
        soundData:setSample(i - 1, 2, v * rightGain)
    end
    local source = love.audio.newSource(soundData, "static")
    return source
end

local function releaseOldestActive()
    if #activeSounds == 0 then return false end
    local s = activeSounds[1]
    table.remove(activeSounds, 1)
    pcall(function() s.source:stop(); s.source:release() end)
    return true
end

local function makeRoomForSources(need)
    need = need or 1
    local getCount = love.audio.getActiveSourceCount
    if type(getCount) ~= "function" then getCount = nil end
    while #activeSounds > 0 do
        if getCount then
            local n = getCount()
            if n + need <= TARGET_ACTIVE_BEFORE_PLAY then break end
        end
        if not releaseOldestActive() then break end
    end
end

-- Play a procedural sound
function Sound.playTone(frequency, duration, volume, pitch)
    if soundsMuted then return nil end
    makeRoomForSources(1)
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

-- Play swarm tone with timbre: "red" (sine), "blue" (rounder), "enraged" (aggressive), with optional stereo pan (-1..1)
-- For enraged tones, useFifth controls whether the perfect fifth is added.
function Sound.playSwarmTone(frequency, duration, volume, pitch, kind, pan, useFifth)
    if soundsMuted then return nil end
    makeRoomForSources(2)
    volume = volume or 1.0
    pitch = pitch or 1.0
    kind = kind or "red"
    local samples
    if kind == "blue" then
        samples = generateToneBlue(frequency, duration)
    elseif kind == "enraged" then
        samples = generateToneEnraged(frequency, duration, SOUND_CONFIG.SAMPLE_RATE, useFifth)
    else
        samples = generateTone(frequency, duration)
    end
    local source
    if pan and pan ~= 0 then
        source = createSourceFromSamplesStereo(samples, SOUND_CONFIG.SAMPLE_RATE, pan)
    else
        source = createSourceFromSamples(samples, SOUND_CONFIG.SAMPLE_RATE)
    end
    source:setVolume(volume * SOUND_CONFIG.SFX_VOLUME * masterVolume)
    source:setPitch(pitch)
    source:play()
    table.insert(activeSounds, { source = source, duration = duration })
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

-- Voice line queue: only one TTS line plays at a time; others are queued.
local voiceLineQueue = {}
local currentVoiceSource = nil

-- Play a pre-generated TTS line (e.g. from scripts/generate_auditor_voice.ps1).
-- Queued: only one line plays at a time; further calls enqueue.
-- Key is the filename without extension: CRITICAL_ERROR, LIFE_LOST, LIFE_LOST_TEXT, GAME_OVER_TEXT, VERDICT_1, VERDICT_2,
-- DEFINE_YOURSELF, WELCOME_TO_RAGE_BAIT, GET_READY, PLEASE_INCREASE_ENGAGEMENT, POWER_UP_ACQUIRED, BONUS_MULTIPLIER, HOSTILITY_SPIKE.
function Sound.playAuditorLine(key)
    if not key or key == "" then return nil end
    local path = "assets/voice/" .. key .. ".wav"
    if not love.filesystem.getInfo(path, "file") then
        return nil
    end
    table.insert(voiceLineQueue, key)
    return true
end

-- Start the next queued voice line (called from Sound.update when current finishes).
local function playNextVoiceLine()
    if #voiceLineQueue == 0 then return end
    local key = table.remove(voiceLineQueue, 1)
    local path = "assets/voice/" .. key .. ".wav"
    local success, source = pcall(love.audio.newSource, path, "static")
    if not success or not source then return end
    source:setVolume(1.0 * SOUND_CONFIG.SFX_VOLUME * masterVolume)
    source:setPitch(1.0)
    source:play()
    currentVoiceSource = source
end

-- Play a sound from a file (if you want to use pre-recorded sounds)
function Sound.playFile(path, volume, pitch, loop)
    if soundsMuted then return nil end
    makeRoomForSources(1)
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
-- Rapid fire (puck) mode uses soundfx/rapidfire when present; else per-color or procedural
function Sound.firePuck(color)
    local rapidfireFile = SOUND_CONFIG.SOUNDFX_PATH .. "rapidfire.wav"
    if love.filesystem.getInfo(rapidfireFile, "file") then
        Sound.playFile(rapidfireFile, 0.2, 1.0, false)
    elseif SOUND_CONFIG.MODE == "prerecorded" then
        local file = SOUND_CONFIG.SOUND_PATH .. "fire_puck_" .. color .. ".ogg"
        if love.filesystem.getInfo(file, "file") then
            Sound.playFile(file, 0.6, 1.0, false)
        else
            local freq = color == "red" and 392.00 or 349.23
            Sound.playTone(freq, 0.05, 0.6, 1.0)
        end
    else
        local freq = color == "red" and 392.00 or 349.23
        Sound.playTone(freq, 0.05, 0.6, 1.0)
    end
end

function Sound.fireBomb(color)
    if SOUND_CONFIG.MODE == "prerecorded" then
        local file = SOUND_CONFIG.SOUND_PATH .. "fire_bomb_" .. color .. ".ogg"
        Sound.playFile(file, 0.7, 0.8, false)
    else
        -- Deeper, longer tone for bomb charging/release (quantized to F major pentatonic)
        -- Red: G3 (~196 Hz), Blue: F3 (~174.61 Hz)
        local freq = color == "red" and 196.00 or 174.61
        Sound.playTone(freq, 0.1, 0.7, 0.8)
    end
end

-- Shotgun: boom (fire); asset from soundfx when present
function Sound.fireShotgun(color)
    local file = SOUND_CONFIG.SOUNDFX_PATH .. "shotgunfire.mp3"
    if love.filesystem.getInfo(file, "file") then
        Sound.playFile(file, 0.8, 1.0, false)
    elseif SOUND_CONFIG.MODE == "prerecorded" then
        local ogg = SOUND_CONFIG.SOUND_PATH .. "shotgun_fire.ogg"
        if love.filesystem.getInfo(ogg, "file") then
            Sound.playFile(ogg, 0.8, 1.0, false)
        else
            Sound.fireBomb(color)
        end
    else
        Sound.playNoise(0.12, 0.85, 0.6)
        local freq = color == "red" and 98.00 or 87.31  -- G2 / F2
        Sound.playTone(freq, 0.15, 0.7, 0.75)
    end
end

function Sound.shotgunReloadReady()
    if soundsMuted then return end
    local file = SOUND_CONFIG.SOUNDFX_PATH .. "reload.wav"
    if love.filesystem.getInfo(file, "file") then
        Sound.playFile(file, 0.9, 1.0, false)
    else
        local ogg = SOUND_CONFIG.SOUND_PATH .. "shotgun_reload.ogg"
        if love.filesystem.getInfo(ogg, "file") then
            Sound.playFile(ogg, 0.9, 1.0, false)
        else
            Sound.playNoise(0.06, 0.95, 1.2)
            table.insert(scheduledSounds, { delay = 0.1, fn = function()
                Sound.playNoise(0.08, 0.9, 0.85)
            end })
        end
    end
end

function Sound.bombExplode(color)
    if SOUND_CONFIG.MODE == "prerecorded" then
        local file = SOUND_CONFIG.SOUND_PATH .. "bomb_explode_" .. color .. ".ogg"
        Sound.playFile(file, 0.8, 1.0, false)
    else
        -- Explosive sound: noise burst with low, in-scale rumble (D2 ~73.42 Hz)
        Sound.playNoise(0.2, 0.8, 0.5)
        Sound.playTone(73.42, 0.3, 0.6, 0.7)  -- Low rumble on D
    end
end

-- Loud countdown beep for rage bait canister (3, 2, 1...)
function Sound.rageBaitCountdownBeep()
    if SOUND_CONFIG.MODE == "prerecorded" then
        -- Use a generic alert if no dedicated file
        Sound.playTone(880, 0.12, 0.95, 1.0)
    else
        Sound.playTone(880, 0.12, 0.95, 1.0)  -- Loud, bright A5
    end
end

-- Coin slot sound (insert credit)
function Sound.playCoinInsert()
    local file = SOUND_CONFIG.SOUNDFX_PATH .. "coin-slot-load.wav"
    if love.filesystem.getInfo(file, "file") then
        Sound.playFile(file, 0.7, 1.0, false)
    else
        Sound.playTone(1318, 0.06, 0.7, 1.0)   -- E6
        Sound.playTone(988, 0.1, 0.6, 0.9)     -- B5, slightly longer
    end
end

function Sound.unitHit()
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "unit_hit.ogg", 0.5, 1.2, false)
    else
        -- Quick impact sound (D4 ~293.66 Hz)
        Sound.playTone(293.66, 0.03, 0.5, 1.2)
    end
end

function Sound.unitKilled()
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "unit_killed.ogg", 0.6, 0.5, false)
    else
        -- Death sound: descending tone starting on G3 (~196 Hz)
        Sound.playTone(196.00, 0.2, 0.6, 0.5)
    end
end

function Sound.powerupCollect(powerupType)
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "powerup_" .. powerupType .. ".ogg", 0.7, 1.5, false)
    else
        -- Collect sound: ascending tone (D5 ~587.33 Hz)
        Sound.playTone(587.33, 0.15, 0.7, 1.5)
    end
end

function Sound.bumperActivate()
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "bumper_activate.ogg", 0.6, 1.0, false)
    else
        -- Bumper activation: metallic ping (G5 ~784 Hz)
        Sound.playTone(784.00, 0.1, 0.6, 1.0)
    end
end

function Sound.bumperHit()
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "bumper_hit.ogg", 0.5, 1.0, false)
    else
        -- Bumper hit: sharp click (C6 ~1046.50 Hz)
        Sound.playTone(1046.50, 0.05, 0.5, 1.0)
    end
end

-- Play a fanfare (victory sound)
function Sound.playFanfare()
    if soundsMuted then return end
    
    if SOUND_CONFIG.MODE == "prerecorded" then
        Sound.playFile(SOUND_CONFIG.SOUND_PATH .. "fanfare.ogg", 0.8, 1.0, false)
    else
        -- Procedural fanfare: ascending notes in F major pentatonic (F, A, C, D)
        -- F4 (~349 Hz), A4 (~440 Hz), C5 (~523.25 Hz), D5 (~587.33 Hz)
        Sound.playTone(349.23, 0.2, 0.6, 1.0)   -- F
        Sound.playTone(440.00, 0.2, 0.6, 1.0)   -- A
        Sound.playTone(523.25, 0.2, 0.6, 1.0)   -- C
        Sound.playTone(587.33, 0.3, 0.8, 1.0)   -- D (longer, louder)
    end
end

-- Update function to clean up finished sounds and cap total for polyphony
function Sound.update(dt)
    -- Scheduled delayed sounds (e.g. shotgun reload clack)
    for i = #scheduledSounds, 1, -1 do
        local s = scheduledSounds[i]
        s.delay = s.delay - dt
        if s.delay <= 0 then
            if s.fn then s.fn() end
            table.remove(scheduledSounds, i)
        end
    end

    -- Voice queue: when current line finishes, play next
    if currentVoiceSource then
        if not currentVoiceSource:isPlaying() then
            currentVoiceSource:stop()
            currentVoiceSource:release()
            currentVoiceSource = nil
            playNextVoiceLine()
        end
    else
        playNextVoiceLine()
    end

    for i = #activeSounds, 1, -1 do
        local sound = activeSounds[i]
        if not sound.source:isPlaying() then
            sound.source:stop()
            sound.source:release()
            table.remove(activeSounds, i)
        end
    end
    -- Cap total so we don't accumulate and hit engine limit (keeps swarm tones audible)
    while #activeSounds > MAX_ACTIVE_SOUNDS do
        releaseOldestActive()
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
    
    -- Stop and release writehum
    Sound.stopWritehum()
    if writehumSource then
        pcall(function() writehumSource:release() end)
        writehumSource = nil
    end
    
    -- Clear voice line queue and stop current voice
    voiceLineQueue = {}
    if currentVoiceSource then
        pcall(function() currentVoiceSource:stop(); currentVoiceSource:release() end)
        currentVoiceSource = nil
    end
    
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

-- Mute sounds (prevent new sounds from playing)
function Sound.mute()
    soundsMuted = true
    -- Stop music
    Sound.stopMusic()
    voiceLineQueue = {}
    if currentVoiceSource then
        pcall(function() currentVoiceSource:stop(); currentVoiceSource:release() end)
        currentVoiceSource = nil
    end
    -- Stop all active sounds
    love.audio.stop()
    -- Clear active sounds list
    activeSounds = {}
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

-- Set music volume directly (for fading)
function Sound.setMusicVolume(volume)
    if musicSource then
        -- Volume should be between 0 and 1, and will be multiplied by master volume
        local targetVolume = math.max(0, math.min(1, volume))
        musicSource:setVolume(targetVolume * masterVolume)
    end
end

-- Get current music volume (returns the base volume, not accounting for master)
function Sound.getMusicVolume()
    if musicSource then
        -- Return the base volume (divide by masterVolume to get original)
        return musicSource:getVolume() / masterVolume
    end
    return SOUND_CONFIG.MUSIC_VOLUME
end

-- Writehum: play from 10s mark only when auditor text trace is active (life lost / game over)
function Sound.startWritehum()
    if soundsMuted then return end
    local path = SOUND_CONFIG.SOUNDFX_PATH .. "writehum.mp3"
    if not love.filesystem.getInfo(path, "file") then return end
    if not writehumSource then
        local ok, src = pcall(love.audio.newSource, path, "stream")
        if not ok or not src then return end
        writehumSource = src
        writehumSource:setLooping(true)
        writehumSource:setVolume(0.5 * SOUND_CONFIG.SFX_VOLUME * masterVolume)
    end
    if not writehumSource:isPlaying() then
        writehumSource:seek(WRITEHUM_SEEK)
        writehumSource:play()
    end
end

function Sound.stopWritehum()
    if writehumSource then
        pcall(function()
            if writehumSource:isPlaying() then
                writehumSource:stop()
            end
        end)
    end
end

return Sound

