# LFG (Lua Flare Game) library

LFG is a Lua (and Love 2D) library on top of the fantastic art and game assets in
[Flare Game](https://github.com/clintbellanger/flare-game) by [Clint
Bellanger](https://github.com/clintbellanger) and
[others](./CREDITS.txt). This project builds a game engine around the
amazing work in Flare Game using the [Love 2D](https://love2d.org/)
game engine as a base. This engine is built with multiplayer pvp in
mind and a subset of functionality from Flare Game is supported.

To see a demo of the engine you can create a main.lua file similar to:
(WARNING: "demo" is a stretch, more of a test bed at the moment)

``` lua
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
```

Or you can execute the demo directly with Love 2D:

```
# Clone the repo using git:
$ git clone https://github.com/chewbranca/lfg.git

# Or to get a zip file:
# $ wget https://github.com/chewbranca/lfg/archive/master.zip

# Download a love_0.10.2* release of your preference from:
# https://bitbucket.org/rude/love/downloads/

# Run the demo!
$ love .
```
