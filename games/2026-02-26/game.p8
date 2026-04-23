pico-8 cartridge // http://www.pico-8.com
version 41
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


function test_input()
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn()
end

function test_input2()
  if testmode then return 0 end
  local b=0
  for i=0,5 do if btn(i,1) then b+=2^i end end
  return b
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
screen_flash = 0
difficulty = 1
last_score_time = 0
last_difficulty = 1
pause_cooldown = 0
gameover_timer = 0

difficulty_preset = 2
insane_unlocked = false 
just_unlocked_insane = false 

pattern_type = nil 
pattern_type2 = nil 
pattern_timer = 0
pattern_timer2 = 0

combo = 0
last_combo_time = 0
combo_pulse = 0

near_misses = 0
near_miss_pulse = 0

multiplier = 1.0
max_multiplier = 1.0
last_mult_milestone = 1.0
multiplier_pulse = 0
multiplier_samples = 0
multiplier_sample_count = 0

float_texts = {}

max_combo = 0
total_stars = 0
total_powerups = 0
survival_time = 0
game_start_time = 0
achievements = {}
achievements_logged = false

px = 60
py = 100
pspeed = 2

coop_mode = false
p2x = 68
p2y = 100
p2_invincible = 0
p2_near_misses = 0
p2_dodges = 0

meteors = {}
meteor_timer = 0
meteor_rate = 60

wave_state = "idle"
wave_timer = 0
wave_warning = 0
wave_count = 0
wave_intensity = 0 
wave_border_pulse = 0

boss_active = false
boss_meteor = nil
boss_dodges = 0
boss_defeats = 0
boss_warning = 0
boss_hp = 0
boss_attack_timer = 0
boss_attack_projectiles = {}
boss_attack_warning = 0
boss_attack_type = 0

stars = {}
star_timer = 0

powerups = {}
powerup_timer = 0
shield_active = false
slowtime = 0
slowtime_mult = 0.4

particles = {}

fade_alpha = 0
fade_dir = 0 
next_state = nil

tutorial_page = 0 

leaderboard_view_mode = 1 
leaderboards = {} 

stars_bg = {} 

function _init()
  cartdata("meteor_dodge_v1")
  highscore = dget(0)
  difficulty_preset = dget(1)
  if difficulty_preset < 1 or difficulty_preset > 4 then
    difficulty_preset = 2 
  end
 
  insane_unlocked = dget(2) == 1
  _log("insane_unlocked:"..tostr(insane_unlocked))
 
  load_leaderboards()
  music(0) 
 
  for i=1,30 do
    add(stars_bg, {
      x=rnd(128),
      y=rnd(128),
      spd=0.3+rnd(0.4),
      bright=flr(rnd(2))
    })
  end
  _log("music:menu")
  _log("init")
end

function _update()
 
  for s in all(stars_bg) do
    s.y += s.spd
    if s.y > 128 then
      s.y = 0
      s.x = rnd(128)
    end
  end

  if state == "menu" then
    update_menu()
  elseif state == "tutorial" then
    update_tutorial()
  elseif state == "leaderboard" then
    update_leaderboard()
  elseif state == "play" then
    update_play()
  elseif state == "pause" then
    update_pause()
  elseif state == "gameover" then
    update_gameover()
  end

 
  update_fade()
end

function _draw()
  cls(1)

 
  camera(shake_x, shake_y)

  if state == "menu" then
    draw_menu()
  elseif state == "tutorial" then
    draw_tutorial()
  elseif state == "leaderboard" then
    draw_leaderboard()
  elseif state == "play" then
    draw_play()
  elseif state == "pause" then
    draw_pause()
  elseif state == "gameover" then
    draw_gameover()
  end

  camera()

 
  if screen_flash > 0 then
    local flash_alpha = screen_flash / 15
    if flash_alpha > 0.3 then
     
      local flash_col = 10 
      if wave_intensity >= 3 then
        flash_col = 8 
      elseif wave_intensity >= 2 then
        flash_col = 9 
      end
      rectfill(0, 0, 127, 127, flash_col)
    end
  end

 
  draw_fade()

 
  if shake_time > 0 then
    shake_time -= 1
    shake_x = rnd(4) - 2
    shake_y = rnd(4) - 2
  else
    shake_x = 0
    shake_y = 0
  end

  if screen_flash > 0 then
    screen_flash -= 1
  end
end

-- leaderboard functions
function load_leaderboards()
 
 
 
  for diff=1,4 do
    leaderboards[diff] = {}
    local base = 3 + (diff - 1) * 10
    for i=1,5 do
      local slot = base + (i - 1) * 2
      local s = dget(slot)
      local t = dget(slot + 1)
      if s > 0 then
        add(leaderboards[diff], {score=s, time=t})
      end
    end
  end
  _log("leaderboards_loaded")
end

function save_to_leaderboard(diff, new_score, new_time)
 
  local board = leaderboards[diff] or {}
  local inserted = false

 
  for i=1,#board do
    if new_score > board[i].score or (new_score == board[i].score and new_time > board[i].time) then
     
      for j=#board,i,-1 do
        board[j + 1] = board[j]
      end
      board[i] = {score=new_score, time=new_time}
      inserted = true
      break
    end
  end

 
  if not inserted and #board < 5 then
    add(board, {score=new_score, time=new_time})
    inserted = true
  end

 
  while #board > 5 do
    del(board, board[6])
  end

  leaderboards[diff] = board

 
  local base = 3 + (diff - 1) * 10
  for i=1,5 do
    local slot = base + (i - 1) * 2
    if board[i] then
      dset(slot, board[i].score)
      dset(slot + 1, board[i].time)
    else
      dset(slot, 0)
      dset(slot + 1, 0)
    end
  end

  if inserted then
    _log("leaderboard_updated:diff"..diff..",score:"..new_score)
  end

  return inserted
end

