-- lfg demo

local lfg = require "lfg"


function love.load()
    assert(lfg.init({map_file="map_demo.lua"}))

    local minotaur = lfg.get_character("Minotaur")
    -- player_obj is map tile object with id="Player0"
    local base_obj = {
        name ="Player foo",
        char = minotaur,
        x = 5,
        y = 5,
        map_inputs = true,
    }

    local player_obj = lfg.player_obj or base_obj
    player_obj.map_inputs = true
    player_obj.char = minotaur

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
