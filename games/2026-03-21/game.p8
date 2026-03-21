pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- space shooter arcade game
-- pilot a spaceship, dodge and destroy enemies

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function _capture()
  if testmode then add(test_log, "screen:"..tostr(stat(0))) end
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
lives = 3
wave_count = 1
difficulty = 2  -- 1=easy, 2=normal, 3=hard
difficulty_selected = 2
difficulty_names = {"easy", "normal", "hard"}
boss_health = 0
wave_complete_timer = 0
current_music = -1  -- track which music pattern is playing

-- visual effects
shake_timer = 0
shake_intensity = 0
flash_timer = 0
flash_color = 0
particles = {}
sprite_flash_timer = 0
sprite_flash_state = false
enemy_anim_frame = 0
starfield = {}  -- background stars

-- initialize starfield
function init_starfield()
  starfield = {}
  for i=1,20 do
    add(starfield, {x=rnd(128), y=rnd(128), speed=0.2+rnd(0.3), color=5+flr(rnd(2))})
  end
end

-- player
player = {x=64, y=110, w=4, h=4}

-- enemies (simple objects)
enemies = {}
next_enemy_spawn = 30
enemy_spawn_timer = 30
enemy_speed = 1
base_enemy_speed = 1

-- projectiles
projectiles = {}
fire_cooldown = 0

-- boss
boss = nil
boss_phase_timer = 0
boss_projectiles = {}
boss_attack_timer = 0

-- power-ups
powerups = {}
shield_count = 0
rapid_fire_timer = 0

-- difficulty
enemies_killed = 0
difficulty_level = 1
score_multiplier = 1

function _init()
  state = "menu"
  score = 0
  lives = 3
  wave_count = 1
  difficulty = 2
  difficulty_selected = 2
  enemies = {}
  projectiles = {}
  particles = {}
  powerups = {}
  enemy_spawn_timer = 30
  enemies_killed = 0
  difficulty_level = 1
  shake_timer = 0
  shake_intensity = 0
  flash_timer = 0
  boss = nil
  boss_health = 0
  boss_attack_timer = 0
  score_multiplier = 1
  shield_count = 0
  rapid_fire_timer = 0
  init_starfield()
  _log("init")
end

-- wave and boss initialization
function init_wave(wv)
  enemies = {}
  boss = nil
  projectiles = {}
  boss_projectiles = {}
  powerups = {}
  particles = {}  -- clear particles for clean wave start
  enemy_spawn_timer = 30
  enemies_killed = 0
  difficulty_level = wv
  wave_complete_timer = 0
  shield_count = 0
  rapid_fire_timer = 0

  -- determine if this is a boss wave
  local is_boss_wave = wv >= 5

  if is_boss_wave then
    -- boss wave: create the boss
    local boss_spd = 1
    if difficulty == 1 then
      boss_health = 3
      boss_spd = 0.8
    elseif difficulty == 2 then
      boss_health = 4
      boss_spd = 1.0
    else
      boss_health = 5
      boss_spd = 1.3
    end

    boss = {
      x = 64, y = 30, w = 6, h = 6,
      health = boss_health, dir = 1, speed = boss_spd,
      charge_timer = 0, attack_timer = 0, last_pattern = 0
    }
    _log("boss:spawn")
  else
    -- regular wave: difficulty scales up with waves
    local spawn_delay = max(10, 30 - wv * 3)
    enemy_spawn_timer = spawn_delay
    _log("wave:"..wv)
  end
end

-- particle system with enhanced visuals
function create_explosion(x, y, count, speed, color)
  for i=1,count do
    local angle = rnd(1)  -- pico-8 uses turns 0-1
    local px = cos(angle) * speed * (0.5 + rnd(0.5))
    local py = sin(angle) * speed * (0.5 + rnd(0.5))
    local lifetime = 15 + flr(rnd(10))
    add(particles, {x=x, y=y, vx=px, vy=py, life=lifetime, color=color, age=0, size=1})
  end
  -- add bright flash particles at center
  for i=1,flr(count/2) do
    local angle = rnd(1)
    local px = cos(angle) * speed * 0.3
    local py = sin(angle) * speed * 0.3
    add(particles, {x=x, y=y, vx=px, vy=py, life=8, color=12, age=0, size=2})
  end
