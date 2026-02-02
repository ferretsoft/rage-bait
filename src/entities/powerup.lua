local Constants = require("src.constants")
local World = require("src.core.world")

local PowerUp = {}
PowerUp.__index = PowerUp

function PowerUp.new(x, y, powerupType)
    local self = setmetatable({}, PowerUp)
    self.type = "powerup"
    self.powerupType = powerupType or "puck"  -- "puck" or "bumper"
    self.x = x
    self.y = y
    self.isDead = false
    
    -- Physics body (Sensor so it detects hits but doesn't bounce)
    self.body = love.physics.newBody(World.physics, x, y, "dynamic")
    self.shape = love.physics.newCircleShape(Constants.POWERUP_RADIUS)
    self.fixture = love.physics.newFixture(self.body, self.shape)
    self.fixture:setCategory(Constants.PHYSICS.POWERUP)
    self.fixture:setMask(Constants.PHYSICS.UNIT) -- Don't collide with units
    self.fixture:setSensor(true)
    self.fixture:setUserData(self)
    
    -- Movement
    self.body:setLinearVelocity(0, Constants.POWERUP_SPEED)
    
    return self
end

function PowerUp:update(dt)
    if self.isDead then return end
    
    local x, y = self.body:getPosition()
    
    -- Clamp X position to playfield bounds (side walls)
    local margin = 20
    local clampedX = math.max(margin, math.min(Constants.PLAYFIELD_WIDTH - margin, x))
    if clampedX ~= x then
        self.body:setPosition(clampedX, y)
        -- Stop horizontal movement if hitting side walls
        local vx, vy = self.body:getLinearVelocity()
        self.body:setLinearVelocity(0, vy)
    end
    
    -- Destroy if it hits or passes the lower playfield edge
    if y >= Constants.PLAYFIELD_HEIGHT then
        self.isDead = true
        self.body:destroy()
    end
end

function PowerUp:hit()
    self.isDead = true
    self.body:destroy()
end

function PowerUp:draw()
    if self.isDead then return end
    local x, y = self.body:getPosition()
    
    -- Pulsing Gold Effect
    local pulse = 1 + math.sin(love.timer.getTime() * 10) * 0.1
    love.graphics.setColor(Constants.COLORS.GOLD)
    love.graphics.circle("fill", x, y, Constants.POWERUP_RADIUS * pulse)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("line", x, y, Constants.POWERUP_RADIUS * pulse)
    
    -- Icon
    if self.powerupType == "bumper" then
        love.graphics.printf("B", x - 10, y - 8, 20, "center")
    else
        love.graphics.printf("P", x - 10, y - 8, 20, "center")
    end
end

return PowerUp