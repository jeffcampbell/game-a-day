pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- Sky Climb: A platformer where you jump up through platforms to reach the top
-- Use arrow keys to move left/right, Z or C to jump

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function test_input(b)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn(b)
end

-- Game state
state = "menu"
score = 0
height = 0
max_height = 0

-- Player
player = {
  x = 64,
  y = 100,
  w = 4,
  h = 6,
  vx = 0,
  vy = 0,
  on_ground = false,
  jump_power = 3
}

-- Platforms
platforms = {}
function init_platforms()
  platforms = {}
  -- Static starting platform
  add(platforms, {x=56, y=110, w=16, h=2, color=3})

  -- Generate scrolling platforms
  for i = 1, 20 do
    local py = 110 - i * 12
    local px = 20 + flr(rnd(70))
    local pw = 8 + flr(rnd(10))
    add(platforms, {x=px, y=py, w=pw, h=2, color=2})
  end
end

-- Enemies (spikes)
spikes = {}
function init_spikes()
  spikes = {}
  for i = 1, 8 do
    local sy = 60 - i * 18
    local sx = 15 + flr(rnd(98))
    add(spikes, {x=sx, y=sy, w=6, h=4, color=8})
  end
end

function _init()
  _log("game:init")
  init_platforms()
  init_spikes()
end

function update_menu()
  if test_input(4) > 0 or btnp(4) > 0 then
    _log("state:play")
    state = "play"
    score = 0
    height = 0
    max_height = 0
    player.y = 100
    player.vy = 0
  end
end

function update_play()
  -- Horizontal movement
  local move = 0
  if test_input(0) > 0 or btn(0) > 0 then move = -1 end
  if test_input(1) > 0 or btn(1) > 0 then move = 1 end

  player.x += move * 1.5
  if player.x < 2 then player.x = 2 end
  if player.x > 122 then player.x = 122 end

  -- Gravity
  player.vy += 0.2
  player.y += player.vy

  -- Platform collision
  player.on_ground = false
  for plat in all(platforms) do
    if player.y + player.h <= plat.y + 2 and
       player.vy >= 0 and
       player.x + player.w > plat.x and
       player.x < plat.x + plat.w then
      player.y = plat.y - player.h
      player.vy = 0
      player.on_ground = true
      _log("jump")
    end
  end

  -- Jump
  if (test_input(4) > 0 or btnp(4) > 0) and player.on_ground then
    player.vy = -player.jump_power
    _log("jump_start")
  end

  -- Spike collision (death)
  for spike in all(spikes) do
    if player.x + player.w > spike.x and
       player.x < spike.x + spike.w and
       player.y + player.h > spike.y and
       player.y < spike.y + spike.h then
      _log("gameover:lose")
      state = "gameover"
      return
    end
  end

  -- Fall off bottom (death)
  if player.y > 128 then
    _log("gameover:lose")
    state = "gameover"
    return
  end

  -- Height tracking and scrolling
  if player.y < 80 then
    local scroll = 80 - player.y
    player.y = 80
    height += scroll
    max_height = max(max_height, height)
    score = flr(height / 10)

    -- Scroll platforms and spikes down
    for plat in all(platforms) do
      plat.y += scroll
    end
    for spike in all(spikes) do
      spike.y += scroll
    end

    -- Remove off-screen platforms and add new ones
    for i = #platforms, 1, -1 do
      if platforms[i].y > 140 then
        deli(platforms, i)
      end
    end
    while #platforms < 15 do
      local py = platforms[#platforms].y - 12
      local px = 20 + flr(rnd(70))
      local pw = 8 + flr(rnd(10))
      add(platforms, {x=px, y=py, w=pw, h=2, color=2})
    end

    -- Remove off-screen spikes and add new ones
    for i = #spikes, 1, -1 do
      if spikes[i].y > 140 then
        deli(spikes, i)
      end
    end
    while #spikes < 8 do
      local sy = spikes[#spikes].y - 18
      local sx = 15 + flr(rnd(98))
      add(spikes, {x=sx, y=sy, w=6, h=4, color=8})
    end
  end

  -- Win condition (reach height)
  if height >= 150 then
    _log("gameover:win")
    state = "gameover"
  end
end

function update_gameover()
  if test_input(4) > 0 or btnp(4) > 0 then
    _log("state:menu")
    state = "menu"
  end
end

function _update()
  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function draw_menu()
  cls(0)
  print("sky climb", 48, 20, 7)
  print("jump up through platforms", 20, 40, 5)
  print("reach the top to win!", 25, 50, 5)
  print("", 64, 70, 0)
  print("controls:", 45, 75, 3)
  print("arrow keys to move", 25, 85, 5)
  print("z or c to jump", 30, 95, 5)
  print("press o to start", 30, 110, 7)
end

function draw_play()
  cls(0)

  -- Draw platforms
  for plat in all(platforms) do
    rectfill(plat.x, plat.y, plat.x + plat.w - 1, plat.y + plat.h - 1, plat.color)
  end

  -- Draw spikes
  for spike in all(spikes) do
    rectfill(spike.x, spike.y, spike.x + spike.w - 1, spike.y + spike.h - 1, spike.color)
  end

  -- Draw player
  rectfill(player.x, player.y, player.x + player.w - 1, player.y + player.h - 1, 11)

  -- Draw HUD
  print("height: " .. score, 2, 2, 7)
end

function draw_gameover()
  cls(0)
  print("game over", 45, 30, 8)
  print("height: " .. score, 45, 50, 7)

  if state == "gameover" then
    -- Check if win or lose by checking max height
    if height >= 150 then
      print("you win!", 50, 65, 11)
    else
      print("you fell!", 48, 65, 8)
    end
  end

  print("press o to continue", 20, 100, 5)
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__label__
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
