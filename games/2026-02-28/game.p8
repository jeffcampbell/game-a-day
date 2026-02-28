pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- neon-slinger
-- top-down shooter

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0
test_inputsp = {}
test_inputp_idx = 0

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

function test_inputp(b)
  if testmode and test_inputp_idx < #test_inputsp then
    test_inputp_idx += 1
    return test_inputsp[test_inputp_idx] or 0
  end
  return btnp(b)
end

-- globals
state = "menu"
score = 0
high_score = 0
wave = 0
combo = 0
enemies_killed = 0
time_survived = 0
start_time = 0
shake_frames = 0
shake_intensity = 0

-- achievement tracking
boss_kills = 0
best_combo = 0
best_combo_session = 0
last_milestone = 0
milestone_texts = {}
flash_timer = 0

-- tiered achievement system
achievements = {} -- all-time unlocked (bitfield)
session_achievements = {} -- unlocked this session
powerups_collected = {} -- track power-ups this run
quick_kill_flag = false -- track boss kill in phase 1

-- achievement definitions
achievement_defs = {
  {id=1, name="first blood", desc="defeat first enemy", check=function() return enemies_killed >= 1 end},
  {id=2, name="slinger", desc="reach wave 5", check=function() return wave >= 5 end},
  {id=3, name="wave veteran", desc="reach wave 10", check=function() return wave >= 10 end},
  {id=4, name="endurance", desc="survive 60s", check=function() return time_survived >= 60 end},
  {id=5, name="sharpshooter", desc="kill 50 enemies", check=function() return enemies_killed >= 50 end},
  {id=6, name="demolition", desc="kill 100 enemies", check=function() return enemies_killed >= 100 end},
  {id=7, name="combo king", desc="25-hit combo", check=function() return combo >= 25 end},
  {id=8, name="unstoppable", desc="50-hit combo", check=function() return combo >= 50 end},
  {id=9, name="boss slayer", desc="defeat a boss", check=function() return boss_kills >= 1 end},
  {id=10, name="quick kill", desc="kill boss in phase 1", check=function() return quick_kill_flag end},
  {id=11, name="time master", desc="survive 180s", check=function() return time_survived >= 180 end},
  {id=12, name="arsenal master", desc="collect all 4 power-ups", check=function()
    return powerups_collected["RR"] and powerups_collected["BS"] and powerups_collected["SH"] and powerups_collected["2X"]
  end}
}

-- player
player = {}
-- enemies, projectiles, powerups, particles
enemies = {}
projectiles = {}
powerups = {}
particles = {}

-- power-up timers
rapid_fire_t = 0
big_shot_t = 0
score_mult_t = 0

-- direction vectors (8-way)
dirs = {
  {1,0},   -- 0: right
  {0.7,0.7}, -- 1: down-right
  {0,1},   -- 2: down
  {-0.7,0.7}, -- 3: down-left
  {-1,0},  -- 4: left
  {-0.7,-0.7}, -- 5: up-left
  {0,-1},  -- 6: up
  {0.7,-0.7}  -- 7: up-right
}

function _init()
  _log("init")
  cartdata("neon-slinger-v1")
  load_achievements()
  init_menu()
end

-- achievement system
function load_achievements()
  -- load achievements from cartdata (3 slots for 12 bits)
  local a1 = dget(3) or 0
  local a2 = dget(4) or 0
  local a3 = dget(5) or 0

  achievements = {}
  -- decode bitfield (12 achievements)
  for i=1,12 do
    local slot = i <= 4 and a1 or (i <= 8 and a2 or a3)
    local bit = ((i - 1) % 4)
    if slot & (1 << bit) > 0 then
      achievements[i] = true
    end
  end

  _log("loaded_achievements:"..count_achievements())
end

function save_achievements()
  -- encode achievements into 3 slots (4 bits each)
  local a1, a2, a3 = 0, 0, 0

  for i=1,12 do
    if achievements[i] then
      local bit = (i - 1) % 4
      if i <= 4 then
        a1 = a1 | (1 << bit)
      elseif i <= 8 then
        a2 = a2 | (1 << bit)
      else
        a3 = a3 | (1 << bit)
      end
    end
  end

  dset(3, a1)
  dset(4, a2)
  dset(5, a3)
  _log("saved_achievements:"..count_achievements())
