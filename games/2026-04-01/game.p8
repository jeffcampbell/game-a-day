pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- brick breaker game for 2026-04-01

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
  return btn(b)
end

-- game state
state = "menu"
score = 0
lives = 3
level = 1
bricks_left = 0
paused = false

-- paddle (width varies by level)
paddle = {x=60, y=116, w=12, h=2, speed=3, flash=0}

-- ball(s) - can have multiple with multi-ball powerup
ball = {x=64, y=100, vx=1.5, vy=-2, r=1, active=false}
balls = {}  -- array of additional balls when multi_ball active

-- bricks
bricks = {}

-- flash effects
hit_flash = 0
flash_color = 0
screen_flash = 0
screen_flash_col = 0

-- screen shake
shake_x = 0
shake_y = 0
shake_time = 0

-- spark effects (for brick hits)
sparks = {}

-- powerups system
powerups = {}
active_effects = {
  wide_paddle = 0,
  slow_mo = 0,
  multiplier = 0,
  shield = false,
  multi_ball_pending = false
}

-- initialize game
function init_game()
  score = 0
  lives = 3
  level = 1
  paused = false
  ball.active = false
  balls = {}  -- clear extra balls
  powerups = {}  -- clear powerups
  update_paddle_width()
  ball.x = paddle.x + paddle.w / 2
  ball.y = paddle.y - 4
  ball.vx = (rnd() - 0.5) * 2  -- start slower at level 1
  ball.vy = -1.5
  create_bricks()
  _log("state:play")
end

-- update paddle width based on level (wider = easier)
function update_paddle_width()
  local base_w
  if level == 1 then
    base_w = 12  -- very wide for level 1
  elseif level == 2 then
    base_w = 10  -- medium-wide
  elseif level == 3 then
    base_w = 8   -- medium
  elseif level == 4 then
    base_w = 6   -- narrow
  else  -- level 5+
    base_w = 4   -- very narrow
  end

  -- apply wide paddle bonus if active
  if active_effects.wide_paddle > 0 then
    paddle.w = flr(base_w * 1.5)
  else
    paddle.w = base_w
  end

  -- keep paddle in bounds after width change
  paddle.x = mid(0, paddle.x, 128 - paddle.w)
end

-- start next level (keep score/lives, advance level)
function next_level()
  if level >= 5 then
    -- reached max level - game over with victory
    state = "gameover"
    sfx(4)
    trigger_flash(11, 20)  -- yellow flash on victory
    trigger_shake(15, 3)   -- satisfying shake
    _log("gameover:win_level_5")
    return
  end

  -- advance to next level
  level += 1
  _log("level:"..level)
  update_paddle_width()
  ball.active = false
  balls = {}  -- clear extra balls
  powerups = {}  -- clear powerups
  ball.x = paddle.x + paddle.w / 2
  ball.y = paddle.y - 4

  -- smooth speed increase: 1.125x, 1.3x, 1.525x, 1.8x (quadratic curve)
  local speed_mult = 1 + (level - 1) * 0.1 + (level - 1) * (level - 1) * 0.025
  ball.vx = (rnd() - 0.5) * 2 * speed_mult
  ball.vy = -1.5 * speed_mult

  trigger_flash(10, 12)  -- cyan flash on level up
  trigger_shake(8, 2)

  create_bricks()
end

-- screen shake effect
function trigger_shake(duration, intensity)
  shake_time = duration
  shake_x = (rnd() - 0.5) * intensity
  shake_y = (rnd() - 0.5) * intensity
end

-- trigger full screen flash
function trigger_flash(color, duration)
  screen_flash = duration
  screen_flash_col = color
end

-- powerup types: 1=multi_ball, 2=wide_paddle, 3=slow_mo, 4=shield, 5=multiplier
function spawn_powerup(x, y)
  if rnd() < 0.25 then  -- 25% spawn rate
    local ptype = flr(rnd(5)) + 1
    local pu = {
      x = x,
      y = y,
      vx = 0,
      vy = 1.5,
      type = ptype,
      flash = 0
    }
    add(powerups, pu)
  end
