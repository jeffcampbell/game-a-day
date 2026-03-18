pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- breakout arcade brick breaker
-- 2026-03-18

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
max_level = 6  -- 5 regular levels + 1 boss
level_start_time = 0
music_playing = false
is_boss_level = false
ball_ready_to_launch = true  -- ball waits on paddle before first launch

-- paddle
paddle_x = 60
paddle_w = 32  -- start wider for better control
paddle_h = 8
paddle_y = 123

-- ball
balls = {}  -- table of active balls
ball_r = 4

-- visual effects
particles = {}
flash_timer = 0
shake_timer = 0
shake_x = 0
flash_color = 7
ball_trails = {}  -- store recent ball positions for trail effect
trail_update_counter = 0
paddle_hit_timer = 0  -- paddle hit animation

-- power-ups
power_ups = {}
active_power_ups = {}  -- table of active power-ups
expand_count = 0  -- track number of active expand power-ups
shield_active = false
shield_timer = 0
lasers = {}  -- laser projectiles

-- boss battle
boss = nil
boss_projectiles = {}
boss_entrance_time = 0

-- particle system
function add_particles(x, y, color, count)
  for i = 1, count do
    add(particles, {
      x = x, y = y,
      vx = (rnd(2) - 1) * 2,
      vy = (rnd(2) - 1) * 2 - 0.5,
      life = 20,
      color = color
    })
  end
end

function update_particles()
  for p in all(particles) do
    p.x += p.vx
    p.y += p.vy
    p.vy += 0.1  -- gravity
    p.life -= 1
    if p.life <= 0 then del(particles, p) end
  end
end

function draw_particles()
  for p in all(particles) do
    local brightness = p.life / 20
    if brightness > 0 then
      pset(p.x, p.y, p.color)
    end
  end
end

-- ball trail system
function update_paddle_hit()
  if paddle_hit_timer > 0 then
    paddle_hit_timer -= 1
  end
end

function update_ball_trails()
  trail_update_counter += 1
  -- capture trail every 2 frames
  if trail_update_counter >= 2 then
    trail_update_counter = 0
    for ball in all(balls) do
      add(ball_trails, {
        x = ball.x,
        y = ball.y,
        life = 15,
        max_life = 15
      })
    end
  end

  -- decay trails
  for trail in all(ball_trails) do
    trail.life -= 1
    if trail.life <= 0 then
      del(ball_trails, trail)
    end
  end
end

function draw_ball_trails()
  for trail in all(ball_trails) do
    local fade = trail.life / trail.max_life
    local trail_color = 5 + flr(fade * 2)  -- fade between color 5-7
    if fade > 0.3 then
      pset(trail.x, trail.y, trail_color)
      pset(trail.x - 1, trail.y, trail_color)
      pset(trail.x + 1, trail.y, trail_color)
    end
  end
end

function trigger_flash()
  flash_timer = 5
end

function trigger_shake(frames)
  shake_timer = frames
  shake_x = 0
end

-- enhanced visual effect: better destruction particles on brick hits
function burst_particles(x, y, color, count, spread)
  spread = spread or 2
  for i = 1, count do
    local angle = (i / count) * 6.28  -- spread around circle
    local speed = spread * (0.5 + rnd(0.5))
    add(particles, {
      x = x, y = y,
      vx = cos(angle / 6.28) * speed,
      vy = sin(angle / 6.28) * speed,
      life = 15 + rnd(8),
      color = color
    })
  end
end

-- bricks with type support
bricks = {}
function get_brick_type(lvl, rand_val)
  -- determine brick type based on level and random value
  -- progression: easy -> moderate -> hard -> very hard -> nightmare
  if lvl == 6 then
    return "normal"  -- boss level should never call this
  elseif lvl == 1 then
    -- level 1: ONLY normal bricks - learn basic mechanics
    return "normal"
  elseif lvl == 2 then
    -- level 2: introduce ice (slow ball)
    if rand_val < 0.8 then return "normal"
    else return "ice" end
  elseif lvl == 3 then
    -- level 3: add multi-hit bricks
    if rand_val < 0.6 then return "normal"
    elseif rand_val < 0.8 then return "ice"
    else return "multi_hit" end
  elseif lvl == 4 then
    -- level 4: introduce explosives
    if rand_val < 0.4 then return "normal"
    elseif rand_val < 0.6 then return "ice"
    elseif rand_val < 0.8 then return "multi_hit"
    else return "explosive" end
  elseif lvl == 5 then
    -- level 5: challenge with unbreakables
    if rand_val < 0.3 then return "normal"
    elseif rand_val < 0.5 then return "ice"
    elseif rand_val < 0.7 then return "multi_hit"
    elseif rand_val < 0.85 then return "explosive"
    else return "unbreakable" end
  end
