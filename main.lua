                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        -- Check for export-spider command-line argument at the top level
for i, arg in ipairs(arg) do
    if arg == "--export-spider" then
        -- Load and run the export script (it will define its own love.load/draw)
        local chunk, err = loadfile("export_spider_graphics.lua")
        if chunk then
            chunk()
            -- Exit early - don't load the rest of main.lua
            return
        else
            print("Error loading export script: " .. tostring(err))
            os.exit(1)
        end
    end
end

local Constants = require("src.constants")
local Event = require("src.core.event")
local Engagement = require("src.core.engagement")
local World = require("src.core.world")
local Time = require("src.core.time")
local Sound = require("src.core.sound")
local EmojiSprites = require("src.core.emoji_sprites")
local Webcam = require("src.core.webcam")
local EngagementPlot = require("src.core.engagement_plot")
local AttractMode = require("src.core.attract_mode")
local DemoMode = require("src.core.demo_mode")
local WindowFrame = require("src.core.window_frame")
local Unit = require("src.entities.unit")
local Turret = require("src.entities.turret")
local Projectile = require("src.entities.projectile")
local PowerUp = require("src.entities.powerup")
local moonshine = require("libs.moonshine")
local ChasePaxton = require("src.core.chase_paxton")
local Auditor = require("src.core.auditor")
local Popups = require("src.core.popups")
local TopBanner = require("src.core.top_banner")
local MonitorFrame = require("src.core.monitor_frame")
local EntityManager = require("src.core.entity_manager")
local CRTManager = require("src.core.crt_manager")
local InputHandler = require("src.core.input_handler")
local ChasePortrait = require("src.core.chase_portrait")
local DrawLayers = require("src.core.draw_layers")
local Godray = require("src.core.godray")
local TextTrace = require("src.core.text_trace")
local DynamicMusic = require("src.core.dynamic_music")
local MatrixEffect = require("src.core.matrix_effect")
local HighScores = require("src.core.high_scores")
local ParticleSystem = require("src.core.particle_system")
local DrawingHelpers = require("src.core.drawing_helpers")
local Doomscroll = require("src.core.doomscroll")
local ToxicSplat = require("src.core.toxic_splat")
local BootingScreen = require("src.screens.booting_screen")
local LogoScreen = require("src.screens.logo_screen")
local IntroVideoScreen = require("src.screens.intro_video_screen")
-- Set BASE so moonshine can find effects in libs directory
moonshine.BASE = "libs"

Game = {
    -- Entity lists
    units = {},
    projectiles = {},
    powerups = {},
    effects = {}, 
    hazards = {},
    explosionZones = {}, 
    turret = nil,
    
    -- Core gameplay state
    score = 0,
    lives = 3,
    level = 1,
    shake = 0,
    logicTimer = 0,
    isUpgraded = false,
    powerupSpawnTimer = 0,
    timeScale = 1.0,  -- Current time scale (1.0 = normal, 0.0 = frozen)
    previousEngagementAtMax = false,  -- Track if engagement was at max last frame (prevents retriggering)
    
    -- Assets
    assets = {
        background = nil,
        foreground = nil,
        logo = nil,  -- Company logo image
        logoBlink = nil,  -- Company logo blink image
        splash = nil,  -- Splash screen image for attract mode
        introVideo = nil,  -- Intro video object
    },
    showBackgroundForeground = false,  -- Toggle for background/foreground layers
    
    -- Screen modes
    modes = {
        booting = false,  -- Start with booting screen (disabled)
        matrix = false,  -- Matrix effect screen (before logo)
        logo = false,  -- Logo screen (after matrix)
        attract = false,  -- Attract mode (after logo)
        joystickTest = false,  -- Joystick test screen (accessible from attract mode)
        demo = false,  -- Demo mode (AI-controlled gameplay with tutorial)
        video = false,  -- Intro video mode (plays before intro screen)
        intro = false,  -- Intro screen mode
        auditor = false,  -- Whether THE AUDITOR sequence is active (final game over only)
        lifeLostAuditor = false,  -- Whether life lost auditor screen is active (engagement depleted but lives remain)
        gameOver = false,  -- Whether game over screen is active
        nameEntry = false,  -- Whether name entry screen is active
        ready = false,  -- Whether ready screen is active
        winText = false,  -- Whether win text is showing (before webcam)
    },
    
    -- Timers
    timers = {
        booting = 0,
        matrix = 0,
        logo = 0,
        previousLogo = 0,  -- Track previous timer value to detect threshold crossings
        attract = 0,
        demo = 0,
        demoAI = 0,
        intro = 0,
        introMusicFade = 0,
        auditor = 0,
        lifeLostAuditor = 0,
        levelTransition = 0,
        webcamWindowAnim = 0,
        webcamWindowDialogue = 0,
        webcamWindowDialogueSentence = 0,
        levelCompleteScreen = 0,
        winText = 0,
        slowMo = 0,
        gameOver = 0,
        pointMultiplier = 0,
        pointMultiplierFlash = 0,
        pointMultiplierText = 0,
        rapidFireText = 0,
        glitchText = 0,
        ready = 0,
    },
    
    -- Logo screen state
    logo = {
        fanfarePlayed = false,  -- Track if fanfare has been played
    },
    
    -- Demo mode state
    demo = {
        step = 1,  -- Current tutorial step
        targetUnit = nil,  -- Current target unit for AI
        charging = false,  -- Whether AI is currently charging
        actionComplete = false,  -- Whether current step's action is complete
        waitingForMessage = true,  -- Whether waiting for message to be shown
        unitConverted = false,  -- Track if a unit was converted (for verification)
        unitEnraged = false,  -- Track if a unit was enraged (for verification)
        unitsFighting = false,  -- Track if units are fighting (for verification)
    },
    
    -- Intro video/music fade state
    intro = {
        musicFadeActive = false,  -- Whether intro music fade is active
        musicFadeStartVolume = 0.6,  -- Starting volume for fade (from SOUND_CONFIG.MUSIC_VOLUME)
        musicFadeTargetVolume = 0.3,  -- Target volume (50% of start)
        step = 1,  -- Current intro step/page
    },
    
    -- Auditor sequences
    auditor = {
        phase = 1,  -- Current phase of THE AUDITOR sequence (1=freeze, 2=fade, 3=verdict, 4=crash)
    },
    lifeLostAuditor = {
        phase = 1,  -- Current phase of life lost auditor (1=freeze, 2=fade, 3=life lost, 4=restart)
    },
    
    -- Level transitions
    levelTransition = {
        active = false,  -- Whether level transition is active
        matrixActive = false,  -- Whether matrix wipe transition is active
    },
    
    -- Webcam window animation and dialogue
    webcamWindow = {
        animating = false,  -- Whether webcam window is animating
        animDuration = 1.0,  -- Duration of webcam window animation (one way)
        reversing = false,  -- Whether animation is reversing back
        dialogueActive = false,  -- Whether dialogue is showing (window centered)
        dialogueDuration = 5.0,  -- How long to show dialogue
        dialogueSentences = {},  -- Array of sentences to display
        dialogueCurrentSentence = 1,  -- Current sentence index (1-based)
        dialogueSentenceDuration = 2.0,  -- How long to show each sentence
    },
    
    -- Level completion
    levelComplete = {
        screenActive = false,  -- Whether level completion screen is active
    },
    
    -- Slow motion
    slowMo = {
        active = false,  -- Whether slow-motion ramp is active
        duration = 1.5,  -- Duration of slow-motion ramp (1.5 seconds)
    },
    
    -- Point multiplier
    pointMultiplier = {
        value = 1,  -- Current point multiplier (incremental)
        active = false,  -- Whether point multiplier is active
        sparks = {},  -- Spark particles for multiplier effect
    },
    
    -- Rapid fire effect
    rapidFire = {
        sparks = {},  -- Spark particles for rapid fire effect
    },
    
    -- Name entry
    nameEntry = {
        text = "",  -- Current name being entered (array of characters)
        cursor = 1,  -- Current cursor position (1-based)
        maxLength = 3,  -- Maximum name length (arcade style, usually 3)
        charSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789",  -- Available characters
        charIndex = {},  -- Current character index for each position
    },
    
    -- Joystick input
    joystick = {
        button1Pressed = false,  -- Track if joystick button 1 is currently pressed (for charge/release)
        button2Pressed = false,  -- Track if joystick button 2 is currently pressed (for charge/release)
    },
    
    -- Visual effects
    visualEffects = {
        glitchTextWriteProgress = 0,  -- Progress of write-on effect (0-1)
    },
    
    -- Ready screen
    ready = {
        phase = 1,  -- Current phase (1=fade out, 2=get ready, 3=go)
        sparks = {},  -- Spark particles for ready screen
    },
    
    -- High scores
    highScores = {},  -- List of high scores {name, score}
    
    -- Rendering
    crtOutputCanvas = nil,  -- Canvas to capture CRT output for fullscreen scaling
    fonts = {
        small = nil,
        medium = nil,
        large = nil,
        terminal = nil,  -- Monospace font for terminal text
        speechBubble = nil,  -- Font for speech bubbles (18px)
        multiplierGiant = nil  -- Giant font for multiplier/ready text (80px)
    },
    
    -- Debug
    debugMode = false,  -- Debug mode (enables instant win/lose)
    
    -- Win condition (set during gameplay)
    winCondition = nil,
}

-- Spark particle functions now use ParticleSystem module

-- --- HELPER: ACTIVATE POWERUP ---
local function collectPowerUp(powerup)
    if powerup.isDead then return end
    local px, py = powerup.body:getPosition()
    powerup:hit() -- Destroy powerup entity
    
    if powerup.powerupType == "puck" then
        -- Puck mode powerup
        if Game.turret then
            Game.turret:activatePuckMode(Constants.POWERUP_DURATION)
            
            -- Activate rapid fire text effect
            Game.timers.rapidFireText = 3.0  -- Text display duration (3 seconds before fade)
            Game.shake = math.max(Game.shake, 1.5)  -- Screen shake
            
            -- Create spark particles for the rapid fire effect
            local centerX = Constants.SCREEN_WIDTH / 2
            local centerY = Constants.SCREEN_HEIGHT / 2 - 100
            Game.rapidFire.sparks = ParticleSystem.createSparks(
                centerX, centerY,
                Constants.UI.SPARK_COUNT_MULTIPLIER,
                Constants.UI.SPARK_SPEED_MIN,
                Constants.UI.SPARK_SPEED_MAX,
                Constants.UI.SPARK_SIZE_MIN,
                Constants.UI.SPARK_SIZE_MAX,
                Constants.UI.SPARK_LIFETIME
            )
            
            -- Visual effect (Gold Explosion)
            table.insert(Game.effects, {
                type = "explosion",
                x = px, y = py,
                radius = 0, maxRadius = 100,
                color = "gold", alpha = 1.0, timer = 0.5
            })
            
            -- Sound effect
            Sound.powerupCollect("puck")
            Webcam.showComment("powerup_collected")
        end
    end
end

-- --- PHYSICS COLLISION CALLBACKS ---

local function beginContact(a, b, coll)
    local objA = a:getUserData()
    local objB = b:getUserData()
    if not objA or not objB then return end

    -- CASE 1: UNIT vs UNIT (Bouncing & Damage)
    if objA.type == "unit" and objB.type == "unit" then
        if objA.state == "neutral" or objB.state == "neutral" then return end
        if objA.alignment == objB.alignment then return end
        
        objA:takeDamage(1, objB); objB:takeDamage(1, objA)
        Game.score = Game.score + (Constants.SCORE_HIT * 2 * Game.pointMultiplier.value)
        Engagement.add(Constants.ENGAGEMENT_REFILL_HIT * 2)
        Sound.unitHit()
        
        local vxA, vyA = objA.body:getLinearVelocity()
        local vxB, vyB = objB.body:getLinearVelocity()
        local speedA = math.sqrt(vxA^2 + vyA^2)
        local speedB = math.sqrt(vxB^2 + vyB^2)
        if speedA > speedB + 150 then objA.body:setLinearVelocity(-vxA*0.3, -vyA*0.3)
        elseif speedB > speedA + 150 then objB.body:setLinearVelocity(-vxB*0.3, -vyB*0.3) end
        return
    end
    
    -- CASE 2: PROJECTILE vs UNIT
    local unit, proj
    if objA.type == "unit" and objB.type == "projectile" then unit = objA; proj = objB
    elseif objB.type == "unit" and objA.type == "projectile" then unit = objB; proj = objA end
    
    if unit and proj then
        if proj.weaponType == "puck" then
            local wasNeutral = unit.state == "neutral"
            unit:hit("puck", proj.color)
            -- Track if a unit was converted from neutral
            if wasNeutral and unit.state == "passive" then
                Game.hasUnitBeenConverted = true
            end
            Sound.unitHit()
            proj:die()
        end
    end
    
    -- CASE 3: PROJECTILE vs POWERUP (Direct Hit)
    local powerup, p2
    if objA.type == "powerup" and objB.type == "projectile" then powerup = objA; p2 = objB
    elseif objB.type == "powerup" and objA.type == "projectile" then powerup = objB; p2 = objA end
    
    if powerup and p2 then
        collectPowerUp(powerup)
        p2:die() -- Destroy the projectile that hit it
    end

    -- [NEW] CASE 4: ZONE (Explosion) vs POWERUP
    local zone, p3
    if objA.type == "powerup" and objB.type == "zone" then p3 = objA; zone = objB
    elseif objB.type == "powerup" and objA.type == "zone" then p3 = objB; zone = objA end
    
    if p3 and zone then
        collectPowerUp(p3)
        -- We do NOT destroy the zone, so it can still damage units
    end
    
end

local function preSolve(a, b, coll)
    local objA = a:getUserData()
    local objB = b:getUserData()
    if not objA or not objB then return end
    
    -- PROJECTILE vs WALL (bottom wall - allow entry from below)
    local wall, proj
    if objA.type == "wall" and objB.type == "projectile" then wall = objA; proj = objB
    elseif objB.type == "wall" and objA.type == "projectile" then wall = objB; proj = objA end
    
    if wall and proj then
        local px, py = proj.body:getPosition()
        local vx, vy = proj.body:getLinearVelocity()
        
        -- Allow projectiles to pass through bottom wall if entering from below
        -- Check if projectile is below playfield and moving upward
        if py > Constants.PLAYFIELD_HEIGHT and vy < 0 then
            -- Projectile is below playfield and moving upward - allow through bottom wall
            coll:setEnabled(false)
            return
        end
    end
    
    -- Zone interactions
    local zone, proj2
    if objA.type == "zone" and objB.type == "projectile" then zone = objA; proj2 = objB
    elseif objB.type == "zone" and objA.type == "projectile" then zone = objB; proj2 = objA end
    
    if zone and proj2 then
        if proj2.weaponType == "bomb" then coll:setEnabled(false)
        else
            if zone.color == proj2.color then coll:setEnabled(false) 
            else coll:setEnabled(true) end
        end
    end
    
    -- Powerup interactions (Ghost physics)
    if objA.type == "powerup" or objB.type == "powerup" then
        coll:setEnabled(false)
    end
end


-- Load high scores from file
-- High score functions now use HighScores module

