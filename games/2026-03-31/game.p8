pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- Fishing Frenzy: Cast your line and reel in the big catch
-- A dynamic fishing game with multiple fish types and satisfying feedback

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
  return btn(b)
end

-- game state
state = "menu"
score = 0
fish_caught = 0
best_score = 0
menu_flash = 0

-- level progression
current_level = 1
total_score = 0
level_fish_caught = 0
levels_data = {
  {target=5, spawn_mult=1.0, esc_mult=1.0},
  {target=6, spawn_mult=0.8, esc_mult=1.2},
  {target=7, spawn_mult=0.6, esc_mult=1.4},
  {target=8, spawn_mult=0.4, esc_mult=1.6},
  {target=9, spawn_mult=0.2, esc_mult=2.0}
}
score_mult = 1.0

-- fishing mechanics
cast_dist = 0
cast_speed = 0
is_casting = false
line_x = 0
line_y = 0
fish_timer = 0
fish_ready = false
fish_size = 0
fish_type = 0
reel_power = 0
casting_power = 0
screen_shake = 0

-- camera for player (boat)
boat_x = 64
boat_y = 100

-- sprite indices
boat_spr = 1
fish1_spr = 2  -- small fish
fish2_spr = 3  -- medium fish
fish3_spr = 4  -- large fish
bobber_spr = 5

function _init()
  state = "menu"
  score = 0
  fish_caught = 0
  cast_dist = 0
  is_casting = false
  fish_ready = false
  fish_timer = 0
  reel_power = 0
  current_level = 1
  total_score = 0
  level_fish_caught = 0
  _log("state:menu")
end

function update_menu()
  menu_flash = (menu_flash + 1) % 30
  if test_input(4) > 0 or test_input(5) > 0 then
    state = "play"
    _log("state:play")
    current_level = 1
    total_score = 0
    level_fish_caught = 0
    score = 0
    _log("level:1")
    sfx(4) -- menu start sound
  end
end

function update_play()
  if screen_shake > 0 then screen_shake -= 1 end

  local lvl_data = levels_data[current_level]
  score_mult = 0.8 + current_level * 0.2

  -- casting phase
  if not is_casting then
    if test_input(4) > 0 then
      casting_power = 0
      is_casting = true
      fish_timer = 0
      fish_ready = false
      _log("action:cast")
    end
  else
    -- build casting power
    casting_power = min(casting_power + 0.15, 100)

    -- release when button released
    if test_input(4) == 0 then
      cast_dist = casting_power * 0.8
      line_x = boat_x
      line_y = boat_y
      -- adjust spawn time based on level
      fish_timer = flr((25 + flr(cast_dist / 8)) * lvl_data.spawn_mult)
      is_casting = false
      sfx(0) -- cast sound
      _log("action:release_cast")
    end
  end

  -- waiting for fish
  if cast_dist > 0 and not fish_ready then
    fish_timer -= 1
    if fish_timer <= 0 then
      fish_ready = true
      fish_size = 5 + flr(rnd(15))
      fish_type = flr(rnd(3))
      sfx(1) -- bite sound
      _log("action:fish_biting")
    end
  end

  -- reeling (increased difficulty)
  if fish_ready then
    if test_input(5) > 0 then
      reel_power = min(reel_power + 0.25, 100)
    else
      reel_power = max(reel_power - 0.08, 0)
    end

    -- reel in the fish (slightly slower)
    cast_dist = max(cast_dist - reel_power * 0.015, 0)

    if cast_dist <= 3 then
      -- caught the fish!
      level_fish_caught += 1
      local fish_points = flr(fish_size * 10 * score_mult)
      score += fish_points
      total_score += fish_points
      cast_dist = 0
      fish_ready = false
      reel_power = 0
      screen_shake = 4
      sfx(2) -- catch sound
      _log("action:fish_caught")
      _log("score:"..score)

      -- check if level is complete
      if level_fish_caught >= lvl_data.target then
        if current_level >= 5 then
          -- all levels complete!
          state = "gameover"
          _log("state:gameover:win")
        else
          -- advance to next level
          current_level += 1
          level_fish_caught = 0
          _log("level:"..current_level)
        end
      end
    end
  end

  -- fish escape (higher chance if not reeling hard)
  if cast_dist > 0 and fish_ready then
    local base_esc = 0.008 * lvl_data.esc_mult
    local esc_chance = base_esc
    if reel_power < 20 then esc_chance = base_esc * 1.875 end
    if reel_power < 10 then esc_chance = base_esc * 3.125 end

    if rnd() < esc_chance then
      cast_dist = 0
      fish_ready = false
      reel_power = 0
      sfx(3) -- escape sound
      _log("action:fish_escaped")
    end
  end
