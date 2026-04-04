pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- penguin slide - navigate icy platforms and collect fish!

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

-- game state machine
state = "menu"
score = 0
high_score = 0  -- track high score across playthroughs
lives = 3
level = 1
camera_x = 0
difficulty = 2  -- 1=easy, 2=medium, 3=hard
difficulty_names = {"easy", "medium", "hard"}
diff_speeds = {0.8, 1.0, 1.3}  -- obstacle speed multipliers
max_levels = {3, 5, 7}  -- levels per difficulty

-- timing
level_start_time = 0  -- frame count when level starts
level_completion_time = 0  -- frames to complete current level
total_playtime = 0  -- total frames played

-- player
px, py = 10, 100
pw, ph = 4, 6
pspeed_x = 0
pspeed_y = 0
pgrounded = false
pdir = 1  -- 1 = right, -1 = left

-- visual polish
shake_amt = 0  -- screenshake amount
shake_x = 0
shake_y = 0
flash_amt = 0  -- screen flash
particles = {}  -- particle effects
portal_pulse = 0  -- exit portal pulse animation
level_complete_timer = 0  -- for level transition fade

-- platforms and obstacles
platforms = {}
fish = {}
spikes = {}
exit_portal = {}
fish_collected = 0  -- track collected fish

-- platform structure: {x, y, w, h}
function init_level(lv)
  _log("level:"..lv)
  platforms = {}
  fish = {}
  spikes = {}
  fish_collected = 0  -- reset fish counter for new level

  -- level 1: basic tutorial level
  if lv == 1 then
    -- ground
    add(platforms, {0, 120, 128, 8})
    -- stepping stones - adjust width for difficulty
    local pw1 = difficulty == 1 and 24 or (difficulty == 2 and 20 or 18)
    add(platforms, {10, 108, pw1, 4})
    add(platforms, {40, 100, pw1, 4})
    add(platforms, {70, 95, pw1, 4})
    add(platforms, {100, 100, pw1, 4})
    -- upper path
    add(platforms, {20, 80, 25, 4})
    add(platforms, {55, 70, 25, 4})
    add(platforms, {85, 75, 30, 4})

    -- fish to collect
    add(fish, {25, 75})
    add(fish, {60, 60})
    add(fish, {100, 65})
    add(fish, {35, 90})

    -- obstacles - fewer for easy, more for hard
    if difficulty <= 1 then
      add(spikes, {30, 115})
      add(spikes, {65, 108})
    else
      add(spikes, {30, 115})
      add(spikes, {65, 108})
      add(spikes, {90, 110})
      if difficulty == 3 then
        add(spikes, {45, 105})
      end
    end

    -- exit
    exit_portal = {110, 70, 10}
  elseif lv == 2 then
    -- level 2: medium difficulty
    add(platforms, {0, 120, 128, 8})
    -- adjust platform widths for difficulty
    local pw2 = difficulty == 1 and 18 or (difficulty == 2 and 15 or 13)
    add(platforms, {5, 105, pw2, 3})
    add(platforms, {28, 98, pw2, 3})
    add(platforms, {48, 90, pw2, 3})
    add(platforms, {68, 85, pw2, 3})
    add(platforms, {90, 95, pw2, 3})

    add(platforms, {15, 70, pw2, 3})
    add(platforms, {40, 65, pw2, 3})
    add(platforms, {65, 60, pw2, 3})

    add(fish, {20, 65})
    add(fish, {45, 58})
    add(fish, {70, 55})
    add(fish, {95, 90})
    add(fish, {12, 100})

    -- difficulty-based spikes
    if difficulty <= 1 then
      add(spikes, {25, 115})
      add(spikes, {50, 115})
    else
      add(spikes, {25, 115})
      add(spikes, {50, 115})
      add(spikes, {75, 115})
      add(spikes, {38, 103})
      add(spikes, {60, 95})
      if difficulty == 3 then
        add(spikes, {18, 105})
      end
    end

    exit_portal = {110, 55, 10}
  elseif lv == 3 then
    -- level 3: hard - tight platforms, many obstacles
    add(platforms, {0, 120, 128, 8})
    -- difficulty-based widths
    local pw3 = difficulty == 1 and 18 or (difficulty == 2 and 14 or 12)
    add(platforms, {3, 108, pw3, 3})
    add(platforms, {25, 103, pw3-2, 3})
    add(platforms, {45, 98, pw3-4, 3})
    add(platforms, {63, 93, pw3-2, 3})
    add(platforms, {85, 100, pw3, 3})

    add(platforms, {12, 80, pw3, 3})
    add(platforms, {38, 73, pw3-2, 3})
    add(platforms, {60, 68, pw3-3, 3})
    add(platforms, {82, 75, pw3, 3})

    add(platforms, {20, 55, pw3-2, 3})
    add(platforms, {50, 48, pw3-2, 3})
    add(platforms, {75, 58, pw3, 3})

    add(fish, {20, 75})
    add(fish, {45, 68})
    add(fish, {70, 53})
    add(fish, {100, 95})
    add(fish, {15, 50})
    add(fish, {60, 43})

    -- difficulty-based spikes
    if difficulty <= 1 then
      add(spikes, {20, 115})
      add(spikes, {40, 115})
      add(spikes, {60, 115})
    else
      add(spikes, {20, 115})
      add(spikes, {40, 115})
      add(spikes, {60, 115})
      add(spikes, {80, 115})
      add(spikes, {35, 106})
      add(spikes, {55, 101})
      add(spikes, {75, 96})
      if difficulty == 3 then
        add(spikes, {28, 85})
        add(spikes, {45, 95})
      else
        add(spikes, {28, 85})
      end
    end

    exit_portal = {110, 45, 10}
  elseif lv == 4 then
    -- level 4: very hard - cascading obstacles, complex jumps
    add(platforms, {0, 120, 128, 8})
    local pw4 = difficulty == 1 and 14 or (difficulty == 2 and 12 or 10)
    add(platforms, {2, 110, pw4, 2})
    add(platforms, {20, 105, pw4-2, 2})
    add(platforms, {38, 100, pw4-3, 2})
    add(platforms, {54, 95, pw4-1, 2})
    add(platforms, {75, 102, pw4, 2})
    add(platforms, {98, 108, pw4-2, 2})

    add(platforms, {10, 85, pw4+2, 2})
    add(platforms, {32, 78, pw4, 2})
    add(platforms, {55, 72, pw4-2, 2})
    add(platforms, {78, 80, pw4+1, 2})

    add(platforms, {18, 60, pw4-1, 2})
    add(platforms, {48, 52, pw4-2, 2})
    add(platforms, {75, 65, pw4, 2})

    add(platforms, {35, 40, pw4, 2})
    add(platforms, {70, 45, pw4-1, 2})

    add(fish, {15, 80})
    add(fish, {40, 73})
    add(fish, {60, 67})
    add(fish, {90, 103})
    add(fish, {25, 55})
    add(fish, {55, 47})
    add(fish, {80, 60})
    add(fish, {42, 35})

    -- difficulty-based spikes
    if difficulty == 1 then
      add(spikes, {18, 115})
      add(spikes, {38, 115})
      add(spikes, {58, 115})
    else
      add(spikes, {18, 115})
      add(spikes, {38, 115})
      add(spikes, {58, 115})
      add(spikes, {78, 115})
      add(spikes, {98, 115})
      add(spikes, {30, 108})
      add(spikes, {50, 103})
      add(spikes, {70, 100})
      if difficulty == 3 then
        add(spikes, {25, 90})
        add(spikes, {45, 82})
        add(spikes, {65, 77})
      end
    end

    exit_portal = {110, 35, 10}
  elseif lv == 5 then
    -- level 5: expert - intense challenge, many precise jumps
    add(platforms, {0, 120, 128, 8})
    local pw5 = difficulty == 1 and 12 or (difficulty == 2 and 10 or 9)
    add(platforms, {1, 110, pw5, 2})
    add(platforms, {18, 106, pw5-1, 2})
    add(platforms, {35, 101, pw5-2, 2})
    add(platforms, {50, 96, pw5-1, 2})
    add(platforms, {68, 102, pw5, 2})
    add(platforms, {88, 107, pw5-1, 2})
    add(platforms, {105, 110, pw5-2, 2})

    add(platforms, {8, 87, pw5+1, 2})
    add(platforms, {28, 80, pw5-1, 2})
    add(platforms, {48, 74, pw5-2, 2})
    add(platforms, {68, 82, pw5, 2})
    add(platforms, {92, 88, pw5-1, 2})

    add(platforms, {15, 65, pw5, 2})
    add(platforms, {40, 58, pw5-1, 2})
    add(platforms, {62, 70, pw5+1, 2})
    add(platforms, {85, 62, pw5-2, 2})

    add(platforms, {25, 48, pw5-2, 2})
    add(platforms, {50, 42, pw5, 2})
    add(platforms, {75, 52, pw5-1, 2})

    add(platforms, {35, 30, pw5-1, 2})
    add(platforms, {70, 38, pw5, 2})

    add(fish, {12, 82})
    add(fish, {35, 75})
    add(fish, {55, 69})
    add(fish, {75, 77})
    add(fish, {100, 102})
    add(fish, {20, 60})
    add(fish, {48, 53})
    add(fish, {70, 65})
    add(fish, {40, 43})
    add(fish, {60, 37})

    -- difficulty-based spikes
    if difficulty == 1 then
      add(spikes, {15, 115})
      add(spikes, {35, 115})
      add(spikes, {55, 115})
      add(spikes, {75, 115})
    else
      add(spikes, {15, 115})
      add(spikes, {35, 115})
      add(spikes, {55, 115})
      add(spikes, {75, 115})
      add(spikes, {95, 115})
      add(spikes, {28, 108})
      add(spikes, {48, 104})
      add(spikes, {68, 100})
      if difficulty == 3 then
        add(spikes, {88, 105})
        add(spikes, {20, 92})
        add(spikes, {42, 85})
        add(spikes, {62, 78})
        add(spikes, {85, 87})
        add(spikes, {32, 70})
        add(spikes, {55, 64})
      end
    end

    exit_portal = {110, 28, 10}
  elseif lv == 6 then
    -- level 6: hard mode only - brutal platforming
    add(platforms, {0, 120, 128, 8})
    add(platforms, {5, 105, 10, 2})
    add(platforms, {22, 100, 9, 2})
    add(platforms, {40, 95, 9, 2})
    add(platforms, {58, 90, 10, 2})
    add(platforms, {76, 98, 9, 2})
    add(platforms, {95, 103, 10, 2})

    add(platforms, {12, 80, 10, 2})
    add(platforms, {35, 73, 9, 2})
    add(platforms, {55, 68, 10, 2})
    add(platforms, {78, 76, 9, 2})

    add(platforms, {18, 55, 9, 2})
    add(platforms, {45, 48, 10, 2})
    add(platforms, {70, 60, 9, 2})

    add(fish, {18, 75})
    add(fish, {40, 68})
    add(fish, {60, 63})
    add(fish, {85, 93})
    add(fish, {28, 50})
    add(fish, {50, 43})
    add(fish, {75, 55})

    add(spikes, {12, 115})
    add(spikes, {28, 115})
    add(spikes, {44, 115})
    add(spikes, {60, 115})
    add(spikes, {76, 115})
    add(spikes, {92, 115})
    add(spikes, {20, 108})
    add(spikes, {40, 103})
    add(spikes, {60, 98})
    add(spikes, {30, 85})
    add(spikes, {50, 78})

    exit_portal = {110, 42, 10}
  elseif lv == 7 then
    -- level 7: hard mode final - extreme challenge
    add(platforms, {0, 120, 128, 8})
    add(platforms, {3, 108, 8, 2})
    add(platforms, {18, 103, 8, 2})
    add(platforms, {33, 98, 8, 2})
    add(platforms, {50, 93, 9, 2})
    add(platforms, {70, 100, 8, 2})
    add(platforms, {88, 105, 8, 2})

    add(platforms, {10, 82, 9, 2})
    add(platforms, {30, 75, 8, 2})
    add(platforms, {52, 70, 9, 2})
    add(platforms, {75, 78, 8, 2})

    add(platforms, {15, 58, 8, 2})
    add(platforms, {42, 50, 9, 2})
    add(platforms, {68, 62, 8, 2})

    add(platforms, {28, 38, 8, 2})
    add(platforms, {62, 45, 9, 2})

    add(fish, {15, 78})
    add(fish, {38, 70})
    add(fish, {58, 65})
    add(fish, {82, 95})
    add(fish, {25, 53})
    add(fish, {48, 45})
    add(fish, {70, 57})
    add(fish, {35, 33})

    add(spikes, {10, 115})
    add(spikes, {22, 115})
    add(spikes, {34, 115})
    add(spikes, {48, 115})
    add(spikes, {62, 115})
    add(spikes, {76, 115})
    add(spikes, {90, 115})
    add(spikes, {15, 108})
    add(spikes, {35, 103})
    add(spikes, {55, 98})
    add(spikes, {25, 85})
    add(spikes, {45, 77})
    add(spikes, {65, 72})

    exit_portal = {110, 32, 10}
  end

  _log("init_level:done")
  px = 5
  py = 115
  pspeed_x = 0
  pspeed_y = 0
  portal_pulse = 0
  particles = {}
  level_start_time = stat(8)  -- frame count
