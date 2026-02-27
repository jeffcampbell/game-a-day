pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- bounce king
-- arcade bouncing ball survival

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
highscore = 0  -- kept for migration only
leaderboard = {}  -- array of {score, initials, timestamp}
new_record = false  -- flag for leaderboard entry
new_record_flash = 0  -- flash timer for new record
leaderboard_rank = 0  -- rank achieved (1-10, 0 if not ranked)
gametime = 0
multiplier = 1.0
diff_level = 1
combo = 0
last_milestone = 0  -- track combo milestones
lives = 3  -- player lives (max 3)
difficulty = 2  -- 1=easy, 2=normal, 3=hard
diff_selection = 2  -- current selection cursor
input_cooldown = 0  -- navigation delay
pause_cooldown = 0  -- pause button cooldown

-- initial entry state
entry_initials = {"a", "a", "a"}  -- 3 letters
entry_cursor = 1  -- which letter (1-3)
entry_saved = false  -- confirmation flag

-- leaderboard display state
lb_scroll = 0  -- scroll offset
last_entry_rank = 0  -- highlight player's last entry

-- settings state
music_enabled = true  -- toggle music on/off
sfx_enabled = true  -- toggle sfx on/off
ball_skin = 1  -- ball appearance: 1=white, 2=gold, 3=cyan
settings_selection = 1  -- current settings menu cursor (1-4)
skins_used = {}  -- track which skins have been selected

-- danger zones system
danger_zones = {}
zone_timer = 0
zone_interval = 450  -- ~15 seconds

-- performance stats
max_combo = 0
total_dodges = 0
total_powerups = 0
total_dodge_bonus = 0

-- achievement system
achievements = {}  -- unlocked status {id -> true/false}
ach_definitions = {
  {id=1, name="survivor", title="survivor", desc="survive for 30+ seconds", unlocked=false},
  {id=2, name="power_master", title="power master", desc="collect all 6 power-ups", unlocked=false},
  {id=3, name="combo_king", title="combo king", desc="reach 20+ combo", unlocked=false},
  {id=4, name="danger_expert", title="danger expert", desc="collect 5+ from danger zones", unlocked=false},
  {id=5, name="speedrunner", title="speedrunner", desc="score 500+ in one game", unlocked=false},
  {id=6, name="unstoppable", title="unstoppable", desc="reach 2.0x multiplier", unlocked=false},
  {id=7, name="collection", title="complete collection", desc="unlock all 3 ball skins", unlocked=false},
  {id=8, name="perfect_wave", title="perfect wave", desc="survive 10s without damage", unlocked=false}
}
ach_scroll = 0  -- scroll position in achievements screen
ach_unlocked_count = 0  -- total unlocked
-- tracking for current game
power_types_collected = {}  -- set of collected types this game
last_damage_time = 0  -- time since last damage
danger_zone_pickups = 0  -- total across all games (persistent)

-- practice mode state
practice_obstacle_type = "spike"  -- selected obstacle type
practice_speed_modifier = 1.0  -- 0.5=slow, 1.0=normal, 1.5=fast
practice_collisions = 0  -- collision counter
practice_pause_timer = 0  -- pause after collision
practice_obstacle_selection = 1  -- menu cursor (1-7)
practice_speed_selection = 2  -- menu cursor (1-3)
practice_obstacle_types = {"spike", "moving", "rotating", "pendulum", "zigzag", "orbiter", "boss"}
practice_speed_names = {"slow", "normal", "fast"}
practice_speed_values = {0.5, 1.0, 1.5}

-- tutorial state
tutorial_page = 1  -- current tutorial page (1-5)
tutorial_completed = false  -- track if player has seen tutorial

-- menu cursor state
menu_cursor = 1  -- 1=play, 2=challenge, 3=practice, 4=tutorial, 5=leaderboard, 6=achievements, 7=settings
menu_items = {"play", "challenge", "practice", "tutorial", "leaderboard", "achievements", "settings"}

-- daily challenge state
challenge_time_left = 90  -- 90 second time limit
challenge_active = false  -- flag for challenge mode
challenge_seed = 0  -- daily seed
challenge_score = 0  -- current challenge score
challenge_best = 0  -- today's personal best
daily_history = {}  -- last 7 days: {day_seed, best_score}
challenge_pulse = 0  -- urgency pulse effect

-- visual juice
shake_time = 0
shake_intensity = 0
shake_x = 0
shake_y = 0
screen_flash = 0
ball_flash = 0
wave_pulse = 0  -- wave counter pulse effect
life_flash = 0  -- flash lives counter when life lost

-- ball physics
ball = {
  x = 64,
  y = 100,
  vx = 0,
  vy = 0,
  r = 3,
  grounded = false
}

-- ball trail effect
ball_trail = {}
max_trail_length = 5

-- obstacles
obstacles = {}
obs_timer = 0
obs_interval = 60
boss_timer = 0
boss_interval = 150
scroll_speed = 0.5

-- power-ups
powerups = {}
pu_timer = 0
shield_time = 0
slowmo_time = 0
doublescore_time = 0
magnet_time = 0
freeze_time = 0
obstacles_frozen = false

-- particle effects
particles = {}

-- floating text
floating_texts = {}

function _init()
  -- enable persistent cartridge data
  cartdata("bounce_king")

  -- migrate old highscore (slot 0) if exists
  local old_hs = dget(0)
  if old_hs > 0 then
    highscore = old_hs
    _log("old_highscore:"..highscore)
  end

  -- load settings (slots 1-3)
  load_settings()

  -- load leaderboard (slots 4-43, 4 per entry)
  load_leaderboard()

  -- load achievements (slots 44-51)
  load_achievements()

  -- load tutorial flag (slot 53)
  local t = dget(53)
  tutorial_completed = t == 1

  -- load daily challenge data (slots 54-63)
  load_daily_challenge()

  _log("state:menu")
end

-- settings persistence
function load_settings()
  local m = dget(1)
  local s = dget(2)
  local b = dget(3)

  -- default to enabled if not set
  music_enabled = m == 0 or m == 1
  sfx_enabled = s == 0 or s == 1
  ball_skin = b >= 1 and b <= 3 and b or 1

  -- track current skin as used
  skins_used[ball_skin] = true

  _log("settings_loaded:m="..tostr(music_enabled)..",s="..tostr(sfx_enabled)..",b="..ball_skin)
end

function save_settings()
  dset(1, music_enabled and 1 or 0)
  dset(2, sfx_enabled and 1 or 0)
  dset(3, ball_skin)
  _log("settings_saved")
end

-- achievement persistence (slots 44-51)
function load_achievements()
  achievements = {}
  ach_unlocked_count = 0
  for i = 1, 8 do
    local unlocked = dget(43 + i) == 1
    achievements[i] = unlocked
    ach_definitions[i].unlocked = unlocked
    if unlocked then
      ach_unlocked_count += 1
    end
  end
  -- load persistent danger zone pickups (slot 52)
  danger_zone_pickups = dget(52) or 0
  _log("achievements_loaded:"..ach_unlocked_count.."/8")
end

function save_achievements()
  for i = 1, 8 do
    dset(43 + i, achievements[i] and 1 or 0)
  end
  -- save persistent danger zone pickups
  dset(52, danger_zone_pickups)
  _log("achievements_saved")
end

-- daily challenge persistence (slots 54-63)
-- slot 54: challenge_best
-- slot 55: challenge_seed
-- slots 56-63: daily_history (4 entries: seed, score, seed, score...)
function load_daily_challenge()
  -- generate today's seed
  challenge_seed = flr(time() / 86400)  -- 86400 = 24*60*60 seconds per day

  -- load stored seed and best
  local stored_seed = dget(55)
  local stored_best = dget(54)

  -- if stored seed matches today, load the best score
  if stored_seed == challenge_seed then
    challenge_best = stored_best
  else
    -- new day, reset best score
    challenge_best = 0
    dset(55, challenge_seed)
    dset(54, 0)
  end

  -- load daily history (last 4 days)
  daily_history = {}
  for i = 1, 4 do
    local slot_base = 54 + i * 2
    local day_seed = dget(slot_base)
    local day_score = dget(slot_base + 1)
    if day_seed > 0 then
      add(daily_history, {seed = day_seed, score = day_score})
    end
  end

  _log("challenge_loaded:seed="..challenge_seed..",best="..challenge_best)
end

function save_daily_challenge()
  -- save current day's best
  dset(54, challenge_best)
  dset(55, challenge_seed)

  -- update daily history
  -- check if today already in history
  local found = false
  for i = 1, #daily_history do
    if daily_history[i].seed == challenge_seed then
      daily_history[i].score = max(daily_history[i].score, challenge_score)
      found = true
      break
    end
  end

  -- if not found, add new entry
  if not found then
    add(daily_history, {seed = challenge_seed, score = challenge_score})
    -- keep only last 4 days
    while #daily_history > 4 do
      del(daily_history, daily_history[1])
    end
  end

  -- save history to cartdata
  for i = 1, 4 do
    local slot_base = 54 + i * 2
    if i <= #daily_history then
      dset(slot_base, daily_history[i].seed)
      dset(slot_base + 1, daily_history[i].score)
    else
      dset(slot_base, 0)
      dset(slot_base + 1, 0)
    end
  end

  _log("challenge_saved:score="..challenge_score..",best="..challenge_best)
end