function update_menu()
  local buttons = test_input()

 
  local max_mode = insane_unlocked and 4 or 3
  if (buttons & 1) > 0 and difficulty_preset > 1 then
    difficulty_preset -= 1
    dset(1, difficulty_preset)
    sfx(4) 
    _log("mode_select:"..get_mode_name())
  elseif (buttons & 2) > 0 and difficulty_preset < max_mode then
    difficulty_preset += 1
    dset(1, difficulty_preset)
    sfx(4) 
    _log("mode_select:"..get_mode_name())
  end

 
  if (buttons & 8) > 0 then
    coop_mode = not coop_mode
    sfx(4) 
    _log("coop_mode:"..tostr(coop_mode))
  end

 
  if (buttons & 4) > 0 then
    sfx(4) 
    _log("sfx:ui_select")
    state = "leaderboard"
    leaderboard_view_mode = difficulty_preset
    _log("state:leaderboard")
  end

 
  if (buttons & 32) > 0 then
    sfx(4) 
    _log("sfx:ui_select")
    state = "tutorial"
    tutorial_page = 0
    _log("state:tutorial")
  end

 
  if (buttons & 16) > 0 then
    sfx(4) 
    _log("sfx:ui_select")
    _log("mode:"..get_mode_name())
    _log("coop:"..tostr(coop_mode))
    state = "play"
    score = 0
    lives = coop_mode and 5 or 3
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
    wave_count = 0
    wave_intensity = 0
    wave_border_pulse = 0
    pattern_type = nil
    pattern_type2 = nil
    pattern_timer = 0
    pattern_timer2 = 0
    multiplier = 1.0
    max_multiplier = 1.0
    last_mult_milestone = 1.0
    multiplier_pulse = 0
    multiplier_samples = 0
    multiplier_sample_count = 0

   
    if difficulty_preset == 1 then
     
      wave_timer = 999999
    elseif difficulty_preset == 4 then
     
      wave_timer = 0
    elseif difficulty_preset == 3 then
     
      wave_timer = 600 + rnd(300)
    else
     
      wave_timer = 1200 + rnd(600)
    end

    wave_warning = 0
    boss_active = false
    boss_meteor = nil
    boss_dodges = 0
    boss_defeats = 0
    boss_warning = 0
    boss_hp = 0
    boss_attack_timer = 0
    boss_attack_projectiles = {}
    boss_attack_warning = 0
    boss_attack_type = 0
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
    p2x = 68
    p2y = 100
    p2_invincible = 0
    p2_near_misses = 0
    p2_dodges = 0
    screen_flash = 0
    music(1) 
    _log("music:play")
    _log("state:play")
  end
end

function update_tutorial()
  local buttons = test_input()

 
  if (buttons & 4) > 0 and tutorial_page > 0 then
    tutorial_page -= 1
    sfx(4)
    _log("tutorial_page:"..tutorial_page)
  elseif (buttons & 8) > 0 and tutorial_page < 2 then
    tutorial_page += 1
    sfx(4)
    _log("tutorial_page:"..tutorial_page)
  end

 
  if (buttons & 32) > 0 or (buttons & 16) > 0 then
    state = "menu"
    sfx(4)
    _log("state:menu")
  end
end

function update_pause()
  local buttons = test_input()

 
  if pause_cooldown > 0 then
    pause_cooldown -= 1
  end

 
  if (buttons & 32) > 0 and pause_cooldown == 0 then
    state = "play"
    pause_cooldown = 15
    _log("resume")
  end

 
  if (buttons & 16) > 0 then
    start_fade("menu")
    pause_cooldown = 0
    music(-1)
    _log("pause:quit")
  end
end

function get_mode_name()
  return ({"zen","normal","hard","insane"})[difficulty_preset] or "normal"
end

function get_pattern_name(p)
  return ({"convergence","scatter","zigzag","spiral","sweep","spread"})[p] or "normal"
end

function spawn_meteor()
 
 
  local mtype = 3
  local rand = rnd(100)

 
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

  local m={[1]={3,1.5,5},[2]={6,0.5,8},[3]={4,1,6}} local mt=m[mtype]
  local size,speed_mult,crad=mt[1],mt[2],mt[3]

 
  if difficulty_preset == 3 then
    speed_mult *= 1.2
  end

 
  local spawn_x, vx = rnd(112) + 8, 0
  local vy = (1 + rnd(1 + difficulty * 0.3)) * speed_mult
  local spawn_pattern = pattern_type
  local spiral_angle = 0
  local sweep_side = 0

 
  if pattern_type2 and rnd(1) < 0.5 then
    spawn_pattern = pattern_type2
  end

  if spawn_pattern == 1 then
   
    spawn_x = rnd(128)
    local center_dir = sgn(64 - spawn_x)
    vx = center_dir * 0.3
  elseif spawn_pattern == 2 then
   
    spawn_x = 56 + rnd(16)
    vx = (spawn_x - 64) / 20
  elseif spawn_pattern == 3 then
   
    spawn_x = rnd(112) + 8
   
  elseif spawn_pattern == 4 then
   
    spiral_angle = rnd(1)
    spawn_x = 64 + cos(spiral_angle) * 40
    vx = cos(spiral_angle + 0.25) * 0.8 
  elseif spawn_pattern == 5 then
   
    sweep_side = flr(rnd(2)) 
    if sweep_side == 0 then
      spawn_x = -8
      vx = 1.2
    else
      spawn_x = 136
      vx = -1.2
    end
  elseif spawn_pattern == 6 then
   
    spawn_x = 64
    vx = (rnd(1) - 0.5) * 1.5
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
    zigzag_phase = rnd(1), 
    spiral_angle = spiral_angle, 
    sweep_side = sweep_side 
  })

  _log("meteor_spawn:"..({[1]="fast",[2]="slow"}[mtype] or "normal"))
end

function spawn_powerup()
  local ptype = flr(rnd(3)) + 1
  add(powerups, {x=rnd(112)+8,y=rnd(100)+10,age=0,type=ptype})
  _log("powerup_spawn:"..({[1]="shield",[2]="slowtime",[3]="invincibility"}[ptype] or "shield"))
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

   
    p.vx *= 0.9
    p.vy *= 0.9

    if p.age >= p.max_age then
      del(particles, p)
    end
  end
end

function draw_particles()
  for p in all(particles) do
   
    local fade = 1 - (p.age / p.max_age)
    local s = p.size * fade
    if s > 0.5 then
      circfill(p.x, p.y, s, p.color)
    end
  end
end

function start_fade(target_state)
  fade_dir = 1
  next_state = target_state
  _log("fade_out_to:"..target_state)
end

function update_fade()
  if fade_dir == 1 then
    fade_alpha += 8
    if fade_alpha >= 128 then
      fade_alpha = 128
      fade_dir = -1
     
      if next_state then
        state = next_state
       
        if state == "gameover" then
          gameover_timer = 0
        end
        next_state = nil
        _log("state:"..state)
      end
    end
  elseif fade_dir == -1 then
    fade_alpha -= 8
    if fade_alpha <= 0 then
      fade_alpha = 0
      fade_dir = 0
    end
  end
