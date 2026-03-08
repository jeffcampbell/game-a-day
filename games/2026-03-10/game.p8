pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- jungle escape - platformer game for 2026-03-10

-- test infrastructure
testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0

function _log(msg)
  if testmode then add(test_log, msg) end
end

function test_input(b)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn()
end

-- game state machine
state = "menu"
score = 0
health = 3
max_health = 3
exit_reached = false

-- player
player = {
  x=64, y=90,
  w=6, h=8,
  vx=0, vy=0,
  jump_power=5,
  grav=0.3,
  on_ground=false,
  sprite=1
}

-- platforms (x, y, w, h, move_type, speed)
platforms = {
  {x=10, y=105, w=20, h=4, move=1, sp=1.5, dir=1},
  {x=40, y=85, w=20, h=4, move=1, sp=1, dir=1},
  {x=70, y=70, w=20, h=4, move=1, sp=1.2, dir=-1},
  {x=20, y=50, w=25, h=4, move=0, sp=0, dir=1}
}

-- enemies (x, y, w, h, left, right)
enemies = {
  {x=50, y=75, w=5, h=5, left=35, right=65, vx=1.5, sprite=2},
  {x=30, y=55, w=5, h=5, left=15, right=45, vx=-1.5, sprite=2}
}

-- gems (x, y, collected)
gems = {
  {x=15, y=95, c=false},
  {x=45, y=75, c=false},
  {x=75, y=60, c=false},
  {x=25, y=40, c=false}
}

-- exit portal
exit = {x=60, y=15, w=8, h=8}

function _update()
  if state == "menu" then
    if test_input(4) > 0 then
      state = "play"
      score = 0
      health = max_health
      exit_reached = false
      player = {x=64, y=90, w=6, h=8, vx=0, vy=0, jump_power=5, grav=0.3, on_ground=false, sprite=1}
      gems = {{x=15,y=95,c=false},{x=45,y=75,c=false},{x=75,y=60,c=false},{x=25,y=40,c=false}}
      _log("state:play")
    end
  elseif state == "play" then
    update_play()
  elseif state == "gameover" then
    if test_input(4) > 0 then
      state = "menu"
      _log("state:menu")
    end
  end
end

function update_play()
  -- player input
  local left = test_input(0)
  local right = test_input(1)
  local jump = test_input(2)

  -- horizontal movement
  if left > 0 then player.vx = -2 end
  if right > 0 then player.vx = 2 end
  if left == 0 and right == 0 then player.vx = 0 end

  -- apply gravity
  player.vy += player.grav
  player.on_ground = false

  -- update player position
  player.x += player.vx
  player.y += player.vy

  -- screen wrapping
  if player.x < 0 then player.x = 128 end
  if player.x > 128 then player.x = 0 end

  -- platform collision
  for p in all(platforms) do
    if collide_player_platform(player, p) then
      if player.vy > 0 then
        player.y = p.y - player.h
        player.vy = 0
        player.on_ground = true
        if jump > 0 then
          player.vy = -player.jump_power
          sfx(0)
          _log("jump")
        end
      end
    end
  end

  -- falling off screen
  if player.y > 128 then
    health -= 1
    _log("died:fall")
    if health <= 0 then
      state = "gameover"
      _log("gameover:lose")
    else
      player.y = 90
      player.vy = 0
    end
  end

  -- update platform positions
  for p in all(platforms) do
    if p.move == 1 then
      p.x += p.sp * p.dir
      if p.x <= 5 then p.dir = 1 end
      if p.x + p.w >= 123 then p.dir = -1 end
    end
  end

  -- update enemies
  for e in all(enemies) do
    e.x += e.vx
    if e.x <= e.left then e.vx = abs(e.vx) end
    if e.x >= e.right then e.vx = -abs(e.vx) end
  end

  -- enemy collision
  for e in all(enemies) do
    if collide_rects(player.x, player.y, player.w, player.h,
                     e.x, e.y, e.w, e.h) then
      health -= 1
      sfx(2)
      _log("died:enemy")
      if health <= 0 then
        state = "gameover"
        _log("gameover:lose")
      else
        player.y = 90
        player.x = 64
        player.vy = 0
      end
    end
  end

  -- gem collection
  for g in all(gems) do
    if not g.c and collide_rects(player.x, player.y, player.w, player.h,
                                 g.x, g.y, 4, 4) then
      g.c = true
      score += 10
      sfx(1)
      _log("gem:"..score)
    end
  end

  -- exit collision (win)
  if collide_rects(player.x, player.y, player.w, player.h,
                   exit.x, exit.y, exit.w, exit.h) then
    exit_reached = true
    sfx(3)
    state = "gameover"
    _log("gameover:win")
  end

  -- cap falling speed
  if player.vy > 3 then player.vy = 3 end
