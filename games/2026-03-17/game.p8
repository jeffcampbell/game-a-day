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
max_levels = 8
game_won = false
level_intro_timer = 0
music_playing = -1  -- track which music pattern is playing

-- combo system
combo_count = 0  -- current combo multiplier (1x, 2x, 3x, etc.)
combo_window = 0  -- frames remaining in combo window (5 seconds = 300 frames)

-- milestone tracking for score celebrations
milestone_1000 = false
milestone_5000 = false

-- visual effects
particles = {}
max_particles = 32
shake_intensity = 0
shake_timer = 0
flash_color = -1
flash_timer = 0

-- leaderboard (top 5 scores)
leaderboard_scores = {}
leaderboard_levels = {}
high_score_rank = -1  -- rank if score is in top 5 (-1 if not)
lb_anim_timer = 0
menu_option = 1  -- 1=start, 2=leaderboard, 3=clear, 4=time_attack

-- time-attack mode
time_attack_mode = false
time_attack_level = 1
level_timer = 0  -- frames elapsed
time_attack_times = {}  -- best times per level [level][rank] = frames
ta_leaderboard = {}  -- leaderboard for current level display
ta_selected_level = 1
ta_menu_option = 1  -- 1=play, 2=view times

-- secret levels
secret_levels_unlocked = false

-- player
player = {
  x = 64,
  y = 100,
  w = 8,
  h = 8,
  vx = 0,
  vy = 0,
  jumping = false,
  coyote_frames = 0,
  color = 3
}

-- physics
gravity = 0.2
jump_power = 5
max_fall = 4
max_coyote = 6
move_speed = 1.5

-- platforms
platforms = {}
enemies = {}
collectibles = {}
boss = nil  -- boss enemy for level 8

-- leaderboard management functions
function load_leaderboard()
  leaderboard_scores = {}
  leaderboard_levels = {}
  for i=0,4 do
    -- decode 2-byte score
    local s_low = dget(i*2)
    local s_high = dget(i*2+1)
    local s = s_low + s_high * 256
    -- decode 2-byte level
    local l_low = dget(20 + i*2)
    local l_high = dget(20 + i*2+1)
    local l = l_low + l_high * 256
    if s > 0 then
      add(leaderboard_scores, s)
      add(leaderboard_levels, l)
    end
  end
  _log("leaderboard:loaded")
end

function save_score(sc, lvl)
  high_score_rank = -1  -- reset before checking
  -- check if score is in top 5
  for i=1,#leaderboard_scores do
    if sc > leaderboard_scores[i] then
      high_score_rank = i
      -- insert at position
      if #leaderboard_scores < 5 then
        add(leaderboard_scores, 0)
        add(leaderboard_levels, 0)
      end
      -- shift scores down
      for j=#leaderboard_scores,i+1,-1 do
        leaderboard_scores[j] = leaderboard_scores[j-1]
        leaderboard_levels[j] = leaderboard_levels[j-1]
      end
      leaderboard_scores[i] = sc
      leaderboard_levels[i] = lvl
      -- keep only top 5
      if #leaderboard_scores > 5 then
        del(leaderboard_scores, leaderboard_scores[6])
        del(leaderboard_levels, leaderboard_levels[6])
      end
      break
    end
  end

  if #leaderboard_scores < 5 and high_score_rank == -1 then
    add(leaderboard_scores, sc)
    add(leaderboard_levels, lvl)
    high_score_rank = #leaderboard_scores
  end

  -- persist to cartridge (2-byte encoding)
  for i=0,4 do
    if i < #leaderboard_scores then
      local sc_val = leaderboard_scores[i+1]
      local lv_val = leaderboard_levels[i+1]
      -- encode score as 2 bytes
      dset(i*2, sc_val % 256)        -- low byte
      dset(i*2+1, flr(sc_val / 256)) -- high byte
      -- encode level as 2 bytes
      dset(20 + i*2, lv_val % 256)        -- low byte
      dset(20 + i*2+1, flr(lv_val / 256)) -- high byte
    else
      dset(i*2, 0)
      dset(i*2+1, 0)
      dset(20 + i*2, 0)
      dset(20 + i*2+1, 0)
    end
  end
  _log("score:saved:"..sc)
end