end

function draw_fade()
  if fade_alpha > 0 then
   
    for i=0,fade_alpha,8 do
      local col = 0
      if i % 16 < 8 then col = 1 end
      rectfill(0, i, 127, i, col)
    end
  end
end

function add_score(points)
 
  local actual = flr(points * multiplier)
  score += actual

 
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
   
    local fade = 1 - (ft.age / ft.max_age)
    if fade > 0.3 then
      print(ft.text, ft.x - 4, ft.y, ft.color)
    end
  end
end

function boss_take_damage()
  boss_hp -= 1
  boss_dodges = 0
  _log("boss_damage:hp="..boss_hp)
  if boss_hp <= 0 then
    boss_defeats += 1
    boss_meteor = nil
    boss_active = false
    boss_attack_projectiles = {}
    add_score(500)
    shake_time = 20
    spawn_particles(64, 40, 30, 10, 3)
    sfx(5)
    _log("boss_defeated:total="..boss_defeats..":score="..score)
    multiplier = min(3, multiplier+0.5)
    add(float_texts, {x=64, y=30, text="boss defeated!", age=0, max_age=90, vy=-0.2, color=10})
  else
    shake_time = 15
    spawn_particles(boss_meteor.x, boss_meteor.y, 20, 9, 2)
    sfx(3)
    _log("boss_hp_lost:remaining="..boss_hp)
    add(float_texts, {x=boss_meteor.x, y=boss_meteor.y-10, text="hit!", age=0, max_age=40, vy=-0.4, color=8})
  end
end

function player_hit_by_boss(player_id)
  if combo > 0 then
    _log("combo_reset:"..combo)
    combo = 0
    combo_pulse = 0
  end
  if multiplier > 1 then
    _log("mult_reset:was="..multiplier)
    multiplier = 1
    last_mult_milestone = 1
    multiplier_pulse = 0
  end
  if shield_active then
    shield_active = false
    if player_id == 1 then invincible = 30 else p2_invincible = 30 end
    _log("shield_used:boss:p"..player_id)
  else
    lives -= 1
    if player_id == 1 then invincible = 60 else p2_invincible = 60 end
    _log("collision:boss_attack:p"..player_id..":lives="..lives)
  end
  shake_time = 20
  local hit_x = player_id == 1 and px or p2x
  local hit_y = player_id == 1 and py or p2y
  spawn_particles(hit_x, hit_y, 12, 8, 3)
  sfx(1)
  _log("sfx:boss_hit_player")
  if lives <= 0 then
    start_fade("gameover")
    survival_time = flr(t()-game_start_time)
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