end

function get_brick_sprite(typ)
  if typ == "ice" then return 3
  elseif typ == "explosive" then return 4
  elseif typ == "multi_hit" then return 5
  elseif typ == "unbreakable" then return 6
  else return 7 end  -- normal
end

function get_brick_color(typ, lvl)
  lvl = lvl or 1
  -- vary colors slightly based on level for visual progression
  if typ == "ice" then return (lvl > 3 and 12 or 11)
  elseif typ == "explosive" then return (lvl > 4 and 2 or 8)
  elseif typ == "multi_hit" then return (lvl > 3 and 13 or 10)
  elseif typ == "unbreakable" then return (lvl > 2 and 6 or 5)
  else return (lvl > 2 and 3 or 9) end  -- normal: level 1-2 yellow, then cyan
end

function get_boss_sprite(phase)
  if phase == 1 then return 8
  elseif phase == 2 then return 9
  else return 10 end
end

function get_boss_color(phase)
  if phase == 1 then return 7  -- white
  elseif phase == 2 then return 8  -- orange/red
  else return 2 end  -- red intense
end

function get_powerup_sprite(typ)
  if typ == "expand" then return 11
  elseif typ == "slow" then return 12
  elseif typ == "multi_ball" then return 13
  elseif typ == "laser" then return 14
  else return 15 end  -- shield
end

function init_boss()
  boss = {
    x = 64,
    y = 10,
    w = 16,
    h = 8,
    health = 18,  -- increased from 15 for better challenge
    max_health = 18,
    phase = 1,
    move_timer = 0,
    shoot_timer = 0
  }
  boss_projectiles = {}
  boss_entrance_time = 30
  is_boss_level = true
  _log("boss:spawn")
end

function init_bricks(lvl)
  bricks = {}
  local brick_w, brick_h = 8, 8
  local start_x, start_y = 8, 8
  local cols = 16
  local rows = lvl == 1 and 2 or (2 + lvl)  -- level 1: only 2 rows; others scale up

  -- distinct level layouts for visual variety
  local layout_pattern = lvl % 3  -- cycle through 3 patterns

  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      local skip = false

      -- level 1: full grid (no skips) - simplest layout
      if lvl > 1 then
        -- layout pattern 1: diagonal gaps
        if layout_pattern == 1 and (col + row) % 5 == 0 then
          skip = true
        -- layout pattern 2: checkerboard middle
        elseif layout_pattern == 2 and row > rows / 2 and (col + row) % 2 == 0 then
          skip = true
        end
      end

      if not skip then
        local typ = get_brick_type(lvl, rnd())
        add(bricks, {
          x = start_x + col * brick_w,
          y = start_y + row * brick_h,
          w = brick_w,
          h = brick_h,
          active = true,
          type = typ,
          color = get_brick_color(typ, lvl),
          health = (typ == "multi_hit") and 2 or 1
        })
      end
    end
  end
end

-- game functions
function init_ball(x, y, vx, vy)
  return {
    x = x, y = y, vx = vx, vy = vy,
    base_vx = vx, base_vy = vy,  -- store base velocity for slow power-up restoration
    slow_count = 0,  -- track active slow power-ups
    waiting_on_paddle = true  -- ball starts on paddle
  }
end

function reset_balls()
  -- reduce ball speed on level 1, gradually increase through levels
  local level_scale = (level - 1) * 0.2  -- 0, 0.2, 0.4, 0.6, 0.8, 1.0
  local base_vx = 0.8 + level_scale * 0.7
  local base_vy = -1.2 - level_scale * 0.8
  balls = {init_ball(64, 110, base_vx, base_vy)}
  active_power_ups = {}
  expand_count = 0
  shield_active = false
  shield_timer = 0
  lasers = {}
  boss_projectiles = {}
  ball_ready_to_launch = true
end

function update_menu()
  if not music_playing then
    -- loop menu music pattern
    music(0, 0, 3)
    music_playing = true
  end
  if btnp(4) or btnp(5) then  -- z or c to start
    _log("state:play")
    state = "play"
    score = 0
    lives = 3
    level = 1
    _log("level:"..level)
    init_bricks(level)
    reset_balls()
    level_start_time = t()
    is_boss_level = false
    music(1, 0, 3)  -- gameplay music
  end