end

function collide_player_platform(p, plat)
  if p.x + p.w <= plat.x then return false end
  if p.x >= plat.x + plat.w then return false end
  if p.y + p.h <= plat.y then return false end
  if p.y >= plat.y + plat.h then return false end
  return true
end

function collide_rects(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 + w1 > x2 and x1 < x2 + w2 and
         y1 + h1 > y2 and y1 < y2 + h2
end

function _draw()
  cls(5)

  if state == "menu" then
    draw_menu()
  elseif state == "play" then
    draw_play()
  elseif state == "gameover" then
    draw_gameover()
  end
end

function draw_menu()
  print("jungle escape", 40, 30, 7)
  print("navigate platforms", 30, 45, 7)
  print("collect gems", 40, 55, 7)
  print("reach the exit", 40, 65, 7)
  print("arrows/wasd to move", 28, 80, 7)
  print("up/w to jump", 42, 90, 7)
  print("z/c to start", 42, 110, 7)
end

function draw_play()
  -- draw platforms
  for p in all(platforms) do
    rectfill(p.x, p.y, p.x + p.w, p.y + p.h, 3)
  end

  -- draw enemies
  for e in all(enemies) do
    spr(2, e.x, e.y)
  end

  -- draw gems
  for g in all(gems) do
    if not g.c then
      spr(3, g.x, g.y)
    end
  end

  -- draw player
  spr(1, player.x, player.y)

  -- draw exit
  spr(4, exit.x, exit.y)

  -- ui
  print("health:" .. health, 3, 3, 7)
  print("gems:" .. count_gems(), 3, 12, 7)
  print("score:" .. score, 80, 3, 7)
end

function draw_gameover()
  cls(5)
  if exit_reached then
    print("you win!", 50, 40, 11)
    print("gems collected", 35, 55, 7)
  else
    print("game over", 45, 40, 8)
    print("try again", 50, 55, 7)
  end
  print("score:" .. score, 50, 70, 7)
  print("z/c to menu", 45, 100, 7)
end

function count_gems()
  local c = 0
  for g in all(gems) do
    if g.c then c += 1 end
  end
  return c
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000007700700077007000770070007700700077007000770070007700700077007000770070007700700077007000770070007700700077007000770070
00000000070007700700077007000770070007700700077007000770070007700700077007000770070007700700077007000770070007700700077007000770
00000000007700700077007000770070007700700077007000770070007700700077007000770070007700700077007000770070007700700077007000770070
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000088008800880088008800880088008800880088008800880088008800880088008800880088008800880088008800880088008800880088008800880
00000000080808000808080008080800080808000808080008080800080808000808080008080800080808000808080008080800080808000808080008080800
00000000088008800880088008800880088008800880088008800880088008800880088008800880088008800880088008800880088008800880088008800880
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000055505500555055005550550055505500555055005550550055505500555055005550550055505500555055005550550055505500555055005550550
00000000050505000505050005050500050505000505050005050500050505000505050005050500050505000505050005050500050505000505050005050500
00000000055505500555055005550550055505500555055005550550055505500555055005550550055505500555055005550550055505500555055005550550
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000033003300330033003300330033003300330033003300330033003300330033003300330033003300330033003300330033003300330033003300330
00000000030303000303030003030300030303000303030003030300030303000303030003030300030303000303030003030300030303000303030003030300
00000000033003300330033003300330033003300330033003300330033003300330033003300330033003300330033003300330033003300330033003300330
__sfx__
000100000f0400d0400b0400904009040070400604006040050400404003040020400104000000000000000000000000000000000000000000000000000000000
000100004d0401d0501b05019050170501505013050110500f0500d0500b0500905007050050500304000000000000000000000000000000000000000000000
000100000100020002000300030004000400050005000600070007000800080009000900000000000000000000000000000000000000000000000000000000000
001000200a050080500a05008050080508055000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
