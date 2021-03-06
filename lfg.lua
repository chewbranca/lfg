local anim8 = require "anim8"
local bump = require "bump"
local ini = require "inifile"
local lume = require "lume"
local serpent = require "serpent"
local sti = require "sti"


local lfg = {
    world_file = "world.dat",
    map_file = "map.lua",
    map = nil,
    player_obj = nil,
    m_objects = {},
    mouse = {
        x = 0,
        y = 0,
        e_dx = 0,
        e_dy = 0,
        angle = 0,
        distance = 0,
    },

    conf = {
        ["debug"] = true,

        flare_dir = "flare-game/",
        char_dir = "flare-game/art_src/characters/",
        anim_dir = "flare-game/art_src/animation_defs/",
        world_file = "world.dat",
        map_file = "map.lua",
    },
}

local real_player = {x = 25, y = 25}

-- in game actors
local entities_ = {}
local projectiles_ = {}

local entities_layer = nil
local projectiles_layer = nil

-- Flare Game base objects
local characters_ = {}
local spells_ = {}

-- This ordering on rows is based on the sprite sheets
local D_W  = {x=-1, y=0}  -- row 1
local D_NW = {x=-1, y=-1} -- row 2
local D_N  = {x=0,  y=-1} -- row 3
local D_NE = {x=1,  y=-1} -- row 4
local D_E  = {x=1,  y=0}  -- row 5
local D_SE = {x=1,  y=1}  -- row 6
local D_S  = {x=0,  y=1}  -- row 7
local D_SW = {x=-1, y=1}  -- row 8

-- Flare Game sprites are west oriented
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

-- radians are east oriented
local RDIRS = {
    D_E ,
    D_SE,
    D_S ,
    D_SW,
    D_W ,
    D_NW,
    D_N ,
    D_NE,
}

local KEY_DIRS = {
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
    swing = "swing",
    cast = "cast",
}

local DEFAULT_DIR = D_S
local DEFAULT_STATE = STATES.stand
local DEFAULT_SPEED = 150
local DEFAULT_PJT_SPEED = DEFAULT_SPEED * math.pi


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
        ams = {},   -- animations
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


function lfg.get_character(c) return characters_[c] end
function lfg.get_spell(s) return spells_[s] end


function lfg.Spell(s)
    assert(s.name, "Spell name is present")
    assert(s.sprite, "Spell sprite is present")
    assert(s.animation, "Spell animation is present")

    local spell = {
        ams = {},   -- animations
        as = nil,   -- animation_set
        grid = nil,
        sprite = nil,
        name = s.name,
    }

    local sprite_path = s.sprite:match("^/") and s.sprite or (lfg.conf.flare_dir .. s.sprite)
    spell.sprite = assert(love.graphics.newImage(sprite_path))

    local anim_path = lfg.conf.flare_dir .. s.animation
    spell.as = assert(lfg.load_and_process(anim_path))

    spell.grid = anim8.newGrid(spell.as.w, spell.as.h, spell.sprite:getWidth(), spell.sprite:getHeight())

    for row, dir in ipairs(DIRS) do
        spell.ams[dir] = {}
        for name, am in pairs(spell.as.animations) do
            local begin = am.position + 1
            local fin   = am.position + am.frames
            local fdur = am.duration / am.frames
            local frames = string.format("%s-%s", begin, fin)

            spell.ams[dir][name] = assert(anim8.newAnimation(spell.grid(frames, row), fdur))
        end
    end

    spells_[spell.name] = spell
    return spell
end


local update_projectiles = function(self, dt)
    local to_rem = {}
    for i, pjt in ipairs(projectiles_) do
        pjt.age = pjt.age + dt
        if pjt.age > pjt.max_age then
            table.insert(to_rem, i)
        end
    end

    for _, idx in ipairs(to_rem) do
        table.remove(projectiles_, idx)
    end

    for _, pjt in ipairs(projectiles_) do
        pjt:update(dt)
    end
end


local draw_projectiles = function(self)
    -- TODO: decide on storing projectiles in global or in map like entities
    for _, pjt in ipairs(projectiles_) do
        pjt:draw()
    end
end


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


-- thanks to: https://gamedev.stackexchange.com/questions/49290/whats-the-best-way-of-transforming-a-2d-vector-into-the-closest-8-way-compass-d
local function angle_to_dir(angle)
    local n = #RDIRS
    local i = 1 + math.floor(n * angle / (2 * math.pi) + n + 0.5) % n
    return RDIRS[i]
end


