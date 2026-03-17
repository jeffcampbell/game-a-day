pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- platformer: reach the top!
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
score = 0
lives = 3
level = 1
game_won = false

-- player
player = {
  x = 64,
  y = 100,
  w = 6,
  h = 8,
  vx = 0,
  vy = 0,
  jumping = false,
  color = 3
}

-- physics
gravity = 0.2
jump_power = 5
max_fall = 4
move_speed = 1.5

-- platforms
platforms = {}
enemies = {}
collectibles = {}

function create_level()
  platforms = {}
  enemies = {}
  collectibles = {}

  -- create platforms
  add(platforms, {x=0, y=120, w=128, h=8, moving=false})  -- floor
  add(platforms, {x=10, y=105, w=30, h=6, moving=false})
  add(platforms, {x=50, y=90, w=30, h=6, moving=false})
  add(platforms, {x=85, y=75, w=35, h=6, moving=false})
  add(platforms, {x=20, y=60, w=35, h=6, moving=false})
  add(platforms, {x=70, y=45, w=40, h=6, moving=false})
  add(platforms, {x=15, y=30, w=40, h=6, moving=false})
  add(platforms, {x=60, y=15, w=50, h=6, moving=false})

  -- create enemies
  add(enemies, {x=50, y=85, w=6, h=6, vx=1, xmin=40, xmax=70, color=8})
  add(enemies, {x=80, y=70, w=6, h=6, vx=-1, xmin=75, xmax=100, color=8})
  add(enemies, {x=30, y=55, w=6, h=6, vx=1, xmin=20, xmax=50, color=8})

  -- create collectibles
  add(collectibles, {x=35, y=95, w=4, h=4, collected=false, color=11})
  add(collectibles, {x=75, y=40, w=4, h=4, collected=false, color=11})
  add(collectibles, {x=40, y=20, w=4, h=4, collected=false, color=11})
end

function init_game()
  player.x = 64
  player.y = 100
  player.vx = 0
  player.vy = 0
  player.jumping = false
  score = 0
  lives = 3
  game_won = false
  create_level()
  _log("state:play")
  _log("level:"..level)
  state = "play"
end

function update_menu()
  if btnp(4) or btnp(5) then
    _log("action:start_game")
    init_game()
  end
end

function update_play()
  -- player movement
  if test_input(0) then -- left
    player.vx = -move_speed
  elseif test_input(1) then -- right
    player.vx = move_speed
  else
    player.vx = 0
  end

  -- jumping
  if test_input(4) and not player.jumping then
    player.vy = -jump_power
    player.jumping = true
    sfx(0)
    _log("action:jump")
  end

  -- apply gravity
  player.vy = min(player.vy + gravity, max_fall)

  -- update position
  player.x += player.vx
  player.y += player.vy

  -- boundary check
  if player.x < 0 then player.x = 0 end
  if player.x + player.w > 128 then player.x = 128 - player.w end

  -- platform collision
  local on_platform = false
  for plat in all(platforms) do
    if collide_rect(player.x, player.y + player.h, player.w, 1,
                    plat.x, plat.y, plat.w, plat.h) then
      if player.vy >= 0 then
        player.y = plat.y - player.h
        player.vy = 0
        player.jumping = false
        on_platform = true
      end
    end
  end

  -- enemy collision
  for enemy in all(enemies) do
    if collide_rect(player.x, player.y, player.w, player.h,
                    enemy.x, enemy.y, enemy.w, enemy.h) then
      lives -= 1
      _log("action:hit_enemy")
      sfx(2)
      if lives <= 0 then
        _log("gameover:lose")
        state = "gameover"
      else
        player.x = 64
        player.y = 100
        player.vy = 0
      end
    end
  end

  -- collectible collision
  for coll in all(collectibles) do
    if not coll.collected and
       collide_rect(player.x, player.y, player.w, player.h,
                    coll.x, coll.y, coll.w, coll.h) then
      coll.collected = true
      score += 10
      sfx(1)
      _log("action:collect")
    end
  end

  -- update enemies
  for enemy in all(enemies) do
    enemy.x += enemy.vx
    if enemy.x < enemy.xmin or enemy.x > enemy.xmax then
      enemy.vx *= -1
    end
  end

  -- win condition: reach top
  if player.y < 5 then
    game_won = true
    _log("gameover:win")
    state = "gameover"
    sfx(3)
  end

  -- fall off bottom
  if player.y > 128 then
    lives -= 1
    _log("action:fell_off")
    if lives <= 0 then
      _log("gameover:lose")
      state = "gameover"
    else
      player.x = 64
      player.y = 100
      player.vy = 0
    end
  end
end

function update_gameover()
  if btnp(4) or btnp(5) then
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

function collide_rect(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 < x2 + w2 and x1 + w1 > x2 and
         y1 < y2 + h2 and y1 + h1 > y2
end

function draw_menu()
  cls(1)
  print("platformer", 50, 40, 7)
  print("reach the top!", 40, 50, 7)
  print("arrow keys: move", 30, 70, 6)
  print("z/c: jump", 40, 80, 6)
  print("press z to start", 35, 100, 3)
end

function draw_play()
  cls(1)

  -- draw platforms
  for plat in all(platforms) do
    rectfill(plat.x, plat.y, plat.x + plat.w - 1, plat.y + plat.h - 1, 5)
  end

  -- draw collectibles
  for coll in all(collectibles) do
    if not coll.collected then
      circfill(coll.x + 2, coll.y + 2, 2, coll.color)
    end
  end

  -- draw enemies
  for enemy in all(enemies) do
    rectfill(enemy.x, enemy.y, enemy.x + enemy.w - 1,
             enemy.y + enemy.h - 1, enemy.color)
  end

  -- draw player
  rectfill(player.x, player.y, player.x + player.w - 1,
           player.y + player.h - 1, player.color)

  -- draw ui
  print("score: "..score, 5, 5, 7)
  print("lives: "..lives, 5, 12, 7)
  print("lvl "..level, 110, 5, 7)
end

function draw_gameover()
  cls(1)
  if state == "gameover" then
    if game_won then
      print("you win!", 50, 40, 11)
      print("score: "..score, 50, 55, 7)
    else
      print("game over", 45, 40, 8)
      print("final score: "..score, 40, 55, 7)
    end
    print("press z to menu", 35, 85, 6)
  end
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

__sfx__
010a00002254325532553255302553255325532553255302553255325532553255302553255325532553255302553255325532553255302553255325532553255302553255325532553255302553255325532553255
010a00003654300034503000400000003650365036500340034003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00001c4320432204322043220432114322043200432000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a000050050505300505053004050505300505053005050505300505053004050505300505053005050505300505053004050505300505053005050505300505053004050505300505053005050505300505053

__music__
00 00000000