end

-- add spark at position
function add_spark(x, y, vx, vy)
  local spark = {
    x = x, y = y,
    vx = vx, vy = vy,
    life = 8
  }
  add(sparks, spark)
end

-- create sparks from impact
function create_sparks(x, y, count)
  for i = 1, count do
    local angle = (i / count) * 1  -- 0 to 1 (full circle in pico-8 angles)
    local speed = 1.5 + rnd(1)
    local vx = cos(angle) * speed
    local vy = sin(angle) * speed
    add_spark(x, y, vx, vy)
  end
end

-- update sparks
function update_sparks()
  for i = #sparks, 1, -1 do
    local s = sparks[i]
    s.life -= 1
    s.x += s.vx
    s.y += s.vy
    s.vy += 0.1  -- gravity
    if s.life <= 0 then
      deli(sparks, i)
    end
  end
end

-- draw sparks
function draw_sparks()
  for i = 1, #sparks do
    local s = sparks[i]
    local col = 7
    if s.life < 3 then
      col = 6  -- fade to darker
    end
    pset(s.x, s.y, col)
  end
end

-- update screen shake
function update_shake()
  if shake_time > 0 then
    shake_time -= 1
    if shake_time > 0 then
      shake_x = (rnd() - 0.5) * 1
      shake_y = (rnd() - 0.5) * 1
    else
      shake_x = 0
      shake_y = 0
    end
  end
end

function create_bricks()
  bricks = {}
  sparks = {}  -- clear sparks for new level

  -- smooth difficulty curve per level
  local rows, cols
  if level == 1 then
    -- very easy: 2 rows, 6 columns (sparse layout)
    rows = 2
    cols = 6
  elseif level == 2 then
    -- easy: 3 rows, 7 columns (still forgiving)
    rows = 3
    cols = 7
  elseif level == 3 then
    -- medium: 3 rows, 8 columns (full width but not too tall)
    rows = 3
    cols = 8
  elseif level == 4 then
    -- hard: 4 rows, 8 columns (tall and full width)
    rows = 4
    cols = 8
  else  -- level 5+
    -- expert: 5 rows, 8 columns (maximum density)
    rows = 5
    cols = 8
  end

  -- calculate brick width to fill screen (8 bricks fit in 128px)
  local brick_w = 15
  local brick_h = 6
  local start_x = (128 - cols * brick_w) / 2  -- center bricks

  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      local brick = {
        x = start_x + col * brick_w,
        y = 20 + row * brick_h,
        w = brick_w,
        h = brick_h,
        alive = true,
        color = 8 + rnd(3)  -- randomize colors: 8, 9, 10
      }
      add(bricks, brick)
    end
  end
  bricks_left = #bricks
end

-- update powerup physics and check paddle collision
function update_powerups()
  for i = #powerups, 1, -1 do
    local pu = powerups[i]
    pu.y += pu.vy

    -- check paddle collision (collect powerup)
    if pu.y >= paddle.y - 4 and
       pu.y <= paddle.y + paddle.h and
       pu.x >= paddle.x and
       pu.x <= paddle.x + paddle.w then
      apply_powerup(pu.type)
      deli(powerups, i)
    elseif pu.y > 128 then
      -- powerup fell off screen
      deli(powerups, i)
    end
  end
end

-- apply powerup effect based on type
function apply_powerup(ptype)
  if ptype == 1 then  -- multi_ball
    active_effects.multi_ball_pending = true
    _log("powerup:multi_ball")
    trigger_flash(12, 4)
  elseif ptype == 2 then  -- wide_paddle
    active_effects.wide_paddle = 180
    update_paddle_width()
    _log("powerup:wide_paddle")
    trigger_flash(14, 4)
  elseif ptype == 3 then  -- slow_mo
    active_effects.slow_mo = 180
    _log("powerup:slow_mo")
    trigger_flash(13, 4)
  elseif ptype == 4 then  -- shield
    active_effects.shield = true
    _log("powerup:shield")
    trigger_flash(10, 4)
  elseif ptype == 5 then  -- multiplier
    active_effects.multiplier = 180
    _log("powerup:multiplier")
    trigger_flash(11, 4)
  end
  sfx(0)  -- collection sound
