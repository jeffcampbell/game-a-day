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
  add(e, {x=6, y=0, hp=1})
  add(e, {x=7, y=3, hp=1})
  add(e, {x=3, y=6, hp=1})
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
  if test_btnp(4) then  -- z button
    _log("state:play")
    state = "play"
    player = {x=1, y=1, hp=3}
    game_map = init_map()
    enemies = init_enemies()
    turn_count = 0
    selected_x, selected_y = 1, 1
  end
end

function update_play()
  -- player movement
  local old_x, old_y = player.x, player.y

  if test_btnp(0) and is_walkable(player.x-1, player.y, game_map) then
    player.x -= 1
  elseif test_btnp(1) and is_walkable(player.x+1, player.y, game_map) then
    player.x += 1
  elseif test_btnp(2) and is_walkable(player.x, player.y-1, game_map) then
    player.y -= 1
  elseif test_btnp(3) and is_walkable(player.x, player.y+1, game_map) then
    player.y += 1
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
      _log("attack:"..target.x..","..target.y)
      if target.hp <= 0 then
        del(enemies, target)
        _log("enemy_defeated")
      end
    end
  end

  if player.x ~= old_x or player.y ~= old_y then
    _log("move:"..player.x..","..player.y)
    -- check if player moved onto enemy (shouldn't happen with walkability check)
  end

  -- enemy turn
  for e in all(enemies) do
    if distance(e.x, e.y, player.x, player.y) == 1 then
      -- attack player
      player.hp -= 1
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
    state = "gameover"
    message = "victory!"
  elseif player.hp <= 0 then
    _log("gameover:lose")
    state = "gameover"
    message = "defeated!"
  end
end

function update_gameover()
  if test_btnp(4) then  -- z to restart
    _log("state:menu")
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
  print("tile tactics", 40, 20, 7)
  print("turn-based strategy", 28, 35, 7)
  print("", 0, 50, 0)
  print("defeat all enemies", 25, 55, 3)
  print("press z to start", 30, 70, 7)
end

function draw_grid(offset_x, offset_y, tile_size)
  for y=0,7 do
    for x=0,7 do
      local px = offset_x + x * tile_size
      local py = offset_y + y * tile_size

      -- draw tile
      if game_map[y][x] == 1 then
        rectfill(px, py, px+tile_size-1, py+tile_size-1, 5)
      else
        rect(px, py, px+tile_size-1, py+tile_size-1, 8)
      end
    end
  end
end

function draw_units(offset_x, offset_y, tile_size)
  -- player
  local px = offset_x + player.x * tile_size + 3
  local py = offset_y + player.y * tile_size + 3
  circfill(px, py, 2, 11)
  print(player.hp, px-2, py-4, 7)

  -- enemies
  for e in all(enemies) do
    local ex = offset_x + e.x * tile_size + 3
    local ey = offset_y + e.y * tile_size + 3
    circfill(ex, ey, 2, 8)
    print(e.hp, ex-2, ey-4, 7)
  end
end

function draw_play()
  cls(0)

  local tile_size = 10
  local offset_x = 8
  local offset_y = 8

  draw_grid(offset_x, offset_y, tile_size)
  draw_units(offset_x, offset_y, tile_size)

  -- ui panel
  print("turn: "..turn_count, 2, 110, 7)
  print("hp: "..player.hp, 40, 110, 11)
  print("enemies: "..#enemies, 70, 110, 8)

  print("arrows:move  z:attack", 2, 120, 5)
end

function draw_gameover()
  cls(0)
  print("game over", 45, 40, 7)
  if message == "victory!" then
    print(message, 48, 55, 3)
  else
    print(message, 48, 55, 8)
  end
  print("press z to menu", 30, 75, 7)
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
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff