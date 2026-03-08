pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- lunar lander
-- gravity-based arcade lander

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

function test_input(i)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn(i)
end

function test_inputp(i)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    local val = test_inputs[test_input_idx] or 0
    return val > 0
  end
  return btnp(i)
end

-- game state
state = "menu"
game_mode = "normal"  -- "normal", "time_attack", or "practice"
menu_cursor = 0  -- 0=normal mode, 1=time attack, 2=leaderboard, 3=practice
practice_level = 1  -- selected practice level (1-5)
practice_cursor = 0  -- practice level selector cursor (0-4)
difficulty = 1  -- 0=easy, 1=normal, 2=hard
difficulty_cursor = 1  -- menu cursor position
level = 1
score = 0
chain = 0
total_fuel_saved = 0
last_chain_milestone = 0

-- time attack mode
time_attack_timer = 240  -- seconds remaining (240 = 4 minutes)
time_attack_start_time = 0  -- time when started
time_attack_level_start = 0  -- time when current level started
time_attack_best_time = 0  -- best completion time
time_warning_played = false  -- 30s warning flag

-- bonus tracking
collision_count = 0
total_bonuses = 0
soft_landing_count = 0
fuel_efficiency_count = 0
precision_landing_count = 0
perfect_run_count = 0
best_landing_score = 0

-- high score persistence
high_score = 0
high_level = 0
high_landing = 0
new_record = false  -- flag for new record celebration

-- leaderboard system
leaderboard = {}  -- top 5 scores with names
player_name = "AAA"  -- name being entered
name_entry_pos = 0  -- current character (0-2)
player_rank = 0  -- player's rank in leaderboard

-- achievement system
achievements = {}  -- 15 boolean flags for unlocked achievements
new_achievements = {}  -- achievements unlocked this session
achievement_names = {
  "first blood",
  "steady hands",
  "chain reaction",
  "expert pilot",
  "perfect run",
  "fuel miser",
  "precision landing",
  "boss slayer",
  "phase 2 survivor",
  "mission complete",
  "hazard dodger",
  "flawless victory",
  "ice master",
  "fuel conservationist",
  "magnetic pilot"
}
achievement_desc = {
  "complete first landing",
  "3 consecutive soft landings",
  "reach landing chain x3",
  "reach landing chain x5",
  "complete level without collisions",
  "land w/ fuel bonus 5 times",
  "land in zone center 5 times",
  "defeat boss (level 3, 4, or 5)",
  "defeat boss in phase 2",
  "reach level 6 (complete all levels)",
  "land near hazard 10 times",
  "win without shield & no collisions",
  "land near ice zone 5 times",
  "complete level w/ <30% fuel",
  "use magnetic pull to land 3 times"
}

-- achievement progress tracking
consecutive_soft_landings = 0
total_soft_landings = 0
total_fuel_efficiency_landings = 0
total_precision_landings = 0
total_perfect_runs = 0
total_hazard_landings = 0
bosses_defeated = 0
phase2_bosses_defeated = 0
shield_used_this_game = false
collisions_this_game = 0
total_ice_landings = 0
total_magnetic_landings = 0

-- ship physics
ship = {}
particles = {}
shake_frames = 0
shake_intensity = 0
thrust_sfx_timer = 0
nearest_hazard_dist = 999  -- distance to nearest hazard (for proximity effects)
hazard_warning_timer = 0  -- cooldown for proximity warning sfx

-- level data
landing_zones = {}
asteroids = {}
fuel_pickups = {}
enemies = {}
enemy_projectiles = {}
boss = nil
boss_projectiles = {}
powerups = {}
active_powerups = {}
hazard_zones = {}
surface_y = 0
camera_y = 0
last_cam_log = -999

function _init()
  load_highscores()
  load_achievements()
  load_leaderboard()
  _log("state:menu")
  music(0)  -- start menu music
end

-- high score persistence
function load_highscores()
  cartdata("lunarlander_v1")
  high_score = dget(0)
  high_level = dget(1)
  high_landing = dget(2)
  time_attack_best_time = dget(15)  -- slot 15 for time attack
  _log("load:score:"..high_score..",level:"..high_level..",landing:"..high_landing..",time:"..time_attack_best_time)
end

function save_highscores()
  dset(0, high_score)
  dset(1, high_level)
  dset(2, high_landing)
  dset(15, time_attack_best_time)  -- save time attack
  _log("save:score:"..high_score..",level:"..high_level..",landing:"..high_landing..",time:"..time_attack_best_time)
end

-- achievement persistence
function load_achievements()
  -- slots 3-14 for original 12 achievements, slots 16-18 for new 3 (0=locked, 1=unlocked)
  for i = 1, 12 do
    achievements[i] = dget(2 + i) > 0
  end
  for i = 13, 15 do
    achievements[i] = dget(3 + i) > 0  -- slots 16-18
  end
  _log("load:achievements:"..count_achievements())
end

function save_achievements()
  for i = 1, 12 do
    dset(2 + i, achievements[i] and 1 or 0)
  end
  for i = 13, 15 do
    dset(3 + i, achievements[i] and 1 or 0)  -- slots 16-18
  end
  _log("save:achievements")
end

-- leaderboard persistence (slots 19-28)
function encode_name(name)
  -- convert 3-char string to number
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
  local val = 0
  for i = 1, 3 do
    local c = sub(name, i, i)
    local code = 37  -- default to space
    -- find character position in lookup table
    for j = 1, #chars do
      if sub(chars, j, j) == c then
        code = j
        break
      end
    end
    val = val * 40 + code
  end
  return val
end

function decode_name(val)
  -- convert number back to 3-char string
  local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
  local name = ""
  for i = 1, 3 do
    local code = val % 40
    val = flr(val / 40)
    if code >= 1 and code <= 37 then
      name = sub(chars, code, code)..name
    else
      name = " "..name
    end
  end
  return name
end

function load_leaderboard()
  leaderboard = {}
  for i = 1, 5 do
    local score = dget(18 + i * 2)
    local name_code = dget(19 + i * 2)
    if score > 0 then
      add(leaderboard, {
        score = score,
        name = decode_name(name_code)
      })
    end
  end
  _log("load:leaderboard:"..#leaderboard.." entries")
end

function save_leaderboard()
  for i = 1, 5 do
    if i <= #leaderboard then
      dset(18 + i * 2, leaderboard[i].score)
      dset(19 + i * 2, encode_name(leaderboard[i].name))
    else
      dset(18 + i * 2, 0)
      dset(19 + i * 2, 0)
    end
  end
  _log("save:leaderboard:"..#leaderboard.." entries")
end

function get_leaderboard_rank(score)
  -- returns rank (1-5) or 0 if not in top 5
  if score == 0 then return 0 end

  local rank = 1
  for entry in all(leaderboard) do
    if score <= entry.score then
      rank += 1
    end
  end

  if rank <= 5 then
    return rank
  end
  return 0
end

function insert_leaderboard_entry(score, name)
  -- insert entry in sorted order and keep top 5
  add(leaderboard, {score = score, name = name})

  -- bubble sort (simple for small array)
  for i = 1, #leaderboard - 1 do
    for j = i + 1, #leaderboard do
      if leaderboard[j].score > leaderboard[i].score then
        local temp = leaderboard[i]
        leaderboard[i] = leaderboard[j]
        leaderboard[j] = temp
      end
    end
  end

  -- keep only top 5
  while #leaderboard > 5 do
    del(leaderboard, leaderboard[6])
  end

  save_leaderboard()
  _log("leaderboard:insert:"..name.."="..score)
end

function count_achievements()
  local count = 0
  for i = 1, 15 do
    if achievements[i] then count += 1 end
  end
  return count
end

function unlock_achievement(id)
  if achievements[id] then return end  -- already unlocked

  achievements[id] = true
  add(new_achievements, id)
  save_achievements()

  _log("achievement:unlock:"..achievement_names[id])

  -- celebration effects
  sfx(5)  -- fanfare sound
  shake_frames = 10
  shake_intensity = 1.2

  -- burst of particles
  for i = 1, 20 do
    add(particles, {
      x = 64,
      y = 64,
      vx = rnd(4) - 2,
      vy = rnd(4) - 2,
      life = 30,
      col = 10  -- gold
    })
  end
end

function check_achievements()
  -- 1. first blood: complete first landing
  if not achievements[1] and total_soft_landings + total_fuel_efficiency_landings + total_precision_landings > 0 then
    unlock_achievement(1)
  end

  -- 2. steady hands: 3 consecutive soft landings
  if not achievements[2] and consecutive_soft_landings >= 3 then
    unlock_achievement(2)
  end

  -- 3. chain reaction: reach landing chain x3
  if not achievements[3] and chain >= 3 then
    unlock_achievement(3)
  end

  -- 4. expert pilot: reach landing chain x5
  if not achievements[4] and chain >= 5 then
    unlock_achievement(4)
  end

  -- 5. perfect run: complete level without collisions
  if not achievements[5] and total_perfect_runs >= 1 then
    unlock_achievement(5)
  end

  -- 6. fuel miser: land with fuel efficiency bonus 5 times
  if not achievements[6] and total_fuel_efficiency_landings >= 5 then
    unlock_achievement(6)
  end

  -- 7. precision landing: land in zone center 5 times
  if not achievements[7] and total_precision_landings >= 5 then
    unlock_achievement(7)
  end

  -- 8. boss slayer: defeat boss
  if not achievements[8] and bosses_defeated >= 1 then
    unlock_achievement(8)
  end

  -- 9. phase 2 survivor: defeat boss in phase 2
  if not achievements[9] and phase2_bosses_defeated >= 1 then
    unlock_achievement(9)
  end

  -- 10. mission complete: reach level 6
  if not achievements[10] and level >= 6 then
    unlock_achievement(10)
  end

  -- 11. hazard dodger: land near hazard 10 times
  if not achievements[11] and total_hazard_landings >= 10 then
    unlock_achievement(11)
  end

  -- 12. flawless victory: win without shield usage and no collisions
  if not achievements[12] and level >= 6 and not shield_used_this_game and collisions_this_game == 0 then
    unlock_achievement(12)
  end

  -- 13. ice master: land near ice zone 5 times
  if not achievements[13] and total_ice_landings >= 5 then
    unlock_achievement(13)
  end

  -- 14. fuel conservationist: complete level with <30% fuel remaining
  if not achievements[14] and ship.fuel > 0 then
    local fuel_table = {80, 70, 60, 50, 40}
    local fuel_mult = {1.15, 1.0, 0.8}
    local max_fuel = flr((fuel_table[level] or 40) * fuel_mult[difficulty + 1])
    if ship.fuel / max_fuel < 0.3 then
      unlock_achievement(14)
    end
  end

  -- 15. magnetic pilot: use magnetic pull to assist landing 3 times
  if not achievements[15] and total_magnetic_landings >= 3 then
    unlock_achievement(15)
  end
end

function check_and_save_records()
  new_record = false

  -- check for new high score
  if score > high_score then
    high_score = score
    new_record = true
    _log("newhigh:score:"..score)
    sfx(5)  -- celebration sound
  end

  -- check for furthest level
  if level > high_level then
    high_level = level
    new_record = true
    _log("newhigh:level:"..level)
  end

  -- check for best landing bonus
  if best_landing_score > high_landing then
    high_landing = best_landing_score
    new_record = true
    _log("newhigh:landing:"..best_landing_score)
  end

  -- check for time attack best time (only if completed all 5 levels)
  if game_mode == "time_attack" and level >= 6 then
    local total_time = t() - time_attack_start_time
    if time_attack_best_time == 0 or total_time < time_attack_best_time then
      time_attack_best_time = total_time
      new_record = true
      _log("newhigh:time_attack:"..flr(total_time).."s")
    end
  end

  -- save if any record was beaten
  if new_record then
    save_highscores()
  end

  -- check for achievements
  check_achievements()
end

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "difficulty_select" then
    update_difficulty_select()
  elseif state == "practice_select" then
    update_practice_select()
  elseif state == "achievements" then
    update_achievements()
  elseif state == "leaderboard" then
    update_leaderboard()
  elseif state == "name_entry" then
    update_name_entry()
  elseif state == "play" then
    update_play()
  elseif state == "pause" then
    update_pause()
  elseif state == "gameover" then
    update_gameover()
  end

  -- update particles
  for p in all(particles) do
    p.x += p.vx
    p.y += p.vy
    p.life -= 1
    if p.life <= 0 then
      del(particles, p)
    end
  end

  -- update shake
  if shake_frames > 0 then
    shake_frames -= 1
  end

  -- update thrust sfx timer
  if thrust_sfx_timer > 0 then
    thrust_sfx_timer -= 1
  end
end

function _draw()
  cls(0)

  -- apply shake and camera offset
  local sx, sy = 0, 0
  if shake_frames > 0 then
    sx = rnd(shake_intensity * 2) - shake_intensity
    sy = rnd(shake_intensity * 2) - shake_intensity
  end

  -- apply camera_y only during play state
  local cam_y = (state == "play" or state == "pause") and camera_y or 0
  camera(sx, sy + cam_y)

  if state == "menu" then
    draw_menu()
  elseif state == "difficulty_select" then
    draw_difficulty_select()
  elseif state == "practice_select" then
    draw_practice_select()
  elseif state == "achievements" then
    draw_achievements()
  elseif state == "leaderboard" then
    draw_leaderboard()
  elseif state == "name_entry" then
    draw_name_entry()
  elseif state == "play" then
    draw_world()  -- draw world elements in world space
  elseif state == "pause" then
    draw_world()  -- draw frozen world
  elseif state == "gameover" then
    draw_gameover()
  end

  camera(0, 0)  -- reset camera before HUD

  -- draw HUD in screen space (play and pause states)
  if state == "play" then
    draw_hud()
  elseif state == "pause" then
    draw_pause()
  end
end

-- menu state
function update_menu()
  -- up/down navigation
  if test_inputp(2) then  -- up
    menu_cursor = max(0, menu_cursor - 1)
    sfx(4)
  elseif test_inputp(3) then  -- down
    menu_cursor = min(3, menu_cursor + 1)
    sfx(4)
  end

  if test_inputp(4) then  -- O button
    if menu_cursor == 0 then
      -- normal mode
      game_mode = "normal"
      state = "difficulty_select"
      difficulty_cursor = 1  -- reset cursor to normal
      _log("state:difficulty_select:normal")
    elseif menu_cursor == 1 then
      -- time attack mode
      game_mode = "time_attack"
      difficulty = 1  -- always normal difficulty
      state = "play"
      level = 1
      score = 0
      chain = 0
      time_attack_timer = 240  -- 4 minutes
      time_attack_start_time = t()
      time_warning_played = false

      -- reset tracking
      collision_count = 0
      total_bonuses = 0
      new_achievements = {}
      shield_used_this_game = false
      collisions_this_game = 0

      init_level()
      music(1)
      _log("state:play:time_attack")
    elseif menu_cursor == 2 then
      -- leaderboard
      state = "leaderboard"
      _log("state:leaderboard")
    else
      -- practice mode
      game_mode = "practice"
      state = "practice_select"
      practice_cursor = 0
      _log("state:practice_select")
    end
  elseif test_inputp(5) then  -- X button - achievements
    state = "achievements"
    _log("state:achievements")
  end
end

function draw_menu()
  print("lunar lander", 32, 20, 7)

  -- high score display
  if high_score > 0 then
    print("best score: "..high_score, 28, 28, 10)
  end

  -- time attack record
  if time_attack_best_time > 0 then
    local mins = flr(time_attack_best_time / 60)
    local secs = flr(time_attack_best_time % 60)
    print("best time: "..mins..":"..secs, 30, 35, 11)
  end

  -- mode selection
  print("select mode:", 32, 48, 7)

  local norm_col = (menu_cursor == 0) and 11 or 6
  local time_col = (menu_cursor == 1) and 11 or 6
  local lead_col = (menu_cursor == 2) and 11 or 6
  local prac_col = (menu_cursor == 3) and 11 or 6

  print("\x8e normal mode", 24, 58, norm_col)
  print("\x8e time attack", 24, 66, time_col)
  print("\x8e leaderboard", 24, 74, lead_col)
  print("\x8e practice mode", 22, 82, prac_col)

  -- mode description
  if menu_cursor == 0 then
    print("classic lander", 24, 92, 13)
    print("all features", 24, 99, 13)
  elseif menu_cursor == 1 then
    print("race vs clock!", 24, 92, 13)
    print("4 min, no power-ups", 14, 99, 13)
  elseif menu_cursor == 2 then
    print("top 5 scores", 28, 92, 13)
    print("with player names", 20, 99, 13)
  else
    print("select any level", 22, 92, 13)
    print("no score tracking", 20, 99, 13)
  end

  print("up/down: select", 24, 110, 6)
  print("o: start  x: achievements", 8, 118, 6)
end

-- achievements state
function update_achievements()
  if test_inputp(5) or test_inputp(4) then  -- X or O button - back to menu
    state = "menu"
    _log("state:menu")
  end
end

function draw_achievements()
  print("achievements", 32, 4, 7)
  local unlocked = count_achievements()
  print(unlocked.."/15 unlocked", 36, 12, unlocked > 0 and 11 or 6)

  -- draw achievements in 2 columns (8 left, 7 right for 15 total)
  for i = 1, 15 do
    local col_x = (i <= 8) and 2 or 66
    local row_y = 22 + ((i - 1) % 8) * 12
    local locked = not achievements[i]

    -- tier number and name
    local tier_col = locked and 5 or 10
    print(i..".", col_x, row_y, tier_col)

    -- show short name (limited space)
    local short_name = achievement_names[i]
    if #short_name > 12 then
      short_name = sub(short_name, 1, 11)
    end
    print(short_name, col_x + 10, row_y, locked and 6 or 7)

    -- description (smaller to fit)
    local short_desc = achievement_desc[i]
    if #short_desc > 17 then
      short_desc = sub(short_desc, 1, 16)
    end
    print(short_desc, col_x + 2, row_y + 5, locked and 5 or 13)

    -- unlock indicator
    if not locked then
      print("\x8e", col_x + 2, row_y, 11)  -- checkmark
    end
  end

  print("press x/o to return", 20, 119, 6)
end

-- leaderboard state
function update_leaderboard()
  if test_inputp(5) or test_inputp(4) then  -- X or O button - back to menu
    state = "menu"
    _log("state:menu")
  end
end

function draw_leaderboard()
  print("leaderboard", 36, 8, 7)
  print("top 5 scores", 32, 16, 13)

  if #leaderboard == 0 then
    print("no scores yet!", 28, 50, 6)
    print("play to set a record!", 16, 58, 13)
  else
    for i = 1, #leaderboard do
      local entry = leaderboard[i]
      local y = 32 + i * 14

      -- rank with trophy/color
      local rank_col = 7
      local trophy = ""
      if i == 1 then
        rank_col = 10  -- gold
        trophy = "\x8e"
      elseif i == 2 then
        rank_col = 12  -- blue
        trophy = "\x8f"
      elseif i == 3 then
        rank_col = 14  -- pink
        trophy = "\x94"
      end

      print(trophy.." "..i..".", 12, y, rank_col)
      print(entry.name, 32, y, rank_col)
      print(entry.score, 68, y, 7)

      -- highlight if this is the player's recent entry
      if player_rank == i and player_rank > 0 then
        rect(10, y - 2, 118, y + 8, 11)
      end
    end
  end

  print("press x/o to return", 20, 119, 6)
end

-- practice mode level selection
function update_practice_select()
  -- up/down navigation
  if test_inputp(2) then  -- up
    practice_cursor = max(0, practice_cursor - 1)
    sfx(4)
  elseif test_inputp(3) then  -- down
    practice_cursor = min(4, practice_cursor + 1)
    sfx(4)
  end

  if test_inputp(4) then  -- O button - start practice
    practice_level = practice_cursor + 1
    level = practice_level
    score = 0
    chain = 0
    difficulty = 1  -- always normal difficulty

    -- reset tracking
    collision_count = 0
    total_bonuses = 0
    new_achievements = {}
    shield_used_this_game = false
    collisions_this_game = 0

    state = "play"
    init_level()
    music(1)
    _log("state:play:practice:level"..practice_level)
  elseif test_inputp(5) then  -- X button - back to menu
    state = "menu"
    _log("state:menu")
  end
end

function draw_practice_select()
  print("practice mode", 32, 8, 7)
  print("select level", 32, 16, 13)

  -- level selection
  for i = 1, 5 do
    local y = 30 + i * 14
    local col = (practice_cursor == i - 1) and 11 or 6

    print("\x8e level "..i, 36, y, col)

    -- level info preview
    if practice_cursor == i - 1 then
      local info_y = 112
      if i == 1 then
        print("easy start", 32, info_y, 13)
      elseif i == 2 then
        print("moderate hazards", 22, info_y, 13)
      elseif i == 3 then
        print("boss encounter", 26, info_y, 13)
      elseif i == 4 then
        print("harder boss", 30, info_y, 13)
      else
        print("final challenge", 24, info_y, 13)
      end
    end
  end

  print("up/down: select", 24, 96, 6)
  print("o: start  x: back", 24, 104, 6)
end

-- name entry state
function update_name_entry()
  -- left/right: move between characters
  if test_inputp(0) then  -- left
    name_entry_pos = max(0, name_entry_pos - 1)
    sfx(4)
  elseif test_inputp(1) then  -- right
    name_entry_pos = min(2, name_entry_pos + 1)
    sfx(4)
  end

  -- up/down: cycle through characters
  if test_inputp(2) or test_inputp(3) then  -- up or down
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 "
    local current_char = sub(player_name, name_entry_pos + 1, name_entry_pos + 1)
    local char_idx = 1

    -- find current character in list
    for i = 1, #chars do
      if sub(chars, i, i) == current_char then
        char_idx = i
        break
      end
    end

    -- move to next/prev character
    if test_inputp(2) then  -- up
      char_idx = char_idx - 1
      if char_idx < 1 then char_idx = #chars end
    else  -- down
      char_idx = char_idx + 1
      if char_idx > #chars then char_idx = 1 end
    end

    -- update player_name
    local new_char = sub(chars, char_idx, char_idx)
    local before = sub(player_name, 1, name_entry_pos)
    local after = sub(player_name, name_entry_pos + 2, 3)
    player_name = before..new_char..after

    sfx(4)
  end

  -- O button: confirm
  if test_inputp(4) then
    insert_leaderboard_entry(score, player_name)
    state = "gameover"
    _log("state:gameover:name_saved")
  end

  -- X button: cancel (use default name)
  if test_inputp(5) then
    insert_leaderboard_entry(score, "???")
    state = "gameover"
    _log("state:gameover:name_cancelled")
  end
end

function draw_name_entry()
  print("new high score!", 28, 20, 10)
  print("you placed #"..player_rank.."!", 32, 28, 11)

  print("enter your name:", 24, 48, 7)

  -- draw name with cursor
  for i = 0, 2 do
    local char = sub(player_name, i + 1, i + 1)
    local x = 40 + i * 16
    local y = 60

    -- highlight current character
    if i == name_entry_pos then
      rectfill(x - 2, y - 2, x + 8, y + 8, 1)
      print(char, x, y, 11)
    else
      print(char, x, y, 7)
    end
  end

  print("left/right: move", 24, 80, 13)
  print("up/down: change letter", 12, 88, 13)
  print("o: confirm  x: skip", 20, 100, 6)

  print("final score: "..score, 28, 112, 10)
end

-- difficulty selection state
function update_difficulty_select()
  -- left/right navigation
  if test_inputp(0) then  -- left
    difficulty_cursor = max(0, difficulty_cursor - 1)
    sfx(4)
    _log("difficulty:cursor:"..difficulty_cursor)
  end
  if test_inputp(1) then  -- right
    difficulty_cursor = min(2, difficulty_cursor + 1)
    sfx(4)
    _log("difficulty:cursor:"..difficulty_cursor)
  end

  -- confirm selection
  if test_inputp(4) then  -- O button
    difficulty = difficulty_cursor
    local diff_names = {"easy", "normal", "hard"}
    _log("difficulty:"..diff_names[difficulty + 1])

    state = "play"
    level = 1
    score = 0
    chain = 0
    last_chain_milestone = 0
    total_fuel_saved = 0

    -- reset bonus tracking
    collision_count = 0
    total_bonuses = 0
    soft_landing_count = 0
    fuel_efficiency_count = 0
    precision_landing_count = 0
    perfect_run_count = 0
    best_landing_score = 0

    -- reset achievement tracking for this game
    new_achievements = {}
    consecutive_soft_landings = 0
    shield_used_this_game = false
    collisions_this_game = 0

    init_level()
    music(1)  -- start gameplay music
    _log("state:play")
  end
end

function draw_difficulty_select()
  print("select difficulty", 24, 20, 7)

  -- difficulty options
  local diff_names = {"easy", "normal", "hard"}
  local diff_x = {16, 48, 88}

  for i = 0, 2 do
    local col = (i == difficulty_cursor) and 11 or 6
    print(diff_names[i + 1], diff_x[i + 1], 40, col)
  end

  -- cursor indicator
  print(">", diff_x[difficulty_cursor + 1] - 8, 40, 11)

  -- description based on cursor
  local desc = ""
  if difficulty_cursor == 0 then
    print("easy mode:", 20, 60, 10)
    print("less gravity", 20, 70, 6)
    print("more fuel", 20, 78, 6)
    print("wider landing zones", 20, 86, 6)
    print("score x0.8", 20, 94, 6)
  elseif difficulty_cursor == 1 then
    print("normal mode:", 18, 60, 10)
    print("standard challenge", 18, 70, 6)
    print("balanced gameplay", 18, 78, 6)
    print("score x1.0", 18, 94, 6)
  else
    print("hard mode:", 20, 60, 10)
    print("more gravity", 20, 70, 6)
    print("less fuel", 20, 78, 6)
    print("narrow landing zones", 20, 86, 6)
    print("score x1.5", 20, 94, 6)
  end

  print("arrows: select", 24, 115, 13)
  print("o: confirm", 32, 122, 13)
end

-- play state
function init_level()
  _log("level:"..level)

  -- track level start time for time attack
  if game_mode == "time_attack" then
    time_attack_level_start = t()
  end

  -- difficulty scaling factors
  local fuel_mult = {1.15, 1.0, 0.8}  -- easy, normal, hard
  local grav_mult = {0.8, 1.0, 1.15}
  local zone_mult = {1.3, 1.0, 0.75}
  local ast_adjust = {-2, -1, 0}  -- asteroid count adjustment

  -- init ship
  local fuel_table = {80, 70, 60, 50, 40}
  local grav_table = {0.15, 0.2, 0.22, 0.24, 0.3}

  local base_fuel = fuel_table[level] or 40
  local base_grav = grav_table[level] or 0.3

  ship = {
    x = 64,
    y = 20,
    vx = 0,
    vy = 0,
    angle = 0,  -- 0 = up, 0.25 = right, 0.5 = down, 0.75 = left
    fuel = flr(base_fuel * fuel_mult[difficulty + 1]),
    gravity = base_grav * grav_mult[difficulty + 1],
    alive = true,
    thrusting = false,
    ice_timer = 0,  -- slowdown effect from ice zones
    near_magnetic = false  -- flag for magnetic pull achievement tracking
  }

  -- init camera
  camera_y = 0
  last_cam_log = -999
  surface_y = 400 + (level * 50)

  -- reset collision count for perfect run bonus
  collision_count = 0

  -- generate landing zones with structured randomization
  landing_zones = {}
  local zone_count = min(3 + level - 1, 5)
  local base_width = 20
  local zone_width = flr(base_width * zone_mult[difficulty + 1])

  -- define horizontal ranges for each zone (creates distinct "lanes")
  -- each zone has its own region to add variety while maintaining structure
  local zone_ranges = {
    {15, 30},   -- zone 1: left region
    {40, 60},   -- zone 2: left-center region
    {70, 90},   -- zone 3: center-right region
    {95, 112},  -- zone 4: right region (levels 4+)
    {50, 65}    -- zone 5: center region (level 5 only, overlaps zone 2 range for variety)
  }

  -- create landing zones with randomized positions within their ranges
  for i = 1, zone_count do
    local range = zone_ranges[i]
    local min_x = range[1]
    local max_x = range[2]

    -- ensure zone fits within bounds considering zone width
    local half_w = flr(zone_width / 2)
    min_x = max(min_x, 8 + half_w)
    max_x = min(max_x, 120 - half_w)

    -- randomize position within the range
    local zx = min_x + rnd(max_x - min_x)
    local zy = surface_y - 2

    add(landing_zones, {
      x = zx,
      y = zy,
      w = zone_width,
      h = 2
    })
    _log("zone:"..i..":x:"..flr(zx)..":range:"..min_x.."-"..max_x)
  end

  -- generate asteroids
  asteroids = {}
  local ast_count = max(0, level + ast_adjust[difficulty + 1])

  -- time attack mode: 20% more asteroids
  if game_mode == "time_attack" and ast_count > 0 then
    ast_count = flr(ast_count * 1.2) + 1
  end

  for i = 1, ast_count do
    add(asteroids, {
      x = 15 + rnd(98),
      y = 80 + rnd(surface_y - 120),
      r = 4 + rnd(4)
    })
  end

  -- generate fuel pickups
  fuel_pickups = {}
  local pickup_counts = {4, 3, 2}  -- easy, normal, hard
  local pickup_count = pickup_counts[difficulty + 1]
  if rnd(1) < 0.5 then
    pickup_count -= 1  -- randomize: easy=3-4, normal=2-3, hard=1-2
  end
  for i = 1, pickup_count do
    local px, py, valid
    local attempts = 0
    repeat
      px = 20 + rnd(88)
      py = 60 + rnd(surface_y - 100)
      valid = true
      attempts += 1

      -- check distance from asteroids
      for a in all(asteroids) do
        local dx = px - a.x
        local dy = py - a.y
        if sqrt(dx * dx + dy * dy) < a.r + 15 then
          valid = false
          break
        end
      end

      -- check distance from landing zones
      for z in all(landing_zones) do
        if py > z.y - 30 and py < z.y + 10 and px > z.x - 10 and px < z.x + z.w + 10 then
          valid = false
          break
        end
      end
    until valid or attempts > 20

    if valid then
      add(fuel_pickups, {
        x = px,
        y = py,
        anim = rnd(1)  -- animation offset
      })
      _log("fuel_pickup:spawn:"..flr(px)..","..flr(py))
    end
  end

  -- generate enemies
  enemies = {}
  if level >= 2 then
    local enemy_counts = {1, 2, 3}  -- easy, normal, hard
    local enemy_count = enemy_counts[difficulty + 1]

    -- time attack mode: 20% more enemies
    if game_mode == "time_attack" and enemy_count > 0 then
      enemy_count = flr(enemy_count * 1.2) + 1
    end

    for i = 1, enemy_count do
      local patrol_type = flr(rnd(2))  -- 0=horizontal, 1=vertical
      local ex, ey, evx, evy, patrol_min, patrol_max

      if patrol_type == 0 then
        -- horizontal patrol
        ex = 16 + rnd(96)
        ey = 80 + rnd(surface_y - 160)
        evx = 0.3 + rnd(0.4)  -- speed 0.3-0.7
        evy = 0
        patrol_min = 16
        patrol_max = 112
      else
        -- vertical patrol
        ex = 20 + rnd(88)
        ey = 60 + rnd(140)
        evx = 0
        evy = 0.3 + rnd(0.4)  -- speed 0.3-0.7
        patrol_min = 60
        patrol_max = 200
      end

      -- fire rate based on difficulty
      local fire_rates = {120, 90, 60}  -- easy, normal, hard
      local fire_rate = fire_rates[difficulty + 1]

      add(enemies, {
        x = ex,
        y = ey,
        vx = evx,
        vy = evy,
        r = 5,
        patrol_type = patrol_type,
        patrol_min = patrol_min,
        patrol_max = patrol_max,
        fire_rate = fire_rate,
        fire_timer = flr(rnd(fire_rate)),  -- random initial delay
        telegraph_timer = 0
      })

      _log("enemy:spawn:"..flr(ex)..","..flr(ey)..":type:"..patrol_type)
    end

    -- spawn sfx (warning beep)
    if enemy_count > 0 then
      sfx(7)
    end
  end

  -- generate power-ups (disabled in time attack mode)
  powerups = {}
  active_powerups = {}
  if game_mode ~= "time_attack" then
    local powerup_count = 2 + flr(rnd(2))  -- 2-3 power-ups per level
    for i = 1, powerup_count do
    local px, py, valid
    local attempts = 0
    repeat
      px = 20 + rnd(88)
      py = 60 + rnd(surface_y - 100)
      valid = true
      attempts += 1

      -- check distance from asteroids
      for a in all(asteroids) do
        local dx = px - a.x
        local dy = py - a.y
        if sqrt(dx * dx + dy * dy) < a.r + 20 then
          valid = false
          break
        end
      end

      -- check distance from enemies
      for e in all(enemies) do
        local dx = px - e.x
        local dy = py - e.y
        if sqrt(dx * dx + dy * dy) < e.r + 20 then
          valid = false
          break
        end
      end

      -- check distance from landing zones
      for z in all(landing_zones) do
        if py > z.y - 35 and py < z.y + 10 and px > z.x - 10 and px < z.x + z.w + 10 then
          valid = false
          break
        end
      end
    until valid or attempts > 20

    if valid then
      -- power-up types: 1=shield, 2=fuel_restorer, 3=rocket_boost, 4=gravity_reducer
      local ptype = flr(rnd(4)) + 1
      add(powerups, {
        x = px,
        y = py,
        type = ptype,
        anim = rnd(1)  -- animation offset
      })
      _log("powerup:spawn:type"..ptype..":"..flr(px)..","..flr(py))
    end
    end
  end

  -- generate hazard zones with type variety
  hazard_zones = {}
  local hazard_counts = {0, 2, 3, 4, 4}  -- level 1: 0, level 2: 2, level 3: 3, level 4+: 4
  local hazard_count = hazard_counts[min(level, 5)]

  -- adjust for difficulty (easy=fewer, hard=more)
  if difficulty == 0 and hazard_count > 0 then
    hazard_count -= 1  -- easy mode: one fewer hazard
  elseif difficulty == 2 and level >= 3 then
    hazard_count = min(hazard_count + 1, 5)  -- hard mode: one more hazard (max 5)
  end

  -- time attack mode: 20% more hazards
  if game_mode == "time_attack" and hazard_count > 0 then
    hazard_count = flr(hazard_count * 1.2) + 1  -- round up for 20% increase
  end

  for i = 1, hazard_count do
    local hx, hy, valid
    local attempts = 0
    repeat
      -- randomize position with awareness of landing zone structure
      -- place hazards in gaps between landing zone ranges
      local gap_ranges = {
        {8, 14},      -- before zone 1
        {31, 39},     -- between zones 1 and 2
        {61, 69},     -- between zones 2 and 3
        {91, 94},     -- between zones 3 and 4
        {113, 120}    -- after zone 4
      }
      local gap = gap_ranges[1 + flr(rnd(#gap_ranges))]
      hx = gap[1] + rnd(gap[2] - gap[1])
      hy = surface_y - 2  -- on the surface
      valid = true
      attempts += 1

      -- check distance from landing zones (must be at least 20px away from zone centers)
      for z in all(landing_zones) do
        local zone_center = z.x + z.w / 2
        if abs(hx - zone_center) < 20 then
          valid = false
          break
        end
      end

      -- check distance from asteroids near surface (must be at least 20px away)
      for a in all(asteroids) do
        if a.y > surface_y - 30 then  -- only check asteroids near surface
          local dx = hx - a.x
          if abs(dx) < a.r + 15 then
            valid = false
            break
          end
        end
      end

      -- check distance from other hazard zones (must be at least 25px apart)
      for h in all(hazard_zones) do
        if abs(hx - h.x) < 25 then
          valid = false
          break
        end
      end
    until valid or attempts > 30

    if valid then
      -- determine hazard type based on level and difficulty
      local htype = "thermal"  -- default
      if level >= 3 then
        local roll = rnd(100)
        if level == 3 then
          -- level 3: 30% ice, 70% thermal
          if roll < 30 then htype = "ice" end
        elseif level == 4 then
          -- level 4: 25% ice, 25% radiation, 50% thermal
          if roll < 25 then
            htype = "ice"
          elseif roll < 50 then
            htype = "radiation"
          end
        else
          -- level 5+: 20% each (ice, radiation, magnetic), 40% thermal
          if difficulty == 2 then
            -- hard mode: more variety
            if roll < 25 then
              htype = "ice"
            elseif roll < 50 then
              htype = "radiation"
            elseif roll < 75 then
              htype = "magnetic"
            end
          else
            if roll < 20 then
              htype = "ice"
            elseif roll < 40 then
              htype = "radiation"
            elseif roll < 60 then
              htype = "magnetic"
            end
          end
        end
      end

      add(hazard_zones, {
        x = hx,
        y = hy,
        r = 6,  -- radius
        anim = rnd(1),  -- animation offset for variation
        type = htype
      })
      _log("hazard:spawn:"..htype..":"..flr(hx)..","..flr(hy))
    end
  end

  particles = {}

  -- spawn boss in levels 3, 4, 5
  boss = nil
  boss_projectiles = {}
  enemy_projectiles = {}
  if level >= 3 then
    local bx = 80 + rnd(20)  -- spawn in middle-right area
    local by = 100 + rnd(surface_y - 200)  -- random vertical position

    -- boss type properties based on level
    local boss_type = level  -- 3=standard, 4=heavy, 5=elite
    local boss_col, boss_r, boss_vx, attack_mult

    if level == 3 then
      -- standard lander (red/orange)
      boss_col = 8  -- red
      boss_r = 8
      boss_vx = 0.2 + rnd(0.1)  -- 0.2-0.3
      attack_mult = 1.0
    elseif level == 4 then
      -- heavy interceptor (purple/magenta) - larger, slower attacks
      boss_col = 2  -- magenta
      boss_r = 12  -- 1.5x larger
      boss_vx = 0.15 + rnd(0.05)  -- 0.15-0.2 (slower)
      attack_mult = 1.2  -- 20% slower attacks
    else
      -- elite guardian (yellow/gold) - smaller, faster
      boss_col = 10  -- yellow
      boss_r = 6  -- 0.75x smaller
      boss_vx = 0.3 + rnd(0.15)  -- 0.3-0.45 (faster)
      attack_mult = 0.9  -- 10% faster attacks
    end

    -- attack cooldown based on difficulty: easy=240f (4s), normal=180f (3s), hard=120f (2s)
    local attack_cooldowns = {240, 180, 120}
    local attack_cooldown = flr(attack_cooldowns[difficulty + 1] * attack_mult)

    boss = {
      x = bx,
      y = by,
      vx = boss_vx,
      r = boss_r,
      hp = 3,  -- takes 3 hits
      max_hp = 3,
      patrol_min = 16,
      patrol_max = 112,
      col = boss_col,
      anim = 0,  -- animation timer
      spawn_timer = 30,  -- entrance effect timer
      attack_timer = attack_cooldown,  -- time until next attack
      attack_telegraph = 0,  -- telegraph effect countdown
      attack_cooldown = attack_cooldown,  -- store for reset
      attack_pattern = 0,  -- 0=burst, 1=aimed, 2=ring, 3=homing
      phase2 = false,  -- phase 2 flag
      telegraph_col = 10,  -- telegraph warning color (pattern-based)
      boss_type = boss_type  -- track boss variant
    }

    _log("boss:spawn:"..flr(bx)..","..flr(by)..":level:"..level..":type:"..boss_type)

    -- boss spawn sfx (warning)
    sfx(7, -1, 12)  -- higher pitch warning

    -- boss spawn particles (glow effect)
    for i = 1, 15 do
      add(particles, {
        x = bx,
        y = by,
        vx = rnd(2) - 1,
        vy = rnd(2) - 1,
        life = 25,
        col = boss_col
      })
    end
  end
end

function update_enemies()
  for e in all(enemies) do
    if e.patrol_type == 0 then
      -- horizontal patrol
      e.x += e.vx
      if e.x < e.patrol_min or e.x > e.patrol_max then
        e.vx = -e.vx  -- reverse direction
      end
    else
      -- vertical patrol
      e.y += e.vy
      if e.y < e.patrol_min or e.y > e.patrol_max then
        e.vy = -e.vy  -- reverse direction
      end
    end

    -- enemy firing system
    e.fire_timer -= 1
    if e.fire_timer <= 20 then
      e.telegraph_timer = e.fire_timer
    end
    if e.fire_timer <= 0 then
      -- fire projectile toward player
      enemy_fire_projectile(e)
      e.fire_timer = e.fire_rate
      e.telegraph_timer = 0
    end
  end

  -- update boss
  if boss then
    -- decrement spawn timer
    if boss.spawn_timer > 0 then
      boss.spawn_timer -= 1
    end

    -- horizontal patrol
    boss.x += boss.vx
    if boss.x < boss.patrol_min or boss.x > boss.patrol_max then
      boss.vx = -boss.vx  -- reverse direction
    end

    -- update animation timer
    boss.anim += 0.05

    -- attack system (only attack after spawn animation)
    if boss.spawn_timer == 0 then
      -- handle telegraph countdown
      if boss.attack_telegraph > 0 then
        boss.attack_telegraph -= 1

        -- repeating charging sound (every 10 frames for audio reinforcement)
        if boss.attack_telegraph % 10 == 0 and boss.attack_telegraph > 0 then
          local pitch_offsets = {0, 4, -4, 8}
          sfx(8, -1, pitch_offsets[boss.attack_pattern + 1] + 2)  -- slight pitch up
        end

        if boss.attack_telegraph == 0 then
          -- fire attack
          boss_fire_attack()
          boss.attack_timer = boss.attack_cooldown  -- reset attack timer
        end
      else
        -- countdown to next attack
        boss.attack_timer -= 1
        if boss.attack_timer <= 0 then
          -- elite boss in phase 2: reduced telegraph time (unpredictable)
          local telegraph_time = 45  -- default
          if boss.phase2 and boss.boss_type == 5 then
            telegraph_time = 30  -- faster attacks for elite
          end
          boss.attack_telegraph = telegraph_time

          -- select pattern: phase 2 can use homing (pattern 3)
          local max_pattern = boss.phase2 and 4 or 3
          boss.attack_pattern = flr(rnd(max_pattern))  -- random pattern

          -- set telegraph color based on attack pattern
          -- pattern 0 (burst): yellow, 1 (aimed): red, 2 (ring): cyan, 3 (homing): orange
          local telegraph_colors = {10, 8, 12, 9}
          boss.telegraph_col = telegraph_colors[boss.attack_pattern + 1]

          _log("boss:telegraph:pattern:"..boss.attack_pattern..":type:"..boss.boss_type)

          -- attack warning sfx with pitch variation per pattern
          local pitch_offsets = {0, 4, -4, 8}  -- different pitch per pattern
          sfx(8, -1, pitch_offsets[boss.attack_pattern + 1])
        end
      end
    end
  end

  -- update boss projectiles
  for p in all(boss_projectiles) do
    p.x += p.vx
    p.y += p.vy
    -- remove projectiles that go off-screen
    if p.x < 0 or p.x > 128 or p.y < 0 or p.y > 128 then
      del(boss_projectiles, p)
    end
  end

  -- update enemy projectiles
  for p in all(enemy_projectiles) do
    p.x += p.vx
    p.y += p.vy
    -- remove projectiles that go off-screen
    if p.x < 0 or p.x > 128 or p.y < 0 or p.y > 128 then
      del(enemy_projectiles, p)
    end
  end
end

function update_play()
  if not ship.alive then
    -- wait for input after crash
    if test_inputp(4) or test_inputp(5) then
      -- skip records/achievements in practice mode
      if game_mode ~= "practice" then
        check_and_save_records()

        -- check if player made leaderboard
        player_rank = get_leaderboard_rank(score)
        if player_rank > 0 then
          player_name = "AAA"
          name_entry_pos = 0
          state = "name_entry"
          _log("state:name_entry:rank:"..player_rank)
          return
        end
      end

      state = "gameover"
      _log("state:gameover:practice:"..tostr(game_mode == "practice"))
    end
    return
  end

  -- check for pause (X button)
  if test_inputp(5) then
    state = "pause"
    _log("state:pause")
    return
  end

  -- time attack timer countdown
  if game_mode == "time_attack" then
    local elapsed = t() - time_attack_start_time
    time_attack_timer = max(0, 240 - elapsed)

    -- warning at 30 seconds
    if time_attack_timer <= 30 and time_attack_timer > 0 and not time_warning_played then
      sfx(6)  -- warning sound
      time_warning_played = true
      _log("time_attack:warning:30s")
    end

    -- time's up - instant loss
    if time_attack_timer <= 0 then
      ship.alive = false
      shake_frames = 15
      shake_intensity = 3
      _log("time_attack:timeout")

      -- particle explosion
      for i = 1, 30 do
        add(particles, {
          x = ship.x,
          y = ship.y,
          vx = rnd(6) - 3,
          vy = rnd(6) - 3,
          life = 40,
          col = 8
        })
      end
    end
  end

  -- calculate proximity to nearest hazard zone (for visual/audio feedback)
  nearest_hazard_dist = 999
  for h in all(hazard_zones) do
    local dx = ship.x - h.x
    local dy = ship.y - h.y
    local dist = sqrt(dx * dx + dy * dy)
    if dist < nearest_hazard_dist then
      nearest_hazard_dist = dist
    end
  end

  -- proximity warning audio (optional - plays when within detection radius)
  local hazard_detection_radius = 40  -- distance threshold for audio warning
  if nearest_hazard_dist < hazard_detection_radius and ship.alive then
    -- play warning sound with pitch based on proximity (closer = higher pitch)
    if hazard_warning_timer <= 0 then
      local proximity_factor = 1 - (nearest_hazard_dist / hazard_detection_radius)  -- 0 to 1
      local pitch_offset = flr(proximity_factor * 8)  -- 0 to 8
      sfx(21, 3, pitch_offset)  -- channel 3 for ambient effects
      hazard_warning_timer = 15  -- cooldown to avoid spam
      _log("hazard:proximity_warning:"..flr(nearest_hazard_dist))
    end
  end

  -- update hazard warning timer
  if hazard_warning_timer > 0 then
    hazard_warning_timer -= 1
  end

  -- update ice slowdown timer
  if ship.ice_timer > 0 then
    ship.ice_timer -= 1
    if ship.ice_timer == 0 then
      _log("ice:slowdown:end")
    end
  end

  -- radiation zone fuel drain (proximity-based)
  ship.near_magnetic = false
  for h in all(hazard_zones) do
    local dx = ship.x - h.x
    local dy = ship.y - h.y
    local dist = sqrt(dx * dx + dy * dy)

    if h.type == "radiation" and dist < 40 and ship.alive then
      -- shield cannot protect against radiation
      -- drain fuel when within 40px (1 fuel per frame when very close)
      local drain_rate = max(0, 1 - (dist / 40))  -- 0 to 1
      if ship.fuel > 0 and drain_rate > 0.5 then
        ship.fuel -= 1
        if ship.fuel % 10 == 0 then  -- log every 10 fuel
          _log("radiation:fuel_drain:"..ship.fuel)
        end
      end
    elseif h.type == "magnetic" and dist < 50 and ship.alive then
      -- check for shield (blocks magnetic pull)
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then
          shield_active = true
          break
        end
      end

      if not shield_active then
        -- apply attractive force toward magnetic center
        local angle_to_mag = atan2(dy, dx)
        ship.vx += cos(angle_to_mag) * 0.8
        ship.vy += sin(angle_to_mag) * 0.8
        ship.near_magnetic = true
      end
    end
  end

  -- update enemies
  update_enemies()

  -- update active power-ups
  for p in all(active_powerups) do
    if p.time then
      p.time -= 1

      -- expiry warning flash (2 blinks in last 2 seconds)
      if p.time == 120 or p.time == 90 or p.time == 60 or p.time == 30 then
        shake_frames = 2
        shake_intensity = 0.15
      end

      -- remove expired
      if p.time <= 0 then
        del(active_powerups, p)
        _log("powerup:expired:type"..p.type)
      end
    end
  end

  -- rotation (affected by ice slowdown)
  local rotation_speed = 0.02
  if ship.ice_timer > 0 then
    rotation_speed = rotation_speed * 0.5  -- 50% slowdown from ice
  end

  if test_input(0) then  -- left
    ship.angle = (ship.angle - rotation_speed) % 1
  end
  if test_input(1) then  -- right
    ship.angle = (ship.angle + rotation_speed) % 1
  end

  -- thrust
  ship.thrusting = false
  if test_input(2) and ship.fuel > 0 then  -- up
    ship.thrusting = true
    ship.fuel -= 1

    -- apply thrust force (check for rocket boost)
    local thrust = 0.4
    for p in all(active_powerups) do
      if p.type == 3 then  -- rocket boost
        thrust = thrust * 3
        break
      end
    end
    ship.vx += cos(ship.angle) * thrust
    ship.vy += sin(ship.angle) * thrust

    -- thrust particles
    local px = ship.x - cos(ship.angle) * 6
    local py = ship.y - sin(ship.angle) * 6
    for i = 1, 3 do
      add(particles, {
        x = px,
        y = py,
        vx = -cos(ship.angle) * 2 + rnd(1) - 0.5,
        vy = -sin(ship.angle) * 2 + rnd(1) - 0.5,
        life = 8,
        col = 10
      })
    end

    -- thrust sfx (limit frequency)
    if thrust_sfx_timer == 0 then
      sfx(0)
      thrust_sfx_timer = 8
      _log("thrust:sfx")
    end

    _log("thrust")
  end

  -- gravity (check for gravity reducer)
  local grav = ship.gravity
  for p in all(active_powerups) do
    if p.type == 4 then  -- gravity reducer
      grav = grav * 0.5
      break
    end
  end
  ship.vy += grav

  -- movement
  ship.x += ship.vx
  ship.y += ship.vy

  -- update camera to follow ship smoothly
  local target_y = ship.y - 60
  camera_y += (target_y - camera_y) * 0.1

  -- clamp camera
  camera_y = max(0, camera_y)  -- don't go above world origin
  camera_y = min(camera_y, surface_y - 64)  -- keep surface visible

  -- log camera at milestones
  local cam_floor = flr(camera_y)
  if cam_floor % 50 == 0 and cam_floor > 0 and abs(cam_floor - last_cam_log) > 1 then
    _log("camera:"..cam_floor)
    last_cam_log = cam_floor
  end

  -- horizontal bounds check
  if ship.x < 0 or ship.x > 128 then
    ship.alive = false
    _log("crash:outofbounds")
    do_crash()
    return
  end

  -- collision with asteroids
  for a in all(asteroids) do
    local dx = ship.x - a.x
    local dy = ship.y - a.y
    if sqrt(dx * dx + dy * dy) < 4 + a.r then
      -- check for shield
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then  -- shield type
          shield_active = true
          shield_used_this_game = true
          del(active_powerups, p)
          _log("shield:absorbed:asteroid")

          -- shield absorption particles (red)
          for i = 1, 15 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(3) - 1.5,
              vy = rnd(3) - 1.5,
              life = 20,
              col = 8
            })
          end

          -- shield absorption sfx
          sfx(6)

          -- screen shake
          shake_frames = 5
          shake_intensity = 0.5

          break
        end
      end

      if not shield_active then
        ship.alive = false
        collision_count += 1
        _log("crash:asteroid")
        do_crash()
        return
      end
    end
  end

  -- collision with enemies
  for e in all(enemies) do
    local dx = ship.x - e.x
    local dy = ship.y - e.y
    if sqrt(dx * dx + dy * dy) < 4 + e.r then
      -- check for shield
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then  -- shield type
          shield_active = true
          shield_used_this_game = true
          del(active_powerups, p)
          _log("shield:absorbed:enemy")

          -- shield absorption particles (red)
          for i = 1, 15 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(3) - 1.5,
              vy = rnd(3) - 1.5,
              life = 20,
              col = 8
            })
          end

          -- shield absorption sfx
          sfx(6)

          -- screen shake
          shake_frames = 5
          shake_intensity = 0.5

          break
        end
      end

      if not shield_active then
        ship.alive = false
        collision_count += 1
        _log("crash:enemy")
        do_crash()
        return
      end
    end
  end

  -- collision with boss
  if boss and boss.spawn_timer == 0 then
    local dx = ship.x - boss.x
    local dy = ship.y - boss.y
    if sqrt(dx * dx + dy * dy) < 4 + boss.r then
      -- check for shield
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then  -- shield type
          shield_active = true
          shield_used_this_game = true
          del(active_powerups, p)
          boss.hp -= 1
          _log("shield:absorbed:boss:hp:"..boss.hp)

          -- check for phase 2 trigger
          if boss.hp <= 2 and not boss.phase2 then
            boss.phase2 = true
            -- phase 2 color: orange for all types
            boss.col = 9  -- orange
            _log("boss:phase2:type:"..boss.boss_type)

            -- phase 2 transformation effects
            sfx(10)  -- phase 2 sfx
            shake_frames = 6
            shake_intensity = 0.8

            -- phase 2 particles (25+ fast particles)
            for i = 1, 30 do
              add(particles, {
                x = boss.x,
                y = boss.y,
                vx = (rnd(5) - 2.5) * 1.5,
                vy = (rnd(5) - 2.5) * 1.5,
                life = 30,
                col = 9  -- orange
              })
            end

            -- boss type specific phase 2 enhancements
            if boss.boss_type == 3 then
              -- standard: double speed, 60% cooldown
              boss.vx = boss.vx * 2
              boss.attack_cooldown = flr(boss.attack_cooldown * 0.6)
            elseif boss.boss_type == 4 then
              -- heavy: moderate speed increase, 67% cooldown (1.5x frequency)
              boss.vx = boss.vx * 1.5
              boss.attack_cooldown = flr(boss.attack_cooldown * 0.67)
            else
              -- elite: triple speed, 50% cooldown
              boss.vx = boss.vx * 3
              boss.attack_cooldown = flr(boss.attack_cooldown * 0.5)
            end
          end

          -- shield absorption particles (boss color)
          for i = 1, 15 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(3) - 1.5,
              vy = rnd(3) - 1.5,
              life = 20,
              col = boss.col
            })
          end

          -- shield absorption sfx
          sfx(6)

          -- screen shake
          shake_frames = 5
          shake_intensity = 0.5

          -- check if boss defeated
          if boss.hp <= 0 then
            do_boss_defeat()
          end

          break
        end
      end

      if not shield_active then
        ship.alive = false
        collision_count += 1
        _log("crash:boss")
        do_crash()
        return
      end
    end
  end

  -- collision with boss projectiles
  for proj in all(boss_projectiles) do
    local dx = ship.x - proj.x
    local dy = ship.y - proj.y
    if sqrt(dx * dx + dy * dy) < 4 + proj.r then
      -- check for shield
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then  -- shield type
          shield_active = true
          shield_used_this_game = true
          del(active_powerups, p)
          del(boss_projectiles, proj)
          _log("shield:absorbed:projectile")

          -- shield absorption particles
          for i = 1, 8 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(2) - 1,
              vy = rnd(2) - 1,
              life = 15,
              col = 11
            })
          end

          -- shield absorption sfx
          sfx(6)

          -- screen shake
          shake_frames = 3
          shake_intensity = 0.3

          break
        end
      end

      if not shield_active then
        ship.alive = false
        collision_count += 1
        _log("crash:projectile")
        del(boss_projectiles, proj)
        do_crash()
        return
      end
    end
  end

  -- collision with enemy projectiles
  for proj in all(enemy_projectiles) do
    local dx = ship.x - proj.x
    local dy = ship.y - proj.y
    if sqrt(dx * dx + dy * dy) < 4 + proj.r then
      -- check for shield
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then  -- shield type
          shield_active = true
          shield_used_this_game = true
          del(active_powerups, p)
          del(enemy_projectiles, proj)
          _log("shield:absorbed:enemy_projectile")

          -- shield absorption particles
          for i = 1, 8 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(2) - 1,
              vy = rnd(2) - 1,
              life = 15,
              col = 11
            })
          end

          -- shield absorption sfx
          sfx(6)

          -- screen shake
          shake_frames = 3
          shake_intensity = 0.3

          break
        end
      end

      if not shield_active then
        ship.alive = false
        collision_count += 1
        _log("crash:enemy_projectile")
        del(enemy_projectiles, proj)
        do_crash()
        return
      end
    end
  end

  -- collision with hazard zones (type-specific effects)
  for h in all(hazard_zones) do
    local dx = ship.x - h.x
    local dy = ship.y - h.y
    local dist = sqrt(dx * dx + dy * dy)

    -- contact collision (thermal and ice only)
    if dist < 4 + h.r and (h.type == "thermal" or h.type == "ice") then
      -- check for shield
      local shield_active = false
      for p in all(active_powerups) do
        if p.type == 1 then  -- shield type
          shield_active = true
          shield_used_this_game = true
          del(active_powerups, p)
          _log("shield:absorbed:"..h.type)

          -- shield absorption particles (type-specific colors)
          local pcol1, pcol2
          if h.type == "ice" then
            pcol1, pcol2 = 12, 6  -- cyan/light blue
          else
            pcol1, pcol2 = 8, 9  -- red/orange
          end
          for i = 1, 15 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(3) - 1.5,
              vy = rnd(3) - 1.5,
              life = 20,
              col = (i % 2 == 0) and pcol1 or pcol2
            })
          end

          -- shield absorption sfx
          sfx(6)

          -- screen shake
          shake_frames = 5
          shake_intensity = 0.5

          break
        end
      end

      if not shield_active then
        if h.type == "thermal" then
          -- thermal: instant death
          ship.alive = false
          collision_count += 1
          _log("crash:hazard:thermal")
          do_crash()
          return
        elseif h.type == "ice" then
          -- ice: apply slowdown effect (50% rotation for 2 seconds = 60 frames)
          ship.ice_timer = 60
          _log("ice:slowdown")
          sfx(11)  -- distinct ice sfx

          -- ice particles
          for i = 1, 10 do
            add(particles, {
              x = ship.x,
              y = ship.y,
              vx = rnd(2) - 1,
              vy = rnd(2) - 1,
              life = 15,
              col = 12  -- cyan
            })
          end
        end
      end
    end
  end

  -- collision with fuel pickups
  for pickup in all(fuel_pickups) do
    local dx = ship.x - pickup.x
    local dy = ship.y - pickup.y
    if sqrt(dx * dx + dy * dy) < 8 then
      -- collect fuel pickup
      local fuel_restore = 10 + rnd(11)  -- 10-20 fuel
      local bonus_points = 25 + rnd(26)  -- 25-50 points
      ship.fuel += fuel_restore
      score += flr(bonus_points)

      _log("fuel_pickup:collect:fuel+"..flr(fuel_restore)..":score+"..flr(bonus_points))

      -- pickup particles
      for i = 1, 10 do
        add(particles, {
          x = pickup.x,
          y = pickup.y,
          vx = rnd(2) - 1,
          vy = rnd(2) - 1,
          life = 15,
          col = 10
        })
      end

      -- pickup sfx
      sfx(4)

      -- screen shake
      shake_frames = 4
      shake_intensity = 0.3

      -- remove pickup
      del(fuel_pickups, pickup)
    end
  end

  -- collision with power-ups
  for pup in all(powerups) do
    local dx = ship.x - pup.x
    local dy = ship.y - pup.y
    if sqrt(dx * dx + dy * dy) < 8 then
      -- check if already have this type
      local already_have = false
      for ap in all(active_powerups) do
        if ap.type == pup.type then
          already_have = true
          break
        end
      end

      if not already_have then
        -- collect power-up
        local ptype = pup.type
        local pname = ({"shield", "fuel_restorer", "rocket_boost", "gravity_reducer"})[ptype]
        local pcol = ({8, 12, 9, 11})[ptype]  -- red, blue, orange, cyan

        _log("powerup:collect:type"..ptype..":"..pname)

        -- instant effects
        if ptype == 2 then
          -- fuel restorer: instant refill
          local fuel_table = {80, 70, 60, 50, 40}
          local fuel_mult = {1.15, 1.0, 0.8}
          local max_fuel = flr((fuel_table[level] or 40) * fuel_mult[difficulty + 1])
          ship.fuel = max_fuel
          _log("powerup:fuel_restorer:refill:"..max_fuel)
        else
          -- add to active power-ups with timer
          local duration = ({0, 0, 600, 720})[ptype]  -- shield=no timer, fuel=no timer, boost=10s, gravity=12s
          add(active_powerups, {
            type = ptype,
            time = duration
          })
        end

        -- power-up particles (color-coded)
        for i = 1, 12 do
          add(particles, {
            x = pup.x,
            y = pup.y,
            vx = rnd(2.5) - 1.25,
            vy = rnd(2.5) - 1.25,
            life = 18,
            col = pcol
          })
        end

        -- power-up sfx (pitch varies by type)
        sfx(5, -1, ptype * 2)

        -- screen shake
        shake_frames = 3
        shake_intensity = 0.25

        -- remove power-up
        del(powerups, pup)
      end
    end
  end

  -- collision with surface
  if ship.y >= surface_y - 4 then
    local landed = false
    local velocity = sqrt(ship.vx * ship.vx + ship.vy * ship.vy)

    -- difficulty-based velocity threshold
    local vel_thresh = {3.0, 2.0, 2.0}  -- easy, normal, hard

    -- check landing zones
    for z in all(landing_zones) do
      if ship.x >= z.x and ship.x <= z.x + z.w then
        if velocity < vel_thresh[difficulty + 1] and (abs(ship.angle) < 0.1 or abs(ship.angle - 1) < 0.1) then
          -- successful landing
          landed = true
          do_landing(velocity, z.x, z.w)
          break
        end
      end
    end

    if not landed then
      -- crashed
      ship.alive = false
      _log("crash:surface:velocity:"..flr(velocity * 10))
      do_crash()
    end
  end

  -- out of fuel check
  if ship.fuel <= 0 and ship.y < surface_y - 10 then
    -- check if drifting to death
    if ship.vy > 3 then
      ship.alive = false
      _log("crash:nofuel")
      do_crash()
    end
  end
end

function do_landing(velocity, zone_x, zone_w)
  _log("landing:velocity:"..flr(velocity * 10))

  -- landing sfx
  sfx(1)

  -- calculate base score
  local base = 100
  local fuel_bonus = ship.fuel * 5
  local speed_bonus = (velocity < 1) and 20 or 0
  chain += 1
  local chain_multiplier = min(1 + (chain - 1) * 0.5, 2)

  -- difficulty score multipliers
  local diff_mult = {0.8, 1.0, 1.5}  -- easy, normal, hard

  -- precision bonuses
  local precision_bonuses = 0

  -- 1. soft landing bonus (velocity < 0.5)
  if velocity < 0.5 then
    local soft_bonus = 50
    precision_bonuses += soft_bonus
    soft_landing_count += 1
    total_soft_landings += 1
    consecutive_soft_landings += 1
    _log("bonus:soft_landing:"..soft_bonus)

    -- gold particles
    for i = 1, 12 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = rnd(2) - 1,
        vy = rnd(2) - 1,
        life = 25,
        col = 10  -- gold
      })
    end

    sfx(16)  -- soft landing sfx
  else
    -- reset consecutive soft landings if not a soft landing
    consecutive_soft_landings = 0
  end

  -- 2. fuel efficiency bonus (>60% fuel)
  local fuel_table = {80, 70, 60, 50, 40}
  local fuel_mult = {1.15, 1.0, 0.8}
  local max_fuel = flr((fuel_table[level] or 40) * fuel_mult[difficulty + 1])
  local fuel_pct = ship.fuel / max_fuel

  if fuel_pct > 0.6 then
    local fuel_eff_bonus = flr(ship.fuel * 3)
    precision_bonuses += fuel_eff_bonus
    fuel_efficiency_count += 1
    total_fuel_efficiency_landings += 1
    _log("bonus:fuel_efficiency:"..fuel_eff_bonus)

    -- cyan particles
    for i = 1, 10 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = rnd(2) - 1,
        vy = rnd(2) - 1,
        life = 20,
        col = 12  -- cyan
      })
    end

    sfx(17)  -- fuel efficiency sfx
  end

  -- 3. precision landing bonus (center third of zone)
  local zone_center = zone_x + zone_w / 2
  local zone_third = zone_w / 3
  local dist_from_center = abs(ship.x - zone_center)

  if dist_from_center < zone_third / 2 then
    local precision_bonus = 75
    precision_bonuses += precision_bonus
    precision_landing_count += 1
    total_precision_landings += 1
    _log("bonus:precision_landing:"..precision_bonus)

    -- white star burst
    for i = 1, 8 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = cos(i / 8) * 2,
        vy = sin(i / 8) * 2,
        life = 18,
        col = 7  -- white
      })
    end

    sfx(18)  -- precision landing sfx
  end

  -- 4. perfect run bonus (no collisions this level)
  if collision_count == 0 then
    local perfect_bonus = 100
    precision_bonuses += perfect_bonus
    perfect_run_count += 1
    total_perfect_runs += 1
    _log("bonus:perfect_run:"..perfect_bonus)

    -- rainbow particles
    for i = 1, 15 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = rnd(3) - 1.5,
        vy = rnd(3) - 1.5,
        life = 30,
        col = 8 + (i % 8)  -- rainbow colors
      })
    end

    sfx(19)  -- perfect run sfx
  end

  -- 5. hazard near-miss bonus (landed within 10px of any hazard)
  local nearest_hazard_dist = 999
  local nearest_hazard_type = nil
  for h in all(hazard_zones) do
    local dist = abs(ship.x - h.x)
    if dist < nearest_hazard_dist then
      nearest_hazard_dist = dist
      nearest_hazard_type = h.type
    end
  end

  if nearest_hazard_dist < 10 then
    local near_miss_bonus = 25 + rnd(16)  -- 25-40 points
    precision_bonuses += flr(near_miss_bonus)
    total_hazard_landings += 1
    _log("bonus:hazard_near_miss:"..nearest_hazard_type..":"..flr(near_miss_bonus))

    -- achievement tracking
    if nearest_hazard_type == "ice" then
      total_ice_landings += 1
    elseif nearest_hazard_type == "magnetic" and ship.near_magnetic then
      total_magnetic_landings += 1
      _log("magnetic:assisted_landing")
    end

    -- type-specific warning particles
    local pcol1, pcol2
    if nearest_hazard_type == "ice" then
      pcol1, pcol2 = 12, 6  -- cyan/light blue
    elseif nearest_hazard_type == "radiation" then
      pcol1, pcol2 = 10, 11  -- yellow/green
    elseif nearest_hazard_type == "magnetic" then
      pcol1, pcol2 = 15, 13  -- purple/lavender
    else
      pcol1, pcol2 = 8, 9  -- red/orange (thermal)
    end

    for i = 1, 10 do
      add(particles, {
        x = ship.x,
        y = ship.y,
        vx = rnd(2.5) - 1.25,
        vy = rnd(2.5) - 1.25,
        life = 22,
        col = (i % 2 == 0) and pcol1 or pcol2
      })
    end

    sfx(20)  -- near-miss warning sfx
  end

  -- apply multipliers to bonuses
  local multiplied_bonuses = flr(precision_bonuses * chain_multiplier * diff_mult[difficulty + 1])
  total_bonuses += multiplied_bonuses

  -- time attack speed multiplier (1.0x base, 1.5x if <18s)
  local speed_mult = 1.0
  if game_mode == "time_attack" then
    local level_time = t() - time_attack_level_start
    if level_time < 18 then
      speed_mult = 1.5
      _log("time_attack:speed_bonus:1.5x:"..flr(level_time).."s")
    else
      _log("time_attack:level_time:"..flr(level_time).."s")
    end
  end

  -- calculate total landing score
  local landing_score = flr((base + fuel_bonus + speed_bonus) * chain_multiplier * diff_mult[difficulty + 1] * speed_mult) + multiplied_bonuses
  score += landing_score
  total_fuel_saved += ship.fuel

  -- track best landing
  if landing_score > best_landing_score then
    best_landing_score = landing_score
    _log("best_landing:"..best_landing_score)
  end

  _log("score:"..score)
  _log("chain:"..chain)

  -- check chain milestones
  if chain >= 10 and last_chain_milestone < 10 then
    sfx(6)
    last_chain_milestone = 10
    _log("chain:milestone:10")
  elseif chain >= 5 and last_chain_milestone < 5 then
    sfx(5)
    last_chain_milestone = 5
    _log("chain:milestone:5")
  elseif chain >= 3 and last_chain_milestone < 3 then
    sfx(4)
    last_chain_milestone = 3
    _log("chain:milestone:3")
  end

  -- landing particles
  for i = 1, 15 do
    add(particles, {
      x = ship.x,
      y = ship.y,
      vx = rnd(2) - 1,
      vy = rnd(2) - 1,
      life = 20,
      col = 11
    })
  end

  -- shake
  shake_frames = 6
  shake_intensity = 0.5

  -- check for achievements
  check_achievements()

  -- advance level (always increment on successful landing)
  level += 1
  sfx(3)  -- level up sfx
  _log("levelup:level"..level)

  -- check win condition
  if game_mode == "practice" then
    -- practice mode: complete after one level
    state = "gameover"
    _log("state:gameover:practice_complete")
    music(3)  -- victory music
  elseif level >= 6 then
    -- game complete (normal/time attack modes)
    check_and_save_records()

    -- check if player made leaderboard
    player_rank = get_leaderboard_rank(score)
    if player_rank > 0 then
      player_name = "AAA"
      name_entry_pos = 0
      state = "name_entry"
      _log("state:name_entry:rank:"..player_rank)
    else
      state = "gameover"
      _log("state:gameover:win")
    end

    music(3)  -- victory music
  else
    -- continue to next level
    init_level()
  end