end

function add_particle(x, y, vx, vy, col, life)
  add(particles, {x=x, y=y, vx=vx, vy=vy, col=col, life=life})
end

function update_particles()
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x += p.vx
    p.y += p.vy
    p.life -= 1
    if p.life <= 0 then
      deli(particles, i)
    end
  end
end

function apply_screenshake()
  if shake_amt > 0 then
    shake_x = rnd(shake_amt*2) - shake_amt
    shake_y = rnd(shake_amt*2) - shake_amt
    shake_amt *= 0.85
  else
    shake_x = 0
    shake_y = 0
  end
  camera(shake_x, shake_y)
end

function draw_particles()
  for p in all(particles) do
    pset(p.x, p.y, p.col)
  end
end

function update_menu()
  if btnp(4) then  -- z button
    _log("state:difficulty_select")
    state = "difficulty_select"
    difficulty = 2  -- reset to medium
  end
end

function update_difficulty_select()
  -- left/right to select difficulty
  if btnp(0) and difficulty > 1 then
    difficulty -= 1
    sfx(0)  -- use jump sound for selection
  end
  if btnp(1) and difficulty < 3 then
    difficulty += 1
    sfx(0)
  end

  -- z to start with selected difficulty
  if btnp(4) then
    test_log = {}  -- clear previous game's logs
    _log("state:play")
    _log("difficulty:"..difficulty_names[difficulty])
    state = "play"
    score = 0
    lives = 3
    level = 1
    sfx(3, 2)  -- level start sound
    init_level(level)
  end
