# Code Optimization Suggestions

## High Priority (Performance Impact)

### 1. **Replace `table.remove()` in loops with swap-and-pop pattern**
**Location**: Multiple places (lines 2696, 2698, 2612-2614, etc.)
**Issue**: `table.remove()` is O(n) - shifts all elements after the removed index
**Solution**: Use swap-and-pop pattern (swap with last element, then remove last)
```lua
-- Instead of:
for i = #Game.units, 1, -1 do
    if Game.units[i].isDead then
        table.remove(Game.units, i)
    end
end

-- Use:
local writeIndex = 1
for i = 1, #Game.units do
    if not Game.units[i].isDead then
        if writeIndex ~= i then
            Game.units[writeIndex] = Game.units[i]
        end
        writeIndex = writeIndex + 1
    end
end
-- Trim the table
for i = writeIndex, #Game.units do
    Game.units[i] = nil
end
```

### 2. **Cache `math.randomseed()` calls**
**Location**: Line 1035 in `drawGlitchyTerminalText()`
**Issue**: `math.randomseed()` is called every frame, which is expensive
**Solution**: Only call when timer changes significantly, or use a different approach
```lua
-- Instead of calling every frame:
local seed = math.floor(Game.glitchTextTimer * 100)
if seed ~= Game.lastGlitchSeed then
    math.randomseed(seed)
    Game.lastGlitchSeed = seed
end
```

### 3. **Optimize string concatenation in loops**
**Location**: Line 1032-1045 in `drawGlitchyTerminalText()`
**Issue**: String concatenation in loops creates many temporary strings
**Solution**: Use `table.concat()` instead
```lua
-- Instead of:
local corruptedText = ""
for i = 1, #displayText do
    corruptedText = corruptedText .. char
end

-- Use:
local chars = {}
for i = 1, #displayText do
    table.insert(chars, char)
end
local corruptedText = table.concat(chars)
```

### 4. **Cache font creation**
**Location**: Line 3274 in draw loop
**Issue**: Creating fonts every frame is very expensive
**Solution**: Cache fonts or create them once
```lua
-- Add to Game.fonts:
Game.fonts.speechBubble = love.graphics.newFont(18)

-- Then use:
love.graphics.setFont(Game.fonts.speechBubble)
```

### 5. **Cache `require()` calls**
**Location**: Line 1629 (and potentially others)
**Issue**: `require()` is cached by Lua, but accessing it repeatedly is still overhead
**Solution**: Cache the result at module level
```lua
-- At top of file:
local Auditor = require("src.core.auditor")

-- Then use:
local errorMsg = Auditor.CRITICAL_ERROR
```

## Medium Priority (Code Quality & Minor Performance)

### 6. **Optimize win condition checking**
**Location**: Lines 2700-2742
**Issue**: Loops through all units twice (once for update, once for win condition)
**Solution**: Count units during update loop
```lua
-- During unit update loop, maintain counts:
local blueCount, redCount, neutralCount = 0, 0, 0
for i = #Game.units, 1, -1 do
    local u = Game.units[i]
    -- ... update logic ...
    if not u.isDead then
        if u.alignment == "blue" then blueCount = blueCount + 1
        elseif u.alignment == "red" then redCount = redCount + 1
        elseif u.state == "neutral" then neutralCount = neutralCount + 1
        end
    end
end
-- Then check win conditions with cached counts
```

### 7. **Reduce repeated `Constants` lookups**
**Location**: Throughout code
**Issue**: `Constants.SCREEN_WIDTH / 2` calculated repeatedly
**Solution**: Cache common calculations
```lua
-- At top of file or in Constants:
Constants.SCREEN_CENTER_X = Constants.SCREEN_WIDTH / 2
Constants.SCREEN_CENTER_Y = Constants.SCREEN_HEIGHT / 2
```

### 8. **Optimize spark particle updates**
**Location**: Lines 2230-2262, 2593-2602
**Issue**: Multiple separate loops for spark updates
**Solution**: Combine into single update function if possible, or use object pooling

### 9. **Cache `unpack()` calls**
**Location**: Line 1606
**Issue**: `unpack()` creates a new table
**Solution**: Store color values directly or cache unpacked values
```lua
-- Instead of:
local r,g,b = unpack(Constants.COLORS.TOXIC)

-- Use:
local TOXIC_R, TOXIC_G, TOXIC_B = unpack(Constants.COLORS.TOXIC)
-- Or better, define as separate constants
```

### 10. **Optimize explosion zone limit check**
**Location**: Line 549
**Issue**: `table.remove(Game.explosionZones, 1)` is O(n)
**Solution**: Use circular buffer or swap-and-pop
```lua
-- Instead of removing from front:
if #Game.explosionZones >= 5 then
    local oldZ = Game.explosionZones[1]
    if oldZ.body then oldZ.body:destroy() end
    -- Swap with last and remove last
    Game.explosionZones[1] = Game.explosionZones[#Game.explosionZones]
    table.remove(Game.explosionZones)
end
```

## Low Priority (Code Organization)

### 11. **Extract duplicate drawing code**
**Location**: Lines 1448-1460, 1527-1539, 1605-1625
**Issue**: Same drawing code repeated in multiple functions
**Solution**: Create shared `drawFrozenGameElements()` function (partially done, but could be more complete)

### 12. **Use object pooling for particles**
**Location**: Spark particles, effects
**Issue**: Constant allocation/deallocation of particle objects
**Solution**: Reuse particle objects from a pool

### 13. **Batch graphics state changes**
**Location**: Throughout draw functions
**Issue**: Many `setColor()`, `setFont()`, `setLineWidth()` calls
**Solution**: Group drawing by state to minimize state changes

### 14. **Optimize physics queries**
**Location**: Unit update code
**Issue**: Multiple physics queries per unit
**Solution**: Batch queries or use spatial partitioning

### 15. **Reduce table lookups in hot paths**
**Location**: Game loop
**Issue**: `Game.units[i]`, `Game.projectiles[i]` accessed multiple times
**Solution**: Cache in local variable
```lua
for i = 1, #Game.units do
    local u = Game.units[i]  -- Cache once
    -- Use 'u' instead of Game.units[i] throughout
end
```

## Memory Optimizations

### 16. **Pre-allocate tables where size is known**
**Location**: Spark particle creation
**Issue**: Tables grow dynamically
**Solution**: Pre-allocate with known size
```lua
-- Instead of:
Game.readySparks = {}
for i = 1, numSparks do
    table.insert(Game.readySparks, {...})
end

-- Use:
Game.readySparks = {}
for i = 1, numSparks do
    Game.readySparks[i] = {...}
end
```

### 17. **Reuse temporary tables**
**Location**: Name entry character building
**Issue**: Creates new table every time
**Solution**: Reuse a table and clear it

## Summary

**Highest Impact Optimizations:**
1. Replace `table.remove()` with swap-and-pop (affects all entity loops)
2. Cache font creation (affects draw performance)
3. Optimize string concatenation (affects text rendering)
4. Cache `math.randomseed()` (affects glitch text)

**Estimated Performance Gain:**
- High priority fixes: 20-40% FPS improvement in heavy scenes
- Medium priority fixes: 10-20% additional improvement
- Low priority fixes: 5-10% improvement + better code maintainability
