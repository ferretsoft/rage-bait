local Constants = require("src.constants")
local World = {}

function World.init()
    love.physics.setMeter(64) 
    World.physics = love.physics.newWorld(0, 0, true)
    
    -- Create Walls (Same as before...)
    World.createWalls() 
end

function World.setCollisionCallbacks(beginContact)
    -- Register the listener with Love's physics engine
    World.physics:setCallbacks(beginContact, nil, nil, nil)
end

function World.createWalls()
    -- (Previous wall creation code goes here)
    -- Ensure you add walls so units don't fly away!
    World.walls = {}
    local w, h = Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT
    
    -- Helper to make a wall
    local function addWall(x, y, ww, wh)
        local body = love.physics.newBody(World.physics, x + ww/2, y + wh/2, "static")
        local shape = love.physics.newRectangleShape(ww, wh)
        local fixture = love.physics.newFixture(body, shape)
        fixture:setCategory(Constants.PHYSICS.WALL)
        -- Wall UserData is nil or a string, doesn't need to be a table
        fixture:setUserData({type="wall"}) 
        table.insert(World.walls, body)
    end
    
    addWall(0, -50, w, 50) -- Top
    addWall(0, h, w, 50)   -- Bottom
    addWall(-50, 0, 50, h) -- Left
    addWall(w, 0, 50, h)   -- Right
end

function World.update(dt)
    World.physics:update(dt)
end

function World.draw(drawFunc)
    love.graphics.push()
    love.graphics.translate(Constants.OFFSET_X, Constants.OFFSET_Y)
    
    -- Draw Playfield Border
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("line", 0, 0, Constants.PLAYFIELD_WIDTH, Constants.PLAYFIELD_HEIGHT)
    
    drawFunc()
    love.graphics.pop()
end

return World