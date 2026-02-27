pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- meteor dodge
-- survive falling meteors!

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

function test_input()
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn()
end

-- game state
state = "menu"
score = 0
highscore = 0
lives = 3
invincible = 0
shake_x = 0
shake_y = 0
shake_time = 0
difficulty = 1
last_score_time = 0
last_difficulty = 1
pause_cooldown = 0

-- difficulty preset: 1=zen, 2=normal, 3=hard
difficulty_preset = 2

-- pattern system (active during waves)
pattern_type = nil  -- nil, 1=convergence, 2=scatter, 3=zigzag
pattern_timer = 0

-- combo system
combo = 0
last_combo_time = 0
combo_pulse = 0

-- near-miss system
near_misses = 0
near_miss_pulse = 0

-- multiplier system
multiplier = 1.0
max_multiplier = 1.0
multiplier_pulse = 0
multiplier_samples = 0
multiplier_sample_count = 0

-- floating text
float_texts = {}

-- metrics tracking
max_combo = 0
total_stars = 0
total_powerups = 0
survival_time = 0
game_start_time = 0
achievements = {}
achievements_logged = false

-- player
px = 60
py = 100
pspeed = 2

-- meteors
meteors = {}
meteor_timer = 0
meteor_rate = 60

-- wave system
wave_state = "idle"
wave_timer = 0
wave_warning = 0

-- boss meteor system
boss_active = false
boss_meteor = nil
boss_dodges = 0
boss_warning = 0

-- stars
stars = {}
star_timer = 0

-- power-ups
powerups = {}
powerup_timer = 0
shield_active = false
slowtime = 0
slowtime_mult = 0.4

-- particles
particles = {}

function _init()
  cartdata("meteor_dodge_v1")
  highscore = dget(0)
  difficulty_preset = dget(1)
  if difficulty_preset < 1 or difficulty_preset > 3 then
    difficulty_preset = 2  -- default to normal
  end
  music(0)  -- menu music
  _log("music:menu")
  _log("init")
end

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "play" then
    update_play()
  elseif state == "pause" then
    update_pause()
  elseif state == "gameover" then
    update_gameover()
  end
end

function _draw()
  cls(1)

  -- apply screen shake
  camera(shake_x, shake_y)

  if state == "menu" then
    draw_menu()
  elseif state == "play" then
    draw_play()
  elseif state == "pause" then
    draw_pause()
  elseif state == "gameover" then
    draw_gameover()
  end

  camera()

  -- update shake
  if shake_time > 0 then
    shake_time -= 1
    shake_x = rnd(4) - 2
    shake_y = rnd(4) - 2
  else
    shake_x = 0
    shake_y = 0
  end
end

function update_menu()
  local buttons = test_input()

  -- mode selection with arrow keys
  if (buttons & 1) > 0 and difficulty_preset > 1 then
    difficulty_preset -= 1
    dset(1, difficulty_preset)
    sfx(4)  -- ui sound
    _log("mode_select:"..get_mode_name())
  elseif (buttons & 2) > 0 and difficulty_preset < 3 then
    difficulty_preset += 1
    dset(1, difficulty_preset)
    sfx(4)  -- ui sound
    _log("mode_select:"..get_mode_name())
  end

  if (buttons & 16) > 0 then
    sfx(4)  -- ui select
    _log("sfx:ui_select")
    _log("mode:"..get_mode_name())
    state = "play"
    score = 0
    lives = 3
    difficulty = 1
    last_difficulty = 1
    pause_cooldown = 0
    meteors = {}
    stars = {}
    powerups = {}
    particles = {}
    meteor_timer = 0
    star_timer = 0
    powerup_timer = 0
    shield_active = false
    slowtime = 0
    last_score_time = t()
    game_start_time = t()
    wave_state = "idle"
    pattern_type = nil
    pattern_timer = 0
    multiplier = 1.0
    max_multiplier = 1.0
    multiplier_pulse = 0
    multiplier_samples = 0
    multiplier_sample_count = 0

    -- set wave timing based on difficulty preset
    if difficulty_preset == 1 then
      -- zen mode: no waves
      wave_timer = 999999
    elseif difficulty_preset == 3 then
      -- hard mode: waves start at 10s
      wave_timer = 600 + rnd(300)
    else
      -- normal mode: waves start at 20-30s
      wave_timer = 1200 + rnd(600)
    end

    wave_warning = 0
    boss_active = false
    boss_meteor = nil
    boss_dodges = 0
    boss_warning = 0
    combo = 0
    last_combo_time = 0
    combo_pulse = 0
    near_misses = 0
    near_miss_pulse = 0
    float_texts = {}
    max_combo = 0
    total_stars = 0
    total_powerups = 0
    survival_time = 0
    px = 60
    py = 100
    multiplier = 1.0
    max_multiplier = 1.0
    multiplier_pulse = 0
    multiplier_samples = 0
    multiplier_sample_count = 0
    music(1)  -- gameplay music
    _log("music:play")
    _log("state:play")
  end
end

