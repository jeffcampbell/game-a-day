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
max_levels = 4
game_won = false
level_intro_timer = 0

-- player
player = {
  x = 64,
  y = 100,
  w = 8,
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

function create_level(lvl)
  platforms = {}
  enemies = {}
  collectibles = {}

  -- level 1: intro layout - basic platforming + 1 moving platform
  if lvl == 1 then
    -- create platforms
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=10, y=105, w=30, h=8, moving=false})
    add(platforms, {x=50, y=90, w=30, h=8, moving=false})
    add(platforms, {x=85, y=75, w=35, h=8, moving=false})
    add(platforms, {x=20, y=60, w=35, h=8, moving=true, vy=-0.5, ymin=50, ymax=70})
    add(platforms, {x=70, y=45, w=40, h=8, moving=false})
    add(platforms, {x=15, y=30, w=40, h=8, moving=false})
    add(platforms, {x=60, y=15, w=50, h=8, moving=false})

    -- create enemies (3 slow enemies)
    add(enemies, {x=50, y=85, w=8, h=8, vx=0.8, xmin=40, xmax=70, type="patrol", color=8})
    add(enemies, {x=80, y=70, w=8, h=8, vx=-0.8, xmin=75, xmax=100, type="patrol", color=8})
    add(enemies, {x=30, y=55, w=8, h=8, vx=0.8, xmin=20, xmax=50, type="patrol", color=8})

    -- create collectibles
    add(collectibles, {x=35, y=95, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=75, y=40, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=40, y=20, w=8, h=8, collected=false, color=11})

  -- level 2: tighter spacing, 2 moving platforms + vertical patrol enemy
  elseif lvl == 2 then
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=5, y=108, w=25, h=8, moving=false})
    add(platforms, {x=50, y=95, w=25, h=8, moving=true, vy=0.5, ymin=88, ymax=102})
    add(platforms, {x=90, y=82, w=30, h=8, moving=false})
    add(platforms, {x=15, y=70, w=30, h=8, moving=false})
    add(platforms, {x=70, y=57, w=35, h=8, moving=true, vy=-0.4, ymin=48, ymax=65})
    add(platforms, {x=25, y=42, w=35, h=8, moving=false})
    add(platforms, {x=75, y=28, w=40, h=8, moving=false})
    add(platforms, {x=20, y=12, w=35, h=8, moving=false})

    -- 4 enemies: 3 horizontal + 1 vertical patrol
    add(enemies, {x=45, y=90, w=8, h=8, vx=1.2, xmin=35, xmax=60, type="patrol", color=8})
    add(enemies, {x=85, y=77, w=8, h=8, vx=-1.2, xmin=70, xmax=100, type="patrol", color=8})
    add(enemies, {x=25, y=65, w=8, h=8, vx=1.2, xmin=15, xmax=45, type="patrol", color=8})
    add(enemies, {x=60, y=50, w=8, h=8, vy=0.6, ymin=42, ymax=65, type="vertical", color=7})

    -- more collectibles
    add(collectibles, {x=30, y=100, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=70, y=87, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=35, y=62, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=80, y=37, w=8, h=8, collected=false, color=11})

  -- level 3: complex layout, moving platform + jumping enemy + fast zapper enemies
  elseif lvl == 3 then
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=8, y=110, w=20, h=8, moving=false})
    add(platforms, {x=45, y=100, w=20, h=8, moving=true, vy=-0.6, ymin=90, ymax=108})
    add(platforms, {x=85, y=90, w=28, h=8, moving=false})
    add(platforms, {x=10, y=78, w=25, h=8, moving=false})
    add(platforms, {x=55, y=68, w=30, h=8, moving=false})
    add(platforms, {x=25, y=55, w=25, h=8, moving=false})
    add(platforms, {x=70, y=42, w=35, h=8, moving=false})
    add(platforms, {x=15, y=28, w=30, h=8, moving=false})
    add(platforms, {x=65, y=15, w=40, h=8, moving=false})

    -- 5 enemies: 4 fast + 1 jumping
    add(enemies, {x=50, y=95, w=8, h=8, vx=2.5, xmin=40, xmax=65, type="patrol", color=8})
    add(enemies, {x=85, y=85, w=8, h=8, vx=-2.5, xmin=70, xmax=100, type="patrol", color=8})
    add(enemies, {x=20, y=73, w=8, h=8, vx=1.5, xmin=10, xmax=35, type="jumping", jump_freq=40, ground_y=73, color=10})
    add(enemies, {x=65, y=63, w=8, h=8, vx=-1.5, xmin=50, xmax=80, type="patrol", color=8})
    add(enemies, {x=35, y=50, w=8, h=8, vx=2.5, xmin=25, xmax=45, type="patrol", color=8})

    -- many collectibles
    add(collectibles, {x=30, y=102, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=75, y=92, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=25, y=70, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=65, y=60, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=35, y=37, w=8, h=8, collected=false, color=11})

  -- level 4: final challenge - moving platforms + mixed enemy types
  elseif lvl == 4 then
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=12, y=108, w=18, h=8, moving=true, vx=0.8, xmin=5, xmax=25})
    add(platforms, {x=50, y=98, w=18, h=8, moving=false})
    add(platforms, {x=88, y=88, w=26, h=8, moving=true, vy=-0.7, ymin=78, ymax=95})
    add(platforms, {x=8, y=76, w=22, h=8, moving=false})
    add(platforms, {x=58, y=64, w=28, h=8, moving=true, vx=-0.9, xmin=45, xmax=70})
    add(platforms, {x=28, y=50, w=20, h=8, moving=false})
    add(platforms, {x=75, y=38, w=30, h=8, moving=false})
    add(platforms, {x=18, y=24, w=25, h=8, moving=false})
    add(platforms, {x=70, y=10, w=35, h=8, moving=false})

    -- 6 mixed enemies: 3 very fast + 2 jumping + 1 vertical
    add(enemies, {x=48, y=93, w=8, h=8, vx=2.8, xmin=38, xmax=62, type="patrol", color=8})
    add(enemies, {x=88, y=83, w=8, h=8, vx=-2.8, xmin=72, xmax=102, type="patrol", color=8})
    add(enemies, {x=15, y=71, w=8, h=8, vx=1.8, xmin=5, xmax=35, type="jumping", jump_freq=35, ground_y=71, color=10})
    add(enemies, {x=70, y=59, w=8, h=8, vy=-0.8, ymin=50, ymax=68, type="vertical", color=7})
    add(enemies, {x=35, y=45, w=8, h=8, vx=2.8, xmin=25, xmax=50, type="jumping", jump_freq=45, ground_y=45, color=10})
    add(enemies, {x=80, y=33, w=8, h=8, vx=-2.5, xmin=65, xmax=95, type="patrol", color=8})

    -- many collectibles
    add(collectibles, {x=32, y=100, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=72, y=90, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=20, y=68, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=65, y=56, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=40, y=42, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=28, y=16, w=8, h=8, collected=false, color=11})
  end
