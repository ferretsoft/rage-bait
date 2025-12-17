local Time = {}

function Time.init()
    Time.scale = 1.0       -- Current speed of the game
    Time.targetScale = 1.0 -- What speed we want to reach
    Time.restoreSpeed = 2.0 -- How fast we return to normal (1.0)
end

function Time.update(dt)
    -- Smoothly lerp (linear interpolate) current scale towards target scale
    -- We use unscaled 'dt' here because time logic must run in real-time
    if Time.scale < Time.targetScale then
        Time.scale = Time.scale + (Time.restoreSpeed * dt)
        if Time.scale > Time.targetScale then Time.scale = Time.targetScale end
    elseif Time.scale > Time.targetScale then
        -- Ramping down (entering slow mo) happens instantly or very fast
        Time.scale = Time.scale - (5.0 * dt) 
        if Time.scale < Time.targetScale then Time.scale = Time.targetScale end
    end
end

-- Call this to trigger a slow motion moment
-- factor: 0.1 (very slow) to 1.0 (normal)
-- duration: How long to stay slow before ramping back up
function Time.slowDown(factor, duration)
    Time.scale = factor
    Time.targetScale = factor
    
    -- After 'duration', automatically set target back to 1.0
    -- We use a simple closure/timer trick here later, but for now 
    -- let's just rely on the Game State to reset it, or use a simple timer:
    Time.timer = duration
end

function Time.checkRestore(dt)
    if Time.timer and Time.timer > 0 then
        Time.timer = Time.timer - dt
        if Time.timer <= 0 then
            Time.targetScale = 1.0 -- Begin ramp up
        end
    end
end

return Time