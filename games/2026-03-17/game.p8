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

-- visual effects
particles = {}
max_particles = 32
shake_intensity = 0
shake_timer = 0
flash_color = -1
flash_timer = 0

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
boss = nil  -- boss enemy for level 8

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
    add(platforms, {x=78, y=90, w=16, h=8, moving=true, vy=-0.8, ymin=80, ymax=98})
    add(platforms, {x=15, y=78, w=18, h=8, moving=false})
    add(platforms, {x=55, y=66, w=16, h=8, moving=false})
    add(platforms, {x=88, y=54, w=20, h=8, moving=true, vx=-1.0, xmin=75, xmax=95})
    add(platforms, {x=25, y=42, w=16, h=8, moving=false})
    add(platforms, {x=68, y=30, w=18, h=8, moving=false})
    add(platforms, {x=12, y=18, w=20, h=8, moving=true, vy=-0.9, ymin=8, ymax=25})

    -- 7 enemies: fast + multiple vertical
    add(enemies, {x=50, y=95, w=8, h=8, vx=3.0, xmin=40, xmax=65, type="patrol", color=8})
    add(enemies, {x=85, y=85, w=8, h=8, vy=-1.0, ymin=75, ymax=95, type="vertical", color=7})
    add(enemies, {x=25, y=73, w=8, h=8, vx=2.2, xmin=15, xmax=40, type="jumping", jump_freq=38, ground_y=73, color=10})
    add(enemies, {x=70, y=61, w=8, h=8, vy=0.9, ymin=52, ymax=70, type="vertical", color=7})
    add(enemies, {x=35, y=50, w=8, h=8, vx=-2.8, xmin=20, xmax=50, type="patrol", color=8})
    add(enemies, {x=80, y=37, w=8, h=8, vy=-1.1, ymin=27, ymax=45, type="vertical", color=7})
    add(enemies, {x=55, y=25, w=8, h=8, vx=2.5, xmin=45, xmax=70, type="patrol", color=8})

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
    add(platforms, {x=8, y=108, w=14, h=8, moving=true, vx=1.0, xmin=5, xmax=25})
    add(platforms, {x=48, y=96, w=14, h=8, moving=false})
    add(platforms, {x=80, y=84, w=14, h=8, moving=true, vx=-1.0, xmin=65, xmax=90})
    add(platforms, {x=20, y=72, w=16, h=8, moving=false})
    add(platforms, {x=65, y=60, w=14, h=8, moving=true, vy=-0.9, ymin=50, ymax=68})
    add(platforms, {x=35, y=48, w=14, h=8, moving=false})
    add(platforms, {x=75, y=36, w=16, h=8, moving=true, vx=1.1, xmin=60, xmax=85})
    add(platforms, {x=15, y=24, w=14, h=8, moving=false})
    add(platforms, {x=55, y=12, w=18, h=8, moving=true, vy=-1.0, ymin=2, ymax=20})

    -- 8 very fast enemies mixed types
    add(enemies, {x=45, y=91, w=8, h=8, vx=3.2, xmin=35, xmax=60, type="patrol", color=8})
    add(enemies, {x=85, y=79, w=8, h=8, vx=-3.2, xmin=70, xmax=95, type="patrol", color=8})
    add(enemies, {x=25, y=67, w=8, h=8, vx=2.5, xmin=15, xmax=40, type="jumping", jump_freq=36, ground_y=67, color=10})
    add(enemies, {x=70, y=55, w=8, h=8, vy=-1.2, ymin=45, ymax=65, type="vertical", color=7})
    add(enemies, {x=40, y=43, w=8, h=8, vx=-3.0, xmin=25, xmax=55, type="patrol", color=8})
    add(enemies, {x=80, y=31, w=8, h=8, vy=1.2, ymin=21, ymax=40, type="vertical", color=7})
    add(enemies, {x=30, y=37, w=8, h=8, vx=2.8, xmin=20, xmax=45, type="jumping", jump_freq=33, ground_y=37, color=10})
    add(enemies, {x=60, y=19, w=8, h=8, vx=-2.8, xmin=45, xmax=75, type="patrol", color=8})

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
    add(platforms, {x=50, y=100, w=16, h=8, moving=true, vy=0.7, ymin=92, ymax=106})
    add(platforms, {x=85, y=90, w=15, h=8, moving=false})
    add(platforms, {x=20, y=78, w=16, h=8, moving=false})
    add(platforms, {x=60, y=66, w=14, h=8, moving=true, vx=-1.2, xmin=45, xmax=68})
    add(platforms, {x=35, y=54, w=18, h=8, moving=false})
    add(platforms, {x=75, y=42, w=16, h=8, moving=true, vx=1.2, xmin=62, xmax=85})
    add(platforms, {x=12, y=30, w=14, h=8, moving=false})
    add(platforms, {x=55, y=18, w=16, h=8, moving=false})
    add(platforms, {x=28, y=6, w=12, h=8, moving=false})

    -- 9 enemies: high density, all fast
    add(enemies, {x=48, y=95, w=8, h=8, vx=3.5, xmin=38, xmax=62, type="patrol", color=8})
    add(enemies, {x=88, y=85, w=8, h=8, vx=-3.5, xmin=72, xmax=100, type="patrol", color=8})
    add(enemies, {x=25, y=73, w=8, h=8, vx=3.0, xmin=15, xmax=40, type="jumping", jump_freq=32, ground_y=73, color=10})
    add(enemies, {x=68, y=61, w=8, h=8, vy=-1.3, ymin=51, ymax=70, type="vertical", color=7})
    add(enemies, {x=40, y=49, w=8, h=8, vx=-3.2, xmin=25, xmax=55, type="patrol", color=8})
    add(enemies, {x=80, y=37, w=8, h=8, vy=1.3, ymin=27, ymax=47, type="vertical", color=7})
    add(enemies, {x=32, y=47, w=8, h=8, vx=3.0, xmin=22, xmax=48, type="jumping", jump_freq=30, ground_y=47, color=10})
    add(enemies, {x=62, y=25, w=8, h=8, vx=-3.2, xmin=47, xmax=77, type="patrol", color=8})
    add(enemies, {x=50, y=65, w=8, h=8, vx=2.8, xmin=40, xmax=60, type="patrol", color=8})

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

  -- play level-specific music
  local music_pat = 1  -- default to level 1 music
  if lvl == 1 then
    music_pat = 1
  elseif lvl == 2 or lvl == 3 then
    music_pat = 2
  elseif lvl == 4 or lvl == 5 then
    music_pat = 3
  elseif lvl >= 6 then
    music_pat = 3  -- use same intense music for final levels
  end

  music(music_pat)
  music_playing = music_pat
  _log("music:level"..lvl)

  -- play level intro sound
  sfx(5)
