-- src/core/demo_mode.lua
-- Demo mode (AI-controlled gameplay with tutorial)

local DemoMode = {}
local Constants = require("src.constants")
local Turret = require("src.entities.turret")
local Engagement = require("src.core.engagement")
local Sound = require("src.core.sound")
local ChasePaxton = require("src.core.chase_paxton")
local Unit = require("src.entities.unit")
local WindowFrame = require("src.core.window_frame")
local World = require("src.core.world")

-- Scripted demo actions for each step
local DEMO_SCRIPT = {
    -- Step 1: Welcome (no action)
    {
        spawnUnits = {},
        actions = {}
    },
    -- Step 2: Convert neutral unit with red (center of playfield)
    {
        spawnUnits = {
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2, alignment = "none"}
        },
        actions = {
            {time = 0.5, type = "rotate", targetX = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2, targetY = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2},
            {time = 1.0, type = "charge", color = "red", targetUnitIndex = 1},
            {time = 1.8, type = "release"}
        }
    },
    -- Step 3: Convert neutral unit with blue (slightly right of center)
    {
        spawnUnits = {
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 + 100, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2, alignment = "none"}
        },
        actions = {
            {time = 0.5, type = "rotate", targetX = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 + 100, targetY = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2},
            {time = 1.0, type = "charge", color = "blue", targetUnitIndex = 1},
            {time = 1.8, type = "release"}
        }
    },
    -- Step 4: Enrage a unit (hit red with blue, with multiple units to show attack)
    {
        spawnUnits = {
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 - 100, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2 - 50, alignment = "red", state = "passive"},
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 - 80, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2 + 50, alignment = "red", state = "passive"},
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 - 60, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2 - 30, alignment = "red", state = "passive"},
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 - 120, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2 - 70, alignment = "red", state = "passive"},
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 - 40, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2 + 70, alignment = "red", state = "passive"},
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 - 90, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2 + 20, alignment = "red", state = "passive"},
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 + 100, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2, alignment = "blue", state = "passive", speedMultiplier = 0.3},
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 + 80, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2 + 80, alignment = "blue", state = "passive", speedMultiplier = 0.3}
        },
        actions = {
            {time = 0.5, type = "rotate", targetX = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 - 100, targetY = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2 - 50},
            {time = 1.0, type = "charge", color = "blue", targetUnitIndex = 1},
            {time = 1.8, type = "release"}
        }
    },
    -- Step 5: Show toxic sludge from killed units (informational - no action, units stay from step 4)
    {
        spawnUnits = {},
        actions = {}
    },
    -- Step 6: Show isolated unit going insane (spawn isolated unit with high isolation timer)
    {
        spawnUnits = {
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2, alignment = "none", isolationTimer = Constants.ISOLATION_INSANE_TIME * 0.7}
        },
        actions = {}
    },
    -- Step 7: Show units fighting (spawn red and blue near each other)
    {
        spawnUnits = {
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 - 80, y = Constants.OFFSET_Y + 350, alignment = "red", state = "passive"},
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2 + 80, y = Constants.OFFSET_Y + 350, alignment = "blue", state = "passive"}
        },
        actions = {}
    },
    -- Step 8: Show toxic sludge and explain engagement decay (spawn unit, let it go insane, then freeze)
    {
        spawnUnits = {
            {x = Constants.OFFSET_X + Constants.PLAYFIELD_WIDTH / 2, y = Constants.OFFSET_Y + Constants.PLAYFIELD_HEIGHT / 2, alignment = "none", isolationTimer = Constants.ISOLATION_INSANE_TIME * 0.95}
        },
        actions = {}  -- Freeze will be triggered when toxic sludge appears (via verification)
    },
    -- Step 9: Informational (no action)
    {
        spawnUnits = {},
        actions = {}
    },
    -- Step 10: Exit message (no action)
    {
        spawnUnits = {},
        actions = {}
    }
}