end

function update_particles()
  for p in all(particles) do
    p.x += p.vx
    p.y += p.vy
    p.vy += 0.15  -- gravity
    p.vx *= 0.96  -- drag
    p.age += 1
    if p.age >= p.life then
      del(particles, p)
    end
  end
end

function trigger_shake(intensity)
  shake_timer = intensity * 2
  shake_intensity = intensity
end

function trigger_flash(color)
  flash_timer = 3
  flash_color = color
end

function update_menu()
  if btnp(4) or btnp(5) then
    state = "difficulty"
    difficulty_selected = 2
    _log("state:difficulty")
    sfx(2)
  end
end

function update_difficulty()
  -- left/right to select difficulty
  if btnp(0) then  -- left
    difficulty_selected = max(1, difficulty_selected - 1)
    sfx(0)
  end
  if btnp(1) then  -- right
    difficulty_selected = min(3, difficulty_selected + 1)
    sfx(0)
  end

  -- z/c to confirm difficulty
  if btnp(4) or btnp(5) then
    difficulty = difficulty_selected

    -- set score multiplier based on difficulty
    if difficulty == 1 then
      score_multiplier = 1
    elseif difficulty == 2 then
      score_multiplier = 1.5
    else
      score_multiplier = 2
    end

    -- initialize game state
    state = "play"
    enemies = {}
    projectiles = {}
    particles = {}
    powerups = {}
    score = 0
    lives = 3
    wave_count = 1
    enemies_killed = 0
    boss = nil
    boss_health = 0
    player = {x=64, y=110, w=4, h=4}
    shield_count = 0
    rapid_fire_timer = 0

    _log("difficulty:"..difficulty_names[difficulty])
    init_wave(1)
    _log("state:play")
    sfx(2)

    -- start music based on difficulty
    current_music = difficulty - 1  -- 0=easy, 1=normal, 2=hard
    music(current_music)
    _log("music:"..difficulty_names[difficulty])
  end
end

