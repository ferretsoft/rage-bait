function love.conf(t)
    -- Identity
    t.identity = "RageBait"        -- The name of the save directory
    t.version = "11.4"               -- The LÖVE version this game is made for

    -- Window / Display
    t.window.title = "RageBait"    -- The window title
    t.window.width = 1080            -- Window width
    t.window.height = 1920           -- Window height
    t.window.borderless = false      -- Remove the title bar? (Keep false for dev)
    t.window.resizable = true        -- Let the user resize the window?
    t.window.minwidth = 1
    t.window.minheight = 1
    t.window.fullscreen = false      -- Enable fullscreen? (False for dev)
    t.window.fullscreentype = "desktop" -- "desktop" means borderless fullscreen
    t.window.vsync = 1               -- Vertical sync (1 = on, 0 = off)
    t.window.msaa = 0                -- Antialiasing (0, 2, 4, 8...)
    t.window.display = 1             -- Index of the monitor to show the window on

    -- Modules (Disable unused ones for performance)
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true        -- Keep true for Arcade Stick support later
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = true         -- CRITICAL: We need this
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.touch = true           -- Useful if deploying to mobile later
    t.modules.video = true
    t.modules.window = true

    -- Console (Crucial for debugging 'print' statements on Windows)
    t.console = true                 
end