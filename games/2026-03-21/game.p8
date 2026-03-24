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
music_fade_timer = 0  -- for fade-out effect

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
score_popups = {}  -- floating score feedback
boss_intro_timer = 0  -- for boss introduction fanfare
boss_attack_warning = 0  -- wind-up effect before boss attacks
combo_pulse_timer = 0  -- for combo counter pulsing

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

-- power-ups
powerups = {}
shield_count = 0
rapid_fire_timer = 0
mega_shot_timer = 0

-- difficulty
enemies_killed = 0
difficulty_level = 1
score_multiplier = 1

-- combo system
combo = 0
combo_multiplier = 1.0
multiplier_flash_timer = 0
multiplier_last_value = 1.0

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
  boss_phase_timer = 0
  score_multiplier = 1
  shield_count = 0
  rapid_fire_timer = 0
  mega_shot_timer = 0
  combo = 0
  combo_multiplier = 1.0
  multiplier_flash_timer = 0
  multiplier_last_value = 1.0
  score_popups = {}
  boss_intro_timer = 0
  boss_attack_warning = 0
  combo_pulse_timer = 0
  init_starfield()
  music(3)  -- start with menu theme
  current_music = 3
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
  mega_shot_timer = 0

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
    boss_intro_timer = 60  -- 1 second intro fanfare
    _log("boss:spawn")
  else
    -- regular wave: difficulty scales up with waves
    local spawn_delay = max(10, 30 - wv * 3)
    enemy_spawn_timer = spawn_delay
    _log("wave:"..wv)
  end
end

-- calculate combo multiplier based on combo count
function calc_combo_multiplier()
  if combo < 5 then
    return 1.0
  elseif combo < 10 then
    return 1.5
  elseif combo < 15 then
    return 2.0
  elseif combo < 20 then
    return 3.0
  else
    return 5.0
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

function create_score_popup(x, y, points)
  add(score_popups, {x=x, y=y, points=points, age=0, lifetime=30})
end

function update_score_popups()
  for sp in all(score_popups) do
    sp.y -= 0.5  -- float upward
    sp.age += 1
    if sp.age >= sp.lifetime then
      del(score_popups, sp)
    end
  end
end

-- update music based on game state
function update_music_state()
  local target_music = -1

  if state == "menu" or state == "difficulty" then
    target_music = 3  -- menu theme
  elseif state == "play" then
    if boss then
      target_music = 5  -- boss battle theme
    else
      target_music = 4  -- gameplay theme
    end
  elseif state == "wave_complete" or state == "boss_defeated" or state == "gameover" then
    target_music = -1  -- fade out music
  end

  -- only change music if target is different from current
  if target_music ~= current_music then
    music(target_music)
    current_music = target_music
  end
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
    mega_shot_timer = 0

    _log("difficulty:"..difficulty_names[difficulty])
    init_wave(1)
    _log("state:play")
    sfx(2)
  end
end

-- enemy type selection based on difficulty
-- types: 1=straight, 2=fast, 3=tank, 4=weaver, 5=scout
function spawn_enemy_type()
  local r = rnd(100)
  if difficulty == 1 then
    -- easy: favor simple types (1,5), minimal weaver
    if r < 50 then return 1       -- 50% straight
    elseif r < 70 then return 5   -- 20% scout
    elseif r < 85 then return 2   -- 15% fast
    elseif r < 95 then return 3   -- 10% tank
    else return 4 end             -- 5% weaver
  elseif difficulty == 2 then
    -- normal: balanced mix of all types
    if r < 30 then return 1       -- 30% straight
    elseif r < 50 then return 5   -- 20% scout
    elseif r < 65 then return 2   -- 15% fast
    elseif r < 80 then return 4   -- 15% weaver
    else return 3 end             -- 20% tank
  else
    -- hard: favor challenging types (3,4,2), less scout
    if r < 25 then return 4       -- 25% weaver
    elseif r < 45 then return 3   -- 20% tank
    elseif r < 60 then return 2   -- 15% fast
    elseif r < 80 then return 1   -- 20% straight
    else return 5 end             -- 20% scout
  end
