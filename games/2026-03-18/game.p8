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
level = 0

-- paddle
paddle_x = 60
paddle_w = 16
paddle_h = 3
paddle_y = 123

-- ball
ball_x = 64
ball_y = 110
ball_vx = 1.5
ball_vy = -2
ball_r = 1.5

-- bricks
bricks = {}
function init_bricks()
  bricks = {}
  local brick_w, brick_h = 8, 4
  local start_x, start_y = 8, 8
  local cols, rows = 16, 3

  for row = 0, rows - 1 do
    for col = 0, cols - 1 do
      add(bricks, {
        x = start_x + col * brick_w,
        y = start_y + row * brick_h,
        w = brick_w,
        h = brick_h,
        active = true,
        color = 8 + row
      })
    end
  end
end

-- game functions
function update_menu()
  if btnp(4) then
    _log("state:play")
    state = "play"
    score = 0
    lives = 3
    level = 0
    init_bricks()
    ball_x = 64
    ball_y = 110
    ball_vx = 1.5
    ball_vy = -2
  end
end

function update_play()
  -- paddle movement
  if test_input(0) > 0 then
    paddle_x = max(0, paddle_x - 2)
  end
  if test_input(1) > 0 then
    paddle_x = min(128 - paddle_w, paddle_x + 2)
  end

  -- ball movement
  ball_x += ball_vx
  ball_y += ball_vy

  -- wall collisions
  if ball_x - ball_r < 0 or ball_x + ball_r > 128 then
    ball_vx *= -1
    ball_x = mid(ball_r, ball_x, 128 - ball_r)
    sfx(1)
  end

  if ball_y - ball_r < 0 then
    ball_vy *= -1
    ball_y = ball_r
    sfx(1)
  end

  -- paddle collision
  if ball_vy > 0 and
     ball_y + ball_r > paddle_y and
     ball_y < paddle_y + paddle_h and
     ball_x > paddle_x and
     ball_x < paddle_x + paddle_w then
    ball_vy = -abs(ball_vy)
    ball_y = paddle_y - ball_r
    local hit_pos = (ball_x - paddle_x) / paddle_w
    ball_vx = (hit_pos - 0.5) * 3
    sfx(0)
  end

  -- brick collisions
  for brick in all(bricks) do
    if brick.active then
      if ball_x > brick.x and
         ball_x < brick.x + brick.w and
         ball_y > brick.y and
         ball_y < brick.y + brick.h then
        brick.active = false
        score += 10
        _log("brick_destroyed:score"..score)

        -- determine bounce direction
        local dx = abs((ball_x) - (brick.x + brick.w/2))
        local dy = abs((ball_y) - (brick.y + brick.h/2))

        if dx > dy then
          ball_vx *= -1
        else
          ball_vy *= -1
        end
        sfx(2)
        break
      end
    end
  end

  -- lose life if ball falls off bottom
  if ball_y > 128 then
    _log("life_lost:lives"..max(0, lives - 1))
    lives -= 1
    if lives <= 0 then
      _log("state:gameover")
      state = "gameover"
      sfx(4)
    else
      ball_x = 64
      ball_y = 110
      ball_vx = 1.5
      ball_vy = -2
      sfx(3)
    end
  end

  -- win condition
  local bricks_left = 0
  for brick in all(bricks) do
    if brick.active then bricks_left += 1 end
  end

  if bricks_left == 0 then
    _log("state:gameover")
    _log("gameover:win")
    state = "gameover"
    sfx(5)
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

  -- draw bricks
  for brick in all(bricks) do
    if brick.active then
      fillp()
      rectfill(brick.x, brick.y, brick.x + brick.w - 1,
               brick.y + brick.h - 1, brick.color)
    end
  end

  -- draw paddle
  fillp()
  rectfill(paddle_x, paddle_y, paddle_x + paddle_w - 1,
           paddle_y + paddle_h - 1, 3)

  -- draw ball
  fillp()
  circfill(ball_x, ball_y, ball_r, 7)

  -- hud
  print("score:"..score, 2, 2, 7)
  print("lives:"..lives, 100, 2, 7)
end

function draw_gameover()
  cls(0)

  if lives <= 0 then
    print("game over", 48, 40, 8)
  else
    print("you win!", 50, 40, 11)
  end

  print("score:"..score, 55, 60, 7)
  print("press z", 52, 80, 7)
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
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
00 41414141
01 42424242
