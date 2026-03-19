pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- treasure cave: action-exploration game
-- collect treasures, avoid enemies and hazards

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

-- game state
state = "menu"
level = 1
lives = 3
treasures_collected = 0
treasures_total = 0

-- player
player = {x=10, y=10, w=6, h=6, vx=0, vy=0, speed=1.5}
player_dir = 1  -- 1=right, -1=left

-- enemies
enemies = {}
-- treasure items
treasures = {}
-- hazards
hazards = {}

-- level definitions
levels = {
  {treasures=3, enemies=2, hazards=3},
  {treasures=4, enemies=3, hazards=4},
  {treasures=4, enemies=4, hazards=5},
  {treasures=5, enemies=3, hazards=6}
}

function init_level(lv)
  treasures = {}
  enemies = {}
  hazards = {}
  player = {x=10, y=10, w=6, h=6, vx=0, vy=0, speed=1.5}
  player_dir = 1

  local ldef = levels[lv]
  treasures_total = ldef.treasures
  treasures_collected = 0

  -- spawn treasures at random positions
  for i=1,ldef.treasures do
    add(treasures, {x=20+rnd(100), y=20+rnd(90), collected=false})
  end

  -- spawn enemies
  for i=1,ldef.enemies do
    add(enemies, {x=40+rnd(60), y=30+rnd(70), w=5, h=5, vx=0.5, vy=0, dir=1})
  end

  -- spawn hazards
  for i=1,ldef.hazards do
    add(hazards, {x=rnd(128), y=50+rnd(40), w=8, h=4})
  end

  _log("level:"..lv)
end

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "play" then
    update_play()
  elseif state == "gameover" then
    update_gameover()
  end
end

function update_menu()
  if btnp(4) or btnp(5) then
    state = "play"
    level = 1
    lives = 3
    treasures_collected = 0
    init_level(level)
    _log("state:play")
  end
end

function update_play()
  -- player movement
  local move_x = 0
  if test_input(0) then move_x = -player.speed
  elseif test_input(1) then move_x = player.speed end

  local move_y = 0
  if test_input(2) then move_y = -player.speed
  elseif test_input(3) then move_y = player.speed end

  if move_x ~= 0 then player_dir = move_x > 0 and 1 or -1 end

  player.x += move_x
  player.y += move_y

  -- clamp player to screen
  player.x = max(0, min(122, player.x))
  player.y = max(0, min(122, player.y))

  -- collect treasures
  for t in all(treasures) do
    if not t.collected and collide(player, t) then
      t.collected = true
      treasures_collected += 1
      sfx(0)
      _log("treasure_collected:"..treasures_collected)
    end
  end

  -- update enemies
  for e in all(enemies) do
    -- simple AI: patrol back and forth, chase if player is nearby
    e.x += e.vx * e.dir

    -- bounce at edges
    if e.x < 0 or e.x > 120 then
      e.dir *= -1
    end

    -- check collision with player
    if collide(player, e) then
      lives -= 1
      sfx(1)
      _log("hit_enemy:"..lives)
      if lives <= 0 then
        state = "gameover"
        _log("gameover:lose")
      else
        -- reset player position
        player = {x=10, y=10, w=6, h=6, vx=0, vy=0, speed=1.5}
      end
    end
  end

  -- check hazards
  for h in all(hazards) do
    if collide(player, h) then
      lives -= 1
      sfx(1)
      _log("hit_hazard:"..lives)
      if lives <= 0 then
        state = "gameover"
        _log("gameover:lose")
      else
        player = {x=10, y=10, w=6, h=6, vx=0, vy=0, speed=1.5}
      end
    end
  end

  -- check level completion
  if treasures_collected >= treasures_total then
    if level >= 4 then
      state = "gameover"
      _log("gameover:win")
    else
      level += 1
      _log("level:"..level)
      init_level(level)
    end
  end
end

function update_gameover()
  if btnp(4) or btnp(5) then
    state = "menu"
    _log("state:menu")
  end
end

function collide(a, b)
  local bw = b.w or 8
  local bh = b.h or 8
  return a.x < b.x + bw and
         a.x + a.w > b.x and
         a.y < b.y + bh and
         a.y + a.h > b.y
end

function _draw()
  cls(0)

  if state == "menu" then
    draw_menu()
  elseif state == "play" then
    draw_play()
  elseif state == "gameover" then
    draw_gameover()
  end
end

function draw_menu()
  print("treasure cave", 35, 20, 7)
  print("collect all treasures", 20, 40, 5)
  print("avoid enemies & spikes", 16, 50, 5)
  print("3 lives to complete", 22, 60, 5)
  print("press z to start", 30, 80, 11)
end

function draw_play()
  -- draw treasures
  for t in all(treasures) do
    if not t.collected then
      spr(1, t.x, t.y)
    end
  end

  -- draw enemies
  for e in all(enemies) do
    spr(2, e.x, e.y)
  end

  -- draw hazards
  for h in all(hazards) do
    rectfill(h.x, h.y, h.x+h.w-1, h.y+h.h-1, 8)
  end

  -- draw player
  spr(0, player.x, player.y)

  -- draw UI
  print("lvl:"..level, 2, 2, 7)
  print("gold:"..treasures_collected.."/"..treasures_total, 40, 2, 7)
  print("lives:"..lives, 100, 2, 7)
end

function draw_gameover()
  if state == "gameover" then
    local won = treasures_collected >= treasures_total and level >= 4

    if won then
      print("you won!", 45, 40, 11)
      print("all treasures collected", 18, 55, 7)
    else
      print("game over", 42, 40, 8)
      print("out of lives", 40, 55, 7)
    end

    print("press z to restart", 25, 80, 5)
  end
end

__gfx__
00000000077700000c5500001d1d1d0008080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077770005555000001d1d100888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077770055555500001d1d100888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077700000055000001d1d1008880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__label__
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

__sfx__
000a00001e25023250272502d2502e2503025023250262502f2502d25000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500003835000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