-- Start demo mode (scripted gameplay with tutorial)
function DemoMode.start()
    Game.attractMode = false
    Game.attractModeTimer = 0
    Game.demoMode = true
    Game.demoTimer = 0
    Game.demoStep = 1
    Game.demoAITimer = 0
    Game.demoTargetUnit = nil
    Game.demoCharging = false
    Game.demoActionComplete = false
    Game.demoWaitingForMessage = true
    Game.demoUnitConverted = false
    Game.demoUnitEnraged = false
    Game.demoUnitsFighting = false
    Game.demoScriptTimer = 0  -- Timer for scripted actions
    Game.demoScriptActions = {}  -- Current step's actions
    
    -- Initialize game entities
    Game.turret = Turret.new()
    Game.score = 0
    Game.powerupSpawnTimer = 5.0
    
    Game.isUpgraded = false
    Game.hasUnitBeenConverted = false
    Game.gameState = "playing"
    Game.winCondition = nil
    Game.level = 1
    Game.levelTransitionTimer = 0
    Game.levelTransitionActive = false
    Game.levelCompleteScreenActive = false
    Game.levelCompleteScreenTimer = 0
    Game.winTextActive = false
    Game.slowMoActive = false
    Game.slowMoDuration = 0
    Game.timeScale = 1.0
    
    -- Reset engagement
    Engagement.init()
    
    -- Reset shake to prevent it from getting stuck
    Game.shake = 0
    
    -- Reset turret charging state
    if Game.turret then
        Game.turret.isCharging = false
        Game.turret.chargeTimer = 0
    end
    
    -- Clear all units
    for i = #Game.units, 1, -1 do
        local u = Game.units[i]
        if u.body and not u.isDead then
            u.body:destroy()
        end
        table.remove(Game.units, i)
    end
    
    -- Start background music
    Sound.playMusic()
    Sound.unmute()
end

-- Spawn a unit at a specific position with optional alignment and state
local function spawnDemoUnit(x, y, alignment, state, isolationTimer, speedMultiplier)
    local unit = Unit.new(World.physics, x, y)
    if alignment and alignment ~= "none" then
        unit.alignment = alignment
        unit.state = state or "passive"
        -- Set visual state to match
        if state == "enraged" then
            unit:enrage()
        end
    end
    -- Set isolation timer if provided (for demo step showing insane units)
    if isolationTimer then
        unit.isolationTimer = isolationTimer
    end
    -- Set speed multiplier for demo mode (makes units slower/faster)
    if speedMultiplier then
        unit.demoSpeedMultiplier = speedMultiplier
    end
    table.insert(Game.units, unit)
    return unit
end