end

-- get base speed for enemy type
-- types: 1=straight(1.0), 2=fast(1.5), 3=tank(0.6), 4=weaver(0.8), 5=scout(1.8)
function get_enemy_speed(etype)
  if etype == 1 then return 1.0
  elseif etype == 2 then return 1.5
  elseif etype == 3 then return 0.6
  elseif etype == 4 then return 0.8   -- weaver
  else return 1.8 end                 -- scout (fast)
end

function update_play()
  -- update visual effects
  if shake_timer > 0 then shake_timer -= 1 end
  if flash_timer > 0 then flash_timer -= 1 end
  if boss_phase_timer > 0 then boss_phase_timer -= 1 end
  if sprite_flash_timer > 0 then sprite_flash_timer -= 1 end
  if boss_intro_timer > 0 then boss_intro_timer -= 1 end
  enemy_anim_frame = (enemy_anim_frame + 1) % 30  -- 30 frame animation cycle
  update_particles()
  update_score_popups()

  -- update active power-up timers
  if rapid_fire_timer > 0 then rapid_fire_timer -= 1 end
  if mega_shot_timer > 0 then mega_shot_timer -= 1 end

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
      -- mega-shot fires 3 projectiles spread
      if mega_shot_timer > 0 then
        add(projectiles, {x=player.x-4, y=player.y-4, w=1, h=3, alive=true, age=0})
        add(projectiles, {x=player.x, y=player.y-4, w=1, h=3, alive=true, age=0})
        add(projectiles, {x=player.x+4, y=player.y-4, w=1, h=3, alive=true, age=0})
        cooldown = 8  -- slower fire rate for mega-shot
        _log("megashot:3x")
      else
        add(projectiles, {x=player.x, y=player.y-4, w=1, h=3, alive=true, age=0})
      end
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
      -- sound handled in apply_powerup()
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
          -- break combo on shield use
          if combo > 0 then
            combo = 0
            multiplier_last_value = 1.0
            combo_multiplier = 1.0
            multiplier_flash_timer = 10
            _log("combo_broken")
          end
        else
          lives -= 1
          create_explosion(player.x, player.y, 8, 1, 10)
          trigger_shake(3)
          trigger_flash(10)
          sfx(1)
          _log("collision:boss_projectile")
          -- break combo on damage
          if combo > 0 then
            combo = 0
            multiplier_last_value = 1.0
            combo_multiplier = 1.0
            multiplier_flash_timer = 10
            _log("combo_broken")
          end

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
      -- break combo on damage
      if combo > 0 then
        combo = 0
        multiplier_last_value = 1.0
        combo_multiplier = 1.0
        multiplier_flash_timer = 10
        _log("combo_broken")
      end

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

    -- play wave start sound on first spawn of new wave
    if wave_count > 1 and enemies_killed == 0 and enemy_spawn_timer == 29 then
      sfx(3)  -- wave start cue
    end

    -- difficulty-based spawn rates with progressive scaling
    local spawn_rate = 30 - (wave_count - 1) * 2
    if difficulty == 1 then
      spawn_rate = 45 - flr(wave_count * 1.5)  -- easier: slower spawns
    elseif difficulty == 3 then
      spawn_rate = 18 - wave_count  -- harder: faster spawns
    end
    spawn_rate = max(5, spawn_rate)  -- clamp minimum

    if enemy_spawn_timer <= 0 then
      -- spawn enemy based on difficulty
      local etype = spawn_enemy_type()
      local spd = get_enemy_speed(etype)
      -- scale speed by wave and difficulty
      spd = spd * (1 + (wave_count - 1) * 0.1)
      if difficulty == 1 then spd *= 0.8
      elseif difficulty == 3 then spd *= 1.2 end
      -- tank enemies have 2 health, others have 1
      local health = etype == 3 and 2 or 1
      spawn_enemy_with_fade(rnd(120)+4, 4, etype, spd, health)
      _log("spawn:type"..etype)
      enemy_spawn_timer = spawn_rate
    end

    -- update enemies
    for e in all(enemies) do
      -- handle spawn fade-in
      if e.fade_timer then
        e.fade_timer -= 1
      end

      -- type-specific movement
      if e.type == 4 then
        -- weaver: sine-wave pattern
        local sine_offset = sin(e.y / 16 + e.x / 64) * 2
        e.x += sine_offset
        e.x = mid(4, e.x, 124)  -- clamp to bounds
      elseif e.type == 5 then
        -- scout: erratic zigzag
        e.zag_timer += 1
        if e.zag_timer % 8 == 0 then
          e.zag_dir = 1 - e.zag_dir
        end
        if e.zag_dir == 0 then
          e.x -= 0.7
        else
          e.x += 0.7
        end
        e.x = mid(4, e.x, 124)  -- clamp to bounds
      end

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

          -- handle enemy hit
          e.health -= 1

          -- visual feedback on hit
          local hit_colors = {8, 10, 14}  -- cyan, red, yellow
          create_explosion(e.x, e.y, 2, 1, hit_colors[e.type])
          trigger_flash(7)
          sfx(0)

          if e.health <= 0 then
            -- enemy dies
            e.alive = false

            -- increment combo on kill
            combo += 1
            local new_multiplier = calc_combo_multiplier()
            if new_multiplier > multiplier_last_value then
              multiplier_flash_timer = 10  -- flash on increase
              combo_pulse_timer = 15  -- pulse animation
              -- play combo milestone sounds at thresholds
              if combo == 5 or combo == 10 or combo == 15 or combo == 20 then
                sfx(5)  -- combo milestone
                trigger_shake(3)  -- intense shake on milestone
                create_explosion(player.x, player.y, 8, 2, 11)  -- bonus feedback
              end
            end
            multiplier_last_value = new_multiplier
            combo_multiplier = new_multiplier

            -- scoring based on type (1:straight 50, 2:fast 75, 3:tank 150, 4:weaver 75, 5:scout 25)
            local points = 0
            if e.type == 1 then
              points = 50
            elseif e.type == 2 then
              points = 75
            elseif e.type == 3 then
              points = 150
            elseif e.type == 4 then
              points = 75
            else  -- type 5 scout
              points = 25
            end
            local earned_points = flr(points * score_multiplier * combo_multiplier)
            score += earned_points

            -- visual feedback on kill with type-specific effects
            local kill_colors = {8, 10, 14, 6, 11}  -- cyan, red, gray, purple, yellow
            local kill_count = {4, 5, 8, 5, 3}      -- explosion particles per type
            create_explosion(e.x, e.y, kill_count[e.type] or 4, 2, kill_colors[e.type] or 7)
            trigger_shake(2)
            trigger_flash(11)
            enemies_killed += 1
            -- type-specific death sounds (reuse existing sounds)
            local death_sound = e.type == 2 and 0 or (e.type == 3 and 2 or (e.type == 5 and 0 or 1))
            sfx(death_sound)
            create_score_popup(e.x, e.y, earned_points)  -- show score
            _log("kill:enemy:type"..e.type..",combo:"..combo.."x")
            _log("score:"..earned_points..",combo:"..combo.."x")

            -- spawn power-up from destroyed enemy
            spawn_powerup(e.x, e.y, e.type)
          else
            _log("hit:enemy:type"..e.type)
          end

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
          -- break combo on shield use
          if combo > 0 then
            combo = 0
            multiplier_last_value = 1.0
            combo_multiplier = 1.0
            multiplier_flash_timer = 10
            _log("combo_broken")
          end
        else
          lives -= 1
          create_explosion(player.x, player.y, 8, 1, 10)  -- red flash
          trigger_shake(3)
          trigger_flash(10)
          sfx(1)
          _log("collision:enemy")
          -- break combo on damage
          if combo > 0 then
            combo = 0
            multiplier_last_value = 1.0
            combo_multiplier = 1.0
            multiplier_flash_timer = 10
            _log("combo_broken")
          end

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
    -- add wave completion bonus with combo multiplier
    local wave_bonus_base = enemies_killed * 5
    local wave_bonus = flr(wave_bonus_base * score_multiplier * combo_multiplier)
    score += wave_bonus
    _log("wave_bonus:"..wave_bonus..",combo:"..combo.."x")

    sfx(5)  -- wave complete stinger
    trigger_shake(2)  -- strong shake on wave complete
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
    -- add boss defeat bonus with combo multiplier
    local boss_bonus_base = 500
    local boss_bonus = flr(boss_bonus_base * score_multiplier * combo_multiplier)
    score += boss_bonus
    _log("boss_bonus:"..boss_bonus..",combo:"..combo.."x")

    music(-1)  -- stop music
    sfx(8)     -- victory stinger
    trigger_shake(3)  -- intense victory shake
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