end

function enemy_fire_projectile(e)
  -- calculate direction to player with slight lead
  local dx = ship.x - e.x
  local dy = ship.y - e.y

  -- add velocity prediction for better aiming
  dx += ship.vx * 5
  dy += ship.vy * 5

  -- normalize direction
  local dist = sqrt(dx * dx + dy * dy)
  if dist > 0 then
    dx /= dist
    dy /= dist
  end

  -- projectile speed based on difficulty
  local proj_speeds = {1.2, 1.5, 1.8}  -- easy, normal, hard
  local speed = proj_speeds[difficulty + 1]

  add(enemy_projectiles, {
    x = e.x,
    y = e.y,
    vx = dx * speed,
    vy = dy * speed,
    r = 1,
    col = 9  -- orange like enemy
  })

  _log("enemy:fire")
  sfx(9, -1, 8)  -- projectile fire sfx with pitch offset
end

function boss_fire_attack()
  if not boss then return end

  -- projectile counts based on difficulty: easy=3, normal=4, hard=5
  local projectile_counts = {3, 4, 5}
  local proj_count = projectile_counts[difficulty + 1]

  -- phase 2 speed multiplier (+20%)
  local speed_mult = boss.phase2 and 1.2 or 1.0

  -- attack sfx
  sfx(9)
  _log("boss:attack:pattern:"..boss.attack_pattern)

  -- boss flash effect
  boss.flash_timer = 5

  -- screen shake (enhanced in phase 2)
  shake_frames = boss.phase2 and 5 or 3
  shake_intensity = boss.phase2 and 0.5 or 0.3

  if boss.attack_pattern == 0 then
    -- burst spray (8-way spread)
    for i = 0, 7 do
      local angle = i / 8
      add(boss_projectiles, {
        x = boss.x,
        y = boss.y,
        vx = cos(angle) * 1.5 * speed_mult,
        vy = sin(angle) * 1.5 * speed_mult,
        r = 2,
        col = boss.col
      })
    end
  elseif boss.attack_pattern == 1 then
    -- aimed burst (proj_count shots toward player)
    local dx = ship.x - boss.x
    local dy = ship.y - boss.y
    local base_angle = atan2(dx, dy)
    for i = 1, proj_count do
      local spread = (i - (proj_count + 1) / 2) * 0.03  -- slight spread
      local angle = base_angle + spread
      add(boss_projectiles, {
        x = boss.x,
        y = boss.y,
        vx = cos(angle) * 2.0 * speed_mult,
        vy = sin(angle) * 2.0 * speed_mult,
        r = 2,
        col = boss.col
      })
    end
  elseif boss.attack_pattern == 2 then
    -- ring pattern (12-way all directions)
    for i = 0, 11 do
      local angle = i / 12
      add(boss_projectiles, {
        x = boss.x,
        y = boss.y,
        vx = cos(angle) * 1.2 * speed_mult,
        vy = sin(angle) * 1.2 * speed_mult,
        r = 2,
        col = boss.col
      })
    end
  else
    -- homing ring (phase 2 only: 8 projectiles that curve toward player)
    local dx = ship.x - boss.x
    local dy = ship.y - boss.y
    local target_angle = atan2(dx, dy)
    for i = 0, 7 do
      local angle = i / 8
      -- blend between ring angle and target angle for homing effect
      local homing_angle = angle * 0.7 + target_angle * 0.3
      add(boss_projectiles, {
        x = boss.x,
        y = boss.y,
        vx = cos(homing_angle) * 1.8,
        vy = sin(homing_angle) * 1.8,
        r = 2,
        col = boss.col,
        homing = true,  -- mark as homing for potential future behavior
        target_angle = target_angle
      })
    end
  end