end

function check_achievements()
  for _, def in pairs(achievement_defs) do
    if not achievements[def.id] and def.check() then
      unlock_achievement(def.id)
    end
  end
end

function unlock_achievement(id)
  achievements[id] = true
  session_achievements[id] = true
  _log("achievement:"..id)

  -- visual feedback
  sfx(6)
  shake_frames = 2
  shake_intensity = 0.5

  -- floating text
  add(milestone_texts, {
    text = "achievement!",
    y = 50,
    life = 40,
    col = 12
  })
end

function count_achievements()
  local count = 0
  for i=1,12 do
    if achievements[i] then count += 1 end
  end
  return count
end

function count_session_achievements()
  local count = 0
  for i=1,12 do
    if session_achievements[i] then count += 1 end
  end
  return count
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
  cls(0)
  if state == "menu" then
    draw_menu()
  elseif state == "play" then
    draw_play()
  elseif state == "pause" then
    draw_pause()
  elseif state == "gameover" then
    draw_gameover()
  end
end

-- menu state
function init_menu()
  state = "menu"
  _log("state:menu")
  high_score = dget(0)
  boss_kills = dget(1)
  best_combo = dget(2)
  music(0) -- menu theme
  _log("music:menu")
end

function update_menu()
  local input = test_input()
  if input & 16 > 0 then -- O button
    init_play()
  end
end

function draw_menu()
  -- title
  print("neon-slinger", 32, 40, 11)
  print("press o to start", 24, 60, 7)
  print("high score: "..high_score, 24, 80, 10)

  -- achievements
  local ach_count = count_achievements()
  print("achievements: "..ach_count.."/12", 20, 90, 12)

  -- controls
  print("l/r: rotate", 32, 100, 6)
  print("o: shoot", 36, 108, 6)
  print("x: dash", 36, 116, 6)
end

-- play state
function init_play()
  state = "play"
  _log("state:play")

  score = 0
  wave = 0
  combo = 0
  enemies_killed = 0
  start_time = time()

  -- reset achievement tracking
  best_combo_session = 0
  last_milestone = 0
  milestone_texts = {}
  flash_timer = 0
  session_achievements = {}
  powerups_collected = {}
  quick_kill_flag = false

  -- reset collections
  enemies = {}
  projectiles = {}
  powerups = {}
  particles = {}

  -- reset power-ups
  rapid_fire_t = 0
  big_shot_t = 0
  score_mult_t = 0

  -- init player
  player = {
    x = 64,
    y = 64,
    rot = 0, -- 0-7
    lives = 3,
    dash_cd = 0,
    invuln = 0,
    shoot_cd = 0,
    has_shield = false
  }

  music(1) -- gameplay theme
  _log("music:gameplay")
  spawn_wave()
end

function update_play()
  -- check for pause (X button press)
  if test_inputp(5) then
    init_pause()
    return
  end

  local input = test_input()

  -- update timers
  time_survived = flr(time() - start_time)

  -- update shake
  if shake_frames > 0 then
    shake_frames -= 1
  end

  -- power-up decay
  if rapid_fire_t > 0 then rapid_fire_t -= 1 end
  if big_shot_t > 0 then big_shot_t -= 1 end
  if score_mult_t > 0 then score_mult_t -= 1 end

  -- player input
  if player.invuln > 0 then
    player.invuln -= 1
  end

  if player.dash_cd > 0 then
    player.dash_cd -= 1
  end

  if player.shoot_cd > 0 then
    player.shoot_cd -= 1
  end

  -- rotation
  if input & 1 > 0 then -- left
    player.rot = (player.rot - 1) % 8
    _log("rot:"..player.rot)
  end
  if input & 2 > 0 then -- right
    player.rot = (player.rot + 1) % 8
    _log("rot:"..player.rot)
  end

  -- shoot
  if input & 16 > 0 and player.shoot_cd == 0 then
    local fire_rate = rapid_fire_t > 0 and 4 or 8
    player.shoot_cd = fire_rate
    shoot_player()
  end

  -- dash
  if input & 32 > 0 and player.dash_cd == 0 then
    player.dash_cd = 60 -- 1 second cooldown
    player.invuln = 10 -- brief invuln
    dash_player()
  end

  -- update enemies
  for e in all(enemies) do
    update_enemy(e)
  end

  -- update projectiles
  for p in all(projectiles) do
    update_projectile(p)
  end

  -- update powerups
  for pu in all(powerups) do
    pu.y += 0.3
    if dist(player.x, player.y, pu.x, pu.y) < 6 then
      collect_powerup(pu)
      del(powerups, pu)
    end
    if pu.y > 140 then
      del(powerups, pu)
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

  -- update milestone effects
  if flash_timer > 0 then
    flash_timer -= 1
  end

  for mt in all(milestone_texts) do
    mt.y -= 0.5
    mt.life -= 1
    if mt.life <= 0 then
      del(milestone_texts, mt)
    end
  end

  -- wave progression
  if #enemies == 0 and enemies_killed > 0 then
    add_score(100)
    _log("wave_complete:"..wave)
    shake_frames = 2
    shake_intensity = 1
    spawn_wave()
  end

  -- check achievements
  check_achievements()

  -- game over check
  if player.lives <= 0 then
    init_gameover()
  end
