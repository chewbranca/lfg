local lfg = {
    world_file = "world.dat",
    map_file = "map.lua",
    map = nil,

    conf = {
        flare_dir = "flare-game/",
        char_dir = "flare-game/art_src/characters/",
        anim_dir = "flare-game/art_src/animation_defs/",
        world_file = "world.dat",
        map_file = "map.lua",
    },
}

local entities_layer = nil

local anim8 = require "anim8"
local ini = require "inifile"
local lume = require "lume"
local serpent = require "serpent"
local sti = require "sti"

local characters_ = {}
local entities_ = {}

local D_W  = {x=-1, y=0}  -- row 1
local D_NW = {x=-1, y=-1} -- row 2
local D_N  = {x=0,  y=-1} -- row 3
local D_NE = {x=1,  y=-1} -- row 4
local D_E  = {x=1,  y=0}  -- row 5
local D_SE = {x=1,  y=1}  -- row 6
local D_S  = {x=0,  y=1}  -- row 7
local D_SW = {x=-1, y=1}  -- row 8

local DIRS = {
    D_W ,
    D_NW,
    D_N ,
    D_NE,
    D_E ,
    D_SE,
    D_S ,
    D_SW,
}

local NDIRS = {
    up = {x=0, y=-1},
    down = {x=0, y=1},
    left = {x=-1, y=0},
    right = {x=1, y=0},
    w = {x=0, y=-1},
    s = {x=0, y=1},
    a = {x=-1, y=0},
    d = {x=1, y=0},
}

local STATES = {
    run = "run",
    stand = "stance",
}

local DEFAULT_DIR = D_S
local DEFAULT_STATE = STATES.stand


function lfg.pp(obj, fn)
    if serpent[fn] then
        print(serpent[fn](obj))
    else
        print(serpent.block(obj))
    end
end


function lfg.dbg(...)
    if lfg.conf.debug then print(string.format(...)) end
end


function lfg.ini_parse(...)
   return ini.parse(...)
end


function lfg.ini_parse_file(...)
   return ini.parse(...)
end


function lfg.load_and_process(inifile)
    return lfg.process(lfg.ini_parse_file(inifile))
end


function lfg.process(conf)
    -- Animation Set
    local as = {
        w = 0,
        h = 0,
        ox = 0,
        oy = 0,
        animations = {}
    }
    for k, v in pairs(conf) do
        if k == "render_offset" and string.match(v, "^(%d+),(%d+)$") then
            local x, y = string.match(v, "^(%d+),(%d+)$")
            as.ox = tonumber(x)
            as.oy = tonumber(y)
        elseif k == "render_size" and string.match(v, "^(%d+),(%d+)$") then
            local w, h = string.match(v, "^(%d+),(%d+)$")
            as.w = tonumber(w)
            as.h = tonumber(h)
        elseif k == "image" and string.match(v, ".png$") then
            as.image_path = v
        elseif type(v) == "table" then
            as.animations[k] = lfg.process_animation(v)
        else
            lfg.dbg("UNKNOWN PAIR[%s]: %s = %s", type(v), k,v)
        end
    end

    return as
end


function lfg.process_animation(v)
    local a = {}
    for k, v in pairs(v) do
        if k == "duration" and string.match(v, "^(%d+)ms$") then
            local ms = tonumber(string.match(v, "^(%d+)ms$"))
            a.duration = ms / 1000
        elseif k == "duration" and string.match(v, "^(%d+)s$") then
            a.duration = tonumber(string.match(v, "^(%d+)s$"))
        elseif k == "frames" and string.match(v, "^(%d+)$") then
            a.frames = tonumber(string.match(v, "^(%d+)$"))
        elseif k == "position" and string.match(v, "^(%d+)$") then
            a.position = tonumber(string.match(v, "^(%d+)$"))
        elseif k == "type" and (v == "looped" or v == "back_forth" or v == "play_once") then
            a.type = v

            lfg.dbg("UNKNOWN ANIMATION PAIR[%s]: %s = %s", type(v), k,v)
        end
    end

    return a