function clear_leaderboard()
  leaderboard_scores = {}
  leaderboard_levels = {}
  high_score_rank = -1
  -- clear all cartridge slots (0-9 for scores, 20-29 for levels)
  for i=0,9 do
    dset(i, 0)
  end
  for i=20,29 do
    dset(i, 0)
  end
  _log("leaderboard:cleared")
end

-- time-attack persistence (cartridge slots 30-77: 3 times per level * 8 levels)
function load_time_attack_times()
  time_attack_times = {}
  for lvl=1,10 do
    time_attack_times[lvl] = {}
    for rank=1,3 do
      local slot = 30 + (lvl-1)*6 + (rank-1)*2
      local lo = dget(slot)
      local hi = dget(slot+1)
      local time_val = lo + hi * 256
      if time_val > 0 then
        add(time_attack_times[lvl], time_val)
      end
    end
  end
  -- load secret unlock flag (slot 102)
  secret_levels_unlocked = (dget(102) > 0)
  _log("time_attack:loaded")
end

function save_time_attack(lvl, time_frames)
  -- insert into top 3 for this level
  if not time_attack_times[lvl] then
    time_attack_times[lvl] = {}
  end
  local times = time_attack_times[lvl]

  -- find insertion position
  local insert_pos = #times + 1
  for i=1,#times do
    if time_frames < times[i] then
      insert_pos = i
      break
    end
  end

  if insert_pos <= 3 then
    -- insert at position
    if #times < 3 then
      add(times, 0)
    end
    -- shift times down
    for i=#times,insert_pos+1,-1 do
      times[i] = times[i-1]
    end
    times[insert_pos] = time_frames
    -- keep only top 3
    if #times > 3 then
      del(times, times[4])
    end
  end

  -- persist to cartridge
  for rank=1,3 do
    if rank <= #times then
      local slot = 30 + (lvl-1)*6 + (rank-1)*2
      local t = times[rank]
      dset(slot, t % 256)
      dset(slot+1, flr(t / 256))
    else
      local slot = 30 + (lvl-1)*6 + (rank-1)*2
      dset(slot, 0)
      dset(slot+1, 0)
    end
  end
  _log("time_attack:saved:"..lvl..":"..time_frames)
end