function update_pause()
  local buttons = test_input()

  -- update pause cooldown
  if pause_cooldown > 0 then
    pause_cooldown -= 1
  end

  -- resume with X
  if (buttons & 32) > 0 and pause_cooldown == 0 then
    state = "play"
    pause_cooldown = 15
    _log("resume")
  end

  -- quit to menu with Z (O button)
  if (buttons & 16) > 0 then
    state = "menu"
    pause_cooldown = 0
    music(-1)
    _log("pause:quit")
    _log("state:menu")
  end
end

function get_mode_name()
  if difficulty_preset == 1 then return "zen"
  elseif difficulty_preset == 3 then return "hard"
  else return "normal" end
end

function spawn_meteor()
  -- determine meteor type based on difficulty
  -- types: 1=fast/red, 2=slow/blue, 3=normal/gray
  local mtype = 3
  local rand = rnd(100)

  -- higher difficulty (lower spawn rate) = more fast meteors
  if meteor_rate <= 30 then
    if rand < 40 then mtype = 1
    elseif rand < 70 then mtype = 3
    else mtype = 2 end
  elseif meteor_rate <= 45 then
    if rand < 25 then mtype = 1
    elseif rand < 60 then mtype = 3
    else mtype = 2 end
  else
    if rand < 15 then mtype = 1
    elseif rand < 50 then mtype = 3
    else mtype = 2 end
  end

  -- set properties based on type
  local size, speed_mult, crad
  if mtype == 1 then
    -- fast red
    size = 3
    speed_mult = 1.5
    crad = 5
  elseif mtype == 2 then
    -- slow blue
    size = 6
    speed_mult = 0.5
    crad = 8
  else
    -- normal gray
    size = 4
    speed_mult = 1
    crad = 6
  end

  -- apply hard mode speed boost
  if difficulty_preset == 3 then
    speed_mult *= 1.2
  end

  -- calculate spawn position and velocity based on pattern
  local spawn_x, vx = rnd(112) + 8, 0
  local vy = (1 + rnd(1 + difficulty * 0.3)) * speed_mult

  if pattern_type == 1 then
    -- convergence: spawn wider, arc toward center
    spawn_x = rnd(128)
    local center_dir = sgn(64 - spawn_x)
    vx = center_dir * 0.3
  elseif pattern_type == 2 then
    -- scatter: spawn center, spread outward
    spawn_x = 56 + rnd(16)
    vx = (spawn_x - 64) / 20
  elseif pattern_type == 3 then
    -- zigzag: spawn offset, oscillate
    spawn_x = rnd(112) + 8
    -- oscillation handled in update
  end

  add(meteors, {
    x = spawn_x,
    y = -8,
    speed = vy,
    vx = vx,
    type = mtype,
    size = size,
    crad = crad,
    near_player = false,
    near_miss_logged = false,
    zigzag_phase = rnd(1)  -- for zigzag pattern
  })

  local tname = "normal"
  if mtype == 1 then tname = "fast"
  elseif mtype == 2 then tname = "slow" end
  _log("meteor_spawn:"..tname)
end

function spawn_powerup()
  -- types: 1=shield, 2=slowtime, 3=invincibility
  local ptype = flr(rnd(3)) + 1
  add(powerups, {
    x = rnd(112) + 8,
    y = rnd(100) + 10,
    age = 0,
    type = ptype
  })

  local pname = "shield"
  if ptype == 2 then pname = "slowtime"
  elseif ptype == 3 then pname = "invincibility" end
  _log("powerup_spawn:"..pname)
end

function spawn_particles(x, y, count, color, spread)
  for i=1,count do
    local angle = rnd(1)
    local speed = 0.5 + rnd(spread)
    add(particles, {
      x = x,
      y = y,
      vx = cos(angle) * speed,
      vy = sin(angle) * speed,
      age = 0,
      max_age = 20 + rnd(10),
      color = color,
      size = 1 + rnd(1)
    })
  end
  _log("particles:"..count)
end

function update_particles()
  for p in all(particles) do
    p.x += p.vx
    p.y += p.vy
    p.age += 1

    -- fade velocity
    p.vx *= 0.9
    p.vy *= 0.9

    if p.age >= p.max_age then
      del(particles, p)
    end
  end
end

function draw_particles()
  for p in all(particles) do
    -- fade size as particle ages
    local fade = 1 - (p.age / p.max_age)
    local s = p.size * fade
    if s > 0.5 then
      circfill(p.x, p.y, s, p.color)
    end
  end
end

function add_score(points)
  -- apply multiplier to score
  local actual = flr(points * multiplier)
  score += actual

  -- track for average calculation
  multiplier_samples += multiplier
  multiplier_sample_count += 1

  _log("score_add:"..points.."x"..multiplier.."="..actual)
  return actual
end

function update_float_texts()
  for ft in all(float_texts) do
    ft.y += ft.vy
    ft.age += 1
    if ft.age >= ft.max_age then
      del(float_texts, ft)
    end
  end
end