function lfg.init(conf)
    if conf then
        for k, v in pairs(conf) do lfg.conf[k] = v end
    end

    -- TODO: switch to proper env
    _G.Character = lfg.Character
    _G.Spell = lfg.Spell
    love.filesystem.load(lfg.conf.world_file)()
    _G.Character = nil
    _G.Spell = nil

    lfg.map = assert(sti(lfg.conf.map_file))

    for k, obj in pairs(lfg.map.objects) do
        lfg.m_objects[k] = obj
        if obj.name == "Player0" then
            assert(not lfg.player_obj)
            lfg.player_obj = obj
        else
            lfg.dbg("SKIPPING OBJ: %s", obj.name)
        end
    end

    lfg.map = assert(sti(lfg.conf.map_file, {"bump"}))
    -- TODO: does bump.cellSize need to be 2D for isometric?
    --lfg.world = bump.newWorld({x=64, y=32})
    --lfg.world = bump.newWorld({x=32, y=32})
    lfg.world = bump.newWorld(32)
    lfg.map:bump_init(lfg.world)

    -- ugly hack due to isometric bug with STI
    local map_mod_name = string.gsub(lfg.conf.map_file, ".lua$", "")
    local map_data = assert(require(map_mod_name))
    local layer = nil
    for _, l in pairs(map_data.layers) do
        if l.name == "collision" then
            layer = l
            break
        end
    end
    assert(layer)
    assert(#layer.data == layer.width * layer.height)

    lfg.real_world = bump.newWorld(1)

    for i, t in ipairs(layer.data) do
        -- assume any tile (eg t ~= 0) is a collision tile
        if t ~= 0 then
            -- zero offset
            local row = math.floor( i / layer.width)
            local col = i % layer.width
            local name = string.format("collision-%i", i)
            lfg.real_world:add(name, row, col, 1, 1)
        end
    end

    -- TODO: why doesn't this work?
    -- Still a bug somewhere in the isometric conversions
    --local count = 0
    --for i, v in ipairs(lfg.world:getItems()) do
    --    local item = lfg.world.rects[v]
    --    local x, y = lfg.map:convertPixelToTile(item.x, item.y)
    --    local name = string.format("collision-%i", i)
    --    lfg.dbg("ADDING COLLISION %s AT <%i, %i>[%i, %i]", name, x, y, item.x, item.y)
    --    --lfg.real_world:add(name, x, y, 1, 1)
    --end

    entities_layer = lfg.map:addCustomLayer("Entities", #lfg.map.layers + 1)
    entities_layer.entities = {}
    entities_layer.update = update_entities
    entities_layer.draw = draw_entities

    projectiles_layer = lfg.map:addCustomLayer("Projectiles", #lfg.map.layers + 1)
    projectiles_layer.update = update_projectiles
    projectiles_layer.draw = draw_projectiles

    return lfg
end


function lfg.set_player(player)
    real_player.x, real_player.y = player.x, player.y
    local x, y = lfg.map:convertTileToPixel(player.x, player.y)
    player.x, player.y = x, y
    lfg.world:add(player, player.x, player.y, 128, 128)
    lfg.real_world:add(real_player, real_player.x, real_player.y, 1, 1)
    lfg.player = player
end


function lfg.update(dt)
    lfg.map:update(dt)
end


function lfg.draw(dt)
    local tx = math.floor(lfg.player.x - love.graphics.getWidth() / 2)
    local ty = math.floor(lfg.player.y - love.graphics.getHeight() / 2)

    love.graphics.push()
    do
        lfg.map:draw(-tx, -ty)
        -- TODO: why is this still drawing on a rectangle grid?
        --lfg.map:bump_draw(lfg.world, -tx, -ty)
        love.graphics.translate(-tx, -ty)
        love.graphics.points(math.floor(lfg.player.x), math.floor(lfg.player.y))
        love.graphics.rectangle("line", lfg.player.x - lfg.player.ox, lfg.player.y - lfg.player.oy, 128, 128)
    end
    love.graphics.pop()

    love.graphics.print("Current FPS: "..tostring(love.timer.getFPS( )), 10, 10)
    local tl_x, tl_y = lfg.map:convertPixelToTile(lfg.player.x, lfg.player.y)
    love.graphics.print(string.format("Current Pos: (%.2f, %.2f) <%.2f, %.2f>", lfg.player.x, lfg.player.y, tl_x, tl_y), 10, 30)
    love.graphics.print(string.format("Mouse Pos:   (%.2f, %.2f)", lfg.mouse.x, lfg.mouse.y), 10, 50)
    local deg = (math.deg(lfg.mouse.angle) + 360) % 360
    love.graphics.print(string.format("Angle[%.2f]: %.2f {%.2f} {[%i]}", lfg.mouse.distance, lfg.mouse.angle, math.deg(lfg.mouse.angle), deg), 10, 70)
end


function lfg.mousemoved(m_x, m_y, dx, dy)
    -- TODO: redraw angle when player moves even if mouse doesn't move
    --    eg you could strafe far enough to warrant angle change

    -- {x,y} are middle of the screen, not player.{x,y}
    local x = math.floor(love.graphics.getWidth() / 2)
    local y = math.floor(love.graphics.getHeight() / 2)

    -- angle between player and mouse
    local angle = lume.angle(x, y, m_x, m_y)
    local distance = lume.distance(x, y, m_x, m_y)
    local e_dx, e_dy = lume.vector(angle, distance)

    lfg.mouse = {
        x = m_x,
        y = m_y,
        e_dx = e_dx,
        e_dy = e_dy,
        angle = angle,
        distance = distance,
    }

    lfg.player.cdir = angle_to_dir(angle)
    lfg.player:set_animation(lfg.player.cdir)
end


local resetstand = function()
    lfg.player.state = STATES.stand
    lfg.player:set_animation(lfg.player.cdir, lfg.player.state)
end

function lfg.mousepressed(m_x, m_y, button)
    local x = math.floor(love.graphics.getWidth() / 2)
    local y = math.floor(love.graphics.getHeight() / 2)

    -- angle between player and mouse
    local angle = lume.angle(x, y, m_x, m_y)
    local distance = lume.distance(x, y, m_x, m_y)
    local e_dx, e_dy = lume.vector(angle, distance)

    if button == 1 then
        lfg.player.state = STATES.swing
        lfg.player:set_animation(lfg.player.cdir, lfg.player.state)
        lfg.player.am.onLoop = resetstand
    elseif button == 2 then
        local n_dx = e_dx / distance
        local n_dy = e_dy / distance

        local pjt = lfg.Projectile:new({
            x      = lfg.player.x,
            y      = lfg.player.y,
            dx     = n_dx,
            dy     = n_dy,
            am     = lfg.player.spell.ams[lfg.player.cdir].power,
            ox     = lfg.player.spell.as.ox,
            oy     = lfg.player.spell.as.oy,
            sprite = lfg.player.spell.sprite,
        })

        lfg.player.state = STATES.cast
        lfg.player:set_animation(lfg.player.cdir, lfg.player.state)
        lfg.player.am.onLoop = resetstand
    end
end


lfg.Entity = {}
local Entity_mt = { __index = lfg.Entity }

function lfg.Entity:new(e)
    assert(e.name)
    assert(e.char)

    local self = {
        char       = e.char,
        name       = e.name,
        x          = e.x or 0,
        y          = e.y or 0,
        ox         = e.ox or e.char.as.ox or 0,
        oy         = e.oy or e.char.as.oy or 0,
        vx         = e.vx or .0,
        vy         = e.vy or .0,
        cdir       = e.cdir or DEFAULT_DIR,
        state      = e.state or DEFAULT_STATE,
        am         = e.am or e.char.ams[DEFAULT_DIR][DEFAULT_STATE],
        map_inputs = e.map_inputs or false,
        speed      = e.speed or DEFAULT_SPEED,
        spell      = e.spell or spells_["Fireball"],
        obj        = e,
    }
    setmetatable(self, Entity_mt)

    entities_[e.name] = self
    entities_layer.entities[e.name] = self

    return self
end


function lfg.Entity:set_animation(dir, state)
    assert(dir)
    state = state or self.state
    self.am = self.char.ams[dir][state]
end


function lfg.Entity:update(dt)
    if self.map_inputs then
        local dir = lfg.get_key_dir()
        if not dir then
            if self.state ~= STATES.stand then
                self.state = STATES.stand
            end
        else
            if self.state ~= STATES.run then
                self.state = STATES.run
                self:set_animation(self.cdir, self.state)
            end

            local x = self.x + dir.x * self.speed * dt
            local y = self.y + dir.y * self.speed * dt
            local tl_x, tl_y = lfg.map:convertPixelToTile(x, y)
            --local actual_x, actual_y, cols, len = lfg.world:move(
            --    lfg.player, new_x, new_y)
            local actual_x, actual_y, cols, len = lfg.real_world:move(
                real_player, tl_x, tl_y)
            local actual_x_px, actual_y_px = lfg.map:convertTileToPixel(
                actual_x, actual_y)

            real_player.x, real_player.y = actual_x, actual_y
            self.x, self.y = actual_x_px, actual_y_px
        end
    end

    self.am:update(dt)
end


function lfg.Entity:draw()
    self.am:draw(self.char.sprite, self.x, self.y, 0, 1, 1, self.ox, self.oy)
end

lfg.Projectile = {}
local Projectile_mt = { __index = lfg.Projectile }


function lfg.Projectile:new(p)
    assert(p.am)
    assert(p.sprite)
    assert(p.x)
    assert(p.y)
    assert(p.dx)
    assert(p.dy)

    local self = {
        am = p.am,
        sprite = p.sprite,
        x = p.x,
        y = p.y,
        dx = p.dx,
        dy = p.dy,

        ox = p.ox or 0,
        oy = p.oy or 0,
        speed = p.speed or DEFAULT_PJT_SPEED,

        age = 0,
        max_age = 5,
    }

    setmetatable(self, Projectile_mt)
    table.insert(projectiles_, self)

    return self
end


function lfg.Projectile:update(dt)
    self.x = self.x + self.dx * self.speed * dt
    self.y = self.y + self.dy * self.speed * dt

    self.am:update(dt)
end


function lfg.Projectile:draw()
    self.am:draw(self.sprite, self.x, self.y, 0, 1, 1, self.ox, self.oy)
end


function lfg.get_key_dir()
    local is_kd = love.keyboard.isDown
    local cdir = {x=0, y=0}
    local ret = nil

    for key, dir in pairs(KEY_DIRS) do
        if love.keyboard.isDown(key) then
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
