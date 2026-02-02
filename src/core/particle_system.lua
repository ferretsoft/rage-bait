-- src/core/particle_system.lua
-- Particle system for spark effects

local ParticleSystem = {}

-- Create spark particles in a circle pattern
function ParticleSystem.createSparks(centerX, centerY, count, speedMin, speedMax, sizeMin, sizeMax, lifetime)
    local sparks = {}
    for i = 1, count do
        local angle = (i / count) * math.pi * 2
        local speed = speedMin + math.random() * (speedMax - speedMin)
        table.insert(sparks, {
            x = centerX,
            y = centerY,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            life = lifetime,
            maxLife = lifetime,
            size = sizeMin + math.random() * (sizeMax - sizeMin)
        })
    end
    return sparks
end

-- Update spark particles (with gravity and fade)
function ParticleSystem.update(sparks, dt, gravity, fadeRate)
    for i = #sparks, 1, -1 do
        local spark = sparks[i]
        spark.x = spark.x + spark.vx * dt
        spark.y = spark.y + spark.vy * dt
        if gravity then
            spark.vy = spark.vy + gravity * dt
        end
        spark.life = spark.life - dt * fadeRate
        if spark.life <= 0 then
            table.remove(sparks, i)
        end
    end
end

-- Draw spark particles (gold/yellow with glow)
function ParticleSystem.draw(sparks, offsetY)
    offsetY = offsetY or 0
    for _, spark in ipairs(sparks) do
        local alpha = spark.life / spark.maxLife
        -- Gold/yellow sparks with fade
        local sparkColor = 0.3 + (spark.life / spark.maxLife) * 0.7  -- Fade from bright to dim
        love.graphics.setColor(1, 0.8 + sparkColor * 0.2, 0.2, alpha)
        love.graphics.circle("fill", spark.x, spark.y + offsetY, spark.size)
        -- Add glow effect
        love.graphics.setColor(1, 0.9, 0.3, alpha * 0.3)
        love.graphics.circle("fill", spark.x, spark.y + offsetY, spark.size * 2)
    end
end

return ParticleSystem