end

function init_game()
  level = 1
  score = 0
  lives = 3
  game_won = false
  start_level(level)
end

function start_level(lvl)
  player.x = 64
  player.y = 100
  player.vx = 0
  player.vy = 0
  player.jumping = false
  create_level(lvl)
  _log("level:"..lvl)
  level_intro_timer = 120  -- 2 seconds at 60fps
  state = "level_intro"
end

function update_menu()
  if btnp(4) or btnp(5) then
    _log("action:start_game")
    init_game()
  end
end

function update_level_intro()
  level_intro_timer -= 1
  if level_intro_timer <= 0 then
    _log("state:play")
    state = "play"
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

  -- update moving platforms
  for plat in all(platforms) do
    if plat.moving then
      if plat.vy then
        -- vertical moving platform
        plat.y += plat.vy
        if plat.y < plat.ymin or plat.y > plat.ymax then
          plat.vy *= -1
        end
      elseif plat.vx then
        -- horizontal moving platform
        plat.x += plat.vx
        if plat.x < plat.xmin or plat.x > plat.xmax then
          plat.vx *= -1
        end
      end
    end
  end

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
        -- player rides on moving platform
        if plat.moving then
          if plat.vy then player.y += plat.vy end
          if plat.vx then player.x += plat.vx end
        end
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
    if enemy.type == "vertical" then
      -- vertical patrol enemy
      enemy.y += enemy.vy
      if enemy.y < enemy.ymin or enemy.y > enemy.ymax then
        enemy.vy *= -1
      end
    elseif enemy.type == "jumping" then
      -- jumping enemy: patrol horizontally + jump periodically
      enemy.x += enemy.vx
      if enemy.x < enemy.xmin or enemy.x > enemy.xmax then
        enemy.vx *= -1
      end
      enemy.jump_timer = (enemy.jump_timer or 0) + 1
      if enemy.jump_timer > enemy.jump_freq then
        enemy.y -= 3
        enemy.jump_timer = 0
        _log("action:enemy_jump")
      else
        enemy.y = min(enemy.y + 0.15, enemy.ground_y)
      end
    else
      -- default horizontal patrol
      enemy.x += enemy.vx
      if enemy.x < enemy.xmin or enemy.x > enemy.xmax then
        enemy.vx *= -1
      end
    end
  end

  -- win condition: reach top
  if player.y < 5 then
    sfx(3)
    if level >= max_levels then
      game_won = true
      _log("gameover:win")
      state = "gameover"
    else
      level += 1
      _log("action:level_complete")
      start_level(level)
    end
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
  elseif state == "level_intro" then update_level_intro()
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
  print("4 challenging levels!", 30, 50, 3)
  print("arrow keys: move", 30, 70, 6)
  print("z/c: jump", 40, 80, 6)
  print("press z to start", 35, 100, 3)