end

function update_play()
  -- horizontal movement with smooth acceleration
  local input_x = 0
  if test_input(0) then input_x = -1 end
  if test_input(1) then input_x = 1 end

  -- smooth acceleration/deceleration
  local target_speed = input_x * 2.5
  pspeed_x += (target_speed - pspeed_x) * 0.3
  if input_x != 0 then pdir = input_x end

  px += pspeed_x

  -- gravity
  pspeed_y += 0.3
  py += pspeed_y

  -- jumping
  if pgrounded and test_input(4) then
    pspeed_y = -3
    sfx(0)  -- jump sound
    _log("action:jump")
    -- jump particle effect
    for j = 1, 3 do
      add_particle(px + rnd(4)-2, py + 4 + rnd(2), rnd(2)-1, 1 + rnd(1), 13, 12)
    end
    pgrounded = false
  end

  -- collision with platforms
  pgrounded = false
  for plat in all(platforms) do
    local px0 = plat[1]
    local py0 = plat[2]
    local pw = plat[3]
    local ph = plat[4]

    if px + pw > px0 and px < px0 + pw and
       py + ph > py0 and py < py0 + ph then
      if pspeed_y > 0 then  -- landing
        py = py0 - ph
        -- screenshake based on fall velocity
        shake_amt = max(0.5, abs(pspeed_y) * 0.2)
        pspeed_y = 0
        pgrounded = true
      end
    end
  end

  -- collect fish
  for i, f in ipairs(fish) do
    if abs(px - f[1]) < 8 and abs(py - f[2]) < 8 then
      sfx(1)  -- fish collected sound
      _log("action:fish_collected")
      score += 10
      fish_collected += 1
      -- particle effects for collection
      for j = 1, 6 do
        local ang = j / 6
        add_particle(f[1], f[2], cos(ang)*1.5, sin(ang)*1.5, 12, 20)
      end
      f[1] = -100  -- move off screen
    end
  end

  -- collision with spikes
  for spike in all(spikes) do
    if abs(px - spike[1]) < 6 and abs(py - spike[2]) < 6 then
      sfx(2)  -- spike hit sound
      _log("action:hit_spike")
      lives -= 1
      -- visual feedback for spike hit
      flash_amt = 12
      shake_amt = 2.5
      -- spike hit particles - more aggressive burst
      for j = 1, 8 do
        local ang = j / 8
        add_particle(px, py, cos(ang)*2, sin(ang)*2, 8, 20)
      end
      px = 5
      py = 115
      pspeed_y = 0
      if lives <= 0 then
        sfx(5)  -- lose sound
        _log("state:gameover")
        _log("result:lose")
        -- track playtime and update high score on loss
        total_playtime = stat(8)
        if score > high_score then
          high_score = score
        end
        state = "gameover"
      end
    end
  end

  -- update exit portal pulse
  portal_pulse += 0.05

  -- check exit
  if exit_portal and
     abs(px - exit_portal[1]) < 8 and
     abs(py - exit_portal[2]) < 8 then
    local max_lv = max_levels[difficulty]
    if level < max_lv then
      sfx(3)  -- level complete sound
      _log("action:level_up")
      -- level complete visual feedback
      flash_amt = 15
      for j = 1, 8 do
        local ang = j / 8
        add_particle(exit_portal[1], exit_portal[2], cos(ang)*2, sin(ang)*2, 11, 25)
      end
      level += 1
      score += 50
      level_complete_timer = 15
      init_level(level)
    else
      sfx(4)  -- win sound
      _log("state:gameover")
      _log("result:win")
      -- win flash
      flash_amt = 20
      -- track total playtime and update high score
      total_playtime = stat(8)
      if score > high_score then
        high_score = score
        _log("high_score:"..high_score)
      end
      state = "gameover"
    end
  end

  -- bounds check
  if py > 128 then
    sfx(2)  -- spike hit sound (reuse for fall)
    _log("action:fell_off")
    lives -= 1
    -- fall effects
    flash_amt = 8
    shake_amt = 1.5
    px = 5
    py = 115
    pspeed_y = 0
    if lives <= 0 then
      sfx(5)  -- lose sound
      _log("state:gameover")
      _log("result:lose")
      -- track playtime and update high score on loss
      total_playtime = stat(8)
      if score > high_score then
        high_score = score
      end
      state = "gameover"
    end
  end

  if px < -10 or px > 138 then
    px = mid(-10, px, 138)
  end