end

-- check extra ball brick collisions
function check_extra_balls_collisions()
  for bi = 1, #balls do
    local b = balls[bi]
    if not b.active then goto next_ball end

    -- brick collisions for extra balls
    for i = 1, #bricks do
      local br = bricks[i]
      if br.alive and
         b.x >= br.x and
         b.x <= br.x + br.w and
         b.y >= br.y and
         b.y <= br.y + br.h then
        br.alive = false
        bricks_left -= 1
        b.vy = -b.vy

        -- calculate score with multiplier
        if active_effects.multiplier > 0 then
          score += 20
        else
          score += 10
        end

        hit_flash = 4
        flash_color = br.color

        -- visual feedback
        local brick_cx = br.x + br.w / 2
        local brick_cy = br.y + br.h / 2
        create_sparks(brick_cx, brick_cy, 4)
        trigger_shake(2, 1)
        trigger_flash(br.color, 2)

        sfx(1)
        _log("brick_broken:extra_ball:score_"..score)
      end
    end

    ::next_ball::
  end
end

-- update effect timers
function update_effects()
  if active_effects.wide_paddle > 0 then
    active_effects.wide_paddle -= 1
    if active_effects.wide_paddle == 0 then
      update_paddle_width()
    end
  end

  if active_effects.slow_mo > 0 then
    active_effects.slow_mo -= 1
  end

  if active_effects.multiplier > 0 then
    active_effects.multiplier -= 1
  end
end

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "play" then
    update_play()
  elseif state == "gameover" then
    update_gameover()
  end
end

function update_menu()
  if test_input(4) then  -- btn o
    init_game()
    state = "play"
    _log("state:play")
  end
end

function update_play()
  -- toggle pause (use btnp for single press detection)
  if btnp(5) then
    paused = not paused
    if paused then
      _log("paused")
      sfx(5)
    else
      _log("resumed")
      sfx(5)
    end
  end

  -- skip game updates when paused
  if paused then return end

  -- paddle movement
  if test_input(0) then paddle.x = max(0, paddle.x - paddle.speed) end
  if test_input(1) then paddle.x = min(128 - paddle.w, paddle.x + paddle.speed) end

  -- launch ball
  if not ball.active then
    if test_input(4) then
      ball.active = true
      _log("launch")
    end
  end

  if ball.active then
    update_ball()
  else
    ball.x = paddle.x + paddle.w / 2
  end

  -- update extra balls
  for i = #balls, 1, -1 do
    local b = balls[i]
    if b.active then
      b.x += b.vx * (active_effects.slow_mo > 0 and 0.7 or 1.0)
      b.y += b.vy * (active_effects.slow_mo > 0 and 0.7 or 1.0)

      -- wall collisions for extra balls
      if b.x - b.r <= 0 or b.x + b.r >= 128 then
        b.vx = -b.vx
        b.x = mid(b.r, b.x, 128 - b.r)
      end
      if b.y - b.r <= 0 then
        b.vy = -b.vy
        b.y = b.r
      end

      -- check if ball fell off
      if b.y > 128 then
        deli(balls, i)
      end
    end
  end

  check_collisions()
  check_extra_balls_collisions()
  update_powerups()
  update_effects()
  update_sparks()
  update_shake()

  -- check level complete
  if ball.active and bricks_left == 0 then
    next_level()
  end

  -- check loss
  if ball.active and ball.y > 128 then
    -- check shield effect
    if active_effects.shield then
      active_effects.shield = false
      _log("shield_used")
      trigger_flash(10, 8)  -- cyan flash
      trigger_shake(5, 1)
      sfx(4)  -- use a victory-like sound for shield
    else
      lives -= 1
      sfx(2)
      trigger_shake(10, 2)  -- shake on life loss
      trigger_flash(8, 8)   -- red flash on damage
      _log("life_lost")
      if lives <= 0 then
        state = "gameover"
        sfx(3)
        trigger_shake(20, 4)  -- heavy shake on game over
        trigger_flash(8, 25)  -- long red flash
        _log("gameover:lose")
      else
        ball.active = false
        ball.x = paddle.x + paddle.w / 2
        ball.y = paddle.y - 4
      end
    end
  end