-- leaderboard persistence (slots 4-43)
-- each entry uses 4 slots: score, char1, char2, char3
-- timestamp stored as minutes since first entry
function load_leaderboard()
  leaderboard = {}
  for i = 1, 10 do
    local slot_base = 4 + (i - 1) * 4
    local sc = dget(slot_base)
    if sc > 0 then
      local c1 = dget(slot_base + 1)
      local c2 = dget(slot_base + 2)
      local c3 = dget(slot_base + 3)
      -- convert codes back to chars (1=a, 26=z)
      local init1 = c1 >= 1 and c1 <= 26 and sub("abcdefghijklmnopqrstuvwxyz", c1, c1) or "a"
      local init2 = c2 >= 1 and c2 <= 26 and sub("abcdefghijklmnopqrstuvwxyz", c2, c2) or "a"
      local init3 = c3 >= 1 and c3 <= 26 and sub("abcdefghijklmnopqrstuvwxyz", c3, c3) or "a"
      add(leaderboard, {
        score = sc,
        initials = init1..init2..init3,
        timestamp = 0  -- not used for now, kept for future
      })
    end
  end

  -- migrate old highscore if leaderboard empty
  if #leaderboard == 0 and highscore > 0 then
    add(leaderboard, {
      score = highscore,
      initials = "cpu",
      timestamp = 0
    })
    save_leaderboard()
    _log("migrated_highscore:"..highscore)
  end

  _log("leaderboard_loaded:"..#leaderboard)
end

function save_leaderboard()
  -- save top 10 entries
  for i = 1, 10 do
    local slot_base = 4 + (i - 1) * 4
    if i <= #leaderboard then
      local entry = leaderboard[i]
      dset(slot_base, entry.score)
      -- convert chars to codes (a=1, z=26)
      local init = entry.initials
      local c1 = sub(init, 1, 1)
      local c2 = sub(init, 2, 2)
      local c3 = sub(init, 3, 3)
      dset(slot_base + 1, ord(c1) - 96)  -- a=97, so a=1
      dset(slot_base + 2, ord(c2) - 96)
      dset(slot_base + 3, ord(c3) - 96)
    else
      -- clear unused slots
      dset(slot_base, 0)
      dset(slot_base + 1, 0)
      dset(slot_base + 2, 0)
      dset(slot_base + 3, 0)
    end
  end
  _log("leaderboard_saved:"..#leaderboard)
end

-- audio wrapper functions
function play_sfx(n, ch, off)
  if sfx_enabled then
    sfx(n, ch, off)
  end
end

function play_music(n, fade, mask)
  if music_enabled then
    music(n, fade, mask)
  else
    music(-1)  -- stop music if disabled
  end
end

-- visual juice functions
function shake(duration, intensity)
  shake_time = duration
  shake_intensity = intensity
  _log("shake:"..duration..":"..intensity)
end

function get_ball_skin_color()
  -- return base color based on skin selection
  if ball_skin == 2 then
    return 9  -- gold/orange
  elseif ball_skin == 3 then
    return 12  -- cyan
  else
    return 10  -- white/yellow (default)
  end
end

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "tutorial" then
    update_tutorial()
  elseif state == "difficulty_select" then
    update_difficulty_select()
  elseif state == "settings" then
    update_settings()
  elseif state == "leaderboard" then
    update_leaderboard()
  elseif state == "achievements" then
    update_achievements()
  elseif state == "practice_obstacle_select" then
    update_practice_obstacle_select()
  elseif state == "practice_speed_select" then
    update_practice_speed_select()
  elseif state == "practice_play" then
    update_practice_play()
  elseif state == "challenge" then
    update_challenge()
  elseif state == "challenge_summary" then
    update_challenge_summary()
  elseif state == "play" then
    update_play()
  elseif state == "pause" then
    update_pause()
  elseif state == "gameover" then
    update_gameover()
  elseif state == "enter_initials" then
    update_enter_initials()
  end
end

function _draw()
  cls(1)

  -- apply screen shake
  camera(shake_x, shake_y)

  if state == "menu" then
    draw_menu()
  elseif state == "tutorial" then
    draw_tutorial()
  elseif state == "difficulty_select" then
    draw_difficulty_select()
  elseif state == "settings" then
    draw_settings()
  elseif state == "leaderboard" then
    draw_leaderboard()
  elseif state == "achievements" then
    draw_achievements()
  elseif state == "practice_obstacle_select" then
    draw_practice_obstacle_select()
  elseif state == "practice_speed_select" then
    draw_practice_speed_select()
  elseif state == "practice_play" then
    draw_practice_play()
  elseif state == "challenge" then
    draw_challenge()
  elseif state == "challenge_summary" then
    draw_challenge_summary()
  elseif state == "play" then
    draw_play()
  elseif state == "pause" then
    draw_pause()
  elseif state == "gameover" then
    draw_gameover()
  elseif state == "enter_initials" then
    draw_enter_initials()
  end

  -- reset camera
  camera()

  -- screen flash effect
  if screen_flash > 0 then
    for i = 0, 127, 4 do
      for j = 0, 127, 4 do
        pset(i, j, 7)
      end
    end
  end

  -- update shake
  if shake_time > 0 then
    shake_time -= 1
    local shake_amt = shake_intensity * (shake_time / 10)
    shake_x = (rnd(2) - 1) * shake_amt
    shake_y = (rnd(2) - 1) * shake_amt
  else
    shake_x = 0
    shake_y = 0
  end

  -- update screen flash
  if screen_flash > 0 then
    screen_flash -= 1
  end

  -- update ball flash
  if ball_flash > 0 then
    ball_flash -= 1
  end

  -- update life flash
  if life_flash > 0 then
    life_flash -= 1
  end

  -- update wave pulse
  if wave_pulse > 0 then
    wave_pulse -= 1
  end
end

-- menu state
function update_menu()
  local input = test_input()

  -- cooldown
  if input_cooldown > 0 then
    input_cooldown -= 1
  end

  -- menu navigation with cooldown
  if input_cooldown == 0 then
    if input & 4 > 0 then  -- up
      menu_cursor = max(1, menu_cursor - 1)
      play_sfx(1)
      _log("menu_nav:up:"..menu_cursor)
      input_cooldown = 10
    end

    if input & 8 > 0 then  -- down
      menu_cursor = min(7, menu_cursor + 1)
      play_sfx(1)
      _log("menu_nav:down:"..menu_cursor)
      input_cooldown = 10
    end

    if input & 16 > 0 then  -- O button - select
      local selection = menu_items[menu_cursor]
      if selection == "play" then
        state = "difficulty_select"
        _log("state:difficulty_select")
        diff_selection = difficulty
        input_cooldown = 10
      elseif selection == "challenge" then
        init_challenge()
        state = "challenge"
        _log("state:challenge")
        input_cooldown = 10
      elseif selection == "practice" then
        state = "practice_obstacle_select"
        _log("state:practice_obstacle_select")
        practice_obstacle_selection = 1
        input_cooldown = 10
      elseif selection == "tutorial" then
        state = "tutorial"
        _log("state:tutorial")
        tutorial_page = 1
        input_cooldown = 10
      elseif selection == "leaderboard" then
        state = "leaderboard"
        _log("state:leaderboard")
        input_cooldown = 10
      elseif selection == "achievements" then
        state = "achievements"
        _log("state:achievements")
        ach_scroll = 0
        input_cooldown = 10
      elseif selection == "settings" then
        state = "settings"
        _log("state:settings")
        settings_selection = 1
        input_cooldown = 10
      end
    end
  end
end

function draw_menu()
  print("bounce king", 38, 30, 7)
  print("survive the fall!", 26, 42, 6)

  -- menu items
  local menu_y = 56
  local menu_labels = {
    "play",
    "daily challenge",
    "practice mode",
    "tutorial",
    "leaderboard",
    "achievements",
    "settings"
  }

  for i = 1, 7 do
    local col = 6
    local prefix = "  "
    if i == menu_cursor then
      col = 10
      prefix = "> "
    end
    print(prefix..menu_labels[i], 24, menu_y + (i - 1) * 8, col)
  end

  -- show top score from leaderboard
  if #leaderboard > 0 then
    local top = leaderboard[1]
    print("best: "..top.score.." ("..top.initials..")", 20, 118, 10)
  end
end

-- tutorial state
function update_tutorial()
  local input = test_input()

  -- cooldown
  if input_cooldown > 0 then
    input_cooldown -= 1
  end

  -- page navigation with cooldown
  if input_cooldown == 0 then
    if input & 4 > 0 then  -- up
      tutorial_page = max(1, tutorial_page - 1)
      play_sfx(1)
      _log("tutorial_nav:up:"..tutorial_page)
      input_cooldown = 10
    end
    if input & 8 > 0 then  -- down
      tutorial_page = min(5, tutorial_page + 1)
      play_sfx(1)
      _log("tutorial_nav:down:"..tutorial_page)
      input_cooldown = 10
    end
  end

  -- skip/exit with O button
  if input & 16 > 0 then  -- O button
    tutorial_completed = true
    dset(53, 1)  -- save completion flag
    state = "menu"
    _log("tutorial_complete")
    _log("state:menu")
  end
end

function draw_tutorial()
  -- header
  print("how to play", 38, 4, 7)
  print("page "..tutorial_page.."/5", 48, 12, 6)

  if tutorial_page == 1 then
    -- controls + objective
    print("controls:", 10, 24, 10)
    print("left/right arrows", 20, 32, 7)
    print("move your ball", 20, 40, 6)
    print("ball bounces automatically", 10, 50, 11)

    print("objective:", 10, 62, 10)
    print("dodge falling obstacles", 16, 70, 7)
    print("collect power-ups", 24, 78, 7)
    print("survive as long as you can", 10, 86, 7)

  elseif tutorial_page == 2 then
    -- obstacles
    print("obstacles:", 10, 24, 10)

    -- spike
    circfill(20, 38, 6, 8)
    print("spike: static", 32, 34, 7)

    -- moving
    circfill(20, 54, 10, 8)
    print("moving: left-right", 36, 50, 7)

    -- rotating
    circfill(20, 70, 8, 8)
    print("rotating: pulsing", 34, 66, 7)

    -- advanced
    print("more types unlock as", 16, 86, 6)
    print("difficulty increases!", 20, 94, 6)

  elseif tutorial_page == 3 then
    -- power-ups
    print("power-ups:", 10, 24, 10)

    -- shield
    circfill(16, 34, 4, 11)
    print("shield: +1 life", 26, 32, 7)

    -- slowmo
    circfill(16, 46, 4, 12)
    print("slowmo: slow time", 26, 44, 7)

    -- doublescore
    circfill(16, 58, 4, 10)
    print("doublescore: 2x pts", 26, 56, 7)

    -- magnet
    circfill(16, 70, 4, 13)
    print("magnet: pull items", 26, 68, 7)

    -- bomb
    circfill(16, 82, 4, 8)
    print("bomb: clear screen", 26, 80, 7)

    -- freeze
    circfill(16, 94, 4, 12)
    print("freeze: stop enemies", 26, 92, 7)

  elseif tutorial_page == 4 then
    -- scoring system
    print("scoring:", 10, 24, 10)

    print("dodge bonus:", 16, 34, 7)
    print("+10 per obstacle", 24, 42, 6)

    print("combo system:", 16, 54, 7)
    print("chain dodges for bonus", 20, 62, 6)
    print("resets on collision", 22, 70, 8)

    print("multiplier:", 16, 82, 7)
    print("increases every 10s", 20, 90, 6)
    print("1.0x -> 1.5x -> 2.0x...", 16, 98, 10)

  elseif tutorial_page == 5 then
    -- ready to play
    print("you're ready!", 34, 30, 10)

    print("tips:", 10, 46, 7)
    print("- stay near the center", 16, 54, 6)
    print("- watch for patterns", 18, 62, 6)
    print("- time your movements", 14, 70, 6)
    print("- collect power-ups", 18, 78, 6)
    print("- practice makes perfect", 10, 86, 11)

    print("good luck!", 40, 100, 14)
  end

  -- navigation hints
  print("up/down: change page", 16, 118, 13)
  print("o: skip to menu", 26, 124, 13)
end

-- difficulty selection state
function update_difficulty_select()
  local input = test_input()

  -- update cooldown
  if input_cooldown > 0 then
    input_cooldown -= 1
  end

  -- navigation with cooldown
  if input_cooldown == 0 then
    if input & 4 > 0 then  -- up
      diff_selection = max(1, diff_selection - 1)
      play_sfx(1)
      _log("difficulty_nav:up")
      input_cooldown = 10
    end
    if input & 8 > 0 then  -- down
      diff_selection = min(3, diff_selection + 1)
      play_sfx(1)
      _log("difficulty_nav:down")
      input_cooldown = 10
    end
  end

  -- confirm
  if input & 16 > 0 then  -- O button
    difficulty = diff_selection
    local diff_names = {"easy", "normal", "hard"}
    _log("difficulty_select:"..diff_names[difficulty])
    state = "play"
    _log("state:play")
    init_game()
  end
end

function draw_difficulty_select()
  print("select difficulty", 22, 30, 7)

  -- easy option
  local col1 = diff_selection == 1 and 10 or 6
  print("> easy", 38, 50, col1)
  print("slower obstacles", 16, 58, 5)
  print("more forgiving", 20, 64, 5)

  -- normal option
  local col2 = diff_selection == 2 and 10 or 6
  print("> normal", 34, 76, col2)
  print("balanced gameplay", 14, 84, 5)

  -- hard option
  local col3 = diff_selection == 3 and 10 or 6
  print("> hard", 38, 96, col3)
  print("faster obstacles", 16, 104, 5)
  print("real challenge", 22, 110, 5)

  print("up/down: choose", 18, 122, 13)
end

-- settings state
function update_settings()
  local input = test_input()

  -- update cooldown
  if input_cooldown > 0 then
    input_cooldown -= 1
  end

  -- navigation with cooldown
  if input_cooldown == 0 then
    if input & 4 > 0 then  -- up
      settings_selection = max(1, settings_selection - 1)
      play_sfx(1)
      _log("settings_nav:up")
      input_cooldown = 10
    end
    if input & 8 > 0 then  -- down
      settings_selection = min(4, settings_selection + 1)
      play_sfx(1)
      _log("settings_nav:down")
      input_cooldown = 10
    end

    -- toggle options with O button
    if input & 16 > 0 then  -- O button
      if settings_selection == 1 then
        music_enabled = not music_enabled
        play_sfx(1)
        _log("toggle_music:"..tostr(music_enabled))
        if not music_enabled then
          music(-1)  -- stop music immediately
        end
      elseif settings_selection == 2 then
        sfx_enabled = not sfx_enabled
        play_sfx(1)
        _log("toggle_sfx:"..tostr(sfx_enabled))
      elseif settings_selection == 3 then
        ball_skin = ball_skin % 3 + 1  -- cycle 1->2->3->1
        skins_used[ball_skin] = true  -- track skin usage
        play_sfx(1)
        _log("ball_skin:"..ball_skin)
        -- check if all skins used for achievement
        local all_used = skins_used[1] and skins_used[2] and skins_used[3]
        if all_used and not achievements[7] then
          unlock_achievement(7)
        end
      end
      save_settings()  -- persist changes
      input_cooldown = 10
    end
  end

  -- back to menu with X button
  if input & 32 > 0 then
    state = "menu"
    _log("state:menu")
    save_settings()  -- ensure settings saved
    input_cooldown = 10
  end
end

function draw_settings()
  print("settings", 44, 20, 7)

  -- music toggle
  local col1 = settings_selection == 1 and 10 or 6
  local check1 = music_enabled and "\x8e" or "\x83"  -- checkmark or X
  print("> music: "..check1, 28, 36, col1)

  -- sfx toggle
  local col2 = settings_selection == 2 and 10 or 6
  local check2 = sfx_enabled and "\x8e" or "\x83"
  print("> sfx: "..check2, 28, 46, col2)

  -- ball skin
  local col3 = settings_selection == 3 and 10 or 6
  local skin_names = {"white", "gold", "cyan"}
  print("> ball: "..skin_names[ball_skin], 28, 56, col3)

  -- ball preview with current skin
  local prev_x = 90
  local prev_y = 58
  local skin_col = get_ball_skin_color()
  circfill(prev_x, prev_y, 3, skin_col)
  circ(prev_x, prev_y, 3, 7)

  -- controls reference
  local col4 = settings_selection == 4 and 10 or 6
  print("> controls", 28, 66, col4)

  -- show controls if selected
  if settings_selection == 4 then
    print("arrows: move ball", 12, 78, 5)
    print("o: confirm/toggle", 12, 84, 5)
    print("x: pause/back", 18, 90, 5)
  end

  print("up/down: navigate", 16, 106, 13)
  print("o: toggle option", 18, 112, 13)
  print("x: back to menu", 18, 118, 13)
end

-- leaderboard state
function update_leaderboard()
  local input = test_input()

  -- back to menu with X button
  if input & 32 > 0 then
    state = "menu"
    _log("state:menu")
    input_cooldown = 10
  end
end

function draw_leaderboard()
  print("leaderboard", 38, 8, 7)
  print("-- top 10 scores --", 22, 18, 6)

  if #leaderboard == 0 then
    print("no entries yet!", 26, 60, 13)
    print("play to set a record!", 14, 70, 11)
  else
    local y = 28
    for i = 1, min(10, #leaderboard) do
      local entry = leaderboard[i]
      local col = 13  -- default cyan
      if i == 1 then
        col = 10  -- gold for 1st
      elseif i == 2 then
        col = 12  -- light blue for 2nd
      elseif i == 3 then
        col = 14  -- pink for 3rd
      end

      -- highlight player's last entry
      if i == last_entry_rank and last_entry_rank > 0 then
        col = 11  -- green highlight
        print(">", 8, y, col)
      end

      -- rank
      local rank_str = i < 10 and " "..i or tostr(i)
      print(rank_str, 14, y, col)

      -- initials
      print(entry.initials, 28, y, col)

      -- score
      print(entry.score, 52, y, col)

      y += 9
      if y > 118 then break end  -- prevent overflow
    end
  end

  print("x: back to menu", 20, 122, 5)
end

-- pause state
function update_pause()
  -- update pause cooldown
  if pause_cooldown > 0 then
    pause_cooldown -= 1
  end

  -- check for unpause button (X = button 5)
  local input = test_input()
  if pause_cooldown == 0 and input & 32 > 0 then
    state = "play"
    play_music(0)  -- resume music
    _log("state:resume")
    pause_cooldown = 15
  end
end

function draw_pause()
  -- draw the frozen game state
  draw_play()

  -- draw semi-transparent overlay (checkerboard pattern for dimming)
  for i = 0, 127, 2 do
    for j = 0, 127, 2 do
      pset(i, j, 0)
    end
  end

  -- pause UI box
  rectfill(24, 40, 104, 90, 0)
  rect(24, 40, 104, 90, 7)
  rect(25, 41, 103, 89, 6)

  -- pause text
  print("paused", 48, 46, 7)
  print("score: "..score, 38, 56, 10)
  print("time: "..flr(gametime/30).."s", 36, 64, 11)
  print("combo: "..combo, 40, 72, 9)
  print("press x to resume", 28, 82, 13)
end

-- achievements state
function update_achievements()
  -- update cooldown
  if input_cooldown > 0 then
    input_cooldown -= 1
  end

  local input = test_input()

  -- return to menu
  if input_cooldown == 0 and input & 32 > 0 then  -- X button
    state = "menu"
    _log("state:menu")
    input_cooldown = 10
  end
end

function draw_achievements()
  print("achievements", 34, 8, 7)
  print(ach_unlocked_count.."/8 unlocked", 32, 18, 10)

  -- draw achievement list
  local y_start = 30
  for i = 1, 8 do
    local ach = ach_definitions[i]
    local y = y_start + (i - 1) * 12

    if ach.unlocked then
      -- unlocked: gold color
      print("\x8e "..ach.title, 10, y, 9)  -- checkmark
      print(ach.desc, 10, y + 6, 10)
    else
      -- locked: dark color
      print("\x94 "..ach.title, 10, y, 5)  -- lock
      print(ach.desc, 10, y + 6, 5)
    end
  end

  print("press x to return", 24, 118, 13)
end

-- game initialization
function init_game()
  ball.x = 64
  ball.y = 100
  ball.vx = 0
  ball.vy = 0
  ball.grounded = false
  score = 0
  new_record = false  -- reset new record flag
  new_record_flash = 0
  leaderboard_rank = 0  -- reset rank
  gametime = 0
  multiplier = 1.0
  diff_level = 1
  combo = 0
  last_milestone = 0
  lives = 3  -- start with 3 lives
  life_flash = 0
  obstacles = {}
  powerups = {}
  particles = {}
  floating_texts = {}
  ball_trail = {}
  obs_timer = 0
  boss_timer = 0
  pu_timer = 0
  shield_time = 0
  slowmo_time = 0
  doublescore_time = 0
  magnet_time = 0
  freeze_time = 0
  obstacles_frozen = false

  -- reset performance stats
  max_combo = 0
  total_dodges = 0
  total_powerups = 0
  total_dodge_bonus = 0

  -- reset achievement tracking for this game
  power_types_collected = {}
  last_damage_time = gametime

  -- set initial parameters based on difficulty
  if difficulty == 1 then  -- easy
    scroll_speed = 0.3
    obs_interval = 80
  elseif difficulty == 2 then  -- normal
    scroll_speed = 0.5
    obs_interval = 60
  elseif difficulty == 3 then  -- hard
    scroll_speed = 0.8
    obs_interval = 40
  end

  -- initialize danger zones
  danger_zones = {
    {x_min=0, x_max=42, active=false, pulse=0},     -- left
    {x_min=43, x_max=85, active=false, pulse=0},    -- center
    {x_min=86, x_max=128, active=false, pulse=0}    -- right
  }
  zone_timer = 0
  zone_interval = 450 + rnd(150)  -- 15-20 seconds
  _log("zones_init")

  play_music(0)  -- start background music
  _log("game_init:difficulty="..difficulty)
end

-- daily challenge initialization
function init_challenge()
  -- recompute seed in case we crossed midnight
  challenge_seed = flr(time() / 86400)
  _log("challenge_seed_recomputed:"..challenge_seed)

  -- check if seed changed (new day) and update best score
  local stored_seed = dget(55)
  if stored_seed ~= challenge_seed then
    -- new day, reset best score
    challenge_best = 0
    dset(55, challenge_seed)
    dset(54, 0)
    _log("challenge_new_day:seed="..challenge_seed)
  else
    -- same day, load existing best
    challenge_best = dget(54)
    _log("challenge_same_day:best="..challenge_best)
  end

  -- reuse init_game logic
  ball.x = 64
  ball.y = 100
  ball.vx = 0
  ball.vy = 0
  ball.grounded = false
  challenge_score = 0
  challenge_active = true
  challenge_time_left = 90 * 30  -- 90 seconds in frames (30fps)
  challenge_pulse = 0
  gametime = 0
  multiplier = 1.0
  diff_level = 1
  combo = 0
  last_milestone = 0
  lives = 3
  life_flash = 0
  obstacles = {}
  powerups = {}
  particles = {}
  floating_texts = {}
  ball_trail = {}
  obs_timer = 0
  boss_timer = 0
  pu_timer = 0
  shield_time = 0
  slowmo_time = 0
  doublescore_time = 0
  magnet_time = 0
  freeze_time = 0
  obstacles_frozen = false

  -- seed-based difficulty (use challenge_seed for deterministic behavior)
  srand(challenge_seed)
  local seed_mod = challenge_seed % 3
  if seed_mod == 0 then
    scroll_speed = 0.6
    obs_interval = 50
  elseif seed_mod == 1 then
    scroll_speed = 0.7
    obs_interval = 45
  else
    scroll_speed = 0.8
    obs_interval = 40
  end

  -- initialize danger zones
  danger_zones = {
    {x_min=0, x_max=42, active=false, pulse=0},
    {x_min=43, x_max=85, active=false, pulse=0},
    {x_min=86, x_max=128, active=false, pulse=0}
  }
  zone_timer = 0
  zone_interval = 450 + rnd(150)

  play_music(0)
  _log("challenge_init:seed="..challenge_seed..",scroll="..scroll_speed..",interval="..obs_interval)
end

-- achievement checking
function check_achievements()
  -- 1. survivor: survive 30+ seconds
  if not achievements[1] and gametime >= 900 then
    unlock_achievement(1)
  end

  -- 2. power master: collect all 6 types
  if not achievements[2] then
    local types_count = 0
    for k, v in pairs(power_types_collected) do
      if v then types_count += 1 end
    end
    if types_count >= 6 then
      unlock_achievement(2)
    end
  end

  -- 3. combo king: reach 20+ combo
  if not achievements[3] and combo >= 20 then
    unlock_achievement(3)
  end

  -- 4. danger expert: 5+ pickups from danger zones (persistent)
  if not achievements[4] and danger_zone_pickups >= 5 then
    unlock_achievement(4)
  end

  -- 5. speedrunner: 500+ score in one game
  if not achievements[5] and score >= 500 then
    unlock_achievement(5)
  end

  -- 6. unstoppable: 2.0x+ multiplier
  if not achievements[6] and multiplier >= 2.0 then
    unlock_achievement(6)
  end

  -- 7. complete collection: checked in settings menu when skin is changed

  -- 8. perfect wave: survive 10s (300 frames) without damage
  if not achievements[8] and gametime - last_damage_time >= 300 then
    unlock_achievement(8)
  end
end

function unlock_achievement(id)
  if achievements[id] then return end  -- already unlocked

  achievements[id] = true
  ach_definitions[id].unlocked = true
  ach_unlocked_count += 1

  local ach = ach_definitions[id]
  _log("achievement:"..ach.name)

  -- visual/audio feedback
  play_sfx(6)  -- achievement sound
  shake(12, 1.2)
  add_floating_text(64, 50, "achievement!", 10)
  add_floating_text(64, 60, ach.title, 9)

  -- save immediately
  save_achievements()
end

-- play state
function update_play()
  -- update pause cooldown
  if pause_cooldown > 0 then
    pause_cooldown -= 1
  end

  -- check for pause button (X = button 5)
  local input = test_input()
  if pause_cooldown == 0 and input & 32 > 0 then
    state = "pause"
    play_music(-1)  -- stop music when paused
    _log("state:pause")
    pause_cooldown = 15
    return
  end

  gametime += 1

  -- difficulty progression
  if gametime % 600 == 0 then
    diff_level += 1
    scroll_speed += 0.1
    obs_interval = max(20, obs_interval - 5)
    play_sfx(6)  -- difficulty increase fanfare
    wave_pulse = 20  -- trigger wave counter pulse
    _log("difficulty:"..diff_level)
    _log("wave:"..diff_level)
  end

  -- update danger zones
  zone_timer += 1
  if zone_timer >= zone_interval then
    zone_timer = 0
    zone_interval = 450 + rnd(150)  -- randomize next interval
    -- toggle random zone
    local z = danger_zones[flr(rnd(3)) + 1]
    z.active = not z.active
    local zone_idx = z == danger_zones[1] and "L" or (z == danger_zones[2] and "C" or "R")
    _log("zone_toggle:"..zone_idx..":"..tostr(z.active))
  end
  -- update zone pulse animations
  for z in all(danger_zones) do
    if z.active then
      z.pulse = (z.pulse + 0.08) % 1
    else
      z.pulse = 0
    end
  end

  -- score multiplier every 30s
  if gametime % 900 == 0 then
    multiplier += 0.5
    _log("multiplier:"..multiplier)
  end

  -- base score
  score += flr(1 * multiplier * (doublescore_time > 0 and 2 or 1))

  -- power-up timers
  if shield_time > 0 then shield_time -= 1 end
  if slowmo_time > 0 then slowmo_time -= 1 end
  if doublescore_time > 0 then doublescore_time -= 1 end
  if magnet_time > 0 then magnet_time -= 1 end
  if freeze_time > 0 then
    freeze_time -= 1
    obstacles_frozen = true
  else
    obstacles_frozen = false
  end

  -- movement input
  if input & 1 > 0 then
    ball.vx -= 0.5
    _log("steer_left")
  end
  if input & 2 > 0 then
    ball.vx += 0.5
    _log("steer_right")
  end

  -- physics
  ball.vx *= 0.9
  ball.vy += 0.4  -- gravity
  ball.x += ball.vx
  ball.y += ball.vy

  -- update ball trail
  local vel = sqrt(ball.vx^2 + ball.vy^2)
  add(ball_trail, {x=ball.x, y=ball.y, vel=vel, age=0})
  for tr in all(ball_trail) do
    tr.age += 1
    if tr.age > 8 then
      del(ball_trail, tr)
    end
  end
  -- limit trail length
  while #ball_trail > max_trail_length do
    del(ball_trail, ball_trail[1])
  end

  -- bounce off floor
  if ball.y >= 122 then
    ball.y = 122
    ball.vy *= -0.7
    ball.grounded = true
    if abs(ball.vy) < 0.5 then
      ball.vy = -3
    end
    play_sfx(0)  -- bounce sound
    shake(6, 0.5 + diff_level * 0.1)  -- small shake, scales with difficulty
    add_particles(ball.x, 122, 5, 13)  -- bounce particles
    _log("bounce")
  else
    ball.grounded = false
  end

  -- wall bounce
  if ball.x < ball.r then
    ball.x = ball.r
    ball.vx *= -0.5
    play_sfx(1)  -- wall bounce sound
    shake(4, 0.3)  -- small shake on wall bounce
    add_particles(ball.x, ball.y, 3, 6)
  elseif ball.x > 128 - ball.r then
    ball.x = 128 - ball.r
    ball.vx *= -0.5
    play_sfx(1)  -- wall bounce sound
    shake(4, 0.3)  -- small shake on wall bounce
    add_particles(ball.x, ball.y, 3, 6)
  end

  -- spawn obstacles
  obs_timer += 1
  if obs_timer >= obs_interval then
    obs_timer = 0
    spawn_obstacle()
  end

  -- spawn boss obstacles (diff_level >= 3)
  if diff_level >= 3 then
    boss_timer += 1
    if boss_timer >= boss_interval then
      boss_timer = 0
      if rnd(1) < 0.33 then
        spawn_boss()
      end
    end
  end

  -- update obstacles
  local speed_mod = slowmo_time > 0 and 0.5 or 1.0
  for o in all(obstacles) do
    -- freeze effect: skip movement when frozen
    if not obstacles_frozen then
      o.y += scroll_speed * speed_mod

      if o.type == "moving" then
        o.x += o.vx
        if o.x < 0 or o.x > 128 then
          o.vx *= -1
        end
      elseif o.type == "rotating" then
        o.angle += 0.02
        o.r = 8 + sin(o.angle) * 4
      elseif o.type == "boss" then
        o.wave_time += 0.03
        o.x = o.base_x + sin(o.wave_time) * 30
      elseif o.type == "pendulum" then
        o.swing_time += 0.04
        o.x = o.base_x + sin(o.swing_time) * 25
      elseif o.type == "zigzag" then
        o.zig_time += 0.05
        local amp = 15 + diff_level * 2
        o.x += sin(o.zig_time) * amp * o.zig_dir * 0.1
        if o.x < 10 or o.x > 118 then
          o.zig_dir *= -1
        end
      elseif o.type == "orbiter" then
        o.orbit_angle += 0.05
      end
    end

    -- check collision
    if shield_time == 0 then
      local collision = false

      -- standard collision for most types
      if o.type != "orbiter" then
        local dist = sqrt((ball.x - o.x)^2 + (ball.y - o.y)^2)
        if dist < ball.r + o.r then
          collision = true
        end
      else
        -- orbiter: check collision with center and two satellites
        local center_dist = sqrt((ball.x - o.x)^2 + (ball.y - o.y)^2)
        if center_dist < ball.r + 3 then
          collision = true
        end
        -- satellite 1
        local sat1_x = o.x + cos(o.orbit_angle) * o.orbit_radius
        local sat1_y = o.y + sin(o.orbit_angle) * o.orbit_radius
        local sat1_dist = sqrt((ball.x - sat1_x)^2 + (ball.y - sat1_y)^2)
        if sat1_dist < ball.r + 3 then
          collision = true
        end
        -- satellite 2
        local sat2_x = o.x + cos(o.orbit_angle + 0.5) * o.orbit_radius
        local sat2_y = o.y + sin(o.orbit_angle + 0.5) * o.orbit_radius
        local sat2_dist = sqrt((ball.x - sat2_x)^2 + (ball.y - sat2_y)^2)
        if sat2_dist < ball.r + 3 then
          collision = true
        end
      end

      if collision then
        -- lose a life
        lives -= 1
        life_flash = 10  -- flash lives counter
        last_damage_time = gametime  -- reset perfect wave tracker
        _log("life_lost")
        _log("lives:"..lives)

        -- collision feedback
        play_sfx(7)  -- collision impact sound
        shake(8, 1.0)  -- medium shake
        ball_flash = 3  -- flash ball white
        add_particles(ball.x, ball.y, 15, 7)  -- particle burst
        combo = 0
        last_milestone = 0
        _log("combo_reset")

        -- remove this obstacle
        del(obstacles, o)

        -- check if game over
        if lives <= 0 then
          play_music(-1)  -- stop music on game over
          state = "gameover"
          _log("state:gameover")
          _log("final_score:"..score)
          _log("max_combo:"..max_combo)
          _log("total_dodges:"..total_dodges)
          _log("total_powerups:"..total_powerups)
          _log("multiplier:"..multiplier)
          local avg = total_dodges > 0 and flr(total_dodge_bonus / total_dodges) or 0
          _log("avg_bonus:"..avg)
          if score > highscore then
            highscore = score
            new_record = true
            new_record_flash = 60  -- flash for 2 seconds
            dset(0, highscore)  -- save to cartridge data
            play_sfx(6)  -- celebratory sound
            shake(20, 0.5)  -- screen shake
            _log("new_highscore:"..highscore)
            _log("highscore_saved")
          end
        end
        return
      end
    end

    -- dodged obstacle bonus
    if not o.dodged and ball.y < o.y - 10 then
      o.dodged = true
      combo += 1
      _log("combo:"..combo)

      -- update performance stats
      if combo > max_combo then
        max_combo = combo
        _log("max_combo:"..max_combo)
      end
      total_dodges += 1

      local base_bonus = 10 * multiplier * (doublescore_time > 0 and 2 or 1)
      if o.is_boss then
        base_bonus *= 2  -- double points for boss dodges
      end

      -- danger zone bonus: check if player is in active zone
      local ball_zone = get_zone(ball.x)
      local in_danger_zone = ball_zone > 0 and danger_zones[ball_zone].active
      if in_danger_zone then
        base_bonus *= 1.5  -- 1.5x multiplier for danger zone dodges
        _log("danger_dodge:zone"..ball_zone)
      end

      local combo_mult = 1 + flr(combo / 5)
      local bonus = flr(base_bonus * combo_mult)
      score += bonus
      total_dodge_bonus += bonus

      play_sfx(5)  -- dodge bonus ascending notes
      local shake_amt = o.is_boss and 6 or 3
      shake(shake_amt, o.is_boss and 0.8 or 0.4)
      if o.is_boss then
        _log("boss_dodge:"..bonus)
        add_particles(ball.x, ball.y, 25, 9)  -- extra particles for boss
      else
        _log("dodge_bonus:"..bonus)
        local pcol = in_danger_zone and 8 or 11  -- red for danger zone
        add_particles(ball.x, ball.y, 15, pcol)
      end

      -- floating text for dodge bonus
      local text_col = in_danger_zone and 8 or 11  -- red for danger
      if combo_mult > 1 then
        add_floating_text(ball.x - 8, ball.y - 12, "+"..bonus.." x"..combo_mult, text_col)
      else
        add_floating_text(ball.x - 6, ball.y - 12, "+"..bonus, text_col)
      end

      -- check for combo milestones
      local milestone = 0
      if combo >= 20 then
        milestone = flr(combo / 5) * 5  -- every 5 after 20
      elseif combo == 15 or combo == 10 or combo == 5 then
        milestone = combo
      end

      -- trigger milestone celebration if new milestone reached
      if milestone > 0 and milestone > last_milestone then
        last_milestone = milestone
        _log("milestone:"..milestone)
        play_sfx(7)  -- celebratory milestone sound
        shake(3, 0.25)  -- gentle shake for milestone
        -- milestone floating text with color
        local m_col = 10  -- yellow
        if milestone >= 15 then
          m_col = 14  -- pink for 15+
        elseif milestone >= 10 then
          m_col = 9  -- orange for 10+
        end
        add_floating_text(64 - 18, 50, milestone.." combo!", m_col)
      end
    end

    -- cleanup
    if o.y > 140 then
      del(obstacles, o)
    end
  end

  -- spawn power-ups
  pu_timer += 1
  if pu_timer >= 300 and #powerups < 2 then
    pu_timer = 0
    spawn_powerup()
  end

  -- update power-ups
  for p in all(powerups) do
    p.y += scroll_speed * speed_mod
    p.spawn_time += 1  -- increment for pulse effect

    -- magnet effect: pull powerups toward ball
    if magnet_time > 0 then
      local dx = ball.x - p.x
      local dy = ball.y - p.y
      local dist = sqrt(dx^2 + dy^2)
      if dist > 1 then
        p.x += (dx / dist) * 2  -- move toward ball
        p.y += (dy / dist) * 2
      end
    end

    -- collect
    local dist = sqrt((ball.x - p.x)^2 + (ball.y - p.y)^2)
    if dist < ball.r + 4 then
      collect_powerup(p)
      del(powerups, p)
    end

    if p.y > 140 then
      del(powerups, p)
    end
  end

  -- update particles
  for pt in all(particles) do
    pt.x += pt.vx
    pt.y += pt.vy
    pt.life -= 1
    if pt.life <= 0 then
      del(particles, pt)
    end
  end

  -- update floating texts
  for ft in all(floating_texts) do
    ft.y += ft.vy
    ft.lifetime -= 1
    if ft.lifetime <= 0 then
      del(floating_texts, ft)
    end
  end

  -- check achievements
  check_achievements()
end

function draw_play()
  -- background grid
  for i = 0, 15 do
    line(0, i * 8 + (gametime % 8), 127, i * 8 + (gametime % 8), 5)
  end

  -- danger zones (subtle pulsing tint + borders)
  for i = 1, 3 do
    local z = danger_zones[i]
    if z.active then
      -- pulsing background tint (checkerboard for subtlety)
      local pulse_alpha = 0.5 + sin(z.pulse) * 0.3
      if pulse_alpha > 0.5 then
        for x = z.x_min, z.x_max - 1, 3 do
          for y = 0, 127, 3 do
            pset(x, y, 8)  -- red tint
          end
        end
      end
      -- glowing borders
      local border_col = sin(z.pulse) > 0.5 and 8 or 2  -- pulse red/dark
      line(z.x_min, 0, z.x_min, 127, border_col)
      line(z.x_max - 1, 0, z.x_max - 1, 127, border_col)
    end
  end

  -- obstacles
  for o in all(obstacles) do
    -- brighter colors for danger zone obstacles
    local danger_boost = o.in_danger and 1 or 0
    if o.type == "spike" then
      local col = o.in_danger and 14 or 8  -- pink in danger, red normal
      circfill(o.x, o.y, o.r, col)
      circ(o.x, o.y, o.r, obstacles_frozen and 12 or 2)  -- cyan outline when frozen
    elseif o.type == "moving" then
      local col = o.in_danger and 8 or 12  -- red in danger, blue normal
      rectfill(o.x - o.r, o.y - 3, o.x + o.r, o.y + 3, col)
      if obstacles_frozen then
        rect(o.x - o.r, o.y - 3, o.x + o.r, o.y + 3, 12)  -- cyan border when frozen
      end
    elseif o.type == "rotating" then
      local col = o.in_danger and 15 or 14  -- white in danger, pink normal
      circfill(o.x, o.y, o.r, col)
      if obstacles_frozen then
        circ(o.x, o.y, o.r, 12)  -- cyan outline when frozen
      end
    elseif o.type == "boss" then
      -- pulsing ring effect
      local pulse = sin(gametime / 15) * 2
      local col1 = o.in_danger and 8 or 2
      local col2 = obstacles_frozen and 12 or (o.in_danger and 14 or 8)
      circfill(o.x, o.y, o.r, col1)
      circ(o.x, o.y, o.r, col2)
      if not obstacles_frozen then
        circ(o.x, o.y, o.r - 2 + pulse, 14)
        circ(o.x, o.y, o.r + 2 + pulse, 9)
      end
    elseif o.type == "pendulum" then
      -- hanging pendulum with chain
      local col = o.in_danger and 8 or 9
      line(o.base_x, 0, o.x, o.y, 5)
      circfill(o.x, o.y, o.r, col)
      circ(o.x, o.y, o.r, obstacles_frozen and 12 or 2)
    elseif o.type == "zigzag" then
      -- zigzag with motion trail
      local col = o.in_danger and 8 or 12
      circfill(o.x, o.y, o.r, col)
      circ(o.x, o.y, o.r, obstacles_frozen and 12 or 1)
    elseif o.type == "orbiter" then
      -- center core
      local col = o.in_danger and 8 or 2
      circfill(o.x, o.y, 3, col)
      circ(o.x, o.y, 3, obstacles_frozen and 12 or 8)
      -- satellite 1
      local sat1_x = o.x + cos(o.orbit_angle) * o.orbit_radius
      local sat1_y = o.y + sin(o.orbit_angle) * o.orbit_radius
      local sat_col = o.in_danger and 14 or 9
      circfill(sat1_x, sat1_y, 3, sat_col)
      if obstacles_frozen then
        circ(sat1_x, sat1_y, 3, 12)
      end
      -- satellite 2
      local sat2_x = o.x + cos(o.orbit_angle + 0.5) * o.orbit_radius
      local sat2_y = o.y + sin(o.orbit_angle + 0.5) * o.orbit_radius
      circfill(sat2_x, sat2_y, 3, sat_col)
      if obstacles_frozen then
        circ(sat2_x, sat2_y, 3, 12)
      end
      -- orbit lines
      circ(o.x, o.y, o.orbit_radius, 5)
    end
  end

  -- power-ups with pulse effect
  for p in all(powerups) do
    local pulse = sin(p.spawn_time / 10) * 1.5
    local r = 4 + pulse
    circfill(p.x, p.y, r, p.col)
    circ(p.x, p.y, r, 7)
    -- outer ring for emphasis
    if p.spawn_time < 30 then
      circ(p.x, p.y, r + 2, 7)
    end
  end

  -- particles
  for pt in all(particles) do
    pset(pt.x, pt.y, pt.col)
  end

  -- floating texts
  for ft in all(floating_texts) do
    -- fade based on remaining lifetime (30 frames total)
    local alpha_step = flr(ft.lifetime / 10)
    if alpha_step >= 2 then
      print(ft.text, ft.x, ft.y, ft.col)
    elseif alpha_step == 1 then
      -- dimmer color in middle fade
      print(ft.text, ft.x, ft.y, 5)
    end
  end

  -- ball trail effect (draw before ball)
  for tr in all(ball_trail) do
    local fade = 1 - (tr.age / 8)
    local vel_factor = min(1, tr.vel / 5)
    local intensity = fade * vel_factor
    if intensity > 0.2 then
      local trail_r = ball.r * fade
      local trail_col = 6  -- base trail color
      -- match ball color states
      if shield_time > 0 then
        trail_col = 11
      elseif combo >= 10 then
        trail_col = 15
      else
        trail_col = 10
      end
      -- fade to darker color
      if fade < 0.5 then
        trail_col = 5
      end
      circfill(tr.x, tr.y, trail_r, trail_col)
    end
  end

  -- magnet glow effect (draw before ball)
  if magnet_time > 0 then
    local pulse = sin(gametime / 8) * 1.5
    circ(ball.x, ball.y, ball.r + 4 + pulse, 11)  -- lime glow ring
    circ(ball.x, ball.y, ball.r + 6 + pulse, 3)  -- outer green ring
  end

  -- ball with flash effect, combo color, and skin
  local ball_col = get_ball_skin_color()  -- default to selected skin
  if ball_flash > 0 then
    ball_col = 7  -- white flash on collision
  elseif shield_time > 0 then
    ball_col = 11  -- cyan shield color
  elseif combo >= 10 then
    ball_col = 15  -- white for high combo
  end
  circfill(ball.x, ball.y, ball.r, ball_col)
  circ(ball.x, ball.y, ball.r, 7)

  -- ui
  print("score:"..score, 2, 2, 7)
  print("time:"..flr(gametime/30).."s", 2, 9, 7)
  -- lives counter with flash effect
  local lives_col = life_flash > 0 and (life_flash % 4 < 2 and 7 or 8) or 8
  print("lives:"..lives, 2, 16, lives_col)
  print("x"..multiplier, 100, 2, 9)
  -- combo counter with milestone colors
  local combo_col = 7  -- white default
  if combo >= 15 then
    combo_col = 14  -- pink for 15+
  elseif combo >= 10 then
    combo_col = 9  -- orange for 10+
  elseif combo >= 5 then
    combo_col = 10  -- yellow for 5+
  end
  print("combo:"..combo, 86, 9, combo_col)

  -- wave counter with pulse effect
  local wave_col = 10  -- yellow
  local wave_y = 16
  if wave_pulse > 0 then
    wave_col = wave_pulse % 4 < 2 and 9 or 10  -- pulse between orange and yellow
    wave_y = 16 + sin(wave_pulse / 4)  -- subtle bounce
  end
  print("wave:"..diff_level, 92, wave_y, wave_col)

  -- danger zone indicator
  local zone_str = "danger:"
  if danger_zones[1].active then zone_str = zone_str.."l" end
  if danger_zones[2].active then zone_str = zone_str.."c" end
  if danger_zones[3].active then zone_str = zone_str.."r" end
  if zone_str != "danger:" then
    print(zone_str, 2, 24, 8)
  end

  -- power-up indicators
  local ind_x = 2
  if shield_time > 0 then
    circfill(ind_x, 120, 3, 11)
    print("s", ind_x-1, 118, 7)
    ind_x += 10
  end
  if slowmo_time > 0 then
    circfill(ind_x, 120, 3, 12)
    print("m", ind_x-1, 118, 7)
    ind_x += 10
  end
  if doublescore_time > 0 then
    circfill(ind_x, 120, 3, 10)
    print("2", ind_x-1, 118, 7)
    ind_x += 10
  end
  if magnet_time > 0 then
    circfill(ind_x, 120, 3, 13)
    print("g", ind_x-1, 118, 7)
    ind_x += 10
  end
  if freeze_time > 0 then
    circfill(ind_x, 120, 3, 12)
    print("f", ind_x-1, 118, 7)
    ind_x += 10
  end
end

-- gameover state
function update_gameover()
  local input = test_input()

  -- check for leaderboard entry (only once)
  if not new_record and leaderboard_rank == 0 then
    -- determine if score ranks in top 10
    local rank = 0
    for i = 1, #leaderboard do
      if score > leaderboard[i].score then
        rank = i
        break
      end
    end
    -- also consider if leaderboard not full
    if rank == 0 and #leaderboard < 10 then
      rank = #leaderboard + 1
    end

    if rank > 0 then
      -- player achieved a leaderboard rank!
      leaderboard_rank = rank
      new_record = true
      new_record_flash = 60
      play_sfx(6)
      shake(20, 0.5)
      _log("leaderboard_rank:"..rank)
    end
  end

  -- if ranked, wait for O button to enter initials
  if leaderboard_rank > 0 and input & 16 > 0 then
    state = "enter_initials"
    _log("state:enter_initials")
    entry_initials = {"a", "a", "a"}
    entry_cursor = 1
    entry_saved = false
    input_cooldown = 15
    return
  end

  -- otherwise, O to retry
  if leaderboard_rank == 0 and input & 16 > 0 then
    state = "play"
    _log("state:play")
    init_game()
  end
end

function draw_gameover()
  -- title
  print("game over", 42, 10, 8)

  -- final score (prominent)
  print("final score", 38, 22, 7)
  print(score, 64 - #tostr(score) * 2, 30, 10)

  -- new leaderboard entry indicator (prominent)
  if new_record and leaderboard_rank > 0 then
    local flash_col = (new_record_flash % 8 < 4) and 10 or 9
    print("leaderboard rank #"..leaderboard_rank, 18, 38, flash_col)
    -- update flash timer
    if new_record_flash > 0 then
      new_record_flash -= 1
    end
  end

  -- best score display
  if #leaderboard > 0 then
    local top = leaderboard[1]
    print("best: "..top.score.." ("..top.initials..")", 20, 48, 12)
  end

  -- performance stats section
  print("-- performance --", 26, 58, 6)

  -- highest combo
  local combo_col = max_combo >= 10 and 15 or 11
  print("max combo: "..max_combo, 28, 66, combo_col)

  -- total dodges
  print("dodges: "..total_dodges, 32, 74, 9)

  -- powerups collected
  print("powerups: "..total_powerups, 28, 82, 11)

  -- lives used
  local lives_used = 3 - lives
  print("lives used: "..lives_used.."/3", 22, 90, 8)

  -- final multiplier
  print("multiplier: x"..multiplier, 24, 98, 10)

  -- average dodge bonus
  local avg_bonus = 0
  if total_dodges > 0 then
    avg_bonus = flr(total_dodge_bonus / total_dodges)
  end
  print("avg bonus: "..avg_bonus, 26, 106, 12)

  -- survival time
  print("time: "..flr(gametime/30).."s", 36, 114, 6)

  -- retry or enter initials prompt
  if leaderboard_rank > 0 then
    print("press o to enter name", 14, 122, 10)
  else
    print("press o to retry", 24, 122, 13)
  end
end

-- enter initials state
function update_enter_initials()
  local input = test_input()

  -- update cooldown
  if input_cooldown > 0 then
    input_cooldown -= 1
    return
  end

  if entry_saved then
    -- after saving, wait for O to continue
    if input & 16 > 0 then
      state = "play"
      _log("state:play")
      init_game()
    end
    return
  end

  -- navigate between letters (left/right)
  if input & 1 > 0 then  -- left
    entry_cursor = max(1, entry_cursor - 1)
    play_sfx(1)
    _log("initial_cursor:"..entry_cursor)
    input_cooldown = 8
  end
  if input & 2 > 0 then  -- right
    entry_cursor = min(3, entry_cursor + 1)
    play_sfx(1)
    _log("initial_cursor:"..entry_cursor)
    input_cooldown = 8
  end

  -- change letter (up/down)
  if input & 4 > 0 then  -- up
    local code = ord(entry_initials[entry_cursor])
    code = code == 122 and 97 or code + 1  -- wrap z->a
    entry_initials[entry_cursor] = chr(code)
    play_sfx(1)
    _log("initial_change:"..entry_initials[entry_cursor])
    input_cooldown = 5
  end
  if input & 8 > 0 then  -- down
    local code = ord(entry_initials[entry_cursor])
    code = code == 97 and 122 or code - 1  -- wrap a->z
    entry_initials[entry_cursor] = chr(code)
    play_sfx(1)
    _log("initial_change:"..entry_initials[entry_cursor])
    input_cooldown = 5
  end

  -- confirm with O button
  if input & 16 > 0 then
    if entry_cursor < 3 then
      -- move to next letter
      entry_cursor += 1
      play_sfx(1)
      input_cooldown = 10
    else
      -- save entry to leaderboard
      local initials_str = entry_initials[1]..entry_initials[2]..entry_initials[3]
      local new_entry = {
        score = score,
        initials = initials_str,
        timestamp = 0
      }

      -- insert at correct rank
      local inserted = false
      for i = 1, #leaderboard do
        if score > leaderboard[i].score then
          -- insert here
          local temp = {}
          for j = 1, i - 1 do
            add(temp, leaderboard[j])
          end
          add(temp, new_entry)
          for j = i, #leaderboard do
            if #temp < 10 then
              add(temp, leaderboard[j])
            end
          end
          leaderboard = temp
          inserted = true
          break
        end
      end

      -- if not inserted and room, append
      if not inserted and #leaderboard < 10 then
        add(leaderboard, new_entry)
      end

      -- save to cartdata
      save_leaderboard()
      last_entry_rank = leaderboard_rank  -- remember for highlight
      entry_saved = true
      play_sfx(6)
      shake(10, 0.3)
      _log("entry_saved:"..initials_str..":"..score)
      input_cooldown = 15
    end
  end

  -- skip with X button
  if input & 32 > 0 then
    state = "play"
    _log("state:play")
    _log("entry_skipped")
    init_game()
  end
end

function draw_enter_initials()
  print("new leaderboard entry!", 12, 20, 10)
  print("rank #"..leaderboard_rank, 48, 30, 11)

  if entry_saved then
    print("entry saved!", 34, 60, 7)
    print("score: "..score, 42, 70, 10)
    print("press o to continue", 16, 100, 13)
  else
    print("enter your initials:", 16, 50, 7)

    -- display initials with cursor
    local x_base = 40
    for i = 1, 3 do
      local col = (i == entry_cursor) and 10 or 6
      local char = entry_initials[i]
      print(char, x_base + (i - 1) * 16, 68, col)

      -- cursor indicator
      if i == entry_cursor then
        print("^", x_base + (i - 1) * 16, 76, 11)
      end
    end

    print("arrows: select/change", 12, 94, 13)
    print("o: confirm letter", 22, 102, 13)
    print("x: skip entry", 28, 110, 5)
  end
end

-- helper: get zone index for x position
function get_zone(x)
  for i = 1, 3 do
    if x >= danger_zones[i].x_min and x < danger_zones[i].x_max then
      return i
    end
  end
  return 0
end

-- obstacle spawning
function spawn_obstacle()
  -- build available types based on difficulty level
  local types = {"spike", "moving", "rotating"}

  -- check for new obstacle types with probability
  if diff_level >= 2 and rnd(1) < 0.20 then
    -- pendulum: 20% chance when diff_level >= 2
    spawn_pendulum()
    return
  end

  if diff_level >= 3 and rnd(1) < 0.15 then
    -- zigzag: 15% chance when diff_level >= 3
    spawn_zigzag()
    return
  end

  if diff_level >= 4 and rnd(1) < 0.10 then
    -- orbiter: 10% chance when diff_level >= 4
    spawn_orbiter()
    return
  end

  -- default obstacle types
  local t = types[flr(rnd(3)) + 1]
  local o = {
    x = 20 + rnd(88),
    y = -10,
    type = t,
    dodged = false,
    is_boss = false
  }

  if t == "spike" then
    o.r = 6
  elseif t == "moving" then
    o.r = 10
    o.vx = 0.5 + rnd(1)
    if rnd(1) > 0.5 then o.vx *= -1 end
  elseif t == "rotating" then
    o.r = 8
    o.angle = 0
  end

  -- assign zone
  o.zone = get_zone(o.x)
  o.in_danger = o.zone > 0 and danger_zones[o.zone].active or false

  add(obstacles, o)
  _log("spawn_obstacle:"..t..(o.in_danger and ":danger" or ""))
end

-- pendulum obstacle
function spawn_pendulum()
  local o = {
    x = 40 + rnd(48),
    y = -10,
    type = "pendulum",
    r = 7,
    dodged = false,
    is_boss = false,
    swing_time = 0,
    base_x = 0
  }
  o.base_x = o.x
  o.zone = get_zone(o.x)
  o.in_danger = o.zone > 0 and danger_zones[o.zone].active or false
  add(obstacles, o)
  _log("spawn_obstacle:pendulum"..(o.in_danger and ":danger" or ""))
end

-- zigzag obstacle
function spawn_zigzag()
  local o = {
    x = 20 + rnd(88),
    y = -10,
    type = "zigzag",
    r = 6,
    dodged = false,
    is_boss = false,
    zig_time = 0,
    zig_dir = rnd(1) > 0.5 and 1 or -1
  }
  o.zone = get_zone(o.x)
  o.in_danger = o.zone > 0 and danger_zones[o.zone].active or false
  add(obstacles, o)
  _log("spawn_obstacle:zigzag"..(o.in_danger and ":danger" or ""))
end

-- orbiter obstacle
function spawn_orbiter()
  local o = {
    x = 40 + rnd(48),
    y = -10,
    type = "orbiter",
    r = 5,
    dodged = false,
    is_boss = false,
    orbit_angle = 0,
    orbit_radius = 8
  }
  o.zone = get_zone(o.x)
  o.in_danger = o.zone > 0 and danger_zones[o.zone].active or false
  add(obstacles, o)
  _log("spawn_obstacle:orbiter"..(o.in_danger and ":danger" or ""))
end

-- boss obstacle spawning
function spawn_boss()
  local o = {
    x = 64,
    base_x = 64,
    y = -10,
    type = "boss",
    r = 13,
    dodged = false,
    is_boss = true,
    wave_time = 0
  }

  o.zone = get_zone(o.x)
  o.in_danger = o.zone > 0 and danger_zones[o.zone].active or false

  add(obstacles, o)
  _log("spawn_obstacle:boss"..(o.in_danger and ":danger" or ""))
  play_sfx(6)  -- boss spawn sound
  shake(8, 1.0)  -- screen shake on boss spawn
end

-- power-up spawning
function spawn_powerup()
  local types = {"shield", "slowmo", "doublescore", "magnet", "bomb", "freeze"}
  local t = types[flr(rnd(6)) + 1]
  local cols = {shield = 11, slowmo = 12, doublescore = 10, magnet = 13, bomb = 8, freeze = 12}

  local x = 20 + rnd(88)

  -- 75% chance to avoid active danger zones
  if rnd(1) > 0.25 then
    local attempts = 0
    while attempts < 10 do
      x = 20 + rnd(88)
      local zone = get_zone(x)
      if zone == 0 or not danger_zones[zone].active then
        break  -- safe zone found
      end
      attempts += 1
    end
  end

  local p = {
    x = x,
    y = -10,
    type = t,
    col = cols[t],
    spawn_time = 0  -- for pulse effect
  }

  add(powerups, p)
  _log("spawn_powerup:"..t)
end

-- power-up collection
function collect_powerup(p)
  local bonus = flr(50 * multiplier * (doublescore_time > 0 and 2 or 1))
  score += bonus
  total_powerups += 1
  _log("powerup_collected:"..p.type)
  _log("powerup_bonus:"..bonus)
  _log("total_powerups:"..total_powerups)

  -- track power-up type for achievement
  power_types_collected[p.type] = true

  -- check if collected from danger zone
  local zone = get_zone(p.x)
  if zone > 0 and danger_zones[zone].active then
    danger_zone_pickups += 1
    _log("danger_zone_pickup:"..danger_zone_pickups)
  end

  shake(8, 1.0)  -- medium shake on powerup collection

  -- floating text for score bonus
  add_floating_text(p.x - 6, p.y - 10, "+"..bonus, 10)

  if p.type == "shield" then
    shield_time = 90
    -- restore 1 life (up to max 3)
    if lives < 3 then
      lives += 1
      _log("life_restored")
      _log("lives:"..lives)
    end
    play_sfx(2)  -- shield powerup
    add_floating_text(p.x - 12, p.y - 20, "shield!", 11)
  elseif p.type == "slowmo" then
    slowmo_time = 60
    play_sfx(3)  -- slowmo powerup
    add_floating_text(p.x - 12, p.y - 20, "slowmo!", 12)
  elseif p.type == "doublescore" then
    doublescore_time = 150
    play_sfx(4)  -- doublescore powerup
    add_floating_text(p.x - 18, p.y - 20, "double score!", 10)
  elseif p.type == "magnet" then
    magnet_time = 240  -- 8 seconds at 30fps
    play_sfx(2)  -- magnet powerup
    add_floating_text(p.x - 12, p.y - 20, "magnet!", 13)
    _log("powerup:magnet")
  elseif p.type == "bomb" then
    -- clear obstacles within radius
    local cleared = 0
    for o in all(obstacles) do
      local dist = sqrt((o.x - ball.x)^2 + (o.y - ball.y)^2)
      if dist < 40 then
        del(obstacles, o)
        add_particles(o.x, o.y, 15, 8)  -- red explosion particles
        cleared += 1
      end
    end
    play_sfx(5)  -- bomb powerup (explosion sound)
    shake(12, 1.5)  -- strong shake on bomb
    screen_flash = 8  -- flash screen
    add_floating_text(p.x - 10, p.y - 20, "bomb!", 8)
    _log("powerup:bomb:cleared="..cleared)
  elseif p.type == "freeze" then
    freeze_time = 180  -- 6 seconds at 30fps
    play_sfx(3)  -- freeze powerup
    add_floating_text(p.x - 12, p.y - 20, "freeze!", 12)
    _log("powerup:freeze")
  end

  add_particles(p.x, p.y, 20, p.col)  -- larger particle burst
end

-- particle system
function add_particles(x, y, count, col)
  for i = 1, count do
    add(particles, {
      x = x,
      y = y,
      vx = rnd(2) - 1,
      vy = rnd(2) - 1,
      col = col,
      life = 15 + rnd(10)
    })
  end
end

-- floating text system
function add_floating_text(x, y, text, col)
  add(floating_texts, {
    x = x,
    y = y,
    text = text,
    col = col,
    vy = -0.5,
    lifetime = 30
  })
  _log("floating_text:"..text)
end

-- practice mode: obstacle selection
function update_practice_obstacle_select()
  local input = test_input()

  -- update cooldown
  if input_cooldown > 0 then
    input_cooldown -= 1
  end

  -- navigation with cooldown
  if input_cooldown == 0 then
    if input & 4 > 0 then  -- up
      practice_obstacle_selection = max(1, practice_obstacle_selection - 1)
      play_sfx(1)
      _log("practice_obstacle_nav:up")
      input_cooldown = 10
    end
    if input & 8 > 0 then  -- down
      practice_obstacle_selection = min(7, practice_obstacle_selection + 1)
      play_sfx(1)
      _log("practice_obstacle_nav:down")
      input_cooldown = 10
    end
  end

  -- confirm selection
  if input & 16 > 0 then  -- O button
    practice_obstacle_type = practice_obstacle_types[practice_obstacle_selection]
    _log("practice_obstacle_selected:"..practice_obstacle_type)
    state = "practice_speed_select"
    _log("state:practice_speed_select")
    input_cooldown = 10
  end

  -- back to menu
  if input & 32 > 0 then  -- X button
    state = "menu"
    _log("state:menu")
    input_cooldown = 10
  end
end

function draw_practice_obstacle_select()
  print("practice mode", 32, 20, 7)
  print("select obstacle", 28, 30, 6)

  -- draw obstacle options
  local y = 45
  for i = 1, 7 do
    local col = (i == practice_obstacle_selection) and 10 or 13
    local prefix = (i == practice_obstacle_selection) and "> " or "  "
    print(prefix..practice_obstacle_types[i], 32, y, col)
    y += 10
  end

  print("o: select  x: back", 14, 118, 5)
end

-- practice mode: speed selection
function update_practice_speed_select()
  local input = test_input()

  -- update cooldown
  if input_cooldown > 0 then
    input_cooldown -= 1
  end

  -- navigation with cooldown
  if input_cooldown == 0 then
    if input & 4 > 0 then  -- up
      practice_speed_selection = max(1, practice_speed_selection - 1)
      play_sfx(1)
      _log("practice_speed_nav:up")
      input_cooldown = 10
    end
    if input & 8 > 0 then  -- down
      practice_speed_selection = min(3, practice_speed_selection + 1)
      play_sfx(1)
      _log("practice_speed_nav:down")
      input_cooldown = 10
    end
  end

  -- confirm selection
  if input & 16 > 0 then  -- O button
    practice_speed_modifier = practice_speed_values[practice_speed_selection]
    _log("practice_speed_selected:"..practice_speed_names[practice_speed_selection])
    state = "practice_play"
    _log("state:practice_play")
    init_practice_game()
  end

  -- back to obstacle select
  if input & 32 > 0 then  -- X button
    state = "practice_obstacle_select"
    _log("state:practice_obstacle_select")
    input_cooldown = 10
  end
end

function draw_practice_speed_select()
  print("practice mode", 32, 20, 7)
  print("select speed", 32, 30, 6)

  print("obstacle: "..practice_obstacle_type, 20, 45, 13)

  -- draw speed options
  local y = 60
  for i = 1, 3 do
    local col = (i == practice_speed_selection) and 10 or 13
    local prefix = (i == practice_speed_selection) and "> " or "  "
    local mult = practice_speed_values[i].."x"
    print(prefix..practice_speed_names[i].." ("..mult..")", 32, y, col)
    y += 12
  end

  print("o: start  x: back", 18, 118, 5)
end

-- practice mode: gameplay initialization
function init_practice_game()
  ball.x = 64
  ball.y = 100
  ball.vx = 0
  ball.vy = 0
  ball.grounded = false
  obstacles = {}
  particles = {}
  floating_texts = {}
  ball_trail = {}
  obs_timer = 0
  practice_collisions = 0
  practice_pause_timer = 0

  -- apply speed modifier to scroll and spawn
  scroll_speed = 0.5 * practice_speed_modifier
  obs_interval = flr(60 / practice_speed_modifier)

  _log("practice_game_init:type="..practice_obstacle_type..",speed="..practice_speed_modifier)
end

-- practice mode: spawn selected obstacle
function spawn_practice_obstacle()
  if practice_obstacle_type == "spike" then
    local o = {x = 20 + rnd(88), y = -10, type = "spike", r = 6, dodged = false, is_boss = false}
    add(obstacles, o)
    _log("practice_spawn:spike")
  elseif practice_obstacle_type == "moving" then
    local o = {x = 20 + rnd(88), y = -10, type = "moving", r = 10, vx = 0.5 + rnd(1), dodged = false, is_boss = false}
    if rnd(1) > 0.5 then o.vx *= -1 end
    add(obstacles, o)
    _log("practice_spawn:moving")
  elseif practice_obstacle_type == "rotating" then
    local o = {x = 20 + rnd(88), y = -10, type = "rotating", r = 8, angle = 0, dodged = false, is_boss = false}
    add(obstacles, o)
    _log("practice_spawn:rotating")
  elseif practice_obstacle_type == "pendulum" then
    local o = {x = 40 + rnd(48), y = -10, type = "pendulum", r = 7, swing_time = 0, base_x = 0, dodged = false, is_boss = false}
    o.base_x = o.x
    add(obstacles, o)
    _log("practice_spawn:pendulum")
  elseif practice_obstacle_type == "zigzag" then
    local o = {x = 20 + rnd(88), y = -10, type = "zigzag", r = 6, zig_time = 0, zig_dir = rnd(1) > 0.5 and 1 or -1, dodged = false, is_boss = false}
    add(obstacles, o)
    _log("practice_spawn:zigzag")
  elseif practice_obstacle_type == "orbiter" then
    local o = {x = 40 + rnd(48), y = -10, type = "orbiter", r = 5, orbit_angle = 0, orbit_radius = 8, dodged = false, is_boss = false}
    add(obstacles, o)
    _log("practice_spawn:orbiter")
  elseif practice_obstacle_type == "boss" then
    local o = {x = 64, base_x = 64, y = -10, type = "boss", r = 13, wave_time = 0, dodged = false, is_boss = true}
    add(obstacles, o)
    _log("practice_spawn:boss")
  end
end

-- practice mode: gameplay update
function update_practice_play()
  -- handle pause timer (1 second pause after collision)
  if practice_pause_timer > 0 then
    practice_pause_timer -= 1
    if practice_pause_timer == 0 then
      -- reset ball after pause
      ball.x = 64
      ball.y = 100
      ball.vx = 0
      ball.vy = 0
      ball.grounded = false
      _log("practice_reset")
    end
    return
  end

  local input = test_input()

  -- exit to menu
  if input & 32 > 0 then  -- X button
    state = "menu"
    _log("state:menu")
    return
  end

  -- ball physics (same as normal play)
  -- steering
  if input & 1 > 0 then ball.vx -= 0.5 end  -- left
  if input & 2 > 0 then ball.vx += 0.5 end  -- right

  -- velocity limits
  ball.vx = mid(-3, ball.vx, 3)

  -- gravity and floor
  if ball.y < 100 then
    ball.vy += 0.2
  else
    ball.y = 100
    ball.vy = 0
    ball.grounded = true
  end

  -- floor bounce
  if ball.y >= 100 and ball.vy > 0 then
    ball.vy = -4
  end

  -- apply velocity
  ball.x += ball.vx
  ball.y += ball.vy

  -- friction
  ball.vx *= 0.9

  -- wall bounce
  if ball.x < ball.r then
    ball.x = ball.r
    ball.vx = abs(ball.vx)
  end
  if ball.x > 128 - ball.r then
    ball.x = 128 - ball.r
    ball.vx = -abs(ball.vx)
  end

  -- update trail
  if #ball_trail < max_trail_length then
    add(ball_trail, {x = ball.x, y = ball.y, life = 10})
  else
    for i = 1, max_trail_length - 1 do
      ball_trail[i] = ball_trail[i + 1]
    end
    ball_trail[max_trail_length] = {x = ball.x, y = ball.y, life = 10}
  end

  for t in all(ball_trail) do
    t.life -= 1
  end

  -- spawn obstacles
  obs_timer += 1
  if obs_timer >= obs_interval then
    spawn_practice_obstacle()
    obs_timer = 0
  end

  -- update obstacles (same movement logic as normal game)
  for o in all(obstacles) do
    o.y += scroll_speed

    -- obstacle type movement
    if o.type == "moving" then
      o.x += o.vx
      if o.x < 10 or o.x > 118 then o.vx *= -1 end
    elseif o.type == "rotating" then
      o.angle += 0.05
    elseif o.type == "pendulum" then
      o.swing_time += 0.04
      o.x = o.base_x + sin(o.swing_time) * 25
    elseif o.type == "zigzag" then
      o.zig_time += 0.1
      local amplitude = 15
      o.x += o.zig_dir * 1.5
      if o.x < 10 or o.x > 118 then o.zig_dir *= -1 end
    elseif o.type == "orbiter" then
      o.orbit_angle += 0.05
    elseif o.type == "boss" then
      o.wave_time += 0.03
      o.x = o.base_x + sin(o.wave_time) * 30
    end

    -- collision detection
    local dist
    if o.type == "orbiter" then
      -- check center + 2 satellites
      local dx = ball.x - o.x
      local dy = ball.y - o.y
      dist = sqrt(dx * dx + dy * dy)
      if dist < ball.r + 3 then
        practice_collision()
      else
        -- check satellites
        for angle_offset = 0, 1, 0.5 do
          local sat_x = o.x + cos(o.orbit_angle + angle_offset) * o.orbit_radius
          local sat_y = o.y + sin(o.orbit_angle + angle_offset) * o.orbit_radius
          local sdx = ball.x - sat_x
          local sdy = ball.y - sat_y
          local sdist = sqrt(sdx * sdx + sdy * sdy)
          if sdist < ball.r + 3 then
            practice_collision()
            break
          end
        end
      end
    else
      local dx = ball.x - o.x
      local dy = ball.y - o.y
      dist = sqrt(dx * dx + dy * dy)
      if dist < ball.r + o.r then
        practice_collision()
      end
    end

    -- remove off-screen obstacles
    if o.y > 140 then
      del(obstacles, o)
    end
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

  -- update floating texts
  for ft in all(floating_texts) do
    ft.y += ft.vy
    ft.lifetime -= 1
    if ft.lifetime <= 0 then
      del(floating_texts, ft)
    end
  end
end

function practice_collision()
  if practice_pause_timer > 0 then return end  -- already in pause

  practice_collisions += 1
  practice_pause_timer = 30  -- 1 second at 30fps
  add_particles(ball.x, ball.y, 15, 8)
  play_sfx(4)
  _log("practice_collision:"..practice_collisions)
end

function draw_practice_play()
  -- draw ball trail
  for i, t in pairs(ball_trail) do
    if t.life > 0 then
      local trail_col = (ball_skin == 1 and 6) or (ball_skin == 2 and 9) or 12
      circfill(t.x, t.y, 1, trail_col)
    end
  end

  -- draw ball
  local ball_col = (ball_skin == 1 and 7) or (ball_skin == 2 and 10) or 12
  circfill(ball.x, ball.y, ball.r, ball_col)

  -- draw obstacles (same as normal play)
  for o in all(obstacles) do
    if o.type == "spike" then
      circfill(o.x, o.y, o.r, 8)
    elseif o.type == "moving" then
      circfill(o.x, o.y, o.r, 14)
    elseif o.type == "rotating" then
      circfill(o.x, o.y, o.r, 12)
      local rx = o.x + cos(o.angle) * 6
      local ry = o.y + sin(o.angle) * 6
      line(o.x, o.y, rx, ry, 7)
    elseif o.type == "pendulum" then
      line(o.base_x, 0, o.x, o.y, 6)
      circfill(o.x, o.y, o.r, 13)
    elseif o.type == "zigzag" then
      circfill(o.x, o.y, o.r, 11)
    elseif o.type == "orbiter" then
      circfill(o.x, o.y, 3, 9)
      circ(o.x, o.y, o.orbit_radius, 5)
      for angle_offset = 0, 1, 0.5 do
        local sat_x = o.x + cos(o.orbit_angle + angle_offset) * o.orbit_radius
        local sat_y = o.y + sin(o.orbit_angle + angle_offset) * o.orbit_radius
        circfill(sat_x, sat_y, 3, 10)
      end
    elseif o.type == "boss" then
      circfill(o.x, o.y, o.r, 8)
      circ(o.x, o.y, o.r + 2, 2)
    end
  end

  -- draw particles
  for p in all(particles) do
    pset(p.x, p.y, p.col)
  end

  -- draw floating texts
  for ft in all(floating_texts) do
    print(ft.text, ft.x, ft.y, ft.col)
  end

  -- draw UI: obstacle type, speed, collision count
  print("practice", 2, 2, 13)
  print(practice_obstacle_type, 2, 9, 10)
  print(practice_speed_names[practice_speed_selection].." ("..practice_speed_modifier.."x)", 2, 16, 11)
  print("hits: "..practice_collisions, 2, 23, 8)
  print("x: exit", 88, 2, 5)

  -- show pause indicator
  if practice_pause_timer > 0 then
    print("resetting...", 36, 64, 7)
  end
end

-- daily challenge state
function update_challenge()
  -- countdown timer
  if challenge_time_left > 0 then
    challenge_time_left -= 1
  else
    -- time's up, end challenge
    challenge_active = false
    if challenge_score > challenge_best then
      challenge_best = challenge_score
    end
    save_daily_challenge()
    state = "challenge_summary"
    _log("state:challenge_summary:score="..challenge_score..",best="..challenge_best)
    return
  end

  -- update pulse effect (increases urgency as time runs out)
  if challenge_time_left < 30 * 30 then  -- last 30 seconds
    challenge_pulse = (challenge_pulse + 1) % 30
  end

  -- reuse play logic
  gametime += 1

  -- update pause cooldown
  if pause_cooldown > 0 then
    pause_cooldown -= 1
  end

  -- check for X button to quit (with cooldown)
  local input = test_input()
  if input & 32 > 0 and pause_cooldown == 0 then  -- X button
    challenge_active = false
    state = "menu"
    _log("state:menu:challenge_quit")
    pause_cooldown = 15
    return
  end

  -- ball physics (reuse input variable instead of calling test_input() again)
  if input & 1 > 0 then  -- left
    ball.vx = max(ball.vx - 0.5, -2.5)
  end
  if input & 2 > 0 then  -- right
    ball.vx = min(ball.vx + 0.5, 2.5)
  end

  -- apply friction
  ball.vx *= 0.85

  -- apply gravity
  if not ball.grounded then
    ball.vy += 0.4
  end

  -- update position
  ball.x += ball.vx
  ball.y += ball.vy

  -- floor collision
  if ball.y >= 120 then
    ball.y = 120
    ball.vy = -ball.vy * 0.7
    ball.grounded = abs(ball.vy) < 0.5
  else
    ball.grounded = false
  end

  -- wall collision
  if ball.x <= ball.r then
    ball.x = ball.r
    ball.vx = -ball.vx * 0.7
  elseif ball.x >= 128 - ball.r then
    ball.x = 128 - ball.r
    ball.vx = -ball.vx * 0.7
  end

  -- spawn obstacles (use challenge difficulty)
  obs_timer += 1
  if obs_timer >= obs_interval then
    spawn_obstacle()
    obs_timer = 0
  end

  -- spawn power-ups
  pu_timer += 1
  if pu_timer >= 240 then
    spawn_powerup()
    pu_timer = 0
  end

  -- update obstacles
  for o in all(obstacles) do
    o.y += scroll_speed
    if o.type == "moving" then
      o.x += o.vx
      if o.x <= o.r or o.x >= 128 - o.r then
        o.vx = -o.vx
      end
    elseif o.type == "rotating" then
      o.angle += 0.05
    elseif o.type == "pendulum" then
      o.swing_time += 0.04
      o.x = o.base_x + sin(o.swing_time) * 25
    elseif o.type == "zigzag" then
      o.x += o.dir * 0.8
      if o.x <= 10 or o.x >= 118 then
        o.dir = -o.dir
      end
    elseif o.type == "orbiter" then
      o.orbit_angle += 0.05
    elseif o.type == "boss" then
      o.move_time += 0.03
      o.x = o.base_x + sin(o.move_time) * 30
    end

    -- remove off-screen obstacles
    if o.y > 140 then
      del(obstacles, o)
      -- dodge bonus (2x for challenge mode)
      local bonus = flr(10 * multiplier * 2)
      challenge_score += bonus
      combo += 1
      max_combo = max(max_combo, combo)
      total_dodges += 1
      total_dodge_bonus += bonus
      add_floating_text("+"..bonus, ball.x, ball.y - 10, 10)
      -- increase multiplier (3x growth for challenge mode)
      multiplier = min(multiplier + 0.15, 5.0)
      spawn_particles(ball.x, ball.y, 15, 10)
      play_sfx(0)
      _log("dodge:combo="..combo..",mult="..multiplier..",bonus="..bonus)

      -- check combo milestones
      local milestone = 0
      if combo == 5 then milestone = 5
      elseif combo == 10 then milestone = 10
      elseif combo == 15 then milestone = 15
      elseif combo == 20 then milestone = 20
      elseif combo == 25 then milestone = 25
      elseif combo >= 30 then milestone = 30 end

      if milestone > 0 and milestone > last_milestone then
        last_milestone = milestone
        local m_col = (milestone <= 10 and 10) or (milestone <= 20 and 9) or 14
        add_floating_text("combo "..milestone.."!", 46, 50, m_col)
        shake_screen(3, 0.25)
        play_sfx(7)
        _log("milestone:"..milestone)
      end
    end
  end

  -- update power-ups
  for pu in all(powerups) do
    pu.y += scroll_speed * 0.8
    if pu.y > 130 then
      del(powerups, pu)
    end

    -- check collision with ball
    local dx = pu.x - ball.x
    local dy = pu.y - ball.y
    local dist = sqrt(dx * dx + dy * dy)
    if dist < ball.r + 3 then
      collect_powerup(pu)
      del(powerups, pu)
    end
  end

  -- update power-up timers
  if shield_time > 0 then shield_time -= 1 end
  if slowmo_time > 0 then slowmo_time -= 1 end
  if doublescore_time > 0 then doublescore_time -= 1 end
  if magnet_time > 0 then magnet_time -= 1 end
  if freeze_time > 0 then freeze_time -= 1 end

  -- magnet effect
  if magnet_time > 0 then
    for pu in all(powerups) do
      local dx = ball.x - pu.x
      local dy = ball.y - pu.y
      local dist = sqrt(dx * dx + dy * dy)
      if dist > 0 and dist < 40 then
        pu.x += (dx / dist) * 1.5
        pu.y += (dy / dist) * 1.5
      end
    end
  end

  -- check obstacle collision
  for o in all(obstacles) do
    local collision = false

    if o.type == "orbiter" then
      -- check center
      local dx = o.x - ball.x
      local dy = o.y - ball.y
      local dist = sqrt(dx * dx + dy * dy)
      if dist < ball.r + 3 then collision = true end

      -- check satellites
      if not collision then
        for angle_offset = 0, 1, 0.5 do
          local sat_x = o.x + cos(o.orbit_angle + angle_offset) * o.orbit_radius
          local sat_y = o.y + sin(o.orbit_angle + angle_offset) * o.orbit_radius
          local sdx = sat_x - ball.x
          local sdy = sat_y - ball.y
          local sdist = sqrt(sdx * sdx + sdy * sdy)
          if sdist < ball.r + 3 then
            collision = true
            break
          end
        end
      end
    else
      -- standard collision
      local dx = o.x - ball.x
      local dy = o.y - ball.y
      local dist = sqrt(dx * dx + dy * dy)
      if dist < ball.r + o.r then
        collision = true
      end
    end

    if collision and shield_time == 0 then
      -- collision detected
      lives -= 1
      life_flash = 20
      combo = 0
      last_milestone = 0
      multiplier = max(1.0, multiplier - 0.5)
      shake_screen(10, 1.5)
      spawn_particles(ball.x, ball.y, 20, 8)
      play_sfx(4)
      _log("collision:lives="..lives..",mult="..multiplier)
      del(obstacles, o)

      if lives <= 0 then
        -- game over
        challenge_active = false
        if challenge_score > challenge_best then
          challenge_best = challenge_score
        end
        save_daily_challenge()
        state = "challenge_summary"
        _log("state:challenge_summary:death:score="..challenge_score..",best="..challenge_best)
        return
      end
    end
  end

  -- update ball trail
  if gametime % 3 == 0 then
    add(ball_trail, {x = ball.x, y = ball.y, life = 5})
    if #ball_trail > max_trail_length then
      del(ball_trail, ball_trail[1])
    end
  end
  for t in all(ball_trail) do
    t.life -= 1
    if t.life <= 0 then
      del(ball_trail, t)
    end
  end

  -- update particles
  for p in all(particles) do
    p.x += p.vx
    p.y += p.vy
    p.vy += 0.1
    p.life -= 1
    if p.life <= 0 then
      del(particles, p)
    end
  end

  -- update floating texts
  for ft in all(floating_texts) do
    ft.y -= 0.5
    ft.life -= 1
    if ft.life <= 0 then
      del(floating_texts, ft)
    end
  end

  -- difficulty progression
  if gametime % 300 == 0 and gametime > 0 then
    diff_level = min(diff_level + 1, 10)
    wave_pulse = 20
    _log("difficulty_up:"..diff_level)
  end
end

function draw_challenge()
  -- draw ball trail
  for i, t in pairs(ball_trail) do
    if t.life > 0 then
      local trail_col = (ball_skin == 1 and 6) or (ball_skin == 2 and 9) or 12
      circfill(t.x, t.y, 1, trail_col)
    end
  end

  -- draw ball
  local ball_col = (ball_skin == 1 and 7) or (ball_skin == 2 and 10) or 12
  if ball_flash > 0 then ball_col = 7 end
  circfill(ball.x, ball.y, ball.r, ball_col)

  -- draw obstacles (same as normal play)
  for o in all(obstacles) do
    if o.type == "spike" then
      circfill(o.x, o.y, o.r, 8)
    elseif o.type == "moving" then
      circfill(o.x, o.y, o.r, 14)
    elseif o.type == "rotating" then
      circfill(o.x, o.y, o.r, 12)
      local rx = o.x + cos(o.angle) * 6
      local ry = o.y + sin(o.angle) * 6
      line(o.x, o.y, rx, ry, 7)
    elseif o.type == "pendulum" then
      line(o.base_x, 0, o.x, o.y, 6)
      circfill(o.x, o.y, o.r, 13)
    elseif o.type == "zigzag" then
      circfill(o.x, o.y, o.r, 11)
    elseif o.type == "orbiter" then
      circfill(o.x, o.y, 3, 9)
      circ(o.x, o.y, o.orbit_radius, 5)
      for angle_offset = 0, 1, 0.5 do
        local sat_x = o.x + cos(o.orbit_angle + angle_offset) * o.orbit_radius
        local sat_y = o.y + sin(o.orbit_angle + angle_offset) * o.orbit_radius
        circfill(sat_x, sat_y, 3, 10)
      end
    elseif o.type == "boss" then
      circfill(o.x, o.y, o.r, 8)
      circ(o.x, o.y, o.r + 2, 2)
    end
  end

  -- draw power-ups
  for pu in all(powerups) do
    local pu_col = pu.type == "shield" and 11 or pu.type == "slowmo" and 12 or pu.type == "doublescore" and 10 or pu.type == "magnet" and 9 or pu.type == "bomb" and 8 or 14
    circfill(pu.x, pu.y, 3, pu_col)
    if pu.type == "magnet" and magnet_time > 0 then
      circ(pu.x, pu.y, 5 + sin(gametime * 0.1) * 2, pu_col)
    end
  end

  -- draw particles
  for p in all(particles) do
    pset(p.x, p.y, p.col)
  end

  -- draw floating texts
  for ft in all(floating_texts) do
    print(ft.text, ft.x, ft.y, ft.col)
  end

  -- draw UI with urgency theme
  local time_sec = flr(challenge_time_left / 30)
  local time_col = 7
  if time_sec <= 10 then
    time_col = (challenge_pulse < 15) and 8 or 9  -- pulse red/orange
  elseif time_sec <= 30 then
    time_col = 9  -- orange
  end

  print("challenge", 2, 2, 8)
  print("time: "..time_sec.."s", 2, 9, time_col)
  print("score: "..challenge_score, 2, 16, 10)

  -- combo counter
  if combo > 0 then
    local combo_col = (combo >= 20 and 14) or (combo >= 10 and 9) or 10
    print("x"..combo, 100, 2, combo_col)
  end

  -- multiplier
  local mult_text = multiplier.."x"
  local mult_col = (multiplier >= 3.0 and 14) or (multiplier >= 2.0 and 9) or 10
  print(mult_text, 100, 9, mult_col)

  -- lives
  for i = 1, lives do
    local life_col = life_flash > 0 and 8 or 11
    circfill(2 + (i - 1) * 6, 120, 2, life_col)
  end

  -- power-up indicators
  local pu_y = 110
  if shield_time > 0 then
    print("shield", 2, pu_y, 11)
    pu_y -= 6
  end
  if slowmo_time > 0 then
    print("slow", 2, pu_y, 12)
    pu_y -= 6
  end
  if doublescore_time > 0 then
    print("2x", 2, pu_y, 10)
    pu_y -= 6
  end
  if magnet_time > 0 then
    print("magnet", 2, pu_y, 9)
    pu_y -= 6
  end
  if freeze_time > 0 then
    print("freeze", 2, pu_y, 14)
  end

  print("x: quit", 88, 120, 5)
end

-- challenge summary state
function update_challenge_summary()
  local input = test_input()

  -- cooldown
  if input_cooldown > 0 then
    input_cooldown -= 1
  end

  if input_cooldown == 0 and (input & 16 > 0 or input & 32 > 0) then  -- O or X
    state = "menu"
    _log("state:menu:challenge_summary_exit")
    input_cooldown = 10
  end
end

function draw_challenge_summary()
  print("challenge complete!", 22, 30, 7)

  print("your score: "..challenge_score, 28, 50, 10)
  print("today's best: "..challenge_best, 22, 60, challenge_score == challenge_best and 10 or 6)

  -- show previous days
  if #daily_history > 0 then
    print("recent history:", 28, 75, 14)
    local y = 85
    for i = 1, min(3, #daily_history) do
      local entry = daily_history[#daily_history - i + 1]
      local days_ago = challenge_seed - entry.seed
      local label = days_ago == 0 and "today" or (days_ago == 1 and "yesterday" or (days_ago.." days ago"))
      print(label..": "..entry.score, 20, y, 6)
      y += 8
    end
  end

  print("press o or x to return", 12, 115, 5)
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
000100003305035050330502e0502e0502a0502805023050200501d0501805014050100500c050090500605004050030500205001050000500005000050000500005000050000500005000050000500005000050
000100001c3501c3501c3501a3501a3501735015350123501035000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000
0002000018050180501a0501c0501e0502105024050270502a0502d05030050330503505037050390503b0503c0503d0503e0503e0503e0503d0503c0503a050380503505032050300502d0502a05027050240500
000200001c2501c2501e2501f25021250242502725029250240501f0501c0501905016050140501205010050000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000240503005038050300502a0503005028050300502405030050380503005024050300502805030050200502a05035050300502805024050200501c0500000000000000000000000000000000000000000
00020000180501e050240501e05018050180501e050240502a0502a0502a0502805027050250502405022050210501f0501d0501c0501a05018050160501405012050100500e0500c0500a050080500605004050
00040000240502405024050240502705027050270502705029050290502905029050270502705027050270502405024050240502405020050200502005020050190501905019050190501605016050160501605014
0004000000050000500005000050000502405027050290502c0502e050300503205034050360503805039050390503a0503a0503a050390503805037050360503405032050300502e0502c0502905027050240500
001000000c0530c0530c0530c0530e0530e0530e0530e053100531005310053100531105311053110531105313053130531305313053110531105311053110530e0530e0530e0530e0530c0530c0530c0530c053
001000001805318053180531805318053180531805318053180531805318053180531805318053180531805318053180531805318053180531805318053180531605316053160531605314053140531405314053
0010000024053240532405324053240532405324053240532705327053270532705327053270532705327053290532905329053290532705327053270532705324053240532405324053200532005320053200531
001000000c0330c0330c0330c033000000000000000000000e0330e0330e0330e03300000000000000000000000000000000000000001103311033110331103300000000000000000013033130331303313033000
__music__
01 08090a0b
01 08090a0b
01 08090a0b
01 08090a0b
__label__
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117777777777777777777777111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777aaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777aaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777aaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111777aaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111177aaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111177aaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111177aaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111177aaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111117aaaaaaaaaaaaa71111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111117aaaaaaaaaaaaa71111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111117aaaaaaaaaaaaa71111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111111117aaaaaaaaaaaaa71111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117aaaaaaaaaaaaaaa7111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117aaaaaaaaaaaaaaa7111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117aaaaaaaaaaaaaaa7111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111117aaaaaaaaaaaaaaa7111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117aaaaaaaaaaaaaaaaa711111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117aaaaaaaaaaaaaaaaa711111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117aaaaaaaaaaaaaaaaa711111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111117aaaaaaaaaaaaaaaaa711111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111117aaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111117aaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111117aaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111111117aaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111117aaaaaaaaaaaaaaaaaaaaa771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaa77111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaa77111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaa77111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaa77111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaa777111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaa777111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaa777111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaa777111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaa7771111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaa777771111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaa777771111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaa777771111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaa777771111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaa77777771111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaa77777771111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaa77777771111111111111111111111111111111111111111111111111111111111111111
111111111111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaa77777771111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaa7777777771111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaa7777777771111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaa7777777771111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaa7777777771111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777771111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777771111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777771111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777771111111111111111111111111111111111111111111111111111111111
111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777771111111111111111111111111111111111111111111111111111111
111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777771111111111111111111111111111111111111111111111111111111
111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777771111111111111111111111111111111111111111111111111111111
111111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777771111111111111111111111111111111111111111111111111111111
11111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777771111111111111111111111111111111111111111111111111111
11111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777771111111111111111111111111111111111111111111111111111
11111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777771111111111111111111111111111111111111111111111111111
11111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777771111111111111111111111111111111111111111111111111111
1111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777771111111111111111111111111111111111111111111111111
1111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777771111111111111111111111111111111111111111111111111
1111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777771111111111111111111111111111111111111111111111111
1111111111111111111111111777aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777771111111111111111111111111111111111111111111111111
11111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777777777771111111111111111111111111111111111111111111111
11111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777777777771111111111111111111111111111111111111111111111
11111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777777777771111111111111111111111111111111111111111111111
11111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa77777777777777777771111111111111111111111111111111111111111111111
1111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777777777771111111111111111111111111111111111111111111
1111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777777777771111111111111111111111111111111111111111111
1111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777777777771111111111111111111111111111111111111111111
1111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa7777777777777777777771111111111111111111111111111111111111111111
111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777777777771111111111111111111111111111111111111111
111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777777777771111111111111111111111111111111111111111
111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777777777771111111111111111111111111111111111111111
111111111111111111111177aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa777777777777777777777771111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
