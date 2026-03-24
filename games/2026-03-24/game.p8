pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- tile tactics: turn-based strategy game
-- player controls a unit on an 8x8 grid, defeat all enemies to win

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0
testmode_curr_input = 0
testmode_prev_input = 0

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

function read_input()
  testmode_prev_input = testmode_curr_input
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    testmode_curr_input = test_inputs[test_input_idx] or 0
  else
    testmode_curr_input = btn()
  end
end

function test_btn(b)
  return (testmode_curr_input & (1 << b)) ~= 0
end

function test_btnp(b)
  local curr = test_btn(b)
  local prev = (testmode_prev_input & (1 << b)) ~= 0
  return curr and not prev
end

-- game state
state = "menu"
player = {x=1, y=1, hp=3}
enemies = {}
turn_count = 0
selected_x, selected_y = 1, 1
message = ""
message_timer = 0
difficulty = 1  -- 1=easy, 2=normal, 3=hard
score = 0
difficulty_select = 2  -- currently selected difficulty in menu

-- animation and effects
screen_shake = 0
flash_timer = 0
flash_color = 0
animation_frame = 0

-- map: 0=walkable, 1=obstacle
function init_map()
  local m = {}
  for y=0,7 do
    m[y] = {}
    for x=0,7 do
      m[y][x] = 0
    end
  end
  -- add some obstacles
  m[2][2] = 1
  m[2][3] = 1
  m[5][5] = 1
  m[5][6] = 1
  return m
end

function init_enemies()
  local e = {}
  if difficulty == 1 then  -- easy
    add(e, {x=6, y=0, hp=1})
    add(e, {x=7, y=3, hp=1})
  elseif difficulty == 2 then  -- normal
    add(e, {x=6, y=0, hp=1})
    add(e, {x=7, y=3, hp=1})
    add(e, {x=3, y=6, hp=1})
  else  -- hard
    add(e, {x=6, y=0, hp=2})
    add(e, {x=7, y=3, hp=1})
    add(e, {x=3, y=6, hp=1})
    add(e, {x=2, y=1, hp=1})
  end
  return e
end

function is_walkable(x, y, map)
  if x < 0 or x > 7 or y < 0 or y > 7 then
    return false
  end
  if map[y][x] == 1 then
    return false
  end
  -- check if enemy occupies tile
  for e in all(enemies) do
    if e.x == x and e.y == y then
      return false
    end
  end
  return true
end

function enemy_at(x, y)
  for e in all(enemies) do
    if e.x == x and e.y == y then
      return e
    end
  end
  return nil
end

function distance(x1, y1, x2, y2)
  return abs(x1-x2) + abs(y1-y2)
end

function move_towards_player(enemy, player, map)
  local best_dist = distance(enemy.x, enemy.y, player.x, player.y)
  local best_x, best_y = enemy.x, enemy.y

  -- try moving in each direction
  local moves = {{0,-1}, {0,1}, {-1,0}, {1,0}}
  for m in all(moves) do
    local nx, ny = enemy.x + m[1], enemy.y + m[2]
    if is_walkable(nx, ny, map) then
      local d = distance(nx, ny, player.x, player.y)
      if d < best_dist then
        best_dist = d
        best_x, best_y = nx, ny
      end
    end
  end

  enemy.x = best_x
  enemy.y = best_y
end

function update_menu()
  -- difficulty selection
  if test_btnp(0) then
    difficulty_select = max(1, difficulty_select - 1)
    sfx(1)
  elseif test_btnp(1) then
    difficulty_select = min(3, difficulty_select + 1)
    sfx(1)
  end

  if test_btnp(4) then  -- z button to start
    _log("state:play")
    _log("difficulty:"..difficulty_select)
    sfx(0)  -- menu confirm sound
    music(0)  -- start background music
    state = "play"
    difficulty = difficulty_select
    player = {x=1, y=1, hp=3}
    game_map = init_map()
    enemies = init_enemies()
    turn_count = 0
    score = 0
    selected_x, selected_y = 1, 1
  end
end

