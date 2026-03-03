-- src/core/entity_manager.lua
-- Entity management system for creating and destroying game entities

local EntityManager = {}

-- Clear all game entities
-- destroyTurret: if true, also destroys the turret body
function EntityManager.clearAll(destroyTurret)
    destroyTurret = destroyTurret or false
    
    -- Destroy turret if requested
    if destroyTurret and Game.turret and Game.turret.body then
        Game.turret.body:destroy()
        Game.turret = nil
    end
    
    -- Clear units
    for i = #Game.units, 1, -1 do
        local u = Game.units[i]
        if u.body and not u.isDead then
            u.body:destroy()
        end
        table.remove(Game.units, i)
    end
    
    -- Clear projectiles (with whistle sound cleanup)
    for i = #Game.projectiles, 1, -1 do
        local p = Game.projectiles[i]
        if not p then table.remove(Game.projectiles, i); goto continue end
        -- Stop whistle sound before destroying
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
        ::continue::
    end
    
    -- Clear powerups
    for i = #Game.powerups, 1, -1 do
        local p = Game.powerups[i]
        if p.body then
            p.body:destroy()
        end
        table.remove(Game.powerups, i)
    end
    
    -- Clear explosion zones
    for i = #Game.explosionZones, 1, -1 do
        local z = Game.explosionZones[i]
        if z.body then
            z.body:destroy()
        end
        table.remove(Game.explosionZones, i)
    end
    
    -- Clear hazards and effects (simple tables)
    Game.hazards = {}
    Game.effects = {}
    -- Clear deployed rage bait canisters and hashtags (inventory counts NOT cleared)
    Game.deployedRageBaits = {}
    Game.deployedHashtags = {}
end

-- Stop all projectile whistle sounds (used when returning to attract mode)
function EntityManager.stopAllProjectileSounds()
    for _, p in ipairs(Game.projectiles) do
        if p and p.whistleSound then
            pcall(function()
                if p.whistleSound:isPlaying() then
                    p.whistleSound:stop()
                    p.whistleSound:release()
                end
            end)
            p.whistleSound = nil
        end
    end
end

return EntityManager