function update_play()
 
  local buttons = test_input()

 
  if pause_cooldown > 0 then
    pause_cooldown -= 1
  end

 
  if (buttons & 32) > 0 and pause_cooldown == 0 then
    state = "pause"
    pause_cooldown = 15
    _log("pause")
    return
  end

 
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

 
  if coop_mode then
    local old_p2x = p2x
    local old_p2y = p2y
    local b2 = test_input2()
    if (b2 & 1) > 0 then p2x -= pspeed end
    if (b2 & 2) > 0 then p2x += pspeed end
    if (b2 & 4) > 0 then p2y -= pspeed end
    if (b2 & 8) > 0 then p2y += pspeed end
    p2x = mid(4, p2x, 120)
    p2y = mid(4, p2y, 120)
    if old_p2x != p2x or old_p2y != p2y then
      _log("move_p2:"..p2x..","..p2y)
    end
    if p2_invincible > 0 then p2_invincible -= 1 end
  end

 
  if invincible > 0 then invincible -= 1 end

 
  if slowtime > 0 then
    slowtime -= 1
    if slowtime == 0 then
      _log("slowtime:end")
    end
  end

 
  update_particles()

 
  update_float_texts()

 
  if combo_pulse > 0 then
    combo_pulse -= 1
  end

 
  if near_miss_pulse > 0 then
    near_miss_pulse -= 1
  end

 
  if multiplier_pulse > 0 then
    multiplier_pulse -= 1
  end

 
  if wave_border_pulse > 0 then
    wave_border_pulse -= 1
  end

 
  difficulty = 1 + flr(t() / 30)
  local base_rate = max(20, 60 - difficulty * 3)

 
  if difficulty_preset == 4 then
    base_rate = max(20, 40 - difficulty * 3) 
  end

 
  if coop_mode then
    base_rate = flr(base_rate * 0.85)
  end

 
  if difficulty > last_difficulty then
    sfx(3)
    _log("sfx:difficulty_up:"..difficulty)
    last_difficulty = difficulty
  end

 
  if difficulty_preset != 1 then
    wave_timer -= 1

    if wave_state == "idle" then
     
      if pattern_type != nil or pattern_type2 != nil then
        pattern_type = nil
        pattern_type2 = nil
        _log("pattern:normal")
      end

     
      if wave_timer <= 120 and wave_warning == 0 then
       
        wave_warning = 120
        sfx(3) 
        _log("wave_warning")
      end

      if wave_warning > 0 then
        wave_warning -= 1
      end

      if wave_timer <= 0 then
       
        wave_state = "active"
        wave_count += 1

       
        local survival = flr(t() - game_start_time)

       
        if difficulty_preset == 4 then
          if survival % 10 == 0 or wave_count % 2 == 0 then
            wave_intensity = 3 
          else
            wave_intensity = 2 
          end
        elseif survival >= 90 or wave_count >= 6 then
          wave_intensity = 3 
        elseif survival >= 60 or wave_count >= 4 then
          wave_intensity = 2 
        elseif survival >= 30 or wave_count >= 2 then
          wave_intensity = 1 
        else
          wave_intensity = 0 
        end

       
        wave_border_pulse = 30

       
        if difficulty_preset == 3 or difficulty_preset == 4 then
          wave_timer = 600 + rnd(300) 
        else
          wave_timer = 480 + rnd(240) 
        end

        wave_warning = 0

       
        local max_pattern = mid(1, 3 + flr(survival / 30), 6)
        pattern_type = flr(rnd(max_pattern)) + 1
        pattern_timer = 240 + rnd(120) 

       
        if difficulty_preset == 3 or difficulty_preset == 4 then
          pattern_type2 = flr(rnd(max_pattern)) + 1
         
          if pattern_type2 == pattern_type then
            pattern_type2 = (pattern_type % max_pattern) + 1
          end
          pattern_timer2 = 300 + rnd(120) 
          _log("wave_pattern:"..get_pattern_name(pattern_type).."+"..get_pattern_name(pattern_type2))
        else
          pattern_type2 = nil
          _log("wave_pattern:"..get_pattern_name(pattern_type))
        end

       
        if wave_intensity >= 3 then
          screen_flash = 15
        elseif wave_intensity >= 2 then
          screen_flash = 12
        elseif wave_intensity >= 1 then
          screen_flash = 8
        end

        sfx(3)
        _log("wave_start:"..wave_count..":intensity="..wave_intensity)
      end
    elseif wave_state == "active" then
     

     
      local survival = flr(t() - game_start_time)
      local max_pattern = mid(1, 3 + flr(survival / 30), 6)

      pattern_timer -= 1
      if pattern_timer <= 0 then
       
        pattern_type = flr(rnd(max_pattern)) + 1
        pattern_timer = 240 + rnd(120) 
        _log("wave_pattern:"..get_pattern_name(pattern_type))
      end

     
      if pattern_type2 then
        pattern_timer2 -= 1
        if pattern_timer2 <= 0 then
          pattern_type2 = flr(rnd(max_pattern)) + 1
         
          if pattern_type2 == pattern_type then
            pattern_type2 = (pattern_type % max_pattern) + 1
          end
          pattern_timer2 = 300 + rnd(120) 
          _log("wave_pattern2:"..get_pattern_name(pattern_type2))
        end
      end

     
      local boss_difficulty_req = (difficulty_preset == 3 or difficulty_preset == 4) and 1 or 2
      if not boss_active and wave_timer <= 180 and wave_timer > 170 and difficulty >= boss_difficulty_req then
        boss_active = true
        boss_warning = 60 
        sfx(3) 
        _log("boss_warning")
      end

     
      if boss_active and boss_warning > 0 then
        boss_warning -= 1
        if boss_warning == 0 then
          boss_meteor = {x=64, y=20, speed=0, vx=0, type=4, size=8, crad=12, zigzag_phase=0}
          boss_hp = 3
          boss_attack_timer = 90
          _log("boss_spawn:hp=3")
        end
      end

      if wave_timer <= 0 then
       
        wave_state = "idle"

       
        if difficulty_preset == 3 or difficulty_preset == 4 then
          wave_timer = 600 + rnd(300) 
        else
          wave_timer = 1200 + rnd(600) 
        end

        boss_active = false
        boss_meteor = nil
        boss_warning = 0
        pattern_type = nil
        pattern_type2 = nil
        _log("wave_end")
      end
    end
  end

 
  if wave_state == "active" then
   
    local wave_mult = max(0.3, 1 - difficulty * 0.1)
    meteor_rate = flr(base_rate * wave_mult)
  else
   
    meteor_rate = base_rate + 15
  end

 
  if t() - last_score_time >= 1 then
    add_score(1)
    last_score_time = t()
    if score % 10 == 0 then
      _log("score:"..score)
    end
  end

 
  meteor_timer -= 1
  if meteor_timer <= 0 then
    spawn_meteor()
    meteor_timer = meteor_rate
    sfx(0) 
    _log("sfx:meteor_spawn")
  end

 
  for m in all(meteors) do
   
    local speed = m.speed
    if slowtime > 0 then
      speed *= slowtime_mult
    end
    m.y += speed

   
    if m.vx then
      m.x += m.vx
    end

   
    if pattern_type == 3 or pattern_type2 == 3 then
     
      m.zigzag_phase += 0.02
      m.x += cos(m.zigzag_phase) * 1.5
    end

    if (pattern_type == 4 or pattern_type2 == 4) and m.spiral_angle then
     
      m.spiral_angle += 0.015
      m.vx = cos(m.spiral_angle + 0.25) * 0.8
    end


    if not m.near_player then
      local dist_p1 = sqrt((m.x - px) * (m.x - px) + (m.y - py) * (m.y - py))
      local near_p1 = dist_p1 < 20
      local near_p2 = coop_mode and sqrt((m.x - p2x) * (m.x - p2x) + (m.y - p2y) * (m.y - p2y)) < 20 or false
      if near_p1 or near_p2 then
        m.near_player = true
        if near_p1 and near_p2 then
          _log("near_both")
        elseif near_p1 then
          _log("near_p1")
        else
          _log("near_p2")
        end
      end
    end

   
    local tx, ty, nm = px, py, false
    if not m.near_miss_logged and invincible == 0 then
      local d = sqrt((m.x-px)*(m.x-px)+(m.y-py)*(m.y-py))
      if d >= 12 and d < 15 and m.y >= py-10 then
        m.near_miss_logged = true
        near_misses += 1
        nm = true
      end
    end
    if not nm and coop_mode and not m.near_miss_logged_p2 and p2_invincible == 0 then
      local d = sqrt((m.x-p2x)*(m.x-p2x)+(m.y-p2y)*(m.y-p2y))
      if d >= 12 and d < 15 and m.y >= p2y-10 then
        m.near_miss_logged_p2 = true
        p2_near_misses += 1
        tx, ty, nm = p2x, p2y, true
      end
    end

    if nm then

       
        local old_mult = flr(multiplier * 10) / 10
        local mult_cap = difficulty_preset == 4 and 4.0 or 3.0
        multiplier = min(mult_cap, multiplier + 0.2)
        local new_mult = flr(multiplier * 10) / 10
        multiplier_pulse = 10

       
        if multiplier > max_multiplier then
          max_multiplier = multiplier
          _log("max_mult:"..multiplier)
        end

       
        if new_mult > old_mult and new_mult > last_mult_milestone then
          local is_milestone = (new_mult == 1.5 or new_mult == 2.0 or new_mult == 3.0 or new_mult == 4.0 or new_mult == 5.0)
          if is_milestone then
           
            last_mult_milestone = new_mult
            sfx(2)
            _log("mult_milestone:"..new_mult)

            add(float_texts, {x=tx, y=ty-10, text=new_mult.."x multiplier!", age=0, max_age=60, vy=-0.3, color=10})
            screen_flash = 10
            shake_time = 12
            spawn_particles(tx, ty, 20, 10, 2.5)
          end
        end

        local points = add_score(10)
        near_miss_pulse = 5
        _log("near_miss:mult="..multiplier..":score="..score)

       
        spawn_particles(m.x, m.y, 8, 10, 1.5)

       
        shake_time = 5

        add(float_texts, {x=m.x, y=m.y, text="+"..points, age=0, max_age=30, vy=-0.5, color=10})
        sfx(2)
        _log("sfx:near_miss")
      end
    end

   
    local p1_hit = invincible == 0 and abs(m.x - px) < m.crad and abs(m.y - py) < m.crad

   
    local p2_hit = coop_mode and p2_invincible == 0 and abs(m.x - p2x) < m.crad and abs(m.y - p2y) < m.crad

    if p1_hit or p2_hit then
      if combo > 0 then
        _log("combo_reset:"..combo)
        combo, combo_pulse = 0, 0
      end
      if multiplier > 1 then
        _log("mult_reset:was="..multiplier)
        multiplier, last_mult_milestone, multiplier_pulse = 1, 1, 0
      end
      if shield_active then
        shield_active = false
        if p1_hit then invincible = 30 else p2_invincible = 30 end
        _log("shield_used")
      else
        lives -= 1
        if p1_hit then invincible = 60 else p2_invincible = 60 end
        _log("collision:"..(p1_hit and "p1" or "p2")..":lives="..lives)
      end
      shake_time = 15
      local pc = m.type == 2 and 12 or 8
      spawn_particles(m.x, m.y, 5, pc, 2)
      del(meteors, m)
      sfx(1)
      _log("sfx:collision")

      if lives <= 0 then
        start_fade("gameover")
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

   
    if m.y > 136 then
      if m.near_player and t() - last_combo_time >= 1 then
        combo += 1
        last_combo_time = t()
        combo_pulse = 10
        _log("dodge:combo="..combo)

       
        if combo > max_combo then
          max_combo = combo
          _log("max_combo:"..max_combo)
        end

       
        if combo == 10 or combo == 25 or combo == 50 or combo == 100 then
          local bonus = combo * 10
          add_score(bonus)
          _log("combo_bonus:"..combo.."="..bonus)
        end

       
        if combo % 10 == 0 then
          sfx(3)
          _log("sfx:combo_milestone:"..combo)
        end
      end
      del(meteors, m)
    end
  end

 
  if boss_meteor then
   
    boss_meteor.zigzag_phase += 0.02
    boss_meteor.x = 64 + sin(boss_meteor.zigzag_phase) * 40

   
    if boss_attack_warning > 0 then
      boss_attack_warning -= 1
      if boss_attack_warning == 0 then
        _log("boss_attack:"..boss_attack_type)
        if boss_attack_type == 1 then
          for i=0,7 do
            local a=i/8
            add(boss_attack_projectiles, {x=boss_meteor.x, y=boss_meteor.y, speed=0.8+sin(a)*0.2, vx=cos(a)*1.2})
          end
        else
          local dx,dy=px-boss_meteor.x, py-boss_meteor.y
          local d=sqrt(dx*dx+dy*dy)
          if d == 0 then d = 0.1 end
          local vx,vy=dx/d*0.8, dy/d*1.5
          for i=0,4 do
            add(boss_attack_projectiles, {x=boss_meteor.x+vx*i*8, y=boss_meteor.y+vy*i*8, speed=vy, vx=vx})
          end
        end
        if boss_attack_type > 0 then sfx(boss_attack_type-1) end
        boss_attack_timer = boss_hp==3 and 180 or boss_hp==2 and 120 or 90
        boss_attack_type = 0
      end
    elseif boss_attack_timer > 0 then
      boss_attack_timer -= 1
      if boss_attack_timer == 0 then
        boss_attack_type = flr(rnd(2)) + 1
        boss_attack_warning = 60
        _log("boss_attack_warning:type="..boss_attack_type)
        sfx(3)
      end
    end

   
    if invincible == 0 and abs(boss_meteor.x-px) < boss_meteor.crad and abs(boss_meteor.y-py) < boss_meteor.crad then
      player_hit_by_boss(1)
    end
   
    if coop_mode and p2_invincible == 0 and abs(boss_meteor.x-p2x) < boss_meteor.crad and abs(boss_meteor.y-p2y) < boss_meteor.crad then
      player_hit_by_boss(2)
    end
  end

  for p in all(boss_attack_projectiles) do
    p.y += p.speed
    if p.vx then p.x += p.vx end

   
    local p1_boss_hit = invincible == 0 and abs(p.x-px) < 8 and abs(p.y-py) < 8
   
    local p2_boss_hit = coop_mode and p2_invincible == 0 and abs(p.x-p2x) < 8 and abs(p.y-p2y) < 8

    if p1_boss_hit then
      player_hit_by_boss(1)
      del(boss_attack_projectiles, p)
    elseif p2_boss_hit then
      player_hit_by_boss(2)
      del(boss_attack_projectiles, p)
    elseif p.y > 136 then
      multiplier = min(difficulty_preset==4 and 4 or 3, multiplier+0.1)
      if multiplier > max_multiplier then max_multiplier = multiplier end
      spawn_particles(px, py, 8, 10, 1.5)
      add(float_texts, {x=px, y=py-8, text="+"..add_score(50), age=0, max_age=30, vy=-0.5, color=10})
      _log("boss_dodge")
      boss_dodges += 1
      if boss_dodges >= 3 then boss_take_damage() end
      del(boss_attack_projectiles, p)
    elseif p.y < -12 or p.x < -12 or p.x > 140 then
      del(boss_attack_projectiles, p)
    end
  end

 
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

 
  for s in all(stars) do
    s.age += 1

   
    local p1_star = abs(s.x - px) < 6 and abs(s.y - py) < 6
    local p2_star = coop_mode and abs(s.x - p2x) < 6 and abs(s.y - p2y) < 6

    if p1_star or p2_star then
      add_score(50)
      total_stars += 1

     
      spawn_particles(s.x, s.y, 6, 10, 1.5)

      del(stars, s)
      sfx(2) 
      _log("sfx:star_pickup")
      _log("pickup:star:total="..total_stars)
    end

   
    if s.age > 300 then
      del(stars, s)
    end
  end

 
  if t() > 10 then
    powerup_timer -= 1
    if powerup_timer <= 0 then
      spawn_powerup()
      powerup_timer = 180 + rnd(300) 
    end
  end

 
  for p in all(powerups) do
    p.age += 1

   
    local p1_powerup = abs(p.x - px) < 6 and abs(p.y - py) < 6
    local p2_powerup = coop_mode and abs(p.x - p2x) < 6 and abs(p.y - p2y) < 6

    if p1_powerup or p2_powerup then
      local points = add_score(25)
      total_powerups += 1

      local trigger_x = p1_powerup and px or p2x
      local trigger_y = p1_powerup and py or p2y

      local pn, pc, ps = "", 12, 5
      if p.type == 1 then
        shield_active = true
        pn, pc, ps = "shield!", 12, 2
        _log("pickup:shield")
      elseif p.type == 2 then
        slowtime = 480
        pn, pc, ps = "slowtime!", 12, 3
        _log("pickup:slowtime:480")
      elseif p.type == 3 then
        if p1_powerup then invincible = invincible > 0 and invincible+300 or 300 end
        if p2_powerup then p2_invincible = p2_invincible > 0 and p2_invincible+300 or 300 end
        pn, pc, ps = "invincible!", 10, 5
        _log("pickup:invincibility")
      end
      spawn_particles(trigger_x, trigger_y, 18, pc, 3)
      add(float_texts, {x=trigger_x, y=trigger_y, text=pn, age=0, max_age=40, vy=-0.8, color=pc})
      add(float_texts, {x=trigger_x, y=trigger_y-8, text="+"..points, age=0, max_age=30, vy=-0.5, color=10})
      shake_time = 8

     
      sfx(ps)

      del(powerups, p)
      _log("sfx:powerup_"..pn)
      _log("pickup:powerup:total="..total_powerups..":bonus="..points)
    end

   
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
  if boss_defeats >= 1 then
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
  gameover_timer += 1

 
  if not achievements_logged then
    for a in all(achievements) do
      _log("achievement:"..a.text)
    end
    achievements_logged = true
  end

 
  if gameover_timer == 1 then
    save_to_leaderboard(difficulty_preset, score, survival_time)
  end

 
  if gameover_timer == 1 and not insane_unlocked and difficulty_preset == 2 and score >= 5000 then
    insane_unlocked = true
    just_unlocked_insane = true
    dset(2, 1) 
    screen_flash = 20
    shake_time = 15
    sfx(5) 
    _log("unlock:insane_mode")
  end

  if (test_input() & 16) > 0 then
    sfx(4) 
    _log("sfx:ui_select")
    start_fade("menu")
    just_unlocked_insane = false 
    music(0) 
    _log("music:menu")
  end