function update_play()
  -- update animations
  animation_frame = (animation_frame + 1) % 16

  -- decay effects
  if screen_shake > 0 then screen_shake -= 1 end
  if flash_timer > 0 then flash_timer -= 1 end

  -- player movement
  local old_x, old_y = player.x, player.y

  if test_btnp(0) and is_walkable(player.x-1, player.y, game_map) then
    player.x -= 1
    sfx(1)  -- movement sound
  elseif test_btnp(1) and is_walkable(player.x+1, player.y, game_map) then
    player.x += 1
    sfx(1)  -- movement sound
  elseif test_btnp(2) and is_walkable(player.x, player.y-1, game_map) then
    player.y -= 1
    sfx(1)  -- movement sound
  elseif test_btnp(3) and is_walkable(player.x, player.y+1, game_map) then
    player.y += 1
    sfx(1)  -- movement sound
  end

  -- attack adjacent enemy
  if test_btnp(4) then  -- z button
    local target = nil
    for e in all(enemies) do
      if distance(player.x, player.y, e.x, e.y) == 1 then
        target = e
        break
      end
    end
    if target then
      target.hp -= 1
      sfx(2)  -- attack sound
      screen_shake = 3
      flash_timer = 4
      flash_color = 8
      _log("attack:"..target.x..","..target.y)
      if target.hp <= 0 then
        del(enemies, target)
        _log("enemy_defeated")
        sfx(4)  -- damage/defeat sound
      end
    end
  end

  if player.x ~= old_x or player.y ~= old_y then
    _log("move:"..player.x..","..player.y)
  end

  -- enemy turn
  for e in all(enemies) do
    if distance(e.x, e.y, player.x, player.y) == 1 then
      -- attack player
      player.hp -= 1
      sfx(3)  -- enemy attack sound
      flash_timer = 6
      flash_color = 8
      screen_shake = 4
      _log("enemy_hit")
    else
      -- move towards player
      move_towards_player(e, player, game_map)
    end
  end

  turn_count += 1

  -- check win/lose
  if #enemies == 0 then
    _log("gameover:win")
    score = 100 + (player.hp * 50) + (300 / max(1, turn_count))
    _log("score:"..flr(score))
    sfx(5)  -- victory sound
    music()  -- stop music
    state = "gameover"
    message = "victory!"
  elseif player.hp <= 0 then
    _log("gameover:lose")
    sfx(5)  -- defeat sound
    music()  -- stop music
    state = "gameover"
    message = "defeated!"
  end
end

function update_gameover()
  if test_btnp(4) then  -- z to restart
    _log("state:menu")
    music()  -- stop music
    state = "menu"
  end
end

function _update()
  read_input()
  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function draw_menu()
  cls(0)

  -- title with styling
  print("========", 40, 10, 5)
  print("tile tactics", 38, 18, 11)
  print("========", 40, 26, 5)

  -- subtitle
  print("turn-based strategy", 28, 35, 7)
  print("defeat all enemies to win", 19, 45, 3)

  -- difficulty selection with styling
  local diff_colors = {3, 7, 8}
  local diff_names = {"easy", "normal", "hard"}
  local y_pos = 65

  print("select difficulty:", 26, 55, 7)

  for i=1,3 do
    local col = diff_colors[i]
    if i == difficulty_select then
      col = 11  -- highlight selected
      print("[>]", 33, y_pos, col)
    else
      print("[ ]", 33, y_pos, col)
    end
    print(diff_names[i], 46, y_pos, col)
    y_pos += 8
  end

  print("press z to start", 28, 110, 5)
end

function draw_grid(offset_x, offset_y, tile_size)
  for y=0,7 do
    for x=0,7 do
      local px = offset_x + x * tile_size
      local py = offset_y + y * tile_size

      -- draw tile background with checkerboard pattern
      local tile_color = 1
      if (x + y) % 2 == 0 then
        tile_color = 2
      end
      rectfill(px, py, px+tile_size-1, py+tile_size-1, tile_color)

      -- draw tile
      if game_map[y][x] == 1 then
        -- obstacle sprite with shading
        spr(3, px, py)
        rectfill(px, py, px+tile_size-1, py+tile_size-1, 0)
      else
        -- walkable tile border
        rect(px, py, px+tile_size-1, py+tile_size-1, 5)
      end
    end
  end
end

function draw_attack_range(offset_x, offset_y, tile_size)
  -- show valid attack tiles with pulse effect
  for y=0,7 do
    for x=0,7 do
      if distance(player.x, player.y, x, y) == 1 then
        local px = offset_x + x * tile_size
        local py = offset_y + y * tile_size
        -- draw attack range indicator with alternating visibility for pulse
        local pulse = (animation_frame / 4) % 2 < 1 and 11 or 5
        rect(px+1, py+1, px+tile_size-2, py+tile_size-2, pulse)
      end
    end
  end
