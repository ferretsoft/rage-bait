Particle = {}

function Particle.new(x, y, color)
    local p = {
        x = x,
        y = y,
        lifetime = math.random(0.5, 1.0),
        timer = 0,
        vx = math.random(-200, 200),
        vy = math.random(-200, 200),
        size = math.random(3, 6),
        color = color
    }
    setmetatable(p, { __index = Particle })
    return p
end

function Particle:update(dt)
    self.timer = self.timer + dt
    if self.timer >= self.lifetime then return true end
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    return false
end

function Particle:draw()
    local alpha = 1.0 - (self.timer / self.lifetime)
    local r, g, b = unpack(self.color)
    love.graphics.setColor(r, g, b, alpha)
    love.graphics.rectangle("fill", self.x, self.y, self.size, self.size)
end