end

function draw_menu()
  print("meteor dodge", 32, 40, 7)
  print("avoid the meteors!", 20, 55, 6)

 
  print("mode:", 46, 58, 13)

 
  local modes={{"zen",10,2},{" normal",36,28},{" hard",74,66},{" insane",102,94}}
  for i,m in pairs(modes) do
    local c=difficulty_preset==i and 10 or (i==4 and (insane_unlocked and 5 or 2) or 5)
    print(m[1],m[2],66,c)
    if difficulty_preset==i then print("\151",m[3],66,10)end
  end
  if not insane_unlocked then print("[locked]",98,74,2)end

  if not insane_unlocked then
    print("unlock: 5k norm", 28, 84, 13)
  else
    print("arrows: select", 26, 84, 6)
  end

 
  print("\136: "..(coop_mode and "co-op" or "solo"),38,92,coop_mode and 10 or 6)

  print("z: start", 42, 98, 11)
  print("x: help", 42, 106, 13)
  print("\139: leaderboard", 32, 114, 10)

 
 
  circfill(50, 20, 3, 8)
  circfill(50, 20, 1, 2)
 
  circfill(64, 20, 4, 8)
  circfill(64, 20, 2, 2)
 
  circfill(82, 20, 6, 12)
  circfill(82, 20, 4, 1)