function draw_float_texts()
  for ft in all(float_texts) do
    -- fade as text ages
    local fade = 1 - (ft.age / ft.max_age)
    if fade > 0.3 then
      print(ft.text, ft.x - 4, ft.y, ft.color)
    end
  end
end

function update_play()
  -- get input once per frame
  local buttons = test_input()

  -- update pause cooldown
  if pause_cooldown > 0 then
    pause_cooldown -= 1
  end

  -- check for pause button (X)
  if (buttons & 32) > 0 and pause_cooldown == 0 then
    state = "pause"
    pause_cooldown = 15
    _log("pause")
    return
  end

  -- player movement
  local old_px = px
  local old_py = py

  if (buttons & 1) > 0 then px -= pspeed end
  if (buttons & 2) > 0 then px += pspeed end
  if (buttons & 4) > 0 then py -= pspeed end
  if (buttons & 8) > 0 then py += pspeed end

  px = mid(4, px, 120)
  py = mid(4, py, 120)

  if old_px != px or old_py != py then
    _log("move:"..px..","..py)
  end

  -- update invincibility
  if invincible > 0 then
    invincible -= 1
  end

  -- update slowtime
  if slowtime > 0 then
    slowtime -= 1
    if slowtime == 0 then
      _log("slowtime:end")
    end
  end

  -- update particles
  update_particles()

  -- update floating texts
  update_float_texts()

  -- update combo pulse
  if combo_pulse > 0 then
    combo_pulse -= 1
  end

  -- update near-miss pulse
  if near_miss_pulse > 0 then
    near_miss_pulse -= 1
  end

  -- update multiplier pulse
  if multiplier_pulse > 0 then
    multiplier_pulse -= 1
  end

  -- increase difficulty over time
  difficulty = 1 + flr(t() / 30)
  local base_rate = max(20, 60 - difficulty * 3)

  -- play sound on difficulty increase
  if difficulty > last_difficulty then
    sfx(3)
    _log("sfx:difficulty_up:"..difficulty)
    last_difficulty = difficulty
  end

  -- wave system (disabled in zen mode)
  if difficulty_preset != 1 then
    wave_timer -= 1

    if wave_state == "idle" then
      -- clear pattern when not in wave
      if pattern_type != nil then
        pattern_type = nil
        _log("pattern:normal")
      end

      -- countdown to next wave
      if wave_timer <= 120 and wave_warning == 0 then
        -- start warning 2 seconds before wave
        wave_warning = 120
        sfx(3)  -- warning sound
        _log("wave_warning")
      end

      if wave_warning > 0 then
        wave_warning -= 1
      end

      if wave_timer <= 0 then
        -- start wave
        wave_state = "active"

        -- hard mode: longer, more intense waves
        if difficulty_preset == 3 then
          wave_timer = 600 + rnd(300)  -- 10-15 seconds
        else
          wave_timer = 480 + rnd(240)  -- 8-12 seconds
        end

        wave_warning = 0

        -- initialize pattern system
        pattern_type = 1  -- start with convergence
        pattern_timer = 240 + rnd(120)  -- 4-6 seconds
        _log("wave_pattern:convergence")

        sfx(3)
        _log("wave_start")
      end
    elseif wave_state == "active" then
      -- wave is active - spawn meteors faster

      -- rotate patterns during wave
      pattern_timer -= 1
      if pattern_timer <= 0 then
        -- cycle to next pattern
        pattern_type += 1
        if pattern_type > 3 then pattern_type = 1 end

        pattern_timer = 240 + rnd(120)  -- 4-6 seconds

        local pname = "convergence"
        if pattern_type == 2 then pname = "scatter"
        elseif pattern_type == 3 then pname = "zigzag" end
        _log("wave_pattern:"..pname)
      end

      -- boss spawn logic
      local boss_difficulty_req = difficulty_preset == 3 and 1 or 2
      if not boss_active and wave_timer <= 180 and wave_timer > 170 and difficulty >= boss_difficulty_req then
        boss_active = true
        boss_warning = 60  -- 1 second warning
        sfx(3)  -- warning sound
        _log("boss_warning")
      end

      -- spawn boss after warning
      if boss_active and boss_warning > 0 then
        boss_warning -= 1
        if boss_warning == 0 then
          boss_meteor = {
            x = rnd(112) + 8,
            y = -12,
            speed = 0.3,
            vx = 0,
            type = 4,  -- boss type
            size = 8,
            crad = 12,
            near_player = false,
            near_miss_logged = false,
            health = 3,
            zigzag_phase = 0
          }
          _log("boss_spawn")
        end
      end

      if wave_timer <= 0 then
        -- end wave
        wave_state = "idle"

        -- hard mode: shorter cooldown
        if difficulty_preset == 3 then
          wave_timer = 600 + rnd(300)  -- 10-15 seconds
        else
          wave_timer = 1200 + rnd(600)  -- 20-30 seconds
        end

        boss_active = false
        boss_meteor = nil
        boss_warning = 0
        pattern_type = nil
        _log("wave_end")
      end
    end
  end

  -- set meteor rate based on wave state
  if wave_state == "active" then
    -- wave intensity scales with difficulty
    local wave_mult = max(0.3, 1 - difficulty * 0.1)
    meteor_rate = flr(base_rate * wave_mult)
  else
    -- relaxed spawn rate between waves
    meteor_rate = base_rate + 15
  end

  -- score increases every second
  if t() - last_score_time >= 1 then
    add_score(1)
    last_score_time = t()
    if score % 10 == 0 then
      _log("score:"..score)
    end
  end

  -- spawn meteors
  meteor_timer -= 1
  if meteor_timer <= 0 then
    spawn_meteor()
    meteor_timer = meteor_rate
    sfx(0)  -- meteor spawn
    _log("sfx:meteor_spawn")
  end

  -- update meteors
  for m in all(meteors) do
    -- apply slowtime multiplier
    local speed = m.speed
    if slowtime > 0 then
      speed *= slowtime_mult
    end
    m.y += speed

    -- apply horizontal movement based on pattern
    if m.vx then
      m.x += m.vx
    end

    -- zigzag pattern: oscillate left/right
    if pattern_type == 3 then
      m.zigzag_phase += 0.02
      m.x += cos(m.zigzag_phase) * 1.5
    end

    -- track if meteor gets near player (dodge zone)
    if not m.near_player then
      local dist = sqrt((m.x - px) * (m.x - px) + (m.y - py) * (m.y - py))
      if dist < 20 then
        m.near_player = true
      end
    end

    -- near-miss detection: reward skillful dodging
    if not m.near_miss_logged and invincible == 0 then
      local dist = sqrt((m.x - px) * (m.x - px) + (m.y - py) * (m.y - py))
      -- trigger when meteor is within 12-15 pixels and passing by player
      if dist >= 12 and dist < 15 and m.y >= py - 10 then
        m.near_miss_logged = true
        near_misses += 1

        -- increase multiplier
        local old_mult = flr(multiplier * 10) / 10
        multiplier = min(5.0, multiplier + 0.2)
        local new_mult = flr(multiplier * 10) / 10
        multiplier_pulse = 10

        -- track max multiplier
        if multiplier > max_multiplier then
          max_multiplier = multiplier
          _log("max_mult:"..multiplier)
        end

        -- play tier-up sound
        if new_mult > old_mult and (new_mult == 1.5 or new_mult == 2.0 or new_mult == 3.0 or new_mult == 4.0 or new_mult == 5.0) then
          sfx(2)
          _log("mult_tier:"..new_mult)
        end

        local points = add_score(10)
        near_miss_pulse = 5
        _log("near_miss:mult="..multiplier..":score="..score)

        -- spawn gold particles
        spawn_particles(m.x, m.y, 8, 10, 1.5)

        -- brief screen shake
        shake_time = 5

        -- add floating text
        add(float_texts, {
          x = m.x,
          y = m.y,
          text = "+"..points,
          age = 0,
          max_age = 30,
          vy = -0.5,
          color = 10
        })

        -- play sound (reuse star pickup sound)
        sfx(2)
        _log("sfx:near_miss")
      end
    end

    -- check collision with player
    if invincible == 0 and
       abs(m.x - px) < m.crad and
       abs(m.y - py) < m.crad then

      -- reset combo on hit
      if combo > 0 then
        _log("combo_reset:"..combo)
        combo = 0
        combo_pulse = 0
      end

      -- reset multiplier on hit
      if multiplier > 1.0 then
        _log("mult_reset:was="..multiplier)
        multiplier = 1.0
        multiplier_pulse = 0
      end

      -- check shield first
      if shield_active then
        shield_active = false
        invincible = 30  -- brief invincibility
        _log("shield_used")
      else
        lives -= 1
        invincible = 60
        _log("collision:lives="..lives)
      end

      shake_time = 15  -- enhanced shake

      -- spawn explosion particles
      local pcol = 8  -- default gray
      if m.type == 1 then pcol = 8  -- red meteor
      elseif m.type == 2 then pcol = 12 end  -- blue meteor
      spawn_particles(m.x, m.y, 5, pcol, 2)

      del(meteors, m)
      sfx(1)  -- collision
      _log("sfx:collision")

      if lives <= 0 then
        state = "gameover"
        survival_time = flr(t() - game_start_time)
        music(-1)  -- stop music
        _log("music:stop")
        _log("survival_time:"..survival_time)
        if score > highscore then
          highscore = score
          dset(0, highscore)
          _log("new_highscore:"..highscore)
        end
        calculate_achievements()
        _log("state:gameover")
      end
    end

    -- successful dodge: meteor exits screen after being near player
    if m.y > 136 then
      if m.near_player and t() - last_combo_time >= 1 then
        combo += 1
        last_combo_time = t()
        combo_pulse = 10
        _log("dodge:combo="..combo)

        -- track max combo
        if combo > max_combo then
          max_combo = combo
          _log("max_combo:"..max_combo)
        end

        -- milestone bonuses
        if combo == 10 or combo == 25 or combo == 50 or combo == 100 then
          local bonus = combo * 10
          add_score(bonus)
          _log("combo_bonus:"..combo.."="..bonus)
        end

        -- sound every 10 combos
        if combo % 10 == 0 then
          sfx(3)
          _log("sfx:combo_milestone:"..combo)
        end
      end
      del(meteors, m)
    end
  end

  -- update boss meteor
  if boss_meteor then
    -- apply slowtime multiplier
    local speed = boss_meteor.speed
    if slowtime > 0 then
      speed *= slowtime_mult
    end
    boss_meteor.y += speed

    -- apply horizontal movement if present
    if boss_meteor.vx then
      boss_meteor.x += boss_meteor.vx
    end

    -- track if boss gets near player (dodge zone)
    if not boss_meteor.near_player then
      local dist = sqrt((boss_meteor.x - px) * (boss_meteor.x - px) + (boss_meteor.y - py) * (boss_meteor.y - py))
      if dist < 25 then
        boss_meteor.near_player = true
      end
    end

    -- near-miss detection for boss (wider threshold)
    if not boss_meteor.near_miss_logged and invincible == 0 then
      local dist = sqrt((boss_meteor.x - px) * (boss_meteor.x - px) + (boss_meteor.y - py) * (boss_meteor.y - py))
      -- trigger when boss is within 15-18 pixels and passing by player
      if dist >= 15 and dist < 18 and boss_meteor.y >= py - 10 then
        boss_meteor.near_miss_logged = true
        near_misses += 1

        -- increase multiplier
        local old_mult = flr(multiplier * 10) / 10
        multiplier = min(5.0, multiplier + 0.2)
        local new_mult = flr(multiplier * 10) / 10
        multiplier_pulse = 10

        -- track max multiplier
        if multiplier > max_multiplier then
          max_multiplier = multiplier
          _log("max_mult:"..multiplier)
        end

        -- play tier-up sound
        if new_mult > old_mult and (new_mult == 1.5 or new_mult == 2.0 or new_mult == 3.0 or new_mult == 4.0 or new_mult == 5.0) then
          sfx(2)
          _log("mult_tier:"..new_mult)
        end

        local points = add_score(10)
        near_miss_pulse = 5
        _log("near_miss:boss:mult="..multiplier..":score="..score)

        -- spawn gold particles
        spawn_particles(boss_meteor.x, boss_meteor.y, 10, 10, 2)

        -- brief screen shake
        shake_time = 5

        -- add floating text
        add(float_texts, {
          x = boss_meteor.x,
          y = boss_meteor.y,
          text = "+"..points,
          age = 0,
          max_age = 30,
          vy = -0.5,
          color = 10
        })

        -- play sound
        sfx(2)
        _log("sfx:near_miss_boss")
      end
    end

    -- check collision with player
    if invincible == 0 and
       abs(boss_meteor.x - px) < boss_meteor.crad and
       abs(boss_meteor.y - py) < boss_meteor.crad then

      -- reset combo on hit
      if combo > 0 then
        _log("combo_reset:"..combo)
        combo = 0
        combo_pulse = 0
      end

      -- reset multiplier on hit
      if multiplier > 1.0 then
        _log("mult_reset:was="..multiplier)
        multiplier = 1.0
        multiplier_pulse = 0
      end

      -- boss deals double damage
      if shield_active then
        shield_active = false
        invincible = 30
        _log("shield_used:boss")
      else
        lives -= 2  -- double damage
        invincible = 60
        _log("collision:boss:lives="..lives)
      end

      shake_time = 30  -- stronger shake

      -- spawn explosion particles
      spawn_particles(boss_meteor.x, boss_meteor.y, 12, 10, 3)

      boss_meteor = nil
      boss_active = false
      sfx(1)  -- collision
      _log("sfx:boss_collision")

      if lives <= 0 then
        state = "gameover"
        survival_time = flr(t() - game_start_time)
        music(-1)
        _log("music:stop")
        _log("survival_time:"..survival_time)
        if score > highscore then
          highscore = score
          dset(0, highscore)
          _log("new_highscore:"..highscore)
        end
        calculate_achievements()
        _log("state:gameover")
      end
    end

    -- successful boss dodge: boss exits screen after being near player
    if boss_meteor.y > 136 then
      if boss_meteor.near_player then
        boss_dodges += 1
        add_score(200)  -- boss bonus
        shake_time = 10
        _log("boss_dodge:score="..score)

        -- spawn celebration particles
        spawn_particles(64, 64, 15, 10, 2)

        sfx(5)  -- triumphant sound
        _log("sfx:boss_defeated")
      end
      boss_meteor = nil
      boss_active = false
    end
  end

  -- spawn stars occasionally
  star_timer -= 1
  if star_timer <= 0 then
    add(stars, {
      x = rnd(112) + 8,
      y = rnd(100) + 10,
      age = 0
    })
    star_timer = 180 + rnd(120)
    _log("star_spawn")
  end

  -- update stars
  for s in all(stars) do
    s.age += 1

    -- check collision with player
    if abs(s.x - px) < 6 and
       abs(s.y - py) < 6 then
      add_score(50)
      total_stars += 1

      -- spawn star particles
      spawn_particles(s.x, s.y, 6, 10, 1.5)

      del(stars, s)
      sfx(2)  -- star pickup
      _log("sfx:star_pickup")
      _log("pickup:star:total="..total_stars)
    end

    -- remove old stars
    if s.age > 300 then
      del(stars, s)
    end
  end

  -- spawn power-ups (after 10 seconds)
  if t() > 10 then
    powerup_timer -= 1
    if powerup_timer <= 0 then
      spawn_powerup()
      powerup_timer = 180 + rnd(300)  -- 3-8 seconds
    end
  end

  -- update power-ups
  for p in all(powerups) do
    p.age += 1

    -- check collision with player
    if abs(p.x - px) < 6 and
       abs(p.y - py) < 6 then
      add_score(25)
      total_powerups += 1

      -- apply power-up effect
      if p.type == 1 then
        -- shield
        shield_active = true
        _log("pickup:shield")
      elseif p.type == 2 then
        -- slow-time
        slowtime = 480  -- 8 seconds
        _log("pickup:slowtime:480")
      elseif p.type == 3 then
        -- invincibility boost
        if invincible > 0 then
          invincible += 300
        else
          invincible = 300
        end
        _log("pickup:invincibility")
      end

      -- spawn particles
      local pcol = 12
      if p.type == 2 then pcol = 14
      elseif p.type == 3 then pcol = 10 end
      spawn_particles(p.x, p.y, 8, pcol, 2)

      del(powerups, p)
      sfx(5)  -- powerup pickup
      _log("sfx:powerup_pickup")
      _log("pickup:powerup:total="..total_powerups)
    end

    -- remove old power-ups (8 seconds)
    if p.age > 480 then
      del(powerups, p)
    end
  end
