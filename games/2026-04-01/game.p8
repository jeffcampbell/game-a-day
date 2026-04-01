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

-- paddle
paddle = {x=60, y=116, w=8, h=2, speed=3, flash=0}

-- ball
ball = {x=64, y=100, vx=1.5, vy=-2, r=1, active=false}

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

-- initialize game
function init_game()
  score = 0
  lives = 3
  level = 1
  ball.active = false
  ball.x = paddle.x + paddle.w / 2
  ball.y = paddle.y - 4
  ball.vx = (rnd() - 0.5) * 3
  ball.vy = -2
  create_bricks()
  _log("state:play")
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
  ball.active = false
  ball.x = paddle.x + paddle.w / 2
  ball.y = paddle.y - 4

  -- smooth speed increase: 1.05x, 1.10x, 1.15x, 1.20x per level
  local speed_mult = 1 + (level - 1) * 0.05
  ball.vx = (rnd() - 0.5) * 3 * speed_mult
  ball.vy = -2 * speed_mult

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

  -- smooth difficulty curve: gradually increase from 3 to 5 rows
  local rows = 3
  if level >= 2 then rows = 3 end
  if level >= 3 then rows = 4 end
  if level >= 4 then rows = 4 end
  if level >= 5 then rows = 5 end

  local cols = 8

  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      local brick = {
        x = col * 16,
        y = 20 + row * 8,
        w = 15,
        h = 6,
        alive = true,
        color = 8 + rnd(3)  -- randomize colors: 8, 9, 10
      }
      add(bricks, brick)
    end
  end
  bricks_left = #bricks
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

  check_collisions()
  update_sparks()
  update_shake()

  -- check level complete
  if ball.active and bricks_left == 0 then
    next_level()
  end

  -- check loss
  if ball.active and ball.y > 128 then
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

function update_ball()
  ball.x += ball.vx
  ball.y += ball.vy

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
      score += 10
      hit_flash = 4
      flash_color = b.color

      -- visual feedback: sparks and screen effects
      local brick_cx = b.x + b.w / 2
      local brick_cy = b.y + b.h / 2
      create_sparks(brick_cx, brick_cy, 6)
      trigger_shake(3, 1)
      trigger_flash(b.color, 3)

      sfx(1)
      _log("brick_broken:score_"..score)
    end
  end
end

function update_gameover()
  if test_input(4) then
    state = "menu"
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

  if not ball.active then
    print("press z to launch", 25, 108, 7)
  end

  -- screen flash overlay
  if screen_flash > 0 then
    rectfill(0, 0, 128, 128, screen_flash_col)
    screen_flash -= 1
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