-- Scripted demo controller (replaces AI with predefined actions)
function DemoMode.updateAI(dt)
    if not Game.turret or Game.gameState ~= "playing" then return end
    if Game.demoWaitingForMessage then return end  -- Don't act while showing message
    if Game.demoActionComplete then return end  -- Don't act after action is complete
    
    local script = DEMO_SCRIPT[Game.demoStep]
    if not script then return end
    
    -- Initialize script actions when starting a new step
    if #Game.demoScriptActions == 0 and #script.actions > 0 then
        Game.demoScriptActions = {}
        for _, action in ipairs(script.actions) do
            table.insert(Game.demoScriptActions, action)
        end
        Game.demoScriptTimer = 0
        
        -- Clear previous step's units (except for steps that need to show multiple units)
        -- Step 4 needs units to stay so enraged unit can attack and create toxic sludge
        -- Step 5 is informational - keep units and toxic sludge from step 4
        -- Step 6 needs units to stay for isolation demo
        -- Step 7 needs multiple units to show fighting
        if Game.demoStep ~= 4 and Game.demoStep ~= 5 and Game.demoStep ~= 6 and Game.demoStep ~= 7 then
            for i = #Game.units, 1, -1 do
                local u = Game.units[i]
                if u.body and not u.isDead then
                    u.body:destroy()
                end
                table.remove(Game.units, i)
            end
            -- Also clear explosion zones from previous step
            for i = #Game.explosionZones, 1, -1 do
                local z = Game.explosionZones[i]
                if z.body then
                    z.body:destroy()
                end
                table.remove(Game.explosionZones, i)
            end
            -- Reset shake to prevent it from getting stuck
            Game.shake = 0
            -- Reset turret charging state when clearing units
            if Game.turret then
                Game.turret.isCharging = false
                Game.turret.chargeTimer = 0
            end
        end
        
        -- Spawn units for this step
        for _, unitData in ipairs(script.spawnUnits) do
            spawnDemoUnit(unitData.x, unitData.y, unitData.alignment, unitData.state, unitData.isolationTimer, unitData.speedMultiplier)
        end
    end
    
    -- Execute scripted actions
    Game.demoScriptTimer = Game.demoScriptTimer + dt
    
    for i = #Game.demoScriptActions, 1, -1 do
        local action = Game.demoScriptActions[i]
        if Game.demoScriptTimer >= action.time then
            if action.type == "rotate" then
                -- Calculate angle to target position
                local turretX, turretY = Game.turret.x, Game.turret.y
                local dx = action.targetX - turretX
                local dy = action.targetY - turretY
                local targetAngle = math.atan2(dy, dx)
                -- Directly set angle (fast rotation)
                Game.turret.angle = targetAngle
                -- Normalize angle
                while Game.turret.angle > math.pi do Game.turret.angle = Game.turret.angle - 2 * math.pi end
                while Game.turret.angle < -math.pi do Game.turret.angle = Game.turret.angle + 2 * math.pi end
            elseif action.type == "charge" then
                if not Game.demoCharging then
                    Game.turret:startCharge(action.color)
                    Game.demoCharging = true
                    -- Calculate target distance for charge using the target unit index or nearest unit
                    local turretX, turretY = Game.turret.x, Game.turret.y
                    local targetUnit = nil
                    
                    if action.targetUnitIndex then
                        -- Use specific unit index from script
                        local script = DEMO_SCRIPT[Game.demoStep]
                        if script and script.spawnUnits and script.spawnUnits[action.targetUnitIndex] then
                            -- Find the unit at the spawn position
                            local targetX = script.spawnUnits[action.targetUnitIndex].x
                            local targetY = script.spawnUnits[action.targetUnitIndex].y
                            for _, unit in ipairs(Game.units) do
                                if not unit.isDead then
                                    local ux, uy = unit.body:getPosition()
                                    local dist = math.sqrt((ux - targetX)^2 + (uy - targetY)^2)
                                    if dist < 50 then  -- Close enough to be the spawned unit
                                        targetUnit = unit
                                        break
                                    end
                                end
                            end
                        end
                    end
                    
                    -- Fallback: find nearest unit (but only neutral units for steps before enrage demo)
                    if not targetUnit then
                        local minDist = 999999
                        for _, unit in ipairs(Game.units) do
                            if not unit.isDead then
                                -- For steps 2-3, only target neutral units to avoid enraging converted units
                                if Game.demoStep <= 3 and unit.state ~= "neutral" then
                                    -- Skip non-neutral units in early steps
                                else
                                    local ux, uy = unit.body:getPosition()
                                    local dx = ux - turretX
                                    local dy = uy - turretY
                                    local dist = math.sqrt(dx*dx + dy*dy)
                                    if dist < minDist then
                                        minDist = dist
                                        targetUnit = unit
                                    end
                                end
                            end
                        end
                    end
                    
                    if targetUnit then
                        local ux, uy = targetUnit.body:getPosition()
                        local dx = ux - turretX
                        local dy = uy - turretY
                        local dist = math.sqrt(dx*dx + dy*dy)
                        -- Aim for exact unit position (subtract small amount to account for any physics/calculation differences)
                        -- This ensures explosion center lands on unit, not past it
                        Game.demoTargetDistance = math.max(50, dist - 10)
                    else
                        -- Calculate distance to target position from rotate action
                        local script = DEMO_SCRIPT[Game.demoStep]
                        if script and script.actions then
                            for _, act in ipairs(script.actions) do
                                if act.type == "rotate" then
                                    local dx = act.targetX - turretX
                                    local dy = act.targetY - turretY
                                    local dist = math.sqrt(dx*dx + dy*dy)
                                    -- Aim for exact target position
                                    Game.demoTargetDistance = dist
                                    break
                                end
                            end
                        end
                        if not Game.demoTargetDistance then
                            Game.demoTargetDistance = 400
                        end
                    end
                    
                    -- Calculate and store the maximum charge time needed
                    Game.demoMaxChargeTime = Game.demoTargetDistance / 500
                    local maxRange = Game.isUpgraded and Constants.BOMB_RANGE_MAX or Constants.BOMB_RANGE_BASE
                    local maxChargeTime = maxRange / 500
                    Game.demoMaxChargeTime = math.min(Game.demoMaxChargeTime, maxChargeTime)
                end
                
                -- Continuously cap charge timer to prevent overshooting
                if Game.demoCharging and Game.turret.isCharging and Game.demoMaxChargeTime then
                    if Game.turret.chargeTimer > Game.demoMaxChargeTime then
                        Game.turret.chargeTimer = Game.demoMaxChargeTime
                    end
                end
            elseif action.type == "release" then
                if Game.demoCharging and Game.turret.isCharging then
                    -- Ensure charge timer is at the exact required level (should already be capped)
                    if Game.demoMaxChargeTime then
                        Game.turret.chargeTimer = Game.demoMaxChargeTime
                    end
                    
                    Game.turret:releaseCharge(Game.projectiles)
                    Game.demoCharging = false
                    Game.demoTargetDistance = nil
                    Game.demoMaxChargeTime = nil
                end
            elseif action.type == "freeze" then
                -- Trigger slow-motion freeze when toxic sludge appears
                Game.slowMoActive = true
                Game.slowMoTimer = 0
                Game.slowMoDuration = 1.5
                Game.timeScale = 1.0
            end
            table.remove(Game.demoScriptActions, i)
        end
    end