end

function get_power_up_type(rand_val)
  -- adjust power-up distribution based on level for better progression
  if level == 1 then
    -- level 1: favor defensive power-ups
    if rand_val < 0.25 then return "expand"
    elseif rand_val < 0.65 then return "slow"
    else return "shield" end
  elseif level == 2 then
    -- level 2: mix of defensive and utility
    if rand_val < 0.3 then return "expand"
    elseif rand_val < 0.6 then return "slow"
    elseif rand_val < 0.8 then return "shield"
    else return "multi_ball" end
  else
    -- levels 3+: balanced mix
    if rand_val < 0.2 then return "expand"
    elseif rand_val < 0.4 then return "slow"
    elseif rand_val < 0.6 then return "multi_ball"
    elseif rand_val < 0.8 then return "laser"
    else return "shield" end
  end
end

function spawn_power_up(x, y, typ)
  local colors = {expand=12, slow=11, multi_ball=9, laser=11, shield=3}
  add(power_ups, {
    x = x, y = y, w = 4, h = 2,
    color = colors[typ] or 12,
    type = typ
  })
end

function update_boss()
  if not boss then return end

  -- handle boss entrance animation
  if boss_entrance_time > 0 then
    boss_entrance_time -= 1
    -- dramatic entrance effect with shaking
    if boss_entrance_time > 20 then
      trigger_shake(2)
      add_particles(boss.x + 6, boss.y + 4, 8, 2)
    elseif boss_entrance_time == 20 then
      _log("boss:ready")
      sfx(5)  -- boss entrance sound
    end
    return
  end

  boss.move_timer += 1
  boss.shoot_timer += 1

  local base_x = 64
  -- more aggressive movement pattern in later phases
  local amplitude = 24 - boss.phase * 4
  local move_speed = 25 - boss.phase * 3  -- faster movement in later phases
  boss.x = base_x + sin(boss.move_timer / move_speed) * amplitude

  local old_phase = boss.phase
  if boss.health > 12 then boss.phase = 1
  elseif boss.health > 6 then boss.phase = 2
  else boss.phase = 3 end

  if boss.phase > old_phase then
    _log("boss:phase"..boss.phase)
    trigger_shake(6)
    burst_particles(boss.x + 6, boss.y + 4, 2, 12, 2.5)  -- intense phase transition particles
    trigger_flash()
  end

  -- more aggressive shooting in later phases
  local shoot_freq = 85 - boss.phase * 20
  if boss.shoot_timer > shoot_freq then
    boss.shoot_timer = 0
    local proj_count = 5 + boss.phase
    for i = 1, proj_count do
      local offset_x = (i - proj_count/2) * 3
      add(boss_projectiles, {
        x = boss.x + 6 + offset_x,
        y = boss.y + 8,
        vx = (rnd() - 0.5) * (1.5 + boss.phase * 0.3),
        vy = 2 + boss.phase * 0.7,
        w = 2,
        h = 2
      })
    end
    sfx(2)
  end
end

function update_boss_projectiles()
  for proj in all(boss_projectiles) do
    proj.y += proj.vy
    proj.x += proj.vx

    if proj.y > 128 then
      del(boss_projectiles, proj)
    else
      if proj.y + proj.h > paddle_y and
         proj.y < paddle_y + paddle_h and
         proj.x + proj.w > paddle_x and
         proj.x < paddle_x + paddle_w then
        if shield_active then
          shield_active = false
          del(boss_projectiles, proj)
          add_particles(proj.x, proj.y, 3, 3)
          sfx(0)
        else
          del(boss_projectiles, proj)
          lives -= 1
          _log("hit_by_projectile:lives"..max(0, lives))
          add_particles(proj.x, proj.y, 8, 4)
          trigger_shake(3)
          sfx(4)
          if lives <= 0 then
            _log("state:gameover")
            state = "gameover"
          end
        end
      end
    end
  end
end

