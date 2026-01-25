-- src/core/draw_layers.lua
-- Centralized draw layer management using z-depth system
-- Higher z-depth = draws on top

local Constants = require("src.constants")

local DrawLayers = {}

-- Internal state: array of draw layers {zDepth, drawFunc, name}
local layers = {}

-- Clear all layers (call at start of each frame)
function DrawLayers.clear()
    layers = {}
end

-- Register a draw layer with a z-depth
-- zDepth: integer (higher = on top)
-- drawFunc: function to call when drawing
-- name: optional string for debugging
function DrawLayers.register(zDepth, drawFunc, name)
    table.insert(layers, {
        zDepth = zDepth,
        drawFunc = drawFunc,
        name = name or "unnamed"
    })
end

-- Draw all layers sorted by z-depth (lowest to highest)
function DrawLayers.drawAll()
    -- Sort by z-depth (ascending - lower numbers draw first)
    table.sort(layers, function(a, b)
        return a.zDepth < b.zDepth
    end)
    
    -- Draw all layers in order
    for _, layer in ipairs(layers) do
        layer.drawFunc()
    end
end

return DrawLayers