function spawn_enemy_with_fade(x, y, etype, spd, health)
  -- spawn with fade-in animation
  local e = {x=x, y=y, type=etype, speed=spd, health=health, fade_timer=10, fade_max=10, alive=true}
  -- initialize movement tracking for special types
  if etype == 5 then  -- scout
    e.zag_dir = rnd(1) > 0.5 and 1 or 0
    e.zag_timer = 0
  end
  add(enemies, e)
end

function spawn_powerup(x, y, enemy_type)
  -- drop chance varies by difficulty: give more help on easy mode
  local base_chance = enemy_type == 1 and 0.15 or 0.25
  local drop_chance = base_chance
  if difficulty == 1 then
    drop_chance = base_chance * 1.3  -- 20% to 33% on easy
  elseif difficulty == 3 then
    drop_chance = base_chance * 0.7  -- 10% to 17% on hard
  end

  if rnd(1) < drop_chance then
    -- pick random powerup: 1=shield, 2=rapid-fire, 3=health, 4=mega-shot (rare)
    local r = rnd(100)
    local pu_type = 1
    if r < 60 then pu_type = 1
    elseif r < 80 then pu_type = 2
    elseif r < 95 then pu_type = 3
    else pu_type = 4 end  -- 5% chance for mega-shot
    add(powerups, {x=x, y=y, type=pu_type, age=0, alive=true})
    _log("powerup:spawn:"..pu_type)
  end
