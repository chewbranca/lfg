-- lfg demo

local lfg = require "lfg"

function love.load()
    assert(lfg.init({map_file="map_oasis.lua"}))

    local minotaur = lfg.get_character("Minotaur")
    local player = lfg.Entity:new("Player foo", minotaur, 100, 100, 0, 0, 0, true)
end


function love.update(dt)
    lfg.update(dt)
end

function love.draw()
    lfg.draw()
end