end

function update_ball()
  -- apply slow-mo effect: reduce speed by 30%
  local speed_mult = 1.0
  if active_effects.slow_mo > 0 then
    speed_mult = 0.7
  end

  ball.x += ball.vx * speed_mult
  ball.y += ball.vy * speed_mult

  -- wall collisions
  if ball.x - ball.r <= 0 or ball.x + ball.r >= 128 then
    ball.vx = -ball.vx
    ball.x = mid(ball.r, ball.x, 128 - ball.r)
  end

  if ball.y - ball.r <= 0 then
    ball.vy = -ball.vy
    ball.y = ball.r
  end
end

function check_collisions()
  -- paddle collision
  if ball.vy > 0 and
     ball.y + ball.r >= paddle.y and
     ball.y - ball.r <= paddle.y + paddle.h and
     ball.x >= paddle.x and
     ball.x <= paddle.x + paddle.w then
    ball.vy = -abs(ball.vy)
    local hit_pos = (ball.x - paddle.x) / paddle.w
    ball.vx = (hit_pos - 0.5) * 4
    paddle.flash = 3

    -- handle multi-ball effect
    if active_effects.multi_ball_pending then
      active_effects.multi_ball_pending = false
      -- create 2 additional balls
      local b1 = {
        x = ball.x - 3,
        y = ball.y,
        vx = ball.vx - 1.5,
        vy = -abs(ball.vy),
        r = 1,
        active = true
      }
      local b2 = {
        x = ball.x + 3,
        y = ball.y,
        vx = ball.vx + 1.5,
        vy = -abs(ball.vy),
        r = 1,
        active = true
      }
      add(balls, b1)
      add(balls, b2)
      _log("multi_ball_activated")
      trigger_flash(12, 6)
    end

    -- add responsive feedback
    trigger_shake(5, 1)
    trigger_flash(6, 2)

    sfx(0)
    _log("paddle_hit")
  end

  -- brick collisions
  for i = 1, #bricks do
    local b = bricks[i]
    if b.alive and
       ball.x >= b.x and
       ball.x <= b.x + b.w and
       ball.y >= b.y and
       ball.y <= b.y + b.h then
      b.alive = false
      bricks_left -= 1
      ball.vy = -ball.vy

      -- calculate score with multiplier effect
      local base_score = 10
      if active_effects.multiplier > 0 then
        score += base_score * 2
      else
        score += base_score
      end

      hit_flash = 4
      flash_color = b.color

      -- visual feedback: sparks and screen effects
      local brick_cx = b.x + b.w / 2
      local brick_cy = b.y + b.h / 2
      create_sparks(brick_cx, brick_cy, 6)
      trigger_shake(3, 1)
      trigger_flash(b.color, 3)

      -- spawn powerup on brick destruction
      spawn_powerup(brick_cx, brick_cy)

      sfx(1)
      _log("brick_broken:score_"..score)
    end
  end
end

function update_gameover()
  if test_input(4) then
    state = "menu"
    paused = false
    _log("state:menu")
  end
end

function _draw()
  cls(0)
  if state == "menu" then
    draw_menu()
  elseif state == "play" then
    draw_play()
  elseif state == "gameover" then
    draw_gameover()
  end
end

