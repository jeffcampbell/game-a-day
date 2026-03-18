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

-- paddle
paddle_x = 60
paddle_w = 16
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

function trigger_flash()
  flash_timer = 5
end

function trigger_shake(frames)
  shake_timer = frames
  shake_x = 0
end

-- bricks with type support
bricks = {}
function get_brick_type(lvl, rand_val)
  -- determine brick type based on level and random value
  -- progression: easy -> moderate -> hard -> very hard -> nightmare
  if lvl == 6 then
    return "normal"  -- boss level should never call this
  elseif lvl == 1 then
    -- level 1: mostly normal, some ice to introduce mechanics
    if rand_val < 0.85 then return "normal"
    else return "ice" end
  elseif lvl == 2 then
    -- level 2: more ice and basic multi-hit
    if rand_val < 0.65 then return "normal"
    elseif rand_val < 0.85 then return "ice"
    else return "multi_hit" end
  elseif lvl == 3 then
    -- level 3: introduce explosive bricks
    if rand_val < 0.5 then return "normal"
    elseif rand_val < 0.7 then return "ice"
    elseif rand_val < 0.88 then return "explosive"
    else return "multi_hit" end
  elseif lvl == 4 then
    -- level 4: balanced mix with unbreakables
    if rand_val < 0.35 then return "normal"
    elseif rand_val < 0.52 then return "ice"
    elseif rand_val < 0.72 then return "explosive"
    elseif rand_val < 0.88 then return "multi_hit"
    else return "unbreakable" end
  else  -- level 5
    -- level 5: challenge with many special bricks
    if rand_val < 0.25 then return "normal"
    elseif rand_val < 0.4 then return "ice"
    elseif rand_val < 0.62 then return "explosive"
    elseif rand_val < 0.82 then return "multi_hit"
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

function get_brick_color(typ)
  if typ == "ice" then return 11
  elseif typ == "explosive" then return 8
  elseif typ == "multi_hit" then return 10
  elseif typ == "unbreakable" then return 5
  else return 9 end  -- normal
end

function get_boss_sprite(phase)
  if phase == 1 then return 8
  elseif phase == 2 then return 9
  else return 10 end
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
  local rows = 2 + lvl

  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      local typ = get_brick_type(lvl, rnd())
      add(bricks, {
        x = start_x + col * brick_w,
        y = start_y + row * brick_h,
        w = brick_w,
        h = brick_h,
        active = true,
        type = typ,
        color = get_brick_color(typ),
        health = (typ == "multi_hit") and 2 or 1
      })
    end
  end
end

-- game functions
function init_ball(x, y, vx, vy)
  return {
    x = x, y = y, vx = vx, vy = vy,
    base_vx = vx, base_vy = vy,  -- store base velocity for slow power-up restoration
    slow_count = 0  -- track active slow power-ups
  }
end

function reset_balls()
  balls = {init_ball(64, 110, 1.5, -2)}
  active_power_ups = {}
  expand_count = 0
  shield_active = false
  shield_timer = 0
  lasers = {}
  boss_projectiles = {}
end

function update_menu()
  if not music_playing then
    -- loop background music pattern
    music(1, 0, 3)
    music_playing = true
  end
  if btnp(4) then
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
  end
end