end

function calculate_achievements()
  achievements = {}
  achievements_logged = false

  if max_combo >= 50 then
    add(achievements, {text="combo killer", col=8})
  end
  if boss_dodges >= 3 then
    add(achievements, {text="boss slayer", col=10})
  end
  if total_stars >= 10 then
    add(achievements, {text="star collector", col=9})
  end
  if survival_time >= 60 then
    add(achievements, {text="survivor", col=12})
  end
  if total_powerups >= 5 then
    add(achievements, {text="power player", col=14})
  end
  if max_multiplier >= 5.0 then
    add(achievements, {text="max multiplier!", col=8})
  end
end

function update_gameover()
  -- log achievements on first frame
  if not achievements_logged then
    for a in all(achievements) do
      _log("achievement:"..a.text)
    end
    achievements_logged = true
  end

  if (test_input() & 16) > 0 then
    sfx(4)  -- ui select
    _log("sfx:ui_select")
    state = "menu"
    music(0)  -- menu music
    _log("music:menu")
    _log("state:menu")
  end
end

function draw_menu()
  print("meteor dodge", 32, 40, 7)
  print("avoid the meteors!", 20, 55, 6)

  -- difficulty mode selection
  print("mode:", 36, 66, 13)

  -- zen mode
  local zen_col = difficulty_preset == 1 and 10 or 5
  print("zen", 24, 74, zen_col)
  if difficulty_preset == 1 then
    print("\151", 16, 74, 10)  -- arrow
  end

  -- normal mode
  local normal_col = difficulty_preset == 2 and 10 or 5
  print("normal", 48, 74, normal_col)
  if difficulty_preset == 2 then
    print("\151", 40, 74, 10)  -- arrow
  end

  -- hard mode
  local hard_col = difficulty_preset == 3 and 10 or 5
  print("hard", 88, 74, hard_col)
  if difficulty_preset == 3 then
    print("\151", 80, 74, 10)  -- arrow
  end

  print("arrows to select", 24, 84, 6)
  print("press z to start", 22, 100, 11)

  -- draw example meteors
  -- fast red
  circfill(50, 20, 3, 8)
  circfill(50, 20, 1, 2)
  -- normal gray
  circfill(64, 20, 4, 8)
  circfill(64, 20, 2, 2)
  -- slow blue
  circfill(82, 20, 6, 12)
  circfill(82, 20, 4, 1)