end

function update_gameover()
  if btnp(4) then
    _log("state:menu")
    state = "menu"
  end
end

function _update()
  if state == "menu" then update_menu()
  elseif state == "difficulty_select" then update_difficulty_select()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
  -- universal updates
  update_particles()
  if flash_amt > 0 then flash_amt -= 1 end
  if level_complete_timer > 0 then level_complete_timer -= 1 end
end

function draw_menu()
  camera(0, 0)
  cls(1)
  print("penguin slide", 32, 20, 7)
  print("navigate icy platforms", 18, 35, 6)
  print("collect fish to score", 20, 45, 6)
  print("reach the goal!", 32, 55, 6)

  print("controls:", 40, 75, 7)
  print("left/right: move", 26, 85, 6)
  print("z: jump", 42, 95, 6)

  if flr(t() * 2) % 2 == 0 then
    print("press z to start", 24, 110, 7)
  end

  -- draw penguin sprite on menu
  spr(1, 55, 30)
end

function draw_difficulty_select()
  camera(0, 0)
  cls(1)
  print("select difficulty", 28, 20, 7)

  -- draw difficulty options
  local y_base = 50
  for i = 1, 3 do
    local col = 7
    local mark = "  "
    if i == difficulty then
      col = 11
      mark = "▶ "
    end
    print(mark..difficulty_names[i], 35, y_base + i*20, col)
  end

  -- show difficulty description
  local desc = ""
  if difficulty == 1 then
    desc = "3 levels - relaxed"
  elseif difficulty == 2 then
    desc = "5 levels - balanced"
  else
    desc = "7 levels - expert!"
  end
  print(desc, 22, 105, 6)

  if flr(t() * 2) % 2 == 0 then
    print("z to start", 42, 118, 7)
  end
  camera(0, 0)