function update_play()
  -- update visual effects
  if shake_timer > 0 then shake_timer -= 1 end
  if flash_timer > 0 then flash_timer -= 1 end
  if boss_phase_timer > 0 then boss_phase_timer -= 1 end
  if sprite_flash_timer > 0 then sprite_flash_timer -= 1 end
  enemy_anim_frame = (enemy_anim_frame + 1) % 30  -- 30 frame animation cycle
  update_particles()

  -- update active power-up timers
  if rapid_fire_timer > 0 then rapid_fire_timer -= 1 end

  -- player movement
  if test_input(0) == 1 then
    player.x = max(4, player.x - 2)
  end
  if test_input(1) == 1 then
    player.x = min(124, player.x + 2)
  end

  -- shooting
  if test_input(4) == 1 or test_input(5) == 1 then
    -- rapid fire doubles fire rate (cooldown halved from 5 to 2.5≈2)
    local cooldown = rapid_fire_timer > 0 and 2 or 5
    if fire_cooldown <= 0 then
      add(projectiles, {x=player.x, y=player.y-4, w=1, h=3, alive=true, age=0})
      fire_cooldown = cooldown
      sfx(0)
      _log("shoot")
    end
  end

  if fire_cooldown > 0 then
    fire_cooldown -= 1
  end

  -- update power-ups
  for pu in all(powerups) do
    pu.y += 0.5  -- fall slowly
    pu.age += 1
    if pu.age >= 300 then
      pu.alive = false  -- disappear after 300 frames
    end
  end
  del_powerups()

  -- player-powerup collision
  for pu in all(powerups) do
    if collision(player.x, player.y, 4, 4, pu.x, pu.y, 3, 3) then
      pu.alive = false
      apply_powerup(pu.type)
      trigger_flash(pu.type == 1 and 3 or 11)  -- cyan flash for shield
      create_explosion(pu.x, pu.y, 5, 1, 12)
      sfx(2)
    end
  end
  del_powerups()

  -- update projectiles (with trail generation)
  for p in all(projectiles) do
    p.y -= 4
    p.age += 1
    -- create trail particles every 2 frames
    if p.age % 2 == 0 then
      add(particles, {x=p.x, y=p.y, vx=0, vy=0.5, life=8, color=11, age=0})
    end
    if p.y < 0 then
      p.alive = false
    end
  end
  del_projectiles()

  -- boss encounter
  if boss then
    -- boss patrol and attack
    local phase = get_boss_phase()
    if phase > 1 and boss_phase_timer <= 0 then
      _log("boss_phase:"..phase)
      boss_phase_timer = 15
    end

    -- charge attack: accelerate toward player
    if boss.charge_timer > 0 then
      boss.charge_timer -= 1
      boss.x += boss.speed * boss.dir
    else
      -- normal patrol
      boss.speed = boss.health >= boss_health * 0.75 and 1 or 1.5
      if difficulty == 1 then boss.speed *= 0.8 elseif difficulty == 3 then boss.speed *= 1.3 end
      boss.x += boss.speed * boss.dir
    end

    if boss.x < 10 or boss.x > 118 then
      boss.dir *= -1
    end

    -- update boss attack timer based on phase
    local attack_interval = 90
    if phase == 1 then
      attack_interval = difficulty == 1 and 120 or (difficulty == 2 and 90 or 60)
    elseif phase == 2 then
      attack_interval = difficulty == 1 and 90 or (difficulty == 2 and 60 or 45)
    else
      attack_interval = difficulty == 1 and 60 or (difficulty == 2 and 40 or 30)
    end

    boss.attack_timer -= 1
    if boss.attack_timer <= 0 then
      local pattern = 1
      if phase >= 2 then
        pattern = boss.last_pattern == 1 and 2 or 1
      end
      if phase >= 3 then
        pattern = (boss.last_pattern % 3) + 1
      end

      if pattern == 1 then
        boss_fire_volley()
      elseif pattern == 2 then
        boss_charge()
      else
        boss_spiral()
      end

      boss.last_pattern = pattern
      boss.attack_timer = attack_interval
    end

    -- update boss projectiles
    for bp in all(boss_projectiles) do
      bp.x += bp.vx
      bp.y += bp.vy
      bp.age += 1
      if bp.y > 128 or bp.x < 0 or bp.x > 128 then
        bp.alive = false
      end
    end
    del_boss_projectiles()

    -- projectile-boss collision
    for p in all(projectiles) do
      if collision(p.x, p.y, 1, 3, boss.x, boss.y, 6, 6) then
        p.alive = false
        boss.health -= 1
        trigger_shake(3)
        trigger_flash(11)
        boss_phase_timer = 15
        sfx(1)
        _log("boss_hit:"..boss.health)

        create_explosion(boss.x, boss.y, 6, 2, 9)

        if boss.health <= 0 then
          state = "boss_defeated"
          _log("state:boss_defeated")
          sfx(3)
          create_explosion(boss.x, boss.y, 12, 3, 11)
          wave_complete_timer = 120
          boss_projectiles = {}
        end
      end
    end
    del_projectiles()

    -- player-boss projectile collision
    for bp in all(boss_projectiles) do
      if collision(player.x, player.y, 4, 4, bp.x, bp.y, 2, 2) then
        bp.alive = false
        if shield_count > 0 then
          shield_count -= 1
          create_explosion(player.x, player.y, 6, 1, 11)
          trigger_shake(1)
          trigger_flash(11)
          sfx(0)
          _log("shield:blocked_boss")
        else
          lives -= 1
          create_explosion(player.x, player.y, 8, 1, 10)
          trigger_shake(3)
          trigger_flash(10)
          sfx(1)
          _log("collision:boss_projectile")

          if lives <= 0 then
            music(-1)
            state = "gameover"
            _log("state:gameover:lose")
            sfx(3)
          else
            player = {x=64, y=110, w=4, h=4}
          end
        end
      end
    end
    del_boss_projectiles()

    -- player-boss collision
    if collision(player.x, player.y, 4, 4, boss.x, boss.y, 6, 6) then
      lives -= 1
      create_explosion(player.x, player.y, 8, 1, 10)
      trigger_shake(3)
      trigger_flash(10)
      sfx(4)
      _log("collision:boss")

      if lives <= 0 then
        music(-1)
        state = "gameover"
        _log("state:gameover:lose")
        sfx(3)
      else
        player = {x=64, y=110, w=4, h=4}
      end
    end

  else
    -- regular wave: spawn enemies
    enemy_spawn_timer -= 1

    local spawn_rate = 30 - (wave_count - 1) * 2
    if difficulty == 1 then
      spawn_rate = 40 - wave_count
    elseif difficulty == 3 then
      spawn_rate = 20 - wave_count
    end

    if enemy_spawn_timer <= 0 then
      local etype = rnd(3) < 2 and 1 or 2
      local spd = base_enemy_speed + (wave_count - 1) * 0.2
      if difficulty == 1 then spd *= 0.7
      elseif difficulty == 3 then spd *= 1.3 end
      add(enemies, {x=rnd(120)+4, y=4, type=etype, speed=spd})
      enemy_spawn_timer = spawn_rate
    end

    -- update enemies
    for e in all(enemies) do
      e.y += e.speed
      if e.y > 128 then
        e.alive = false
      end
    end
    del_enemies()

    -- collision: projectile-enemy
    for p in all(projectiles) do
      for e in all(enemies) do
        if collision(p.x, p.y, 1, 3, e.x, e.y, 4, 4) then
          p.alive = false
          e.alive = false

          -- visual feedback on kill
          local points = e.type == 1 and 1 or 3
          score += flr(points * score_multiplier)

          if e.type == 1 then
            create_explosion(e.x, e.y, 4, 1.5, 8)  -- cyan explosion
          else
            create_explosion(e.x, e.y, 6, 2, 9)    -- magenta explosion
          end

          -- spawn power-up from destroyed enemy (15% small, 25% large)
          spawn_powerup(e.x, e.y, e.type)

          trigger_shake(2)
          trigger_flash(11)
          enemies_killed += 1
          sfx(1)
          _log("kill:enemy")

          -- check if wave is complete
          local target_kills = 30 + (wave_count - 1) * 5
          if enemies_killed >= target_kills then
            state = "wave_complete"
            wave_complete_timer = 90
            _log("state:wave_complete")
          end
        end
      end
    end
    del_projectiles()

    -- collision: player-enemy
    for e in all(enemies) do
      if collision(player.x, player.y, 4, 4, e.x, e.y, 4, 4) then
        e.alive = false

        -- check if shield absorbs hit
        if shield_count > 0 then
          shield_count -= 1
          create_explosion(player.x, player.y, 6, 1, 11)  -- yellow flash
          trigger_shake(1)
          trigger_flash(11)
          sfx(0)
          _log("shield:blocked")
        else
          lives -= 1
          create_explosion(player.x, player.y, 8, 1, 10)  -- red flash
          trigger_shake(3)
          trigger_flash(10)
          sfx(1)
          _log("collision:enemy")

          if lives <= 0 then
            state = "gameover"
            _log("state:gameover:lose")
            sfx(3)
          end
        end
      end
    end
    del_enemies()
  end

  _capture()