end

function do_boss_defeat()
  if not boss then return end

  -- check if phase 2 for enhanced defeat
  local is_phase2 = boss.phase2
  if is_phase2 then
    _log("boss:phase2:defeated")
  else
    _log("boss:defeated")
  end

  -- award bonus points (extra 100 for phase 2)
  local bonus = is_phase2 and 250 or 150
  score += bonus
  _log("score:"..score..":boss_bonus:"..bonus)

  -- boss defeat sfx
  if is_phase2 then
    -- extended fanfare for phase 2
    sfx(10)  -- first fanfare
    sfx(11, -1, 0)  -- second fanfare chained
  else
    sfx(2, -1, 0)  -- explosion sound
  end

  -- boss defeat particles (50+ for phase 2, 25 for normal)
  local particle_count = is_phase2 and 55 or 25
  for i = 1, particle_count do
    add(particles, {
      x = boss.x,
      y = boss.y,
      vx = rnd(4) - 2,
      vy = rnd(4) - 2,
      life = 35,
      col = boss.col
    })
  end

  -- screen shake (enhanced for phase 2)
  shake_frames = is_phase2 and 12 or 8
  shake_intensity = is_phase2 and 1.5 or 1.0

  -- track achievement progress
  bosses_defeated += 1
  if is_phase2 then
    phase2_bosses_defeated += 1
  end

  -- check for achievements
  check_achievements()

  -- remove boss
  boss = nil