function create_level(lvl)
  platforms = {}
  enemies = {}
  collectibles = {}
  boss = nil

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

  -- level 5: narrow chains, fast vertical enemies
  elseif lvl == 5 then
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=10, y=110, w=16, h=8, moving=false})
    add(platforms, {x=42, y=100, w=18, h=8, moving=false})
    add(platforms, {x=78, y=90, w=16, h=8, moving=true, vy=-0.7, ymin=80, ymax=98})
    add(platforms, {x=15, y=78, w=18, h=8, moving=false})
    add(platforms, {x=55, y=66, w=16, h=8, moving=false})
    add(platforms, {x=88, y=54, w=20, h=8, moving=true, vx=-1.0, xmin=75, xmax=95})
    add(platforms, {x=25, y=42, w=16, h=8, moving=false})
    add(platforms, {x=68, y=30, w=18, h=8, moving=false})
    add(platforms, {x=12, y=18, w=20, h=8, moving=true, vy=-0.7, ymin=8, ymax=25})

    -- 6 enemies: fast + multiple vertical (reduced from 7 for balance)
    add(enemies, {x=50, y=95, w=8, h=8, vx=2.8, xmin=40, xmax=65, type="patrol", color=8})
    add(enemies, {x=85, y=85, w=8, h=8, vy=-0.9, ymin=75, ymax=95, type="vertical", color=7})
    add(enemies, {x=25, y=73, w=8, h=8, vx=2.2, xmin=15, xmax=40, type="jumping", jump_freq=38, ground_y=73, color=10})
    add(enemies, {x=70, y=61, w=8, h=8, vy=0.9, ymin=52, ymax=70, type="vertical", color=7})
    add(enemies, {x=35, y=50, w=8, h=8, vx=-2.8, xmin=20, xmax=50, type="patrol", color=8})
    add(enemies, {x=80, y=37, w=8, h=8, vy=-1.0, ymin=27, ymax=45, type="vertical", color=7})

    -- many collectibles on narrow platforms
    add(collectibles, {x=28, y=102, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=60, y=92, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=92, y=82, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=32, y=70, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=70, y=58, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=40, y=44, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=75, y=32, w=8, h=8, collected=false, color=11})

  -- level 6: tight navigation, synchronized moving platforms
  elseif lvl == 6 then
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=8, y=108, w=16, h=8, moving=true, vx=0.9, xmin=5, xmax=25})
    add(platforms, {x=48, y=96, w=16, h=8, moving=false})
    add(platforms, {x=80, y=84, w=16, h=8, moving=true, vx=-0.9, xmin=65, xmax=90})
    add(platforms, {x=20, y=72, w=16, h=8, moving=false})
    add(platforms, {x=65, y=60, w=16, h=8, moving=true, vy=-0.8, ymin=50, ymax=68})
    add(platforms, {x=35, y=48, w=16, h=8, moving=false})
    add(platforms, {x=75, y=36, w=16, h=8, moving=true, vx=1.0, xmin=60, xmax=85})
    add(platforms, {x=15, y=24, w=16, h=8, moving=false})
    add(platforms, {x=55, y=12, w=18, h=8, moving=true, vy=-0.9, ymin=2, ymax=20})

    -- 7 very fast enemies mixed types (reduced from 8 for balance)
    add(enemies, {x=45, y=91, w=8, h=8, vx=3.0, xmin=35, xmax=60, type="patrol", color=8})
    add(enemies, {x=85, y=79, w=8, h=8, vx=-3.0, xmin=70, xmax=95, type="patrol", color=8})
    add(enemies, {x=25, y=67, w=8, h=8, vx=2.5, xmin=15, xmax=40, type="jumping", jump_freq=36, ground_y=67, color=10})
    add(enemies, {x=70, y=55, w=8, h=8, vy=-1.1, ymin=45, ymax=65, type="vertical", color=7})
    add(enemies, {x=40, y=43, w=8, h=8, vx=-2.8, xmin=25, xmax=55, type="patrol", color=8})
    add(enemies, {x=80, y=31, w=8, h=8, vy=1.1, ymin=21, ymax=40, type="vertical", color=7})
    add(enemies, {x=30, y=37, w=8, h=8, vx=2.8, xmin=20, xmax=45, type="jumping", jump_freq=35, ground_y=37, color=10})

    -- fewer collectibles on tight platforms
    add(collectibles, {x=24, y=100, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=58, y=88, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=88, y=76, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=38, y=64, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=78, y=52, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=45, y=40, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=25, y=28, w=8, h=8, collected=false, color=11})

  -- level 7: precision platforming, dense enemies
  elseif lvl == 7 then
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=5, y=110, w=18, h=8, moving=false})
    add(platforms, {x=50, y=100, w=18, h=8, moving=true, vy=0.6, ymin=92, ymax=106})
    add(platforms, {x=85, y=90, w=16, h=8, moving=false})
    add(platforms, {x=20, y=78, w=18, h=8, moving=false})
    add(platforms, {x=60, y=66, w=16, h=8, moving=true, vx=-1.0, xmin=45, xmax=68})
    add(platforms, {x=35, y=54, w=18, h=8, moving=false})
    add(platforms, {x=75, y=42, w=18, h=8, moving=true, vx=1.0, xmin=62, xmax=85})
    add(platforms, {x=12, y=30, w=16, h=8, moving=false})
    add(platforms, {x=55, y=18, w=18, h=8, moving=false})
    add(platforms, {x=28, y=6, w=16, h=8, moving=false})

    -- 8 enemies: high density, all fast (reduced from 9 for balance)
    add(enemies, {x=48, y=95, w=8, h=8, vx=3.2, xmin=38, xmax=62, type="patrol", color=8})
    add(enemies, {x=88, y=85, w=8, h=8, vx=-3.2, xmin=72, xmax=100, type="patrol", color=8})
    add(enemies, {x=25, y=73, w=8, h=8, vx=2.8, xmin=15, xmax=40, type="jumping", jump_freq=33, ground_y=73, color=10})
    add(enemies, {x=68, y=61, w=8, h=8, vy=-1.2, ymin=51, ymax=70, type="vertical", color=7})
    add(enemies, {x=40, y=49, w=8, h=8, vx=-3.0, xmin=25, xmax=55, type="patrol", color=8})
    add(enemies, {x=80, y=37, w=8, h=8, vy=1.2, ymin=27, ymax=47, type="vertical", color=7})
    add(enemies, {x=32, y=47, w=8, h=8, vx=2.8, xmin=22, xmax=48, type="jumping", jump_freq=34, ground_y=47, color=10})
    add(enemies, {x=62, y=25, w=8, h=8, vx=-2.8, xmin=47, xmax=77, type="patrol", color=8})

    -- limited collectibles for high challenge
    add(collectibles, {x=28, y=102, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=62, y=92, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=92, y=82, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=40, y=70, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=75, y=58, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=50, y=44, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=30, y=22, w=8, h=8, collected=false, color=11})

  -- level 8: ultimate challenge - boss encounter!
  elseif lvl == 8 then
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=8, y=108, w=14, h=8, moving=true, vx=1.2, xmin=4, xmax=24})
    add(platforms, {x=45, y=98, w=12, h=8, moving=false})
    add(platforms, {x=82, y=86, w=14, h=8, moving=true, vx=-1.2, xmin=67, xmax=88})
    add(platforms, {x=22, y=74, w=12, h=8, moving=false})
    add(platforms, {x=62, y=62, w=12, h=8, moving=true, vy=-1.0, ymin=52, ymax=70})
    add(platforms, {x=38, y=50, w=12, h=8, moving=false})
    add(platforms, {x=75, y=38, w=12, h=8, moving=true, vx=1.3, xmin=60, xmax=85})
    add(platforms, {x=18, y=26, w=12, h=8, moving=false})
    add(platforms, {x=55, y=14, w=14, h=8, moving=true, vy=-1.1, ymin=4, ymax=22})
    add(platforms, {x=32, y=6, w=10, h=8, moving=false})

    -- 9 regular enemies + 1 boss
    add(enemies, {x=50, y=93, w=8, h=8, vx=3.8, xmin=40, xmax=65, type="patrol", color=8})
    add(enemies, {x=85, y=81, w=8, h=8, vx=-3.8, xmin=70, xmax=100, type="patrol", color=8})
    add(enemies, {x=28, y=69, w=8, h=8, vx=3.2, xmin=18, xmax=42, type="jumping", jump_freq=28, ground_y=69, color=10})
    add(enemies, {x=70, y=57, w=8, h=8, vy=-1.5, ymin=47, ymax=67, type="vertical", color=7})
    add(enemies, {x=42, y=45, w=8, h=8, vx=-3.5, xmin=27, xmax=57, type="patrol", color=8})
    add(enemies, {x=82, y=33, w=8, h=8, vy=1.5, ymin=23, ymax=43, type="vertical", color=7})
    add(enemies, {x=35, y=57, w=8, h=8, vx=3.2, xmin=25, xmax=50, type="jumping", jump_freq=26, ground_y=57, color=10})
    add(enemies, {x=62, y=21, w=8, h=8, vx=-3.5, xmin=47, xmax=77, type="patrol", color=8})
    add(enemies, {x=48, y=73, w=8, h=8, vx=3.0, xmin=38, xmax=63, type="patrol", color=8})

    -- spawn boss enemy (replaces one of the 10)
    boss = {
      x=60, y=40, w=8, h=8,
      health=3, max_health=3,
      phase=1, phase_timer=0,
      wave_time=0,
      bounce_vy=0,
      color=9,
      type="boss"
    }
    _log("boss:spawned")

    -- very few collectibles - high risk/reward
    add(collectibles, {x=26, y=100, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=60, y=90, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=88, y=78, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=45, y=66, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=75, y=54, w=8, h=8, collected=false, color=11})
    add(collectibles, {x=28, y=32, w=8, h=8, collected=false, color=11})

  -- secret level 1: fast bonus
  elseif lvl == 9 then
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=10, y=95, w=35, h=8, moving=false})
    add(platforms, {x=70, y=70, w=35, h=8, moving=false})
    add(platforms, {x=15, y=45, w=35, h=8, moving=false})
    add(platforms, {x=65, y=20, w=40, h=8, moving=false})
    add(enemies, {x=45, y=90, w=8, h=8, vx=3.0, xmin=35, xmax=65, type="patrol", color=8})
    add(enemies, {x=80, y=65, w=8, h=8, vx=-3.0, xmin=65, xmax=95, type="patrol", color=8})
    add(collectibles, {x=32, y=87, w=8, h=8, collected=false, color=11})

  -- secret level 2: vertical bonus
  elseif lvl == 10 then
    add(platforms, {x=0, y=120, w=128, h=8, moving=false})
    add(platforms, {x=20, y=100, w=80, h=8, moving=false})
    add(platforms, {x=30, y=75, w=70, h=8, moving=false})
    add(platforms, {x=15, y=50, w=90, h=8, moving=false})
    add(platforms, {x=35, y=25, w=60, h=8, moving=false})
    add(enemies, {x=64, y=95, w=8, h=8, vy=-1.5, ymin=85, ymax=105, type="vertical", color=7})
    add(enemies, {x=64, y=70, w=8, h=8, vy=1.5, ymin=60, ymax=80, type="vertical", color=7})
    add(collectibles, {x=64, y=92, w=8, h=8, collected=false, color=11})
  end
