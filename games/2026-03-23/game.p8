pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

-- tile match puzzle - 2026-03-23
-- gravity-based tile matching game

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
  return btn()
end

-- wrapper for btn() style button checks
function test_btn(b)
  return band(curr_btn, shl(1, b)) > 0
end

-- wrapper for btnp() style button presses
function test_btnp(b)
  return band(curr_btn, shl(1, b)) > 0 and not band(prev_btn, shl(1, b)) > 0
end

-- game state
state = "menu"
score = 0
level = 1
game_time = 0
spawn_counter = 0
spawn_rate = 30  -- decrease over time for difficulty
combo = 0  -- combo counter
screen_shake = 0  -- screen shake effect
flash_time = 0  -- screen flash effect

-- button state caching for test_input integration
curr_btn = 0
prev_btn = 0

-- grid constants
grid_w = 8
grid_h = 12
tile_size = 8
grid_x = (128 - grid_w * tile_size) / 2
grid_y = 8

-- grid data: 0 = empty, 1-5 = tile colors
grid = {}
falling_tiles = {}  -- falling tile instances

-- tile colors: red, orange, yellow, green, light blue
tile_colors = {8, 9, 10, 11, 12}

-- initialize grid
function init_game()
  grid = {}
  falling_tiles = {}
  score = 0
  level = 1
  game_time = 0
  spawn_counter = 0
  spawn_rate = 30
  combo = 0
  screen_shake = 0
  flash_time = 0

  for y = 1, grid_h do
    grid[y] = {}
    for x = 1, grid_w do
      grid[y][x] = 0
    end
  end

  _log("state:play")
  _log("game:initialized")
end

-- spawn new falling tile at top
function spawn_tile()
  local tile = {
    x = flr(rnd(grid_w)) + 1,
    y = 1,
    col = tile_colors[flr(rnd(5)) + 1]
  }
  add(falling_tiles, tile)
  _log("tile:spawn:" .. tile.x)
end

-- apply gravity to falling tiles
function update_gravity()
  for i = #falling_tiles, 1, -1 do
    local tile = falling_tiles[i]

    -- check if tile can fall
    if tile.y >= grid_h or grid[tile.y + 1][tile.x] ~= 0 then
      -- place in grid
      grid[tile.y][tile.x] = tile.col
      del(falling_tiles, tile)
      _log("tile:placed:" .. tile.x .. "," .. tile.y)
    else
      -- fall down
      tile.y += 1
    end
  end
end

-- detect and clear matching lines
function clear_matches()
  local cleared = {}
  local to_clear = {}

  -- check horizontal matches
  for y = 1, grid_h do
    local x = 1
    while x <= grid_w do
      if grid[y][x] ~= 0 then
        local col = grid[y][x]
        local match_len = 1
        local start_x = x

        while x + match_len <= grid_w and grid[y][x + match_len] == col do
          match_len += 1
        end

        if match_len >= 3 then
          for i = 0, match_len - 1 do
            local key = (start_x + i) .. "," .. y
            to_clear[key] = true
          end
        end
        x += match_len
      else
        x += 1
      end
    end
  end

  -- check vertical matches
  for x = 1, grid_w do
    local y = 1
    while y <= grid_h do
      if grid[y][x] ~= 0 then
        local col = grid[y][x]
        local match_len = 1
        local start_y = y

        while y + match_len <= grid_h and grid[y + match_len][x] == col do
          match_len += 1
        end

        if match_len >= 3 then
          for i = 0, match_len - 1 do
            local key = x .. "," .. (start_y + i)
            to_clear[key] = true
          end
        end
        y += match_len
      else
        y += 1
      end
    end
  end

  -- clear marked tiles
  local clear_count = 0
  for key, _ in pairs(to_clear) do
    local parts = {}
    for part in key:gmatch("[^,]+") do
      add(parts, tonumber(part))
    end
    local x, y = parts[1], parts[2]
    if grid[y][x] ~= 0 then
      grid[y][x] = 0
      clear_count += 1
    end
  end

  if clear_count > 0 then
    combo += 1
    local score_gain = clear_count * 10 * combo
    score += score_gain
    screen_shake = 2
    flash_time = 4
    _log("match:detected:" .. clear_count)
    _log("combo:" .. combo)
    _log("score_gained:" .. score_gain)
    sfx(0)  -- play clear sound
  else
    combo = 0
  end

  return clear_count > 0
end

-- apply gravity to settled tiles after clearing
function settle_tiles()
  local changed = true
  while changed do
    changed = false
    for y = grid_h, 2, -1 do
      for x = 1, grid_w do
        if grid[y][x] == 0 and grid[y - 1][x] ~= 0 then
          grid[y][x] = grid[y - 1][x]
          grid[y - 1][x] = 0
          changed = true
        end
      end
    end
  end