function update_play()
  update_particles()
  update_ball_trails()
  update_paddle_hit()

  -- boss level handling
  if is_boss_level then
    update_boss()
    update_boss_projectiles()
  end

  -- handle ball launch from paddle (waiting for player input)
  if ball_ready_to_launch then
    for ball in all(balls) do
      if ball.waiting_on_paddle then
        -- keep ball centered on paddle
        ball.x = paddle_x + paddle_w / 2
        ball.y = paddle_y - ball_r - 2

        -- launch on any directional input or button press
        if btnp(0) or btnp(1) or btnp(2) or btnp(3) or btnp(4) or btnp(5) then
          ball.waiting_on_paddle = false
          ball_ready_to_launch = false
          _log("ball:launch")
          sfx(0)
        end
      end
    end
  end

  -- update lasers and laser-brick collision
  for laser in all(lasers) do
    laser.y -= 3
    if laser.y < 0 then
      del(lasers, laser)
    else
      -- laser-brick collision
      for brick in all(bricks) do
        if brick.active and laser.x > brick.x and
           laser.x < brick.x + brick.w and
           laser.y > brick.y and
           laser.y < brick.y + brick.h then
          -- destroy brick with laser
          brick.active = false
          score += (brick.type == "multi_hit" and 25 or 15)
          add_particles(brick.x + 4, brick.y + 4, brick.color, 3)
          del(lasers, laser)
          break
        end
      end
    end
  end

  -- update shield timer
  if shield_active then
    shield_timer -= 1
    if shield_timer <= 0 then
      shield_active = false
    end
  end

  -- update active power-ups
  for pup in all(active_power_ups) do
    pup.timer -= 1
    if pup.timer <= 0 then
      del(active_power_ups, pup)
      -- restore paddle to normal size when expand expires
      if pup.type == "expand" then
        expand_count = max(0, expand_count - 1)
        local base_w = 32 - (level - 1) * 4
        paddle_w = min(48, max(8, base_w + expand_count * 8))
      -- restore ball velocity when slow expires
      elseif pup.type == "slow" then
        for ball in all(balls) do
          ball.slow_count = max(0, ball.slow_count - 1)
          -- recalculate velocity based on remaining slow count
          local slow_factor = 0.75 ^ ball.slow_count
          ball.vx = ball.base_vx * slow_factor
          ball.vy = ball.base_vy * slow_factor
        end
      end
    end
  end

  -- update power-ups (fall down, check paddle collision)
  for p in all(power_ups) do
    p.y += 1
    if p.y > 128 then
      del(power_ups, p)
    elseif p.y + p.h > paddle_y and
           p.y < paddle_y + paddle_h and
           p.x + p.w > paddle_x and
           p.x < paddle_x + paddle_w then
      -- collect power-up
      del(power_ups, p)
      add(active_power_ups, {type = p.type, timer = 300})
      score += 5  -- bonus points for collecting power-up
      add_particles(p.x, p.y, 10, 5)  -- visual feedback

      if p.type == "expand" then
        expand_count += 1
        local base_w = 32 - (level - 1) * 4
        paddle_w = min(48, max(8, base_w + expand_count * 8))  -- expand adds width but caps at 48
        sfx(5)  -- level up sound for expand
      elseif p.type == "slow" then
        for ball in all(balls) do
          ball.slow_count += 1
          -- recalculate velocity based on slow count
          local slow_factor = 0.75 ^ ball.slow_count
          ball.vx = ball.base_vx * slow_factor
          ball.vy = ball.base_vy * slow_factor
        end
        sfx(3)  -- different pitch for slow
      elseif p.type == "multi_ball" then
        for ball in all(balls) do
          local new_vx1 = ball.vx + 0.5
          local new_vy1 = ball.vy
          add(balls, {
            x=ball.x+2, y=ball.y, vx=new_vx1, vy=new_vy1,
            base_vx=ball.base_vx + 0.5, base_vy=ball.base_vy, slow_count=ball.slow_count
          })
          local new_vx2 = ball.vx - 0.5
          local new_vy2 = ball.vy
          add(balls, {
            x=ball.x-2, y=ball.y, vx=new_vx2, vy=new_vy2,
            base_vx=ball.base_vx - 0.5, base_vy=ball.base_vy, slow_count=ball.slow_count
          })
        end
        sfx(5)  -- celebratory sound for multi-ball
      elseif p.type == "shield" then
        shield_active = true
        shield_timer = 900  -- 15 seconds
        sfx(0)  -- positive sound for shield
      else
        sfx(0)
      end
    end
  end

  -- paddle movement
  if test_input(0) > 0 then
    paddle_x = max(0, paddle_x - 2)
  end
  if test_input(1) > 0 then
    paddle_x = min(128 - paddle_w, paddle_x + 2)
  end

  -- ball movement and collision detection for all balls
  for ball in all(balls) do
    -- skip physics if ball is waiting on paddle
    if ball.waiting_on_paddle then
      goto ball_update_skip
    end

    local orig_vx, orig_vy = ball.vx, ball.vy
    ball.x += ball.vx
    ball.y += ball.vy

    -- wall collisions
    if ball.x - ball_r < 0 or ball.x + ball_r > 128 then
      ball.vx *= -1
      ball.x = mid(ball_r, ball.x, 128 - ball_r)
      trigger_flash()
      trigger_shake(3)
      flash_color = 7
      sfx(1)
    end

    if ball.y - ball_r < 0 then
      ball.vy *= -1
      ball.y = ball_r
      trigger_flash()
      trigger_shake(2)
      flash_color = 7
      sfx(1)
    end

    -- paddle collision
    if ball.vy > 0 and
       ball.y + ball_r > paddle_y and
       ball.y < paddle_y + paddle_h and
       ball.x > paddle_x and
       ball.x < paddle_x + paddle_w then
      ball.vy = -abs(ball.vy)
      ball.y = paddle_y - ball_r
      local hit_pos = (ball.x - paddle_x) / paddle_w
      ball.vx = (hit_pos - 0.5) * 3
      trigger_flash()
      trigger_shake(3)
      flash_color = 7
      -- add paddle impact particles
      add_particles(ball.x, ball.y, 7, 3)
      paddle_hit_timer = 4  -- visual feedback on paddle hit
      sfx(0)

      -- laser paddle effect
      for pup in all(active_power_ups) do
        if pup.type == "laser" then
          add(lasers, {x=paddle_x + 4, y=paddle_y})
          add(lasers, {x=paddle_x + paddle_w - 4, y=paddle_y})
        end
      end
    end

    -- boss collision (on boss level)
    if is_boss_level and boss and boss_entrance_time <= 0 then
      if ball.x > boss.x - boss.w/2 and
         ball.x < boss.x + boss.w/2 and
         ball.y > boss.y and
         ball.y < boss.y + boss.h then
        -- hit the boss!
        boss.health -= 1
        _log("boss:hit:health"..boss.health)
        score += 50
        burst_particles(boss.x + 6, boss.y + 4, 9, 8, 1.8)
        trigger_shake(3)
        trigger_flash()
        flash_color = 9
        sfx(3)

        -- bounce ball away from boss
        local dx = abs(ball.x - boss.x)
        local dy = abs(ball.y - (boss.y + boss.h/2))
        if dx > dy then ball.vx *= -1
        else ball.vy *= -1 end
      end
    end

    -- brick collisions
    for brick in all(bricks) do
      if brick.active then
        if ball.x > brick.x and
           ball.x < brick.x + brick.w and
           ball.y > brick.y and
           ball.y < brick.y + brick.h then

          -- handle ice brick (slow ball)
          if brick.type == "ice" then
            ball.vx *= 0.7
            ball.vy *= 0.7
            flash_color = 11
            add_particles(brick.x + 4, brick.y + 4, 12, 3)  -- extra ice particles
          elseif brick.type == "explosive" then
            flash_color = 8
            add_particles(brick.x + 4, brick.y + 4, 8, 2)  -- pre-explosion particles
          end

          -- multi-hit brick logic
          if brick.type == "multi_hit" then
            brick.health -= 1
            if brick.health <= 0 then
              brick.active = false
              score += 20
              _log("brick_destroyed:score"..score)
              burst_particles(brick.x + 4, brick.y + 4, brick.color, 8, 1.5)
            else
              -- show damage (no point added yet)
              add_particles(brick.x + 4, brick.y + 4, 1, 2)
              trigger_flash()
              sfx(2)
              -- bounce
              local dx = abs(ball.x - (brick.x + brick.w/2))
              local dy = abs(ball.y - (brick.y + brick.h/2))
              if dx > dy then ball.vx *= -1
              else ball.vy *= -1 end
              break
            end
          elseif brick.type == "unbreakable" then
            -- just bounce, don't destroy
            local dx = abs(ball.x - (brick.x + brick.w/2))
            local dy = abs(ball.y - (brick.y + brick.h/2))
            if dx > dy then ball.vx *= -1
            else ball.vy *= -1 end
            trigger_flash()
            sfx(2)
            break
          elseif brick.type ~= "multi_hit" then
            brick.active = false
            score += 10
            _log("brick_destroyed:score"..score)
            burst_particles(brick.x + 4, brick.y + 4, brick.color, 6, 1.5)

            -- handle explosive brick chain reaction
            if brick.type == "explosive" then
              burst_particles(brick.x + 4, brick.y + 4, 8, 10, 2)
              trigger_shake(3)
              -- destroy adjacent bricks in 3x3
              for adj in all(bricks) do
                if adj.active and abs(adj.x - brick.x) <= 8 and
                   abs(adj.y - brick.y) <= 8 then
                  if adj != brick then
                    adj.active = false
                    score += (adj.type == "multi_hit" and 20 or 10)
                    add_particles(adj.x + 4, adj.y + 4, adj.color, 4)
                    -- chain reaction for explosives
                    if adj.type == "explosive" then
                      add_particles(adj.x + 4, adj.y + 4, 8, 8)
                    end
                  end
                end
              end
            end
          end

          trigger_flash()
          trigger_shake(1)

          -- spawn power-up based on brick type (more generous on level 1)
          local spawn_chance = level == 1 and 0.15 or 0.1
          if brick.type == "ice" then spawn_chance = 0.05
          elseif brick.type == "explosive" then spawn_chance = 0.08
          elseif brick.type == "multi_hit" then spawn_chance = 0.12 end

          if rnd() < spawn_chance then
            spawn_power_up(brick.x + 4, brick.y + 4, get_power_up_type(rnd()))
          end

          -- bounce direction
          if brick.type ~= "unbreakable" or brick.active then
            local dx = abs(ball.x - (brick.x + brick.w/2))
            local dy = abs(ball.y - (brick.y + brick.h/2))
            if dx > dy then ball.vx *= -1
            else ball.vy *= -1 end
          end

          sfx(2)
          break
        end
      end
    end

    -- lose life if ball falls off bottom
    if ball.y > 128 then
      if shield_active then
        shield_active = false
        ball.y = paddle_y - ball_r
        ball.vy = -abs(ball.vy)
        sfx(0)
      else
        del(balls, ball)
      end
    end

    ::ball_update_skip::
  end

  -- check if all balls are lost
  if #balls == 0 then
    _log("life_lost:lives"..max(0, lives - 1))
    lives -= 1
    if lives <= 0 then
      _log("state:gameover")
      state = "gameover"
      sfx(4)
    else
      reset_balls()
      -- scale ball velocity by current level to maintain difficulty
      local base_vx = 1.5 + level * 0.4
      local base_vy = -2 - level * 0.3
      for ball in all(balls) do
        ball.base_vx = base_vx
        ball.base_vy = base_vy
        ball.vx = base_vx
        ball.vy = base_vy
      end
      sfx(3)
    end
  end

  -- boss defeat condition
  if is_boss_level and boss and boss.health <= 0 then
    _log("boss:defeated")
    _log("state:gameover")
    _log("gameover:win")
    state = "gameover"
    score *= 2  -- 2x multiplier for boss victory
    -- massive explosion effect on boss defeat
    burst_particles(boss.x + 6, boss.y + 4, 9, 16, 3)
    burst_particles(boss.x + 2, boss.y - 2, 8, 12, 2.5)
    trigger_shake(10)
    trigger_flash()
    flash_color = 9
    sfx(5)
  end

  -- level complete condition
  local bricks_left = 0
  for brick in all(bricks) do
    if brick.active and brick.type ~= "unbreakable" then
      bricks_left += 1
    end
  end

  if bricks_left == 0 and not is_boss_level then
    if level < max_level then
      -- advance to next level
      _log("level_complete:"..level)
      level += 1
      _log("level:"..level)

      -- visual feedback for level complete
      trigger_shake(8)
      trigger_flash()
      flash_color = 11
      burst_particles(64, 64, 11, 12, 2)

      -- check if this is the boss level
      if level == 6 then
        init_boss()
        music(2, 0, 3)  -- boss battle music
      else
        init_bricks(level)
      end

      -- reset power-ups on level transition
      active_power_ups = {}
      expand_count = 0
      shield_active = false
      lasers = {}

      -- difficulty scaling (resets to base width)
      local base_w = 32 - (level - 1) * 4  -- level 1: 32, level 2: 28, etc
      paddle_w = max(16, base_w)

      -- increase ball speed
      local base_vx = 1.5 + level * 0.4
      local base_vy = -2 - level * 0.3
      for ball in all(balls) do
        ball.base_vx = base_vx
        ball.base_vy = base_vy
        ball.slow_count = 0  -- reset slow count on level transition
        ball.vx = base_vx
        ball.vy = base_vy
      end

      -- reset position
      for ball in all(balls) do
        ball.x = 64
        ball.y = 110
      end
      level_start_time = t()
      sfx(5)
    else
      -- all levels complete - win!
      _log("state:gameover")
      _log("gameover:win")
      state = "gameover"
      sfx(5)
    end
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
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function draw_menu()
  cls(0)
  print("breakout", 50, 10, 7)
  print("brick breaker", 45, 20, 7)

  -- instructions
  print("arrow keys:", 20, 35, 11)
  print("move paddle", 35, 35, 7)
  print("z / c to launch", 25, 45, 11)
  print("and play", 50, 45, 7)

  -- level preview
  print("6 levels to master", 28, 60, 10)
  print("including boss battle", 18, 70, 10)

  print("press z/c to start", 28, 95, 11)