end

function init_game(mode)
  time_attack_mode = (mode == "time_attack")
  if time_attack_mode then
    level = ta_selected_level
    lives = 1  -- time-attack: single life (no retry penalty)
  else
    level = 1
    lives = 3
  end
  score = 0
  game_won = false
  level_timer = 0
  start_level(level)
end

function start_level(lvl)
  player.x = 64
  player.y = 100
  player.vx = 0
  player.vy = 0
  player.jumping = false
  player.coyote_frames = 0
  create_level(lvl)
  _log("level:"..lvl)
  level_intro_timer = 120  -- 2 seconds at 60fps
  state = "level_intro"

  -- play level-specific music
  local music_pat = 1  -- default to level 1 music
  if lvl == 1 then
    music_pat = 1
  elseif lvl == 2 or lvl == 3 then
    music_pat = 2
  elseif lvl == 4 or lvl == 5 then
    music_pat = 3
  elseif lvl >= 6 then
    music_pat = 3  -- use same intense music for final/secret levels
  end

  music(music_pat)
  music_playing = music_pat
  _log("music:level"..lvl)

  -- play level intro sound
  sfx(5)
end

function update_menu()
  if #leaderboard_scores == 0 then load_leaderboard() load_time_attack_times() end
  if music_playing ~= 0 then music(0) music_playing = 0 _log("music:menu") end
  if btnp(2) then menu_option = max(1, menu_option-1) end
  if btnp(3) then menu_option = min(4, menu_option+1) end

  -- menu selection
  if btnp(4) or btnp(5) then
    if menu_option == 1 then
      _log("action:start_game")
      init_game("normal")
    elseif menu_option == 2 then
      _log("action:view_leaderboard")
      state = "leaderboard"
    elseif menu_option == 3 then
      _log("action:clear_leaderboard")
      clear_leaderboard()
      menu_option = 1
    elseif menu_option == 4 then
      _log("action:time_attack")
      state = "ta_select"
      ta_selected_level = 1
    end
  end