end

function draw_tutorial()
 
  for s in all(stars_bg) do
    local c = s.bright == 1 and 6 or 5
    pset(s.x, s.y, c)
  end

 
  print("page "..(tutorial_page+1).."/3", 44, 4, 6)

  if tutorial_page == 0 then
    print("how to play", 34, 14, 7)
    print("controls:", 4, 26, 11)
    print("arrows: move", 4, 34, 6)
    print("z: select", 4, 42, 6)
    print("x: pause", 4, 50, 6)
    print("objective:", 4, 62, 11)
    print("dodge meteors!", 4, 70, 6)
    print("survive!", 4, 78, 6)
    print("score:", 4, 90, 11)
    print("near-miss: +10", 4, 98, 10)
    print("combo bonus!", 4, 106, 10)

  elseif tutorial_page == 1 then
    print("difficulty", 38, 14, 7)
    print("zen: relaxed", 4, 26, 10)
    print("normal: balanced", 4, 34, 11)
    print("hard: fast waves", 4, 42, 8)
    print("insane: unlock", 4, 50, 9)
    print("via normal 5k+", 4, 58, 13)
    print("multiplier:", 4, 74, 11)
    print("near-miss boost", 4, 82, 6)
    print("max: 3x-4x", 4, 90, 10)

  elseif tutorial_page == 2 then
    print("power-ups", 36, 14, 7)
    rectfill(4, 26, 12, 34, 11)
    print("shield", 18, 28, 11)
    print("blocks 1 hit", 18, 36, 6)
    rectfill(4, 46, 12, 54, 14)
    print("slow-time", 18, 48, 14)
    print("slows meteors", 18, 56, 6)
    rectfill(4, 66, 12, 74, 10)
    print("invincible", 18, 68, 10)
    print("immune", 18, 76, 6)
    print("waves:", 4, 88, 11)
    print("meteor patterns", 4, 96, 6)
    print("+ boss fights!", 4, 104, 8)
  end

 
  print("up/down: change page", 14, 122, 13)
end

function update_leaderboard()
  local buttons = test_input()

 
  if (buttons & 1) > 0 and leaderboard_view_mode > 1 then
    leaderboard_view_mode -= 1
    sfx(4)
    _log("leaderboard_view:"..get_diff_name(leaderboard_view_mode))
  elseif (buttons & 2) > 0 and leaderboard_view_mode < 4 then
    leaderboard_view_mode += 1
    sfx(4)
    _log("leaderboard_view:"..get_diff_name(leaderboard_view_mode))
  end

 
  if (buttons & 32) > 0 then
    sfx(4)
    _log("sfx:ui_select")
    state = "menu"
    _log("state:menu")
  end
end