end

        
function lfg.Character(c)
    assert(c.name, "Character name is present")
    assert(c.sprite, "Character sprite is present")
    assert(c.animation, "Character animation is present")

    local char = {
        ams = {},  -- animations
        as = nil,   -- animation_set
        grid = nil,
        sprite = nil,
        name = c.name,
        cdir = D_S,
        state = STATES.run,
    }

    local sprite_path = c.sprite:match("^/") and c.sprite or (lfg.conf.char_dir .. c.sprite)
    char.sprite = assert(love.graphics.newImage(sprite_path))

    local anim_path = lfg.conf.anim_dir .. c.animation
    char.as = assert(lfg.load_and_process(anim_path))

    char.grid = anim8.newGrid(char.as.w, char.as.h, char.sprite:getWidth(), char.sprite:getHeight())

    for row, dir in ipairs(DIRS) do
        char.ams[dir] = {}
        for name, am in pairs(char.as.animations) do
            local begin = am.position + 1
            local fin   = am.position + am.frames
            local fdur = am.duration / am.frames
            local frames = string.format("%s-%s", begin, fin)

            char.ams[dir][name] = anim8.newAnimation(char.grid(frames, row), fdur)
        end
    end

    characters_[char.name] = char
    return char
end

local Character = lfg.Character


function lfg.get_character(c) return characters_[c] end

local update_entities = function(self, dt)
    for _, ent in pairs(entities_layer.entities) do
        ent:update(dt)
    end
end


local draw_entities = function(self)
    for _, ent in pairs(entities_layer.entities) do
        ent:draw()
    end
end


function lfg.init(conf)
    if conf then
        for k, v in pairs(conf) do lfg.conf[k] = v end
    end

    _G.Character = lfg.Character
    dofile(lfg.conf.world_file)
    _G.Character = nil

    lfg.map = assert(sti(lfg.conf.map_file))
    entities_layer = lfg.map:addCustomLayer("Entities", 5)
    entities_layer.entities = {}
    entities_layer.update = update_entities
    entities_layer.draw = draw_entities

    return lfg
end


function lfg.update(dt)
    lfg.map:update(dt)
end


function lfg.draw(dt)
    lfg.map:draw(dt)
end


lfg.Entity = {}
local Entity_mt = { __index = lfg.Entity }

function lfg.Entity:new(name, char, x, y, r, ox, oy, map_inputs)
    assert(name)
    assert(char)

    local self = {
        char = char,
        name = name,
        x = x or 0,
        y = y or 0,
        ox = ox or 0,
        oy = oy or 0,
        vx = 0,
        vy = 0,
        cdir = DEFAULT_DIR,
        state = DEFAULT_STATE,
        am = char.ams[DEFAULT_DIR][DEFAULT_STATE],
        map_inputs = map_inputs or false,
        speed = 96,
    }
    setmetatable(self, Entity_mt)

    entities_[name] = self
    entities_layer.entities[name] = self

    print("CREATING ENTITY: ")
    lfg.pp(char.ams[DEFAULT_DIR])
    lfg.pp(self.am)
    lfg.pp(self)

    return self
end


function lfg.Entity:update(dt)
    if self.map_inputs then
        local dir = lfg.get_key_dir()
        if not dir then
            if self.state ~= STATES.stand then
                self.state = STATES.stand
                self.am = self.char.ams[self.cdir][self.state]
            end
        else
            if self.state ~= STATES.run then
                self.state = STATES.run
                self.am = self.char.ams[self.cdir][self.state]
            end

            if dir ~= self.cdir then
                self.am = self.char.ams[dir][self.state]
                self.cdir = dir
            end

            self.x = self.x + dir.x * self.speed * dt
            self.y = self.y + dir.y * self.speed * dt
        end
    end

    self.am:update(dt)
end


function lfg.Entity:draw()
    self.am:draw(self.char.sprite, self.x, self.y, 0, 1, 1, self.ox, self.oy)
end


function lfg.get_key_dir()
    local is_kd = love.keyboard.isDown
    local cdir = {x=0, y=0}
    local ret = nil

    for name, dir in pairs(NDIRS) do
        if love.keyboard.isDown(name) then
            cdir.x = cdir.x + dir.x
            cdir.y = cdir.y + dir.y
        end
    end

    if cdir.x == 0 and cdir.y == 0 then
        return nil
    end

    for _, dir in ipairs(DIRS) do
        if dir.x == cdir.x and dir.y == cdir.y then
            return dir
        end
    end
    assert(false, "should always find a dir")
end


return lfg