end

function do_crash()
  -- track collision (skip if already counted from asteroid hit)
  if ship.alive then
    collision_count += 1
    collisions_this_game += 1
    consecutive_soft_landings = 0  -- reset consecutive soft landings
  end

  -- crash sfx and music
  sfx(2)
  music(2)  -- game over music

  -- crash particles
  for i = 1, 25 do
    add(particles, {
      x = ship.x,
      y = ship.y,
      vx = rnd(4) - 2,
      vy = rnd(4) - 2,
      life = 30,
      col = 8
    })
  end

  -- shake
  shake_frames = 12
  shake_intensity = 2

  -- reset chain
  chain = 0
  last_chain_milestone = 0
  _log("chain:reset")
end

function draw_world()
  -- draw moon surface
  rectfill(0, surface_y, 128, 128, 13)
  line(0, surface_y, 128, surface_y, 5)

  -- draw landing zones
  for z in all(landing_zones) do
    rectfill(z.x, z.y, z.x + z.w, z.y + z.h, 11)
  end

  -- draw hazard zones (type-specific visuals)
  for h in all(hazard_zones) do
    -- calculate distance from ship to this hazard
    local dx = ship.x - h.x
    local dy = ship.y - h.y
    local dist = sqrt(dx * dx + dy * dy)

    -- proximity factor: 0 (far) to 1 (very close)
    local proximity_threshold = 50
    local proximity_factor = max(0, 1 - (dist / proximity_threshold))

    if h.type == "thermal" then
      -- thermal: pulsing red/orange circles (original design)
      local pulse_speed = 1.5 + (proximity_factor * 2.5)
      local pulse = sin((t() * pulse_speed + h.anim)) * 2 + h.r
      local glow_speed = 3 + (proximity_factor * 3)
      local glow_base = 3 + (proximity_factor * 3)
      local glow = sin((t() * glow_speed + h.anim)) * 1.5 + glow_base

      local glow_col = (proximity_factor > 0.5) and 8 or 2
      circfill(h.x, h.y, glow, glow_col)

      local heat_speed = 4 + (proximity_factor * 4)
      local heat_phase = flr((t() * heat_speed + h.anim) % 2)
      local heat_col = (heat_phase == 0) and 8 or 9
      circfill(h.x, h.y, pulse, heat_col)

      local center_col = (proximity_factor > 0.7) and 7 or 10
      circfill(h.x, h.y, pulse * 0.5, center_col)

      if proximity_factor > 0.6 then
        local warning_r = h.r + 4 + sin(t() * 6) * 2
        circ(h.x, h.y, warning_r, 9)
      end

    elseif h.type == "ice" then
      -- ice: flickering cyan/light blue with fast pulse
      local pulse_speed = 4 + (proximity_factor * 4)  -- faster than thermal
      local pulse = sin((t() * pulse_speed + h.anim)) * 1.5 + h.r
      local glow = sin((t() * pulse_speed + h.anim)) * 1.5 + 4

      local glow_col = (proximity_factor > 0.5) and 6 or 1
      circfill(h.x, h.y, glow, glow_col)

      local ice_phase = flr((t() * 8 + h.anim) % 2)  -- fast flicker
      local ice_col = (ice_phase == 0) and 12 or 6  -- cyan/light blue
      circfill(h.x, h.y, pulse, ice_col)

      circfill(h.x, h.y, pulse * 0.4, 7)  -- white center

      if proximity_factor > 0.6 then
        local warning_r = h.r + 3 + sin(t() * 8) * 1.5
        circ(h.x, h.y, warning_r, 12)
      end

    elseif h.type == "radiation" then
      -- radiation: slow-pulsing yellow/green circles
      local pulse_speed = 1 + (proximity_factor * 1.5)  -- slower than thermal
      local pulse = sin((t() * pulse_speed + h.anim)) * 2.5 + h.r
      local glow = sin((t() * pulse_speed + h.anim)) * 2 + 5

      local glow_col = (proximity_factor > 0.5) and 10 or 3
      circfill(h.x, h.y, glow, glow_col)

      local rad_phase = flr((t() * 2 + h.anim) % 2)
      local rad_col = (rad_phase == 0) and 10 or 11  -- yellow/green
      circfill(h.x, h.y, pulse, rad_col)

      circfill(h.x, h.y, pulse * 0.3, 10)  -- yellow center

      if proximity_factor > 0.6 then
        local warning_r = h.r + 5 + sin(t() * 3) * 2
        circ(h.x, h.y, warning_r, 10)
      end

    elseif h.type == "magnetic" then
      -- magnetic: spiral pattern or rotating rings (purple)
      local pulse = sin((t() * 2 + h.anim)) * 1.5 + h.r
      local glow = sin((t() * 2 + h.anim)) * 2 + 4

      local glow_col = (proximity_factor > 0.5) and 2 or 0
      circfill(h.x, h.y, glow, glow_col)

      circfill(h.x, h.y, pulse, 15)  -- purple main circle

      -- rotating rings
      local angle = (t() + h.anim) % 1
      for i = 0, 3 do
        local ring_angle = (angle + i * 0.25) % 1
        local rx = h.x + cos(ring_angle) * (h.r + 3)
        local ry = h.y + sin(ring_angle) * (h.r + 3)
        circfill(rx, ry, 1, 13)  -- small purple dots
      end

      circfill(h.x, h.y, pulse * 0.3, 6)  -- light blue center

      if proximity_factor > 0.6 then
        local warning_r = h.r + 4 + sin(t() * 4) * 2
        circ(h.x, h.y, warning_r, 15)
      end
    end
  end

  -- draw asteroids
  for a in all(asteroids) do
    circfill(a.x, a.y, a.r, 8)
    circ(a.x, a.y, a.r, 2)
  end

  -- draw enemies
  for e in all(enemies) do
    -- telegraph warning (glow when about to fire)
    if e.telegraph_timer > 0 and e.telegraph_timer <= 20 then
      local glow_col = (e.telegraph_timer % 8 < 4) and 10 or 7  -- flash yellow/white
      circ(e.x, e.y, e.r + 2, glow_col)
    end

    circfill(e.x, e.y, e.r, 9)  -- orange circle
    circ(e.x, e.y, e.r, 2)  -- red outline
    -- cross marker
    line(e.x - 3, e.y, e.x + 3, e.y, 7)  -- horizontal
    line(e.x, e.y - 3, e.x, e.y + 3, 7)  -- vertical
  end

  -- draw boss
  if boss then
    -- spawn entrance effect (growing from center)
    if boss.spawn_timer > 0 then
      local grow = (30 - boss.spawn_timer) / 30
      local r = boss.r * grow
      circfill(boss.x, boss.y, r, boss.col)
      circ(boss.x, boss.y, r + 1, 7)  -- white glow
    else
      -- normal boss appearance
      -- phase 2 aura effect (semi-transparent larger circle)
      if boss.phase2 then
        local aura_r = boss.r + 4 + sin(boss.anim * 2) * 2
        circ(boss.x, boss.y, aura_r, boss.col)  -- outer aura (boss color)
        circ(boss.x, boss.y, aura_r - 1, 7)  -- white inner aura
      end

      -- telegraph warning effect (enhanced)
      local boss_draw_col = boss.col
      if boss.attack_telegraph > 0 then
        -- expanding pulse rings (more dramatic)
        local progress = (45 - boss.attack_telegraph) / 45  -- 0 to 1
        local expand_r = boss.r + 6 + progress * 8  -- expands outward

        -- outer expanding ring (pulses with telegraph color)
        circ(boss.x, boss.y, expand_r, boss.telegraph_col)
        if boss.attack_telegraph % 4 < 2 then
          circ(boss.x, boss.y, expand_r + 1, 7)  -- white accent flash
        end

        -- inner warning glow (constant)
        circ(boss.x, boss.y, boss.r + 3, boss.telegraph_col)
        circ(boss.x, boss.y, boss.r + 4, 7)  -- white glow

        -- boss color cycling during telegraph (flash warning color)
        if boss.attack_telegraph % 8 < 4 then
          boss_draw_col = boss.telegraph_col  -- alternate with pattern color
        end

        -- exclamation mark indicator (above boss, flashing)
        if boss.attack_telegraph % 6 < 3 then
          line(boss.x, boss.y - boss.r - 5, boss.x, boss.y - boss.r - 8, boss.telegraph_col)
          pset(boss.x, boss.y - boss.r - 3, boss.telegraph_col)
        end
      end

      -- flash effect when firing (overrides telegraph)
      if boss.flash_timer and boss.flash_timer > 0 then
        boss_draw_col = 7  -- white flash
        boss.flash_timer -= 1
      end

      -- outer circle (boss body)
      circfill(boss.x, boss.y, boss.r, boss_draw_col)

      -- pulsing outline
      local pulse_r = boss.r + sin(boss.anim) * 1.5
      circ(boss.x, boss.y, pulse_r, 7)  -- white pulsing outline

      -- inner circle (docking ring design)
      local inner_r = boss.r - 3
      circ(boss.x, boss.y, inner_r, 2)  -- dark inner ring

      -- HP indicator (small dots at top)
      for i = 1, boss.hp do
        pset(boss.x - 3 + (i - 1) * 3, boss.y - boss.r - 2, 11)
      end
    end
  end

  -- draw boss projectiles
  for proj in all(boss_projectiles) do
    circfill(proj.x, proj.y, proj.r, proj.col)
    circ(proj.x, proj.y, proj.r + 1, 7)  -- white outline
  end

  -- draw enemy projectiles
  for proj in all(enemy_projectiles) do
    circfill(proj.x, proj.y, proj.r, proj.col)  -- orange
    circ(proj.x, proj.y, proj.r + 1, 7)  -- white outline
  end

  -- draw fuel pickups
  for pickup in all(fuel_pickups) do
    -- pulsing animation
    local pulse = sin((t() * 2 + pickup.anim)) * 1.5 + 4.5
    circfill(pickup.x, pickup.y, pulse, 10)
    circ(pickup.x, pickup.y, pulse + 1, 9)
    -- spark effect
    if pulse > 5 then
      pset(pickup.x + 3, pickup.y, 7)
      pset(pickup.x - 3, pickup.y, 7)
      pset(pickup.x, pickup.y + 3, 7)
      pset(pickup.x, pickup.y - 3, 7)
    end
  end

  -- draw power-ups
  for pup in all(powerups) do
    -- pulsing animation
    local pulse = sin((t() * 2 + pup.anim)) * 1.5 + 4.5
    local pcol = ({8, 12, 9, 11})[pup.type]  -- red, blue, orange, cyan
    local pcol2 = ({2, 6, 4, 3})[pup.type]  -- dark variants
    circfill(pup.x, pup.y, pulse, pcol)
    circ(pup.x, pup.y, pulse + 1, pcol2)
    -- type indicator (small symbol)
    if pup.type == 1 then
      -- shield: plus sign
      line(pup.x - 2, pup.y, pup.x + 2, pup.y, 7)
      line(pup.x, pup.y - 2, pup.x, pup.y + 2, 7)
    elseif pup.type == 2 then
      -- fuel: F
      pset(pup.x - 1, pup.y - 1, 7)
      pset(pup.x, pup.y - 1, 7)
      pset(pup.x - 1, pup.y, 7)
      pset(pup.x, pup.y, 7)
      pset(pup.x - 1, pup.y + 1, 7)
    elseif pup.type == 3 then
      -- boost: up arrow
      pset(pup.x, pup.y - 1, 7)
      pset(pup.x - 1, pup.y, 7)
      pset(pup.x + 1, pup.y, 7)
    else
      -- gravity: down arrow
      pset(pup.x, pup.y + 1, 7)
      pset(pup.x - 1, pup.y, 7)
      pset(pup.x + 1, pup.y, 7)
    end
  end

  -- draw particles
  for p in all(particles) do
    pset(p.x, p.y, p.col)
  end

  -- draw ship
  if ship.alive then
    local x, y = ship.x, ship.y

    -- shield glow aura (when shield power-up is active)
    local shield_active = false
    for p in all(active_powerups) do
      if p.type == 1 then  -- shield type
        shield_active = true
        break
      end
    end

    if shield_active then
      -- pulsing animation: oscillates between 8-12px at ~2Hz
      local pulse_radius = 10 + sin(t() * 2) * 2
      -- draw concentric circles for glow effect
      circ(x, y, pulse_radius, 12)  -- outer cyan ring
      circ(x, y, pulse_radius - 1, 12)  -- middle cyan ring
      circ(x, y, pulse_radius - 2, 6)  -- inner darker blue ring
    end

    -- ship body (triangle)
    local s1x = x + cos(ship.angle) * 5
    local s1y = y + sin(ship.angle) * 5
    local s2x = x + cos(ship.angle + 0.3) * 3
    local s2y = y + sin(ship.angle + 0.3) * 3
    local s3x = x + cos(ship.angle - 0.3) * 3
    local s3y = y + sin(ship.angle - 0.3) * 3

    line(s1x, s1y, s2x, s2y, 7)
    line(s2x, s2y, s3x, s3y, 7)
    line(s3x, s3y, s1x, s1y, 7)

    -- thrust flame
    if ship.thrusting then
      local fx = x - cos(ship.angle) * 6
      local fy = y - sin(ship.angle) * 6
      line(s2x, s2y, fx, fy, 9)
      line(s3x, s3y, fx, fy, 9)
    end
  end