end

function draw_play()
  apply_screenshake()
  cls(1)

  -- draw level label
  print("level "..level, 2, 2, 7)
  print("score: "..score, 65, 2, 7)
  print("lives: "..lives, 95, 2, 7)

  -- difficulty label
  local diff_col = 6
  if difficulty == 1 then diff_col = 3 end
  if difficulty == 3 then diff_col = 8 end
  print("["..difficulty_names[difficulty].."]", 2, 12, diff_col)

  -- fish counter and high score on HUD
  local total_fish = #fish
  print("fish:"..fish_collected.."/"..total_fish, 45, 12, 12)
  print("hi:"..high_score, 95, 12, 11)

  -- draw platforms
  for plat in all(platforms) do
    rectfill(plat[1], plat[2], plat[1]+plat[3]-1, plat[2]+plat[4]-1, 3)
  end

  -- draw fish
  for f in all(fish) do
    spr(2, f[1]-2, f[2]-2)
  end

  -- draw spikes
  for spike in all(spikes) do
    spr(3, spike[1]-2, spike[2]-2)
  end

  -- draw exit with pulse effect
  if exit_portal then
    local pulse = sin(portal_pulse) * 0.5 + 0.5
    local pulse_col = 11 + flr(pulse * 3)
    spr(4, exit_portal[1]-2, exit_portal[2]-5)
    -- portal glow
    circ(exit_portal[1], exit_portal[2]-2, 4 + pulse*2, pulse_col)
  end

  -- draw player
  spr(1, px-2, py-2, 1, 1, pdir == -1)

  -- draw particles
  draw_particles()

  -- screen flash effect
  if flash_amt > 0 then
    local flash_col = flr(flash_amt / 2)
    if flash_col > 0 and flash_col <= 7 then
      rectfill(0, 0, 127, 127, flash_col)
    end
  end

  -- draw instruction
  print("jump: z", 2, 120, 7)
  camera(0, 0)