end

function shoot_player()
  _log("shoot")
  sfx(0)

  local dir = dirs[player.rot + 1]
  local size = big_shot_t > 0 and 2 or 1

  add(projectiles, {
    x = player.x + dir[1] * 8,
    y = player.y + dir[2] * 8,
    vx = dir[1] * 3,
    vy = dir[2] * 3,
    owner = "player",
    size = size,
    dmg = big_shot_t > 0 and 2 or 1
  })
end

function dash_player()
  _log("dash")
  sfx(3)

  local dir = dirs[player.rot + 1]
  player.x += dir[1] * 15
  player.y += dir[2] * 15

  -- clamp to arena
  player.x = mid(8, player.x, 120)
  player.y = mid(8, player.y, 120)

  -- damage nearby enemies
  for e in all(enemies) do
    if dist(player.x, player.y, e.x, e.y) < 12 then
      damage_enemy(e, 1)
    end
  end
end

function update_enemy(e)
  -- boss special attacks (heavy enemies)
  if e.type == "heavy" then
    update_boss_attacks(e)
  end

  -- handle dashing
  if e.dashing then
    e.dash_timer -= 1
    if e.dash_timer <= 0 then
      e.dashing = false
      e.speed = 0.3 -- restore normal speed
      _log("boss_dash_end")
    else
      -- continue dash movement
      local dx = e.dash_target_x - e.x
      local dy = e.dash_target_y - e.y
      local d = sqrt(dx*dx + dy*dy)
      if d > 0 then
        e.x += (dx / d) * e.speed
        e.y += (dy / d) * e.speed
      end
    end
  else
    -- normal movement toward player
    local dx = player.x - e.x
    local dy = player.y - e.y
    local d = sqrt(dx*dx + dy*dy)

    if d > 0 then
      local speed = e.speed or 0.5
      e.x += (dx / d) * speed
      e.y += (dy / d) * speed
    end
  end

  -- shooter behavior
  if e.type == "shooter" then
    e.shoot_timer = (e.shoot_timer or 0) + 1
    if e.shoot_timer >= 90 then
      e.shoot_timer = 0
      enemy_shoot(e)
    end
  end

  -- collision with player
  if player.invuln == 0 and dist(player.x, player.y, e.x, e.y) < 6 then
    -- extra damage during dash (3x in phase 2, 2x in phase 1)
    local dmg = 1
    if e.dashing and e.type == "heavy" then
      dmg = e.phase2 and 3 or 2
    end
    hit_player(dmg)
    if not e.dashing then
      del(enemies, e)
    end
  end
end

function enemy_shoot(e)
  local dx = player.x - e.x
  local dy = player.y - e.y
  local d = sqrt(dx*dx + dy*dy)

  if d > 0 then
    add(projectiles, {
      x = e.x,
      y = e.y,
      vx = (dx / d) * 1.5,
      vy = (dy / d) * 1.5,
      owner = "enemy",
      size = 1,
      dmg = 1
    })
  end
end