end

function draw_play()
  cls(0)

  -- update shake effect
  if shake_timer > 0 then
    shake_x = rnd(3) - 1.5
    shake_timer -= 1
  else
    shake_x = 0
  end

  -- apply camera shake with some vertical variation for dynamics
  local shake_y = flr(rnd(2)) - 0.5
  camera(shake_x, shake_y)

  -- draw bricks using sprites
  for brick in all(bricks) do
    if brick.active then
      local sprite_idx = get_brick_sprite(brick.type)
      spr(sprite_idx, brick.x, brick.y, 1, 1)
    end
  end

  -- draw boss using sprite with phase variation
  if is_boss_level and boss then
    local sprite_idx = get_boss_sprite(boss.phase)
    local boss_col = get_boss_color(boss.phase)
    spr(sprite_idx, boss.x - 8, boss.y, 2, 1)

    -- phase indicator aura
    if boss.phase > 1 then
      circfill(boss.x, boss.y + 4, 10, boss_col)
    end

    -- boss health bar above it
    local health_pct = boss.health / boss.max_health
    rectfill(boss.x - 8, boss.y - 4, boss.x + 8, boss.y - 2, 0)
    local bar_color = (boss.phase == 3 and 2) or (boss.phase == 2 and 8) or 11
    rectfill(boss.x - 8, boss.y - 4, boss.x - 8 + health_pct * 16, boss.y - 2, bar_color)
  end

  -- draw paddle using sprites with hit animation
  spr(0, paddle_x, paddle_y, 2, 1)
  -- visual highlight when paddle hits ball
  if paddle_hit_timer > 0 then
    local highlight_color = 11 + (paddle_hit_timer % 2)
    line(paddle_x, paddle_y - 1, paddle_x + paddle_w, paddle_y - 1, highlight_color)
  end

  -- draw shield if active
  if shield_active then
    local shield_y = paddle_y - 4
    circfill(paddle_x + paddle_w/2, shield_y, 6, 3)
  end

  -- draw boss projectiles as sprites with visual effects
  for proj in all(boss_projectiles) do
    spr(16, proj.x - 2, proj.y - 2, 1, 1)
    -- add trailing effect for projectiles
    circfill(proj.x, proj.y - 4, 2, 8)
  end

  -- draw lasers
  for laser in all(lasers) do
    line(laser.x, laser.y, laser.x, laser.y + 4, 11)
    line(laser.x - 1, laser.y + 1, laser.x - 1, laser.y + 3, 11)
    line(laser.x + 1, laser.y + 1, laser.x + 1, laser.y + 3, 11)
  end

  -- draw ball trail (before balls so it appears behind)
  draw_ball_trails()

  -- draw balls with direction-based animation
  for ball in all(balls) do
    local ball_sprite_x = ball.x - 4
    local ball_sprite_y = ball.y - 4
    -- sprite 2 is the ball, add slight visual emphasis based on speed
    local is_fast = abs(ball.vx) > 2 or abs(ball.vy) > 2
    spr(2, ball_sprite_x, ball_sprite_y, 1, 1)

    -- draw waiting indicator if ball on paddle
    if ball.waiting_on_paddle then
      circfill(ball.x, ball.y, 5, 11)  -- outer circle
      circfill(ball.x, ball.y, 3, 7)   -- inner highlight
      circfill(ball.x, ball.y, 2, 11)  -- pulsing effect
    elseif is_fast and flash_timer == 0 then
      -- add glow effect if ball is moving fast
      circfill(ball.x, ball.y, 3, 11 + flr(sin(t() * 4) * 2))
    end
  end

  -- draw power-ups using sprites with animation
  for p in all(power_ups) do
    local bob = sin(t() * 4) * 2
    local sprite_idx = get_powerup_sprite(p.type)
    spr(sprite_idx, p.x - 4, p.y - 2 + bob, 1, 1)
  end

  -- draw particles
  draw_particles()

  -- flash effect with color
  if flash_timer > 0 then
    fillp(0x5a5a)
    rectfill(0, 0, 128, 128, flash_color)
    fillp()
    flash_timer -= 1
  end

  camera()

  -- hud
  print("score:"..score, 2, 2, 7)
  print("lv:"..level, 50, 2, (is_boss_level and 8 or 7))
  print("lives:"..lives, 100, 2, 7)

  -- show boss health if on boss level
  if is_boss_level and boss then
    print("boss:"..boss.health.."/"..boss.max_health, 30, 12, get_boss_color(boss.phase))
  end

  -- show active power-ups with count
  local pup_display = ""
  local exp_count = 0
  local has_slow = false
  local has_laser = false

  for pup in all(active_power_ups) do
    if pup.type == "expand" then exp_count += 1
    elseif pup.type == "slow" then has_slow = true
    elseif pup.type == "laser" then has_laser = true end
  end

  if exp_count > 0 then pup_display = "exp:"..exp_count.." " end
  if has_slow then pup_display = pup_display.."slow " end
  if has_laser then pup_display = pup_display.."las:"..#lasers end

  if pup_display ~= "" then
    print(pup_display, 2, 120, 10)
  end

  if shield_active then
    print("shield", 85, 120, 3)
  end

  -- show ready/launch indicator if ball waiting
  if ball_ready_to_launch then
    print("ready!", 60, 60, 11)
  end

  -- level progress indicator (bottom right)
  local level_pct = (level - 1) / max_level
  rectfill(90, 122, 126, 126, 0)
  if level_pct > 0 then
    rectfill(90, 122, 90 + level_pct * 36, 126, (is_boss_level and 8 or 11))
  end
