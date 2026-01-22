# Code Organization & Structure Improvement Suggestions

## Critical Issues (High Priority)

### 1. **Split main.lua into Logical Modules**
**Current**: 3937 lines in a single file
**Problem**: Hard to navigate, maintain, and understand
**Solution**: Split into focused modules:

```
src/
  core/
    game_state.lua          # Game state management (playing, ready, game over, etc.)
    input_handler.lua        # All input handling (keyboard, joystick)
    drawing.lua              # All drawing functions
    initialization.lua       # love.load() and initialization code
    high_scores.lua         # High score management
  screens/
    booting_screen.lua
    logo_screen.lua
    intro_screen.lua
    game_over_screen.lua
    life_lost_screen.lua
    ready_screen.lua
    name_entry_screen.lua
```

### 2. **Consolidate Game State Variables**
**Current**: 137+ fields in Game table, many boolean flags
**Problem**: Hard to track state, potential conflicts
**Solution**: Use state machine pattern or group related state:

```lua
Game.state = {
    current = "attract",  -- Single current state
    previous = nil,
    -- State-specific data
    attract = { timer = 0, ... },
    playing = { ... },
    gameOver = { ... },
    ready = { phase = 1, timer = 0, ... }
}
```

### 3. **Remove Dead/Old Code**
**Issues Found**:
- **Old banner variables in Game table** (lines 39-58): Should be removed, TopBanner module handles this
- **Old banner image loading** (lines 407-436): Duplicate of TopBanner.load() - should be removed
- **Old banner animation code** (lines 2395-2494): Should be removed, TopBanner.update() handles this
- **Duplicate `Webcam.showComment()` calls**:
  - Line 649-650: `Webcam.showComment("game_start")` called twice
  - Line 183-184: `Webcam.showComment("powerup_collected")` called twice
- **`drawAuditor()` function** (line 1597): Still exists and is called (line 3613), but might be old code path - verify if needed

### 4. **Extract Input Handling to Module**
**Current**: Input handling scattered across:
- `love.keypressed()` (line 2758)
- `love.keyreleased()` (line 3010)
- `love.joystickpressed()` (line 3126)
- `love.joystickaxis()` (line 3038)
- `love.joystickhat()` (line 3085)
- `love.joystickreleased()` (line 3017)

**Solution**: Create `src/core/input_handler.lua`:
```lua
local InputHandler = {}

function InputHandler.handleKeyPressed(key)
    -- All keyboard input logic
end

function InputHandler.handleJoystickPressed(joystick, button)
    -- All joystick input logic
end

-- etc.

return InputHandler
```

Then in main.lua:
```lua
local InputHandler = require("src.core.input_handler")

function love.keypressed(key)
    InputHandler.handleKeyPressed(key)
end
```

## Medium Priority (Code Quality)

### 5. **Group Related Functions**
**Current**: Functions are scattered throughout file
**Solution**: Organize by responsibility:

```lua
-- === INITIALIZATION ===
function love.load() ... end
function startGame() ... end
function startGameplay() ... end

-- === GAME LOGIC ===
function spawnUnitsForLevel() ... end
function advanceToNextLevel() ... end
function handleGameOver() ... end
function restartLevel() ... end

-- === DRAWING ===
function drawGame() ... end
function drawBootingScreen() ... end
-- etc.

-- === INPUT ===
function love.keypressed() ... end
-- etc.
```

### 6. **Extract Screen Drawing to Separate Module**
**Current**: All screen drawing functions in main.lua
**Solution**: Create `src/screens/` directory:
- Each screen gets its own file
- Consistent interface: `ScreenName.draw()`, `ScreenName.update(dt)`
- Reduces main.lua size significantly

### 7. **Create Game State Manager**
**Current**: State managed with many boolean flags
**Solution**: Centralized state manager:

```lua
local GameState = {
    current = "attract",
    transitions = {
        attract = { to = {"logo", "playing"} },
        playing = { to = {"game_over", "level_complete", "ready"} },
        -- etc.
    }
}

function GameState.set(newState)
    -- Validate transition
    -- Cleanup old state
    -- Initialize new state
end
```

### 8. **Consolidate Duplicate Drawing Code**
**Current**: `drawFrozenGameState()` exists but similar code repeated in:
- `drawLifeLostAuditor()` (line 1442)
- `drawGameOver()` (line 1521)
- `drawAuditor()` (line 1597)
- `drawWinTextScreen()` (line 1714)
- `drawLevelCompleteScreen()` (line 1783)

**Solution**: Make `drawFrozenGameState()` more complete and use it everywhere

### 9. **Extract Constants from Magic Numbers**
**Current**: Many magic numbers throughout code
**Examples**:
- Line 156: `Constants.SCREEN_HEIGHT / 2 - 100` (should be a named constant)
- Line 3274: `fontSize = 18` (should be in Constants)
- Line 1352-1357: Webcam dimensions (should be constants)

**Solution**: Add to `src/constants.lua`:
```lua
Constants.UI = {
    WEBCAM_WIDTH = 400,
    WEBCAM_HEIGHT = 300,
    SPEECH_BUBBLE_FONT_SIZE = 18,
    -- etc.
}
```

### 10. **Remove Unused/Old Variables**
**Check for**:
- `Game.topBanner*` variables (should use TopBanner module)
- `Game.gameOverBannerDrop`, `Game.gameOverBannerDropped` (should use TopBanner API)
- Old banner animation state variables

