ToxicZone = {}

function ToxicZone.new(x, y)
    local zone = {
        x = x,
        y = y,
        timer = 0,
        radius = 12, 
        animOffset = math.random() * 6.28
    }
    setmetatable(zone, { __index = ToxicZone })
    return zone
end

function ToxicZone:update(dt, users)
    self.timer = self.timer + dt
    
    local rSq = self.radius * self.radius
    
    for _, user in ipairs(users) do
        -- INSANE USERS ARE IMMUNE TO TOXICITY
        if not user.isInsane then
            local ux = user.x + user.width/2
            local uy = user.y + user.height/2
            
            local dx = self.x - ux
            local dy = self.y - uy
            
            if (dx*dx + dy*dy) < rSq then
                if user:takeDamage(10 * dt) then
                    user.killedByToxic = true
                end
            end
        end
    end
    
    return false 
end

function ToxicZone:draw()
    local pulse = math.sin(self.timer * 4 + self.animOffset) * 2
    local visualRadius = self.radius + pulse
    
    love.graphics.setColor(0.2, 0.8, 0.2, 0.8) 
    love.graphics.circle("fill", self.x, self.y, visualRadius)
    
    love.graphics.setColor(0.1, 0.5, 0.1, 1)
    love.graphics.circle("line", self.x, self.y, visualRadius)
end