end

function apply_powerup(pu_type)
  local pu_points = 100
  local earned_points = flr(pu_points * score_multiplier * combo_multiplier)
  score += earned_points

  -- play different sound for each powerup type
  if pu_type == 1 then
    -- shield: absorbs one collision (max 3)
    if shield_count < 3 then
      shield_count += 1
      sfx(3)  -- shield pickup sound
      _log("shield_pickup:"..shield_count)
    else
      _log("shield_full")
    end
  elseif pu_type == 2 then
    -- rapid fire: doubles fire rate for 5 seconds (300 frames)
    rapid_fire_timer = 300
    sfx(4)  -- rapid fire sound
    _log("rapidfire_pickup:5s")
  elseif pu_type == 3 then
    -- health: restores one lost life (max 3)
    if lives < 3 then
      lives += 1
      create_explosion(player.x, player.y, 8, 1, 11)  -- green particle burst
      sfx(5)  -- health pickup sound
      _log("health_pickup:"..lives)
    else
      _log("health_full")
    end
  elseif pu_type == 4 then
    -- mega-shot: triple fire for 3 seconds (180 frames)
    mega_shot_timer = 180
    sfx(6)  -- distinctive sound for rare power-up
    _log("megashot_pickup:3s")
  end
  _log("powerup_score:"..earned_points..",combo:"..combo.."x")
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
  -- visual feedback: screen shake on volley
  trigger_shake(1)
  -- particles at boss
  create_explosion(boss.x, boss.y, 3, 0.5, 8)
