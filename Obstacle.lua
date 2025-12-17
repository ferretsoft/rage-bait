Obstacle = {}

function Obstacle.new(x, y, w, h)
    local obs = {
        x = x,
        y = y,
        width = w,
        height = h,
        color = {0.3, 0.3, 0.35} -- Concrete color
    }
    setmetatable(obs, { __index = Obstacle })
    return obs
end

function Obstacle:draw()
    love.graphics.setColor(self.color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    
    -- Draw a highlight/border for 3D effect
    love.graphics.setColor(0.4, 0.4, 0.45)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    love.graphics.setLineWidth(1)
end