end

function draw_gameover()
  cls(0)

  local is_win = (level >= max_level and is_boss_level and boss and boss.health <= 0)

  if is_win then
    print("you win!", 50, 30, 11)
    print("boss defeated!", 40, 45, 8)
  else
    print("game over", 48, 30, 8)
    print("level "..level, 55, 45, 7)
  end

  print("score:"..score, 50, 65, 7)
  print("lives lost:"..max(0, 3 - lives), 40, 80, 8)
  print("press z to retry", 35, 100, 11)
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770077777700099990009a99a0a0bbbbb0008888008aaaaaa00c2222c000d5d5d0008880800966660099999900c0000c000c00c000a0a0a000f00f000f0
077777700777777000999900099900a0b0bb000088888008aaaa00000c2c20000d5d5000088888008666600099999000c0000c000c00c000a00a00f00f0f00f0f
077777700777777009aa9a00099aa0a0b0bb000088888008aaaa00000c2c200000d005000088888008660600099999000c0000c000c00c000a00a00f00f0f00f0f
077777700777777009aa9a00099aa0a0b0bb000088888008aaaa00000d2d000000d5d000088888008606000099999000c0000c000c00c000a0a0a00f00f0f00f0f
077777700777777009999900099900a0bbbbb0008888008aaaaaa000d5d5d00000d05000088880008966600099999000c0000c000c00c000a00a00f00f0f00f0f
07777770077777700099990009a99a0a0bbbbb0008888008aaaaaaa00c2222c000d5d5d0008880800966660099999900c0000c000c00c000a0a0a000f00f000f0
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
010100000a5000a5000a5000a5000a500050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000f5400f5400f5400f5400f5400f5400f5400f5400f5400f5400f5400f5400f5400f5400f5400f5400000000000000000000000000000000000000
001000000c2400c2400c2400c2400c2400c2400c2400c2400000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000003000030000300003000030000300003000030000300003000030000300003000000000000000000000000000000000000000000000000000000000
00010000005001050010500105001050010500105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000055001550015500155001550015500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__music__
00 00000000
01 01010101
02 02020202
03 03030303