end

function draw_pause()
  -- draw the game state in background (frozen)
  for i=0,20 do
    local sx = (i * 37) % 128
    local sy = (i * 53 + t() * 10) % 128
    pset(sx, sy, 5)
  end

  -- draw meteors
  for m in all(meteors) do
    local mcol = 6
    if m.type == 1 then mcol = 8
    elseif m.type == 2 then mcol = 12 end
    circfill(m.x, m.y, m.size, mcol)
    circfill(m.x, m.y, m.size - 2, 2)
  end

  -- draw stars
  for s in all(stars) do
    local pulse = 1 + sin(t() * 2 + s.x / 20) * 0.5
    for i=0,3 do
      local angle = i / 4 + t() * 0.1
      local px = s.x + cos(angle) * 3 * pulse
      local py = s.y + sin(angle) * 3 * pulse
      circfill(px, py, 1, 10)
    end
  end

  -- draw player
  local pcol = 7
  if invincible > 0 and (invincible % 8 < 4) then
    pcol = 10
  end
  circfill(px, py, 3, pcol)
  circfill(px - 1, py - 1, 1, 12)

  -- semi-transparent overlay
  for y=0,127 do
    if y % 2 == 0 then
      for x=0,127,2 do
        pset(x, y, 0)
      end
    else
      for x=1,127,2 do
        pset(x, y, 0)
      end
    end
  end

  -- pause title
  print("paused", 44, 30, 7)

  -- current stats
  local survival = flr(survival_time)
  print("score: "..score, 36, 50, 11)
  print("time: "..survival.."s", 36, 58, 11)

  if combo > 0 then
    print("combo: "..combo.."x", 34, 66, 10)
  end

  -- controls
  print("x to resume", 32, 86, 6)
  print("z to quit to menu", 18, 94, 6)