function draw_leaderboard()
 
  for s in all(stars_bg) do
    local c = s.bright == 1 and 6 or 5
    pset(s.x, s.y, c)
  end

 
  print("leaderboards", 32, 8, 7)

 
  local tab_x = {6, 38, 72, 98}
  local tab_names = {"zen", "norm", "hard", "insn"}
  for i=1,4 do
    local col = leaderboard_view_mode == i and 10 or 5
    print(tab_names[i], tab_x[i], 18, col)
    if leaderboard_view_mode == i then
      print("\139", tab_x[i] - 2, 26, 10) 
    end
  end

 
  local board = leaderboards[leaderboard_view_mode] or {}
  print(get_diff_name(leaderboard_view_mode).." mode", 36, 36, 11)

  if #board == 0 then
    print("no scores yet!", 28, 64, 6)
  else
    for i=1,#board do
      local entry = board[i]
      local y = 46 + i * 12

     
      local rc=({{10},{10},{9},{8}})[i] or {6}
      print(i..".",8,y,rc[1])
      local sc=entry.score>=10000 and 10 or entry.score>=5000 and 11 or entry.score>=2000 and 12 or 6
      print(entry.score,22,y,sc)

     
      local mins = flr(entry.time / 60)
      local secs = flr(entry.time % 60)
      local time_str = mins.."m"..secs.."s"
      print(time_str, 70, y, 13)

     
      if entry.score >= 5000 then
        print("\139", 118, y, 10)
      end
    end
  end

 
  print("arrows: switch mode", 14, 116, 13)
  print("x: return to menu", 18, 124, 13)
end

function get_diff_name(d)
  return ({"zen","normal","hard","insane"})[d] or "insane"
end

function draw_pause()
 
  for i=0,20 do
    local sx = (i * 37) % 128
    local sy = (i * 53 + t() * 10) % 128
    pset(sx, sy, 5)
  end

 
  for m in all(meteors) do
    local mc=m.type==1 and 8 or m.type==2 and 12 or 6
    circfill(m.x,m.y,m.size,mc)
    circfill(m.x,m.y,m.size-2,2)
  end

 
  for s in all(stars) do
    local pulse = 1 + sin(t() * 2 + s.x / 20) * 0.5
    for i=0,3 do
      local angle = i / 4 + t() * 0.1
      local px = s.x + cos(angle) * 3 * pulse
      local py = s.y + sin(angle) * 3 * pulse
      circfill(px, py, 1, 10)
    end
  end

 
  local pc=invincible>0 and invincible%8<4 and 10 or 7
  circfill(px,py,3,pc)
  circfill(px-1,py-1,1,12)
  if coop_mode then
    circfill(p2x,p2y,3,p2_invincible>0 and p2_invincible%8<4 and 9 or 7)
    circfill(p2x-1,p2y-1,1,8)
  end
  for y=0,127 do for x=(y%2),127,2 do pset(x,y,0)end end

 
  print("paused", 44, 30, 7)

 
  local survival = flr(survival_time)
  print("score: "..score, 36, 50, 11)
  print("time: "..survival.."s", 36, 58, 11)

  if combo > 0 then
    print("combo: "..combo.."x", 34, 66, 10)
  end

 
  print("x to resume", 32, 86, 6)
  print("z to quit to menu", 18, 94, 6)
end

