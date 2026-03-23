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
combo_timer = 0  -- frames since last match (reset combo if > 120)
screen_shake = 0  -- screen shake effect
flash_time = 0  -- screen flash effect
difficulty = "medium"  -- easy, medium, hard
difficulty_selected = false
music_difficulty = nil  -- track which difficulty's music is playing

-- high score persistence
high_score = 0
high_level = 0
high_combo = 0
is_new_high_score = false

-- button state caching for test_input integration
curr_btn = 0
prev_btn = 0

-- grid constants
grid_w = 8
grid_h = 12
tile_size = 8
grid_x = (128 - grid_w * tile_size) / 2
grid_y = 8

-- pop animations for cleared tiles
pop_anims = {}

-- grid data: 0 = empty, 1-5 = tile colors
grid = {}
falling_tiles = {}  -- falling tile instances

-- tile colors: red, orange, yellow, green, light blue
tile_colors = {8, 9, 10, 11, 12}

-- load high scores from cartdata
function load_high_scores()
  high_score = dget(0) or 0
  high_level = dget(1) or 0
  high_combo = dget(2) or 0
  _log("high_score:current:" .. high_score)
end

-- save high scores to cartdata
function save_high_scores()
  dset(0, high_score)
  dset(1, high_level)
  dset(2, high_combo)
end

-- set difficulty parameters
function set_difficulty(diff)
  difficulty = diff
  _log("difficulty:selected:" .. diff)

  if diff == "easy" then
    grid_w = 6
    grid_h = 10
    spawn_rate = 50
    _log("grid:6x10,spawn:50")
  elseif diff == "medium" then
    grid_w = 8
    grid_h = 12
    spawn_rate = 30
    _log("grid:8x12,spawn:30")
  elseif diff == "hard" then
    grid_w = 10
    grid_h = 14
    spawn_rate = 15
    _log("grid:10x14,spawn:15")
  end

  grid_x = (128 - grid_w * tile_size) / 2
end

-- initialize grid
function init_game()
  grid = {}
  falling_tiles = {}
  pop_anims = {}
  score = 0
  level = 1
  game_time = 0
  spawn_counter = 0
  combo = 0
  combo_timer = 0
  screen_shake = 0
  flash_time = 0
  music_difficulty = nil  -- reset music tracking to force music change

  -- load high scores on first game
  load_high_scores()

  for y = 1, grid_h do
    grid[y] = {}
    for x = 1, grid_w do
      grid[y][x] = 0
    end
  end

  _log("state:play")
  _log("game:initialized:" .. difficulty)
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
      sfx(4)  -- tile placement sound
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

  -- clear marked tiles and create pop animations
  local clear_count = 0
  for key, _ in pairs(to_clear) do
    local parts = {}
    for part in key:gmatch("[^,]+") do
      add(parts, tonumber(part))
    end
    local x, y = parts[1], parts[2]
    if grid[y][x] ~= 0 then
      -- create pop animation
      add(pop_anims, {
        x = grid_x + (x - 1) * tile_size + tile_size / 2,
        y = grid_y + (y - 1) * tile_size + tile_size / 2,
        time = 0,
        col = grid[y][x]
      })
      grid[y][x] = 0
      clear_count += 1
    end
  end

  if clear_count > 0 then
    -- check if combo was already active, otherwise reset
    if combo_timer > 120 then
      combo = 0
    end
    combo += 1
    combo_timer = 0  -- reset combo timer

    -- score multiplier based on combo
    local multiplier = min(5, 1 + (combo - 1) * 0.5)  -- 1x, 1.5x, 2x, 2.5x, 3x...
    local score_gain = flr(clear_count * 10 * multiplier)
    score += score_gain

    screen_shake = 2
    flash_time = 4
    _log("match:detected:" .. clear_count)
    _log("combo:" .. combo)
    _log("score_gained:" .. score_gain)

    -- get pitch offset based on difficulty (higher pitches in harder modes)
    local pitch_offset = 0
    if difficulty == "hard" then
      pitch_offset = 4  -- high pitch for hard mode
    elseif difficulty == "medium" then
      pitch_offset = 2  -- medium pitch for medium mode
    end

    -- play different sfx based on match size and combo
    if combo >= 3 then
      sfx(6, nil, pitch_offset)  -- combo streak sound with difficulty-driven pitch
      _log("sfx:combo_streak:pitch_offset:" .. pitch_offset)
    elseif clear_count >= 8 then
      sfx(2, nil, pitch_offset)  -- big cascade
    elseif clear_count >= 5 then
      sfx(0, nil, pitch_offset)  -- medium match
    else
      sfx(0, nil, pitch_offset)  -- small match
    end
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
    if not difficulty_selected then
      sfx(5)  -- button press sound
      state = "difficulty"
      _log("state:difficulty")
    end
  end
end

