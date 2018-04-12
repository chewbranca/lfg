-- lfg demo

local lfg = require "lfg"


function love.load()
    assert(lfg.init({map_file="map_demo.lua"}))

    local minotaur = lfg.get_character("Minotaur") -- or "Skeleton" or "Zombie"
    local spell = lfg.get_spell("Fireball") -- or "Lightning" or "Channel", etc

    local player_obj = lfg.player_obj or {}
    player_obj.name ="Player foo"
    player_obj.char = minotaur
    player_obj.x = 5
    player_obj.y = 5
    player_obj.map_inputs = true
    player_obj.spell = spell

    local player = lfg.Entity:new(player_obj)
    lfg.set_player(player)
    lfg.dbg("PLAYER IS:")
    lfg.pp(player)
end


-- or: love.update = lfg.update
function love.update(dt)
    lfg.update(dt)
end


-- or: love.draw = lfg.draw
function love.draw()
    lfg.draw()
end


-- or: love.mousemoved = lfg.mousemoved
function love.mousemoved(...)
    lfg.mousemoved(...)
end

love.mousepressed = lfg.mousepressed