end

function update_wave_complete()
  wave_complete_timer -= 1
  if wave_complete_timer <= 0 or btnp(4) or btnp(5) then
    sfx(5)  -- wave complete stinger
    wave_count += 1
    state = "play"
    init_wave(wave_count)
    -- restart music for next wave
    music(current_music)
    _log("state:play")
  end
end

function update_boss_defeated()
  if wave_complete_timer > 0 then
    wave_complete_timer -= 1
  end
  if wave_complete_timer <= 0 and (btnp(4) or btnp(5)) then
    music(-1)  -- stop music
    sfx(6)     -- victory stinger
    state = "gameover"
    _log("state:gameover:win")
  end
end

function update_gameover()
  if btnp(4) or btnp(5) then
    music(-1)  -- stop any music
    state = "menu"
    _log("state:menu")
    sfx(2)
  end
end

function del_projectiles()
  for i=#projectiles,1,-1 do
    if not projectiles[i].alive then
      del(projectiles, projectiles[i])
    end
  end
end

function del_enemies()
  for i=#enemies,1,-1 do
    if not enemies[i].alive then
      del(enemies, enemies[i])
    end
  end
end

function del_powerups()
  for i=#powerups,1,-1 do
    if not powerups[i].alive then
      del(powerups, powerups[i])
    end
  end