function draw_play()
 
  for s in all(stars_bg) do pset(s.x,s.y,s.bright==1 and 1 or 0)end
  for i=0,20 do pset(i*37%128,i*53+t()*10%128,5)end

 
  if wave_warning>0 and flr(wave_warning/8)%2==0 then
    rect(0,0,127,127,8)
    rect(1,1,126,126,8)
  end

 
  if wave_border_pulse>0 then
    local ps=wave_border_pulse/6
    local col=wave_intensity>=3 and 8 or wave_intensity>=2 and 9 or 10
    rect(0,0,127,127,col)
    if ps>2 then rect(1,1,126,126,col)end
  end

 
  if wave_state=="active" then
    local wt=({"wave "..wave_count,"wave "..wave_count,"danger!","critical!"})[wave_intensity+1] or "wave "..wave_count
    local ic=({{10},{10},{9},{8}})[wave_intensity+1] or {10}
    local pc=ic[1]+(wave_intensity>=2 and (flr(t()*8)%2)*-1 or 0)
    print(wt,2,14,pc)
    local pt=get_pattern_name(pattern_type)..(pattern_type2 and "+"..get_pattern_name(pattern_type2) or "")
    print(pt,2,120,7)
  end

 
  draw_player(px,py,invincible,invincible>54 and 7 or 12,invincible>54 and 7 or 7,invincible>54 and 7 or 10)
  if coop_mode then
    draw_player(p2x,p2y,p2_invincible,p2_invincible>54 and 7 or 9,p2_invincible>54 and 7 or 7,p2_invincible>54 and 7 or 8)
  end

 
  if near_miss_pulse > 0 then
    local pulse_size = (5 - near_miss_pulse) * 1.5
    circ(px, py, 4 + pulse_size, 10)
    circ(px, py, 5 + pulse_size, 9)
  end

 
  if shield_active then
    local ro=t()*4%8
    circ(px,py,5+ro*0.2,12)
    if coop_mode then circ(p2x,p2y,5+ro*0.2,12)end
  end

 
  for m in all(meteors) do
    local col1,col2=m.type==2 and 12 or 8,m.type==2 and 1 or 2
    for i=1,3 do
      if m.size-i*0.5>0 then circ(m.x,m.y-i*2,m.size-i*0.5,col2)end
    end
    circfill(m.x,m.y,m.size,col1)
    circfill(m.x,m.y,m.size-2,col2)
    circfill(m.x-1,m.y-1,1,5)
  end

 
  if boss_meteor then
    local oc,mc,cc=({[1]={8,2,14},[2]={9,8,2},[3]={10,9,7}})[boss_hp] or {8,2,14}
    local pulse=sin(t()*2)*2
    circ(boss_meteor.x,boss_meteor.y,boss_meteor.size+2+pulse,oc)
    circ(boss_meteor.x,boss_meteor.y,boss_meteor.size+4+pulse,mc)
    circfill(boss_meteor.x,boss_meteor.y,boss_meteor.size,oc)
    circfill(boss_meteor.x,boss_meteor.y,boss_meteor.size-2,mc)
    circfill(boss_meteor.x,boss_meteor.y,boss_meteor.size-4,cc)
    circfill(boss_meteor.x-1,boss_meteor.y-1,2,cc)
  end

 
  for p in all(boss_attack_projectiles) do
    circfill(p.x, p.y, 3, 8)
    circfill(p.x, p.y, 2, 9)
    circfill(p.x, p.y, 1, 10)
  end

 
  if boss_warning>0 then
    print("boss!",50,10,8+flr(t()*8)%2)
  elseif boss_meteor then
    rect(32,10,96,14,5)
    if boss_hp>0 then
      rectfill(33,11,32+flr(boss_hp/3*64),13,boss_hp==3 and 10 or boss_hp==2 and 9 or 8)
    end
    if boss_attack_warning>0 then
      local an=({"ring!","beam!"})[boss_attack_type] or ""
      print(an,48,18,8+flr(boss_attack_warning/8)%2)
    end
  end

 
  for s in all(stars) do
    draw_star(s.x, s.y)
  end

 
  for p in all(powerups) do
    draw_powerup(p.x, p.y, p.type)
  end

 
  draw_particles()

 
  draw_float_texts()

 
  print("score:"..score, 2, 2, 7)
  print("hi:"..highscore, 2, 8, 10)

 
  if combo>0 then
    local ct="x"..combo
    local cy=2-(combo_pulse>0 and flr(combo_pulse/5) or 0)
    local cc=combo>=50 and 8 or combo>=25 and 9 or combo>=10 and 10 or 7
    print(ct,127-#ct*4,cy,cc)
  end
  if multiplier>1.0 then
    local mt=flr(multiplier*10)/10.."x"
    local my=2-(multiplier_pulse>0 and flr(multiplier_pulse/3) or 0)
    local mc=multiplier>=5.0 and 8 or multiplier>=3.0 and 9 or 10
    if multiplier_pulse>0 then print(mt,64-#mt*2+1,my+1,1)end
    print(mt,64-#mt*2,my,mc)
  end

 
  for i=1,lives do
    circfill(125 - i * 8, 13, 2, 8)
  end

 
  if slowtime > 0 then
    print("slow", 2, 120, 14)
  end

 
  if boss_active and boss_dodges > 0 then
    print("hits:"..boss_dodges.."/3", 2, 114, 10)
  end
end

function draw_gameover()
 
  local title_col = 8
  if score >= 10000 then
    title_col = 8 + (flr(gameover_timer / 4) % 2)
  end
  print("game over!", 36, 4, title_col)

 
  if gameover_timer>=0 then
    local sc=score>=10000 and 12 or score>=5000 and 10 or 7
    print("final score:",30,14,7)
    print(score,64-#tostr(score)*2,20,sc)
    if score==highscore and score>0 then print("new high score!",28,28,10)end
  end

 
  if gameover_timer >= 8 then
    print("--- stats ---", 32, 38, 13)
  end

  local y = 46
  local spacing = 6

 
  if gameover_timer>=12 then
    local tc=survival_time>=120 and 12 or survival_time>=60 and 10 or survival_time>=30 and 9 or 6
    print("\139 time:"..survival_time.."s",3,y,tc)
    y+=spacing
  end
  if gameover_timer>=15 then
    local cc=max_combo>=100 and 12 or max_combo>=50 and 10 or max_combo>=25 and 9 or 6
    print("\148 combo:x"..max_combo,3,y,cc)
    y+=spacing
  end
  if gameover_timer>=18 then
    local mc=max_multiplier>=5.0 and 12 or max_multiplier>=3.0 and 10 or max_multiplier>=2.0 and 9 or 6
    print("\151 mult:"..flr(max_multiplier*10)/10.."x",3,y,mc)
    y+=spacing
  end
  if gameover_timer>=21 then
    local wc=wave_count>=10 and 12 or wave_count>=6 and 10 or wave_count>=3 and 9 or 6
    print("\131 waves:"..wave_count,3,y,wc)
    y+=spacing
  end

 
  if gameover_timer>=24 then
    local sc=total_stars>=20 and 12 or total_stars>=10 and 10 or total_stars>=5 and 9 or 6
    print("\143 stars:"..total_stars,3,y,sc)
    y+=spacing
  end
  if gameover_timer>=27 then
    local pc=total_powerups>=10 and 12 or total_powerups>=5 and 10 or total_powerups>=3 and 14 or 6
    print("\014 power:"..total_powerups,3,y,pc)
    y+=spacing
  end
  if gameover_timer>=30 then
    local bc=boss_defeats>=3 and 12 or boss_defeats>=2 and 10 or boss_defeats>=1 and 8 or 6
    print("\007 bosses:"..boss_defeats,3,y,bc)
  end

 
  if coop_mode and gameover_timer>=33 then
    y+=spacing
    print("--- co-op ---",32,y,13)
    print("p1:"..near_misses.." p2:"..p2_near_misses,3,y+spacing+2,10)
  end
  if just_unlocked_insane and gameover_timer>=10 then
    print("unlocked:",38,88,7)
    print("insane mode!",30,96,10+(flr(gameover_timer/8)%2))
  end

 
  local ach_start = just_unlocked_insane and 104 or 35
  if gameover_timer >= ach_start and #achievements > 0 then
    local ach_y = 96
    if just_unlocked_insane then ach_y = 104 end
    print("achievements:", 26, ach_y, 7)
    ach_y += 8
    for i, a in pairs(achievements) do
     
      if gameover_timer >= ach_start + (i * 3) then
        print("\151 "..a.text, 20, ach_y, a.col)
      end
      ach_y += 6
    end
  end

 
  local prompt_col = 11 + (flr(gameover_timer / 15) % 2)
  print("press z to retry", 22, 118, prompt_col)
end

function draw_player(px,py,inv,bc,ic,cc)
  if inv==0 or inv%4<2 then
    circfill(px,py,3,bc)circfill(px,py,2,ic)circfill(px,py-1,1,cc)
    pset(px-3,py+1,6)pset(px+3,py+1,6)
  end
end

function draw_star(x, y)
 
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
  local c, border_c, glow_c

  if ptype == 1 then
   
    c = 12
    border_c = 1
    glow_c = 6
  elseif ptype == 2 then
   
    c = 14
    border_c = 2
    glow_c = 13
  else
   
    c = 10
    border_c = 9
    glow_c = 9
  end

 
  local pulse = 1 + sin(t() * 4) * 0.5
  local glow_radius = 5 + pulse * 2
  circ(x, y, glow_radius, glow_c)
  circ(x, y, glow_radius - 1, glow_c)

 
  for i=0,3 do
    local a = (i / 4 + spin) % 1
    local dx = cos(a) * 4
    local dy = sin(a) * 4
    line(x, y, x + dx, y + dy, c)
  end

 
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