end

function draw_play()
  -- draw starfield background
  for i=0,20 do
    local sx = (i * 37) % 128
    local sy = (i * 53 + t() * 10) % 128
    pset(sx, sy, 5)
  end

  -- wave warning visual: pulsing border
  if wave_warning > 0 then
    local pulse = flr(wave_warning / 8) % 2
    if pulse == 0 then
      local col = 8  -- red warning
      rect(0, 0, 127, 127, col)
      rect(1, 1, 126, 126, col)
    end
  end

  -- wave active indicator
  if wave_state == "active" then
    local pulse_col = 8 + flr(t() * 4) % 2
    print("wave!", 2, 14, pulse_col)
  end

  -- draw player
  if invincible == 0 or invincible % 4 < 2 then
    local body_col, inner_col, cockpit_col = 12, 7, 10

    -- flash white on fresh damage
    if invincible > 54 then
      body_col, inner_col, cockpit_col = 7, 7, 7
    end

    -- ship body
    circfill(px, py, 3, body_col)
    circfill(px, py, 2, inner_col)
    -- cockpit
    circfill(px, py - 1, 1, cockpit_col)
    -- wings
    pset(px - 3, py + 1, 6)
    pset(px + 3, py + 1, 6)
  end

  -- draw shield ring
  if shield_active then
    local ring_offset = (t() * 4) % 8
    circ(px, py, 5 + ring_offset * 0.2, 12)
  end

  -- draw meteors
  for m in all(meteors) do
    local col1, col2
    if m.type == 1 then
      -- fast red
      col1 = 8
      col2 = 2
    elseif m.type == 2 then
      -- slow blue
      col1 = 12
      col2 = 1
    else
      -- normal gray
      col1 = 8
      col2 = 2
    end
    circfill(m.x, m.y, m.size, col1)
    circfill(m.x, m.y, m.size - 2, col2)
    circfill(m.x - 1, m.y - 1, 1, 5)
  end

  -- draw boss meteor
  if boss_meteor then
    -- pulsing ring effect
    local pulse = sin(t() * 2) * 2
    circ(boss_meteor.x, boss_meteor.y, boss_meteor.size + 2 + pulse, 10)
    circ(boss_meteor.x, boss_meteor.y, boss_meteor.size + 4 + pulse, 9)

    -- main body (bright white/gold)
    circfill(boss_meteor.x, boss_meteor.y, boss_meteor.size, 10)
    circfill(boss_meteor.x, boss_meteor.y, boss_meteor.size - 2, 9)
    circfill(boss_meteor.x, boss_meteor.y, boss_meteor.size - 4, 7)
    -- glowing core
    circfill(boss_meteor.x - 1, boss_meteor.y - 1, 2, 7)
  end

  -- boss warning text
  if boss_warning > 0 or boss_meteor then
    local pulse_col = 8 + flr(t() * 8) % 2
    print("boss!", 50, 30, pulse_col)
  end

  -- draw stars
  for s in all(stars) do
    draw_star(s.x, s.y)
  end

  -- draw power-ups
  for p in all(powerups) do
    draw_powerup(p.x, p.y, p.type)
  end

  -- draw particles
  draw_particles()

  -- draw floating texts
  draw_float_texts()

  -- draw ui
  print("score:"..score, 2, 2, 7)
  print("hi:"..highscore, 2, 8, 10)

  -- draw combo counter (top-right)
  if combo > 0 then
    local combo_text = "x"..combo
    local text_width = #combo_text * 4
    local combo_x = 127 - text_width
    local combo_y = 2

    -- color based on combo level
    local combo_col = 7  -- white
    if combo >= 50 then
      combo_col = 8  -- red
    elseif combo >= 25 then
      combo_col = 9  -- orange/yellow
    elseif combo >= 10 then
      combo_col = 10  -- yellow
    end

    -- pulsate effect
    if combo_pulse > 0 then
      combo_y -= flr(combo_pulse / 5)
    end

    print(combo_text, combo_x, combo_y, combo_col)
  end

  -- draw multiplier (center-top, only if >1.0)
  if multiplier > 1.0 then
    local mult_text = flr(multiplier * 10) / 10 .. "x"
    local text_width = #mult_text * 4
    local mult_x = 64 - text_width / 2
    local mult_y = 2

    -- color based on multiplier tier (spec: yellow 1.5x, orange 3x, red 5x)
    local mult_col = 10  -- yellow (default for 1.0-2.9x)
    if multiplier >= 5.0 then
      mult_col = 8  -- red
    elseif multiplier >= 3.0 then
      mult_col = 9  -- orange
    end

    -- pulsate effect when multiplier increases
    if multiplier_pulse > 0 then
      local scale = 1 + multiplier_pulse / 20
      mult_y -= flr(multiplier_pulse / 3)
      -- draw shadow for emphasis
      print(mult_text, mult_x + 1, mult_y + 1, 1)
    end

    print(mult_text, mult_x, mult_y, mult_col)
  end

  -- draw lives
  for i=1,lives do
    circfill(125 - i * 8, 13, 2, 8)
  end

  -- draw slowtime indicator
  if slowtime > 0 then
    print("slow", 2, 120, 14)
  end

  -- draw boss dodges counter
  if boss_dodges > 0 then
    print("boss x"..boss_dodges, 2, 114, 10)
  end
