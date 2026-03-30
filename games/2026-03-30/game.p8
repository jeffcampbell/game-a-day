pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

-- marble maze: tilt the maze to guide the marble to the goal
-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

-- visual effect variables
screen_shake = 0
screen_shake_x = 0
screen_shake_y = 0
goal_flash = 0
particles = {}
level_complete_flash = 0
game_over_flash = 0
menu_slide_timer = 0
level_counter_bounce = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function test_input(b)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn(b)
end

-- utility functions
function split(str, delim)
  local result = {}
  local start = 1
  while true do
    local pos = str:find(delim, start)
    if not pos then
      add(result, str:sub(start))
      break
    end
    add(result, str:sub(start, pos - 1))
    start = pos + #delim
  end
  return result
end

-- particle system
function spawn_particles(x, y, count, colors)
  for i = 1, count do
    local angle = (i / count) * 1  -- 0 to 1 rotation
    local speed = 0.5 + rnd(1)
    local vx = speed * cos(angle)
    local vy = speed * sin(angle)
    local col = colors[1 + flr(rnd(#colors))]
    add(particles, {
      x = x,
      y = y,
      vx = vx,
      vy = vy,
      life = 30,
      col = col
    })
  end
end

function update_particles()
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x += p.vx
    p.y += p.vy
    p.vy += 0.1  -- gravity
    p.life -= 1
    if p.life <= 0 then
      deli(particles, i)
    end
  end
end

function draw_particles()
  for p in all(particles) do
    local alpha = flr(p.life / 30 * 7)
    if alpha > 0 then
      pset(p.x, p.y, p.col)
    end
  end
end

-- game state
state = "menu"
score = 0
level = 1
final_level = 10
tilt = 0  -- -1, 0, 1 for left, center, right
marble_x = 64
marble_y = 40
marble_vx = 0
marble_vy = 0
marble_radius = 3

-- goal position
goal_x = 100
goal_y = 100

-- level data: walls as simple positions
walls = {}

function init_level(lv)
  level = lv
  marble_x = 20
  marble_y = 30
  marble_vx = 0
  marble_vy = 0
  tilt = 0
  goal_x = 100
  goal_y = 100

  -- simple wall setup
  walls = {}

  if lv == 1 then
    -- basic maze with walls
    for x = 30, 50 do walls[x..":70"] = true end
    for y = 50, 70 do walls[50..":"..y] = true end
    for x = 50, 80 do walls[x..":50"] = true end
    for y = 30, 50 do walls[80..":"..y] = true end
  elseif lv == 2 then
    -- spiral maze
    for x = 30, 70 do walls[x..":60"] = true end
    for y = 40, 80 do walls[30..":"..y] = true end
    for x = 30, 80 do walls[x..":40"] = true end
    for y = 60, 100 do walls[80..":"..y] = true end
  elseif lv == 3 then
    -- zigzag maze - medium difficulty
    for x = 20, 40 do walls[x..":50"] = true end
    for x = 50, 70 do walls[x..":60"] = true end
    for x = 30, 60 do walls[x..":80"] = true end
    for y = 30, 50 do walls[70..":"..y] = true end
    for y = 60, 100 do walls[40..":"..y] = true end
    goal_y = 105
  elseif lv == 4 then
    -- complex cross pattern
    for y = 30, 100 do walls[40..":"..y] = true end
    for y = 30, 100 do walls[80..":"..y] = true end
    for x = 20, 100 do walls[x..":50"] = true end
    for x = 20, 100 do walls[x..":80"] = true end
    -- gaps in walls
    for x = 40, 42 do walls[x..":50"] = false end
    for x = 80, 82 do walls[x..":80"] = false end
    goal_x = 110
    goal_y = 110
  elseif lv == 5 then
    -- narrow passages - hard difficulty
    for x = 20, 60 do walls[x..":45"] = true end
    for x = 30, 80 do walls[x..":65"] = true end
    for x = 40, 100 do walls[x..":85"] = true end
    for y = 35, 65 do walls[25..":"..y] = true end
    for y = 55, 95 do walls[75..":"..y] = true end
    goal_x = 110
    goal_y = 100
  elseif lv == 6 then
    -- extreme challenge - dense maze
    for x = 20, 90 do walls[x..":40"] = true end
    for x = 20, 90 do walls[x..":70"] = true end
    for y = 30, 110 do walls[45..":"..y] = true end
    for y = 30, 110 do walls[75..":"..y] = true end
    for x = 20, 45 do walls[x..":55"] = true end
    for x = 75, 100 do walls[x..":55"] = true end
    goal_x = 105
    goal_y = 110
  elseif lv == 7 then
    -- multi-chamber maze with narrow choke points
    -- left chamber
    for x = 20, 35 do walls[x..":30"] = true end
    for y = 30, 100 do walls[35..":"..y] = true end
    for x = 20, 35 do walls[x..":100"] = true end
    -- center chamber
    for x = 45, 60 do walls[x..":35"] = true end
    for y = 35, 95 do walls[60..":"..y] = true end
    for x = 45, 60 do walls[x..":95"] = true end
    -- right chamber
    for x = 70, 100 do walls[x..":30"] = true end
    for y = 30, 100 do walls[70..":"..y] = true end
    for x = 70, 100 do walls[x..":100"] = true end
    -- narrow choke points connecting chambers
    for y = 50, 80 do walls[35..":"..y] = false end
    for y = 60, 75 do walls[60..":"..y] = false end
    goal_x = 95
    goal_y = 65
  elseif lv == 8 then
    -- dense spiral pattern
    for x = 30, 100 do walls[x..":50"] = true end
    for y = 30, 100 do walls[30..":"..y] = true end
    for x = 30, 100 do walls[x..":100"] = true end
    for y = 30, 100 do walls[100..":"..y] = true end
    for x = 40, 90 do walls[x..":60"] = true end
    for y = 40, 90 do walls[40..":"..y] = true end
    for x = 40, 90 do walls[x..":90"] = true end
    for y = 40, 90 do walls[90..":"..y] = true end
    for x = 50, 80 do walls[x..":70"] = true end
    for y = 50, 80 do walls[50..":"..y] = true end
    -- gaps in spiral
    for x = 50, 55 do walls[x..":60"] = false end
    for y = 75, 80 do walls[40..":"..y] = false end
    for x = 85, 90 do walls[x..":90"] = false end
    goal_x = 65
    goal_y = 80
  elseif lv == 9 then
    -- dense grid maze - precise control required
    -- create tight grid corridors
    for x = 20, 110, 20 do
      for y = 20, 110, 10 do
        for dx = 0, 5 do
          walls[x + dx..":"..y] = true
        end
      end
    end
    for y = 20, 110, 20 do
      for x = 20, 110, 10 do
        for dy = 0, 5 do
          walls[x..":"..y + dy] = true
        end
      end
    end
    -- open some passages
    for x = 25, 105, 20 do walls[x..":25"] = false end
    for y = 25, 105, 20 do walls[105..":"..y] = false end
    goal_x = 110
    goal_y = 65
  elseif lv == 10 then
    -- ultimate challenge - tight passages + complex routing
    -- dense vertical walls
    for y = 20, 110 do walls[35..":"..y] = true end
    for y = 20, 110 do walls[65..":"..y] = true end
    for y = 20, 110 do walls[95..":"..y] = true end
    -- dense horizontal walls
    for x = 20, 110 do walls[x..":40"] = true end
    for x = 20, 110 do walls[x..":75"] = true end
    for x = 20, 110 do walls[x..":110"] = true end
    -- narrow gaps forcing specific paths
    for y = 50, 60 do walls[35..":"..y] = false end
    for x = 30, 40 do walls[x..":40"] = false end
    for x = 60, 70 do walls[x..":75"] = false end
    for y = 85, 100 do walls[95..":"..y] = false end
    goal_x = 110
    goal_y = 90
  end

  _log("level:"..lv)
end

function update_menu()
  menu_slide_timer = min(20, menu_slide_timer + 1)
  if btnp(4) or btnp(5) then
    sfx(3)  -- menu selection sound
    _log("state:play")
    state = "play"
    init_level(1)
  end
end

function update_play()
  -- update visual effects
  screen_shake = max(0, screen_shake - 1)
  goal_flash = max(0, goal_flash - 1)
  level_complete_flash = max(0, level_complete_flash - 1)
  update_particles()

  -- read tilt input
  if test_input(0) ~= 0 then  -- left
    tilt = -1
  elseif test_input(1) ~= 0 then  -- right
    tilt = 1
  else
    tilt = 0
  end

  -- apply gravity based on tilt
  local gravity = 0.2
  if tilt == -1 then
    marble_vx -= gravity
  elseif tilt == 1 then
    marble_vx += gravity
  else
    marble_vx *= 0.95  -- friction
  end

  marble_vy += gravity  -- downward gravity
  marble_vy *= 0.98    -- air friction
  marble_vx *= 0.98

  -- clamp velocities
  marble_vx = mid(-2, marble_vx, 2)
  marble_vy = mid(-2, marble_vy, 2)

  -- update position
  marble_x += marble_vx
  marble_y += marble_vy

  -- boundary collisions
  if marble_x - marble_radius < 0 then
    marble_x = marble_radius
    marble_vx = 0
    screen_shake = 4
    screen_shake_x = 2
    sfx(0)  -- wall collision sound
  end
  if marble_x + marble_radius > 128 then
    marble_x = 128 - marble_radius
    marble_vx = 0
    screen_shake = 4
    screen_shake_x = -2
    sfx(0)  -- wall collision sound
  end
  if marble_y - marble_radius < 0 then
    marble_y = marble_radius
    marble_vy = 0
    screen_shake = 4
    screen_shake_y = 2
    sfx(0)  -- wall collision sound
  end

  -- lose condition: fall off bottom
  if marble_y > 128 then
    sfx(2)  -- fall sound
    game_over_flash = 15
    _log("gameover:lose")
    state = "gameover"
    return
  end

  -- win condition: reach goal
  local dist_to_goal = sqrt((marble_x - goal_x)^2 + (marble_y - goal_y)^2)
  if dist_to_goal < 8 then
    sfx(1)  -- goal reached sound
    score += 100
    goal_flash = 15
    level_complete_flash = 20
    -- spawn sparkle particles at goal
    spawn_particles(goal_x, goal_y, 12, {10, 11, 12, 13, 14, 15})
    _log("level_complete:"..level)
    _log("score:"..score)

    -- advance to next level or end game
    if level < final_level then
      _log("state:level_transition")
      state = "level_transition"
    else
      _log("gameover:win")
      game_over_flash = 15
      state = "gameover"
    end
    return
  end

  -- check wall collisions
  local cx = flr(marble_x / 8)
  local cy = flr(marble_y / 8)
  local hit = false
  for dx = -1, 1 do
    for dy = -1, 1 do
      local check_x = cx + dx
      local check_y = cy + dy
      if walls[check_x..":"..check_y] then
        hit = true
        -- simple collision response
        if marble_vx > 0 and dx == 1 then
          marble_vx = -marble_vx * 0.5
          marble_x = check_x * 8 - marble_radius
        end
        if marble_vx < 0 and dx == -1 then
          marble_vx = -marble_vx * 0.5
          marble_x = (check_x + 1) * 8 + marble_radius
        end
        if marble_vy > 0 and dy == 1 then
          marble_vy = -marble_vy * 0.5
          marble_y = check_y * 8 - marble_radius
        end
        if marble_vy < 0 and dy == -1 then
          marble_vy = -marble_vy * 0.5
          marble_y = (check_y + 1) * 8 + marble_radius
        end
      end
    end
  end
  if hit then
    screen_shake = 3
    screen_shake_x = rnd(4) - 2
    screen_shake_y = rnd(4) - 2
    sfx(0)  -- wall collision sound
  end

  _log("pos:"..flr(marble_x)..","..flr(marble_y))
end

function update_level_transition()
  level_counter_bounce = min(15, level_counter_bounce + 1)
  if btnp(4) or btnp(5) then
    _log("state:play")
    state = "play"
    level_counter_bounce = 0
    init_level(level + 1)
  end
end

function update_gameover()
  game_over_flash = max(0, game_over_flash - 1)
  if btnp(4) or btnp(5) then
    _log("state:menu")
    state = "menu"
    score = 0
    menu_slide_timer = 0
  end
end

function _update()
  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "level_transition" then update_level_transition()
  elseif state == "gameover" then update_gameover()
  end
end

function draw_menu()
  cls(1)
  -- menu slide-in animation
  local slide_ease = menu_slide_timer / 20
  local title_offset = flr((1 - slide_ease) * -30)
  local text_offset = flr((1 - slide_ease) * 30)

  print("marble maze", 30 + title_offset, 20, 7)
  print("tilt left/right", 20 + text_offset, 40, 6)
  print("to guide the marble", 15 + text_offset, 50, 6)
  print("to the goal!", 30 + text_offset, 60, 6)

  -- pulsing start prompt
  local pulse = flr(t() * 2) % 2
  local prompt_col = pulse == 0 and 5 or 10
  print("press z or x to start", 15, 80, prompt_col)
end

function draw_play()
  -- apply level complete flash
  if level_complete_flash > 0 then
    local flash_val = flr(level_complete_flash / 2) % 2
    if flash_val == 0 then
      pal(1, 11)
      pal(7, 10)
    end
  end

  cls(1)

  -- apply screen shake to camera with easing
  if screen_shake > 0 then
    local shake_ease = screen_shake / 4
    local shake_x = screen_shake_x * shake_ease * rnd(1)
    local shake_y = screen_shake_y * shake_ease * rnd(1)
    camera(shake_x, shake_y)
  else
    camera(0, 0)
  end

  -- draw score with level counter animation
  print("score:"..score, 5, 5, 7)
  print("level:"..level, 5, 12, 7)

  -- draw walls with sprite
  for key in pairs(walls) do
    local parts = split(key, ":")
    local x = tonum(parts[1])
    local y = tonum(parts[2])
    if x and y then
      spr(2, x*8, y*8)
    end
  end

  -- draw goal with flash effect
  if goal_flash > 0 then
    -- flash with color cycling
    local flash_color = 10 + (flr(goal_flash / 2) % 2) * 2
    pal(10, flash_color)
  end
  spr(1, goal_x - 4, goal_y - 4)
  pal()  -- reset palette

  -- draw marble with tilt indicator
  if tilt == -1 then
    spr(3, 46, 6)
  elseif tilt == 1 then
    spr(4, 74, 6)
  end

  -- draw marble
  spr(0, marble_x - 4, marble_y - 4)

  -- draw particles
  draw_particles()

  -- draw instruction
  print("arrows:tilt z/x:menu", 3, 120, 5)

  -- reset camera and palette
  camera(0, 0)
  pal()
end

function draw_level_transition()
  cls(1)
  print("level "..level.." complete!", 20, 30, 10)
  print("score:"..score, 40, 50, 7)

  -- bouncing level counter animation
  local bounce_ease = sin(level_counter_bounce / 15 * 0.5) * 3
  print("get ready for level "..(level + 1), 10, 70 + bounce_ease, 6)

  -- pulsing continue prompt
  local pulse = flr(t() * 2) % 2
  local prompt_col = pulse == 0 and 5 or 14
  print("press z or x to continue", 10, 85, prompt_col)
end

function draw_gameover()
  -- apply flash palette on game over
  local flash_val = flr(game_over_flash / 3) % 2
  if flash_val == 0 and score == 0 then
    pal(1, 8)
    pal(7, 2)
  end

  cls(1)

  if score > 0 and marble_y <= 128 then
    -- victory state
    print("all levels complete!", 15, 20, 10)
    print("final score:"..score, 25, 50, 7)
    print("you mastered", 25, 65, 6)
    print("the marble maze!", 20, 75, 6)

    -- pulsing menu prompt
    local pulse = flr(t() * 2) % 2
    local prompt_col = pulse == 0 and 5 or 14
    print("press z or x", 30, 100, prompt_col)
    print("for menu", 40, 110, prompt_col)
  else
    -- failure state
    print("you fell!", 40, 30, 8)
    print("try again", 35, 50, 6)

    local pulse = flr(t() * 2) % 2
    local prompt_col = pulse == 0 and 8 or 2
    print("press z or x", 30, 70, prompt_col)
    print("for menu", 40, 80, prompt_col)
  end

  pal()
end

function _draw()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "level_transition" then draw_level_transition()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
0077000000aa000055555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07ee700000aaaa0054545454000080000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7eeeee70aaaaaaaa5555555500088000000880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7eeeee70aaaaaaaa5454545408888000000888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7eeeee70aaaaaaaa5555555500088000000880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07ee700000aaaa0054545454000080000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0077000000aa000055555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000005454545400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__sfx__
000100001c0502d05021050250502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d0502d050
000100002465026650296502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d650
000100002d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d6502d650
00010000246502665029650186501865018650186500c6500c6500c6500c6500c6500c6500c6500c6500c6500c6500c6500c6500c6500c6500c6500c650
00010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__label__
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777
