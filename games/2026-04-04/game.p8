pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- penguin slide - navigate icy platforms and collect fish!

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function _capture()
  if testmode then add(test_log, "SCREEN:"..tostr(stat(0))) end
end

function test_input(b)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn()
end

-- game state machine
state = "menu"
score = 0
lives = 3
level = 1
camera_x = 0

-- player
px, py = 10, 100
pw, ph = 4, 6
pspeed_x = 0
pspeed_y = 0
pgrounded = false
pdir = 1  -- 1 = right, -1 = left

-- platforms and obstacles
platforms = {}
fish = {}
spikes = {}
exit_portal = {}

-- platform structure: {x, y, w, h}
function init_level(lv)
  _log("level:"..lv)
  platforms = {}
  fish = {}
  spikes = {}

  -- level 1: basic tutorial level
  if lv == 1 then
    -- ground
    add(platforms, {0, 120, 128, 8})
    -- stepping stones
    add(platforms, {10, 108, 20, 4})
    add(platforms, {40, 100, 20, 4})
    add(platforms, {70, 95, 20, 4})
    add(platforms, {100, 100, 20, 4})
    -- upper path
    add(platforms, {20, 80, 25, 4})
    add(platforms, {55, 70, 25, 4})
    add(platforms, {85, 75, 30, 4})

    -- fish to collect
    add(fish, {25, 75})
    add(fish, {60, 60})
    add(fish, {100, 65})
    add(fish, {35, 90})

    -- obstacles
    add(spikes, {30, 115})
    add(spikes, {65, 108})
    add(spikes, {90, 110})

    -- exit
    exit_portal = {110, 70, 10}
  else
    -- level 2: harder
    add(platforms, {0, 120, 128, 8})
    add(platforms, {5, 105, 18, 3})
    add(platforms, {28, 98, 15, 3})
    add(platforms, {48, 90, 15, 3})
    add(platforms, {68, 85, 18, 3})
    add(platforms, {90, 95, 20, 3})

    add(platforms, {15, 70, 20, 3})
    add(platforms, {40, 65, 18, 3})
    add(platforms, {65, 60, 20, 3})

    add(fish, {20, 65})
    add(fish, {45, 58})
    add(fish, {70, 55})
    add(fish, {95, 90})
    add(fish, {12, 100})

    add(spikes, {25, 115})
    add(spikes, {50, 115})
    add(spikes, {75, 115})
    add(spikes, {38, 103})
    add(spikes, {60, 95})

    exit_portal = {110, 55, 10}
  end

  _log("init_level:done")
  px = 5
  py = 115
  pspeed_x = 0
  pspeed_y = 0
end

function update_menu()
  if btnp(4) then  -- z button
    _log("state:play")
    state = "play"
    score = 0
    lives = 3
    level = 1
    init_level(level)
  end
end

function update_play()
  -- horizontal movement
  local input_x = 0
  if test_input(0) then input_x = -1 end
  if test_input(1) then input_x = 1 end

  pspeed_x = input_x * 2.5
  if input_x != 0 then pdir = input_x end

  px += pspeed_x

  -- gravity
  pspeed_y += 0.3
  py += pspeed_y

  -- jumping
  if pgrounded and test_input(4) then
    pspeed_y = -3
    _log("action:jump")
    pgrounded = false
  end

  -- collision with platforms
  pgrounded = false
  for plat in all(platforms) do
    local px0 = plat[1]
    local py0 = plat[2]
    local pw = plat[3]
    local ph = plat[4]

    if px + pw > px0 and px < px0 + pw and
       py + ph > py0 and py < py0 + ph then
      if pspeed_y > 0 then  -- landing
        py = py0 - ph
        pspeed_y = 0
        pgrounded = true
      end
    end
  end

  -- collect fish
  for i, f in ipairs(fish) do
    if abs(px - f[1]) < 8 and abs(py - f[2]) < 8 then
      _log("action:fish_collected")
      score += 10
      f[1] = -100  -- move off screen
    end
  end

  -- collision with spikes
  for spike in all(spikes) do
    if abs(px - spike[1]) < 6 and abs(py - spike[2]) < 6 then
      _log("action:hit_spike")
      lives -= 1
      px = 5
      py = 115
      pspeed_y = 0
      if lives <= 0 then
        _log("state:gameover")
        _log("result:lose")
        state = "gameover"
      end
    end
  end

  -- check exit
  if exit_portal and
     abs(px - exit_portal[1]) < 8 and
     abs(py - exit_portal[2]) < 8 then
    if level < 2 then
      _log("action:level_up")
      level += 1
      score += 50
      init_level(level)
    else
      _log("state:gameover")
      _log("result:win")
      state = "gameover"
    end
  end

  -- bounds check
  if py > 128 then
    _log("action:fell_off")
    lives -= 1
    px = 5
    py = 115
    pspeed_y = 0
    if lives <= 0 then
      _log("state:gameover")
      _log("result:lose")
      state = "gameover"
    end
  end

  if px < -10 or px > 138 then
    px = mid(-10, px, 138)
  end
end

function update_gameover()
  if btnp(4) then
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
  cls(1)
  print("penguin slide", 32, 20, 7)
  print("navigate icy platforms", 18, 35, 6)
  print("collect fish to score", 20, 45, 6)
  print("reach the goal!", 32, 55, 6)

  print("controls:", 40, 75, 7)
  print("left/right: move", 26, 85, 6)
  print("z: jump", 42, 95, 6)

  if flr(t() * 2) % 2 == 0 then
    print("press z to start", 24, 110, 7)
  end

  -- draw penguin sprite on menu
  spr(1, 55, 30)
end

function draw_play()
  cls(1)

  -- draw level label
  print("level "..level, 2, 2, 7)
  print("score: "..score, 70, 2, 7)
  print("lives: "..lives, 95, 2, 7)

  -- draw platforms
  for plat in all(platforms) do
    rectfill(plat[1], plat[2], plat[1]+plat[3]-1, plat[2]+plat[4]-1, 3)
  end

  -- draw fish
  for f in all(fish) do
    spr(2, f[1]-2, f[2]-2)
  end

  -- draw spikes
  for spike in all(spikes) do
    spr(3, spike[1]-2, spike[2]-2)
  end

  -- draw exit
  if exit_portal then
    spr(4, exit_portal[1]-2, exit_portal[2]-5)
  end

  -- draw player
  spr(1, px-2, py-2)

  -- draw instruction
  print("jump: z", 2, 120, 7)
end

function draw_gameover()
  cls(1)

  if state == "gameover" then
    local win_state = false
    for log in all(test_log or {}) do
      if log == "result:win" then win_state = true end
    end

    if win_state then
      print("you win!", 45, 40, 11)
      print("final score: "..score, 30, 60, 7)
    else
      print("game over", 40, 40, 8)
      print("score: "..score, 42, 60, 7)
    end
  end

  print("press z to return to menu", 14, 100, 7)
end

function _draw()
  cls()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00000000007cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000776770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000767770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000776770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000069600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000696900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800080080088008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0088000086880008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0080080088008880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000088008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000088008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000088888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000008888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a0a00000000000070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0a0a0000000000770770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a0a0a007777070707007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0a0a0070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a0a00007777070070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000770077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100100000f000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0111111007777700070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0111111007707770707070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0111111007707770070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0011110007070700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00110000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
