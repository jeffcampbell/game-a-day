pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- star dodge
-- dodge falling stars!

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

function test_input()
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1
    return test_inputs[test_input_idx] or 0
  end
  return btn()
end

-- game state
state = "menu"
score = 0
player_x = 64
stars = {}
spawn_timer = 0
spawn_rate = 30
speed = 1
prev_input = 0

function _init()
  _log("init")
end

function _update()
  if state == "menu" then update_menu()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function _draw()
  cls()
  if state == "menu" then draw_menu()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

-- menu state
function update_menu()
  local input = test_input()
  -- check if O button just pressed
  if input & 16 > 0 and prev_input & 16 == 0 then
    start_game()
  end
  prev_input = input
end

function draw_menu()
  print("star dodge", 40, 40, 7)
  print("dodge falling stars", 20, 55, 6)
  print("arrows to move", 28, 70, 13)
  print("press o to start", 24, 85, 11)
end

-- play state
function start_game()
  state = "play"
  _log("state:play")
  score = 0
  _log("score:0")
  player_x = 64
  stars = {}
  spawn_timer = 0
  spawn_rate = 30
  speed = 1
  prev_input = 0
end

function update_play()
  local input = test_input()

  -- move player
  if input & 1 > 0 then  -- left
    player_x = max(4, player_x - 2)
  end
  if input & 2 > 0 then  -- right
    player_x = min(124, player_x + 2)
  end

  -- spawn stars
  spawn_timer -= 1
  if spawn_timer <= 0 then
    add(stars, {x=rnd(120)+4, y=0})
    spawn_timer = spawn_rate
    _log("star_spawn")
  end

  -- update stars
  for s in all(stars) do
    s.y += speed

    -- check if passed bottom
    if s.y > 120 then
      del(stars, s)
      score += 1
      _log("score:"..score)

      -- increase difficulty every 10 points
      if score % 10 == 0 then
        speed = min(3, speed + 0.2)
        spawn_rate = max(15, spawn_rate - 2)
        _log("difficulty_up")
      end
    end

    -- check collision with player
    if abs(s.x - player_x) < 5 and abs(s.y - 112) < 5 then
      state = "gameover"
      _log("collision")
      _log("state:gameover")
      _log("final_score:"..score)
      return
    end
  end

  prev_input = input
end

function draw_play()
  -- draw player ship
  circfill(player_x, 112, 3, 8)
  circ(player_x, 112, 3, 9)
  line(player_x-2, 110, player_x+2, 110, 9)

  -- draw stars
  for s in all(stars) do
    -- yellow star with white center
    circfill(s.x, s.y, 2, 10)
    pset(s.x, s.y, 7)
    pset(s.x-1, s.y, 10)
    pset(s.x+1, s.y, 10)
    pset(s.x, s.y-1, 10)
    pset(s.x, s.y+1, 10)
  end

  -- draw score
  print("score:"..score, 2, 2, 7)

  -- draw speed indicator
  local speed_bars = flr(speed * 2)
  for i=1,speed_bars do
    rectfill(118, 12-i*2, 126, 13-i*2, 8)
  end
  print("spd", 118, 2, 7)
end

-- gameover state
function update_gameover()
  local input = test_input()
  -- check if O button just pressed
  if input & 16 > 0 and prev_input & 16 == 0 then
    start_game()
  end
  prev_input = input
end

function draw_gameover()
  print("game over!", 40, 50, 8)
  print("final score: "..score, 30, 70, 7)
  print("press o to retry", 24, 90, 11)
end