function draw_menu()
  print("brick breaker", 40, 30, 7)
  print("press z to start", 30, 50, 7)
  print("arrows to move", 32, 60, 7)
  print("z to launch", 35, 70, 7)
  print("x to pause", 38, 80, 7)
end

function draw_play()
  -- apply screen shake offset
  camera(shake_x, shake_y)

  -- bricks with flash effect
  for i = 1, #bricks do
    local b = bricks[i]
    if b.alive then
      local col = b.color
      if hit_flash > 0 and hit_flash <= 2 and flash_color == b.color then
        col = 7
      end
      rectfill(b.x + 1, b.y + 1, b.x + b.w - 1, b.y + b.h - 1, col)
      rect(b.x, b.y, b.x + b.w, b.y + b.h, 0)
    end
  end

  -- paddle with flash effect
  local paddle_col = 7
  if paddle.flash > 0 then
    paddle_col = 6
    paddle.flash -= 1
  end
  rectfill(paddle.x, paddle.y, paddle.x + paddle.w, paddle.y + paddle.h, paddle_col)
  rect(paddle.x, paddle.y, paddle.x + paddle.w, paddle.y + paddle.h, 5)

  -- ball with slight glow
  circfill(ball.x, ball.y, ball.r + 1, 8)
  circfill(ball.x, ball.y, ball.r, 7)

  -- draw extra balls
  for i = 1, #balls do
    local b = balls[i]
    if b.active then
      circfill(b.x, b.y, b.r + 1, 9)
      circfill(b.x, b.y, b.r, 10)
    end
  end

  -- draw powerups
  for i = 1, #powerups do
    local pu = powerups[i]
    local col = 8 + (pu.type - 1)  -- different colors per type
    circfill(pu.x, pu.y, 2, col)
    circ(pu.x, pu.y, 2, 7)
  end

  -- draw spark effects
  draw_sparks()

  -- flash effect decay
  if hit_flash > 0 then
    hit_flash -= 1
  end

  -- reset camera
  camera(0, 0)

  -- ui (drawn after camera reset)
  print("score: "..score, 2, 2, 7)
  print("lives: "..lives, 90, 2, 7)
  print("level "..level, 50, 2, 7)

  -- show active powerups on HUD
  local hud_y = 10
  if active_effects.wide_paddle > 0 then
    print("wide", 2, hud_y, 14)
    hud_y += 7
  end
  if active_effects.slow_mo > 0 then
    print("slow", 2, hud_y, 13)
    hud_y += 7
  end
  if active_effects.multiplier > 0 then
    print("2x pts", 2, hud_y, 11)
    hud_y += 7
  end
  if active_effects.shield then
    print("shield", 2, hud_y, 10)
  end

  if not ball.active then
    print("press z to launch", 25, 108, 7)
  end

  -- screen flash overlay
  if screen_flash > 0 then
    rectfill(0, 0, 128, 128, screen_flash_col)
    screen_flash -= 1
  end

  -- pause overlay
  if paused then
    rectfill(0, 50, 128, 78, 0)
    print("paused", 52, 60, 7)
  end
end

function draw_gameover()
  if level >= 5 then
    print("completed all levels!", 25, 40, 11)
    print("final score: "..score, 35, 55, 7)
    print("level: "..(level - 1), 48, 65, 7)
  else
    print("game over", 48, 50, 8)
    print("final score: "..score, 35, 60, 7)
    print("level reached: "..level, 30, 70, 7)
  end
  print("press z for menu", 30, 85, 7)
end

__gfx__
0007700077777700000000007007700070077000700770007007700070077000700770007007700070077000000000000000000000000000000000000000000
7700077700000007007700007007700070077000700770007007700070077000700770007007700070077000000000000000000000000000000000000000000
7700077700000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0007700077777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
__sfx__
000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000020653065306530653065306530653065300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000010551055105510551055105510551000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000030653045304530453045304530450000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000030453035302530353035302530350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