function love.load()
    love.window.setMode(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    love.window.setTitle("RageBait!")
    Game.fonts.small = love.graphics.newFont(Constants.UI.FONT_SMALL)
    Game.fonts.medium = love.graphics.newFont(Constants.UI.FONT_MEDIUM)
    Game.fonts.large = love.graphics.newFont(Constants.UI.FONT_LARGE)
    Game.fonts.speechBubble = love.graphics.newFont(Constants.UI.FONT_SPEECH_BUBBLE)
    -- Load DOS font for announcement text (RAPID FIRE, multipliers)
    local success, dosFont = pcall(love.graphics.newFont, "assets/ModernDOS9x16.ttf", Constants.UI.FONT_ANNOUNCEMENT_GIANT)
    if success and dosFont then
        Game.fonts.announcementGiant = dosFont
    else
        Game.fonts.announcementGiant = love.graphics.newFont(Constants.UI.FONT_ANNOUNCEMENT_GIANT)
    end
    -- Try to load a monospace font, fallback to default if not available
    local success, font = pcall(love.graphics.newFont, "assets/NotoColorEmoji.ttf", 32)
    if success and font then
        Game.fonts.terminal = font
    else
        -- Fallback to default monospace font
        Game.fonts.terminal = love.graphics.newFont(Constants.UI.FONT_TERMINAL)
    end
    
    -- Load high scores
    HighScores.load()
    
    -- Reset high scores
    HighScores.reset()
    
    -- Load background image
    local success, img = pcall(love.graphics.newImage, "assets/background.png")
    if success then
        Game.assets.background = img
    else
        Game.assets.background = nil
    end
    
    -- Load foreground image
    local success2, img2 = pcall(love.graphics.newImage, "assets/foreground.png")
    if success2 then
        Game.assets.foreground = img2
    else
        Game.assets.foreground = nil
    end
    
    -- Load company logo
    local success3, img3 = pcall(love.graphics.newImage, "assets/ferretlogo.png")
    if success3 then
        Game.assets.logo = img3
    else
        Game.assets.logo = nil
        print("Warning: Could not load logo: assets/ferretlogo.png")
    end
    
    -- Load company logo blink version
    local success5, img5 = pcall(love.graphics.newImage, "assets/ferretlogo_blink.png")
    if success5 then
        Game.assets.logoBlink = img5
    else
        Game.assets.logoBlink = nil
        print("Warning: Could not load logo blink: assets/ferretlogo_blink.png")
    end
    
    -- Load splash screen image
    local success4, img4 = pcall(love.graphics.newImage, "assets/splash.png")
    if success4 then
        Game.assets.splash = img4
    else
        Game.assets.splash = nil
        print("Warning: Could not load splash: assets/splash.png")
    end
    
    -- Load plexiglass overlay image
    local success7, img7 = pcall(love.graphics.newImage, "assets/plexi.jpeg")
    if success7 then
        Game.plexi = img7
    else
        Game.plexi = nil
        print("Warning: Could not load plexi: assets/plexi.jpeg")
    end
    
    -- Load plexi shader
    local plexiShaderCode = love.filesystem.read("shaders/plexi.fs")
    if plexiShaderCode then
        Game.plexiShader = love.graphics.newShader(plexiShaderCode)
    else
        Game.plexiShader = nil
        print("Warning: Could not load plexi shader")
    end
    
    -- Load plexi apply mask shader
    local plexiApplyMaskShaderCode = love.filesystem.read("shaders/plexi_apply_mask.fs")
    if plexiApplyMaskShaderCode then
        Game.plexiApplyMaskShader = love.graphics.newShader(plexiApplyMaskShaderCode)
    else
        Game.plexiApplyMaskShader = nil
        print("Warning: Could not load plexi apply mask shader")
    end
    
    -- Create canvas for capturing scene before plexi overlay (with stencil support)
    Game.plexiSceneStencilCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, {format = 'stencil8'})
    Game.plexiSceneCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    Game.plexiSceneCanvas:setFilter("linear", "linear")
    
    -- Create canvas for plexi mask
    Game.plexiMaskCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    Game.plexiMaskCanvas:setFilter("linear", "linear")
    
    -- Create temporary canvas for mask blur passes
    Game.plexiMaskBlurTempCanvas = love.graphics.newCanvas(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT)
    Game.plexiMaskBlurTempCanvas:setFilter("linear", "linear")
    
    -- Load Gaussian blur shader for mask blur
    local gaussianBlurShaderCode = love.filesystem.read("shaders/gaussian_blur.fs")
    if gaussianBlurShaderCode then
        Game.plexiMaskBlurShader = love.graphics.newShader(gaussianBlurShaderCode)
    else
        Game.plexiMaskBlurShader = nil
        print("Warning: Could not load gaussian blur shader for mask")
    end
    
    -- Load top banner images (using TopBanner module)
    TopBanner.load()
    
    -- Load monitor frame images
    MonitorFrame.load()
    
    -- Load godray effect
    Godray.load()
    
    -- Load text trace effect
    TextTrace.load()
    
    -- Load dynamic music player
    DynamicMusic.load()
    
    -- Load matrix effect
    MatrixEffect.load()
    
    -- Load Chase Paxton portrait images
    ChasePortrait.load()
    
    -- Load intro video
    local success6, vid = pcall(love.graphics.newVideo, "assets/introvideo.ogv")
    if success6 then
        Game.assets.introVideo = vid
        -- Videos don't loop by default in LÖVE, so no need to set looping
    else
        Game.assets.introVideo = nil
        print("Warning: Could not load intro video: assets/introvideo.ogv")
    end
    
    Event.clear(); Engagement.init(); World.init(); Time.init(); Sound.init(); EmojiSprites.init(); Webcam.init(); EngagementPlot.init()
    World.physics:setCallbacks(beginContact, nil, preSolve, nil)
    
    -- Start with matrix screen (booting screen disabled)
    Game.modes.booting = false
    Game.timers.booting = 0
    Game.modes.matrix = true
    Game.timers.matrix = 0
    Game.modes.logo = false
    Game.timers.logo = 0
    Game.timers.previousLogo = 0
    Game.assets.logoFanfarePlayed = false
    Game.modes.attract = false
    Game.modes.attractTimer = 0
    
    -- Don't initialize game entities until coin is inserted
    Game.turret = nil
    Game.score = 0
    Game.powerupSpawnTimer = 5.0
    
    Game.isUpgraded = false;
    Game.hasUnitBeenConverted = false;
    Game.gameState = "playing";
    Game.winCondition = nil;
    Game.hazards = {}; Game.explosionZones = {}; Game.units = {}; Game.projectiles = {}; Game.effects = {}; Game.powerups = {}
    
    -- Initialize Moonshine CRT effect
    Game.crtEnabled = false
    -- Create CRT effect (moonshine.BASE is already set to "libs")
    local crtEffect = require("libs.crt")(moonshine)
    
    -- Configure CRT appearance parameters:
    -- distortionFactor: Controls barrel distortion/curvature (default: {1.06, 1.065})
    --   Higher values = more curvature. Try {1.1, 1.1} for strong curve, {1.02, 1.02} for subtle
    crtEffect.distortionFactor = {1.02, 1.02}
    
    -- feather: Controls edge feathering/masking (default: 0.02)
    --   Higher values = softer edges. Try 0.05 for softer, 0.01 for sharper
    crtEffect.feather = 0.02  
    
    -- scaleFactor: Controls overall scale (default: 1)
    --   Values < 1 = zoom out, > 1 = zoom in. Usually keep at 1
    crtEffect.scaleFactor = 1
    
    -- scanlineIntensity: Controls scanline visibility (default: 0.3)
    --   Higher values = more visible scanlines (0.0 = off, 1.0 = very strong)
    --   Try 0.5 for strong scanlines, 0.1 for subtle
    crtEffect.scanlineIntensity = 0.3
    
    -- chromaIntensity: Controls chromatic aberration (color separation) (default: 0.5)
    --   Higher values = more color separation. Try 0.8 for strong, 0.2 for subtle
    --   0.0 = no chromatic aberration
    --   Disabled in fullscreen to prevent edge sampling issues with glow
    crtEffect.chromaIntensity = 0.0  -- Disabled to fix glow coverage issue
    
    -- screenSize: Screen dimensions (needed for scanlines)
    crtEffect.screenSize = {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT}
    
    -- Vignette intensity (increased for stronger effect)
    crtEffect.vignetteIntensity = 0.8
    
    -- Window bounds will be calculated dynamically in love.draw()
    crtEffect.windowBounds = {0.5, 0.5, 0.0, 0.0}  -- Default center, no size
    
    -- Create glow effect
    local glowEffect = require("libs.glow")(moonshine)
    
    -- Configure glow parameters:
    -- min_luma: Minimum brightness threshold (default: 0.7)
    --   Lower values = more things glow. Try 0.3 for more glow, 0.9 for less
    glowEffect.min_luma = 0.65
    
    -- strength: Glow blur radius/intensity (default: 5)
    --   Higher values = stronger blur/glow. Try 10 for strong, 2 for subtle
    glowEffect.strength = 5.25  -- Reduced to 75% of previous value (7 * 0.75)
    
    -- Store original glow strength for temporary reduction during video
    Game.glowStrengthNormal = 5.25
    Game.glowStrengthVideo = 5.25 * 0.75  -- 75% of normal during video
    
    -- Create effect chain: glow first, then CRT
    Game.crtChain = moonshine.chain(Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT, glowEffect)
    Game.crtChain.next(crtEffect)
    
    -- Store effect references for later access
    Game.glowEffect = glowEffect
    Game.crtEffect = crtEffect
    
    for i=1, 20 do
        local x = math.random(50, Constants.PLAYFIELD_WIDTH - 50)
        local y = math.random(50, Constants.PLAYFIELD_HEIGHT - 300)
        table.insert(Game.units, Unit.new(World.physics, x, y))
    end
    
    Event.on("bomb_exploded", function(data)
        Time.slowDown(0.1, 0.5); Game.shake = 1.0
        
        -- Clamp explosion zone position to playfield bounds (accounting for radius)
        local zoneX = math.max(data.radius, math.min(Constants.PLAYFIELD_WIDTH - data.radius, data.x))
        local zoneY = math.max(data.radius, math.min(Constants.PLAYFIELD_HEIGHT - data.radius, data.y))
        
        -- [NOTE] The radius comes from data.radius, which is set by Constants.EXPLOSION_RADIUS
        -- This ensures the size is constant regardless of throw distance.
        table.insert(Game.effects, {type = "explosion", x = zoneX, y = zoneY, radius = 0, maxRadius = data.radius, color = data.color, alpha = 1.0, timer = 0.5})
        
        local blocked = false
        for _, z in ipairs(Game.explosionZones) do
            local dx = zoneX - z.x; local dy = zoneY - z.y
            if (dx*dx + dy*dy) < (z.radius * z.radius) then if z.color ~= data.color then blocked = true break end end
        end
        if blocked then return end
        if #Game.explosionZones >= 5 then local oldZ = table.remove(Game.explosionZones, 1); if oldZ.body then oldZ.body:destroy() end end
        
        local body = love.physics.newBody(World.physics, zoneX, zoneY, "static")
        local shape = love.physics.newCircleShape(data.radius)
        local fixture = love.physics.newFixture(body, shape)
        fixture:setCategory(Constants.PHYSICS.ZONE); fixture:setUserData({ type = "zone", color = data.color })
        table.insert(Game.explosionZones, {x = zoneX, y = zoneY, radius = data.radius, color = data.color, timer = Constants.EXPLOSION_DURATION, body = body})
    end)
    Event.on("unit_killed", function(data)
        Game.score = Game.score + (Constants.SCORE_KILL * Game.pointMultiplier.value); Engagement.add(Constants.ENGAGEMENT_REFILL_KILL); Game.shake = math.max(Game.shake, 0.2)
        -- Use position from event data (captured before body destruction)
        local x, y = data.x, data.y
        if not x or not y then
            -- Fallback: try to get from body if still available (shouldn't happen)
            if data.victim and data.victim.body then
                x, y = data.victim.body:getPosition()
            else
                return  -- Can't get position, skip
            end
        end
        -- Clamp toxic zone position to playfield bounds (accounting for radius)
        local toxicX = math.max(Constants.TOXIC_RADIUS, math.min(Constants.PLAYFIELD_WIDTH - Constants.TOXIC_RADIUS, x))
        local toxicY = math.max(Constants.TOXIC_RADIUS, math.min(Constants.PLAYFIELD_HEIGHT - Constants.TOXIC_RADIUS, y))
        local r, g, b = unpack(Constants.COLORS.TOXIC)
        local hazard = {
            x = toxicX, 
            y = toxicY, 
            radius = Constants.TOXIC_RADIUS, 
            timer = Constants.TOXIC_DURATION,
            splat = ToxicSplat.createSplat(toxicX, toxicY, Constants.TOXIC_RADIUS, {r * 0.5, g * 0.5, b * 0.5})
        }
        table.insert(Game.hazards, hazard)
        Webcam.showComment("unit_killed")
    end)
    Event.on("unit_insane_exploded", function(data)
        local x, y = data.x, data.y  -- Use position from event data (captured before body destruction)
        -- Clamp position to playfield bounds (accounting for radius)
        local toxicX = math.max(Constants.INSANE_TOXIC_RADIUS, math.min(Constants.PLAYFIELD_WIDTH - Constants.INSANE_TOXIC_RADIUS, x))
        local toxicY = math.max(Constants.INSANE_TOXIC_RADIUS, math.min(Constants.PLAYFIELD_HEIGHT - Constants.INSANE_TOXIC_RADIUS, y))
        
        -- Create orange explosion splat (fiery orange, larger scale)
        -- Fiery orange color: {1.0, 0.4, 0.1} for base, with highlights
        local orangeSplat = ToxicSplat.createSplat(toxicX, toxicY, Constants.INSANE_EXPLOSION_RADIUS, {0.8, 0.3, 0.1})
        table.insert(Game.effects, {
            type = "orange_splat",
            x = toxicX, 
            y = toxicY,
            splat = orangeSplat,
            alpha = 1.0,
            timer = 0.8,  -- Duration of orange explosion
            speechBubble = data.speechBubble,  -- Preserve speech bubble for drawing
            toxicX = toxicX,  -- Store position for green zone creation
            toxicY = toxicY
        })
        
        Game.shake = math.max(Game.shake, 2.0)  -- Strong screen shake
        Webcam.showComment("unit_killed")  -- Use same comment for now
    end)
end

-- Start the game (called when coin is inserted)
function startGame()
    -- Unmute sounds for new game
    Sound.unmute()
    Game.modes.attract = false
    Game.modes.attractTimer = 0
    
    -- Reset all game over states
    Game.modes.gameOver = false
    Game.timers.gameOver = 0
    Game.modes.auditor = false
    Game.timers.auditor = 0
    Game.auditor.phase = 1
    Game.modes.nameEntry = false
    Game.nameEntry.text = ""
    Game.nameEntry.cursor = 1
    Game.nameEntry.charIndex = {}
    
    -- Reset joystick button states
    Game.joystick.button1Pressed = false
    Game.joystick.button2Pressed = false
    
    -- Start intro video first, then intro screen
    if Game.assets.introVideo then
        Game.modes.video = true
        Game.assets.introVideo:play()
        Game.modes.intro = false
        
        -- Reduce glow strength when video starts
        if Game.glowEffect and Game.glowStrengthVideo then
            Game.glowEffect.strength = Game.glowStrengthVideo
        end
        
        -- Start music fade: fade from current volume to 50% over 3 seconds
        Game.intro.musicFadeActive = true
        Game.timers.introMusicFade = 0
        Game.intro.musicFadeStartVolume = Sound.getMusicVolume() or 0.6
        Game.intro.musicFadeTargetVolume = Game.intro.musicFadeStartVolume * 0.5  -- 50% of start volume
    else
        -- If video doesn't exist, skip directly to intro screen
        Game.modes.video = false
        Game.modes.intro = true
        Game.timers.intro = 0
        Game.intro.step = 1
        Game.intro.musicFadeActive = false
    end
end


-- Actually start gameplay (called after intro screen)
function startGameplay()
    Game.modes.intro = false
    Game.timers.intro = 0
    Game.intro.step = 1
    Webcam.showComment("game_start")
    
    -- Stop intro/attract mode music
    Sound.stopMusic()
    
    -- Start dynamic music (part 1, bar mode)
    DynamicMusic.startAutomatic()
    
    -- Reset monitor frame animations for new game
    MonitorFrame.resetEyelidAnimation()
    MonitorFrame.resetBottomCenterPanelAnimation()
    
    -- Reset engagement to starting value (critical - prevents immediate game over)
    Engagement.init()
    
    -- Initialize game entities
    Game.turret = Turret.new()
    Game.score = 0
    Game.powerupSpawnTimer = 5.0
    
    Game.isUpgraded = false
    Game.hasUnitBeenConverted = false
    Game.gameState = "playing"
    Game.winCondition = nil
    Game.level = 1
    Game.timers.levelTransition = 0
    Game.levelTransition.active = false
    Game.levelComplete.screenActive = false
    Game.timers.levelCompleteScreen = 0
    Game.modes.winText = false
    Game.webcamWindow.animating = false
    Game.timers.webcamWindowAnim = 0
    Game.webcamWindow.reversing = false
    Game.webcamWindow.dialogueActive = false
    Game.timers.webcamWindowDialogue = 0
    Game.timers.winText = 0
    Game.webcamWindow.animating = false
    Game.timers.webcamWindowAnim = 0
    Game.slowMo.active = false
    Game.timers.slowMo = 0
    Game.timeScale = 1.0
    Game.lives = 3
    Game.timers.gameOver = 0
    Game.modes.gameOver = false
    Game.shouldRestartLevel = false
    Game.modes.auditor = false
    Game.timers.auditor = 0
    Game.auditor.phase = 1
    Game.modes.lifeLostAuditor = false
    Game.timers.lifeLostAuditor = 0
    Game.lifeLostAuditor.phase = 1
    Game.modes.nameEntry = false
    Game.nameEntry.text = ""
    Game.nameEntry.cursor = 1
    Game.nameEntry.charIndex = {}
    Game.pointMultiplier.value = 1
    Game.timers.pointMultiplier = 0
    Game.pointMultiplier.valueActive = false
    Game.timers.pointMultiplierFlash = 0
    Game.timers.pointMultiplierText = 0
    Game.pointMultiplier.valueSparks = {}
    Game.timers.rapidFireText = 0
    Game.rapidFire.sparks = {}
    Game.previousEngagementAtMax = false
    Game.hazards = {}
    Game.explosionZones = {}
    Game.units = {}
    Game.projectiles = {}
    Game.effects = {}
    Game.powerups = {}
    
    -- Spawn initial units
    spawnUnitsForLevel()
    
    -- Trigger ready sequence
    Game.modes.ready = true
    Game.timers.ready = 0
    Game.ready.phase = 1
    Game.ready.sparks = {}
    Game.gameState = "ready"
    -- Reset banner to original position
    TopBanner.reset()
end

-- Spawn units for the current level
function spawnUnitsForLevel()
    -- Base number of units, increases with level
    local baseUnits = 20
    local unitsToSpawn = baseUnits + (Game.level - 1) * 5  -- 5 more units per level
    
    for i=1, unitsToSpawn do
        local x = math.random(50, Constants.PLAYFIELD_WIDTH - 50)
        local y = math.random(50, Constants.PLAYFIELD_HEIGHT - 300)
        local unit = Unit.new(World.physics, x, y)
        -- Ensure unit starts as neutral (grey)
        unit.state = "neutral"
        unit.alignment = "none"
        unit.isolationTimer = 0
        unit.isInsane = false
        table.insert(Game.units, unit)
    end
end

-- Advance to the next level
function advanceToNextLevel(winCondition)
    -- Stop turret charging immediately (prevents charge sound from continuing)
    if Game.turret then
        Game.turret.isCharging = false
        Game.turret.chargeTimer = 0
        if Game.turret.chargeSound then
            local success, isPlaying = pcall(function()
                return Game.turret.chargeSound:isPlaying()
            end)
            if success and isPlaying then
                pcall(function()
                    Game.turret.chargeSound:stop()
                    Game.turret.chargeSound:release()
                end)
            end
            Game.turret.chargeSound = nil
        end
    end
    
    -- Clear all multipliers on win
    Game.pointMultiplier.value = 1
    Game.timers.pointMultiplier = 0
    Game.pointMultiplier.valueActive = false
    Game.timers.pointMultiplierFlash = 0
    Game.timers.pointMultiplierText = 0
    Game.pointMultiplier.valueSparks = {}
    
    -- Clean up all game sounds first (stops all active sounds)
    Sound.cleanup()
    
    -- Unmute sounds so fanfare can play
    Sound.unmute()
    
    -- Play fanfare for victory
    Sound.playFanfare()
    
    -- Start slow-motion ramp to freeze
    Game.slowMo.active = true
    Game.timers.slowMo = 0
    Game.timeScale = 1.0
    Game.winCondition = winCondition
    Game.gameState = "level_complete"
    
    -- Restart dynamic music for win (part 2) - Sound.cleanup() stopped it, so restart it immediately
    if DynamicMusic.isAutomatic() then
        print("DynamicMusic: Restarting music for win (part 2) after Sound.cleanup()")
        DynamicMusic.startPart(2)  -- Start part 2 immediately for win music
    end
    -- Don't show level complete screen yet - wait for freeze
    Game.levelComplete.screenActive = false
    Game.timers.levelCompleteScreen = 0
end

-- Handle game over (lose a life)
function handleGameOver(condition)
    -- Stop turret charge sound
    if Game.turret and Game.turret.chargeSound then
        pcall(function()
            Game.turret.chargeSound:stop()
            Game.turret.chargeSound:release()
        end)
        Game.turret.chargeSound = nil
    end
    
    -- Stop all projectile whistle sounds (they can get stuck if projectiles don't explode)
    for _, p in ipairs(Game.projectiles) do
        if p.whistleSound then
            local success, isPlaying = pcall(function() return p.whistleSound:isPlaying() end)
            if success and isPlaying then
                pcall(function() p.whistleSound:stop() end)
                pcall(function() p.whistleSound:release() end)
            end
            p.whistleSound = nil
        end
    end
    
    -- Check if we have lives remaining BEFORE decrementing
    local hasLivesRemaining = Game.lives > 1  -- Will have lives after decrement if currently > 1
    -- Only decrement lives if we have lives remaining (prevent going below 0)
    if Game.lives > 0 then
        Game.lives = Game.lives - 1
    end
    
    -- If engagement was depleted and we have lives remaining, show life lost auditor screen
    if condition == "engagement_depleted" and hasLivesRemaining then
        Game.modes.lifeLostAuditor = true
        Game.timers.lifeLostAuditor = 0
        Game.lifeLostAuditor.phase = 1  -- Start with system freeze
        Game.gameState = "life_lost_auditor"
        Sound.cleanup()  -- Stop all sounds for the auditor sequence
        DynamicMusic.stopAutomatic()  -- Stop automatic music
        -- Trigger banner drop animation (drop 120px from current position)
        TopBanner.triggerDrop(Constants.TIMING.LIFE_LOST_BANNER_DROP)
        return
    end
    
    -- If all lives are lost, show game over screen (same as life lost, just top bar)
    if not hasLivesRemaining then
        Game.modes.gameOver = true
        Game.timers.gameOver = 2.0  -- 2 second wait at dropped banner position
        -- Trigger banner drop (same as life lost)
        TopBanner.triggerDrop(Constants.TIMING.GAME_OVER_BANNER_DROP)
        DynamicMusic.stopAutomatic()  -- Stop automatic music
        Sound.playIntroMusic()  -- Play intro music (same as attract mode)
        return
    end
    
    -- Normal game over (lose a life, but not engagement depletion)
    Game.modes.gameOver = true
    Game.timers.gameOver = 2.0  -- 2 second wait at dropped banner position
    Game.gameState = "lost"
    Game.winCondition = condition
    -- Store whether we should restart (have lives remaining after this loss)
    Game.shouldRestartLevel = hasLivesRemaining
    -- Trigger banner drop animation (drop 320px from current position)
    TopBanner.triggerDrop(Constants.TIMING.GAME_OVER_BANNER_DROP)
    Game.visualEffects.glitchTextWriteProgress = 0  -- Reset write-on effect
    DynamicMusic.stopAutomatic()  -- Stop automatic music
    Sound.playIntroMusic()  -- Play intro music (same as attract mode)
end

-- Helper function to clear weapon upgrades (defined before restartLevel)
local function clearWeaponUpgrades()
    Game.isUpgraded = false
    Constants.PUCK_LIFETIME = Constants.PUCK.LIFETIME
end

-- Restart the current level after losing a life
-- Note: Score and level are preserved (not reset)
function restartLevel()
    -- Start matrix transition to hide the reset
    Game.levelTransition.matrixActive = true
    MatrixEffect.startTransition(2.0, function()
        -- Transition complete - now do the actual reset
        Game.modes.gameOver = false
        Game.timers.gameOver = 0
        Game.shouldRestartLevel = false
        Game.modes.auditor = false  -- Make sure THE AUDITOR is not active
        Game.timers.auditor = 0
        Game.auditor.phase = 1
        Game.modes.lifeLostAuditor = false  -- Make sure life lost auditor is not active
        Game.timers.lifeLostAuditor = 0
        Game.lifeLostAuditor.phase = 1
        -- Reset banner to original position on restart
        TopBanner.reset()
        
        -- Trigger ready sequence
        Game.modes.ready = true
        Game.timers.ready = 0
        Game.ready.phase = 1
        Game.ready.sparks = {}
        Game.gameState = "ready"
        Game.winCondition = nil
        Game.hasUnitBeenConverted = false
        
        -- Unmute sounds so they can play again after restart
        Sound.unmute()
        
        -- Stop intro/attract mode music
        Sound.stopMusic()
        
        -- Restart dynamic music (part 1, bar mode)
        DynamicMusic.startAutomatic()
        
        -- Reset engagement to 100% (same as new level/game start)
        -- Score and level are NOT reset - they are preserved
        Engagement.value = Constants.ENGAGEMENT_MAX
        
        -- Reset monitor frame animations
        MonitorFrame.resetAnimations()
        
        -- Clear all game entities
        EntityManager.clearAll(false)  -- Don't destroy turret on restart
        
        -- Clear weapon upgrades on level restart
        clearWeaponUpgrades()
        
        -- Spawn units for current level
        spawnUnitsForLevel()
        
        -- End transition
        Game.levelTransition.matrixActive = false
    end)
    
    -- Clear entities immediately (before transition starts)
    EntityManager.clearAll(false)  -- Don't destroy turret on restart
end

-- Return to attract mode
function returnToAttractMode()
    -- Stop automatic music when returning to attract mode
    DynamicMusic.stopAutomatic()
    
    Game.modes.logo = false
    Game.timers.logo = 0
    Game.timers.previousLogo = 0
    Game.modes.video = false
    Game.modes.intro = false
    Game.modes.attract = true
    Game.modes.attractTimer = 0
    
    -- Stop and reset video if it's playing
    if Game.assets.introVideo then
        -- Safely check if video is playing and pause it
        local success, isPlaying = pcall(function()
            return Game.assets.introVideo:isPlaying()
        end)
        if success and isPlaying then
            pcall(function()
                if Game.assets.introVideo.pause then
                    Game.assets.introVideo:pause()
                end
            end)
        end
        -- Safely seek to beginning
        pcall(function()
            if Game.assets.introVideo.seek then
                Game.assets.introVideo:seek(0)  -- Reset to beginning
            end
        end)
    end
    Game.modes.gameOver = false
    Game.timers.gameOver = 0
    -- Reset banner
    TopBanner.reset()
    Game.modes.auditor = false
    Game.timers.auditor = 0
    Game.auditor.phase = 1
    Game.modes.nameEntry = false
    Game.nameEntry.text = ""
    Game.nameEntry.cursor = 1
    Game.nameEntry.charIndex = {}
    Game.gameState = "attract"
    Game.winCondition = nil
    
    -- Stop all sounds
    Sound.cleanup()
    
    -- Stop turret charge sound if active
    if Game.turret and Game.turret.chargeSound then
        -- Use pcall to safely check if sound is still valid
        local success, isPlaying = pcall(function() return Game.turret.chargeSound:isPlaying() end)
        if success and isPlaying then
            pcall(function() Game.turret.chargeSound:stop() end)
            pcall(function() Game.turret.chargeSound:release() end)
        end
        Game.turret.chargeSound = nil
    end
    
    -- Stop all projectile whistle sounds (before clearing entities)
    EntityManager.stopAllProjectileSounds()
    
    -- Clear all game entities (including turret)
    EntityManager.clearAll(true)  -- Destroy turret on game over
end

-- Draw joystick test / input diagnostics screen
-- Draw glitchy terminal text with write-on effect
-- Drawing helper functions now use DrawingHelpers module

-- Helper function to clear button held status
local function clearButtonHeldStatus()
    if Game.turret then
        Game.turret.isCharging = false
        Game.turret.chargeTimer = 0
        if Game.turret.chargeSound then
            pcall(function()
                Game.turret.chargeSound:stop()
                Game.turret.chargeSound:release()
            end)
            Game.turret.chargeSound = nil
        end
    end
    Game.joystick.button1Pressed = false
    Game.joystick.button2Pressed = false
end

-- Plexi scale and text outline functions now use DrawingHelpers module

-- drawGlitchyTerminalText has been moved to TopBanner module

function drawJoystickTestScreen()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
    DrawingHelpers.drawTealWallpaper()

    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local border = Constants.UI.BORDER_WIDTH
    local boxWidth = 800
    local boxHeight = 500
    local boxX = (Constants.SCREEN_WIDTH - boxWidth) / 2
    local boxY = (Constants.SCREEN_HEIGHT - boxHeight) / 2

    -- Background panel
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle(
        "fill",
        boxX + border,
        boxY + border + titleBarHeight,
        boxWidth - border * 2,
        boxHeight - border * 2 - titleBarHeight
    )

    -- Windows 95 style frame
    WindowFrame.draw(boxX, boxY, boxWidth, boxHeight, "Joystick Test")

    local contentX = boxX + border + 12
    local contentY = boxY + titleBarHeight + border + 16

    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    local header = "USB Joystick Diagnostics"
    local headerWidth = Game.fonts.large:getWidth(header)
    love.graphics.print(header, boxX + (boxWidth - headerWidth) / 2, contentY)

    contentY = contentY + 40

    love.graphics.setFont(Game.fonts.medium)

    -- Instructions
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    local inst1 = "Press any joystick button while in attract mode or press J to open this screen."
    local inst2 = "Press ESC or SPACE to return to attract mode."
    love.graphics.print(inst1, contentX, contentY)
    love.graphics.print(inst2, contentX, contentY + 24)

    contentY = contentY + 60
    
    -- Draw monitor frame (always visible)
    MonitorFrame.draw()

    -- Joystick information
    local joysticks = love.joystick.getJoysticks()
    local joystick = joysticks[1]

    if not joystick then
        love.graphics.setColor(1, 0.4, 0.4, 1)
        love.graphics.print(
            "No joystick detected. Connect your USB interface and make sure it shows up as a joystick in Windows.",
            contentX,
            contentY
        )
        return
    end

    love.graphics.setColor(0.8, 0.9, 1.0, 1)
    local nameLabel = "Active Joystick:"
    love.graphics.print(nameLabel, contentX, contentY)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(joystick:getName(), contentX + Game.fonts.medium:getWidth(nameLabel) + 8, contentY)

    contentY = contentY + 28

    love.graphics.setColor(0.7, 0.9, 0.7, 1)
    local guidLabel = "GUID:"
    love.graphics.print(guidLabel, contentX, contentY)
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    love.graphics.print(joystick:getGUID(), contentX + Game.fonts.medium:getWidth(guidLabel) + 8, contentY)

    contentY = contentY + 36

    -- Buttons
    local buttonCount = joystick:getButtonCount()
    love.graphics.setColor(1, 0.9, 0.6, 1)
    love.graphics.print("Buttons (" .. tostring(buttonCount) .. "):", contentX, contentY)

    contentY = contentY + 22
    love.graphics.setColor(1, 1, 1, 1)

    local col1X = contentX
    local col2X = contentX + 260
    local maxPerColumn = 12

    for i = 1, buttonCount do
        local col = math.floor((i - 1) / maxPerColumn)
        local row = (i - 1) % maxPerColumn
        local x = col == 0 and col1X or col2X
        local y = contentY + row * 18

        local down = joystick:isDown(i)
        if down then
            love.graphics.setColor(0.2, 1.0, 0.2, 1)
        else
            love.graphics.setColor(0.6, 0.6, 0.6, 1)
        end

        local label = string.format("Button %02d : %s", i, down and "PRESSED" or "released")
        love.graphics.print(label, x, y)
    end

    -- Axes
    local axisStartY = contentY + maxPerColumn * 18 + 16
    local axisCount = joystick:getAxisCount()
    love.graphics.setColor(0.6, 0.9, 1.0, 1)
    love.graphics.print("Axes (" .. tostring(axisCount) .. "):", contentX, axisStartY)

    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    for i = 1, axisCount do
        local value = joystick:getAxis(i)
        local text = string.format("Axis %02d : %.2f", i, value)
        love.graphics.print(text, contentX, axisStartY + 18 * i)
    end

    -- Hats
    local hatStartY = axisStartY + 18 * (axisCount + 2)
    local hatCount = joystick:getHatCount()
    love.graphics.setColor(0.9, 0.8, 1.0, 1)
    love.graphics.print("Hats (" .. tostring(hatCount) .. "):", contentX, hatStartY)

    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    for i = 1, hatCount do
        local dir = joystick:getHat(i)
        local text = string.format("Hat %02d : %s", i, dir)
        love.graphics.print(text, contentX, hatStartY + 18 * i)
    end
end

-- Screen drawing functions moved to src/screens/ modules

-- Draw intro screen with centered webcam
function drawIntroScreen()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
    DrawingHelpers.drawTealWallpaper()
    
    -- Intro messages (multiple steps) - Chase Paxton's onboarding
    local currentStep = math.min(Game.intro.step, #ChasePaxton.INTRO_MESSAGES)
    local currentMessage = ChasePaxton.getIntroMessage(currentStep)
    local stepStartTime = 0
    for i = 1, currentStep - 1 do
        stepStartTime = stepStartTime + ChasePaxton.INTRO_MESSAGES[i].duration
    end
    local stepElapsed = Game.timers.intro - stepStartTime
    
    -- Auto-advance steps (except last one which waits for input)
    if currentStep < #ChasePaxton.INTRO_MESSAGES and stepElapsed >= currentMessage.duration then
        Game.intro.step = currentStep + 1
    end
    
    -- Draw centered webcam window (larger for intro screen to accommodate portrait and text)
    local WEBCAM_WIDTH = 600  -- Larger width for intro screen
    local WEBCAM_HEIGHT = 500  -- Larger height to fit portrait and text below
    local WEBCAM_X = (Constants.SCREEN_WIDTH - WEBCAM_WIDTH) / 2
    local WEBCAM_Y = (Constants.SCREEN_HEIGHT - WEBCAM_HEIGHT) / 2 + Constants.UI.WEBCAM_OFFSET_Y
    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local borderWidth = Constants.UI.BORDER_WIDTH
    
    -- Draw transparent black background for content area
    DrawingHelpers.drawWindowContentBackground(WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT, titleBarHeight, borderWidth)
    
    -- Draw Windows 95 style frame with title bar
    WindowFrame.draw(WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT, "Chase Paxton")
    
    -- Calculate content area
    local contentX = WEBCAM_X + borderWidth
    local contentY = WEBCAM_Y + titleBarHeight + borderWidth
    local contentWidth = WEBCAM_WIDTH - (borderWidth * 2)
    local contentHeight = WEBCAM_HEIGHT - titleBarHeight - (borderWidth * 2)
    
    -- Draw title at the top
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(1, 1, 0, 1)
    local titleWidth = Game.fonts.large:getWidth(currentMessage.title)
    local titleY = contentY + 10
    love.graphics.print(currentMessage.title, WEBCAM_X + (WEBCAM_WIDTH - titleWidth) / 2, titleY)
    
    -- Draw character portrait in the upper portion of the window (much larger)
    local portraitAreaHeight = 320  -- Reserve more space for larger portrait at top
    local portraitY = contentY + 50  -- Below title
    local charX = WEBCAM_X + WEBCAM_WIDTH / 2
    local charY = portraitY + portraitAreaHeight / 2
    
    -- Calculate available space for portrait (upper portion) - use most of the width
    local portraitAvailableWidth = contentWidth - 40  -- Less padding for larger portrait
    local portraitAvailableHeight = portraitAreaHeight - 20  -- Padding
    
    -- Calculate scale to fit portrait in upper portion, but allow it to be larger
    local portraitScale = ChasePortrait.calculateScale(portraitAvailableWidth, portraitAvailableHeight, 5)
    -- Make it even larger by multiplying the scale
    portraitScale = portraitScale * 1.5  -- Make portrait 50% larger than calculated fit
    -- Set talking state based on whether there's a message being shown
    ChasePortrait.setTalking(currentMessage ~= nil and stepElapsed < currentMessage.duration)
    ChasePortrait.draw(charX, charY, portraitScale)
    
    -- Draw message below the portrait
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(1, 1, 1, 1)
    local lines = {}
    for line in currentMessage.message:gmatch("[^\n]+") do
        table.insert(lines, line)
    end
    
    local lineHeight = Game.fonts.medium:getHeight() + 5
    -- Start text below the portrait area
    local textStartY = portraitY + portraitAreaHeight + 20
    for i, line in ipairs(lines) do
        local lineWidth = Game.fonts.medium:getWidth(line)
        love.graphics.print(line, WEBCAM_X + (WEBCAM_WIDTH - lineWidth) / 2, textStartY + (i - 1) * lineHeight)
    end
    
    -- Draw progress indicator (dots)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    local dotSize = 8
    local dotSpacing = 15
    local totalWidth = (#ChasePaxton.INTRO_MESSAGES - 1) * dotSpacing
    local dotsStartX = WEBCAM_X + (WEBCAM_WIDTH - totalWidth) / 2
    for i = 1, #ChasePaxton.INTRO_MESSAGES - 1 do
        local dotX = dotsStartX + (i - 1) * dotSpacing
        local dotY = WEBCAM_Y + WEBCAM_HEIGHT - 15
        if i < currentStep then
            love.graphics.setColor(1, 1, 1, 1)  -- Completed
        elseif i == currentStep then
            love.graphics.setColor(1, 1, 0, 1)  -- Current
        else
            love.graphics.setColor(0.5, 0.5, 0.5, 1)  -- Not reached
        end
        love.graphics.circle("fill", dotX, dotY, dotSize)
    end
end

-- Draw name entry rays and text (drawn after godrays, on top of everything)
function drawNameEntryRaysAndText()
    if not Game.modes.nameEntry then return end
    
    -- For name entry, always show text and rays (don't require banner drop visibility check)
    -- The banner should already be dropped when we reach name entry screen
    local glitchTextTimer = Game.timers.glitchText or 0
    
    -- Use terminal font for glitchy effect
    local terminalFont = Game.fonts.terminal
    if not terminalFont then return end
    
    love.graphics.setFont(terminalFont)
    
    -- Calculate name entry text position (centered on screen, no box)
    local charWidth = terminalFont:getWidth("A")
    local totalWidth = charWidth * Game.nameEntry.maxLength
    local startX = (Constants.SCREEN_WIDTH - totalWidth) / 2
    local textY = Constants.SCREEN_HEIGHT / 2
    
    -- Get center point for rays (same as godrays - vigilant center)
    local centerX, centerY = TopBanner.getVigilantCenter()
    if centerX and centerY then
        centerY = centerY - 47  -- Same offset as godrays
        centerX = centerX - 4
    else
        -- Fallback: use screen center if vigilant center not available
        centerX = Constants.SCREEN_WIDTH / 2
        centerY = Constants.SCREEN_HEIGHT / 2 - 100
    end
    
    -- Prepare character data for ray drawing
    local pulse = (math.sin(glitchTextTimer * 3) + 1) / 2  -- 0 to 1
    local alpha = 0.6 + pulse * 0.4  -- Pulse between 0.6 and 1.0
    
    -- Per-character flicker: each character has its own flicker phase
    local flickerRate = 8  -- Same as life lost text
    local flickerTime = glitchTextTimer * flickerRate
    
    local charData = {}
    
    for i = 1, Game.nameEntry.maxLength do
        local char = Game.nameEntry.text:sub(i, i) or "A"
        local charX = startX + (i - 1) * charWidth
        
        -- Apply glitch corruption (3% chance) - same as terminal text
        local displayChar = char
        math.randomseed(math.floor(glitchTextTimer * 100) + i)  -- Per-character seed
        local glitchChars = {"█", "▓", "▒"}
        if math.random() < 0.03 then
            displayChar = glitchChars[math.random(#glitchChars)]
        end
        
        -- Per-character flicker: each character has a phase offset
        local charFlickerPhase = (flickerTime + (i * 0.1)) % 1.0  -- Offset each character by 0.1
        local charIsVisible = charFlickerPhase < 0.6  -- Show for 60% of the cycle
        
        table.insert(charData, {
            char = displayChar,
            x = charX,
            y = textY,
            isCursor = (i == Game.nameEntry.cursor),
            isVisible = charIsVisible  -- Per-character visibility
        })
    end
    
    -- First, draw rays from all characters (on top of everything)
    -- Always draw rays if center point is available
    if not centerX or not centerY then
        -- Fallback center if not available
        centerX = Constants.SCREEN_WIDTH / 2
        centerY = Constants.SCREEN_HEIGHT / 2 - 100
    end
    
    -- Match TextTrace exactly: same pixel sample rate, color, line width, and opacity
    local pixelSampleRate = 8  -- Same as TextTrace
    local lineColor = {0.2, 1.0, 0.3}  -- Same as TextTrace state.lineColor
    local rayWidth = 1  -- Same as TextTrace state.rayWidth
    local finalOpacity = 1.0  -- Same as TextTrace for life lost/game over
    
    local oldBlendMode = love.graphics.getBlendMode()
    local oldColor = {love.graphics.getColor()}
    local oldLineWidth = love.graphics.getLineWidth()
    
    love.graphics.setBlendMode("add")  -- Same as TextTrace
    love.graphics.setLineWidth(rayWidth)  -- Same as TextTrace
    
    -- Draw rays for each character (per-character flicker)
    for _, data in ipairs(charData) do
        -- Only draw rays when this character is visible
        if not data.isVisible then
            goto continue_char
        end
        -- Render character to canvas to sample pixels (same approach as TextTrace)
        local padding = 10
        local canvasWidth = charWidth + padding * 2
        local canvasHeight = terminalFont:getHeight() + padding * 2
        local charCanvas = love.graphics.newCanvas(canvasWidth, canvasHeight)
        charCanvas:setFilter("nearest", "nearest")  -- Nearest for pixel-perfect sampling (like TextTrace)
        
        local oldCanvas = love.graphics.getCanvas()
        local oldShader = love.graphics.getShader()
        local oldBlendModeCanvas = love.graphics.getBlendMode()
        
        love.graphics.setCanvas(charCanvas)
        love.graphics.setShader()  -- No shader
        love.graphics.setBlendMode("alpha")  -- Normal alpha blending
        love.graphics.clear(0, 0, 0, 0)
        
        -- Render character in green (same as terminal text)
        love.graphics.setColor(0, 1, 0, 1)  -- Green text, full opacity
        love.graphics.setFont(terminalFont)
        love.graphics.print(data.char, padding, padding)
        
        love.graphics.setCanvas(oldCanvas)
        love.graphics.setShader(oldShader)
        love.graphics.setBlendMode(oldBlendModeCanvas)
        
        -- Get ImageData from canvas (must restore canvas first)
        local imageData = charCanvas:newImageData()
        charCanvas:release()
        
        -- Sample pixels and draw rays (exactly like TextTrace)
        local width = imageData:getWidth()
        local height = imageData:getHeight()
        
        local pixelsFound = 0
        
        -- Sample more densely to ensure we find pixels (check every pixel, not just every 8th)
        -- But still draw lines at the sample rate to match TextTrace density
        for y = 0, height - 1, 1 do
            for x = 0, width - 1, 1 do
                local r, g, b, a = imageData:getPixel(x, y)
                
                -- If pixel has alpha (is part of text), draw a line to center (same threshold as TextTrace)
                if a > 0.1 then  -- Same threshold as TextTrace
                    -- Only draw a line if this pixel aligns with our sample rate
                    if (x % pixelSampleRate == 0) and (y % pixelSampleRate == 0) then
                        pixelsFound = pixelsFound + 1
                        -- Convert canvas coordinates to screen coordinates
                        local screenX = data.x - padding + x
                        local screenY = data.y - padding + y
                        
                        -- Calculate brightness from the sampled pixel (exactly like TextTrace)
                        local pixelBrightness = g * a  -- Green channel multiplied by alpha (same as TextTrace)
                        local lineBrightness = pixelBrightness * 0.5  -- Half brightness (same as TextTrace)
                        
                        -- Set color with half brightness (exactly like TextTrace)
                        love.graphics.setColor(
                            lineColor[1] * lineBrightness,
                            lineColor[2] * lineBrightness,
                            lineColor[3] * lineBrightness,
                            finalOpacity  -- Same as TextTrace
                        )
                        
                        -- Draw thin line from this pixel to center (same as TextTrace)
                        love.graphics.line(screenX, screenY, centerX, centerY)
                    end
                end
            end
        end
        
        -- Fallback: if no pixels found, draw a line from character center (ensures rays are always visible)
        if pixelsFound == 0 then
            local charCenterX = data.x + charWidth / 2
            local charCenterY = data.y + terminalFont:getHeight() / 2
            -- Use half brightness to match text trace style
            love.graphics.setColor(
                lineColor[1] * 0.5,
                lineColor[2] * 0.5,
                lineColor[3] * 0.5,
                finalOpacity
            )
            love.graphics.line(charCenterX, charCenterY, centerX, centerY)
        end
        
        imageData:release()
        ::continue_char::
    end
    
    -- Draw "Define your identifier, Asset" text above the top banner (same style as name entry)
    -- Draw instruction text rays using the same setup (before restoring state)
    local instructionText = "ASSET: DEFINE YOUR IDENTIFIER"  -- All caps
    local instructionTextX = Constants.SCREEN_WIDTH / 2  -- Centered
    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local borderWidth = Constants.UI.BORDER_WIDTH
    local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
    local instructionTextY = frameY - 60 + 70 + 40 + 50  -- Lowered by 70px + 40px + 50px more = 160px total (was 60px above, now 100px below frame top)
    
    -- Flicker as a unit (same tempo as game over text)
    local instructionFlickerRate = 8  -- Same as game over text
    local instructionFlickerTime = glitchTextTimer * instructionFlickerRate
    local instructionFlickerPhase = instructionFlickerTime % 1.0
    local instructionIsVisible = instructionFlickerPhase < 0.6  -- Show for 60% of the cycle
    
    -- Draw rays for instruction text (only when visible, as a unit)
    if instructionIsVisible then
        -- Calculate scaling (same as drawGlitchyTerminalText)
        local baseScale = 1.0 + math.sin(glitchTextTimer * 4) * 0.05  -- Pulse between 0.95 and 1.05
        
        -- Render instruction text to canvas to sample pixels (with scaling applied)
        local instructionTextWidth = terminalFont:getWidth(instructionText)
        local instructionPadding = 20
        -- Account for scaling in canvas size
        local instructionCanvasWidth = (instructionTextWidth * baseScale) + instructionPadding * 2
        local instructionCanvasHeight = (terminalFont:getHeight() * baseScale) + instructionPadding * 2
        local instructionCanvas = love.graphics.newCanvas(instructionCanvasWidth, instructionCanvasHeight)
        instructionCanvas:setFilter("nearest", "nearest")
        
        local oldCanvas2 = love.graphics.getCanvas()
        local oldShader2 = love.graphics.getShader()
        local oldBlendMode2 = love.graphics.getBlendMode()
        
        love.graphics.setCanvas(instructionCanvas)
        love.graphics.setShader()
        love.graphics.setBlendMode("alpha")
        love.graphics.clear(0, 0, 0, 0)
        
        -- Apply scaling when rendering to canvas (same as drawGlitchyTerminalText)
        -- The text baseline is at y, and scaled around the horizontal center
        love.graphics.push()
        local canvasTextX = instructionPadding + (instructionTextWidth * baseScale) / 2
        local canvasTextY = instructionPadding  -- Baseline at padding (not vertically centered)
        love.graphics.translate(canvasTextX, canvasTextY)
        love.graphics.scale(baseScale, baseScale)
        love.graphics.translate(-instructionTextWidth / 2, 0)  -- Only horizontal centering
        
        love.graphics.setColor(0, 1, 0, alpha)  -- Use same alpha as text
        love.graphics.setFont(terminalFont)
        love.graphics.print(instructionText, 0, 0)
        
        love.graphics.pop()
        
        love.graphics.setCanvas(oldCanvas2)
        love.graphics.setShader(oldShader2)
        love.graphics.setBlendMode(oldBlendMode2)
        
        -- Get ImageData and sample pixels for rays
        local instructionImageData = instructionCanvas:newImageData()
        instructionCanvas:release()
        
        local instWidth = instructionImageData:getWidth()
        local instHeight = instructionImageData:getHeight()
        
        -- Calculate text position for ray coordinate conversion (accounting for scaling)
        -- The text baseline is at instructionTextY, horizontally centered at instructionTextX
        local textCenterX = instructionTextX
        local textBaselineY = instructionTextY
        
        -- Canvas position where text is rendered (accounting for padding and scaling)
        local canvasTextX = instructionPadding + (instructionTextWidth * baseScale) / 2
        local canvasTextBaselineY = instructionPadding  -- Baseline at padding
        
        for y = 0, instHeight - 1, 1 do
            for x = 0, instWidth - 1, 1 do
                local r, g, b, a = instructionImageData:getPixel(x, y)
                if a > 0.1 then
                    if (x % pixelSampleRate == 0) and (y % pixelSampleRate == 0) then
                        -- Convert canvas coordinates to screen coordinates
                        -- The canvas has the scaled text, so we need to map canvas pixels to screen pixels
                        -- Canvas pixel (x, y) is relative to canvas text position, then we map to screen position
                        local canvasRelX = x - canvasTextX
                        local canvasRelY = y - canvasTextBaselineY
                        
                        -- Map to screen space (text baseline at instructionTextY, centered at instructionTextX)
                        local screenX = textCenterX + canvasRelX
                        local screenY = textBaselineY + canvasRelY
                        
                        local pixelBrightness = g * a
                        local lineBrightness = pixelBrightness * 0.5
                        
                        love.graphics.setColor(
                            lineColor[1] * lineBrightness,
                            lineColor[2] * lineBrightness,
                            lineColor[3] * lineBrightness,
                            finalOpacity
                        )
                        
                        love.graphics.line(screenX, screenY, centerX, centerY)
                    end
                end
            end
        end
        
        instructionImageData:release()
        
        -- Draw instruction text using the same terminal text style (flickers as a unit)
        TopBanner.drawGlitchyTerminalText(instructionText, instructionTextX, instructionTextY, 32, glitchTextTimer, 1.0, terminalFont)
    end
    
    -- Restore state (after drawing both name entry and instruction text rays)
    love.graphics.setBlendMode(oldBlendMode)
    love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
    love.graphics.setLineWidth(oldLineWidth)
    
    -- Then, draw the text characters on top of the rays using the same terminal text style
    -- Per-character flicker: each character flickers independently
    for _, data in ipairs(charData) do
        -- Only draw when this character is visible
        if not data.isVisible then
            goto continue_char_text
        end
        
        -- Highlight current cursor position with yellow background
        if data.isCursor then
            -- Draw blinking cursor background
            if math.floor(love.timer.getTime() * 2) % 2 == 0 then
                love.graphics.setColor(1, 1, 0, 0.3)
                love.graphics.rectangle("fill", data.x - 5, data.y - 5, charWidth + 10, terminalFont:getHeight() + 10)
            end
        end
        
        -- Draw character using the same terminal text style as other terminal text
        TopBanner.drawGlitchyTerminalChar(data.char, data.x, data.y, glitchTextTimer, terminalFont, alpha)
        ::continue_char_text::
    end
end

-- Draw life lost auditor screen (engagement depleted but lives remain)
function drawLifeLostAuditor()
    -- Draw frozen game state (no updates, but visible)
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
    DrawingHelpers.drawTealWallpaper()
    
    -- Apply shake transform to everything (background, game, windows)
    love.graphics.push()
        if Game.shake > 0 then
            local s = Game.shake * Game.shake * 15; love.graphics.translate(love.math.random(-s, s), love.math.random(-s, s))
        end
        
        -- Draw background image if loaded and enabled (full screen) - now affected by shake
        if Game.showBackgroundForeground and Game.assets.background then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(Game.assets.background, 0, 0, 0, 
                Constants.SCREEN_WIDTH / Game.assets.background:getWidth(),
                Constants.SCREEN_HEIGHT / Game.assets.background:getHeight())
        end
        
        -- Draw grid on playfield (affected by shake)
        DrawingHelpers.drawPlayfieldGrid()
        
        -- Draw frozen game elements
        DrawingHelpers.drawFrozenGameState()
        
        -- Draw Windows 95 style frame around the playfield (A.R.A.C. Control Interface)
        do
            local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
            local borderWidth = Constants.UI.BORDER_WIDTH
            local frameX = Constants.OFFSET_X - borderWidth
            local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
            local frameW = Constants.PLAYFIELD_WIDTH + (borderWidth * 2)
            local frameH = Constants.PLAYFIELD_HEIGHT + titleBarHeight + (borderWidth * 2)

            WindowFrame.draw(frameX, frameY, frameW, frameH, "A.R.A.C. Control Interface")
        end
        
        -- Draw webcam window (below playfield, affected by shake)
        Webcam.draw()
        
        -- Draw engagement plot (next to webcam, affected by shake)
        EngagementPlot.draw()
        
        -- Draw score window (below playfield, centered)
        drawScoreWindow()
        
        -- Draw doomscroll window (below score window)
        Doomscroll.draw(Game.fonts)
        
        -- Draw multiplier window (below engagement plot) - skip in demo mode
        if not Game.modes.demo then
            drawMultiplierWindow()
        end
        
    love.graphics.pop()
    
        -- Draw black overlay during life lost (behind banner, in front of game)
        local greyFade = TopBanner.getGameOverGreyFade()
        if TopBanner.isGameOverDropActive() and greyFade > 0 then
            DrawingHelpers.drawBlackOverlay(greyFade)
        end
    
    -- Draw terminal text for life lost
    if Game.modes.lifeLostAuditor then
        TopBanner.drawLifeLostText(Game.timers.glitchText, Game.visualEffects.glitchTextWriteProgress, Game.fonts.terminal)
    end
end

-- Draw game over screen (same as life lost but with different text)
function drawGameOver()
    -- Draw frozen game state (no updates, but visible)
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
    DrawingHelpers.drawTealWallpaper()
    
    -- Apply shake transform to everything (background, game, windows)
    love.graphics.push()
        if Game.shake > 0 then
            local s = Game.shake * Game.shake * 15; love.graphics.translate(love.math.random(-s, s), love.math.random(-s, s))
        end
        
        -- Draw background image if loaded and enabled (full screen) - now affected by shake
        if Game.showBackgroundForeground and Game.assets.background then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(Game.assets.background, 0, 0, 0, 
                Constants.SCREEN_WIDTH / Game.assets.background:getWidth(),
                Constants.SCREEN_HEIGHT / Game.assets.background:getHeight())
        end
        
        -- Draw grid on playfield (affected by shake)
        DrawingHelpers.drawPlayfieldGrid()
        
        -- Draw frozen game elements
        DrawingHelpers.drawFrozenGameState()
        
        -- Draw Windows 95 style frame around the playfield (A.R.A.C. Control Interface)
        do
            local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
            local borderWidth = Constants.UI.BORDER_WIDTH
            local frameX = Constants.OFFSET_X - borderWidth
            local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
            local frameW = Constants.PLAYFIELD_WIDTH + (borderWidth * 2)
            local frameH = Constants.PLAYFIELD_HEIGHT + titleBarHeight + (borderWidth * 2)

            WindowFrame.draw(frameX, frameY, frameW, frameH, "A.R.A.C. Control Interface")
        end
        
        -- Draw webcam window (below playfield, affected by shake)
        Webcam.draw()
        
        -- Draw engagement plot (next to webcam, affected by shake)
        EngagementPlot.draw()
        
        -- Draw score window (below playfield, centered)
        drawScoreWindow()
        
        -- Draw doomscroll window (below score window)
        Doomscroll.draw(Game.fonts)
        
        -- Draw multiplier window (below engagement plot) - skip in demo mode
        if not Game.modes.demo then
            drawMultiplierWindow()
        end
        
    love.graphics.pop()
    
    -- Draw black overlay during game over (behind banner, in front of game)
    local greyFade = TopBanner.getGameOverGreyFade()
    if TopBanner.isGameOverDropActive() and greyFade > 0 then
        DrawingHelpers.drawBlackOverlay(greyFade)
    end
    
    -- Draw terminal text for game over
    if Game.modes.gameOver then
        TopBanner.drawGameOverText(Game.timers.glitchText, Game.visualEffects.glitchTextWriteProgress, Game.fonts.terminal)
    end
end

-- Draw THE AUDITOR game over sequence
function drawAuditor()
    -- Phase 1: System freeze - show frozen game state
    if Game.auditor.phase == 1 then
        -- Draw frozen game state (no updates, but visible)
        love.graphics.clear(Constants.COLORS.BACKGROUND)
        
        -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
        DrawingHelpers.drawTealWallpaper()
        
        -- Draw frozen game elements
        DrawingHelpers.drawFrozenGameState()
        
        -- Show webcam with CRITICAL_ERROR
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.setFont(Game.fonts.large)
        local errorMsg = Auditor.CRITICAL_ERROR
        local errorWidth = Game.fonts.large:getWidth(errorMsg)
        love.graphics.print(errorMsg, Constants.SCREEN_WIDTH / 2 - errorWidth / 2, Constants.SCREEN_HEIGHT / 2)
        
    -- Phase 2: Fade to black, show THE AUDITOR
    elseif Game.auditor.phase == 2 then
        local fadeProgress = Game.timers.auditor / 2.0
        local fadeAlpha = math.min(fadeProgress, 1.0)
        
        -- Draw teal wallpaper first (visible before fade takes over)
        DrawingHelpers.drawTealWallpaper()
        
        -- Draw frozen game elements (visible before fade)
        DrawingHelpers.drawFrozenGameState()
        
        -- Fade to black
        DrawingHelpers.drawBlackOverlay(fadeAlpha)
        
        -- Show THE AUDITOR (hooded figure with red camera lens)
        if fadeAlpha >= 0.5 then
            local auditorAlpha = (fadeAlpha - 0.5) * 2  -- Fade in during second half
            drawAuditorFigure(auditorAlpha)
        end
        
    -- Phase 3: Show verdict text
    elseif Game.auditor.phase == 3 then
        -- Black background
        DrawingHelpers.drawBlackOverlay(1.0)
        
        -- Draw THE AUDITOR
        drawAuditorFigure(1.0)
        
        -- Show verdict text
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(1, 0, 0, 1)  -- Red text
        
        local verdict1 = Auditor.VERDICT[1]
        local verdict2 = Auditor.VERDICT[2]
        
        local v1Width = Game.fonts.large:getWidth(verdict1)
        local v2Width = Game.fonts.large:getWidth(verdict2)
        
        love.graphics.print(verdict1, Constants.SCREEN_WIDTH / 2 - v1Width / 2, Constants.SCREEN_HEIGHT / 2 - 50)
        love.graphics.print(verdict2, Constants.SCREEN_WIDTH / 2 - v2Width / 2, Constants.SCREEN_HEIGHT / 2 + 50)
        
    -- Phase 4: Crash to black
    elseif Game.auditor.phase == 4 then
        DrawingHelpers.drawBlackOverlay(1.0)
    end
end

-- Draw THE AUDITOR figure (hooded figure with red camera lens)
function drawAuditorFigure(alpha)
    local centerX = Constants.SCREEN_WIDTH / 2
    local centerY = Constants.SCREEN_HEIGHT / 2
    
    -- Hood (dark shape)
    love.graphics.setColor(0.1, 0.1, 0.1, alpha)
    love.graphics.ellipse("fill", centerX, centerY - 100, 200, 250)
    
    -- Hood outline
    love.graphics.setColor(0.05, 0.05, 0.05, alpha)
    love.graphics.setLineWidth(3)
    love.graphics.ellipse("line", centerX, centerY - 100, 200, 250)
    
    -- Red camera lens (glowing eye)
    love.graphics.setColor(1, 0, 0, alpha)
    love.graphics.circle("fill", centerX, centerY - 80, 40)
    
    -- Inner glow
    love.graphics.setColor(1, 0.3, 0.3, alpha * 0.6)
    love.graphics.circle("fill", centerX, centerY - 80, 30)
    
    -- Bright center
    love.graphics.setColor(1, 1, 1, alpha * 0.8)
    love.graphics.circle("fill", centerX, centerY - 80, 15)
    
    -- Outer glow ring
    love.graphics.setColor(1, 0, 0, alpha * 0.3)
    love.graphics.setLineWidth(5)
    love.graphics.circle("line", centerX, centerY - 80, 50)
end

-- Draw level completion screen with Chase Paxton
function drawWinTextScreen()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
    DrawingHelpers.drawTealWallpaper()
    
    -- Apply shake transform (if any)
    love.graphics.push()
        if Game.shake and Game.shake > 0 then
            local s = Game.shake * Game.shake * 15; love.graphics.translate(love.math.random(-s, s), love.math.random(-s, s))
        end
        
        -- Draw background image if loaded and enabled
        if Game.showBackgroundForeground and Game.assets.background then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(Game.assets.background, 0, 0, 0, 
                Constants.SCREEN_WIDTH / Game.assets.background:getWidth(),
                Constants.SCREEN_HEIGHT / Game.assets.background:getHeight())
        end
        
        -- Draw the game frozen in the background (faded)
        if Game.turret then
            local function drawGameFrozen()
                World.draw(function()
                -- Draw units (frozen)
                for _, u in ipairs(Game.units) do
                    if not u.isDead then
                        u:draw()
                    end
                end
                
                -- Draw projectiles (frozen)
                for _, p in ipairs(Game.projectiles) do
                    if not p.isDead then
                        p:draw()
                    end
                end
                
                -- Draw effects (frozen)
                for _, e in ipairs(Game.effects) do
                    if e.type == "explosion" and e.duration and e.duration > 0 then
                        local t = e.timer / e.duration
                        local alpha = 1.0 - t
                        local radius = e.radius * (1.0 - t * 0.5)
                        love.graphics.setColor(1, 1, 0, alpha * 0.5)
                        love.graphics.circle("fill", e.x, e.y, radius, 32)
                    elseif e.type == "explosion" then
                        -- Fallback if duration is missing - just draw at current state
                        love.graphics.setColor(1, 1, 0, 0.5)
                        love.graphics.circle("fill", e.x, e.y, e.radius or 50, 32)
                    end
                end
                
                -- Draw turret (frozen)
                if Game.turret then
                    Game.turret:draw()
                end
            end)
        end
        
        love.graphics.setColor(1, 1, 1, 0.3)  -- Fade the game
        drawGameFrozen()
        
        -- Add color tint overlay based on win condition
        if Game.winCondition == "blue_only" then
            -- Blue tint overlay
            love.graphics.setColor(0.2, 0.4, 1.0, 0.4)  -- Blue with transparency
            love.graphics.rectangle("fill", Constants.OFFSET_X, Constants.OFFSET_Y, 
                Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT)
        elseif Game.winCondition == "red_only" then
            -- Red tint overlay
            love.graphics.setColor(1.0, 0.2, 0.2, 0.4)  -- Red with transparency
            love.graphics.rectangle("fill", Constants.OFFSET_X, Constants.OFFSET_Y, 
                Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT)
        end
        
        -- Draw grid on playfield (after overlays so it's visible on top)
        DrawingHelpers.drawPlayfieldGrid()
    end
    
    love.graphics.pop()
    
    -- Win text removed - Chase Paxton handles this in his dialogue
    
    -- Draw animating webcam window if animation is active (during matrix transition)
    if Game.webcamWindow.animating or Game.webcamWindow.dialogueActive then
        drawAnimatingWebcamWindow()
    end
end

-- Draw animating webcam window (used during level complete sequence)
function drawAnimatingWebcamWindow()
    if not Game.webcamWindow.animating and not Game.webcamWindow.dialogueActive then
        return
    end
    
    -- Get original webcam window position and size
    local originalWidth = Constants.UI.WEBCAM_GAMEPLAY_WIDTH
    local originalHeight = Constants.UI.WEBCAM_GAMEPLAY_HEIGHT
    local originalX = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH - originalWidth - Constants.UI.WEBCAM_GAMEPLAY_OFFSET_X
    local originalY = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + Constants.UI.WEBCAM_GAMEPLAY_OFFSET_Y
    
    -- Target position and size (centered, scaled up)
    local targetWidth = originalWidth * Constants.UI.WEBCAM_ANIMATION_SCALE
    local targetHeight = originalHeight * Constants.UI.WEBCAM_ANIMATION_SCALE
    local targetX = (Constants.SCREEN_WIDTH - targetWidth) / 2
    local targetY = (Constants.SCREEN_HEIGHT - targetHeight) / 2
    
    -- Calculate animated position and scale
    local animProgress = 0
    if Game.webcamWindow.animating and Game.webcamWindow.animDuration and Game.webcamWindow.animDuration > 0 then
        if Game.webcamWindow.reversing then
            -- Reverse animation: go from 1.0 back to 0.0
            animProgress = math.max((Game.timers.webcamWindowAnim or 0) / Game.webcamWindow.animDuration, 0.0)
            animProgress = 1 - math.pow(1 - animProgress, 3)  -- Ease out (but reversed)
        else
            -- Forward animation: go from 0.0 to 1.0
            animProgress = math.min((Game.timers.webcamWindowAnim or 0) / Game.webcamWindow.animDuration, 1.0)
            animProgress = 1 - math.pow(1 - animProgress, 3)  -- Ease out cubic
        end
    elseif Game.webcamWindow.dialogueActive then
        animProgress = 1.0  -- Fully centered during dialogue
    else
        animProgress = 0.0
    end
    
    local WEBCAM_WIDTH = originalWidth + (targetWidth - originalWidth) * animProgress
    local WEBCAM_HEIGHT = originalHeight + (targetHeight - originalHeight) * animProgress
    local WEBCAM_X = originalX + (targetX - originalX) * animProgress
    local WEBCAM_Y = originalY + (targetY - originalY) * animProgress
    
    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local borderWidth = Constants.UI.BORDER_WIDTH
    
    -- Draw transparent black background for content area
    DrawingHelpers.drawWindowContentBackground(WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT, titleBarHeight, borderWidth)
    
    -- Draw Windows 95 style frame with title bar
    WindowFrame.draw(WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT, "Chase Paxton")
    
    -- Draw Chase Paxton character portrait - adjust for title bar
    local charX = WEBCAM_X + WEBCAM_WIDTH / 2
    local charY = WEBCAM_Y + titleBarHeight + borderWidth + (WEBCAM_HEIGHT - titleBarHeight - borderWidth) / 2
    
    -- Calculate available space (accounting for title bar and borders)
    local availableWidth = WEBCAM_WIDTH - (borderWidth * 2)
    local availableHeight = WEBCAM_HEIGHT - titleBarHeight - (borderWidth * 2)
    
    -- Calculate scale to fit within webcam window
    local portraitScale = ChasePortrait.calculateScale(availableWidth, availableHeight, 10)
    ChasePortrait.draw(charX, charY, portraitScale)
    
    -- Draw dialogue messages when centered (dialogue active)
    if Game.webcamWindow.dialogueActive and animProgress >= 0.99 then
        -- Calculate subtitle position (below portrait, centered)
        local subtitleY = charY + (availableHeight / 2) + 20  -- Below portrait center
        local subtitleHeight = 50  -- Increased for larger font
        local subtitleWidth = availableWidth - 20
        local subtitleX = WEBCAM_X + borderWidth + 10
        
        -- Draw subtitle background (semi-transparent black bar)
        love.graphics.setColor(0, 0, 0, 0.7)  -- Semi-transparent black
        love.graphics.rectangle("fill", subtitleX, subtitleY, subtitleWidth, subtitleHeight)
        
        -- Draw current sentence as subtitle (centered)
        if Game.webcamWindow.dialogueCurrentSentence <= #Game.webcamWindow.dialogueSentences then
            local currentSentence = Game.webcamWindow.dialogueSentences[Game.webcamWindow.dialogueCurrentSentence]
            love.graphics.setFont(Game.fonts.large)
            love.graphics.setColor(1, 1, 1, 1)  -- White
            local sentenceWidth = Game.fonts.large:getWidth(currentSentence)
            local sentenceX = subtitleX + (subtitleWidth - sentenceWidth) / 2
            local sentenceY = subtitleY + (subtitleHeight - Game.fonts.large:getHeight()) / 2
            love.graphics.print(currentSentence, sentenceX, sentenceY)
        end
    end
end

-- drawLevelCompleteScreen() removed - functionality now handled by drawAnimatingWebcamWindow()

-- Draw ready screen with GET READY and GO! text
function drawReadyScreen()
    -- Draw the normal game playfield in background (same as drawGame but without HUD)
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
    DrawingHelpers.drawTealWallpaper()
    
    -- Apply shake transform
    love.graphics.push()
        if Game.shake > 0 then
            local s = Game.shake * Game.shake * 15; love.graphics.translate(love.math.random(-s, s), love.math.random(-s, s))
        end
        
        -- Draw background image if loaded and enabled
        if Game.showBackgroundForeground and Game.assets.background then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(Game.assets.background, 0, 0, 0, 
                Constants.SCREEN_WIDTH / Game.assets.background:getWidth(),
                Constants.SCREEN_HEIGHT / Game.assets.background:getHeight())
        end
        
        -- Draw grid on playfield (affected by shake)
        DrawingHelpers.drawPlayfieldGrid()
        
        -- Draw game elements
        World.draw(function()
            for _, h in ipairs(Game.hazards) do
                if h.splat then
                    -- Use animated splat
                    local a = (h.timer / (h.radius == Constants.INSANE_TOXIC_RADIUS and Constants.INSANE_TOXIC_DURATION or Constants.TOXIC_DURATION)) * 0.4
                    ToxicSplat.draw(h.splat, a)
                else
                    -- Fallback to simple circle if splat not initialized
                    local r,g,b = unpack(Constants.COLORS.TOXIC); local a = (h.timer/Constants.TOXIC_DURATION)*0.4
                    love.graphics.setColor(r,g,b,a); love.graphics.circle("fill", h.x, h.y, h.radius)
                    love.graphics.setColor(r,g,b,a+0.2); love.graphics.setLineWidth(2); love.graphics.circle("line", h.x, h.y, h.radius)
                end
            end
            
            if #Game.explosionZones > 0 then
                love.graphics.clear(false, true, false) 
                for _, z in ipairs(Game.explosionZones) do
                    love.graphics.setStencilTest("equal", 0)
                    if z.color == "red" then love.graphics.setColor(1, 0, 0, 0.3) else love.graphics.setColor(0, 0, 1, 0.3) end
                    love.graphics.circle("fill", z.x, z.y, z.radius, 64)
                    love.graphics.setLineWidth(3); love.graphics.setColor(1, 1, 1, 0.5); love.graphics.circle("line", z.x, z.y, z.radius, 64)
                    love.graphics.setStencilTest(); love.graphics.stencil(function() love.graphics.circle("fill", z.x, z.y, z.radius, 64) end, "replace", 1)
                end
                love.graphics.setStencilTest()
            end
            
            for _, u in ipairs(Game.units) do u:draw() end
            for _, p in ipairs(Game.projectiles) do p:draw() end
            for _, pup in ipairs(Game.powerups) do pup:draw() end
            
            for _, e in ipairs(Game.effects) do
                if e.type == "explosion" then
                    love.graphics.setLineWidth(3)
                    if e.color == "gold" then love.graphics.setColor(1, 0.8, 0.2, e.alpha)
                    elseif e.color == "red" then love.graphics.setColor(1, 0.2, 0.2, e.alpha)
                    else love.graphics.setColor(0.2, 0.2, 1, e.alpha) end
                    love.graphics.circle("line", e.x, e.y, e.radius, 64); love.graphics.setColor(1, 1, 1, e.alpha * 0.2); love.graphics.circle("fill", e.x, e.y, e.radius, 64)
                elseif e.type == "orange_splat" then
                    -- Draw orange explosion splat with fiery orange colors
                    if e.splat then
                        love.graphics.push()
                        love.graphics.translate(e.splat.x, e.splat.y)
                        love.graphics.scale(e.splat.currentScale)
                        
                        -- PASS 1: Base Orange Layer
                        love.graphics.setBlendMode("alpha")
                        love.graphics.setColor(0.8, 0.3, 0.1, e.alpha)
                        
                        for _, shape in ipairs(e.splat.shapes) do
                            love.graphics.circle("fill", shape.x, shape.y, shape.r)
                        end
                        
                        -- PASS 2: Additive Highlights (Fiery Glow)
                        love.graphics.setBlendMode("add")
                        love.graphics.setColor(0.6, 0.4, 0.1, 0.6 * e.alpha)  -- Fiery orange glow
                        
                        -- Only highlight blobs/lumps, streaks are too thin to notice
                        for _, shape in ipairs(e.splat.shapes) do
                            if shape.type == "core" or shape.type == "lump" or (shape.type == "blob" and shape.r > 1.2) then
                                local offX = -0.4 * shape.r * 0.3
                                local offY = -0.4 * shape.r * 0.3
                                -- Scale highlight down slightly
                                love.graphics.circle("fill", shape.x + offX, shape.y + offY, shape.r * 0.7)
                            end
                        end
                        
                        love.graphics.setBlendMode("alpha")
                        love.graphics.pop()
                    end
                end
            end
            
            if Game.turret then Game.turret:draw() end
        end)
        
        -- Draw Windows 95 style frame around the playfield (A.R.A.C. Control Interface)
        do
            local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
            local borderWidth = Constants.UI.BORDER_WIDTH
            local frameX = Constants.OFFSET_X - borderWidth
            local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
            local frameW = Constants.PLAYFIELD_WIDTH + (borderWidth * 2)
            local frameH = Constants.PLAYFIELD_HEIGHT + titleBarHeight + (borderWidth * 2)

            WindowFrame.draw(frameX, frameY, frameW, frameH, "A.R.A.C. Control Interface")
        end
        
        -- Draw webcam window (below playfield, affected by shake)
        Webcam.draw()
        
        -- Draw engagement plot (next to webcam, affected by shake)
        EngagementPlot.draw()
        
        -- Draw score window (below playfield, centered)
        drawScoreWindow()
        
        -- Draw doomscroll window (below score window)
        Doomscroll.draw(Game.fonts)
        
        -- Draw multiplier window (below engagement plot) - skip in demo mode
        if not Game.modes.demo then
            drawMultiplierWindow()
        end
        
    love.graphics.pop()
    
    -- Create giant font if not cached (use DOS font)
    if not Game.fonts.multiplierGiant then
        local success, dosFont = pcall(love.graphics.newFont, "assets/ModernDOS9x16.ttf", Constants.UI.FONT_MULTIPLIER_GIANT)
        if success and dosFont then
            Game.fonts.multiplierGiant = dosFont
        else
            Game.fonts.multiplierGiant = love.graphics.newFont(Constants.UI.FONT_MULTIPLIER_GIANT)
        end
    end
    
    local centerX, centerY = DrawingHelpers.getScreenCenter()
    
    if Game.ready.phase == 1 then
        -- Phase 1: Fade out black overlay (show frozen game)
        -- Text not shown yet
    elseif Game.ready.phase == 2 then
        -- Phase 2: Show "GET READY" text
        local elapsed = Game.timers.ready - Constants.TIMING.READY_FADE_OUT_DURATION
        local textAlpha = math.min(elapsed / 0.3, 1.0)  -- Fade in over 0.3s
        
        love.graphics.setFont(Game.fonts.multiplierGiant)
        
        -- Pulsing color effect
        local pulse = DrawingHelpers.calculatePulse(4)
        local r = 0.2 + pulse * 0.8
        local g = 0.8 + pulse * 0.2
        local b = 0.2 + pulse * 0.8
        
        local text = "GET READY"
        local textWidth = Game.fonts.multiplierGiant:getWidth(text)
        local textHeight = Game.fonts.multiplierGiant:getHeight()
        
        DrawingHelpers.drawTextWithOutline(text, centerX - textWidth / 2, centerY - textHeight / 2, r, g, b, textAlpha)
        
        -- Draw sparks
        ParticleSystem.draw(Game.ready.sparks)
    elseif Game.ready.phase == 3 then
        -- Phase 3: Show "GO!" text
        local elapsed = Game.timers.ready - Constants.TIMING.READY_FADE_OUT_DURATION - Constants.TIMING.READY_GET_READY_DURATION
        local textAlpha = math.min(elapsed / 0.2, 1.0)  -- Fade in quickly
        
        love.graphics.setFont(Game.fonts.multiplierGiant)
        
        -- Pulsing color effect (more intense)
        local pulse = DrawingHelpers.calculatePulse(6)
        local r = 0.8 + pulse * 0.2
        local g = 0.2 + pulse * 0.8
        local b = 0.2 + pulse * 0.8
        
        local text = "GO!"
        local textWidth = Game.fonts.multiplierGiant:getWidth(text)
        local textHeight = Game.fonts.multiplierGiant:getHeight()
        local centerX, centerY = DrawingHelpers.getScreenCenter()
        
        DrawingHelpers.drawTextWithOutline(text, centerX - textWidth / 2, centerY - textHeight / 2, r, g, b, textAlpha)
        
        -- Draw sparks
        ParticleSystem.draw(Game.ready.sparks)
    end
end


function love.update(dt)
    -- Don't quit on escape if dynamic music sandbox is open
    if not DynamicMusic.isActive() and love.keyboard.isDown("escape") then 
        love.event.quit() 
    end
    
    -- Handle booting screen
    if Game.modes.booting then
        Game.timers.booting = Game.timers.booting + dt
        
        -- After 10 seconds, transition to logo screen
        if Game.timers.booting >= 10.0 then
            Game.modes.booting = false
            Game.timers.booting = 0
            Game.modes.logo = true
            Game.timers.logo = 0
            Game.timers.previousLogo = 0
            Game.assets.logoFanfarePlayed = false
        end
        
        return  -- Don't update game logic during booting screen
    end
    
    -- Handle matrix screen
    if Game.modes.matrix then
        -- Pause matrix screen updates if dynamic music sandbox is open
        if not DynamicMusic.isActive() then
            Game.timers.matrix = Game.timers.matrix + dt
            MatrixEffect.update(dt)
            -- Keep running until space is pressed (handled in InputHandler)
        end
        
        -- Update dynamic music player (even when paused)
        DynamicMusic.update(dt)
        
        return  -- Don't update game logic during matrix screen
    end
    
    -- Handle logo screen
    if Game.modes.logo then
        -- Pause logo screen updates if dynamic music sandbox is open
        if not DynamicMusic.isActive() then
            Game.timers.previousLogo = Game.timers.logo
            Game.timers.logo = Game.timers.logo + dt
            
            -- Play fanfare exactly when the blink animation starts (at 2.5 seconds)
            -- This happens when the logo image changes to the blink version
            if Game.timers.previousLogo < 2.5 and Game.timers.logo >= 2.5 then
                Sound.playFanfare()
            end
            
            -- After 5.75 seconds (1s slide + 1.5s wait + 0.25s blink + 3s wait), transition to attract mode
            if Game.timers.logo >= 5.75 then
                Game.modes.logo = false
                Game.timers.logo = 0
                Game.timers.previousLogo = 0
                Game.assets.logoFanfarePlayed = false
                Game.modes.attract = true
                Game.modes.attractTimer = 0
                -- Start playing intro music when transitioning to attract mode
                Sound.playIntroMusic()
            end
        end
        
        -- Update dynamic music player (even when paused)
        DynamicMusic.update(dt)
        
        return  -- Don't update game logic during logo screen
    end

    -- Handle joystick test mode (input-only screen, no game simulation)
    if Game.modes.joystickTest then
        return
    end
    
    -- Handle demo mode
    if Game.modes.demo then
        DemoMode.update(dt)
        -- Update game normally in demo mode
        -- (AI will control turret, but game logic runs)
    end
    
    -- Handle attract mode
    if Game.modes.attract then
        -- Pause attract mode updates if dynamic music sandbox is open
        if not DynamicMusic.isActive() then
            AttractMode.update(dt)
        end
        DynamicMusic.update(dt)
        return  -- Don't update game logic in attract mode
    end
    
    -- Update dynamic music player (also during logo screen)
    if Game.modes.logo then
        DynamicMusic.update(dt)
    end
    
    -- Handle ready screen (GET READY / GO!)
    if Game.modes.ready then
        Game.timers.ready = Game.timers.ready + dt
        
        -- Phase 1: Fade out black overlay (0.5s)
        if Game.ready.phase == 1 then
            if Game.timers.ready >= Constants.TIMING.READY_FADE_OUT_DURATION then
                Game.ready.phase = 2
                Game.timers.ready = Constants.TIMING.READY_FADE_OUT_DURATION
                -- Create sparks for GET READY
                local centerX = Constants.SCREEN_WIDTH / 2
                local centerY = Constants.SCREEN_HEIGHT / 2
                Game.ready.sparks = ParticleSystem.createSparks(
                    centerX, centerY,
                    Constants.UI.SPARK_COUNT_READY,
                    Constants.UI.SPARK_SPEED_MIN,
                    Constants.UI.SPARK_SPEED_MAX,
                    Constants.UI.SPARK_SIZE_MIN,
                    Constants.UI.SPARK_SIZE_MAX,
                    Constants.UI.SPARK_LIFETIME
                )
            end
        -- Phase 2: Show "GET READY" (1.5s)
        elseif Game.ready.phase == 2 then
            if Game.timers.ready >= Constants.TIMING.READY_FADE_OUT_DURATION + Constants.TIMING.READY_GET_READY_DURATION then
                Game.ready.phase = 3
                -- Create more sparks for GO!
                local centerX = Constants.SCREEN_WIDTH / 2
                local centerY = Constants.SCREEN_HEIGHT / 2
                Game.ready.sparks = ParticleSystem.createSparks(
                    centerX, centerY,
                    Constants.UI.SPARK_COUNT_LEVEL_COMPLETE,
                    Constants.UI.SPARK_SPEED_MIN_LEVEL_COMPLETE,
                    Constants.UI.SPARK_SPEED_MAX_LEVEL_COMPLETE,
                    Constants.UI.SPARK_SIZE_MIN,
                    Constants.UI.SPARK_SIZE_MAX,
                    Constants.UI.SPARK_LIFETIME
                )
            end
        -- Phase 3: Show "GO!" (0.5s), then start playing
        elseif Game.ready.phase == 3 then
            if Game.timers.ready >= Constants.TIMING.READY_FADE_OUT_DURATION + Constants.TIMING.READY_GET_READY_DURATION + Constants.TIMING.READY_GO_DURATION then
                Game.modes.ready = false
                Game.timers.ready = 0
                Game.ready.phase = 1
                Game.gameState = "playing"
                -- Trigger eyelid animation when gameplay starts
                MonitorFrame.startEyelidAnimation()
            end
        end
        
        -- Update sparks
        ParticleSystem.update(Game.ready.sparks, dt, nil, Constants.UI.SPARK_FADE_RATE_READY)
        
        -- Update monitor frame (for eyelid animation that starts at end of ready sequence)
        MonitorFrame.update(dt)
        
        -- Update turret during ready sequence (to initialize legs)
        if Game.turret then
            Game.turret:update(dt)
        end
        
        return  -- Don't update other game logic during ready sequence
    end
    
    -- Handle intro video
    if Game.modes.video then
        -- Update music fade
        if Game.intro.musicFadeActive then
            Game.timers.introMusicFade = Game.timers.introMusicFade + dt
            local fadeDuration = 3.0  -- 3 seconds
            local fadeProgress = math.min(1.0, Game.timers.introMusicFade / fadeDuration)
            
            -- Interpolate volume from start to target
            local currentVolume = Game.intro.musicFadeStartVolume + 
                (Game.intro.musicFadeTargetVolume - Game.intro.musicFadeStartVolume) * fadeProgress
            Sound.setMusicVolume(currentVolume)
            
            -- Fade complete
            if fadeProgress >= 1.0 then
                Game.intro.musicFadeActive = false
            end
        end
        
        if Game.assets.introVideo then
            -- Check if video has finished
            if not Game.assets.introVideo:isPlaying() and Game.assets.introVideo:tell() > 0 then
                -- Video has finished, transition to intro screen
                Game.modes.video = false
                Game.modes.intro = true
                Game.timers.intro = 0
                Game.intro.step = 1
                Game.intro.musicFadeActive = false
                -- Restore normal glow strength when video ends
                if Game.glowEffect and Game.glowStrengthNormal then
                    Game.glowEffect.strength = Game.glowStrengthNormal
                end
            end
        else
            -- If video doesn't exist, skip directly to intro screen
            Game.modes.video = false
            Game.modes.intro = true
            Game.timers.intro = 0
            Game.intro.step = 1
            Game.intro.musicFadeActive = false
            -- Restore normal glow strength when video ends
            if Game.glowEffect and Game.glowStrengthNormal then
                Game.glowEffect.strength = Game.glowStrengthNormal
            end
        end
        return  -- Don't update game logic during video
    end
    
    -- Handle intro screen
    if Game.modes.intro then
        Game.timers.intro = Game.timers.intro + dt
        -- Update portrait animation
        ChasePortrait.update(dt)
        return  -- Don't update game logic during intro
    end
    
    -- Handle name entry
    if Game.modes.nameEntry then
        -- Update banner animation to maintain dropped state
        TopBanner.update(dt, Game.gameState, Engagement.value, Game.modes.gameOver, Game.modes.lifeLostAuditor)
        
        -- Update glitch text timer for flicker effect
        Game.timers.glitchText = Game.timers.glitchText + dt
        
        -- Decay shake to prevent it from getting stuck
        if Game.shake > 0 then
            Game.shake = math.max(0, Game.shake - 2.5 * dt)
        end
        
        return  -- Don't update other game logic during name entry
    end
    
    -- Handle life lost auditor screen (engagement depleted but lives remain)
    if Game.modes.lifeLostAuditor then
        -- Update banner animation FIRST (before checking if it's dropped)
        TopBanner.update(dt, Game.gameState, Engagement.value, Game.modes.gameOver, Game.modes.lifeLostAuditor)
        
        -- Update monitor frame animations (eyelid, BottomCenterPanel, etc.)
        MonitorFrame.update(dt)
        
        -- Update engagement-based panel animations (also handles reverse animation if active)
        MonitorFrame.updateEngagementAnimations(Engagement.value, dt)
        
        -- Update glitch text timer and write-on progress
        Game.timers.glitchText = Game.timers.glitchText + dt
        if Game.visualEffects.glitchTextWriteProgress < 1.0 then
            Game.visualEffects.glitchTextWriteProgress = math.min(1.0, Game.visualEffects.glitchTextWriteProgress + dt * 1.5)
        end
        
        -- Wait at dropped position for 5.5 seconds (banner drop animation is handled by TopBanner.update())
        -- Check if banner has finished dropping
        if TopBanner.isGameOverBannerDropped() then
            -- When banner hits down position, instantly move animated frame layers to top
            MonitorFrame.setEngagementPanelsToMaximum()
            
            -- Start counting timer when banner finishes dropping
            Game.timers.lifeLostAuditor = Game.timers.lifeLostAuditor + dt
            
            -- Check if we should start reverse animation
            if not Game.reverseAnimationActive and Game.timers.lifeLostAuditor >= Constants.TIMING.LIFE_LOST_WAIT_TIME then
                -- Start reverse animations
                Game.reverseAnimationActive = true
                Game.reverseEngagementActive = true
                Game.reverseEngagementTimer = 0
                Game.reverseEngagementStartValue = Engagement.value
                TopBanner.startReverseAnimation()
                MonitorFrame.startReverseAnimation()
            end
        else
            -- Banner hasn't finished dropping yet, reset timer
            Game.timers.lifeLostAuditor = 0
        end
        
        -- Update reverse animations if active (check this outside the banner dropped check)
        if Game.reverseAnimationActive then
            -- Animate engagement back to 100 over 1.5 seconds
            if Game.reverseEngagementActive then
                Game.reverseEngagementTimer = Game.reverseEngagementTimer + dt
                local progress = math.min(1.0, Game.reverseEngagementTimer / 1.5)
                Engagement.value = Game.reverseEngagementStartValue + 
                    (Constants.ENGAGEMENT_MAX - Game.reverseEngagementStartValue) * progress
                
                if progress >= 1.0 then
                    Engagement.value = Constants.ENGAGEMENT_MAX
                    Game.reverseEngagementActive = false
                end
            end
            
            -- Check if reverse animations are complete
            if TopBanner.isReverseAnimationComplete() and MonitorFrame.isReverseAnimationComplete() and not Game.reverseEngagementActive then
                -- Reverse animations complete, restart the level
                Game.reverseAnimationActive = false
                Game.modes.lifeLostAuditor = false
                Game.timers.lifeLostAuditor = 0
                Game.lifeLostAuditor.phase = 1
                restartLevel()
            end
        end
        
        -- Allow projectiles to continue updating so they can explode and stop sounds naturally
        Time.checkRestore(dt); Time.update(dt); local gameDt = dt * Time.scale
        for i = #Game.projectiles, 1, -1 do 
            local p = Game.projectiles[i]
            p:update(gameDt)
            if p.isDead then 
                table.remove(Game.projectiles, i) 
            end
        end
        
        return  -- Don't update game logic during life lost auditor sequence
    end
    
    -- Auditor sequence removed - game over now uses same screen as life lost (top bar only)
    -- This block is disabled
    if false and Game.modes.auditor and not Game.modes.intro then
        Game.timers.auditor = Game.timers.auditor + dt
        
        -- Phase 1: System freeze (1 second)
        if Game.auditor.phase == 1 and Game.timers.auditor >= 1.0 then
            Game.auditor.phase = 2
            Game.timers.auditor = 0
        -- Phase 2: Fade to black and show THE AUDITOR (2 seconds)
        elseif Game.auditor.phase == 2 and Game.timers.auditor >= 2.0 then
            Game.auditor.phase = 3
            Game.timers.auditor = 0
        -- Phase 3: Show verdict (3 seconds)
        elseif Game.auditor.phase == 3 and Game.timers.auditor >= 3.0 then
            Game.auditor.phase = 4
            Game.timers.auditor = 0
        -- Phase 4: Crash to black (1 second), then check for high score
        elseif Game.auditor.phase == 4 and Game.timers.auditor >= 1.0 then
            -- Check for high score before returning to attract mode
            if HighScores.isHighScore(Game.score) then
                -- Stop all projectile whistle sounds before name entry
                for _, p in ipairs(Game.projectiles) do
                    if p.whistleSound then
                        local success, isPlaying = pcall(function() return p.whistleSound:isPlaying() end)
                        if success and isPlaying then
                            pcall(function() p.whistleSound:stop() end)
                            pcall(function() p.whistleSound:release() end)
                        end
                        p.whistleSound = nil
                    end
                end
                
                -- Start name entry (arcade style)
                Game.modes.auditor = false  -- Clear auditor sequence
                Game.timers.auditor = 0
                Game.auditor.phase = 1
                Game.modes.nameEntry = true
                Game.nameEntry.text = "AAA"  -- Initialize with 'A' in all positions
                Game.nameEntry.cursor = 1
                Game.nameEntry.charIndex = {1, 1, 1}  -- Initialize all positions to 'A' (index 1)
            else
                -- No high score, return to attract mode
                returnToAttractMode()
            end
        end
        
        return  -- Don't update game logic during THE AUDITOR sequence
    end
    
    -- Handle game over screen
    if Game.modes.gameOver then
        -- Update banner animation FIRST (before checking if it's dropped)
        TopBanner.update(dt, Game.gameState, Engagement.value, Game.modes.gameOver, Game.modes.lifeLostAuditor)
        
        -- Don't stop sounds here - let projectile whistles continue until they explode
        
        -- Update glitch text timer and write-on progress
        Game.timers.glitchText = Game.timers.glitchText + dt
        if Game.visualEffects.glitchTextWriteProgress < 1.0 then
            Game.visualEffects.glitchTextWriteProgress = math.min(1.0, Game.visualEffects.glitchTextWriteProgress + dt * 1.5)
        end
        
        -- Wait at dropped position for 2 seconds (banner drop animation is handled by TopBanner.update())
        if TopBanner.isGameOverBannerDropped() then
            -- When banner hits down position, instantly move animated frame layers to top
            MonitorFrame.setEngagementPanelsToMaximum()
            
            Game.timers.gameOver = Game.timers.gameOver - dt
            
            -- Check if we should start reverse animation
            if not Game.reverseAnimationActive and Game.timers.gameOver <= 0 and Game.shouldRestartLevel and Game.lives > 0 then
                -- Start reverse animations
                Game.reverseAnimationActive = true
                Game.reverseEngagementActive = true
                Game.reverseEngagementTimer = 0
                Game.reverseEngagementStartValue = Engagement.value
                TopBanner.startReverseAnimation()
                MonitorFrame.startReverseAnimation()
            end
            
            -- Update reverse animations if active
            if Game.reverseAnimationActive then
                -- Animate engagement back to 100 over 1.5 seconds
                if Game.reverseEngagementActive then
                    Game.reverseEngagementTimer = Game.reverseEngagementTimer + dt
                    local progress = math.min(1.0, Game.reverseEngagementTimer / 1.5)
                    Engagement.value = Game.reverseEngagementStartValue + 
                        (Constants.ENGAGEMENT_MAX - Game.reverseEngagementStartValue) * progress
                    
                    if progress >= 1.0 then
                        Engagement.value = Constants.ENGAGEMENT_MAX
                        Game.reverseEngagementActive = false
                    end
                end
                
                -- Check if reverse animations are complete
                if TopBanner.isReverseAnimationComplete() and MonitorFrame.isReverseAnimationComplete() and not Game.reverseEngagementActive then
                    -- Reverse animations complete, restart the level
                    Game.reverseAnimationActive = false
                    restartLevel()
                    return
                end
            elseif Game.timers.gameOver <= 0 then
                -- Game over screen complete (no reverse needed - going to name entry or attract)
                if Game.shouldRestartLevel and Game.lives > 0 then
                    -- This shouldn't happen if reverse is working, but keep as fallback
                    restartLevel()
                elseif Game.lives <= 0 then
                    -- All lives lost - check for high score
                    if HighScores.isHighScore(Game.score) then
                        -- Stop all projectile whistle sounds before name entry
                        for _, p in ipairs(Game.projectiles) do
                            if p.whistleSound then
                                local success, isPlaying = pcall(function() return p.whistleSound:isPlaying() end)
                                if success and isPlaying then
                                    pcall(function() p.whistleSound:stop() end)
                                    pcall(function() p.whistleSound:release() end)
                                end
                                p.whistleSound = nil
                            end
                        end
                        
                        -- Start name entry (arcade style)
                        Game.modes.gameOver = false  -- Clear game over screen
                        Game.modes.nameEntry = true
                        Game.nameEntry.text = "AAA"  -- Initialize with 'A' in all positions
                        Game.nameEntry.cursor = 1
                        Game.nameEntry.charIndex = {1, 1, 1}  -- Initialize all positions to 'A' (index 1)
                    else
                        -- No high score, return to attract mode
                        returnToAttractMode()
                    end
                else
                    -- Safety fallback: if somehow we have lives but shouldn't restart, restart anyway
                    restartLevel()
                end
            end
        end
        
        -- Allow projectiles to continue updating so they can explode and stop sounds naturally
        Time.checkRestore(dt); Time.update(dt); local gameDt = dt * Time.scale
        for i = #Game.projectiles, 1, -1 do 
            local p = Game.projectiles[i]
            p:update(gameDt)
            if p.isDead then 
                table.remove(Game.projectiles, i) 
            end
        end
        
        return  -- Don't update other game logic during game over
    end
    
    -- Handle slow-motion ramp to freeze
    local gameDt = dt
    if Game.slowMo.active then
        Game.timers.slowMo = Game.timers.slowMo + dt
        local progress = math.min(Game.timers.slowMo / Game.slowMo.duration, 1.0)
        -- Ramp from 1.0 to 0.0 (smooth ease-out)
        Game.timeScale = 1.0 - (progress * progress)  -- Quadratic ease-out
        
        -- Apply time scale to game updates during slow-mo
        gameDt = dt * Game.timeScale
        
        -- Update sound system with normal dt (sounds should not be affected by slow-mo)
        Sound.update(dt)
        
        -- When fully frozen, handle differently in demo mode vs normal gameplay
        if Game.timeScale <= 0.0 then
            Game.timeScale = 0.0
            if Game.modes.demo and Game.demo.step == 8 then
                -- In demo mode step 8, just freeze - don't show win text
                -- The freeze will be released when step completes
            else
                -- Normal gameplay: show win text
                Game.slowMo.active = false
                -- Skip win text, go straight to Chase Paxton animation
                Game.modes.winText = false
                Game.timers.winText = 0
                -- Clean up any remaining game sounds when frozen (fanfare should be done by now)
                Sound.cleanup()
                Sound.unmute()  -- Re-enable for any UI sounds
                -- Restart dynamic music (part 2) after cleanup
                if DynamicMusic.isAutomatic() then
                    DynamicMusic.startPart(2)
                end
                -- Start matrix transition and webcam window animation immediately
                Game.levelTransition.matrixActive = true
                Game.webcamWindow.animating = true
                Game.webcamWindow.reversing = false
                Game.timers.webcamWindowAnim = 0
                Game.webcamWindow.dialogueActive = false
                Game.timers.webcamWindowDialogue = 0
                -- Ensure duration is set
                if not Game.webcamWindow.animDuration or Game.webcamWindow.animDuration <= 0 then
                    Game.webcamWindow.animDuration = 1.0
                end
                MatrixEffect.startTransition(2.0, function()
                    -- Transition complete - matrix done, animation continues to center
                    Game.levelTransition.matrixActive = false
                end)
                Sound.update(dt)
                return
            end
        end
    else
        -- Normal time handling
        Time.checkRestore(dt)
        Time.update(dt)
        gameDt = dt * Time.scale
    end
    
    -- Handle win text display (pause before webcam)
    if Game.modes.winText then
        Game.timers.winText = Game.timers.winText - dt
        -- Update sound system during win text display
        Sound.update(dt)
        if Game.timers.winText <= 0 then
            -- Win text done, start matrix transition to Chase Paxton screen
            Game.modes.winText = false
            Game.timers.winText = 0
            Game.levelTransition.matrixActive = true
            -- Start webcam window animation (forward to center)
            Game.webcamWindow.animating = true
            Game.webcamWindow.reversing = false
            Game.timers.webcamWindowAnim = 0
            Game.webcamWindow.dialogueActive = false
            Game.timers.webcamWindowDialogue = 0
            Game.webcamWindow.dialogueSentences = {}
            Game.webcamWindow.dialogueCurrentSentence = 1
            Game.timers.webcamWindowDialogueSentence = 0
            -- Ensure duration is set
            if not Game.webcamWindow.animDuration or Game.webcamWindow.animDuration <= 0 then
                Game.webcamWindow.animDuration = 1.0
            end
            MatrixEffect.startTransition(2.0, function()
                -- Transition complete - matrix done, animation continues to center
                Game.levelTransition.matrixActive = false
            end)
        end
        return  -- Don't update game logic during win text display
    end
    
    -- Handle webcam window animation
    if Game.webcamWindow.animating then
        if not Game.webcamWindow.reversing then
            -- Animating forward to center
            if not Game.webcamWindow.dialogueActive then
                -- Only update timer if dialogue hasn't started yet
                Game.timers.webcamWindowAnim = Game.timers.webcamWindowAnim + dt
                if Game.timers.webcamWindowAnim >= Game.webcamWindow.animDuration then
                    -- Reached center, start dialogue
                    Game.timers.webcamWindowAnim = Game.webcamWindow.animDuration
                    Game.webcamWindow.dialogueActive = true
                    Game.timers.webcamWindowDialogue = 0
                    -- Split message into sentences
                    local levelCompleteMsg = ChasePaxton.getLevelCompleteMessage(Game.winCondition)
                    Game.webcamWindow.dialogueSentences = {}
                    -- Split by sentence delimiters (. ! ?)
                    for sentence in levelCompleteMsg.message:gmatch("([^%.%!%?]+[%.%!%?]?)") do
                        sentence = sentence:match("^%s*(.-)%s*$")  -- Trim whitespace
                        if sentence ~= "" then
                            table.insert(Game.webcamWindow.dialogueSentences, sentence)
                        end
                    end
                    -- If no sentences found, use the whole message
                    if #Game.webcamWindow.dialogueSentences == 0 then
                        table.insert(Game.webcamWindow.dialogueSentences, levelCompleteMsg.message)
                    end
                    Game.webcamWindow.dialogueCurrentSentence = 1
                    Game.timers.webcamWindowDialogueSentence = 0
                    Webcam.showComment("level_complete")
                    ChasePortrait.setTalking(true)
                end
            end
        else
            -- Animating reverse back to original position
            Game.timers.webcamWindowAnim = Game.timers.webcamWindowAnim - dt
            if Game.timers.webcamWindowAnim <= 0 then
                -- Back to original position, animation complete
                Game.timers.webcamWindowAnim = 0
                Game.webcamWindow.animating = false
                Game.webcamWindow.reversing = false
                Game.webcamWindow.dialogueActive = false
                
                -- Clear all units and area effects from previous level during matrix wipe
                -- Note: We only clear units and explosion zones here, not projectiles/hazards
                -- (those are cleared in the transition callback)
                for i = #Game.units, 1, -1 do
                    local u = Game.units[i]
                    if u.body and not u.isDead then
                        u.body:destroy()
                    end
                    table.remove(Game.units, i)
                end
                
                -- Clear explosion zones (area effects) before level transition
                for i = #Game.explosionZones, 1, -1 do
                    local z = Game.explosionZones[i]
                    if z.body then
                        z.body:destroy()
                    end
                    table.remove(Game.explosionZones, i)
                end
                
                -- Clear visual effects before level transition
                Game.effects = {}
                
                -- Start matrix transition to hide the level change
                Game.levelTransition.matrixActive = true
                MatrixEffect.startTransition(2.0, function()
                    -- Transition complete - now do the actual level transition
                    Game.level = Game.level + 1
                    Game.levelTransition.active = false
                    Game.timers.levelTransition = 0
                    Game.gameState = "playing"
                    Game.winCondition = nil
                    Game.hasUnitBeenConverted = false
                    
                    -- Reset engagement to 100% for new level
                    Engagement.init()
                    
                    -- Clear projectiles, hazards, explosion zones, and effects for new level
                    -- Note: Units are already cleared before the transition
                    for i = #Game.projectiles, 1, -1 do
                        local p = Game.projectiles[i]
                        if p.whistleSound then
                            pcall(function()
                                p.whistleSound:stop()
                                p.whistleSound:release()
                            end)
                            p.whistleSound = nil
                        end
                        if p.body then
                            p.body:destroy()
                        end
                        table.remove(Game.projectiles, i)
                    end
                    Game.hazards = {}
                    
                    -- Clear explosion zones (area effects) for new level
                    for i = #Game.explosionZones, 1, -1 do
                        local z = Game.explosionZones[i]
                        if z.body then
                            z.body:destroy()
                        end
                        table.remove(Game.explosionZones, i)
                    end
                    
                    -- Clear visual effects for new level
                    Game.effects = {}
                    
                    -- Clear button held status and weapon upgrades
                    clearButtonHeldStatus()
                    clearWeaponUpgrades()
                    
                    -- Spawn new units for next level
                    spawnUnitsForLevel()
                    
                    -- Trigger ready sequence for new level
                    Game.modes.ready = true
                    Game.timers.ready = 0
                    Game.ready.phase = 1
                    Game.ready.sparks = {}
                    Game.gameState = "ready"
                    -- Reset banner to original position
                    TopBanner.reset()
                    
                    -- Stop intro/attract mode music
                    Sound.stopMusic()
                    
                    -- Switch dynamic music back to part 1 for new level
                    if not DynamicMusic.isAutomatic() then
                        DynamicMusic.startAutomatic()
                    else
                        DynamicMusic.switchToPart(1)
                    end
                    
                    -- End transition
                    Game.levelTransition.matrixActive = false
                end)
                
                -- Proceed to level transition (but matrix will handle the visual)
                Game.levelTransition.active = true
                Game.timers.levelTransition = 2.0  -- 2 second transition
                Game.timeScale = 1.0  -- Reset time scale
                
                -- Clear projectiles and hazards immediately
                for i = #Game.projectiles, 1, -1 do
                    local p = Game.projectiles[i]
                    if p.whistleSound then
                        pcall(function()
                            p.whistleSound:stop()
                            p.whistleSound:release()
                        end)
                        p.whistleSound = nil
                    end
                    if p.body then
                        p.body:destroy()
                    end
                    table.remove(Game.projectiles, i)
                end
                Game.hazards = {}
                
                -- Clear button held status immediately
                clearButtonHeldStatus()
                
                -- Clean up any remaining sounds before transition
                Sound.cleanup()
                Sound.unmute()  -- Re-enable sounds for next level
                -- Restart dynamic music (part 2) after cleanup - it should continue until next level
                if DynamicMusic.isAutomatic() then
                    DynamicMusic.startPart(2)
                end
            end
        end
    end
    
    -- Handle dialogue display (when window is centered)
    if Game.webcamWindow.dialogueActive then
        Game.timers.webcamWindowDialogue = Game.timers.webcamWindowDialogue + dt
        Game.timers.webcamWindowDialogueSentence = Game.timers.webcamWindowDialogueSentence + dt
        -- Update sound system during dialogue
        Sound.update(dt)
        -- Update portrait animation (always talking during dialogue)
        ChasePortrait.setTalking(true)
        ChasePortrait.update(dt)
        
        -- Advance to next sentence if current sentence time is up
        if Game.timers.webcamWindowDialogueSentence >= Game.webcamWindow.dialogueSentenceDuration then
            Game.webcamWindow.dialogueCurrentSentence = Game.webcamWindow.dialogueCurrentSentence + 1
            Game.timers.webcamWindowDialogueSentence = 0
            -- If we've shown all sentences, wait a bit before ending dialogue
            if Game.webcamWindow.dialogueCurrentSentence > #Game.webcamWindow.dialogueSentences then
                -- All sentences shown, wait a bit more then end
                if Game.timers.webcamWindowDialogue >= Game.webcamWindow.dialogueDuration then
                    -- Dialogue done, start reverse animation
                    Game.webcamWindow.dialogueActive = false
                    Game.timers.webcamWindowDialogue = 0
                    Game.timers.webcamWindowDialogueSentence = 0
                    Game.webcamWindow.dialogueSentences = {}
                    Game.webcamWindow.dialogueCurrentSentence = 1
                    -- Make sure animation is still active and timer is at max for reverse
                    if not Game.webcamWindow.animating then
                        Game.webcamWindow.animating = true
                    end
                    Game.webcamWindow.reversing = true
                    if Game.timers.webcamWindowAnim < Game.webcamWindow.animDuration then
                        Game.timers.webcamWindowAnim = Game.webcamWindow.animDuration
                    end
                    ChasePortrait.setTalking(false)
                end
            end
        end
    end
    
    -- Handle matrix transition (for level restarts and transitions)
    if Game.levelTransition.matrixActive then
        MatrixEffect.update(dt)
        -- Also update level transition timer if both are active
        if Game.levelTransition.active then
            Game.timers.levelTransition = Game.timers.levelTransition - dt
            if Game.timers.levelTransition <= 0 then
                Game.timers.levelTransition = 0  -- Keep it at 0 until matrix transition completes
            end
        end
        return  -- Don't update other game logic during matrix transition
    end
    
    -- Handle level transition (matrix transition handles the visual, this just tracks timing)
    if Game.levelTransition.active then
        Game.timers.levelTransition = Game.timers.levelTransition - dt
        -- Matrix transition callback will handle the actual level change
        if Game.timers.levelTransition <= 0 then
            Game.timers.levelTransition = 0  -- Keep it at 0 until matrix transition completes
        end
        return  -- Don't update other game logic during transition
    end
    
    -- Don't spawn powerups in demo mode
    if not Game.modes.demo then
        Game.powerupSpawnTimer = Game.powerupSpawnTimer - dt
        if Game.powerupSpawnTimer <= 0 then
            Game.powerupSpawnTimer = math.random(15, 25)
            local px = math.random(50, Constants.PLAYFIELD_WIDTH - 50)
            -- Clamp powerup X position to playfield bounds (accounting for radius)
            local clampedX = math.max(Constants.POWERUP_RADIUS, math.min(Constants.PLAYFIELD_WIDTH - Constants.POWERUP_RADIUS, px))
            -- Only spawn puck powerups (bumpers removed)
            table.insert(Game.powerups, PowerUp.new(clampedX, -50, "puck"))
        end
    end

    if not Game.isUpgraded and Game.score >= Constants.UPGRADE_SCORE then
    Game.isUpgraded = true
    -- Only upgrade the Puck Lifetime. The Bomb Radius is already maxed!
    Constants.PUCK_LIFETIME = Constants.PUCK_LIFETIME_MAX
    Game.shake = 2.0
    end
    -- Always update shake decay (even in demo mode) to prevent it from getting stuck
    if Game.shake > 0 then Game.shake = math.max(0, Game.shake - 2.5 * dt) end

    -- Skip main game updates during slow-mo or when game state is not playing
    -- This prevents new sounds from being created during win sequence
    -- Exception: In demo mode, allow updates during slow-mo (for step 7 toxic sludge demo)
    if (Game.slowMo.active or Game.gameState ~= "playing") and not Game.modes.demo then
        -- Sound is already updated above during slow-mo handling
        if not Game.slowMo.active then
            Sound.update(dt)
        end
        Webcam.update(dt)
        EngagementPlot.update(dt)
        -- Update dynamic music even during win sequence so it can switch to part 2
        DynamicMusic.update(dt)
        return  -- Don't update game entities during slow-mo or non-playing states
    end
    
    -- Use gameDt from slow-mo handling (already calculated above)
    -- Normal time handling
    Time.checkRestore(dt)
    Time.update(dt)
    gameDt = dt * Time.scale
    
    -- Calculate toxic hazard count for engagement decay
    local toxicHazardCount = #Game.hazards
    
    -- Don't update engagement decay in demo mode
    if not Game.modes.demo then
        Engagement.update(gameDt, toxicHazardCount, Game.level)
    end
    
    -- Update banner animation (using TopBanner module)
    -- Note: Banner is already updated above for gameOverActive and lifeLostAuditorActive cases
    -- Only update here if we're in normal gameplay
    if not Game.modes.gameOver and not Game.modes.lifeLostAuditor then
        TopBanner.update(dt, Game.gameState, Engagement.value, Game.modes.gameOver, Game.modes.lifeLostAuditor)
    end
    
    World.update(gameDt); Sound.update(dt); Webcam.update(dt); EngagementPlot.update(dt); Godray.update(dt); DynamicMusic.update(dt)
    
    -- Check if engagement ran out (game over)
    -- Only check if we're actually playing and not already in a game over state
    if Game.gameState == "playing" and Engagement.value <= 0 then
        if not Game.modes.gameOver and not Game.modes.lifeLostAuditor then
            handleGameOver("engagement_depleted")
            Webcam.showComment("game_over")
        end
    end
    
    -- Check engagement level for comments and point multiplier
    if Game.gameState == "playing" then
        -- Update monitor frame (for eyelid and BottomCenterPanel animations)
        MonitorFrame.update(dt)
        
        -- Update engagement-based panel animations (RightMidPanel, TopPanel, LeftMidPanel)
        -- Also handles reverse animation if active
        MonitorFrame.updateEngagementAnimations(Engagement.value, dt)
        
        -- Trigger BottomCenterPanel animation when engagement hits 65 or below
        if Engagement.value <= 65 then
            MonitorFrame.startBottomCenterPanelAnimation()
        end
        
        local engagementPct = Engagement.value / Constants.ENGAGEMENT_MAX
        
        -- Check if engagement reached 100% (activate point multiplier)
        -- Only trigger when crossing the threshold from below, not when already at 100%
        -- Skip multipliers in demo mode
        local isAtMax = Engagement.value >= Constants.ENGAGEMENT_MAX
        if isAtMax and not Game.previousEngagementAtMax and not Game.pointMultiplier.valueActive and not Game.modes.demo then
            -- Activate point multiplier
            Game.pointMultiplier.value = Game.pointMultiplier.value + 1  -- Incremental multiplier
            Game.pointMultiplier.valueActive = true
            Game.timers.pointMultiplier = 10.0  -- 10 seconds
            Game.timers.pointMultiplierFlash = 2.0  -- Flash animation duration (increased for spark effect)
            Game.timers.pointMultiplierText = 3.0  -- Text display duration (3 seconds before fade)
            Game.shake = math.max(Game.shake, 1.5)  -- Screen shake
            
            -- Create spark particles for the multiplier effect
            local centerX = Constants.SCREEN_WIDTH / 2
            local centerY = Constants.SCREEN_HEIGHT / 2 - 100
            Game.pointMultiplier.valueSparks = ParticleSystem.createSparks(
                centerX, centerY,
                Constants.UI.SPARK_COUNT_MULTIPLIER,
                Constants.UI.SPARK_SPEED_MIN,
                Constants.UI.SPARK_SPEED_MAX,
                Constants.UI.SPARK_SIZE_MIN,
                Constants.UI.SPARK_SIZE_MAX,
                Constants.UI.SPARK_LIFETIME
            )
            
            -- Play sound effect
            Sound.playTone(800, 0.3, 0.8, 1.5)  -- High pitch success sound
            Sound.playTone(600, 0.3, 0.8, 1.2)  -- Second tone for richness
            
            Webcam.showComment("engagement_high")
        end
        
        -- Update tracking flag for next frame
        Game.previousEngagementAtMax = isAtMax
        
        -- Update point multiplier timer (skip in demo mode)
        if Game.pointMultiplier.valueActive and not Game.modes.demo then
            Game.timers.pointMultiplier = Game.timers.pointMultiplier - dt
            if Game.timers.pointMultiplier <= 0 then
                -- Timer expired - deactivate multiplier
                Game.pointMultiplier.valueActive = false
                Game.timers.pointMultiplierFlash = 0
                Game.pointMultiplier.valueSparks = {}  -- Clear sparks
                Game.previousEngagementAtMax = false  -- Reset flag to allow re-triggering
            else
                -- Update flash timer
                if Game.timers.pointMultiplierFlash > 0 then
                    Game.timers.pointMultiplierFlash = Game.timers.pointMultiplierFlash - dt
                end
                
                -- Update text timer (fades out after 3 seconds)
                if Game.timers.pointMultiplierText > 0 then
                    Game.timers.pointMultiplierText = Game.timers.pointMultiplierText - dt
                end
                
            -- Update spark particles
            ParticleSystem.update(Game.pointMultiplier.valueSparks, dt, Constants.UI.SPARK_GRAVITY, Constants.UI.SPARK_FADE_RATE_MULTIPLIER)
            end
            -- Note: Multiplier stays active for full duration regardless of engagement level
        end
        
        -- Update rapid fire text timer and sparks
        if Game.timers.rapidFireText > 0 then
            Game.timers.rapidFireText = Game.timers.rapidFireText - dt
            
            -- Update rapid fire spark particles
            ParticleSystem.update(Game.rapidFire.sparks, dt, Constants.UI.SPARK_GRAVITY, Constants.UI.SPARK_FADE_RATE_MULTIPLIER)
        end
        
        if engagementPct < 0.25 and math.random() < 0.01 then  -- 1% chance per frame when low
            Webcam.showComment("engagement_low")
        elseif engagementPct > 0.75 and math.random() < 0.005 then  -- 0.5% chance per frame when high
            Webcam.showComment("engagement_high")
        end
    end
    
    for i = #Game.hazards, 1, -1 do 
        local h = Game.hazards[i]
        h.timer = h.timer - dt
        -- Update splat animation if it exists
        if h.splat and h.splat.isAnimating then
            ToxicSplat.update(h.splat, dt)
        end
        if h.timer <= 0 then table.remove(Game.hazards, i) end 
    end
    for i = #Game.explosionZones, 1, -1 do local z = Game.explosionZones[i]; z.timer = z.timer - dt; if z.timer <= 0 then z.body:destroy(); table.remove(Game.explosionZones, i) end end
    for i = #Game.powerups, 1, -1 do local p = Game.powerups[i]; p:update(gameDt); if p.isDead then table.remove(Game.powerups, i) end end
    
    -- Update doomscroll feed
    Doomscroll.update(dt, Game)

    Game.logicTimer = Game.logicTimer + dt
    if Game.logicTimer > 0.1 then
        Game.logicTimer = 0
        
        -- Check units for explosion zones
        for _, u in ipairs(Game.units) do
            if not u.isDead then
                local ux, uy = u.body:getPosition(); local activeZone = nil
                for _, z in ipairs(Game.explosionZones) do
                    local dx = ux - z.x; local dy = uy - z.y
                    if (dx*dx + dy*dy) < (z.radius * z.radius) then activeZone = z; break end
                end
                if activeZone then 
                    local wasNeutral = u.state == "neutral"
                    u:hit("bomb", activeZone.color)
                    -- Track if a unit was converted from neutral
                    if wasNeutral and u.state == "passive" then
                        Game.hasUnitBeenConverted = true
                    end
                end
            end
        end
    end

    if Game.turret then 
        -- In demo mode, AI controls the turret
        if Game.modes.demo then
            DemoMode.updateAI(dt)
        end
        Game.turret:update(dt, Game.projectiles, Game.isUpgraded) 
    end
    
    -- Update units (freeze movement in demo mode to prevent random wandering, except step 4 for enrage demo)
    for i = #Game.units, 1, -1 do 
        local u = Game.units[i]
        if Game.modes.demo then
            -- Step 4: Allow full unit updates to show enraged unit attacking
            if Game.demo.step == 4 then
                u:update(gameDt, Game.units, Game.hazards, Game.explosionZones, Game.turret)
            -- In demo mode, freeze unit movement but allow state changes
            elseif not u.isDead then
                -- Freeze unit velocity to prevent wandering
                u.body:setLinearVelocity(0, 0)
                
                -- Update speech bubbles
                if u.speechBubble then
                    u.speechBubble.timer = u.speechBubble.timer + gameDt
                    if u.speechBubble.timer >= u.speechBubble.duration then
                        u.speechBubble = nil
                    end
                end
                if u.groupSpeechBubble then
                    u.groupSpeechBubble.timer = u.groupSpeechBubble.timer + gameDt
                    if u.groupSpeechBubble.timer >= u.groupSpeechBubble.duration then
                        u.groupSpeechBubble = nil
                    end
                end
                
                -- Only update isolation timer for insane units demo steps
                if (Game.demo.step == 6 or Game.demo.step == 8) and u.state == "neutral" then
                    u:checkIsolation(gameDt, Game.units)
                end
                
                -- Check if unit went insane
                if u.isInsane and not u.isDead then
                    u:goInsane()
                end
                
                -- Update enrage timer if enraged
                if u.state == "enraged" then
                    u.enrageTimer = u.enrageTimer - gameDt
                    if u.enrageTimer <= 0 then
                        u.state = "passive"
                    end
                end
            end
        else
            -- Normal gameplay: full unit update
            u:update(gameDt, Game.units, Game.hazards, Game.explosionZones, Game.turret)
        end
        if u.isDead then table.remove(Game.units, i) end 
    end
    for i = #Game.projectiles, 1, -1 do local p = Game.projectiles[i]; p:update(gameDt); if p.isDead then table.remove(Game.projectiles, i) end end
    
    -- Check win conditions (skip in demo mode)
    if Game.gameState == "playing" and not Game.modes.demo then
        local blueCount = 0
        local redCount = 0
        local neutralCount = 0
        
        for _, u in ipairs(Game.units) do
            if not u.isDead then
                if u.alignment == "blue" then
                    blueCount = blueCount + 1
                elseif u.alignment == "red" then
                    redCount = redCount + 1
                elseif u.state == "neutral" then
                    neutralCount = neutralCount + 1
                end
            end
        end
        
        local totalUnits = blueCount + redCount + neutralCount
        
        -- Win condition 1: Only blue units left
        if totalUnits > 0 and blueCount > 0 and redCount == 0 and neutralCount == 0 then
            if not Game.levelTransition.active then
                advanceToNextLevel("blue_only")
            end
        -- Win condition 2: Only red units left
        elseif totalUnits > 0 and redCount > 0 and blueCount == 0 and neutralCount == 0 then
            if not Game.levelTransition.active then
                advanceToNextLevel("red_only")
            end
        -- Win condition 3: No units left
        elseif totalUnits == 0 then
            if not Game.levelTransition.active and not Game.modes.gameOver then
                handleGameOver("no_units")
            end
        -- Win condition 4: Only neutral units left (grey win condition)
        -- IMPORTANT: This win condition is ONLY active if at least one unit has been converted on this stage
        -- This prevents winning immediately if all units start as neutral and none are converted
        elseif totalUnits > 0 and neutralCount == totalUnits and Game.hasUnitBeenConverted then
            if not Game.levelTransition.active then
                advanceToNextLevel("neutral_only")
            end
        end
    end
    
    for i = #Game.effects, 1, -1 do
        local e = Game.effects[i]; e.timer = e.timer - dt
        if e.type == "explosion" then
            e.radius = e.radius + (e.maxRadius * 8 * dt); if e.radius > e.maxRadius then e.radius = e.maxRadius end; e.alpha = e.timer / 0.5
            -- Update speech bubble timer if present
            if e.speechBubble then
                e.speechBubble.timer = (e.speechBubble.timer or 0) + dt
            end
        elseif e.type == "orange_splat" then
            -- Update orange splat animation
            if e.splat and e.splat.isAnimating then
                ToxicSplat.update(e.splat, dt, 5.0)  -- Faster animation for explosion
            end
            -- Fade out alpha over time
            e.alpha = e.timer / 0.8  -- Fade from 1.0 to 0.0 over 0.8 seconds
            -- Update speech bubble timer if present
            if e.speechBubble then
                e.speechBubble.timer = (e.speechBubble.timer or 0) + dt
            end
            -- When orange splat finishes, create green toxic zone
            if e.timer <= 0 then
                local r, g, b = unpack(Constants.COLORS.TOXIC)
                local hazard = {
                    x = e.toxicX, 
                    y = e.toxicY,
                    radius = Constants.INSANE_TOXIC_RADIUS,
                    timer = Constants.INSANE_TOXIC_DURATION,
                    splat = ToxicSplat.createSplat(e.toxicX, e.toxicY, Constants.INSANE_TOXIC_RADIUS, {r * 0.5, g * 0.5, b * 0.5})
                }
                table.insert(Game.hazards, hazard)
                table.remove(Game.effects, i)
            end
        end
        if e.type ~= "orange_splat" and e.timer <= 0 then table.remove(Game.effects, i) end
    end
end

function love.keypressed(key)
    InputHandler.handleKeyPressed(key)
end

-- Text input disabled for arcade-style name entry (uses arrow keys instead)

function love.keyreleased(key)
    InputHandler.handleKeyReleased(key)
end

function love.joystickreleased(joystick, button)
    InputHandler.handleJoystickReleased(joystick, button)
end

-- Handle joystick axis input (for DPad/analog stick in name entry)
function love.joystickaxis(joystick, axis, value)
    InputHandler.handleJoystickAxis(joystick, axis, value)
end

-- Handle joystick hat input (for DPad in name entry)
function love.joystickhat(joystick, hat, direction)
    InputHandler.handleJoystickHat(joystick, hat, direction)
end

-- Handle joystick button presses
function love.joystickpressed(joystick, button)
    InputHandler.handleJoystickPressed(joystick, button)
end

-- Drawing function that will be wrapped by Moonshine if CRT is enabled
function drawGame()
    love.graphics.clear(Constants.COLORS.BACKGROUND)
    
    -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
    DrawingHelpers.drawTealWallpaper()
    
    -- Apply shake transform to everything (background, game, foreground, HUD)
    love.graphics.push()
        if Game.shake > 0 then
            local s = Game.shake * Game.shake * 15; love.graphics.translate(love.math.random(-s, s), love.math.random(-s, s))
        end
        
    -- Draw background image if loaded and enabled (full screen) - now affected by shake
    if Game.showBackgroundForeground and Game.assets.background then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Game.assets.background, 0, 0, 0, 
            Constants.SCREEN_WIDTH / Game.assets.background:getWidth(),
            Constants.SCREEN_HEIGHT / Game.assets.background:getHeight())
    end
    
    -- Draw grid on playfield (affected by shake)
    DrawingHelpers.drawPlayfieldGrid()
    
    World.draw(function()
        for _, h in ipairs(Game.hazards) do
            if h.splat then
                -- Use animated splat
                local a = (h.timer / (h.radius == Constants.INSANE_TOXIC_RADIUS and Constants.INSANE_TOXIC_DURATION or Constants.TOXIC_DURATION)) * 0.4
                ToxicSplat.draw(h.splat, a)
            else
                -- Fallback to simple circle if splat not initialized
                local r,g,b = unpack(Constants.COLORS.TOXIC); local a = (h.timer/Constants.TOXIC_DURATION)*0.4
                love.graphics.setColor(r,g,b,a); love.graphics.circle("fill", h.x, h.y, h.radius)
                love.graphics.setColor(r,g,b,a+0.2); love.graphics.setLineWidth(2); love.graphics.circle("line", h.x, h.y, h.radius)
            end
        end
        
        if #Game.explosionZones > 0 then
            love.graphics.clear(false, true, false) 
            for _, z in ipairs(Game.explosionZones) do
                love.graphics.setStencilTest("equal", 0)
                if z.color == "red" then love.graphics.setColor(1, 0, 0, 0.3) else love.graphics.setColor(0, 0, 1, 0.3) end
                love.graphics.circle("fill", z.x, z.y, z.radius, 64)
                love.graphics.setLineWidth(3); love.graphics.setColor(1, 1, 1, 0.5); love.graphics.circle("line", z.x, z.y, z.radius, 64)
                love.graphics.setStencilTest(); love.graphics.stencil(function() love.graphics.circle("fill", z.x, z.y, z.radius, 64) end, "replace", 1)
            end
            love.graphics.setStencilTest()
        end
        
        for _, u in ipairs(Game.units) do u:draw() end
        for _, p in ipairs(Game.projectiles) do p:draw() end
        for _, pup in ipairs(Game.powerups) do pup:draw() end
        
        for _, e in ipairs(Game.effects) do
            if e.type == "explosion" then
                love.graphics.setLineWidth(3)
                if e.color == "gold" then love.graphics.setColor(1, 0.8, 0.2, e.alpha)
                elseif e.color == "red" then love.graphics.setColor(1, 0.2, 0.2, e.alpha)
                else love.graphics.setColor(0.2, 0.2, 1, e.alpha) end
                love.graphics.circle("line", e.x, e.y, e.radius, 64); love.graphics.setColor(1, 1, 1, e.alpha * 0.2); love.graphics.circle("fill", e.x, e.y, e.radius, 64)
                
                -- Draw speech bubble if present (for insane units)
                if e.speechBubble and e.speechBubble.text then
                    local bubbleX = e.x
                    local bubbleY = e.y - Constants.UNIT_RADIUS - 40
                    local padding = 10
                    local font = Game.fonts.speechBubble
                    
                    local textWidth = font:getWidth(e.speechBubble.text)
                    local textHeight = font:getHeight()
                    local bubbleWidth = textWidth + padding * 2
                    local bubbleHeight = textHeight + padding * 2
                    
                    -- Fade out with explosion (timer is updated in update loop)
                    local bubbleAlpha = math.max(e.alpha, 0.5)  -- Keep it visible even during explosion
                    if e.speechBubble and e.speechBubble.timer and e.speechBubble.duration then
                        if e.speechBubble.timer > e.speechBubble.duration * 0.7 then
                            bubbleAlpha = bubbleAlpha * (1.0 - ((e.speechBubble.timer - e.speechBubble.duration * 0.7) / (e.speechBubble.duration * 0.3)))
                        end
                    end
                    
                    -- Draw speech bubble background (more opaque)
                    love.graphics.setColor(0, 0, 0, bubbleAlpha * 0.9)
                    love.graphics.rectangle("fill", bubbleX - bubbleWidth / 2, bubbleY - bubbleHeight, bubbleWidth, bubbleHeight, 4)
                    
                    -- Draw speech bubble border (brighter)
                    love.graphics.setColor(0.8, 0.8, 0.8, bubbleAlpha)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", bubbleX - bubbleWidth / 2, bubbleY - bubbleHeight, bubbleWidth, bubbleHeight, 4)
                    
                    -- Draw speech bubble tail
                    love.graphics.setColor(0, 0, 0, bubbleAlpha * 0.9)
                    love.graphics.polygon("fill", 
                        bubbleX - 10, bubbleY - 6,
                        bubbleX + 10, bubbleY - 6,
                        bubbleX, bubbleY + 6
                    )
                    love.graphics.setColor(0.8, 0.8, 0.8, bubbleAlpha)
                    love.graphics.setLineWidth(2)
                    love.graphics.polygon("line", 
                        bubbleX - 10, bubbleY - 6,
                        bubbleX + 10, bubbleY - 6,
                        bubbleX, bubbleY + 6
                    )
                    
                    -- Draw text (brighter)
                    love.graphics.setColor(1, 0.5, 0.5, bubbleAlpha)
                    love.graphics.setFont(font)
                    love.graphics.print(e.speechBubble.text, bubbleX - textWidth / 2, bubbleY - bubbleHeight + padding)
                end
            elseif e.type == "orange_splat" then
                -- Draw orange explosion splat with fiery orange colors
                if e.splat then
                    love.graphics.push()
                    love.graphics.translate(e.splat.x, e.splat.y)
                    love.graphics.scale(e.splat.currentScale)
                    
                    -- PASS 1: Base Orange Layer
                    love.graphics.setBlendMode("alpha")
                    love.graphics.setColor(0.8, 0.3, 0.1, e.alpha)
                    
                    for _, shape in ipairs(e.splat.shapes) do
                        love.graphics.circle("fill", shape.x, shape.y, shape.r)
                    end
                    
                    -- PASS 2: Additive Highlights (Fiery Glow)
                    love.graphics.setBlendMode("add")
                    love.graphics.setColor(0.6, 0.4, 0.1, 0.6 * e.alpha)  -- Fiery orange glow
                    
                    -- Only highlight blobs/lumps, streaks are too thin to notice
                    for _, shape in ipairs(e.splat.shapes) do
                        if shape.type == "core" or shape.type == "lump" or (shape.type == "blob" and shape.r > 1.2) then
                            local offX = -0.4 * shape.r * 0.3
                            local offY = -0.4 * shape.r * 0.3
                            -- Scale highlight down slightly
                            love.graphics.circle("fill", shape.x + offX, shape.y + offY, shape.r * 0.7)
                        end
                    end
                    
                    love.graphics.setBlendMode("alpha")
                    love.graphics.pop()
                end
                
                -- Draw speech bubble if present (for insane units)
                if e.speechBubble and e.speechBubble.text then
                    local bubbleX = e.x
                    local bubbleY = e.y - Constants.UNIT_RADIUS - 40
                    local padding = 10
                    local font = Game.fonts.speechBubble
                    
                    local textWidth = font:getWidth(e.speechBubble.text)
                    local textHeight = font:getHeight()
                    local bubbleWidth = textWidth + padding * 2
                    local bubbleHeight = textHeight + padding * 2
                    
                    -- Fade out with explosion (timer is updated in update loop)
                    local bubbleAlpha = math.max(e.alpha, 0.5)  -- Keep it visible even during explosion
                    if e.speechBubble and e.speechBubble.timer and e.speechBubble.duration then
                        if e.speechBubble.timer > e.speechBubble.duration * 0.7 then
                            bubbleAlpha = bubbleAlpha * (1.0 - ((e.speechBubble.timer - e.speechBubble.duration * 0.7) / (e.speechBubble.duration * 0.3)))
                        end
                    end
                    
                    -- Draw speech bubble background (more opaque)
                    love.graphics.setColor(0, 0, 0, bubbleAlpha * 0.9)
                    love.graphics.rectangle("fill", bubbleX - bubbleWidth / 2, bubbleY - bubbleHeight, bubbleWidth, bubbleHeight, 4)
                    
                    -- Draw speech bubble border (brighter)
                    love.graphics.setColor(0.8, 0.8, 0.8, bubbleAlpha)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", bubbleX - bubbleWidth / 2, bubbleY - bubbleHeight, bubbleWidth, bubbleHeight, 4)
                    
                    -- Draw speech bubble tail
                    love.graphics.setColor(0, 0, 0, bubbleAlpha * 0.9)
                    love.graphics.polygon("fill", 
                        bubbleX - 10, bubbleY - 6,
                        bubbleX + 10, bubbleY - 6,
                        bubbleX, bubbleY + 6
                    )
                    love.graphics.setColor(0.8, 0.8, 0.8, bubbleAlpha)
                    love.graphics.setLineWidth(2)
                    love.graphics.polygon("line", 
                        bubbleX - 10, bubbleY - 6,
                        bubbleX + 10, bubbleY - 6,
                        bubbleX, bubbleY + 6
                    )
                    
                    -- Draw text (brighter)
                    love.graphics.setColor(1, 0.5, 0.5, bubbleAlpha)
                    love.graphics.setFont(font)
                    love.graphics.print(e.speechBubble.text, bubbleX - textWidth / 2, bubbleY - bubbleHeight + padding)
                end
            elseif e.type == "forcefield" then
                love.graphics.setLineWidth(4)
                love.graphics.setColor(0.2, 0.6, 1, e.alpha * 0.6)
                love.graphics.circle("line", e.x, e.y, e.radius, 32)
                love.graphics.setColor(0.3, 0.7, 1, e.alpha * 0.3)
                love.graphics.circle("fill", e.x, e.y, e.radius, 32)
            end
        end
        
        if Game.turret then Game.turret:draw() end
    end)

    -- Draw Windows 95 style frame around the playfield (A.R.A.C. Control Interface)
    -- Position the frame so the playfield content begins at Constants.OFFSET_X/Y (no gameplay coordinate changes)
    do
        local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
        local borderWidth = Constants.UI.BORDER_WIDTH
        local frameX = Constants.OFFSET_X - borderWidth
        local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
        local frameW = Constants.PLAYFIELD_WIDTH + (borderWidth * 2)
        local frameH = Constants.PLAYFIELD_HEIGHT + titleBarHeight + (borderWidth * 2)

        WindowFrame.draw(frameX, frameY, frameW, frameH, "A.R.A.C. Control Interface")
    end
    
    -- Draw black overlay during game over (behind banner, in front of game)
    local greyFade = TopBanner.getGameOverGreyFade()
    if TopBanner.isGameOverDropActive() and greyFade > 0 then
        DrawingHelpers.drawBlackOverlay(greyFade)
    end
    
    -- Draw terminal text for game over
    if Game.modes.gameOver then
        TopBanner.drawGameOverText(Game.timers.glitchText, Game.visualEffects.glitchTextWriteProgress, Game.fonts.terminal)
    end
    
    -- Draw foreground image if loaded and enabled (full screen, on top of game elements) - now affected by shake
    if Game.showBackgroundForeground and Game.assets.foreground then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(Game.assets.foreground, 0, 0, 0, 
            Constants.SCREEN_WIDTH / Game.assets.foreground:getWidth(),
            Constants.SCREEN_HEIGHT / Game.assets.foreground:getHeight())
    end
    
    -- Draw HUD - now affected by shake and CRT
    drawHUD()
    
    -- Draw webcam window (below playfield, affected by shake)
    Webcam.draw()
    
    -- Draw engagement plot (next to webcam, affected by shake)
    EngagementPlot.draw()
    
    -- Draw score window (below playfield, centered)
    drawScoreWindow()
    
    -- Draw doomscroll window (below score window)
    Doomscroll.draw(Game.fonts)
    
    -- Draw multiplier window (below engagement plot) - skip in demo mode
    if not Game.modes.demo then
        drawMultiplierWindow()
    end
    
    love.graphics.pop()
    
    -- CRITICAL: Reset color to white before Moonshine processes the canvas
    -- Otherwise, any color set by effects (like gold explosion) will tint the entire screen
    love.graphics.setColor(1, 1, 1, 1)
end

-- Calculate bounding box of all active windows for vignette
local function calculateWindowBounds()
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    
    -- Playfield frame (A.R.A.C. Control Interface)
    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local borderWidth = Constants.UI.BORDER_WIDTH
    local frameX = Constants.OFFSET_X - borderWidth
    local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
    local frameW = Constants.PLAYFIELD_WIDTH + (borderWidth * 2)
    local frameH = Constants.PLAYFIELD_HEIGHT + titleBarHeight + (borderWidth * 2)
    
    minX = math.min(minX, frameX)
    minY = math.min(minY, frameY)
    maxX = math.max(maxX, frameX + frameW)
    maxY = math.max(maxY, frameY + frameH)
    
    -- Webcam window
    local WEBCAM_WIDTH = 300
    local WEBCAM_HEIGHT = 200
    local WEBCAM_X = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH - WEBCAM_WIDTH - 20
    local WEBCAM_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + 20
    
    minX = math.min(minX, WEBCAM_X)
    minY = math.min(minY, WEBCAM_Y)
    maxX = math.max(maxX, WEBCAM_X + WEBCAM_WIDTH)
    maxY = math.max(maxY, WEBCAM_Y + WEBCAM_HEIGHT)
    
    -- Engagement plot
    local PLOT_WIDTH = Constants.UI.PLOT_WINDOW_WIDTH
    local PLOT_HEIGHT = Constants.UI.PLOT_WINDOW_HEIGHT
    local PLOT_X = Constants.OFFSET_X + Constants.UI.WINDOW_OFFSET_X
    local PLOT_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + Constants.UI.WINDOW_SPACING
    
    minX = math.min(minX, PLOT_X)
    minY = math.min(minY, PLOT_Y)
    maxX = math.max(maxX, PLOT_X + PLOT_WIDTH)
    maxY = math.max(maxY, PLOT_Y + PLOT_HEIGHT)
    
    -- Score window
    local SCORE_WIDTH = Constants.UI.SCORE_WINDOW_WIDTH
    local SCORE_HEIGHT = Constants.UI.SCORE_WINDOW_HEIGHT
    local SCORE_X = (Constants.SCREEN_WIDTH - SCORE_WIDTH) / 2
    local SCORE_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + Constants.UI.WINDOW_SPACING
    
    minX = math.min(minX, SCORE_X)
    minY = math.min(minY, SCORE_Y)
    maxX = math.max(maxX, SCORE_X + SCORE_WIDTH)
    maxY = math.max(maxY, SCORE_Y + SCORE_HEIGHT)
    
    -- Multiplier window (if active)
    if not Game.modes.demo then
        local MULTIPLIER_WIDTH = PLOT_WIDTH
        local MULTIPLIER_HEIGHT = Constants.UI.MULTIPLIER_WINDOW_HEIGHT
        local MULTIPLIER_X = PLOT_X
        local MULTIPLIER_Y = PLOT_Y + PLOT_HEIGHT + Constants.UI.WINDOW_SPACING
        
        minX = math.min(minX, MULTIPLIER_X)
        minY = math.min(minY, MULTIPLIER_Y)
        maxX = math.max(maxX, MULTIPLIER_X + MULTIPLIER_WIDTH)
        maxY = math.max(maxY, MULTIPLIER_Y + MULTIPLIER_HEIGHT)
    end
    
    -- Convert to normalized coordinates (0-1) and return as x, y, width, height
    local boundsX = minX / Constants.SCREEN_WIDTH
    local boundsY = minY / Constants.SCREEN_HEIGHT
    local boundsW = (maxX - minX) / Constants.SCREEN_WIDTH
    local boundsH = (maxY - minY) / Constants.SCREEN_HEIGHT
    
    return {boundsX, boundsY, boundsW, boundsH}
end

function love.draw()
    -- Calculate scaling for fullscreen mode
    local scaleX, scaleY = 1, 1
    local offsetX, offsetY = 0, 0
    local isFullscreen = love.window.getFullscreen()
    
    if isFullscreen then
        -- Get actual window dimensions (will be the fullscreen resolution)
        local windowWidth, windowHeight = love.graphics.getDimensions()
        
        -- Calculate scale to stretch and fill the entire screen
        scaleX = windowWidth / Constants.SCREEN_WIDTH
        scaleY = windowHeight / Constants.SCREEN_HEIGHT
        
        -- No offset needed when stretching to fill
        offsetX = 0
        offsetY = 0
    end
    
    -- Update CRT vignette window bounds based on active windows
    if Game.crtEffect then
        local windowBounds = calculateWindowBounds()
        Game.crtEffect.windowBounds = windowBounds
    end
    
    -- Helper function to draw plexiglass overlay (directly over CRT layer)
    -- sceneCanvas: canvas containing the scene before plexi (for bright pixel detection)
    local function drawPlexiOverlay(sceneCanvas)
        if Game.plexi then
            -- Calculate plexi scale (15% larger)
            local plexiScaleX, plexiScaleY = DrawingHelpers.calculatePlexiScale()
            
                -- Draw first plexi layer (additive)
                love.graphics.setBlendMode("add")
                love.graphics.setColor(1, 1, 1, Constants.UI.PLEXI_OPACITY)
            
            if isFullscreen then
                -- Draw at fullscreen resolution to match CRT output
                local windowWidth, windowHeight = love.graphics.getDimensions()
                love.graphics.push()
                love.graphics.scale(scaleX, scaleY)
                love.graphics.draw(Game.plexi, 0, 0, 0, plexiScaleX, plexiScaleY)
                love.graphics.pop()
            else
                -- Draw at base resolution
                love.graphics.draw(Game.plexi, 0, 0, 0, plexiScaleX, plexiScaleY)
            end
            
            -- Now create mask from bright pixels in the captured scene
            if Game.plexiShader and sceneCanvas then
                -- Apply shader to create mask (with growth)
                -- Draw mask at same resolution and position as scene was captured
                love.graphics.setCanvas(Game.plexiMaskCanvas)
                love.graphics.clear(0, 0, 0, 0)
                love.graphics.setShader(Game.plexiShader)
                Game.plexiShader:send("source", sceneCanvas)
                Game.plexiShader:send("brightnessThreshold", 0.4)  -- Lower threshold for more bright pixels
                Game.plexiShader:send("textureSize", {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT})
                love.graphics.setBlendMode("alpha")
                love.graphics.setColor(1, 1, 1, 1)
                -- Draw scene canvas at (0, 0) to match capture position
                love.graphics.draw(sceneCanvas, 0, 0, 0, 1, 1)
                love.graphics.setShader()
                
                -- Blur the mask by 8 pixels (horizontal then vertical pass)
                if Game.plexiMaskBlurShader then
                    -- Horizontal blur pass
                    love.graphics.setCanvas(Game.plexiMaskBlurTempCanvas)
                    love.graphics.clear(0, 0, 0, 0)
                    love.graphics.setShader(Game.plexiMaskBlurShader)
                    Game.plexiMaskBlurShader:send("direction", {1.0, 0.0})  -- Horizontal
                    Game.plexiMaskBlurShader:send("radius", 8.0)  -- 8 pixel blur
                    Game.plexiMaskBlurShader:send("textureSize", {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT})
                    love.graphics.setBlendMode("alpha")
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(Game.plexiMaskCanvas, 0, 0)
                    
                    -- Vertical blur pass
                    love.graphics.setCanvas(Game.plexiMaskCanvas)
                    love.graphics.clear(0, 0, 0, 0)
                    Game.plexiMaskBlurShader:send("direction", {0.0, 1.0})  -- Vertical
                    love.graphics.draw(Game.plexiMaskBlurTempCanvas, 0, 0)
                    love.graphics.setShader()
                end
                
                love.graphics.setCanvas()
                
                -- Draw second plexi layer using mask at higher opacity
                love.graphics.setCanvas()  -- Draw to screen
                love.graphics.setBlendMode("add")  -- Additive blend for the second layer
                
                if Game.plexiApplyMaskShader then
                    -- Use shader to apply blurred background and mask to plexi texture
                    love.graphics.setShader(Game.plexiApplyMaskShader)
                    Game.plexiApplyMaskShader:send("mask", Game.plexiMaskCanvas)
                    Game.plexiApplyMaskShader:send("opacity", 1.0)  -- Full opacity
                    -- Send screen size for coordinate conversion
                    if isFullscreen then
                        local windowWidth, windowHeight = love.graphics.getDimensions()
                        Game.plexiApplyMaskShader:send("screenSize", {windowWidth, windowHeight})
                    else
                        Game.plexiApplyMaskShader:send("screenSize", {Constants.SCREEN_WIDTH, Constants.SCREEN_HEIGHT})
                    end
                    love.graphics.setColor(1, 1, 1, 1)
                    
                    -- Use exact same position, scale, and transformations as first layer
                    if isFullscreen then
                        local windowWidth, windowHeight = love.graphics.getDimensions()
                        love.graphics.push()
                        love.graphics.scale(scaleX, scaleY)
                        -- Draw at exact same position as first layer (0, 0)
                        love.graphics.draw(Game.plexi, 0, 0, 0, plexiScaleX, plexiScaleY)
                        love.graphics.pop()
                    else
                        -- Draw at exact same position as first layer (0, 0)
                        love.graphics.draw(Game.plexi, 0, 0, 0, plexiScaleX, plexiScaleY)
                    end
                    
                    love.graphics.setShader()
                else
                    -- Fallback: simple multiply approach
                    love.graphics.setColor(1, 1, 1, 0.7)
                    if isFullscreen then
                        local windowWidth, windowHeight = love.graphics.getDimensions()
                        love.graphics.push()
                        love.graphics.scale(scaleX, scaleY)
                        love.graphics.draw(Game.plexi, 0, 0, 0, plexiScaleX, plexiScaleY)
                        love.graphics.pop()
                    else
                        love.graphics.draw(Game.plexi, 0, 0, 0, plexiScaleX, plexiScaleY)
                    end
                end
            end
            
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
    
    -- Helper function to apply CRT shader to any drawing function
    local function drawWithCRT(drawFunc)
        local sceneCanvas = nil
        
        -- First, render scene to canvas (before CRT) - with stencil support
        -- Capture at base resolution without transformations to match screen
        if Game.plexiSceneCanvas then
            love.graphics.setCanvas({Game.plexiSceneCanvas, depthstencil = Game.plexiSceneStencilCanvas})
            love.graphics.clear(0, 0, 0, 0)
            love.graphics.setShader()
            love.graphics.setBlendMode("alpha")
            love.graphics.setColor(1, 1, 1, 1)
            
            -- Draw at base resolution without any transformations
            drawFunc()
            
            love.graphics.setCanvas()
            sceneCanvas = Game.plexiSceneCanvas
        end
        
        -- Now apply CRT and draw to screen
        if Game.crtEnabled and Game.crtChain then
            -- In fullscreen, the CRT chain was already resized when entering fullscreen
            if isFullscreen then
                -- Get fullscreen dimensions
                local windowWidth, windowHeight = love.graphics.getDimensions()
                
                -- Draw scene directly at fullscreen resolution (scaled) so glow processes full area
                -- The CRT chain is already resized to fullscreen, so it will process at fullscreen resolution
                love.graphics.setColor(1, 1, 1, 1)
                Game.crtChain.draw(function()
                    love.graphics.setColor(1, 1, 1, 1)
                    -- Draw the scene with scaling transformation so it fills fullscreen
                    -- This ensures glow processes the full screen area from the start
                    local scaleX = windowWidth / Constants.SCREEN_WIDTH
                    local scaleY = windowHeight / Constants.SCREEN_HEIGHT
                    love.graphics.push()
                    love.graphics.scale(scaleX, scaleY)
                    drawFunc()
                    love.graphics.pop()
                end)
            else
                -- Windowed mode: just apply CRT normally
                Game.crtChain.draw(drawFunc)
            end
        else
            -- No CRT: apply scaling transformation, then draw
            love.graphics.push()
            love.graphics.translate(offsetX, offsetY)
            love.graphics.scale(scaleX, scaleY)
            drawFunc()
            love.graphics.pop()
        end
        
        -- Always draw plexiglass overlay after CRT processing
        drawPlexiOverlay(sceneCanvas)
    end
    
    -- Draw joystick test screen (from attract mode)
    if Game.modes.joystickTest then
        drawWithCRT(drawJoystickTestScreen)
        MonitorFrame.draw()
        return
    end

    -- Draw booting screen (before logo)
    if Game.modes.booting then
        drawWithCRT(BootingScreen.draw)
        MonitorFrame.draw()
        return
    end
    
    -- Draw matrix screen (before logo)
    if Game.modes.matrix then
        love.graphics.clear(0, 0, 0)  -- Black background
        MatrixEffect.draw()
        DynamicMusic.draw()  -- Draw on top of matrix screen
        MonitorFrame.draw()
        return
    end
    
    -- Draw logo screen (before attract mode)
    if Game.modes.logo then
        drawWithCRT(LogoScreen.draw)
        DynamicMusic.draw()  -- Draw on top of logo screen
        MonitorFrame.draw()
        return
    end
    
    -- Draw attract mode screen
    if Game.modes.attract then
        drawWithCRT(AttractMode.draw)
        DynamicMusic.draw()  -- Draw on top of attract mode
        MonitorFrame.draw()
        return
    end
    
    -- Draw demo mode screen
    if Game.modes.demo then
        drawWithCRT(DemoMode.draw)
        MonitorFrame.draw()
        Godray.draw()
        return
    end
    
    -- Draw intro video (before intro screen)
    if Game.modes.video then
        drawWithCRT(IntroVideoScreen.draw)
        
        -- Draw video after CRT effect but before monitor frame
        if Game.assets.introVideo then
            -- Get video dimensions
            local videoWidth = Game.assets.introVideo:getWidth()
            local videoHeight = Game.assets.introVideo:getHeight()
            
            -- Calculate scaling to fit screen while maintaining aspect ratio
            local scaleX = Constants.SCREEN_WIDTH / videoWidth
            local scaleY = Constants.SCREEN_HEIGHT / videoHeight
            local scale = math.min(scaleX, scaleY)
            
            -- Calculate centered position
            local drawWidth = videoWidth * scale
            local drawHeight = videoHeight * scale
            local x = (Constants.SCREEN_WIDTH - drawWidth) / 2
            local y = (Constants.SCREEN_HEIGHT - drawHeight) / 2
            
            -- Draw video centered (after CRT, before monitor frame)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(Game.assets.introVideo, x, y, 0, scale, scale)
        else
            -- If video doesn't exist, show a message (shouldn't happen, but fallback)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(Game.fonts.large)
            local msg = "Video not found"
            local msgWidth = Game.fonts.large:getWidth(msg)
            love.graphics.print(msg, (Constants.SCREEN_WIDTH - msgWidth) / 2, Constants.SCREEN_HEIGHT / 2)
        end
        
        MonitorFrame.draw()
        Godray.draw()
        return
    end
    
    -- Draw intro screen (check before AUDITOR to prevent showing CRITICAL_ERROR on new game)
    if Game.modes.intro then
        drawWithCRT(drawIntroScreen)
        MonitorFrame.draw()
        Godray.draw()
        return
    end
    
    -- Draw level completion screen (Chase Paxton)
    if Game.modes.winText then
        -- Draw win text + scanlines + matrix together, then apply CRT to the combined result
        if Game.levelTransition.matrixActive then
            drawWithCRT(function()
                drawWinTextScreen()
                -- Draw animated scanlines on top of win text
                MatrixEffect.drawScanlines()
                -- Draw matrix on top of scanlines (before CRT processes it)
                MatrixEffect.draw()
            end)
        else
            drawWithCRT(drawWinTextScreen)
        end
        MonitorFrame.draw()
        Godray.draw()
        return
    end
    
    -- Draw animating webcam window (level complete sequence)
    if Game.webcamWindow.animating or Game.webcamWindow.dialogueActive then
        -- Draw everything just like normal gameplay, but with animating webcam window
        drawWithCRT(function()
            -- Draw teal wallpaper (like Windows desktop) - covers entire screen except playfield
            DrawingHelpers.drawTealWallpaper()
            
            -- Draw background image if loaded and enabled
            if Game.showBackgroundForeground and Game.assets.background then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(Game.assets.background, 0, 0, 0, 
                    Constants.SCREEN_WIDTH / Game.assets.background:getWidth(),
                    Constants.SCREEN_HEIGHT / Game.assets.background:getHeight())
            end
            
            -- Draw frozen game state (same as drawGame but frozen)
            World.draw(function()
                -- Draw units (frozen)
                for _, u in ipairs(Game.units) do
                    if not u.isDead then
                        u:draw()
                    end
                end
                
                -- Draw projectiles (frozen)
                for _, p in ipairs(Game.projectiles) do
                    if not p.isDead then
                        p:draw()
                    end
                end
                
                -- Draw effects (frozen)
                for _, e in ipairs(Game.effects) do
                    if e.type == "explosion" and e.duration and e.duration > 0 then
                        local t = e.timer / e.duration
                        local alpha = 1.0 - t
                        local radius = e.radius * (1.0 - t * 0.5)
                        love.graphics.setColor(1, 1, 0, alpha * 0.5)
                        love.graphics.circle("fill", e.x, e.y, radius, 32)
                    elseif e.type == "explosion" then
                        love.graphics.setColor(1, 1, 0, 0.5)
                        love.graphics.circle("fill", e.x, e.y, e.radius or 50, 32)
                    end
                end
                
                -- Draw turret (frozen)
                if Game.turret then
                    Game.turret:draw()
                end
            end)
            
            -- Draw Windows 95 style frame around the playfield (A.R.A.C. Control Interface)
            do
                local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
                local borderWidth = Constants.UI.BORDER_WIDTH
                local frameX = Constants.OFFSET_X - borderWidth
                local frameY = Constants.OFFSET_Y - borderWidth - titleBarHeight
                local frameW = Constants.PLAYFIELD_WIDTH + (borderWidth * 2)
                local frameH = Constants.PLAYFIELD_HEIGHT + titleBarHeight + (borderWidth * 2)
                WindowFrame.draw(frameX, frameY, frameW, frameH, "A.R.A.C. Control Interface")
            end
            
            -- Draw foreground image if loaded and enabled
            if Game.showBackgroundForeground and Game.assets.foreground then
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(Game.assets.foreground, 0, 0, 0, 
                    Constants.SCREEN_WIDTH / Game.assets.foreground:getWidth(),
                    Constants.SCREEN_HEIGHT / Game.assets.foreground:getHeight())
            end
            
            -- Draw HUD
            drawHUD()
            
            -- Draw webcam window in original position (background, not animating)
            Webcam.draw()
            
            -- Draw engagement plot (next to webcam)
            EngagementPlot.draw()
            
            -- Draw score window (below playfield, centered)
            drawScoreWindow()
            
            -- Draw doomscroll window (below score window)
            Doomscroll.draw(Game.fonts)
            
            -- Draw multiplier window (below engagement plot) - skip in demo mode
            if not Game.modes.demo then
                drawMultiplierWindow()
            end
            
            -- Draw animating webcam window on top (the one that moves to center)
            drawAnimatingWebcamWindow()
        end)
        MonitorFrame.draw()
        Godray.draw()
        return
    end
    
    -- Draw life lost auditor screen (engagement depleted but lives remain)
    if Game.modes.lifeLostAuditor then
        drawWithCRT(drawLifeLostAuditor)
        -- Respect shouldDrawOnTop() check - only draw on top when banner has moved out of frame
        if TopBanner.shouldDrawOnTop() then
            MonitorFrame.draw()
            TopBanner.draw()
            -- Draw animated panels on top of banner when it's at down position
            MonitorFrame.drawAnimatedPanelsOnTop()
        else
            TopBanner.draw()
            MonitorFrame.draw()
        end
        TopBanner.drawLifeLostText(Game.timers.glitchText, Game.visualEffects.glitchTextWriteProgress, Game.fonts.terminal)
        Godray.draw()
        TextTrace.draw()
        return
    end
    
    -- Draw game over screen (same as life lost but with different text)
    if Game.modes.gameOver then
        drawWithCRT(drawGameOver)
        -- Respect shouldDrawOnTop() check - only draw on top when banner has moved out of frame
        if TopBanner.shouldDrawOnTop() then
            MonitorFrame.draw()
            TopBanner.draw()
            -- Draw animated panels on top of banner when it's at down position
            MonitorFrame.drawAnimatedPanelsOnTop()
        else
            TopBanner.draw()
            MonitorFrame.draw()
        end
        TopBanner.drawGameOverText(Game.timers.glitchText, Game.visualEffects.glitchTextWriteProgress, Game.fonts.terminal)
        Godray.draw()
        TextTrace.draw()
        return
    end
    
    -- Draw matrix transition overlay (for level transitions and restarts)
    if Game.levelTransition.matrixActive then
        -- Draw game + scanlines + matrix together, then apply CRT to the combined result
        drawWithCRT(function()
            drawGame()
            -- Draw animated scanlines on top of game content
            MatrixEffect.drawScanlines()
            -- Draw matrix on top of scanlines (before CRT processes it)
            MatrixEffect.draw()
        end)
        MonitorFrame.draw()
        return
    end
    
    -- Draw ready screen (GET READY / GO!)
    if Game.modes.ready then
        drawWithCRT(drawReadyScreen)
        TopBanner.draw()
        MonitorFrame.draw()
        Godray.draw()
        return
    end
    
    -- Auditor sequence removed - game over now uses same screen as life lost (top bar only)
    
    -- Apply CRT effect if enabled, otherwise draw normally
    drawWithCRT(drawGame)
    
    -- Draw top banner and monitor frame after CRT effect (so they appear on top)
    -- Top banner always drawn (at all times)
    -- If banner should draw on top (during game over/life lost), draw it after MonitorFrame
    if TopBanner.shouldDrawOnTop() then
        MonitorFrame.draw()
        TopBanner.draw()
    else
        TopBanner.draw()
        -- Monitor frame always on top of everything
        MonitorFrame.draw()
    end
    
    -- Draw godray effect on top of everything
    Godray.draw()
    
    -- Draw name entry screen (draw after godrays so rays appear on top)
    if Game.modes.nameEntry then
        -- Draw name entry rays and text (on top of everything except text itself)
        drawNameEntryRaysAndText()
    end
    
    -- Draw debug mode indicator
    if Game.debugMode then
        love.graphics.setColor(1, 0, 0, 0.8)  -- Red with transparency
        if Game.fonts.medium then
            love.graphics.setFont(Game.fonts.medium)
        end
        love.graphics.print("DEBUG MODE", 10, 10)
        love.graphics.print("F2: Instant Win | F3: Instant Lose | F4: Game Over", 10, 40)
        love.graphics.setColor(1, 1, 1, 1)  -- Reset color
    end
    
    -- Draw FPS counter at mid-bottom of screen
    local fps = love.timer.getFPS()
    local fpsText = "FPS: " .. fps
    if Game.fonts.medium then
        love.graphics.setFont(Game.fonts.medium)
    end
    local fpsWidth = Game.fonts.medium:getWidth(fpsText)
    local fpsX = (Constants.SCREEN_WIDTH - fpsWidth) / 2  -- Centered horizontally
    local fpsY = Constants.SCREEN_HEIGHT - 30  -- 30 pixels from bottom
    love.graphics.setColor(1, 1, 1, 0.8)  -- White with slight transparency
    love.graphics.print(fpsText, fpsX, fpsY)
    love.graphics.setColor(1, 1, 1, 1)  -- Reset color
end

function drawScoreWindow()
    -- Score window dimensions and position (below playfield, centered)
    local SCORE_WIDTH = Constants.UI.SCORE_WINDOW_WIDTH
    local SCORE_HEIGHT = Constants.UI.SCORE_WINDOW_HEIGHT
    local SCORE_X = (Constants.SCREEN_WIDTH - SCORE_WIDTH) / 2  -- Centered
    local SCORE_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + Constants.UI.WINDOW_SPACING
    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local borderWidth = Constants.UI.BORDER_WIDTH
    
    -- Draw transparent black background for content area
    DrawingHelpers.drawWindowContentBackground(SCORE_X, SCORE_Y, SCORE_WIDTH, SCORE_HEIGHT, titleBarHeight, borderWidth)
    
    -- Draw Windows 95 style frame with title bar
    WindowFrame.draw(SCORE_X, SCORE_Y, SCORE_WIDTH, SCORE_HEIGHT, "Score")
    
    -- Draw score content - adjust for title bar
    love.graphics.setFont(Game.fonts.large)
    love.graphics.setColor(1, 1, 1, 1)
    local scoreText = "SCORE: " .. Game.score
    local scoreWidth = Game.fonts.large:getWidth(scoreText)
    love.graphics.print(scoreText, SCORE_X + (SCORE_WIDTH - scoreWidth) / 2, SCORE_Y + titleBarHeight + borderWidth + 15)
end


function drawMultiplierWindow()
    -- Multiplier window dimensions and position (below engagement plot)
    local PLOT_WIDTH = Constants.UI.PLOT_WINDOW_WIDTH
    local PLOT_HEIGHT = Constants.UI.PLOT_WINDOW_HEIGHT
    local PLOT_X = Constants.OFFSET_X + Constants.UI.WINDOW_OFFSET_X
    local PLOT_Y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT + Constants.UI.WINDOW_SPACING
    
    local MULTIPLIER_WIDTH = PLOT_WIDTH
    local MULTIPLIER_HEIGHT = Constants.UI.MULTIPLIER_WINDOW_HEIGHT
    local MULTIPLIER_X = PLOT_X
    local MULTIPLIER_Y = PLOT_Y + PLOT_HEIGHT + Constants.UI.WINDOW_SPACING
    local titleBarHeight = Constants.UI.TITLE_BAR_HEIGHT
    local borderWidth = Constants.UI.BORDER_WIDTH
    
    -- Draw transparent black background for content area
    DrawingHelpers.drawWindowContentBackground(MULTIPLIER_X, MULTIPLIER_Y, MULTIPLIER_WIDTH, MULTIPLIER_HEIGHT, titleBarHeight, borderWidth)
    
    -- Draw Windows 95 style frame with title bar
    WindowFrame.draw(MULTIPLIER_X, MULTIPLIER_Y, MULTIPLIER_WIDTH, MULTIPLIER_HEIGHT, "Multiplier")
    
    if Game.pointMultiplier.valueActive then
        -- Draw multiplier content - adjust for title bar
        love.graphics.setFont(Game.fonts.medium)
        
        -- Multiplier value with gold/yellow pulsing
        local flash = (math.sin(love.timer.getTime() * 3) + 1) / 2
        love.graphics.setColor(1, 0.8 + flash * 0.2, 0.2, 1)
        local multiplierText = "x" .. Game.pointMultiplier.value .. " POINT MULTIPLIER"
        local multiplierWidth = Game.fonts.medium:getWidth(multiplierText)
        love.graphics.print(multiplierText, MULTIPLIER_X + (MULTIPLIER_WIDTH - multiplierWidth) / 2, MULTIPLIER_Y + titleBarHeight + borderWidth + 10)
        
        -- Timer
        love.graphics.setColor(1, 1, 1, 0.9)
        local timerText = math.ceil(Game.timers.pointMultiplier) .. "s remaining"
        local timerWidth = Game.fonts.medium:getWidth(timerText)
        love.graphics.print(timerText, MULTIPLIER_X + (MULTIPLIER_WIDTH - timerWidth) / 2, MULTIPLIER_Y + titleBarHeight + borderWidth + 35)
    else
        -- Show inactive state - adjust for title bar
        love.graphics.setColor(0.5, 0.5, 0.5, 0.7)
        love.graphics.setFont(Game.fonts.medium)
        local inactiveText = "MULTIPLIER: INACTIVE"
        local inactiveWidth = Game.fonts.medium:getWidth(inactiveText)
        love.graphics.print(inactiveText, MULTIPLIER_X + (MULTIPLIER_WIDTH - inactiveWidth) / 2, MULTIPLIER_Y + titleBarHeight + borderWidth + 20)
    end
end

function drawHUD()
    love.graphics.setColor(0, 1, 0); love.graphics.setFont(Game.fonts.medium); love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    
    -- Show CRT status
    if Game.crtEnabled then
        love.graphics.setColor(0.8, 0.8, 0.2)
        love.graphics.print("CRT: ON (Press C to toggle)", 10, 30)
    else
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("CRT: OFF (Press C to toggle)", 10, 30)
    end

    -- Removed engagement meter and score - now in separate window below playfield
    love.graphics.setColor(0.8, 0.8, 0.8); love.graphics.setFont(Game.fonts.medium); love.graphics.print("LEVEL: " .. Game.level, 10, 50)
    love.graphics.setColor(1, 0.2, 0.2); love.graphics.print("LIVES: " .. Game.lives, 200, 50)
    
    if Game.isUpgraded then love.graphics.setColor(1, 1, 0); love.graphics.print("WEAPONS UPGRADED!", 10, 70) end
    
    -- Draw point multiplier announcement (giant flashing "2X" with sparks) - skip in demo mode
    if Game.pointMultiplier.valueActive and not Game.modes.demo then
        local centerX, centerY = DrawingHelpers.getScreenCenter()
        centerY = centerY - 100
        
        -- Draw spark particles
        ParticleSystem.draw(Game.pointMultiplier.valueSparks)
        
        -- Calculate flash alpha
        local flashAlpha = 1.0
        if Game.timers.pointMultiplierFlash > 0 then
            -- Flash animation during first 2 seconds
            flashAlpha = 0.6 + 0.4 * (math.sin(Game.timers.pointMultiplierFlash * 12) + 1) / 2
        end
        
        -- Use cached giant font for "2X" text
        love.graphics.setFont(Game.fonts.announcementGiant)
        
        local multiplierText = Game.pointMultiplier.value .. "X"
        local multiplierWidth = Game.fonts.announcementGiant:getWidth(multiplierText)
        local multiplierX = centerX - multiplierWidth / 2
        local multiplierY = centerY - Constants.UI.FONT_ANNOUNCEMENT_GIANT / 2
        
        -- Flashy colors (gold/yellow pulsing)
        local flash = (math.sin(love.timer.getTime() * 8) + 1) / 2
        local r = 1
        local g = 0.7 + flash * 0.3
        local b = 0.1
        
        -- Draw text with thick outline for visibility
        love.graphics.setLineWidth(8)
        love.graphics.setColor(0, 0, 0, flashAlpha * 0.9)
        for dx = -4, 4, 2 do
            for dy = -4, 4, 2 do
                if dx ~= 0 or dy ~= 0 then
                    love.graphics.print(multiplierText, multiplierX + dx, multiplierY + dy)
                end
            end
        end
        
        -- Draw main text with pulsing color
        love.graphics.setColor(r, g, b, flashAlpha)
        love.graphics.print(multiplierText, multiplierX, multiplierY)
        
        -- Add extra glow effect
        love.graphics.setColor(r, g, b, flashAlpha * 0.3)
        for i = 1, 3 do
            love.graphics.print(multiplierText, multiplierX, multiplierY)
        end
    end
    
    -- Draw rapid fire announcement (giant flashing "RAPID FIRE" with sparks)
    if Game.timers.rapidFireText > 0 then
        local centerX = Constants.SCREEN_WIDTH / 2
        -- Position rapid fire text above multiplier text if multiplier is active
        local centerY
        if Game.pointMultiplier.valueActive then
            -- Place above multiplier text (multiplier is at SCREEN_HEIGHT/2 - 100, with 120px font)
            -- Rapid fire should be about 150px above the multiplier text center
            centerY = Constants.SCREEN_HEIGHT / 2 - 250
        else
            -- Same position as multiplier when multiplier is not active
            centerY = Constants.SCREEN_HEIGHT / 2 - 100
        end
        
        -- Draw spark particles (adjust their visual position if multiplier is active)
        local sparkOffsetY = 0
        if Game.pointMultiplier.valueActive then
            -- Adjust spark positions to match the rapid fire text position above multiplier
            sparkOffsetY = -150  -- Move sparks up by 150px to match text position
        end
        ParticleSystem.draw(Game.rapidFire.sparks, sparkOffsetY)
        
        -- Calculate flash alpha and fade out after 3 seconds
        local flashAlpha = 1.0
        local flashTimer = 3.0 - Game.timers.rapidFireText
        if flashTimer < 2.0 then
            -- Flash animation during first 2 seconds
            flashAlpha = 0.6 + 0.4 * (math.sin(flashTimer * 12) + 1) / 2
        end
        -- Fade out after 3 seconds
        if Game.timers.rapidFireText < 1.0 then
            -- Fade out over last second
            flashAlpha = flashAlpha * (Game.timers.rapidFireText / 1.0)
        end
        
        -- Use cached giant font for "RAPID FIRE" text
        love.graphics.setFont(Game.fonts.announcementGiant)
        
        local rapidFireText = "RAPID FIRE"
        local textWidth = Game.fonts.announcementGiant:getWidth(rapidFireText)
        local textX = centerX - textWidth / 2
        local textY = centerY - Constants.UI.FONT_ANNOUNCEMENT_GIANT / 2
        
        -- Flashy colors (gold/yellow pulsing)
        local flash = (math.sin(love.timer.getTime() * 8) + 1) / 2
        local r = 1
        local g = 0.7 + flash * 0.3
        local b = 0.1
        
        -- Draw text with thick outline for visibility
        love.graphics.setLineWidth(8)
        love.graphics.setColor(0, 0, 0, flashAlpha * 0.9)
        for dx = -4, 4, 2 do
            for dy = -4, 4, 2 do
                if dx ~= 0 or dy ~= 0 then
                    love.graphics.print(rapidFireText, textX + dx, textY + dy)
                end
            end
        end
        
        -- Draw main text with pulsing color
        love.graphics.setColor(r, g, b, flashAlpha)
        love.graphics.print(rapidFireText, textX, textY)
        
        -- Add extra glow effect
        love.graphics.setColor(r, g, b, flashAlpha * 0.3)
        for i = 1, 3 do
            love.graphics.print(rapidFireText, textX, textY)
        end
    end
    
    
    -- Display level transition message
    if Game.levelTransition.active then
        love.graphics.setFont(Game.fonts.large)
        love.graphics.setColor(0, 1, 0)
        local message = Popups.getWinMessage(Game.winCondition)
        local textWidth = Game.fonts.large:getWidth(message)
        love.graphics.print(message, (Constants.SCREEN_WIDTH - textWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 100)
        
        love.graphics.setFont(Game.fonts.medium)
        love.graphics.setColor(1, 1, 0)
        local nextLevelMsg = Popups.getAdvancingMessage(Game.level + 1)
        local nextLevelWidth = Game.fonts.medium:getWidth(nextLevelMsg)
        love.graphics.print(nextLevelMsg, (Constants.SCREEN_WIDTH - nextLevelWidth) / 2, Constants.SCREEN_HEIGHT / 2 - 50)
    -- Removed old game over screen messages - banner drop replaces them
    elseif Game.modes.nameEntry then
        -- Name entry screen - only terminal text is drawn (rays and text drawn separately after godrays)
        -- All UI elements (box, title, score, instructions) removed - only green terminal text remains
    end
end