function update_boss_attacks(e)
  -- initialize timers if needed
  if not e.spawn_time then
    e.spawn_time = time()
    e.burst_cd = 0
    e.dash_cd = 0
    e.burst_used = false
  end

  -- update cooldowns and effects
  if e.burst_cd > 0 then e.burst_cd -= 1 end
  if e.dash_cd > 0 then e.dash_cd -= 1 end
  if e.flash_timer and e.flash_timer > 0 then e.flash_timer -= 1 end
  if e.spin_timer and e.spin_timer > 0 then e.spin_timer -= 1 end
  if e.spawn_flash and e.spawn_flash > 0 then e.spawn_flash -= 1 end
  if e.glow_t then e.glow_t = (e.glow_t + 1) % 12 end

  -- boss pulse expansion effect
  if e.pulse_timer and e.pulse_timer > 0 then
    e.pulse_timer -= 1
    e.pulse_radius = (20 - e.pulse_timer) * 0.7  -- expands to ~14 pixels
  end

  -- handle dash warning countdown
  if e.dash_warn and e.dash_warn > 0 then
    e.dash_warn -= 1
    if e.dash_warn == 0 then
      -- warning over, start actual dash
      _log("boss_dash")
      sfx(3)
      e.dashing = true
      e.dash_timer = 60
      e.speed = 0.6
    end
  end

  local elapsed = time() - e.spawn_time
  local hp_pct = e.hp / e.max_hp

  -- phase 2 cooldown adjustments
  local burst_cooldown = e.phase2 and 90 or 120  -- 3s vs 5s (at 30fps: 2s=60, but keeping 90 for 3s)
  local dash_cooldown = e.phase2 and 120 or 180  -- 2s vs 3s

  -- burst attack (once at 50% hp or 5s, repeats in phase 2)
  if (not e.burst_used and (hp_pct <= 0.5 or elapsed >= 5) and e.burst_cd == 0) or (e.phase2 and e.burst_cd == 0) then
    boss_burst_attack(e)
    e.burst_used = true
    e.burst_cd = burst_cooldown
  end

  -- dash attack (when player in range)
  local d = dist(player.x, player.y, e.x, e.y)
  if not e.dashing and not e.dash_warn and d < 60 and d > 10 and e.dash_cd == 0 then
    boss_dash_attack(e, dash_cooldown)
  end
end

function boss_burst_attack(e)
  local pattern = e.phase2 and "spiral" or "burst"
  _log("boss_"..pattern)
  sfx(6)
  e.flash_timer = 10
  e.spin_timer = 30 -- spinning animation

  -- phase 2: 12-way spiral, phase 1: 8-way burst
  local count = e.phase2 and 12 or 8
  for i=0,count-1 do
    local angle = i / count
    local vx = cos(angle) * e.speed * 3
    local vy = sin(angle) * e.speed * 3
    add(projectiles, {
      x = e.x,
      y = e.y,
      vx = vx,
      vy = vy,
      owner = "enemy",
      size = 1,
      dmg = 1
    })
  end
end

function boss_dash_attack(e, cooldown)
  _log("boss_dash_warn")
  sfx(9) -- dash warning sound
  _log("sfx:dash_warn")

  e.dash_cd = cooldown or 180
  e.dash_warn = 30 -- warning indicator frames
  e.dash_target_x = player.x
  e.dash_target_y = player.y
end

function update_projectile(p)
  p.x += p.vx
  p.y += p.vy

  -- bounds check
  if p.x < 0 or p.x > 128 or p.y < 0 or p.y > 128 then
    del(projectiles, p)
    return
  end

  if p.owner == "player" then
    -- check enemy collision
    for e in all(enemies) do
      if dist(p.x, p.y, e.x, e.y) < 5 then
        damage_enemy(e, p.dmg)
        del(projectiles, p)
        break
      end
    end
  elseif p.owner == "enemy" then
    -- check player collision
    if player.invuln == 0 and dist(p.x, p.y, player.x, player.y) < 5 then
      hit_player()
      del(projectiles, p)
    end
  end
end

function damage_enemy(e, dmg)
  e.hp -= dmg
  sfx(1)

  -- phase 2 trigger for bosses
  if e.type == "heavy" and not e.phase2 and e.hp <= 2 then
    e.phase2 = true
    _log("boss:phase2")
    -- visual flash for phase change
    e.flash_timer = 15
    shake_frames = 2
    shake_intensity = 1
    sfx(6)
  end

  if e.hp <= 0 then
    kill_enemy(e)
  end