function update_difficulty()
  if test_btnp(1) then  -- right
    if difficulty == "easy" then
      difficulty = "medium"
      sfx(3)  -- menu navigation sound
    elseif difficulty == "medium" then
      difficulty = "hard"
      sfx(3)  -- menu navigation sound
    end
  end
  if test_btnp(0) then  -- left
    if difficulty == "hard" then
      difficulty = "medium"
      sfx(3)  -- menu navigation sound
    elseif difficulty == "medium" then
      difficulty = "easy"
      sfx(3)  -- menu navigation sound
    end
  end

  if test_btnp(4) or test_btnp(5) then  -- z or x to confirm
    sfx(5)  -- button press/confirm sound
    set_difficulty(difficulty)
    difficulty_selected = true
    init_game()
    state = "play"
  end
end

function update_play()
  game_time += 1

  -- update combo timer
  combo_timer += 1
  if combo_timer > 120 then  -- 2 seconds at 60fps
    combo = 0
    combo_timer = 0
  end

  -- update screen effects
  if screen_shake > 0 then screen_shake -= 1 end
  if flash_time > 0 then flash_time -= 1 end

  -- update pop animations
  for i = #pop_anims, 1, -1 do
    pop_anims[i].time += 1
    if pop_anims[i].time > 8 then
      del(pop_anims, pop_anims[i])
    end
  end

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
    is_new_high_score = check_high_score()
    _log("state:gameover")
    _log("final_score:" .. score)
    _log("level_reached:" .. level)
    _log("final_combo:" .. combo)
    sfx(1)  -- game over sound
  end
end

function update_gameover()
  if test_btnp(4) or test_btnp(5) then  -- z or x
    sfx(5)  -- button press sound
    _log("action:return_to_menu")
    is_new_high_score = false
    difficulty_selected = false
    state = "menu"
    _log("state:menu")
  end
end

-- check and save high scores
function check_high_score()
  local is_new = false
  if score > high_score then
    high_score = score
    high_level = level
    high_combo = combo
    _log("high_score:new")
    is_new = true
  end
  save_high_scores()
  return is_new
end

function _update()
  prev_btn = curr_btn
  curr_btn = test_input(0)

  -- background music management
  if state == "menu" or state == "difficulty" then
    if stat(54) == -1 then
      music(0)  -- calm menu music
    end
  elseif state == "play" then
    -- select music pattern based on difficulty
    local target_pattern = 0  -- default easy
    if difficulty == "medium" then
      target_pattern = 1  -- medium intensity
    elseif difficulty == "hard" then
      target_pattern = 2  -- high intensity
    end

    -- only change music when difficulty changes
    if music_difficulty ~= difficulty then
      if stat(54) == -1 then
        music(target_pattern)
        music_difficulty = difficulty
        _log("music:changed:pattern:" .. target_pattern .. ":difficulty:" .. difficulty)
      end
    elseif stat(54) == -1 then
      music(target_pattern)
    end
  elseif state == "gameover" then
    music(-1)  -- stop music on game over
  end

  if state == "menu" then update_menu()
  elseif state == "difficulty" then update_difficulty()
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

  -- high score display
  print("best: " .. high_score, 70, 10, 11)

  -- instructions
  print("match 3+ tiles", 26, 55, 11)
  print("to clear them", 30, 62, 11)

  print("spawn gets faster", 20, 75, 7)
  print("score increases levels", 16, 82, 7)

  print("press z for difficulty", 21, 100, 10)
end

function draw_difficulty()
  cls(1)

  print("select difficulty", 30, 20, 7)

  -- draw difficulty options
  local easy_col = difficulty == "easy" and 7 or 5
  local med_col = difficulty == "medium" and 7 or 5
  local hard_col = difficulty == "hard" and 7 or 5

  print("easy", 20, 50, easy_col)
  print("6x10 grid, slow spawn", 16, 57, 5)

  print("medium", 15, 75, med_col)
  print("8x12 grid, normal spawn", 12, 82, 5)

  print("hard", 20, 100, hard_col)
  print("10x14 grid, fast spawn", 14, 107, 5)

  -- instructions
  print("< > select  z confirm", 12, 115, 11)
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

  -- draw pop animations
  for anim in all(pop_anims) do
    local scale = 1 + (8 - anim.time) / 8
    local size = flr(tile_size * scale / 2)
    fillp()
    circfill(anim.x, anim.y, size, anim.col)
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

  -- draw combo with visual feedback
  if combo > 1 then
    local multiplier = min(5, 1 + (combo - 1) * 0.5)
    local combo_col = combo > 5 and 8 or (combo > 3 and 10 or 11)
    print("x" .. flr(multiplier * 10) / 10, 80, 116, combo_col)
  end
end

function draw_gameover()
  cls(1)

  print("game over", 43, 30, 8)

  print("score: " .. score, 35, 50, 7)

  -- check if new high score
  if is_new_high_score then
    print("high score!", 40, 60, 7)
  end

  print("level: " .. level, 35, 70, 10)
  if combo > 0 then
    print("final combo: " .. combo, 28, 80, 12)
  end

  print("best: " .. high_score, 40, 105, 11)

  print("press z for menu", 26, 115, 10)
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "difficulty" then draw_difficulty()
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
01010000240524052405240524052405240524052405000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000140514051405140514051405140514051405000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000340534053405340534053405340534053405000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100001405240530053c053f05000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d0000104010401040104010401040104010401000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010d000013401340134013401340134013401340000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c0000173017301730173017301730173017300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__music__
00 04040203
01 04050406
02 04050605