end

function update_leaderboard()
  if btnp(4) or btnp(5) then
    _log("state:menu")
    menu_option = 1
    state = "menu"
  end
end

function update_ta_select()
  -- level selection for time-attack
  local max_lvl = 8
  if secret_levels_unlocked then max_lvl = 10 end
  if btnp(2) then  -- up
    ta_selected_level = max(1, ta_selected_level - 1)
  end
  if btnp(3) then  -- down
    ta_selected_level = min(max_lvl, ta_selected_level + 1)
  end

  -- select or cancel
  if btnp(4) then
    _log("ta:selected_level:"..ta_selected_level)
    init_game("time_attack")
  elseif btnp(5) then
    -- x button: view times for this level
    _log("ta:view_times:"..ta_selected_level)
    state = "ta_leaderboard"
  end
end

function update_ta_leaderboard()
  local m=8+(secret_levels_unlocked and 2 or 0)
  if btnp(2) then ta_selected_level = max(1, ta_selected_level-1)
  elseif btnp(3) then ta_selected_level = min(m, ta_selected_level+1)
  elseif btnp(4) or btnp(5) then _log("state:ta_select") state = "ta_select" end
end

function update_level_intro()
  level_intro_timer -= 1
  if level_intro_timer <= 0 then _log("state:play") state = "play" end
end

