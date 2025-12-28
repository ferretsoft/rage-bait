local Constants = require("src.constants")
local World = require("src.core.world")

local Bumper = {}
Bumper.__index = Bumper

function Bumper.new(x, y, height, color)
    local self = setmetatable({}, Bumper)
    
    self.type = "bumper"
    self.x = x
    self.y = y
    self.width = Constants.BUMPER_WIDTH
    self.height = height or Constants.BUMPER_HEIGHT
    self.cornerRadius = Constants.BUMPER_CORNER_RADIUS
    self.color = color or "blue"  -- Default to blue
    
    -- Physics body (static - doesn't move)
    -- Use rectangle shape for physics (rectangular collision)
    self.body = love.physics.newBody(World.physics, x, y, "static")
    self.shape = love.physics.newRectangleShape(self.width, self.height)
    self.fixture = love.physics.newFixture(self.body, self.shape)
    self.fixture:setCategory(Constants.PHYSICS.BUMPER)
    self.fixture:setRestitution(Constants.BUMPER_RESTITUTION)
    self.fixture:setUserData(self)
    
    -- State
    self.activated = false
    self.activeTimer = 0
    
    -- Visual effects
    self.flashTimer = 0
    
    return self
end

function Bumper:update(dt)
    self.flashTimer = math.max(0, self.flashTimer - dt * 5)
    
    -- Update activation timer
    if self.activated then
        self.activeTimer = self.activeTimer - dt
        if self.activeTimer <= 0 then
            self.activated = false
        end
    end
end

function Bumper:activate()
    if not self.activated then
        self.activated = true
        self.activeTimer = Constants.BUMPER_ACTIVE_DURATION
    end
    self.flashTimer = 0.3
end

function Bumper:draw()
    local x, y = self.body:getPosition()
    
    -- Flash effect when hit
    local flash = self.flashTimer > 0 and (self.flashTimer / 0.3) or 0
    
    local w = self.width
    local h = self.height
    local r = self.cornerRadius
    
    -- Get color values
    local baseColor, brightColor, fieldColor
    if self.color == "red" then
        baseColor = {0.6, 0.2, 0.2, 1}
        brightColor = {0.8, 0.4, 0.4, 1}
        fieldColor = {1, 0.2, 0.2, 1}
    else  -- blue
        baseColor = {0.2, 0.2, 0.6, 1}
        brightColor = {0.4, 0.4, 0.8, 1}
        fieldColor = {0.2, 0.6, 1, 1}
    end
    
    -- Draw forcefield if activated
    if self.activated then
        local fieldAlpha = 0.3 + math.sin(love.timer.getTime() * 8) * 0.1
        love.graphics.setColor(fieldColor[1], fieldColor[2], fieldColor[3], fieldAlpha)
        love.graphics.circle("fill", x, y, Constants.BUMPER_FORCEFIELD_RADIUS, 32)
        love.graphics.setColor(fieldColor[1] * 1.5, fieldColor[2] * 1.5, fieldColor[3] * 1.5, fieldAlpha + 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, Constants.BUMPER_FORCEFIELD_RADIUS, 32)
    end
    
    -- Draw rounded rectangle (outer - colored)
    if self.activated then
        love.graphics.setColor(baseColor[1] * 0.7, baseColor[2] * 0.7, baseColor[3] * 0.7, 1)  -- Darker when active
    else
        love.graphics.setColor(baseColor[1], baseColor[2], baseColor[3], 1)
    end
    love.graphics.rectangle("fill", x - w/2, y - h/2, w, h, r)
    
    -- Inner rounded rectangle (brighter)
    local innerW = w * 0.85
    local innerH = h * 0.85
    local innerR = r * 0.85
    if self.activated then
        love.graphics.setColor(brightColor[1], brightColor[2], brightColor[3], 1)  -- Brighter when active
    else
        love.graphics.setColor(brightColor[1] * 0.8, brightColor[2] * 0.8, brightColor[3] * 0.8, 1)
    end
    love.graphics.rectangle("fill", x - innerW/2, y - innerH/2, innerW, innerH, innerR)
    
    -- Flash overlay
    if flash > 0 then
        love.graphics.setColor(1, 1, 0.5, flash * 0.8)
        love.graphics.rectangle("fill", x - w/2, y - h/2, w, h, r)
    end
    
    -- Border
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x - w/2, y - h/2, w, h, r)
    
    -- Center highlight (small rounded rectangle)
    local centerW = w * 0.4
    local centerH = h * 0.4
    local centerR = r * 0.4
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("fill", x - centerW/2, y - centerH/2, centerW, centerH, centerR)
end

return Bumper