end

function draw_hud()
  -- draw hud in screen space (camera independent)
  local vel = sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
  local height = max(0, surface_y - ship.y)
  local angle_deg = flr((ship.angle * 360) % 360)

  print("vel:"..flr(vel * 10) / 10, 2, 2, 7)
  print("fuel:"..flr(ship.fuel), 2, 9, 7)

  -- fuel bar (calculate max based on difficulty)
  local fuel_table = {80, 70, 60, 50, 40}
  local fuel_mult = {1.15, 1.0, 0.8}
  local max_fuel = flr((fuel_table[level] or 40) * fuel_mult[difficulty + 1])
  local fuel_pct = ship.fuel / max_fuel
  rectfill(30, 10, 30 + fuel_pct * 30, 13, 8)
  rect(30, 10, 60, 13, 7)

  print("alt:"..flr(height), 2, 16, 7)
  print("ang:"..angle_deg, 2, 23, 7)
  print("lvl:"..level, 100, 2, 7)

  -- practice mode indicator
  if game_mode == "practice" then
    print("practice", 46, 123, 11)  -- cyan at bottom
    print("score:"..score, 80, 9, 6)  -- gray (non-scoring)
  else
    print("score:"..score, 80, 9, 10)
  end

  -- time attack timer
  if game_mode == "time_attack" then
    local mins = flr(time_attack_timer / 60)
    local secs = flr(time_attack_timer % 60)
    local timer_col = time_attack_timer <= 30 and 8 or 7
    print("time:"..mins..":"..secs, 84, 16, timer_col)
  end

  if chain > 1 then
    print("x"..flr((1 + (chain - 1) * 0.5) * 10) / 10, 110, 16, 11)
  end

  -- phase 2 indicator
  if boss and boss.phase2 then
    print("phase 2", 46, 2, 12)  -- cyan text, centered
  end

  -- active power-ups display
  local pup_y = 30
  for p in all(active_powerups) do
    local pname = ({"shd", "ful", "bst", "grv"})[p.type]
    local pcol = ({8, 12, 9, 11})[p.type]

    -- draw icon
    circfill(2, pup_y, 2, pcol)

    -- draw time (if applicable)
    if p.time then
      local sec = flr(p.time / 60) + 1
      print(pname..":"..sec, 6, pup_y - 2, 7)
    else
      print(pname, 6, pup_y - 2, 7)
    end

    pup_y += 6
  end

  if not ship.alive then
    print("crashed!", 40, 60, 8)
    print("press o/x", 40, 70, 7)
  end