## Low Priority (Polish)

### 11. **Add Section Headers**
**Current**: Some sections have headers, but inconsistent
**Solution**: Consistent header format:
```lua
-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- ============================================================================
-- GAME STATE MANAGEMENT
-- ============================================================================

-- ============================================================================
-- DRAWING FUNCTIONS
-- ============================================================================
```

### 12. **Document Function Parameters**
**Current**: Functions lack parameter documentation
**Solution**: Add JSDoc-style comments:
```lua
--[[
    Spawns units for the current level
    @param level number - The level number (determines unit count)
    @return nil
]]
function spawnUnitsForLevel()
```

### 13. **Group Game Table Fields by Category**
**Current**: Fields are somewhat grouped but could be better
**Solution**: Use nested tables:
```lua
Game = {
    entities = {
        units = {},
        projectiles = {},
        powerups = {},
        effects = {},
        hazards = {},
        explosionZones = {}
    },
    ui = {
        fonts = {},
        shake = 0,
        -- etc.
    },
    state = {
        current = "attract",
        level = 1,
        score = 0,
        -- etc.
    }
}
```

### 14. **Extract Particle System**
**Current**: Spark particles handled inline in multiple places
**Solution**: Create `src/core/particle_system.lua`:
```lua
local ParticleSystem = {}

function ParticleSystem.createSparks(centerX, centerY, count, color)
    -- Reusable spark creation
end

function ParticleSystem.update(dt, particles)
    -- Reusable update logic
end

function ParticleSystem.draw(particles, colorScheme)
    -- Reusable drawing
end
```

### 15. **Create Screen Manager**
**Current**: Screen drawing order managed in `love.draw()`
**Solution**: Screen manager with priority system:
```lua
local ScreenManager = {
    screens = {},
    add = function(name, drawFunc, priority) ... end,
    draw = function() ... end  -- Draws in priority order
}
```

## File Structure Recommendations

### Proposed Structure:
```
main.lua                    # Minimal - just requires and calls
src/
  core/
    game.lua                # Main game loop (love.update, love.draw)
    game_state.lua          # State management
    input_handler.lua       # All input
    initialization.lua      # love.load
    high_scores.lua         # High score system
    particle_system.lua    # Particle effects
  screens/
    booting_screen.lua
    logo_screen.lua
    attract_screen.lua      # (uses AttractMode module)
    intro_screen.lua
    ready_screen.lua
    game_screen.lua         # Main gameplay drawing
    game_over_screen.lua
    life_lost_screen.lua
    name_entry_screen.lua
    level_complete_screen.lua
  entities/                 # (already exists)
  core/                     # (existing modules)
```

## Specific Code Issues Found

### 1. **Duplicate Webcam.showComment() calls**
- Line 649-650: `Webcam.showComment("game_start")` called twice
- Line 183-184: `Webcam.showComment("powerup_collected")` called twice
- **Fix**: Remove duplicate calls

### 2. **Old banner code still present**
- Lines 39-58: Old banner variables in Game table (should use TopBanner module)
- Lines 407-436: Old banner image loading (duplicate of TopBanner.load())
- Lines 2395-2494: Old banner animation logic (should be in TopBanner.update())
- **Fix**: Remove old code, verify TopBanner module handles everything

### 3. **drawAuditor() function appears to be dead code**
- Line 1597: Function defined
- Line 3613: Function called, but only if `Game.auditorActive` is true
- Line 804: `auditorActive` is set to true when all lives lost
- **BUT**: Based on earlier refactoring, game over should use banner drop (like life lost)
- Line 2046: Update logic exists but may not be reached if game over uses banner drop
- **Fix**: Verify if this code path is still used. If game over always uses banner drop now, remove auditor sequence entirely

### 2. **Old banner code still present**
- Lines 39-58: Old banner image variables (should use TopBanner module)
- Lines 2395-2494: Old banner animation logic (should be in TopBanner)
- **Fix**: Remove or verify if still needed

### 3. **drawAuditor() function exists but unused**
- Line 1597: Function defined but never called
- **Fix**: Remove or integrate if needed

### 4. **Inconsistent require() usage**
- Some modules cached at top (good)
- Some required inline (lines 1337, 1629, 1661)
- **Fix**: Cache all requires at top of file

### 5. **Font creation in draw loop**
- Line 3274: `love.graphics.newFont(fontSize)` in draw loop
- **Fix**: Cache font or add to Game.fonts

### 6. **Magic numbers for UI dimensions**
- Lines 1352-1357: Webcam dimensions
- Line 156: Center positions
- **Fix**: Move to Constants

## Implementation Priority

**Phase 1 (Quick Wins)**:
1. Remove duplicate `Webcam.showComment()` calls
2. Cache all `require()` calls at top
3. Remove unused `drawAuditor()` function
4. Cache font creation (line 3274)
5. Extract magic numbers to Constants

**Phase 2 (Medium Effort)**:
1. Extract input handling to module
2. Extract screen drawing to separate files
3. Create particle system module
4. Remove old banner code

**Phase 3 (Major Refactor)**:
1. Split main.lua into logical modules
2. Implement state machine
3. Reorganize Game table structure
4. Create screen manager

## Benefits

- **Maintainability**: Easier to find and modify code
- **Readability**: Smaller, focused files
- **Testability**: Modules can be tested independently
- **Performance**: Better code organization can lead to optimizations
- **Collaboration**: Multiple developers can work on different modules