end

function boss_charge()
  if not boss then return end
  local dx = player.x - boss.x
  local accel = difficulty == 1 and 0.5 or (difficulty == 2 and 0.8 or 1.2)
  if dx > 0 then boss.dir = 1 else boss.dir = -1 end
  boss.speed = 2 * accel
  boss.charge_timer = 30 + difficulty * 10
  sfx(6)  -- distinct charge sound
  -- visual warning: intense shake
  trigger_shake(2)
  -- flash screen red
  trigger_flash(8)
  boss_attack_warning = 20  -- wind-up animation
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
  sfx(7)  -- spiral attack sound
  -- visual feedback
  trigger_shake(1)
  create_explosion(boss.x, boss.y, 4, 1, 13)  -- purple spiral particles
  boss_attack_warning = 15
end

function del_boss_projectiles()
  for i=#boss_projectiles,1,-1 do
    if not boss_projectiles[i].alive then
      del(boss_projectiles, boss_projectiles[i])
    end
  end
end

function _update()
  -- update music state based on current game state
  update_music_state()

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

  print("tips:", 40, 80, 6)
  print("combo for multiplier!", 15, 88, 11)
  print("survive 5 waves for boss", 10, 96, 10)

  print("press z to start", 25, 110, 11)
end

function draw_difficulty()
  cls(0)
  print("select difficulty", 30, 20, 7)

  -- draw difficulty options with descriptions
  local y = 45
  local descriptions = {"few enemies", "normal pace", "hard mode"}
  local desc_cols = {3, 7, 8}  -- green, white, red
  for i=1,3 do
    local col = difficulty_selected == i and 11 or 7
    local marker = difficulty_selected == i and "> " or "  "
    print(marker..difficulty_names[i], 40, y, col)
    print(descriptions[i], 35, y+8, desc_cols[i])
    y += 18
  end

  print("left/right to change", 20, 100, 6)
  print("z to confirm", 35, 110, 6)
end

function draw_wave_complete()
  cls(0)
  print("wave "..wave_count.." complete!", 25, 20, 11)
  print("enemies killed: "..enemies_killed, 20, 35, 7)

  -- show difficulty scaling info
  local mult_display = "x"..difficulty
  if difficulty == 1 then mult_display = "x1.0"
  elseif difficulty == 2 then mult_display = "x1.5"
  else mult_display = "x2.0" end
  print("difficulty: "..mult_display, 28, 45, 6)

  print("wave bonus: +"..flr(enemies_killed * 5), 25, 60, 10)

  local next_mult = "x"..flr(combo_multiplier * 10) / 10
  print("combo: "..next_mult, 38, 70, 11)

  if wave_count < 5 then
    print("next: wave "..(wave_count+1), 30, 85, 7)
  else
    print("next: boss battle!", 30, 85, 9)
  end

  print("press z to continue", 20, 110, 11)
end

function draw_boss_defeated()
  cls(0)
  print("boss defeated!", 30, 10, 11)
  print("victory!", 45, 22, 10)
  print("final score: "..score, 28, 35, 7)
  print("enemies: "..enemies_killed, 30, 43, 7)
  print("waves: "..wave_count, 38, 51, 7)
  local diff_text = difficulty_names[difficulty]
  print("difficulty: "..diff_text, 25, 59, 6)
  local max_mult = "x"..flr(combo_multiplier * 10) / 10
  print("max combo: "..max_mult, 28, 67, 11)

  print("press z to finish", 25, 110, 11)
end