end

function kill_enemy(e)
  _log("enemy_kill:"..e.type)

  -- boss death gets special fanfare
  if e.type == "heavy" then
    sfx(10)
    _log("sfx:boss_death")

    -- track quick kill (killed before phase 2)
    if not e.phase2 then
      quick_kill_flag = true
      _log("quick_kill")
    end
  else
    sfx(2)
  end

  -- score
  local base_score = e.score or 10
  local mult = get_score_multiplier()
  add_score(flr(base_score * mult) + combo)

  combo += 1
  enemies_killed += 1
  _log("combo:"..combo)

  -- combo milestone celebration
  if combo >= 10 and combo % 10 == 0 and combo > last_milestone then
    last_milestone = combo
    _log("combo_milestone:"..combo)

    -- screen flash
    flash_timer = 3

    -- floating text
    add(milestone_texts, {
      text = "combo x"..combo.."!",
      y = 64,
      life = 30,
      col = 10
    })

    -- corner particle burst
    for i=1,8 do
      local angle = i / 8
      add(particles, {
        x = 64,
        y = 64,
        vx = cos(angle) * 3,
        vy = sin(angle) * 3,
        life = 30,
        col = 10
      })
    end

    -- victory chime sfx
    sfx(6)
  end

  -- boss enhanced death feedback
  if e.type == "heavy" then
    boss_kills += 1
    _log("boss_kill:"..boss_kills)
    shake_frames = 4
    shake_intensity = 5
    flash_timer = 2  -- brief white flash
    -- enhanced spiral particle burst
    for i=1,18 do
      local angle = i / 18
      add(particles, {
        x = e.x,
        y = e.y,
        vx = cos(angle) * 2.5,  -- travel further
        vy = sin(angle) * 2.5,
        life = 32,  -- slower (live longer)
        col = 8 + flr(rnd(4))
      })
    end
  else
    -- normal explosion particles
    for i=1,15 do
      add(particles, {
        x = e.x,
        y = e.y,
        vx = rnd(3) - 1.5,
        vy = rnd(3) - 1.5,
        life = 20,
        col = 8 + flr(rnd(4))
      })
    end
  end

  -- powerup chance (1/20)
  if rnd(20) < 1 then
    spawn_powerup(e.x, e.y)
  end

  del(enemies, e)
end

function hit_player(dmg)
  dmg = dmg or 1

  if player.has_shield then
    player.has_shield = false
    sfx(5)
    _log("shield_block")
    return
  end

  player.lives -= dmg
  player.invuln = 60
  combo = 0
  sfx(7)
  _log("hit:lives="..player.lives..",dmg="..dmg)
  _log("combo_reset")

  -- screen shake (stronger for higher damage)
  shake_frames = 3 + dmg
  shake_intensity = 2 + dmg * 0.5

  -- particles
  for i=1,10 do
    add(particles, {
      x = player.x,
      y = player.y,
      vx = rnd(3) - 1.5,
      vy = rnd(3) - 1.5,
      life = 20,
      col = 8
    })
  end
end

function spawn_wave()
  wave += 1
  _log("wave:"..wave)

  local count = 3 + wave
  local boss_wave = wave % 5 == 0

  if boss_wave then
    -- boss wave: 1 heavy + minions
    spawn_enemy("heavy")
    count = 4
    music(2) -- boss theme
    _log("music:boss")
  else
    music(1) -- gameplay theme
    _log("music:gameplay")
  end

  for i=1,count do
    local enemy_type = "minion"

    if wave >= 3 and rnd(100) < 30 then
      enemy_type = "shooter"
    elseif wave >= 5 and rnd(100) < 20 then
      enemy_type = "speedy"
    end

    spawn_enemy(enemy_type)
  end
end