end

-- check if game is over (tiles reach top)
function check_game_over()
  for x = 1, grid_w do
    if grid[2][x] ~= 0 then
      return true
    end
  end
  return false
end

function update_menu()
  if test_btnp(4) or test_btnp(5) then  -- z or x
    _log("action:start_game")
    init_game()
    state = "play"
  end
end

function update_play()
  game_time += 1

  -- update screen effects
  if screen_shake > 0 then screen_shake -= 1 end
  if flash_time > 0 then flash_time -= 1 end

  -- level progression
  local target_level = flr(score / 200) + 1
  if target_level > level then
    level = target_level
    _log("level:up:" .. level)
    sfx(2)  -- level up sound
  end

  -- difficulty ramp
  if game_time % 600 == 0 then  -- every 10 seconds
    spawn_rate = max(10, spawn_rate - 2)
    _log("difficulty:ramp:" .. spawn_rate)
  end

  -- spawn tiles
  spawn_counter += 1
  if spawn_counter >= spawn_rate then
    spawn_tile()
    spawn_counter = 0
  end

  -- update gravity
  update_gravity()

  -- clear matches and settle
  local cleared = true
  while cleared do
    cleared = clear_matches()
    if cleared then
      settle_tiles()
    end
  end

  -- check game over
  if check_game_over() then
    state = "gameover"
    _log("state:gameover")
    _log("final_score:" .. score)
    _log("level_reached:" .. level)
    sfx(1)  -- game over sound
  end
end

function update_gameover()
  if test_btnp(4) or test_btnp(5) then  -- z or x
    _log("action:return_to_menu")
    state = "menu"
    _log("state:menu")
  end
end

function _update()
  prev_btn = curr_btn
  curr_btn = test_input(0)

  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function draw_tile(x, y, col)
  if col ~= 0 then
    -- draw filled rectangle for tile
    fillp()
    rectfill(x, y, x + tile_size - 1, y + tile_size - 1, col)
    -- highlight top-left for depth
    pset(x, y, 7)
    pset(x + 1, y, 7)
    pset(x, y + 1, 7)
    -- shadow bottom-right for depth
    pset(x + tile_size - 1, y + tile_size - 1, 1)
    pset(x + tile_size - 2, y + tile_size - 1, 1)
    pset(x + tile_size - 1, y + tile_size - 2, 1)
  end
end

function draw_menu()
  cls(1)

  -- title
  print("tile", 52, 20, 7)
  print("match", 47, 28, 10)
  print("puzzle", 48, 36, 12)

  -- instructions
  print("match 3+ tiles", 26, 55, 11)
  print("to clear them", 30, 62, 11)

  print("spawn gets faster", 20, 75, 7)
  print("score increases levels", 16, 82, 7)

  print("press z to start", 27, 100, 10)

  _log("state:menu")
end

function draw_play()
  cls(0)

  -- apply screen shake offset
  local shake_x = 0
  local shake_y = 0
  if screen_shake > 0 then
    shake_x = rnd(3) - 1
    shake_y = rnd(3) - 1
  end

  -- draw grid background
  local gx = grid_x + shake_x
  local gy = grid_y + shake_y
  rectfill(gx - 1, gy - 1, gx + grid_w * tile_size,
           gy + grid_h * tile_size, 5)

  -- draw settled tiles
  for y = 1, grid_h do
    for x = 1, grid_w do
      local px = gx + (x - 1) * tile_size
      local py = gy + (y - 1) * tile_size
      draw_tile(px, py, grid[y][x])
    end
  end

  -- draw falling tiles
  for tile in all(falling_tiles) do
    local px = gx + (tile.x - 1) * tile_size
    local py = gy + (tile.y - 1) * tile_size
    draw_tile(px, py, tile.col)
  end

  -- draw flash effect
  if flash_time > 0 then
    fillp(0x5a5a.1)
    rectfill(0, 0, 127, 127, 7)
    fillp()
  end

  -- draw ui
  print("score:" .. score, 5, 116, 7)
  print("lvl:" .. level, 50, 116, 7)
  print("combo:" .. combo, 80, 116, 7)
end

function draw_gameover()
  cls(1)

  print("game over", 43, 30, 8)

  print("score: " .. score, 35, 50, 7)
  print("level: " .. level, 35, 60, 10)
  if combo > 0 then
    print("final combo: " .. combo, 28, 70, 12)
  end

  print("press z for menu", 26, 95, 10)
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
010100000f050f0501c051c05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101000034053405340534053405340534053405340534053405340534053405340534053405340534053405340534053405340534053405340534053405000000000000000000000000000000000000000000
010100003735373537353735373537353735373537353735373500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