end

function draw_units(offset_x, offset_y, tile_size)
  -- player with sprite and glow effect
  local px = offset_x + player.x * tile_size
  local py = offset_y + player.y * tile_size

  -- player glow
  circfill(px + 4, py + 4, 6, 5)
  spr(0, px, py)

  -- player hp indicator with background
  if player.hp > 0 then
    rectfill(px + 4, py - 4, px + 10, py, 0)
    print(player.hp, px + 5, py - 3, 11)
  end

  -- enemies
  for e in all(enemies) do
    local ex = offset_x + e.x * tile_size
    local ey = offset_y + e.y * tile_size

    -- alternate enemy sprites
    local enemy_sprite = 1 + ((e.x + e.y) % 2)

    -- enemy glow
    circfill(ex + 4, ey + 4, 5, 8)
    spr(enemy_sprite, ex, ey)

    -- enemy hp indicator with background
    if e.hp > 0 then
      rectfill(ex + 4, ey - 4, ex + 10, ey, 0)
      print(e.hp, ex + 5, ey - 3, 8)
    end

    -- show threat range (where enemies can attack) with animation
    if distance(e.x, e.y, player.x, player.y) == 1 then
      local tx = offset_x + e.x * tile_size
      local ty = offset_y + e.y * tile_size
      rect(tx, ty, tx+tile_size-1, ty+tile_size-1, 8)
      rect(tx+1, ty+1, tx+tile_size-2, ty+tile_size-2, 8)
    end
  end
end

function draw_play()
  cls(0)

  local tile_size = 10
  local offset_x = 8
  local offset_y = 8

  -- apply screen shake
  if screen_shake > 0 then
    offset_x += rnd(3) - 1
    offset_y += rnd(3) - 1
  end

  draw_grid(offset_x, offset_y, tile_size)
  draw_attack_range(offset_x, offset_y, tile_size)
  draw_units(offset_x, offset_y, tile_size)

  -- flash effect
  if flash_timer > 0 then
    local alpha = max(1, flash_timer / 3)
    rectfill(0, 0, 127, 127, flash_color)
  end

  -- ui background panel
  rectfill(0, 104, 127, 127, 1)
  rect(0, 103, 127, 127, 5)

  -- ui panel with better visuals
  local diff_col = 7
  if difficulty == 1 then diff_col = 3
  elseif difficulty == 3 then diff_col = 8 end

  -- draw ui elements with separators
  print("arrows:move", 2, 109, 7)
  print("z:attack", 60, 109, 11)

  print("turn:", 2, 119, 5)
  print(turn_count, 20, 119, 5)
  print("hp:", 30, 119, 11)
  print(player.hp, 40, 119, 11)
  print("foes:", 48, 119, 8)
  print(#enemies, 65, 119, 8)
  print("d"..difficulty, 75, 119, diff_col)
end

function draw_gameover()
  cls(0)

  -- game over title
  print("=============", 34, 15, 5)
  print("   game over   ", 33, 23, 7)
  print("=============", 34, 31, 5)

  if message == "victory!" then
    print("*** victory! ***", 32, 45, 3)
    rectfill(25, 60, 102, 80, 1)
    rect(25, 60, 102, 80, 3)
    print("score:", 35, 65, 11)
    print(flr(score), 65, 65, 11)

    -- bonus display
    local bonus_text = "+"..max(50, player.hp * 50).." for hp"
    print(bonus_text, 30, 75, 3)
  else
    print("*** defeated! ***", 31, 45, 8)
    rectfill(20, 60, 107, 80, 1)
    rect(20, 60, 107, 80, 8)
    print("enemies remaining:", 25, 70, 8)
    print(#enemies, 85, 70, 8)
  end

  print("press z to menu", 30, 110, 5)
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00033000007700000055500001111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00333300077777005555550011111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333330777777755555555111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03333330777777755555555111111111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00333300077777705555555011111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030300007700000055500001111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010100000000000000000000111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000e000012350f3350123400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000153501335010350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600000c3500b35003350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000093500833006350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000071a3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001e0007183501c3501535010350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
331c241c241c241c301c301c301c3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
41 06ffffff

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