function draw_play()
  -- background color changes by wave for visual progression
  local bg_color = 0
  if wave_count >= 5 then
    bg_color = 1  -- darker for boss waves
  end
  cls(bg_color)

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

  -- draw shield aura when shield is active
  if shield_count > 0 then
    circ(player.x, player.y, 6 + sin(enemy_anim_frame / 30) * 1, 3)  -- cyan shield ring
  end

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

  -- draw score popups (floating text)
  for sp in all(score_popups) do
    local alpha = 1 - (sp.age / sp.lifetime)
    local col = 11  -- yellow text
    if alpha > 0.7 then
      print("+"..sp.points, flr(sp.x)-4, flr(sp.y), col)
    elseif alpha > 0.3 then
      -- fade out effect: only print every other frame
      if flr(sp.age) % 2 == 0 then
        print("+"..sp.points, flr(sp.x)-4, flr(sp.y), col)
      end
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
    elseif pu.type == 4 then
      spr(4, flr(pu.x)-4, flr(pu.y)-4)  -- mega-shot (reuse projectile sprite)
      -- add bright glow for rare power-up
      if pu.age % 3 == 0 then
        circ(flr(pu.x), flr(pu.y), 5, 12)
      end
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
    -- boss introduction effect: dramatic flash and pulsing glow
    if boss_intro_timer > 0 then
      local flash_intensity = flr((boss_intro_timer / 60) * 16)
      for i=1,flash_intensity do
        circ(boss.x, boss.y, i+5, 8)
      end
    end

    -- draw boss sprite with flash effect when hit
    local boss_sprite = boss_phase_timer > 0 and 8 or 3
    spr(boss_sprite, boss.x-4, boss.y-4)

    -- boss aura glow - pulsing
    local aura_size = 5 + flr(sin(boss_phase_timer / 15) * 2)
    circ(boss.x, boss.y, aura_size, 5)

    -- attack wind-up warning: intense red aura
    if boss_attack_warning > 0 then
      local warn_size = 8 + (20 - boss_attack_warning) / 2
      circ(boss.x, boss.y, warn_size, 8)  -- red warning ring
      if boss_attack_warning % 2 == 0 then
        circ(boss.x, boss.y, warn_size - 2, 2)  -- flash white center
      end
      boss_attack_warning -= 1
    end

    -- additional hit flash
    if boss_phase_timer > 0 and boss_phase_timer % 2 == 0 then
      circ(boss.x, boss.y, 6, 12)
    end
  else
    -- draw regular enemies with type-specific visuals
    for e in all(enemies) do
      local bob = sin(enemy_anim_frame / 30 + (e.x + e.y) / 20) * 0.5
      local draw_y = e.y - 4 + bob

      -- apply fade-in effect during spawn
      local fade_alpha = 1
      if e.fade_timer then
        fade_alpha = 1 - (e.fade_timer / e.fade_max)
      end

      -- skip drawing if fading in but not visible yet
      if fade_alpha < 0.1 then
        goto skip_enemy_draw
      end

      if e.type == 1 then
        -- straight: cyan colored
        spr(1, e.x-4, draw_y)
      elseif e.type == 2 then
        -- fast: red with speed indicator
        spr(2, e.x-4, draw_y)
        line(e.x+1, e.y-1, e.x+3, e.y-1, 10)
      elseif e.type == 3 then
        -- tank: gray with health dots
        spr(2, e.x-4, draw_y)
        if e.health and e.health == 2 then
          pset(e.x-2, draw_y-2, 14)
          pset(e.x+1, draw_y-2, 14)
        else
          pset(e.x-2, draw_y-2, 14)
        end
      elseif e.type == 4 then
        -- weaver: purple with wavy pattern
        spr(1, e.x-4, draw_y)
        -- wave indicator: vertical line
        pset(e.x, draw_y-3, 13)
        pset(e.x, draw_y+2, 13)
      else
        -- scout (type 5): yellow, small, zigzag
        spr(1, e.x-4, draw_y)
        -- speed stripes
        line(e.x-2, e.y, e.x+2, e.y, 11)
      end

      ::skip_enemy_draw::
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

  -- draw ui (over flash) - color coded by difficulty
  local hud_col = 7  -- default white
  if difficulty == 1 then
    hud_col = 3  -- green for easy
  elseif difficulty == 2 then
    hud_col = 7  -- white for normal
  else
    hud_col = 8  -- red for hard
  end

  -- boss intro text if boss just spawned
  if boss_intro_timer > 30 then
    print("boss wave!", 35, 40, 8)
  end

  print("score: "..score, 5, 5, hud_col)
  print("lives: "..lives, 5, 12, hud_col)
  print("wave: "..wave_count, 5, 19, hud_col)

  -- draw active power-ups
  local pu_y = 26
  if shield_count > 0 then
    print("shield:"..shield_count, 5, pu_y, 3)
    pu_y += 7
  end
  if rapid_fire_timer > 0 then
    local sec = flr(rapid_fire_timer / 60) + 1
    print("rapid "..sec.."s", 5, pu_y, 10)
    pu_y += 7
  end
  if mega_shot_timer > 0 then
    local sec = flr(mega_shot_timer / 60) + 1
    print("mega x3", 5, pu_y, 11)
  end

  -- draw boss health if in boss wave
  if boss then
    print("boss hp: "..boss.health, 85, 5, 10)
  end

  -- draw combo multiplier in bottom-right with pulsing effect
  local multiplier_text = "x"..flr(combo_multiplier * 10) / 10
  local multiplier_color = 7  -- default white
  if combo_multiplier >= 5.0 then
    multiplier_color = 8  -- red for max bonus
  elseif combo_multiplier >= 3.0 then
    multiplier_color = 10  -- orange/red for high bonus
  elseif combo_multiplier >= 2.0 then
    multiplier_color = 11  -- yellow for good bonus
  end

  -- flash effect when multiplier increases
  if multiplier_flash_timer > 0 then
    multiplier_color = 7  -- yellow/white flash
    multiplier_flash_timer -= 1
  end

  -- pulsing effect for combo
  local combo_scale = 1
  if combo_pulse_timer > 0 then
    combo_scale = 1 + sin(combo_pulse_timer / 5) * 0.15
    combo_pulse_timer -= 1
  end

  -- draw combo text with scale effect
  local x_off = flr((1 - combo_scale) * 4)
  print(multiplier_text, 115 + x_off, 120, multiplier_color)

  -- draw combo counter next to multiplier
  if combo > 0 then
    print("("..combo..")", 110, 112, 6)
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
00070000000c0000000e000000080800000000000000001000008808000000000000000000000000000000000000000000000000000000000000000000000000
00777000000c000000eee00000888800000100000011100008888880000000000000000000000000000000000000000000000000000000000000000000000000
07777700cc000ccc0eeeee0088888800011000000110000888888880000000000000000000000000000000000000000000000000000000000000000000000000
07777700cccccccceeeeeeee88888888011000000110000088888888000000000000000000000000000000000000000000000000000000000000000000000000
07777700cccccccceeeeeeee88888888011000000100000088888888000000000000000000000000000000000000000000000000000000000000000000000000
07777700cc000ccc0eeeee0088888800000000000000000888888880000000000000000000000000000000000000000000000000000000000000000000000000
00777000000c000000eee00000888800000000000000000008888880000000000000000000000000000000000000000000000000000000000000000000000000
00070000000c0000000e000000080800000000000000000000008808000000000000000000000000000000000000000000000000000000000000000000000000

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
010200002454325432543200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200001f441f441f441f441f441c441c441c440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010300000c4510450c4514450c450c451045100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400006c4507c4506c4507c4500c4500c45000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400003c4503c4503c4503c4501c4501c4500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200002844384432844384410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00040404
01 01050505
02 02070707
03 03080808
04 04090909
05 050a0a0a

