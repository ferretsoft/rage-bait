local Constants = require("src.constants")
local World = require("src.core.world")

local PowerUp = {}
PowerUp.__index = PowerUp

function PowerUp.new(x, y)
    local self = setmetatable({}, PowerUp)
    self.type = "powerup"
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
    
    -- Destroy if it falls off screen
    local x, y = self.body:getPosition()
    if y > Constants.PLAYFIELD_HEIGHT + 50 then
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
    
    -- Icon ("P" for Puck)
    love.graphics.printf("P", x - 10, y - 8, 20, "center")
end

return PowerUp