function update_play()
  if time_attack_mode then level_timer += 1 end
  update_particles() update_shake() update_flash()

  -- update combo window
  if combo_window > 0 then combo_window -= 1 else combo_count = 0 end
  -- update coyote window
  if not player.jumping and player.coyote_frames > 0 then player.coyote_frames -= 1 end
  if test_input(0) then player.vx = -move_speed
  elseif test_input(1) then player.vx = move_speed
  else player.vx = 0 end
  if test_input(4) and (not player.jumping or player.coyote_frames > 0) then
    player.vy = -jump_power
    player.jumping = true
    player.coyote_frames = 0
    if combo_count > 1 then sfx(0, -1, 1) else sfx(0) end
    _log("action:jump")
  end

  player.vy = min(player.vy+gravity, max_fall)
  player.x += player.vx player.y += player.vy
  if player.x < 0 then player.x = 0 elseif player.x+player.w > 128 then player.x = 128-player.w end

  for plat in all(platforms) do
    if plat.moving then
      if plat.vy then
        plat.y += plat.vy
        if plat.y < plat.ymin or plat.y > plat.ymax then plat.vy *= -1 end
      elseif plat.vx then
        plat.x += plat.vx
        if plat.x < plat.xmin or plat.x > plat.xmax then plat.vx *= -1 end
      end
    end
  end

  local w=player.jumping
  for plat in all(platforms) do
    if collide_rect(player.x, player.y+player.h, player.w, 1,
                    plat.x, plat.y, plat.w, plat.h) and player.vy >= 0 then
      player.y = plat.y - player.h
      player.vy = 0
      player.jumping = false
      player.coyote_frames = max_coyote
      if w then sfx(4) apply_shake(1, 4) _log("action:land") end
      if plat.moving then
        if plat.vy then player.y += plat.vy end
        if plat.vx then player.x += plat.vx end
      end
    end
  end

  for enemy in all(enemies) do
    if collide_rect(player.x, player.y, player.w, player.h,
                    enemy.x, enemy.y, enemy.w, enemy.h) then
      lives -= 1 combo_count = 0 combo_window = 0
      _log("action:hit_enemy")
      sfx(2) sfx(6) apply_shake(2, 6) spawn_particles(player.x+4, player.y+4, 8, 8, 1.5) set_flash(8, 3)
      if lives <= 0 then _log("gameover:lose") state = "gameover"
      else player.x = 64 player.y = 100 player.vy = 0 player.coyote_frames = max_coyote end
    end
  end

  if boss and collide_rect(player.x, player.y, player.w, player.h,
                           boss.x, boss.y, boss.w, boss.h) then
    boss.health -= 1 _log("action:hit_boss:"..boss.health)
    sfx(2) sfx(6) apply_shake(3, 8) spawn_particles(boss.x+4, boss.y+4, 10, 9, 1.8) set_flash(9, 4)
    player.x -= 3 player.vy = -4
    if boss.health <= 0 then
      local m=min(combo_count+1, 5)
      score += 50*m combo_count = m combo_window = 300
      _log("action:boss_defeated:combo:"..m.."x")
      boss = nil sfx(3) sfx(9) sfx(0) apply_shake(2, 12) set_flash(11, 25) spawn_particles(64, 50, 20, 9, 2.5)
    end
  end

  for coll in all(collectibles) do
    if not coll.collected and collide_rect(player.x, player.y, player.w, player.h,
                    coll.x, coll.y, coll.w, coll.h) then
      coll.collected = true score += 10
      sfx(1) sfx(7) spawn_particles(coll.x+4, coll.y+4, 12, 11, 1.5) set_flash(11, 3)
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

  if boss then
    boss.wave_time += 1
    if boss.health <= boss.max_health * 0.5 then
      boss.phase = 2
      boss.x += cos(boss.wave_time/25)*2.2 boss.y += sin(boss.wave_time/20)*1.5
      boss.x = max(20, min(boss.x, 100)) boss.y = max(20, min(boss.y, 80))
    else
      boss.phase = 1
      boss.x = 40 + sin(boss.wave_time/40)*25 boss.y = 45 + cos(boss.wave_time/50)*10
    end
  end

  if player.y < 5 or (level == 8 and not boss) then
    sfx(3) sfx(9) apply_shake(1, 8) set_flash(11, 20) spawn_particles(64, 32, 12, 11, 2)
    if time_attack_mode then save_time_attack(level, level_timer) end
    if level >= max_levels then
      game_won = true secret_levels_unlocked = true dset(102, 1)
      sfx(8) music(-1) music_playing = -1 _log("gameover:win") state = "gameover"
    else
      if not time_attack_mode then
        level += 1
        _log("action:level_complete")
        start_level(level)
      else
        _log("ta:level_complete:"..level_timer)
        state = "gameover"
      end
    end
  end

  -- score milestones
  if score >= 5000 and not milestone_5000 then
    milestone_5000 = true
    sfx(3)
    sfx(9)
    apply_shake(1, 6)
    set_flash(11, 12)
    spawn_particles(64, 64, 15, 11, 1.2)
    _log("milestone:5000")
  end

  if score >= 1000 and not milestone_1000 then
    milestone_1000 = true
    sfx(3)
    apply_shake(1, 4)
    set_flash(10, 8)
    spawn_particles(64, 64, 10, 10, 1)
    _log("milestone:1000")
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
  if lb_anim_timer == 0 then
    lb_anim_timer = 60
    if not time_attack_mode then save_score(score, level) end
  end
  lb_anim_timer -= 1
  if btnp(4) or btnp(5) then
    _log("state:menu") music(0) music_playing = 0
    state = (time_attack_mode and "ta_select" or "menu")
    if not time_attack_mode then menu_option = 1 end
    high_score_rank = -1 lb_anim_timer = 0
  end