function spawn_enemy(typ)
  local x, y = 0, 0
  local side = flr(rnd(4))

  if side == 0 then -- top
    x = rnd(128)
    y = 0
  elseif side == 1 then -- right
    x = 128
    y = rnd(128)
  elseif side == 2 then -- bottom
    x = rnd(128)
    y = 128
  else -- left
    x = 0
    y = rnd(128)
  end

  local e = {
    type = typ,
    x = x,
    y = y,
    hp = 1,
    max_hp = 1,
    speed = 0.5,
    score = 10,
    col = 8
  }

  if typ == "shooter" then
    e.score = 20
    e.col = 9
    e.shoot_timer = 0
  elseif typ == "speedy" then
    e.hp = 2
    e.max_hp = 2
    e.speed = 1.2
    e.score = 25
    e.col = 10
  elseif typ == "heavy" then
    e.hp = 3
    e.max_hp = 3
    e.speed = 0.3
    e.score = 50
    e.col = 8 -- boss color: light gray
    e.glow_t = 0 -- pulsing glow timer
    e.spawn_flash = 3 -- spawn announcement flash
    e.pulse_radius = 0 -- expanding pulse effect
    e.pulse_timer = 20 -- frames for pulse expansion
  end

  add(enemies, e)
  _log("spawn:"..typ)

  -- boss spawn announcement
  if typ == "heavy" then
    sfx(8) -- boss entrance sound
    _log("sfx:boss_spawn")
    shake_frames = 3
    shake_intensity = 1

    -- spawn particle burst
    for i=1,10 do
      local angle = i / 10
      add(particles, {
        x = e.x,
        y = e.y,
        vx = cos(angle) * 1.5,
        vy = sin(angle) * 1.5,
        life = 20,
        col = 8 + flr(rnd(4))
      })
    end
  end
end

function spawn_powerup(x, y)
  local types = {"RR", "BS", "SH", "2X"}
  local typ = types[flr(rnd(4)) + 1]

  add(powerups, {
    type = typ,
    x = x,
    y = y
  })

  _log("powerup_spawn:"..typ)
end

function collect_powerup(pu)
  _log("powerup_collect:"..pu.type)
  sfx(4)

  -- track for arsenal master achievement
  powerups_collected[pu.type] = true

  if pu.type == "RR" then
    rapid_fire_t = 180 -- 3 seconds
  elseif pu.type == "BS" then
    big_shot_t = 300 -- 5 seconds
  elseif pu.type == "SH" then
    player.has_shield = true
  elseif pu.type == "2X" then
    score_mult_t = 600 -- 10 seconds
  end
end

function get_score_multiplier()
  local base = 1.0

  -- time multiplier (0.5x per 30s, max 2.0x at 120s)
  base += min(flr(time_survived / 30) * 0.5, 1.0)

  -- power-up multiplier
  if score_mult_t > 0 then
    base *= 2
  end

  return base
end

function add_score(pts)
  score += pts
  _log("score:"..score)
  if score > high_score then
    high_score = score
    dset(0, high_score)
    _log("new_high_score:"..high_score)
  end
end