end

function draw_gameover()
  apply_screenshake()
  cls(1)

  if state == "gameover" then
    local win_state = false
    for log in all(test_log or {}) do
      if log == "result:win" then win_state = true end
    end

    if win_state then
      -- win screen with comprehensive feedback
      print("★ you win! ★", 30, 8, 11)
      print("all levels complete!", 20, 20, 7)

      -- score and collection stats
      print("final score: "..score, 32, 33, 7)
      print("fish collected: "..fish_collected, 24, 43, 12)

      -- playtime
      local playtime_sec = total_playtime / 60
      print("time: "..flr(playtime_sec).."s", 44, 53, 6)

      -- high score display
      print("high score: "..high_score, 32, 63, 11)

      -- show stars based on score
      if score >= 500 then
        print("★★★ perfect! ★★★", 22, 85, 11)
      elseif score >= 350 then
        print("★★ excellent! ★★", 25, 85, 11)
      else
        print("★ great job! ★", 32, 85, 11)
      end
    else
      -- game over screen
      print("game over", 38, 15, 8)
      print("score: "..score, 40, 28, 7)
      print("level reached: "..level, 28, 38, 7)
      print("fish collected: "..fish_collected, 24, 48, 12)
      print("high score: "..high_score, 36, 58, 11)

      -- difficulty info
      print("["..difficulty_names[difficulty].."]", 48, 68, 6)
    end
  end

  -- screen flash on gameover
  if flash_amt > 0 then
    local flash_col = flr(flash_amt / 2)
    if flash_col > 0 and flash_col <= 7 then
      rectfill(0, 0, 127, 127, flash_col)
    end
  end

  if flr(t() * 2) % 2 == 0 then
    print("press z to return to menu", 14, 110, 7)
  end
  camera(0, 0)
end

function _draw()
  cls()
  if state == "menu" then draw_menu()
  elseif state == "difficulty_select" then draw_difficulty_select()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__sfx__
0:010444051045110451104511040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1:021445054544505454454545045454545414535544505454405444044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2:061345054142514145041004100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3:071545064644054544054434453445344504140414000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4:081545074745074554753545045344534534450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5:031544034544034443034333033323032210031100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gfx__
00000000007cc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000776770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000767770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000776770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000077660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000066660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000069600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000696900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0800080080088008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0088000086880008000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0080080088008880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000088008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000088008800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000088888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000008888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a0a00000000000070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0a0a0000000000770770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a0a0a0a007777070707007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0a0a0070707070707070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a0a00007777070070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000770077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000070070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100100000f000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0111111007777700070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0111111007707770707070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0111111007707770070700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0011110007070700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00110000077770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