end

function _update()
  if state == "menu" then update_menu()
  elseif state == "leaderboard" then update_leaderboard()
  elseif state == "ta_select" then update_ta_select()
  elseif state == "ta_leaderboard" then update_ta_leaderboard()
  elseif state == "level_intro" then update_level_intro()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function collide_rect(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 < x2 + w2 and x1 + w1 > x2 and
         y1 < y2 + h2 and y1 + h1 > y2
end

-- particle system
function spawn_particles(x, y, count, color, speed)
  if #particles >= max_particles then return end
  for i=1,count do
    if #particles < max_particles then
      local angle = rnd(1)
      local vel = speed * (0.5 + rnd(0.5))
      add(particles, {
        x = x + rnd(4) - 2,
        y = y + rnd(4) - 2,
        vx = cos(angle) * vel,
        vy = sin(angle) * vel,
        life = 30,
        max_life = 30,
        color = color
      })
    end
  end
end

function update_particles()
  for p in all(particles) do
    p.x += p.vx
    p.y += p.vy
    p.vy += 0.15  -- gravity
    p.life -= 1
    if p.life <= 0 then
      del(particles, p)
    end
  end
end

function draw_particles()
  for p in all(particles) do
    local brightness = flr(p.life / p.max_life * 3)
    if brightness > 0 then
      pset(flr(p.x), flr(p.y), p.color)
    end
  end
end

-- screen shake
function apply_shake(intensity, duration)
  shake_intensity = max(shake_intensity, intensity)
  shake_timer = max(shake_timer, duration)
end

function update_shake()
  if shake_timer > 0 then
    shake_timer -= 1
  else
    shake_intensity = 0
  end
end

function set_flash(color, duration)
  flash_color = color
  flash_timer = duration
end

function update_flash()
  if flash_timer > 0 then
    flash_timer -= 1
  else
    flash_color = -1
  end
end

function get_camera_offset()
  if shake_intensity > 0 then
    return rnd(shake_intensity * 2) - shake_intensity,
           rnd(shake_intensity * 2) - shake_intensity
  end
  return 0, 0
end

function draw_menu()
  cls(1)
  print("platformer", 50, 40, 7)
  print("8 challenging levels!", 30, 50, 3)
  local o={40,38,38,40}
  local t={"start game","leaderboard","clear scores","time attack"}
  for i=1,4 do
    local c=(menu_option==i and 11 or 3)
    print(t[i], o[i], 55+i*10, c)
  end
  print("up/down to select, z to pick", 10, 110, 6)
end

function draw_play()
  cls(1)

  -- apply camera shake
  local shake_x, shake_y = get_camera_offset()
  camera(shake_x, shake_y)

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

  -- draw boss
  if boss then
    -- draw boss with visual effect (brighter/distinct)
    -- use sprite 1 but with distinct color
    local boss_col = boss.color
    if boss.phase == 2 then
      -- flash in phase 2 to show aggression
      if flr(boss.wave_time / 3) % 2 == 0 then
        boss_col = 15  -- white flash effect
      end
    end
    -- draw boss as 8x8 enemy sprite with color indication
    pset(boss.x, boss.y, boss_col)
    pset(boss.x + 7, boss.y, boss_col)
    pset(boss.x, boss.y + 7, boss_col)
    pset(boss.x + 7, boss.y + 7, boss_col)
    spr(1, boss.x, boss.y)
  end

  -- draw player
  spr(0, player.x, player.y)

  -- draw particles
  draw_particles()

  -- reset camera
  camera(0, 0)

  -- draw flash overlay
  if flash_timer > 0 then
    rectfill(0, 0, 127, 127, flash_color)
  end

  if time_attack_mode then
    print(fmt(level_timer), 5, 5, 7)
  else
    print("score: "..score, 5, 5, 7)
  end
  print("lives: "..lives, 5, 12, 7) print("lvl "..level, 110, 5, 7)
  if combo_count > 1 then
    local c=(combo_count >= 3 and (flr(time()*4)%2==0 and 11 or 10) or 10)
    print("combo: "..combo_count.."x", 55, 12, c)
  end
end

function draw_level_intro()
  cls(1)
  print("level "..level, 45, 50, 3)
  local m={"master the basics!","things get tighter!","stay sharp!","final challenge!","narrow escapes!","precision mode!","swarm of enemies!","ultimate test!"}
  local x={30,30,45,35,35,35,30,38}
  print(m[level], x[level], 70, 7)
end

function draw_gameover()
  cls(1)
  if time_attack_mode then
    print("time attack complete!", 25, 40, 11) print("level "..level, 50, 55, 3) print("time: "..fmt(level_timer), 40, 70, 7)
  elseif game_won then
    print("you win!", 50, 40, 11) print("all 8 levels complete!", 25, 55, 3)
  else
    print("game over", 45, 40, 8) print("reached level "..level, 35, 55, 7)
  end
  if not time_attack_mode then
    local c=7
    if high_score_rank > 0 and lb_anim_timer > 0 and flr(lb_anim_timer/8)%2==0 then c=11 end
    print("score: "..score, 50, 70, c)
    if high_score_rank > 0 then print("#"..high_score_rank.." high score!", 30, 80, 11) end
  end
  print("press z to menu", 35, 95, 6)
end

function fmt(f)
  local s=flr(f/60)
  local m=flr(s/60)
  s=s%60
  return m..":"..((s<10 and "0" or "")..s)
end

function draw_leaderboard()
  cls(1)
  print("leaderboard", 45, 10, 7)
  print("top 5 scores", 40, 20, 3)

  if #leaderboard_scores == 0 then
    print("no scores yet!", 35, 50, 8)
  else
    for i=1,#leaderboard_scores do
      local y = 35 + (i-1) * 10
      print("#"..i, 20, y, 3)
      print(leaderboard_scores[i], 45, y, 7)
      print("l"..leaderboard_levels[i], 70, y, 6)
    end
  end

  print("press z to menu", 35, 110, 6)
end

function draw_ta_select()
  cls(1)
  print("time attack", 45, 20, 7)
  print("select level:", 35, 35, 3)
  local m=8+(secret_levels_unlocked and 2 or 0)
  for i=1,m do
    local c=(i==ta_selected_level and 11 or 3)
    local l=(i<9 and "l"..i or (i==9 and "s1" or "s2"))
    print(l, 40+((i-1)%4)*20, 50+flr((i-1)/4)*15, c)
  end
  print("z: play, x: times", 25, 110, 6)
end

function draw_ta_leaderboard()
  cls(1)
  print("best times - level "..ta_selected_level, 20, 10, 7)

  if not time_attack_times[ta_selected_level] or
     #time_attack_times[ta_selected_level] == 0 then
    print("no times yet!", 50, 50, 8)
  else
    local times = time_attack_times[ta_selected_level]
    for i=1,#times do
      local y = 35 + (i-1) * 15
      print("#"..i, 20, y, 3)
      print(fmt(times[i]), 50, y, 7)
    end
  end

  print("press z to back", 35, 110, 6)
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "leaderboard" then draw_leaderboard()
  elseif state == "ta_select" then draw_ta_select()
  elseif state == "ta_leaderboard" then draw_ta_leaderboard()
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
010800004505350505505305a053505a0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a0000365436543654365436543654300030003000300030003000300030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01080000175017501750175017500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800004305430543054305430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00006a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a64
01040000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__music__
00 01010101
01 02030203
02 03040304
03 05060506