end

-- Check if demo step verification is complete
function DemoMode.checkVerification()
    -- Step 1: Welcome message - no verification needed
    if Game.demoStep == 1 then
        return true
    end
    
    -- Step 2-3: Need to verify a unit was converted
    if Game.demoStep == 2 or Game.demoStep == 3 then
        -- Check if any unit was converted (changed from neutral to passive)
        for _, unit in ipairs(Game.units) do
            if not unit.isDead and unit.state == "passive" and unit.alignment ~= "none" then
                return true
            end
        end
        return false
    end
    
    -- Step 4: Need to verify a unit was enraged AND toxic sludge appeared (from killed units)
    if Game.demoStep == 4 then
        local unitEnraged = false
        for _, unit in ipairs(Game.units) do
            if not unit.isDead and unit.state == "enraged" then
                unitEnraged = true
                break
            end
        end
        -- Also check for toxic sludge (units must have died)
        local hasToxicSludge = false
        for _, hazard in ipairs(Game.hazards) do
            if hazard.radius > 0 and hazard.timer > 0 then
                hasToxicSludge = true
                break
            end
        end
        return unitEnraged and hasToxicSludge
    end
    
    -- Step 5: Need to verify toxic sludge appeared from killed units (informational step)
    -- Since step 4 already ensures toxic sludge exists, this should always pass
    if Game.demoStep == 5 then
        -- Check if toxic hazard exists (from killed units in step 4)
        for _, hazard in ipairs(Game.hazards) do
            if hazard.radius > 0 and hazard.timer > 0 then
                return true
            end
        end
        return false
    end
    
    -- Step 6: Need to verify a unit went insane (exploded from isolation)
    if Game.demoStep == 6 then
        -- Check if any unit has gone insane
        for _, unit in ipairs(Game.units) do
            if unit.isInsane then
                return true
            end
        end
        -- Also check effects for explosion from insane unit (has speech bubble)
        for _, effect in ipairs(Game.effects) do
            if effect.type == "explosion" and effect.speechBubble then
                return true
            end
        end
        -- Check for insane toxic hazards (larger radius indicates insane explosion)
        for _, hazard in ipairs(Game.hazards) do
            if hazard.radius >= Constants.INSANE_TOXIC_RADIUS * 0.9 then  -- Close to insane radius
                return true
            end
        end
        return false
    end
    
    -- Step 7: Need to verify units are fighting (different alignments exist)
    if Game.demoStep == 7 then
        local hasRed = false
        local hasBlue = false
        for _, unit in ipairs(Game.units) do
            if not unit.isDead and unit.state ~= "neutral" then
                if unit.alignment == "red" then hasRed = true end
                if unit.alignment == "blue" then hasBlue = true end
            end
        end
        return hasRed and hasBlue
    end
    
    -- Step 8: Need to verify toxic sludge appeared (for engagement decay explanation)
    if Game.demoStep == 8 then
        -- Check if toxic hazard exists (from insane explosion)
        for _, hazard in ipairs(Game.hazards) do
            if hazard.radius > 0 and hazard.timer > 0 then
                return true
            end
        end
        return false
    end
    
    -- Step 9-10: Informational steps - no verification needed
    if Game.demoStep >= 9 then
        return true
    end
    
    return false