end

function update_gameover()
  if test_input(4) > 0 or test_input(5) > 0 then
    best_score = max(best_score, total_score)
    state = "menu"
    sfx(4) -- menu sound
    _log("state:menu")
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

  -- animated water background
  for i = 0, 4 do
    local wave = flr(sin((t() * 2 + i) / 8) * 2)
    print("~~~", 0 + i * 40, 70 + wave, 5)
    print("~~~", 20 + i * 40, 78 + wave, 5)
  end

  -- title
  if menu_flash > 15 then
    print("fishing frenzy", 33, 15, 7)
  end

  -- instructions
  print("5 levels of fishing", 30, 32, 7)
  print("z to cast / x to reel", 21, 45, 6)

  -- best score
  if best_score > 0 then
    print("best: "..best_score, 39, 70, 5)
  end

  -- blinking start prompt
  if menu_flash % 20 > 10 then
    print("press z to start", 27, 110, 8)
  end
end

function draw_play()
  cls(1)

  -- screen shake effect
  local shake_x = 0
  local shake_y = 0
  if screen_shake > 0 then
    shake_x = flr(rnd(5)) - 2
    shake_y = flr(rnd(5)) - 2
  end
  camera(shake_x, shake_y)

  -- animated water with wave patterns
  for i = 0, 4 do
    local w1 = flr(sin((t() * 2 + i * 0.5) / 4) * 1.5)
    local w2 = flr(sin((t() * 1.5 + i) / 5) * 1)
    print("~~~", 0 + i * 40, 72 + w1, 5)
    print("~~~", 20 + i * 40, 80 + w2, 5)
  end

  -- boat (player) with subtle bobbing
  local boat_bob = flr(sin(t() * 2) * 0.5)
  spr(boat_spr, boat_x - 4, boat_y - 4 + boat_bob)

  -- fishing line with tension curve
  if cast_dist > 0 then
    local line_curve = sin(t() * 0.1) * 2 + (100 - reel_power) * 0.01
    local end_x = boat_x + line_curve
    local end_y = boat_y - 4 + cast_dist

    line(boat_x, boat_y - 4, end_x, end_y, 6)

    -- draw tension indicator (line thickness simulation)
    if reel_power > 50 then
      line(boat_x - 1, boat_y - 3, end_x - 1, end_y, 6)
    end

    -- fish at end of line
    if fish_ready then
      local fish_wiggle = sin(t() * 0.3) * 1.5
      local fx = end_x + fish_wiggle
      local fy = end_y

      -- draw appropriate fish sprite
      if fish_type == 0 then
        spr(fish1_spr, fx - 4, fy - 4)
      elseif fish_type == 1 then
        spr(fish2_spr, fx - 4, fy - 4)
      else
        spr(fish3_spr, fx - 4, fy - 4)
      end
    end
  end

  -- casting power meter
  if is_casting then
    rectfill(5, 5, 5 + casting_power / 2, 12, 8)
    rect(5, 5, 5 + 50, 12, 7)
    print("cast", 60, 6, 7)
  end

  -- reel power meter with color change
  if fish_ready then
    local reel_col = 11
    if reel_power > 70 then reel_col = 10 end
    rectfill(5, 15, 5 + reel_power / 2, 22, reel_col)
    rect(5, 15, 5 + 50, 22, 7)
    print("reel!", 60, 16, 7)
  end

  -- score and progress
  local lvl_data = levels_data[current_level]
  local target = lvl_data.target
  print("score: "..score, 5, 40, 7)
  print("level "..current_level.." ("..level_fish_caught.."/"..target..")", 5, 50, 7)

  -- reset camera
  camera(0, 0)
end

function draw_gameover()
  cls(1)

  -- water background
  for i = 0, 4 do
    print("~~~", 0 + i * 40, 100, 5)
  end

  -- victory screen
  print("all 5 levels complete!", 24, 10, 10)
  print("excellent work!", 32, 25, 7)

  print("total score:", 32, 45, 7)
  print(total_score, 52, 57, 10)

  if total_score > best_score then
    print("new best!", 39, 70, 8)
  end

  -- blinking prompt
  if flr(t() * 2) % 2 == 0 then
    print("press z to menu", 28, 110, 7)
  end
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00000000066660000011100000222000003330000044400000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000677766001111110221222202033333003444440000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000677766001111110221222202033333003444440000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066660000011100000222000003330000044400000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000a0500d0500e050105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001235012350143501535000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000c0300a0308030605000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000007040070400704007040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000905009050090500905000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

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
