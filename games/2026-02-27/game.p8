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
highscore = 0
new_record = false  -- flag for new high score
new_record_flash = 0  -- flash timer for new record
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

-- settings state
music_enabled = true  -- toggle music on/off
sfx_enabled = true  -- toggle sfx on/off
ball_skin = 1  -- ball appearance: 1=white, 2=gold, 3=cyan
settings_selection = 1  -- current settings menu cursor (1-4)

-- danger zones system
danger_zones = {}
zone_timer = 0
zone_interval = 450  -- ~15 seconds

-- performance stats
max_combo = 0
total_dodges = 0
total_powerups = 0
total_dodge_bonus = 0

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

  -- load saved high score (slot 0)
  highscore = dget(0)
  _log("highscore_loaded:"..highscore)

  -- load settings (slots 1-3)
  load_settings()

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

  _log("settings_loaded:m="..tostr(music_enabled)..",s="..tostr(sfx_enabled)..",b="..ball_skin)
end

function save_settings()
  dset(1, music_enabled and 1 or 0)
  dset(2, sfx_enabled and 1 or 0)
  dset(3, ball_skin)
  _log("settings_saved")
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
  elseif state == "difficulty_select" then
    update_difficulty_select()
  elseif state == "settings" then
    update_settings()
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
  elseif state == "difficulty_select" then
    draw_difficulty_select()
  elseif state == "settings" then
    draw_settings()
  elseif state == "play" then
    draw_play()
  elseif state == "pause" then
    draw_pause()
  elseif state == "gameover" then
    draw_gameover()
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

  if input & 16 > 0 then  -- O button
    state = "difficulty_select"
    _log("state:difficulty_select")
    diff_selection = difficulty  -- reset to last selected
  end

  if input & 32 > 0 then  -- X button
    state = "settings"
    _log("state:settings")
    settings_selection = 1  -- reset cursor
    input_cooldown = 10
  end
end

function draw_menu()
  print("bounce king", 38, 40, 7)
  print("survive the fall!", 26, 52, 6)
  print("left/right: steer", 20, 70, 13)
  print("collect power-ups", 18, 78, 11)
  print("press o to start", 22, 96, 10)
  print("press x for settings", 14, 104, 13)
  if highscore > 0 then
    print("best: "..highscore, 40, 116, 10)
  end
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
        play_sfx(1)
        _log("ball_skin:"..ball_skin)
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
  if test_input() & 16 > 0 then
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

  -- new record indicator (prominent)
  if new_record then
    local flash_col = (new_record_flash % 8 < 4) and 10 or 9
    print("new record!", 36, 38, flash_col)
    -- update flash timer
    if new_record_flash > 0 then
      new_record_flash -= 1
    end
  end

  -- best score display
  if highscore > 0 then
    print("best: "..highscore, 42, 48, 12)
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

  -- retry prompt
  print("press o to retry", 24, 122, 13)
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