end

-- Update demo mode
function DemoMode.update(dt)
    Game.demoTimer = Game.demoTimer + dt
    Game.demoAITimer = Game.demoAITimer + dt
    
    if Game.demoStep <= #ChasePaxton.DEMO_MESSAGES then
        local currentMessage = ChasePaxton.DEMO_MESSAGES[Game.demoStep]
        
        -- Phase 1: Show message for a few seconds (reduced for faster demo)
        -- Special case: Step 5 waits for toxic sludge BEFORE showing message
        -- Special case: Step 10 shows message for full duration then returns to attract mode
        if Game.demoWaitingForMessage then
            -- For step 5, wait for toxic sludge to appear before showing message
            -- Since step 4 already ensures toxic sludge exists, this should pass quickly
            if Game.demoStep == 5 then
                -- Keep waiting until toxic sludge appears (should be immediate since step 4 verified it)
                if DemoMode.checkVerification() then
                    -- Toxic sludge exists, wait a moment to ensure it's clearly visible before showing message
                    if Game.demoAITimer >= 0.5 then
                        Game.demoWaitingForMessage = false
                        Game.demoActionComplete = false
                        Game.demoAITimer = 0
                    end
                end
            -- Step 10: Show message for full duration, then return to attract mode
            elseif Game.demoStep == 10 then
                if Game.demoAITimer >= currentMessage.duration then
                    -- Return to attract mode
                    Game.demoMode = false
                    Game.attractMode = true
                    Game.attractModeTimer = 0
                    Game.demoTimer = 0
                    Game.demoStep = 1
                    Game.demoAITimer = 0
                    Game.demoTargetUnit = nil
                    Game.demoCharging = false
                    
                    -- Clean up game entities
                    for i = #Game.units, 1, -1 do
                        local u = Game.units[i]
                        if u.body and not u.isDead then
                            u.body:destroy()
                        end
                        table.remove(Game.units, i)
                    end
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
                    for i = #Game.powerups, 1, -1 do
                        local p = Game.powerups[i]
                        if p.body then
                            p.body:destroy()
                        end
                        table.remove(Game.powerups, i)
                    end
                    for i = #Game.explosionZones, 1, -1 do
                        local z = Game.explosionZones[i]
                        if z.body then
                            z.body:destroy()
                        end
                        table.remove(Game.explosionZones, i)
                    end
                    Game.hazards = {}
                    Game.effects = {}
                    
                    -- Destroy turret if it exists
                    if Game.turret then
                        if Game.turret.webBody then
                            Game.turret.webBody:destroy()
                        end
                        if Game.turret.barrierBody then
                            Game.turret.barrierBody:destroy()
                        end
                        if Game.turret.hardBarrierBody then
                            Game.turret.hardBarrierBody:destroy()
                        end
                        Game.turret = nil
                    end
                    
                    -- Clean up sounds and unmute before playing intro music
                    Sound.cleanup()
                    Sound.unmute()
                    -- Start playing intro music when returning to attract mode
                    Sound.playIntroMusic()
                end
            elseif Game.demoAITimer >= 1.5 then  -- Reduced from 2.0 to 1.5 seconds
                Game.demoWaitingForMessage = false
                Game.demoActionComplete = false
                Game.demoAITimer = 0
                -- Reset verification flags for new step
                Game.demoUnitConverted = false
                Game.demoUnitEnraged = false
                Game.demoUnitsFighting = false
                -- Reset slow-mo state when starting a new step
                Game.slowMoActive = false
                Game.timeScale = 1.0
                Game.slowMoTimer = 0
                Game.slowMoDuration = 0
            end
        -- Phase 2: Perform action and verify
        elseif not Game.demoActionComplete then
            -- Step 5 is informational - it already verified in Phase 1, just show message and complete
            if Game.demoStep == 5 then
                -- Ensure slow-mo is not active (shouldn't be, but just in case)
                Game.slowMoActive = false
                Game.timeScale = 1.0
                Game.slowMoTimer = 0
                Game.slowMoDuration = 0
                -- Show message for a moment, then mark complete
                if Game.demoAITimer >= 2.0 then
                    Game.demoActionComplete = true
                    Game.demoAITimer = 0
                end
            else
                -- AI will perform action (handled in updateAI)
                -- Check if verification is complete
                if DemoMode.checkVerification() then
                    -- For step 4, wait longer to let enraged unit attack and create toxic sludge
                    -- For step 8, trigger freeze when toxic sludge appears
                    if Game.demoStep == 8 and not Game.slowMoActive then
                        Game.slowMoActive = true
                        Game.slowMoTimer = 0
                        Game.slowMoDuration = 1.5
                        Game.timeScale = 1.0
                    end
                    -- Wait a moment to show the result before marking complete
                    -- Step 4: Wait longer after toxic sludge appears to ensure it's visible
                    -- Step 8: Wait longer to show the frozen toxic sludge
                    local waitTime = 0.8  -- Default
                    if Game.demoStep == 4 then
                        -- Wait 2 seconds after toxic sludge appears to ensure it's visible when step 5 starts
                        waitTime = 2.0
                    elseif Game.demoStep == 8 then
                        waitTime = 2.5  -- Show frozen toxic sludge
                    end
                    if Game.demoAITimer >= waitTime then
                        Game.demoActionComplete = true
                        Game.demoAITimer = 0
                    end
                end
            end
        -- Phase 3: Action complete, advance to next step (faster transition)
        elseif Game.demoActionComplete then
            if Game.demoAITimer >= 0.5 then  -- Reduced from 1.0 to 0.5 seconds
                if Game.demoStep < #ChasePaxton.DEMO_MESSAGES then
                    -- Clear script state for next step
                    Game.demoScriptActions = {}
                    Game.demoScriptTimer = 0
                    
                    -- Reset shake and slow-mo to prevent them from getting stuck between steps
                    Game.shake = 0
                    Game.slowMoActive = false
                    Game.timeScale = 1.0
                    Game.slowMoTimer = 0
                    Game.slowMoDuration = 0
                    
                    local nextStep = Game.demoStep + 1
                    
                    -- Clear units before transitioning (except steps that need to keep units)
                    -- Step 4 needs units to stay so enraged unit can attack and create toxic sludge
                    -- Step 5 is informational - keep units and toxic sludge from step 4
                    -- Step 6 needs to clear previous units and spawn isolated unit
                    -- Step 7 needs multiple units to show fighting
                    if nextStep == 6 then
                        -- Clear all units before step 6 (isolated unit demo)
                        for i = #Game.units, 1, -1 do
                            local u = Game.units[i]
                            if u.body and not u.isDead then
                                u.body:destroy()
                            end
                            table.remove(Game.units, i)
                        end
                        -- Clear explosion zones
                        for i = #Game.explosionZones, 1, -1 do
                            local z = Game.explosionZones[i]
                            if z.body then
                                z.body:destroy()
                            end
                            table.remove(Game.explosionZones, i)
                        end
                        -- Clear hazards from previous steps
                        Game.hazards = {}
                    elseif nextStep ~= 4 and nextStep ~= 5 and nextStep ~= 7 then
                        -- Clear units for other steps
                        for i = #Game.units, 1, -1 do
                            local u = Game.units[i]
                            if u.body and not u.isDead then
                                u.body:destroy()
                            end
                            table.remove(Game.units, i)
                        end
                        -- Clear explosion zones
                        for i = #Game.explosionZones, 1, -1 do
                            local z = Game.explosionZones[i]
                            if z.body then
                                z.body:destroy()
                            end
                            table.remove(Game.explosionZones, i)
                        end
                    end
                    
                    -- Spawn units for next step immediately
                    local nextScript = DEMO_SCRIPT[nextStep]
                    if nextScript then
                        for _, unitData in ipairs(nextScript.spawnUnits) do
                            spawnDemoUnit(unitData.x, unitData.y, unitData.alignment, unitData.state, unitData.isolationTimer, unitData.speedMultiplier)
                        end
                    end
                    
                    -- Reset turret charging state to prevent reticule from getting stuck
                    if Game.turret then
                        Game.turret.isCharging = false
                        Game.turret.chargeTimer = 0
                        -- Stop charging sound if playing
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
                    
                    Game.demoStep = nextStep
                    Game.demoWaitingForMessage = true
                    Game.demoActionComplete = false
                    Game.demoAITimer = 0
                    Game.demoCharging = false
                    Game.demoTargetUnit = nil
                end
            end
        end
    end
end

-- Draw demo mode screen
function DemoMode.draw()
    -- Draw the game normally (drawGame is defined in main.lua)
    if drawGame then
        drawGame()
    end
    
    -- Draw tutorial message overlay (always visible, only text changes)
    if Game.demoStep <= #ChasePaxton.DEMO_MESSAGES then
        local currentMessage = ChasePaxton.DEMO_MESSAGES[Game.demoStep]
        
        -- Always show the Paxton window, only the text changes
        -- Draw webcam with tutorial message (positioned at top center for visibility)
            local WEBCAM_WIDTH = 600
            local WEBCAM_HEIGHT = 280
            local WEBCAM_X = (Constants.SCREEN_WIDTH - WEBCAM_WIDTH) / 2
            local WEBCAM_Y = 50  -- Position at top of screen
            local titleBarHeight = 20
            local borderWidth = 3
            
            -- Draw transparent black background for content area
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", WEBCAM_X + borderWidth, WEBCAM_Y + borderWidth + titleBarHeight, 
                WEBCAM_WIDTH - (borderWidth * 2), WEBCAM_HEIGHT - (borderWidth * 2) - titleBarHeight)
            
            -- Draw Windows 95 style frame with title bar
            WindowFrame.draw(WEBCAM_X, WEBCAM_Y, WEBCAM_WIDTH, WEBCAM_HEIGHT, "Chase Paxton")
            
            -- Draw Chase Paxton character (smaller, on left side) - adjust for title bar
            local charX = WEBCAM_X + 80
            local charY = WEBCAM_Y + titleBarHeight + borderWidth + 60
            
            -- Character head
            love.graphics.setColor(0.9, 0.8, 0.7, 1)
            love.graphics.circle("fill", charX, charY, 50)
            love.graphics.setColor(0.7, 0.6, 0.5, 1)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", charX, charY, 50)
            
            -- Eyes (animated)
            local eyeOffset = math.sin(Game.demoTimer * 3) * 2
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.circle("fill", charX - 12 + eyeOffset, charY - 8, 4)
            love.graphics.circle("fill", charX + 12 + eyeOffset, charY - 8, 4)
            
            -- Mouth (talking animation)
            local mouthOpen = math.sin(Game.demoTimer * 8) > 0
            if mouthOpen then
                love.graphics.ellipse("fill", charX, charY + 12, 7, 4)
            else
                love.graphics.arc("line", charX, charY + 12, 7, 0, math.pi)
            end
            
            -- Tutorial message (large font, on right side, with word wrapping)
            love.graphics.setFont(Game.fonts.large)  -- Use large font for better visibility
            love.graphics.setColor(1, 1, 1, 1)
            
            -- Calculate available space for text - adjust for title bar
            local charWidth = 160  -- Character takes up ~160px (80px radius circle + padding)
            local textX = WEBCAM_X + charWidth + 20  -- Start after character with padding
            local textY = WEBCAM_Y + titleBarHeight + borderWidth + 20  -- Top padding
            local textWidth = WEBCAM_WIDTH - charWidth - 40  -- Available width (window - char - padding)
            local textHeight = WEBCAM_HEIGHT - titleBarHeight - borderWidth - 40  -- Available height (window - title bar - padding)
            
            -- Split message by newlines first
            local paragraphs = {}
            for para in currentMessage.message:gmatch("[^\n]+") do
                table.insert(paragraphs, para)
            end
            
            -- Word wrap each paragraph to fit within textWidth
            local wrappedLines = {}
            for _, para in ipairs(paragraphs) do
                local words = {}
                for word in para:gmatch("%S+") do
                    table.insert(words, word)
                end
                
                local currentLine = ""
                for _, word in ipairs(words) do
                    local testLine = currentLine == "" and word or currentLine .. " " .. word
                    local lineWidth = Game.fonts.large:getWidth(testLine)
                    
                    if lineWidth <= textWidth then
                        currentLine = testLine
                    else
                        if currentLine ~= "" then
                            table.insert(wrappedLines, currentLine)
                        end
                        currentLine = word
                        -- If a single word is too long, force it anyway
                        if Game.fonts.large:getWidth(word) > textWidth then
                            table.insert(wrappedLines, word)
                            currentLine = ""
                        end
                    end
                end
                if currentLine ~= "" then
                    table.insert(wrappedLines, currentLine)
                end
            end
            
            -- Draw wrapped lines, ensuring they fit vertically
            local lineHeight = Game.fonts.large:getHeight() + 6  -- Line height with spacing
            local maxLines = math.floor(textHeight / lineHeight)
            local linesToDraw = math.min(#wrappedLines, maxLines)
            
            for i = 1, linesToDraw do
                love.graphics.print(wrappedLines[i], textX, textY + (i - 1) * lineHeight)
            end
    end
end

-- Handle input in demo mode
function DemoMode.keypressed(key)
    if key == "space" or key == "return" or key == "enter" then
        -- Exit demo mode and return to attract mode
        Game.demoMode = false
        Game.demoTimer = 0
        Game.demoStep = 1
        Game.demoAITimer = 0
        Game.demoTargetUnit = nil
        Game.demoCharging = false
        
        -- Clean up game entities
        for i = #Game.units, 1, -1 do
            local u = Game.units[i]
            if u.body and not u.isDead then
                u.body:destroy()
            end
            table.remove(Game.units, i)
        end
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
        for i = #Game.powerups, 1, -1 do
            local p = Game.powerups[i]
            if p.body then
                p.body:destroy()
            end
            table.remove(Game.powerups, i)
        end
        for i = #Game.explosionZones, 1, -1 do
            local z = Game.explosionZones[i]
            if z.body then
                z.body:destroy()
            end
            table.remove(Game.explosionZones, i)
        end
        Game.hazards = {}
        Game.effects = {}
        
        -- Destroy turret if it exists
        if Game.turret then
            if Game.turret.webBody then
                Game.turret.webBody:destroy()
            end
            if Game.turret.barrierBody then
                Game.turret.barrierBody:destroy()
            end
            if Game.turret.hardBarrierBody then
                Game.turret.hardBarrierBody:destroy()
            end
            Game.turret = nil
        end
        
        Sound.cleanup()
        Sound.unmute()
        
        -- Return to attract mode
        Game.attractMode = true
        Game.attractModeTimer = 0
        -- Start playing intro music when returning to attract mode
        Sound.playIntroMusic()
        return true
    end
    return false
end

return DemoMode