end

function update_menu()
  -- start menu music if not playing
  if music_playing ~= 0 then
    music(0)
    music_playing = 0
    _log("music:menu")
  end

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
  -- update particles and effects
  update_particles()
  update_shake()
  update_flash()

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
  local was_jumping = player.jumping
  for plat in all(platforms) do
    if collide_rect(player.x, player.y + player.h, player.w, 1,
                    plat.x, plat.y, plat.w, plat.h) then
      if player.vy >= 0 then
        player.y = plat.y - player.h
        player.vy = 0
        player.jumping = false
        on_platform = true
        -- play landing sound + visual feedback
        if was_jumping then
          sfx(4)
          apply_shake(1, 4)  -- light shake on landing
          _log("action:land")
        end
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
      sfx(6)  -- impact sound effect
      apply_shake(2, 6)  -- medium shake on enemy hit
      spawn_particles(player.x + 4, player.y + 4, 8, 8, 1.5)
      set_flash(8, 3)  -- brief red flash
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

  -- boss collision (damage boss on hit)
  if boss and collide_rect(player.x, player.y, player.w, player.h,
                           boss.x, boss.y, boss.w, boss.h) then
    boss.health -= 1
    _log("action:hit_boss:"..boss.health)
    sfx(2)
    sfx(6)
    apply_shake(3, 8)  -- stronger shake for boss hit
    spawn_particles(boss.x + 4, boss.y + 4, 10, 9, 1.8)
    set_flash(9, 4)  -- magenta flash
    -- knock player back
    player.x -= 3
    player.vy = -4

    if boss.health <= 0 then
      _log("action:boss_defeated")
      boss = nil
      sfx(3)
      sfx(9)
      apply_shake(2, 12)  -- extended shake for victory
      set_flash(11, 25)  -- longer yellow flash
      spawn_particles(64, 50, 20, 9, 2.5)  -- boss explosion
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
      sfx(7)  -- coin sparkle sound
      spawn_particles(coll.x + 4, coll.y + 4, 6, 11, 1.2)
      set_flash(11, 2)  -- yellow flash
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

  -- update boss (multi-phase behavior)
  if boss then
    boss.wave_time += 1
    local phase_threshold = boss.max_health * 0.5

    if boss.health <= phase_threshold then
      -- phase 2: aggressive bouncing
      boss.phase = 2
      local speed = 2.2
      boss.x += cos(boss.wave_time / 25) * speed
      boss.y += sin(boss.wave_time / 20) * 1.5

      -- keep in bounds
      boss.x = max(20, min(boss.x, 100))
      boss.y = max(20, min(boss.y, 80))
    else
      -- phase 1: slow sine wave
      boss.phase = 1
      boss.x = 40 + sin(boss.wave_time / 40) * 25
      boss.y = 45 + cos(boss.wave_time / 50) * 10
    end
  end

  -- win condition: reach top OR defeat boss on level 8
  local should_complete_level = false
  if player.y < 5 then
    should_complete_level = true
  elseif level == 8 and not boss then
    -- boss defeated, level 8 is complete
    should_complete_level = true
  end

  if should_complete_level then
    sfx(3)
    sfx(9)  -- level complete chime
    apply_shake(1, 8)
    set_flash(11, 20)  -- longer flash on completion
    spawn_particles(64, 32, 12, 11, 2)
    if level >= max_levels then
      game_won = true
      sfx(8)  -- play victory fanfare
      music(-1)  -- stop music
      music_playing = -1
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
    music(0)  -- go back to menu music
    music_playing = 0
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
  print("arrow keys: move", 30, 70, 6)
  print("z/c: jump", 40, 80, 6)
  print("press z to start", 35, 100, 3)
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

  -- draw ui (always on screen)
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
  elseif level == 5 then
    print("narrow escapes!", 35, 70, 7)
  elseif level == 6 then
    print("precision mode!", 35, 70, 7)
  elseif level == 7 then
    print("swarm of enemies!", 30, 70, 7)
  elseif level == 8 then
    print("ultimate test!", 38, 70, 7)
  end
end

function draw_gameover()
  cls(1)
  if state == "gameover" then
    if game_won then
      print("you win!", 50, 40, 11)
      print("all 8 levels complete!", 25, 55, 3)
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
010800004505350505505305a053505a0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a0000365436543654365436543654300030003000300030003000300030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01080000175017501750175017500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800004305430543054305430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00006a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a64
01040000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__music__
00 00000000
01 00000000
02 00000000
03 00000000