end

-- gameover state
function update_gameover()
  if test_inputp(4) or test_inputp(5) then
    state = "menu"
    new_record = false  -- reset celebration flag
    player_rank = 0  -- reset rank display
    music(0)  -- restart menu music
    _log("state:menu")
  end
end

function draw_gameover()
  if game_mode == "practice" then
    -- practice mode gameover screen
    if ship.alive then
      print("practice complete!", 24, 20, 11)
    else
      print("practice ended", 32, 20, 8)
    end

    print("level "..practice_level, 48, 30, 7)
    print("final score: "..score, 28, 40, 6)
    print("(not saved)", 38, 48, 5)

    -- bonus breakdown
    print("bonus breakdown:", 24, 60, 6)
    print("soft landings: "..soft_landing_count, 8, 68, 7)
    print("fuel efficient: "..fuel_efficiency_count, 8, 75, 7)
    print("precision: "..precision_landing_count, 8, 82, 7)
    print("perfect runs: "..perfect_run_count, 8, 89, 7)

    print("collisions: "..collision_count, 32, 100, collision_count == 0 and 11 or 8)

    print("press o/x to menu", 20, 119, 6)
  elseif game_mode == "time_attack" then
    -- time attack gameover screen
    if level > 5 then
      print("mission complete!", 24, 20, 11)

      local total_time = t() - time_attack_start_time
      local mins = flr(total_time / 60)
      local secs = flr(total_time % 60)
      print("time: "..mins..":"..secs, 36, 28, 10)
    else
      print("time's up!", 40, 20, 8)
      print("reached level "..level, 28, 28, 7)
    end

    -- celebration for new records
    if new_record then
      print("*** new record! ***", 20, 36, 10)
    end

    print("final score: "..score, 28, 44, 7)

    -- best time record
    if time_attack_best_time > 0 then
      local mins = flr(time_attack_best_time / 60)
      local secs = flr(time_attack_best_time % 60)
      print("best time: "..mins..":"..secs, 30, 52, 11)
    end

    print("time attack stats:", 24, 64, 6)
    print("levels completed: "..(level - 1), 16, 72, 7)
    print("speed bonuses: check logs", 12, 80, 7)
  else
    -- normal mode gameover screen
    if level > 5 then
      print("mission complete!", 24, 20, 11)
    else
      print("mission failed", 32, 20, 8)
    end

    -- celebration for new records
    if new_record then
      print("*** new record! ***", 20, 28, 10)
    end

    -- show leaderboard rank
    if player_rank > 0 then
      local rank_col = player_rank == 1 and 10 or (player_rank == 2 and 12 or (player_rank == 3 and 14 or 11))
      print("you placed #"..player_rank.."!", 28, 35, rank_col)
    end

    print("final score: "..score, 28, 43, 7)
    print("best landing: "..best_landing_score, 24, 51, 10)
    print("total bonuses: "..total_bonuses, 20, 59, 10)

    -- bonus breakdown
    print("bonus breakdown:", 24, 70, 6)
    print("soft landings: "..soft_landing_count, 8, 78, 7)
    print("fuel efficient: "..fuel_efficiency_count, 8, 85, 7)
    print("precision: "..precision_landing_count, 8, 92, 7)
    print("perfect runs: "..perfect_run_count, 8, 99, 7)

    -- new achievements this session (only show if no rank display)
    if #new_achievements > 0 and player_rank == 0 then
      print("new achievements:", 20, 106, 11)
      print("\x8e "..achievement_names[new_achievements[1]], 16, 113, 10)
    elseif player_rank == 0 then
      print("achievements: "..count_achievements().."/15", 24, 110, 6)
    end
  end

  print("press o/x to restart", 16, 119, 6)
end

-- pause state
function update_pause()
  if test_inputp(5) then  -- X button - resume
    state = "play"
    _log("state:play")
  elseif test_inputp(4) then  -- O button - quit to menu
    state = "menu"
    music(0)  -- restart menu music
    _log("state:menu")
  end
end

function draw_pause()
  -- semi-transparent overlay
  rectfill(0, 0, 128, 128, 0)

  -- title
  print("paused", 48, 10, 7)

  -- current stats
  print("score: "..score, 32, 25, 10)
  print("level: "..level, 32, 33, 7)

  -- chain multiplier
  if chain > 1 then
    local mult = flr((1 + (chain - 1) * 0.5) * 10) / 10
    print("chain: x"..mult, 32, 41, 11)
  end

  -- fuel status
  local fuel_table = {80, 70, 60, 50, 40}
  local fuel_mult = {1.15, 1.0, 0.8}
  local max_fuel = flr((fuel_table[level] or 40) * fuel_mult[difficulty + 1])
  print("fuel: "..flr(ship.fuel).."/"..max_fuel, 32, 49, 7)

  -- active power-ups
  if #active_powerups > 0 then
    print("active power-ups:", 24, 60, 6)
    local pup_y = 68
    for p in all(active_powerups) do
      local pname = ({"shield", "fuel+", "boost", "low-g"})[p.type]
      local pcol = ({8, 12, 9, 11})[p.type]

      circfill(26, pup_y + 2, 2, pcol)

      if p.time then
        local sec = flr(p.time / 60) + 1
        print(pname.." ("..sec.."s)", 30, pup_y, 7)
      else
        print(pname, 30, pup_y, 7)
      end

      pup_y += 8
    end
  end

  -- controls
  print("x: resume", 40, 105, 11)
  print("o: quit to menu", 28, 113, 8)
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
__sfx__
001000001c0501c0501c0501c050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c5501e5502055023550255502755029550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000030540285501f5401854010530085200752007510075100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c5501e5502155023550275502a5502d550305500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000020550235502555027550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001d5502055023550275502a5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000018550205502355027550295502c550305503355000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000c5300c5300c5300c53018530185301853018530245302453024530245302d5302d5302d5302d53000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000205302453027530295302c5302d530305303053000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000305303053030530285302453020530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000275302753027530275302753027530275302753027530275302753000000275302753027530275300000000000000000000000000000000000000000000000000000000000000000000000000000000
001000003053030530305303053030530305303053030530305303053030530000003053030530305303053000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002d5302d5302d5302d5302d5302d5302d5302d5302d5302d5302d53000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000245302453024530245302453024530245302453024530245302453000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000205302053020530205302053020530205302053020530205302053000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c5301c5301c5301c5301c5301c5301c5301c53000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002055023550265502a5502d550305503355037550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001855020550235502655028550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000002355027550295502d5503055033550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001855020550235502755029550305503555038550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000c5300c5300c5300c5300c5300c5300c5300c530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 08090a0b
00 0c0d0e0f
00 0e0d0c41
00 08090a0b
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
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00777777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