function dist(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return sqrt(dx*dx + dy*dy)
end

function draw_play()
  -- apply screen shake
  if shake_frames > 0 then
    local dx = rnd(shake_intensity * 2) - shake_intensity
    local dy = rnd(shake_intensity * 2) - shake_intensity
    camera(dx, dy)
  else
    camera(0, 0)
  end

  -- arena border
  rect(4, 4, 123, 123, 5)

  -- particles
  for pt in all(particles) do
    pset(pt.x, pt.y, pt.col)
  end

  -- powerups
  for pu in all(powerups) do
    rectfill(pu.x - 2, pu.y - 2, pu.x + 2, pu.y + 2, 12)
    print(pu.type, pu.x - 4, pu.y - 8, 7)
  end

  -- enemies
  for e in all(enemies) do
    local r = e.type == "heavy" and 5 or (e.type == "speedy" and 2 or 3)

    -- boss spawn pulse effect (expanding circle)
    if e.pulse_timer and e.pulse_timer > 0 and e.pulse_radius then
      local alpha = e.pulse_timer / 20  -- fade out as pulse expands
      local pulse_col = (e.pulse_timer % 4 < 2) and 3 or 8  -- magenta/gray alternate
      circ(e.x, e.y, e.pulse_radius, pulse_col)
      if e.pulse_radius > 3 then
        circ(e.x, e.y, e.pulse_radius - 1, pulse_col)
      end
    end

    -- boss spawn flash
    local col = e.col
    if e.spawn_flash and e.spawn_flash > 0 then
      col = (e.spawn_flash % 2 == 0) and 15 or 8
    elseif e.flash_timer and e.flash_timer > 0 then
      col = (e.flash_timer % 4 < 2) and 7 or e.col
    end

    -- phase 2 color change for bosses
    if e.type == "heavy" and e.phase2 then
      col = 9 -- orange (aggression color)
    end

    -- dash warning indicator (purple outline)
    if e.dash_warn and e.dash_warn > 0 then
      line(e.x, e.y, e.dash_target_x, e.dash_target_y, 11)
      -- thick pulsing outline
      if e.dash_warn % 8 < 4 then
        circ(e.x, e.y, r + 1, 11)
        circ(e.x, e.y, r + 2, 11)
      end
    end

    circfill(e.x, e.y, r, col)

    -- boss pulsing glow
    if e.type == "heavy" and e.glow_t and not e.spawn_flash then
      local glow_col = (e.glow_t < 6) and 8 or 3
      -- phase 2: add aggressive red ring
      if e.phase2 then
        glow_col = (e.glow_t < 6) and 9 or 8
        circ(e.x, e.y, r + 2, glow_col) -- extra ring for phase 2
      end
      circ(e.x, e.y, r + 1, glow_col)
    end

    -- boss spinning crosshairs during burst
    if e.spin_timer and e.spin_timer > 0 then
      local angle = (30 - e.spin_timer) * 0.1
      local len = 8
      -- horizontal line
      local hx = cos(angle) * len
      local hy = sin(angle) * len
      line(e.x - hx, e.y - hy, e.x + hx, e.y + hy, 7)
      -- vertical line
      local vx = cos(angle + 0.25) * len
      local vy = sin(angle + 0.25) * len
      line(e.x - vx, e.y - vy, e.x + vx, e.y + vy, 7)
    end

    -- boss outline during dash
    if e.dashing then
      circ(e.x, e.y, r + 1, 10)
    end

    -- hp bar for multi-hp enemies
    if e.max_hp > 1 then
      local w = 8
      local frac = e.hp / e.max_hp
      rectfill(e.x - w/2, e.y - r - 3, e.x - w/2 + w * frac, e.y - r - 2, 11)
    end
  end

  -- projectiles
  for p in all(projectiles) do
    local col = p.owner == "player" and 10 or 8
    circfill(p.x, p.y, p.size, col)
  end

  -- player
  if player.invuln % 4 < 2 then
    circfill(player.x, player.y, 4, 11)

    -- shield
    if player.has_shield then
      circ(player.x, player.y, 6, 12)
    end

    -- facing indicator
    local dir = dirs[player.rot + 1]
    line(player.x, player.y,
         player.x + dir[1] * 6,
         player.y + dir[2] * 6, 7)
  end

  -- ui
  print("score:"..score, 2, 2, 7)
  print("wave:"..wave, 48, 2, 10)
  print("time:"..time_survived, 90, 2, 9)
  print("combo:"..combo, 2, 120, 14)

  -- lives
  for i=1,player.lives do
    circfill(118 - i * 6, 120, 2, 8)
  end

  -- power-up indicators
  local py = 10
  if rapid_fire_t > 0 then
    print("RR", 2, py, 10)
    py += 8
  end
  if big_shot_t > 0 then
    print("BS", 2, py, 14)
    py += 8
  end
  if score_mult_t > 0 then
    print("2X", 2, py, 12)
    py += 8
  end

  -- dash cooldown
  if player.dash_cd > 0 then
    local frac = player.dash_cd / 60
    rectfill(2, 110, 2 + 20 * (1 - frac), 113, 6)
  end

  -- milestone floating text
  for mt in all(milestone_texts) do
    local fade = mt.life / 30
    local col = mt.col
    if fade < 0.3 then col = 5 end
    print(mt.text, 36, mt.y, col)
  end

  -- screen flash for milestone
  if flash_timer > 0 then
    local intensity = flash_timer / 3
    rectfill(0, 0, 127, 127, 7)
    -- fade effect by alternating pixels
    if flash_timer == 1 then
      for i=0,127,2 do
        for j=0,127,2 do
          pset(i, j, 0)
        end
      end
    end
  end
end

-- pause state
function init_pause()
  state = "pause"
  _log("state:pause")
  music(-1) -- stop music
  _log("music:stop")
end

function update_pause()
  if test_inputp(5) then -- X to resume
    state = "play"
    _log("state:play")
    -- resume appropriate music
    if wave % 5 == 0 then
      music(2) -- boss theme
      _log("music:boss")
    else
      music(1) -- gameplay theme
      _log("music:gameplay")
    end
  end
  if test_inputp(4) then -- O to menu
    init_menu()
  end
end

function draw_pause()
  -- draw game state underneath
  draw_play()

  -- darken overlay
  rectfill(0, 0, 127, 127, 0)
  for i=0,127,4 do
    for j=0,127,4 do
      pset(i, j, 1)
    end
  end

  -- pause text
  print("paused", 48, 50, 7)
  print("press x to resume", 20, 70, 10)
  print("press o for menu", 22, 80, 6)
end

-- gameover state
function init_gameover()
  state = "gameover"
  _log("state:gameover")
  _log("final_score:"..score)
  _log("waves:"..wave)
  _log("kills:"..enemies_killed)
  _log("time:"..time_survived)
  music(3) -- gameover theme
  _log("music:gameover")

  -- final achievement check
  check_achievements()

  -- track session best combo
  best_combo_session = max(best_combo_session, combo)
  _log("best_combo_session:"..best_combo_session)

  -- update and save achievements
  if best_combo_session > best_combo then
    best_combo = best_combo_session
    dset(2, best_combo)
    _log("new_best_combo:"..best_combo)
  end

  -- save boss kills
  dset(1, boss_kills)
  _log("total_boss_kills:"..boss_kills)

  -- save achievements
  save_achievements()

  -- log session achievements
  local session_count = count_session_achievements()
  _log("session_achievements:"..session_count)
end

function update_gameover()
  local input = test_input()
  if input & 16 > 0 then -- O to restart
    init_play()
  end
  if input & 32 > 0 then -- X to menu
    init_menu()
  end
end

function draw_gameover()
  print("game over", 40, 30, 8)

  print("score: "..score, 36, 42, 7)
  print("waves: "..wave, 38, 50, 7)
  print("kills: "..enemies_killed, 38, 58, 7)
  print("time: "..time_survived.."s", 36, 66, 7)

  -- session achievements
  local session_count = count_session_achievements()
  if session_count > 0 then
    print("new achievements: "..session_count, 16, 76, 12)
    -- show which ones
    local y = 84
    for i=1,12 do
      if session_achievements[i] then
        local def = achievement_defs[i]
        print("\x97 "..def.name, 8, y, 10)
        y += 6
        if y > 104 then break end -- prevent overflow
      end
    end
  else
    print("no new achievements", 20, 76, 5)
  end

  -- total achievements
  local total = count_achievements()
  print("total: "..total.."/12", 42, 108, 14)

  print("o:retry x:menu", 28, 120, 6)
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
000100000c0500e0500f05010050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001c0501a0501705014050110500e0500b0500805000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002000020050230502505027050290502a0502a0502a0502a0502a0502a0502a0502a0502a0502a0502a050000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000180501e05024050280500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000240502405023050210501e0501b05017050130500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000140501605018050190500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200002c0502a0502705024050200501c05018050140500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000080500a0500c0500e05010050120501405015050160501605016050160501605016050160501605000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e0502005022050200501e0502005022050200501e0502005022050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000100501305015050180501b0501e05021050240502705029050290502a0502a0502a0502a0502a050000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c0501c0501e0501e05020050200502205022050240502405024050240502005020050200502005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000010050100500f0500f0500c0500c0500f0500f05010050100501005010050180501805018050180500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c0501c0501e0501e05020050200502205022050270502705027050270502005020050200502005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000008050080500a0500a0500c0500c0500a0500a050080500805008050080501005010050100501005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000240502405027050270502905029050270502705024050240502405024050270502705027050270500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000006050060500805008050090500905008050080500605006050060500605010050100501005010050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000020050220502405027050290502a0502a0502a05029050270502405020050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0b0c0d0e
01 0f100809
02 00010203
03 04050607

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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