end

function collision(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 < x2 + w2 and x1 + w1 > x2 and
         y1 < y2 + h2 and y1 + h1 > y2
end

function spawn_powerup(x, y, enemy_type)
  -- drop chance: 15% for small enemies, 25% for large enemies
  local drop_chance = enemy_type == 1 and 0.15 or 0.25

  if rnd(1) < drop_chance then
    -- pick random powerup: 1=shield, 2=rapid-fire, 3=health
    local pu_type = flr(rnd(3)) + 1
    add(powerups, {x=x, y=y, type=pu_type, age=0, alive=true})
    _log("powerup:spawn:"..pu_type)
  end
end

function apply_powerup(pu_type)
  if pu_type == 1 then
    -- shield: absorbs one collision (max 3)
    if shield_count < 3 then
      shield_count += 1
      _log("shield_pickup:"..shield_count)
    else
      _log("shield_full")
    end
  elseif pu_type == 2 then
    -- rapid fire: doubles fire rate for 5 seconds (300 frames)
    rapid_fire_timer = 300
    _log("rapidfire_pickup:5s")
  elseif pu_type == 3 then
    -- health: restores one lost life (max 3)
    if lives < 3 then
      lives += 1
      create_explosion(player.x, player.y, 8, 1, 11)  -- green particle burst
      _log("health_pickup:"..lives)
    else
      _log("health_full")
    end
  end
end

-- boss attack system
function get_boss_phase()
  if not boss then return 1 end
  local health_percent = boss.health / boss_health
  if health_percent > 0.75 then return 1
  elseif health_percent > 0.4 then return 2
  else return 3 end
end

function boss_fire_volley()
  if not boss then return end
  local count = 3
  if difficulty == 2 then count = 4 end
  if difficulty == 3 then count = 5 end

  for i=0,count-1 do
    local offset = (i - flr(count/2)) * 8
    add(boss_projectiles, {
      x = boss.x + offset, y = boss.y + 4,
      vx = 0, vy = 2, alive = true, age = 0
    })
  end
  sfx(4)
end

function boss_charge()
  if not boss then return end
  local dx = player.x - boss.x
  local accel = difficulty == 1 and 0.5 or (difficulty == 2 and 0.8 or 1.2)
  if dx > 0 then boss.dir = 1 else boss.dir = -1 end
  boss.speed = 2 * accel
  boss.charge_timer = 30 + difficulty * 10
  sfx(4)
end

function boss_spiral()
  if not boss then return end
  local count = difficulty == 1 and 3 or (difficulty == 2 and 4 or 5)
  for i=0,count-1 do
    local angle = (i / count) + (boss.dir > 0 and 0 or 0.5)
    local vx = sin(angle) * 1.5
    local vy = 2 + cos(angle) * 0.5
    add(boss_projectiles, {
      x = boss.x, y = boss.y + 4,
      vx = vx, vy = vy, alive = true, age = 0
    })
  end
  sfx(4)
end

function del_boss_projectiles()
  for i=#boss_projectiles,1,-1 do
    if not boss_projectiles[i].alive then
      del(boss_projectiles, boss_projectiles[i])
    end
  end
end

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "difficulty" then
    update_difficulty()
  elseif state == "play" then
    update_play()
  elseif state == "wave_complete" then
    update_wave_complete()
  elseif state == "boss_defeated" then
    update_boss_defeated()
  elseif state == "gameover" then
    update_gameover()
  end
end

function draw_menu()
  cls(1)
  print("space shooter", 35, 20, 7)
  print("arcade game", 40, 30, 7)

  print("controls:", 30, 50, 6)
  print("arrow keys: move", 20, 60, 7)
  print("z/x: shoot", 30, 70, 7)

  print("destroy enemies", 25, 85, 6)
  print("avoid collisions", 25, 95, 6)

  print("press z to start", 25, 110, 11)
end

function draw_difficulty()
  cls(0)
  print("select difficulty", 30, 20, 7)

  -- draw difficulty options
  local y = 50
  for i=1,3 do
    local col = difficulty_selected == i and 11 or 7
    local marker = difficulty_selected == i and "> " or "  "
    print(marker..difficulty_names[i], 40, y, col)
    y += 15
  end

  print("left/right to change", 20, 100, 6)
  print("z to confirm", 35, 110, 6)
end

function draw_wave_complete()
  cls(0)
  print("wave "..wave_count.." complete!", 25, 30, 11)
  print("enemies killed: "..enemies_killed, 20, 50, 7)
  print("wave bonus: +"..flr(enemies_killed * 5), 25, 70, 10)

  if wave_count < 5 then
    print("next: wave "..(wave_count+1), 30, 85, 7)
  else
    print("next: boss battle!", 30, 85, 9)
  end

  print("press z to continue", 20, 110, 11)
end

function draw_boss_defeated()
  cls(0)
  print("boss defeated!", 30, 30, 11)
  print("victory!", 45, 45, 10)
  print("final score: "..score, 30, 65, 7)
  print("all waves cleared!", 20, 80, 6)

  print("press z to finish", 25, 110, 11)
end

function draw_play()
  cls(0)

  -- draw starfield background
  for star in all(starfield) do
    star.y += star.speed
    if star.y > 128 then
      star.y = -2
      star.x = rnd(128)
    end
    pset(flr(star.x), flr(star.y), star.color)
  end

  -- apply screen shake
  local shake_x = 0
  local shake_y = 0
  if shake_timer > 0 then
    shake_x = rnd(shake_intensity * 2) - shake_intensity
    shake_y = rnd(shake_intensity * 2) - shake_intensity
  end
  camera(shake_x, shake_y)

  -- draw player using sprite
  spr(0, player.x-4, player.y-4)

  -- draw projectiles using sprite with glow
  for p in all(projectiles) do
    -- add projectile glow
    if p.age % 2 == 0 then
      pset(flr(p.x), flr(p.y)-3, 12)  -- bright glow
    end
    spr(4, p.x-2, p.y-2)
    -- trail effect
    if p.age % 3 == 0 then
      add(particles, {x=p.x, y=p.y+2, vx=rnd(0.5)-0.25, vy=0.3, life=5, color=11, age=0, size=1})
    end
  end

  -- draw particles (explosions and trails) with size variation
  for part in all(particles) do
    local alpha = flr(part.life - part.age) / part.life
    if alpha > 0.5 then
      if part.size and part.size > 1 then
        -- bright burst particles
        for dx=-part.size,part.size do
          pset(flr(part.x)+dx, flr(part.y), part.color)
        end
      else
        pset(flr(part.x), flr(part.y), part.color)
      end
    elseif alpha > 0 then
      pset(flr(part.x), flr(part.y), 1)
    end
  end

  -- draw power-ups using sprites with rotation animation
  for pu in all(powerups) do
    local rotation = flr((pu.age + pu.type * 10) / 3) % 4
    local pulse = sin((pu.age + pu.type * 20) / 60) * 2
    if pu.type == 1 then
      spr(5, flr(pu.x)-4, flr(pu.y)-4)  -- shield
    elseif pu.type == 2 then
      -- rapid-fire rotates
      if rotation == 0 then spr(6, flr(pu.x)-4, flr(pu.y)-4)
      elseif rotation == 1 then spr(6, flr(pu.x)-4, flr(pu.y)-4, 1, 1, false, false)
      else spr(6, flr(pu.x)-4, flr(pu.y)-4) end
    elseif pu.type == 3 then
      spr(7, flr(pu.x)-4, flr(pu.y)-4)  -- health
    end
  end


  -- draw boss projectiles
  for bp in all(boss_projectiles) do
    pset(flr(bp.x), flr(bp.y), 8)
    pset(flr(bp.x)-1, flr(bp.y), 8)
    pset(flr(bp.x)+1, flr(bp.y), 8)
    if bp.age % 2 == 0 then
      pset(flr(bp.x), flr(bp.y)-1, 13)
    end
  end

  -- draw boss or enemies
  if boss then
    -- draw boss sprite with flash effect when hit
    local boss_sprite = boss_phase_timer > 0 and 8 or 3
    spr(boss_sprite, boss.x-4, boss.y-4)
    -- boss aura glow - pulsing
    local aura_size = 5 + flr(sin(boss_phase_timer / 15) * 2)
    circ(boss.x, boss.y, aura_size, 5)
    -- additional hit flash
    if boss_phase_timer > 0 and boss_phase_timer % 2 == 0 then
      circ(boss.x, boss.y, 6, 12)
    end
  else
    -- draw regular enemies using sprites with subtle bob animation
    for e in all(enemies) do
      local bob = sin(enemy_anim_frame / 30 + (e.x + e.y) / 20) * 0.5
      local draw_y = e.y - 4 + bob
      if e.type == 1 then
        spr(1, e.x-4, draw_y)  -- small enemy with vertical bob
      else
        spr(2, e.x-4, draw_y)  -- large enemy with vertical bob
      end
    end
  end

  -- reset camera
  camera(0, 0)

  -- flash overlay if recently hit with intensity based on timer
  if flash_timer > 0 then
    local flash_intensity = flr((flash_timer / 3) * 8)  -- fade intensity
    local flash_col = flash_color
    if flash_intensity > 0 then
      for i=0,flash_intensity do
        if flash_color == 10 then
          -- red flash for player damage - striped
          line(0, i*8, 128, i*8, 10)
        elseif flash_color == 11 then
          -- yellow flash for kill - full screen
          rectfill(0, 0, 128, 128, 11)
          break
        end
      end
    end
  end

  -- draw ui (over flash)
  print("score: "..score, 5, 5, 7)
  print("lives: "..lives, 5, 12, 7)
  print("wave: "..wave_count, 5, 19, 7)

  -- draw active power-ups
  local pu_y = 26
  if shield_count > 0 then
    print("shield:"..shield_count, 5, pu_y, 3)
    pu_y += 7
  end
  if rapid_fire_timer > 0 then
    local sec = flr(rapid_fire_timer / 60) + 1
    print("rapid "..sec.."s", 5, pu_y, 10)
  end

  -- draw boss health if in boss wave
  if boss then
    print("boss hp: "..boss.health, 85, 5, 10)
  end
end

function draw_gameover()
  cls(0)

  if state == "gameover" then
    -- check if this was a win or loss from log state
    local msg = "game over"
    local col = 7
    print(msg, 40, 40, col)
    print("final score: "..score, 30, 55, 11)
    print("enemies killed: "..enemies_killed, 20, 65, 7)
    print("wave reached: "..wave_count, 20, 75, 7)
    print("difficulty: "..difficulty_names[difficulty], 20, 85, 6)

    print("press z to restart", 20, 110, 10)
  end
end

function _draw()
  if state == "menu" then
    draw_menu()
  elseif state == "difficulty" then
    draw_difficulty()
  elseif state == "play" then
    draw_play()
  elseif state == "wave_complete" then
    draw_wave_complete()
  elseif state == "boss_defeated" then
    draw_boss_defeated()
  elseif state == "gameover" then
    draw_gameover()
  end
end

__gfx__
007070aa008080dd00a00099008080cc00b0b0ee00c0c0ff00800088000000000000000000000000000000000000000000000000000000000000000000000000
07777aaa888888dd0aaaa0999999cc00b0b0ee00c0c0ff088888880000000000000000000000000000000000000000000000000000000000000000000000000000
7888aaaa8888dddd0aaaa099999cc0b0b0eeff0c0c0ff088888880000000000000000000000000000000000000000000000000000000000000000000000000000
7888aaaa8888dddd0aaaa099999cc0b0b0eeff0c0c0ff088888880000000000000000000000000000000000000000000000000000000000000000000000000000
78aaaaa88888dddd0aaaa099999cc0b0b0eeff0c0c0ff0bbbbb000000000000000000000000000000000000000000000000000000000000000000000000000000
7aaaaaa8888dddd000aaa9999cc000b0b0ee000c0c0ff00bbb0000000000000000000000000000000000000000000000000000000000000000000000000000000
007070000080000000a00000000cc000b0b00000c0c00000b00000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gfx__
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

__sfx__
010100000c4514c45000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010100001c051d055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01010000164514b451000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01040000304503045030450304500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300002c3503c35000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01050000084500845008450084500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300002c450344502c450344500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400005c5505a5505c5505a55050450504500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00040404
01 01050505
02 02070707