end

function draw_play()
  cls(1)

  -- draw platforms
  for plat in all(platforms) do
    -- draw platform sprite (sprite 2) tiled across platform
    for px = plat.x, plat.x + plat.w - 1, 8 do
      spr(2, px, plat.y)
    end
  end

  -- draw collectibles
  for coll in all(collectibles) do
    if not coll.collected then
      spr(3, coll.x, coll.y)
    end
  end

  -- draw enemies
  for enemy in all(enemies) do
    spr(1, enemy.x, enemy.y)
  end

  -- draw player
  spr(0, player.x, player.y)

  -- draw ui
  print("score: "..score, 5, 5, 7)
  print("lives: "..lives, 5, 12, 7)
  print("lvl "..level, 110, 5, 7)
end

function draw_level_intro()
  cls(1)
  print("level "..level, 45, 50, 3)
  if level == 1 then
    print("master the basics!", 30, 70, 7)
  elseif level == 2 then
    print("things get tighter!", 30, 70, 7)
  elseif level == 3 then
    print("stay sharp!", 45, 70, 7)
  elseif level == 4 then
    print("final challenge!", 35, 70, 7)
  end
end

function draw_gameover()
  cls(1)
  if state == "gameover" then
    if game_won then
      print("you win!", 50, 40, 11)
      print("all 4 levels complete!", 25, 55, 3)
      print("score: "..score, 50, 70, 7)
    else
      print("game over", 45, 40, 8)
      print("reached level "..level, 35, 55, 7)
      print("score: "..score, 50, 70, 7)
    end
    print("press z to menu", 35, 85, 6)
  end
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "level_intro" then draw_level_intro()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00033300088800005555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333330088888805050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333330088888805555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03030330080808805050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33033330880888855555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33333330888888805050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03030330008888005555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03000330000000005050505000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

