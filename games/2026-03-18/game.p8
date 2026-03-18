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
max_level = 5
level_start_time = 0
music_playing = false

-- paddle
paddle_x = 60
paddle_w = 16
paddle_h = 8
paddle_y = 123

-- ball
ball_x = 64
ball_y = 110
ball_vx = 1.5
ball_vy = -2
ball_r = 4

-- visual effects
particles = {}
flash_timer = 0
shake_timer = 0
shake_x = 0

-- power-ups
power_ups = {}
active_power_up = nil
power_up_timer = 0

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

-- bricks
bricks = {}
function init_bricks(lvl)
  bricks = {}
  local brick_w, brick_h = 8, 8
  local start_x, start_y = 8, 8

  -- level progression: more rows per level
  local cols = 16
  local rows = 2 + lvl

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
  if not music_playing then
    music(0, 0, 1)
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
    ball_x = 64
    ball_y = 110
    ball_vx = 1.5
    ball_vy = -2
    level_start_time = t()
    active_power_up = nil
    power_up_timer = 0
  end
end

function update_play()
  update_particles()

  -- update power-up
  if active_power_up then
    power_up_timer -= 1
    if power_up_timer <= 0 then
      active_power_up = nil
      -- restore paddle to normal size
      paddle_w = max(8, 16 - level * 2)
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
      active_power_up = "expand"
      power_up_timer = 300  -- 5 seconds at 60 fps
      paddle_w = min(28, paddle_w + 8)  -- expand paddle
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

  -- ball movement
  ball_x += ball_vx
  ball_y += ball_vy

  -- wall collisions
  if ball_x - ball_r < 0 or ball_x + ball_r > 128 then
    ball_vx *= -1
    ball_x = mid(ball_r, ball_x, 128 - ball_r)
    trigger_flash()
    trigger_shake(3)
    sfx(1)
  end

  if ball_y - ball_r < 0 then
    ball_vy *= -1
    ball_y = ball_r
    trigger_flash()
    trigger_shake(2)
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
    trigger_flash()
    trigger_shake(2)
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

        -- particle burst on destruction
        add_particles(brick.x + 4, brick.y + 4, brick.color, 4)
        trigger_flash()
        trigger_shake(1)

        -- 10% chance to spawn power-up
        if rnd() < 0.1 then
          add(power_ups, {
            x = brick.x + 4,
            y = brick.y + 4,
            w = 4,
            h = 2,
            color = 12,
            type = "expand"
          })
        end

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
      -- more aggressive speed increase
      local base_vx = 1.5 + level * 0.3
      local base_vy = -2 - level * 0.2
      ball_vx = base_vx
      ball_vy = base_vy
      sfx(3)
    end
  end

  -- level complete condition
  local bricks_left = 0
  for brick in all(bricks) do
    if brick.active then bricks_left += 1 end
  end

  if bricks_left == 0 then
    if level < max_level then
      -- advance to next level
      _log("level_complete:"..level)
      level += 1
      _log("level:"..level)
      init_bricks(level)

      -- more aggressive difficulty scaling
      paddle_w = max(8, 16 - level * 2)  -- shrink paddle each level

      -- increase ball speed more aggressively
      local base_vx = 1.5 + level * 0.4
      local base_vy = -2 - level * 0.3
      ball_vx = base_vx
      ball_vy = base_vy

      -- reset position
      ball_x = 64
      ball_y = 110
      level_start_time = t()
      active_power_up = nil
      power_up_timer = 0
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
      local sprite_idx = 3 + (brick.color - 8)
      if sprite_idx >= 3 and sprite_idx <= 9 then
        spr(sprite_idx, brick.x, brick.y, 1, 1)
      else
        fillp()
        rectfill(brick.x, brick.y, brick.x + brick.w - 1,
                 brick.y + brick.h - 1, brick.color)
      end
    end
  end

  -- draw paddle using sprites
  spr(0, paddle_x, paddle_y, 2, 1)

  -- draw ball sprite
  local ball_sprite_x = ball_x - 4
  local ball_sprite_y = ball_y - 4
  spr(2, ball_sprite_x, ball_sprite_y, 1, 1)

  -- draw power-ups
  for p in all(power_ups) do
    rectfill(p.x, p.y, p.x + p.w, p.y + p.h, p.color)
    print("+", p.x, p.y, 7)
  end

  -- draw particles
  draw_particles()

  -- flash effect on collision
  if flash_timer > 0 then
    fillp(0x5a5a)
    rectfill(0, 0, 128, 128, 7)
    fillp()
    flash_timer -= 1
  end

  camera()

  -- hud (drawn outside shake/flash)
  print("score:"..score, 2, 2, 7)
  print("level:"..level, 50, 2, 7)
  print("lives:"..lives, 100, 2, 7)
  if active_power_up then
    print("pow+", 60, 120, 10)
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
0ddddd0000ddddd0000aa00008888880099999900aaaaa000bbbbb000ccccc000ddddd000eeeee000000000000000000000000000000000000000000000000000000000
0ddddd0000ddddd000aaaa00008888880099999900aaaaa000bbbbb000ccccc000ddddd000eeeee000000000000000000000000000000000000000000000000000000000
0ddddd0000ddddd000aaaa00008888880099999900aaaaa000bbbbb000ccccc000ddddd000eeeee000000000000000000000000000000000000000000000000000000000
0ddddd0000ddddd0000aa00008888880099999900aaaaa000bbbbb000ccccc000ddddd000eeeee000000000000000000000000000000000000000000000000000000000
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
00 00000000
01 01010101
