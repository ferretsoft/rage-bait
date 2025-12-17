-- src/core/event.lua
local Event = {}
local listeners = {}

function Event.on(name, callback)
    if not listeners[name] then
        listeners[name] = {}
    end
    table.insert(listeners[name], callback)
end

function Event.emit(name, data)
    if listeners[name] then
        for _, callback in ipairs(listeners[name]) do
            callback(data)
        end
    end
end

function Event.clear()
    listeners = {}
end

return Event