function get_power_up_type(rand_val)
  if rand_val < 0.3 then return "expand"
  elseif rand_val < 0.55 then return "slow"
  elseif rand_val < 0.75 then return "multi_ball"
  elseif rand_val < 0.9 then return "laser"
  else return "shield" end
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
    -- don't shoot or move during entrance
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
    add_particles(boss.x + 6, boss.y + 4, 9, 8)  -- phase transition particles
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

  -- boss level handling
  if is_boss_level then
    update_boss()
    update_boss_projectiles()
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
        paddle_w = max(8, 16 - level * 2 + expand_count * 8)
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

      if p.type == "expand" then
        expand_count += 1
        paddle_w = max(8, 16 - level * 2 + expand_count * 8)
      elseif p.type == "slow" then
        for ball in all(balls) do
          ball.slow_count += 1
          -- recalculate velocity based on slow count
          local slow_factor = 0.75 ^ ball.slow_count
          ball.vx = ball.base_vx * slow_factor
          ball.vy = ball.base_vy * slow_factor
        end
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
      elseif p.type == "shield" then
        shield_active = true
        shield_timer = 900  -- 15 seconds
      end
      sfx(0)
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
        add_particles(boss.x + 6, boss.y + 4, 9, 6)
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
          elseif brick.type == "explosive" then
            flash_color = 8
          end

          -- multi-hit brick logic
          if brick.type == "multi_hit" then
            brick.health -= 1
            if brick.health <= 0 then
              brick.active = false
              score += 20
              _log("brick_destroyed:score"..score)
              add_particles(brick.x + 4, brick.y + 4, brick.color, 4)
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
            add_particles(brick.x + 4, brick.y + 4, brick.color, 4)

            -- handle explosive brick chain reaction
            if brick.type == "explosive" then
              add_particles(brick.x + 4, brick.y + 4, 8, 8)
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

          -- spawn power-up based on brick type
          local spawn_chance = 0.1
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
    -- explosion effect on boss defeat
    add_particles(boss.x + 6, boss.y + 4, 9, 12)
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
      add_particles(64, 64, 11, 10)

      -- check if this is the boss level
      if level == 6 then
        init_boss()
      else
        init_bricks(level)
      end

      -- reset power-ups on level transition
      active_power_ups = {}
      expand_count = 0
      shield_active = false
      lasers = {}

      -- difficulty scaling (resets to base width)
      paddle_w = max(8, 16 - level * 2)

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
  print("breakout", 50, 30, 7)
  print("brick breaker", 45, 45, 7)
  print("press z to start", 38, 70, 11)
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

  camera(shake_x, 0)

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
    spr(sprite_idx, boss.x - 8, boss.y, 2, 1)
    -- boss health bar above it
    local health_pct = boss.health / boss.max_health
    rectfill(boss.x - 8, boss.y - 4, boss.x + 8, boss.y - 2, 0)
    rectfill(boss.x - 8, boss.y - 4, boss.x - 8 + health_pct * 16, boss.y - 2, 11)
  end

  -- draw paddle using sprites
  spr(0, paddle_x, paddle_y, 2, 1)

  -- draw shield if active
  if shield_active then
    local shield_y = paddle_y - 4
    circfill(paddle_x + paddle_w/2, shield_y, 6, 3)
  end

  -- draw boss projectiles as sprites
  for proj in all(boss_projectiles) do
    spr(16, proj.x - 2, proj.y - 2, 1, 1)
  end

  -- draw lasers
  for laser in all(lasers) do
    line(laser.x, laser.y, laser.x, laser.y + 4, 11)
    line(laser.x - 1, laser.y + 1, laser.x - 1, laser.y + 3, 11)
    line(laser.x + 1, laser.y + 1, laser.x + 1, laser.y + 3, 11)
  end

  -- draw balls
  for ball in all(balls) do
    local ball_sprite_x = ball.x - 4
    local ball_sprite_y = ball.y - 4
    spr(2, ball_sprite_x, ball_sprite_y, 1, 1)
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
  print("level:"..level, 50, 2, 7)
  print("lives:"..lives, 100, 2, 7)

  -- show boss health if on boss level
  if is_boss_level and boss then
    print("boss:"..boss.health.."/"..boss.max_health, 35, 2, 10)
  end

  -- show active power-ups
  local pup_str = ""
  for pup in all(active_power_ups) do
    if pup.type == "expand" then pup_str = "exp "..pup_str
    elseif pup.type == "slow" then pup_str = "slo "..pup_str
    elseif pup.type == "laser" then pup_str = "las "..pup_str end
  end
  if pup_str ~= "" then
    print(pup_str, 55, 120, 10)
  end

  -- show laser on active power-ups count
  if #lasers > 0 then
    print("laser:"..#lasers, 80, 120, 11)
  end
end

function draw_gameover()
  cls(0)

  if lives <= 0 then
    print("game over", 48, 40, 8)
  elseif level >= max_level then
    print("you win!", 50, 40, 11)
  else
    print("game over", 48, 40, 8)
  end

  print("score:"..score, 55, 60, 7)
  print("level:"..level, 50, 75, 7)
  print("press z", 52, 90, 7)
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ddddd0000ddddd0000aa00009999900ccccc00aaaaa00555555088888800aaaaaa00aaaaaa00dd00dd0088880088770000888880000000000000000000000000000
0ddddd0000ddddd000aaaa00098889009ccccc0aaaa000555555088888800aaaaaa00aaaaaa00dd00dd0088880088888000888880000000000000000000000000000
0ddddd0000ddddd000aaaa00098889009cc1cc0aaaa0005155150888a8800a1aa1a00a0aaa00dd00dd008aa8a088888000888880000000000000000000000000000
0ddddd0000ddddd0000aa00098889009ccccc0aaaa0005155150888a8800a0aaa0a0aa1a1aa00dd00dd008aa8a088888000888880000000000000000000000000000
00000000000000000000000009999900ccccc00aaaaa00555555088888800aaaaaa00aaaaaa00dd00dd0088880088770000888880000000000000000000000000000
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
00010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000005001050010500105001050010500105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000055001550015500155001550015500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__music__
00 00000000
01 01010101