end

function draw_gameover()
  -- title
  print("game over!", 36, 4, 8)

  -- score section
  print("final score: "..score, 3, 14, 7)
  if score == highscore and score > 0 then
    print("new high score!", 28, 20, 10)
  else
    print("high score: "..highscore, 3, 20, 10)
  end

  -- metrics section
  print("--- stats ---", 32, 30, 13)
  print("time: "..survival_time.."s", 3, 38, 6)
  print("max combo: x"..max_combo, 3, 44, 6)

  -- multiplier stats
  local avg_mult = 1.0
  if multiplier_sample_count > 0 then
    avg_mult = flr((multiplier_samples / multiplier_sample_count) * 10) / 10
  end
  local max_mult_rounded = flr(max_multiplier * 10) / 10
  print("max mult: "..max_mult_rounded.."x", 3, 50, 6)
  print("avg mult: "..avg_mult.."x", 3, 56, 6)

  print("bosses: "..boss_dodges, 3, 62, 6)
  print("stars: "..total_stars, 3, 68, 6)
  print("power-ups: "..total_powerups, 3, 74, 6)

  -- achievements section
  local ach_y = 84
  if #achievements > 0 then
    print("achievements:", 26, ach_y, 7)
    ach_y += 8
    for a in all(achievements) do
      print("\151 "..a.text, 20, ach_y, a.col)
      ach_y += 6
    end
  end

  -- retry prompt
  print("press z to retry", 22, 118, 11)
end

function draw_star(x, y)
  -- spinning star pickup
  local spin = t() * 2
  local c = 10
  for i=0,3 do
    local a = (i / 4 + spin) % 1
    local dx = cos(a) * 4
    local dy = sin(a) * 4
    line(x, y, x + dx, y + dy, c)
  end
  circfill(x, y, 2, 9)
end

function draw_powerup(x, y, ptype)
  local spin = t() * 3
  local c, border_c

  if ptype == 1 then
    -- shield (blue with border)
    c = 12
    border_c = 1
  elseif ptype == 2 then
    -- slow-time (purple)
    c = 14
    border_c = 2
  else
    -- invincibility (gold)
    c = 10
    border_c = 9
  end

  -- draw star shape
  for i=0,3 do
    local a = (i / 4 + spin) % 1
    local dx = cos(a) * 4
    local dy = sin(a) * 4
    line(x, y, x + dx, y + dy, c)
  end

  -- center and border
  circfill(x, y, 2, c)
  circ(x, y, 3, border_c)
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
000100001f0502105023050250502705027050250502305021050200501f0501d0501c0501b0501a05019050180501705016050150501405013050120501105010050100500f0500e0500d0500c0500b0500a050
000200000c0530e053100531305317053190531c0531e053200532305324053240532305320053200531f0531d0531c0531a05318053160531405312053100530f0530e0530c0530a053080530605304053020530105300003
000300001d0501f05021050230502505027050290502b0502d0502f050310503305035050370503905039050390503905039050390503805037050350503305031050300502e0502c0502a0502805026050240502205020050
00020000180501a0501c0501e050200502205024050260502805028050280502805028050280502705026050240502205020050200502005020050200501f0501d0501c0501a05018050160501405012050100500f050
00010000200502205024050260502805028050280502805028050280502805028050280502805027050260502505024050230502205021050200501f0501e0501d0501c0501b0501a05019050180501705016050150500000
000300002405026050280502a0502c0502e050300503205034050360503805037050360503505034050330503205031050300502f0502e0502d0502c0502b0502a05029050280502705026050250502405023050220502105020050
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00014344
00 01024344
00 02034344
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
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777700000007777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777770000077777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777770000077777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777770000077777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777770000077777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777700000007777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
11111111111111111111111177777777777777777777777777777777777777777777777111111111111111111111111111111111111111111111111111111111
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
