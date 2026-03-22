pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- lane racer: top-down racing game
-- dodge obstacles and survive as long as possible

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
mode = "endless"  -- "endless" or "campaign"
num_players = 1  -- 1 or 2
difficulty = 1  -- 1=easy, 2=normal, 3=hard
current_level = 1  -- for campaign mode
campaign_progress = 0  -- highest level completed (0-5)
score = 0
score2 = 0  -- second player score
lives = 3
lives2 = 3  -- second player lives
time_elapsed = 0
spawn_timer = 0
spawn_rate = 30  -- frames between spawns
obstacles = {}
particles = {}
floaters = {}  -- floating score text
shake_frames = 0  -- screen shake effect
music_playing = false
speed_trap_frames = 0  -- frames remaining in speed trap effect
speed_trap_frames2 = 0  -- second player speed trap
engine_loop_counter = 0  -- counter for ambient engine loop

-- adaptive difficulty tracking (10-second rolling window)
dodge_successes = 0  -- obstacles passed without hitting
dodge_attempts = 0  -- total obstacles in current window
adaptive_window = 0  -- frame counter for window (max 600)
difficulty_indicator = "balanced"  -- "easy", "balanced", "hard"
hazard_speed_adjust = 0  -- cumulative speed adjustment
spawn_rate_adjust = 0  -- cumulative spawn rate adjustment

-- high score data
high_scores = {0, 0, 0, 0, 0}  -- top 5 scores
games_played = 0
total_score_sum = 0
best_time = 0
personal_best = 0

-- achievement flags (set during save_game_score)
is_new_record_achieved = false
is_personal_best_achieved = false

-- campaign level definitions
levels = {
  {name="intro", score_target=50, spawn_rate_start=60, obstacle_types={h=80,b=15,s=3,t=2}, hazard_speed=0.5},
  {name="variety", score_target=100, spawn_rate_start=50, obstacle_types={h=70,b=20,s=8,t=2}, hazard_speed=0.7},
  {name="challenge", score_target=150, spawn_rate_start=40, obstacle_types={h=60,b=20,s=15,t=5}, hazard_speed=0.9},
  {name="intense", score_target=200, spawn_rate_start=30, obstacle_types={h=50,b=20,s=20,t=10}, hazard_speed=1.1},
  {name="boss", score_target=250, spawn_rate_start=20, obstacle_types={h=40,b=20,s=20,t=20}, hazard_speed=1.3}
}

-- player
player = {
  x = 32,
  y = 110,
  w = 6,
  h = 6,
  speed = 2,
  invincibility_frames = 0  -- frames remaining in invincibility state
}

-- player 2
player2 = {
  x = 96,
  y = 110,
  w = 6,
  h = 6,
  speed = 2,
  invincibility_frames = 0
}

-- lane bounds
lane_left = 8
lane_right = 56
lane_width = lane_right - lane_left

-- player 2 lane bounds
lane_left2 = 72
lane_right2 = 120
lane_width2 = lane_right2 - lane_left2

-- constants
win_score = 500
win_time = 120  -- 2 minutes in seconds

function _init()
  cartdata(0)  -- enable cartridge data
  load_stats()
  is_new_record_achieved = false
  is_personal_best_achieved = false
  music(0)  -- start menu music
  _log("state:menu")
end

-- cartdata functions (addresses 0-9)
function load_stats()
  games_played = dget(0)
  personal_best = dget(1)
  total_score_sum = dget(2)
  best_time = dget(3)
  campaign_progress = dget(9)  -- campaign highest level
  for i = 1, 5 do
    high_scores[i] = dget(3 + i)
  end
end

function save_stats()
  dset(0, games_played)
  dset(1, personal_best)
  dset(2, total_score_sum)
  dset(3, best_time)
  dset(9, campaign_progress)
  for i = 1, 5 do
    dset(3 + i, high_scores[i])
  end
end

function save_game_score(final_score, final_time)
  -- store old values before updating (for achievement detection)
  local old_personal_best = personal_best
  local old_high_score_1 = high_scores[1]

  games_played += 1
  total_score_sum += final_score

  if final_time > best_time then
    best_time = final_time
  end

  if final_score > personal_best then
    personal_best = final_score
  end

  -- insert into high scores
  for i = 1, 5 do
    if final_score > high_scores[i] then
      -- shift scores down
      for j = 5, i + 1, -1 do
        high_scores[j] = high_scores[j - 1]
      end
      high_scores[i] = final_score
      break
    end
  end

  save_stats()

  -- set achievement flags based on old values
  is_new_record_achieved = final_score > old_high_score_1
  is_personal_best_achieved = final_score > old_personal_best and final_score <= old_high_score_1
end

function get_rank(score)
  for i = 1, 5 do
    if score == high_scores[i] then
      return i
    end
  end
  return 0
end

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "mode_select" then
    update_mode_select()
  elseif state == "difficulty_select" then
    update_difficulty_select()
  elseif state == "play" then
    update_play()
  elseif state == "level_complete" then
    update_level_complete()
  elseif state == "gameover" then
    update_gameover()
  elseif state == "stats" then
    update_stats()
  end
end

function _draw()
  cls(0)
  if state == "menu" then
    draw_menu()
  elseif state == "mode_select" then
    draw_mode_select()
  elseif state == "difficulty_select" then
    draw_difficulty_select()
  elseif state == "play" then
    draw_play()
  elseif state == "level_complete" then
    draw_level_complete()
  elseif state == "gameover" then
    draw_gameover()
  elseif state == "stats" then
    draw_stats()
  end
end

-- menu state
function update_menu()
  if btnp(4) then  -- z button
    _log("state:mode_select")
    state = "mode_select"
    sfx(2)  -- ui sound
  elseif btnp(5) then  -- x button
    _log("state:stats")
    state = "stats"
    sfx(2)  -- ui sound
  end
end

function draw_menu()
  print("lane racer", 48, 30, 7)
  print("dodge obstacles", 40, 50, 7)
  print("survive 2 min or reach 500pts", 15, 65, 6)
  print("press z to play", 32, 85, 3)
  print("press x for stats", 30, 100, 6)
end

-- mode select state
function update_mode_select()
  if btnp(0) then  -- left
    num_players = max(1, num_players - 1)
  elseif btnp(1) then  -- right
    num_players = min(2, num_players + 1)
  elseif btnp(2) then  -- up
    if num_players == 1 then
      mode = "endless"
    elseif num_players == 2 then
      mode = "endless"
    end
  elseif btnp(3) then  -- down
    if num_players == 1 then
      mode = "campaign"
    elseif num_players == 2 then
      mode = "campaign"
    end
  elseif btnp(4) then  -- z button
    _log("state:difficulty_select")
    state = "difficulty_select"
    sfx(2)
  elseif btnp(5) then  -- x button
    _log("state:menu")
    state = "menu"
    sfx(2)
  end
end

function draw_mode_select()
  print("select mode", 42, 30, 7)
  print("left/right: players", 28, 45, 6)

  -- player count
  local p1_col, p2_col = 6, 6
  if num_players == 1 then p1_col = 11 else p2_col = 11 end
  print("1p", 20, 60, p1_col)
  print("2p", 105, 60, p2_col)

  -- mode (up/down)
  local e_col, c_col = 6, 6
  if mode == "endless" then e_col = 11 else c_col = 11 end
  print("endless", 40, 75, e_col)
  print("campaign", 40, 85, c_col)

  if mode == "campaign" then
    print("lvl: "..min(5, campaign_progress+1).."/5", 35, 100, 10)
  end

  print("z to play", 50, 110, 3)
end

-- difficulty select state
function update_difficulty_select()
  if btnp(0) then  -- left
    difficulty = max(1, difficulty - 1)
  elseif btnp(1) then  -- right
    difficulty = min(3, difficulty + 1)
  elseif btnp(4) then  -- z button
    _log("state:play")
    _log("difficulty:"..difficulty)
    if mode == "campaign" then
      current_level = campaign_progress + 1
      if current_level > 5 then current_level = 5 end
      _log("campaign:level:"..current_level)
    end
    start_game()
  elseif btnp(5) then  -- x button
    _log("state:mode_select")
    state = "mode_select"
    sfx(2)
  end
end

function draw_difficulty_select()
  if mode == "campaign" then
    print("campaign: level "..current_level, 22, 30, 7)
  else
    if num_players == 1 then
      print("select difficulty", 32, 30, 7)
    else
      print("difficulty (2-player)", 28, 30, 7)
    end
  end

  local y_base = 50
  for i = 1, 3 do
    local label = ""
    if i == 1 then label = "easy"
    elseif i == 2 then label = "normal"
    else label = "hard"
    end

    local x = 20 + (i-1) * 40
    local col = 6
    if i == difficulty then col = 11 end
    print(label, x, y_base, col)
  end

  print("arrows to choose, z to play", 5, 90, 6)
  print("x to back", 45, 105, 6)
end

-- play state
function start_game()
  state = "play"
  score = 0
  score2 = 0
  lives = 3
  lives2 = 3
  time_elapsed = 0
  spawn_timer = 0
  obstacles = {}
  particles = {}
  floaters = {}
  shake_frames = 0
  speed_trap_frames = 0
  speed_trap_frames2 = 0
  music_playing = true
  engine_loop_counter = 0
  -- reset adaptive difficulty
  dodge_successes = 0
  dodge_attempts = 0
  adaptive_window = 0
  difficulty_indicator = "balanced"
  hazard_speed_adjust = 0
  spawn_rate_adjust = 0
  music(1)  -- start gameplay ambient music
  is_new_record_achieved = false
  is_personal_best_achieved = false

  -- reset player positions
  player.x = 32
  player.y = 110
  player.invincibility_frames = 0
  player2.x = 96
  player2.y = 110
  player2.invincibility_frames = 0

  if mode == "campaign" then
    -- campaign mode: level-based difficulty
    local lvl = levels[current_level]
    spawn_rate = lvl.spawn_rate_start
    win_score = lvl.score_target
    if num_players == 2 then
      _log("campaign_start:level:"..current_level.":2p")
    else
      _log("campaign_start:level:"..current_level)
    end
  else
    -- endless mode: difficulty select
    if difficulty == 1 then
      spawn_rate = 60
    elseif difficulty == 2 then
      spawn_rate = 45
    else
      spawn_rate = 30
    end
    win_score = 500
    if num_players == 2 then
      _log("endless_start:2p")
    end
  end
end

function update_play()
  -- update invincibility
  if player.invincibility_frames > 0 then
    player.invincibility_frames -= 1
  end
  if num_players == 2 and player2.invincibility_frames > 0 then
    player2.invincibility_frames -= 1
  end

  -- update speed trap effect
  if speed_trap_frames > 0 then
    speed_trap_frames -= 1
  end
  if num_players == 2 and speed_trap_frames2 > 0 then
    speed_trap_frames2 -= 1
  end

  -- ambient engine loop every 2 seconds
  engine_loop_counter += 1
  if engine_loop_counter > 120 then
    sfx(7)
    engine_loop_counter = 0
  end

  -- player 1 input (with speed reduction if in speed trap)
  local move_speed = player.speed
  if speed_trap_frames > 0 then
    move_speed = player.speed * 0.5  -- halve speed during trap
  end

  if test_input(0) then  -- left
    player.x = max(lane_left, player.x - move_speed)
  end
  if test_input(1) then  -- right
    player.x = min(lane_right, player.x + move_speed)
  end

  -- player 2 input (separate buttons via btn(i, p=1))
  if num_players == 2 then
    local move_speed2 = player2.speed
    if speed_trap_frames2 > 0 then
      move_speed2 = player2.speed * 0.5
    end

    if btn(0, 1) then  -- left (player 2)
      player2.x = max(lane_left2, player2.x - move_speed2)
    end
    if btn(1, 1) then  -- right (player 2)
      player2.x = min(lane_right2, player2.x + move_speed2)
    end
  end

  -- update adaptive difficulty
  update_adaptive_difficulty()

  -- obstacle spawning
  spawn_timer -= 1
  if spawn_timer <= 0 then
    spawn_obstacle()
    spawn_timer = spawn_rate + spawn_rate_adjust

    -- increase difficulty over time
    local current_score = score
    if num_players == 2 then
      current_score = max(score, score2)
    end
    if current_score > 0 and current_score % 100 == 0 then
      spawn_rate = max(10, spawn_rate - 2)
      _log("level_up")
      sfx(3)  -- level-up sound
      shake_frames = 2  -- light shake on level-up
    end
  end

  -- update obstacles
  for i = #obstacles, 1, -1 do
    local obs = obstacles[i]
    obs.y += obs.speed

    -- player 1 collision
    local p1_hit = false
    if obs.y < player.y + player.h and
       obs.y + obs.h > player.y and
       obs.x < player.x + player.w and
       obs.x + obs.w > player.x then
      p1_hit = true
    end

    -- player 2 collision (for p2-specific lane)
    local p2_hit = false
    if num_players == 2 then
      if obs.y < player2.y + player2.h and
         obs.y + obs.h > player2.y and
         obs.x2 < player2.x + player2.w and
         obs.x2 + obs.w > player2.x then
        p2_hit = true
      end
    end

    -- handle collisions
    if p1_hit then
      handle_obstacle_collision(obs, "p1")
    end
    if p2_hit then
      handle_obstacle_collision(obs, "p2")
    end

    -- check if passed
    if obs.y > 128 then
      if not obs.p1_counted then
        if num_players == 1 or not p1_hit then
          score += 1
          sfx(1)
          add_floater(player.x, player.y, "+1", 11)
          -- track dodge success for adaptive difficulty
          if not obs.was_hit then
            dodge_successes += 1
          end
        end
        obs.p1_counted = true
      end

      if num_players == 2 then
        if not obs.p2_counted then
          if not p2_hit then
            score2 += 1
            sfx(1)
            add_floater(player2.x, player2.y, "+1", 11)
            -- track dodge success for adaptive difficulty
            if not obs.was_hit then
              dodge_successes += 1
            end
          end
          obs.p2_counted = true
        end
      end

      if obs.p1_counted and (num_players == 1 or obs.p2_counted) then
        deli(obstacles, i)
      end
    end
  end

  -- update particles
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.life -= 1
    if p.life <= 0 then
      deli(particles, i)
    end
  end

  -- update floaters
  for i = #floaters, 1, -1 do
    local f = floaters[i]
    f.life -= 1
    f.y -= 1
    if f.life <= 0 then
      deli(floaters, i)
    end
  end

  -- update screen shake
  if shake_frames > 0 then
    shake_frames -= 1
  end

  -- update timer
  time_elapsed += 1/60

  -- check game over condition (either player loses all lives)
  if num_players == 2 then
    if lives <= 0 or lives2 <= 0 then
      _log("gameover:lose")
      local final_score = max(score, score2)
      save_game_score(final_score, flr(time_elapsed))
      state = "gameover"
      music_playing = false
      music()
    end
  else
    if lives <= 0 then
      _log("gameover:lose")
      save_game_score(score, flr(time_elapsed))
      state = "gameover"
      music_playing = false
      music()
    end
  end

  -- check win condition
  local level_won = false
  if mode == "campaign" then
    -- campaign: win when both players reach target (or player 1 if solo)
    if num_players == 2 then
      if score >= win_score and score2 >= win_score then
        level_won = true
      end
    else
      if score >= win_score then
        level_won = true
      end
    end
  else
    -- endless: win on score or time
    if num_players == 2 then
      local high_score = max(score, score2)
      if high_score >= win_score or time_elapsed >= win_time then
        level_won = true
      end
    else
      if score >= win_score or time_elapsed >= win_time then
        level_won = true
      end
    end
  end

  if level_won then
    _log("gameover:win")
    local final_score = max(score, score2)
    save_game_score(final_score, flr(time_elapsed))

    if mode == "campaign" then
      -- update campaign progress
      if current_level > campaign_progress then
        campaign_progress = current_level
        save_stats()
      end
      state = "level_complete"
      music_playing = false
      music()
    else
      state = "gameover"
      music_playing = false
      music()
    end
  end
end

function update_adaptive_difficulty()
  -- update rolling window counter
  adaptive_window += 1
  if adaptive_window > 600 then  -- 10 seconds at 60fps
    adaptive_window = 0
    dodge_successes = 0
    dodge_attempts = 0
  end

  -- calculate dodge rate (with safety check)
  local dodge_rate = 0
  if dodge_attempts > 0 then
    dodge_rate = dodge_successes / dodge_attempts
  end

  -- determine difficulty level
  if dodge_rate > 0.8 then
    difficulty_indicator = "hard"
  elseif dodge_rate < 0.4 then
    difficulty_indicator = "easy"
  else
    difficulty_indicator = "balanced"
  end

  -- adjust difficulty every 30 frames to smooth transitions
  if adaptive_window % 30 == 0 then
    if dodge_rate > 0.8 then
      -- too easy: increase difficulty
      spawn_rate_adjust = min(10, spawn_rate_adjust + 0.1)
      hazard_speed_adjust = min(0.5, hazard_speed_adjust + 0.05)
    elseif dodge_rate < 0.4 then
      -- too hard: decrease difficulty
      spawn_rate_adjust = max(-5, spawn_rate_adjust - 0.1)
      hazard_speed_adjust = max(-0.3, hazard_speed_adjust - 0.05)
    else
      -- balanced: gradually return to normal
      spawn_rate_adjust *= 0.95
      hazard_speed_adjust *= 0.95
    end
  end
end

function handle_obstacle_collision(obs, player_id)
  -- mark obstacle as hit for adaptive difficulty tracking
  obs.was_hit = true

  if player_id == "p1" then
    if obs.type == "hazard" then
      _log("obstacle:hazard")
      if player.invincibility_frames <= 0 then
        lives -= 1
        player.invincibility_frames = 60  -- 1 second of invincibility after hit
        spawn_particle(obs.x, obs.y)
        sfx(0)
        shake_frames = 4
      else
        sfx(5)
        _log("invincibility:triggered")
      end
    elseif obs.type == "bonus" then
      _log("obstacle:bonus")
      score += 5
      sfx(4)
      add_floater(player.x, player.y, "+5", 3)
    elseif obs.type == "speed_trap" then
      _log("obstacle:speed_trap")
      speed_trap_frames = 2
      sfx(1)
      add_floater(player.x, player.y, "slow", 9)
    elseif obs.type == "shield" then
      _log("obstacle:shield")
      player.invincibility_frames = 300
      sfx(4)
      add_floater(player.x, player.y, "shield!", 11)
    end
  else  -- p2
    if obs.type == "hazard" then
      _log("obstacle:hazard:p2")
      if player2.invincibility_frames <= 0 then
        lives2 -= 1
        player2.invincibility_frames = 60  -- 1 second of invincibility after hit
        spawn_particle(obs.x2, obs.y)
        sfx(0)
        shake_frames = 4
      else
        sfx(5)
        _log("invincibility:triggered:p2")
      end
    elseif obs.type == "bonus" then
      _log("obstacle:bonus:p2")
      score2 += 5
      sfx(4)
      add_floater(player2.x, player2.y, "+5", 3)
    elseif obs.type == "speed_trap" then
      _log("obstacle:speed_trap:p2")
      speed_trap_frames2 = 2
      sfx(1)
      add_floater(player2.x, player2.y, "slow", 9)
    elseif obs.type == "shield" then
      _log("obstacle:shield:p2")
      player2.invincibility_frames = 300
      sfx(4)
      add_floater(player2.x, player2.y, "shield!", 11)
    end
  end
end

function spawn_obstacle()
  local w = 8 + flr(rnd(8))
  local x = lane_left + rnd(lane_width - w)
  local x2 = lane_left2 + rnd(lane_width2 - w)

  local obs = {
    x = x,
    x2 = x2,
    y = -8,
    w = w,
    h = 8,
    speed = 0.7 + (difficulty - 1) * 0.35 + hazard_speed_adjust,
    type = "hazard",
    sprite_id = 2,
    p1_counted = false,
    p2_counted = false,
    was_hit = false  -- track if this obstacle hit any player
  }

  -- track attempt for adaptive difficulty
  dodge_attempts += 1

  -- determine obstacle type based on mode
  local roll = rnd(100)
  local h_pct, b_pct, s_pct, t_pct = 60, 25, 10, 5

  if mode == "campaign" then
    -- use level-specific obstacle distribution
    local lvl = levels[current_level]
    local types = lvl.obstacle_types
    h_pct = types.h or 60
    b_pct = types.b or 20
    s_pct = types.s or 10
    t_pct = types.t or 5
    obs.speed = lvl.hazard_speed + hazard_speed_adjust
  end

  if roll < h_pct then
    obs.type = "hazard"
    obs.sprite_id = 2
  elseif roll < h_pct + b_pct then
    obs.type = "bonus"
    obs.sprite_id = 3
  elseif roll < h_pct + b_pct + s_pct then
    obs.type = "speed_trap"
    obs.sprite_id = 4
  elseif roll < 100 then
    obs.type = "shield"
    obs.sprite_id = 5
  end

  add(obstacles, obs)
end

function spawn_particle(x, y)
  local colors = {8, 9, 10, 15}  -- varied impact colors
  for i = 1, 6 do  -- more particles on collision
    local p = {
      x = x + rnd(8) - 4,
      y = y + rnd(8) - 4,
      vx = rnd(3) - 1.5,
      vy = rnd(2) - 1,
      life = 15,
      col = colors[flr(rnd(4)) + 1]
    }
    add(particles, p)
  end
end

function add_floater(x, y, text, col)
  add(floaters, {
    x = x,
    y = y,
    text = text,
    col = col,
    life = 30
  })
end

function draw_play()
  -- apply screen shake
  local shake_x = 0
  local shake_y = 0
  if shake_frames > 0 then
    shake_x = rnd(3) - 1.5
    shake_y = rnd(3) - 1.5
  end
  camera(shake_x, shake_y)

  if num_players == 1 then
    -- single player view
    -- draw lane markers
    line(lane_left, 0, lane_left, 128, 5)
    line(lane_right, 0, lane_right, 128, 5)

    -- draw center line dashes
    for y = 0, 128, 10 do
      line(64, y, 64, y + 5, 5)
    end

    -- draw player car
    spr(1, player.x - 3, player.y - 3)

    -- draw invincibility shield
    if player.invincibility_frames > 0 then
      local pulse = abs(sin(time_elapsed * 4)) * 2
      circ(player.x, player.y, 4 + pulse, 11)
    end

    -- draw speed trap indicator
    if speed_trap_frames > 0 then
      rect(player.x - 4, player.y - 4, player.x + 4, player.y + 4, 8)
    end

    -- draw obstacles
    for obs in all(obstacles) do
      local scale = obs.w / 8
      if scale > 1 then
        sspr(obs.sprite_id * 8, 0, 8, 8, obs.x, obs.y, obs.w, 8)
      else
        spr(obs.sprite_id, obs.x, obs.y)
      end
    end
  else
    -- split-screen two player view
    -- left side: player 1
    line(lane_left, 0, lane_left, 128, 5)
    line(lane_right, 0, lane_right, 128, 5)

    spr(1, player.x - 3, player.y - 3)
    if player.invincibility_frames > 0 then
      local pulse = abs(sin(time_elapsed * 4)) * 2
      circ(player.x, player.y, 4 + pulse, 11)
    end
    if speed_trap_frames > 0 then
      rect(player.x - 4, player.y - 4, player.x + 4, player.y + 4, 8)
    end

    -- right side: player 2
    line(lane_left2, 0, lane_left2, 128, 5)
    line(lane_right2, 0, lane_right2, 128, 5)

    spr(1, player2.x - 3, player2.y - 3)
    if player2.invincibility_frames > 0 then
      local pulse = abs(sin(time_elapsed * 4)) * 2
      circ(player2.x, player2.y, 4 + pulse, 11)
    end
    if speed_trap_frames2 > 0 then
      rect(player2.x - 4, player2.y - 4, player2.x + 4, player2.y + 4, 8)
    end

    -- divider line between screens
    line(64, 0, 64, 128, 5)

    -- draw obstacles for both players
    for obs in all(obstacles) do
      local scale = obs.w / 8
      -- player 1 obstacles
      if scale > 1 then
        sspr(obs.sprite_id * 8, 0, 8, 8, obs.x, obs.y, obs.w, 8)
      else
        spr(obs.sprite_id, obs.x, obs.y)
      end
      -- player 2 obstacles
      if scale > 1 then
        sspr(obs.sprite_id * 8, 0, 8, 8, obs.x2, obs.y, obs.w, 8)
      else
        spr(obs.sprite_id, obs.x2, obs.y)
      end
    end
  end

  -- draw particles
  for p in all(particles) do
    pset(p.x, p.y, p.col)
    p.x += p.vx
    p.y += p.vy
  end

  -- draw floaters
  for f in all(floaters) do
    print(f.text, f.x - 4, f.y, f.col)
  end

  -- reset camera
  camera(0, 0)

  -- draw ui
  if num_players == 1 then
    print("score:"..score, 2, 2, 7)
    if mode == "campaign" then
      print("level:"..current_level, 2, 10, 7)
      print("target:"..win_score, 2, 18, 6)
    else
      print("lives:"..lives, 2, 10, 7)
      print("time:"..flr(time_elapsed), 2, 18, 7)
    end
    -- draw difficulty indicator
    local diff_col = 10  -- balanced = yellow
    if difficulty_indicator == "easy" then
      diff_col = 11  -- easy = green
    elseif difficulty_indicator == "hard" then
      diff_col = 8  -- hard = red
    end
    print("dif:"..difficulty_indicator, 100, 2, diff_col)
  else
    -- 2-player UI
    print("p1:"..score, 2, 2, 7)
    print("p2:"..score2, 2, 10, 7)
    print("l1:"..lives, 2, 18, 8)
    print("l2:"..lives2, 65, 18, 8)
    if mode == "campaign" then
      print("target:"..win_score, 35, 2, 6)
    else
      print("time:"..flr(time_elapsed), 35, 2, 7)
    end
    -- draw difficulty indicator (2-player view)
    local diff_col = 10  -- balanced = yellow
    if difficulty_indicator == "easy" then
      diff_col = 11  -- easy = green
    elseif difficulty_indicator == "hard" then
      diff_col = 8  -- hard = red
    end
    print("d:"..difficulty_indicator, 95, 10, diff_col)
  end
end

-- level complete state (campaign only)
function update_level_complete()
  if btnp(4) then  -- z button
    if current_level >= 5 then
      _log("campaign:completed")
      state = "menu"
      music(0)
      sfx(2)
    else
      -- next level
      _log("campaign:next_level")
      current_level += 1
      sfx(2)
      start_game()
    end
  elseif btnp(5) then  -- x button
    _log("state:menu")
    state = "menu"
    music(0)
    sfx(2)
  end
end

function draw_level_complete()
  print("level complete!", 35, 30, 11)

  if num_players == 1 then
    print("score: "..score, 42, 50, 7)
  else
    print("p1: "..score, 38, 50, 7)
    print("p2: "..score2, 38, 60, 7)
  end

  if current_level < 5 then
    print("level "..current_level.." / 5", 38, 75, 6)
    print("press z for level "..(current_level+1), 15, 90, 3)
  else
    print("★ campaign complete! ★", 25, 75, 10)
    print("press z to finish", 30, 90, 3)
  end

  print("press x to menu", 32, 110, 6)
end

-- gameover state
function update_gameover()
  if btnp(4) then  -- z button
    _log("state:menu")
    state = "menu"
    music_playing = false
    music(0)  -- return to menu music
    sfx(2)  -- ui sound
  end
end

function draw_gameover()
  if num_players == 1 then
    print("game over", 48, 40, 8)
    print("final score:"..score, 30, 60, 7)

    -- show achievement messages
    local rank = get_rank(score)
    if is_new_record_achieved then
      print("★new record!★", 40, 75, 10)
      _log("achievement:new_record")
    elseif is_personal_best_achieved then
      print("personal best!", 38, 75, 11)
      _log("achievement:personal_best")
    elseif rank > 0 then
      print("#"..rank.." all time", 40, 75, 14)
    else
      if score >= win_score or time_elapsed >= win_time then
        print("you won!", 48, 75, 11)
      else
        print("you lost", 48, 75, 8)
      end
    end

    print("press z to try again", 20, 105, 3)
  else
    -- 2-player game over
    print("game over", 48, 20, 8)
    print("p1: "..score, 20, 35, 7)
    print("p2: "..score2, 20, 45, 7)

    -- determine winner
    if lives <= 0 and lives2 > 0 then
      print("player 2 wins!", 38, 60, 11)
      _log("p2_wins")
    elseif lives2 <= 0 and lives > 0 then
      print("player 1 wins!", 38, 60, 11)
      _log("p1_wins")
    elseif lives <= 0 and lives2 <= 0 then
      if score > score2 then
        print("player 1 wins!", 38, 60, 11)
        _log("p1_wins")
      elseif score2 > score then
        print("player 2 wins!", 38, 60, 11)
        _log("p2_wins")
      else
        print("tie game!", 45, 60, 14)
        _log("tie")
      end
    else
      if score >= win_score and score2 >= win_score then
        if score > score2 then
          print("p1 wins!", 45, 60, 11)
          _log("p1_wins")
        elseif score2 > score then
          print("p2 wins!", 45, 60, 11)
          _log("p2_wins")
        else
          print("tie!", 52, 60, 14)
          _log("tie")
        end
      end
    end

    print("press z to menu", 36, 105, 3)
  end
end

-- stats state
function update_stats()
  if btnp(4) then  -- z button
    _log("state:menu")
    state = "menu"
    music(0)  -- return to menu music
    sfx(2)  -- ui sound
  end
end

function draw_stats()
  print("statistics", 48, 5, 7)

  -- high scores
  print("high scores:", 10, 20, 11)
  for i = 1, 5 do
    local score_str = ""..high_scores[i]
    if high_scores[i] > 0 then
      print("#"..i.." "..score_str, 15, 25 + (i - 1) * 8, 7)
    else
      print("#"..i.." ---", 15, 25 + (i - 1) * 8, 5)
    end
  end

  -- stats
  local avg = 0
  if games_played > 0 then
    avg = flr(total_score_sum / games_played)
  end
  print("games:"..games_played, 65, 25, 6)
  print("best:"..personal_best, 65, 35, 6)
  print("avg:"..avg, 65, 45, 6)
  print("time:"..best_time.."s", 65, 55, 6)

  print("press z to menu", 30, 110, 3)
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
000000000033300000030000003333000099999900cccccc00000000000000000000000000000000000000000000000000000000000000000000000000000
00000000033bb30033cc33000033333000099999900cccccc00000000000000000000000000000000000000000000000000000000000000000000000000000
0000000003333300033cc33000033333000099999900cccccc00000000000000000000000000000000000000000000000000000000000000000000000000000
000000000033300000030000003333000099999900cccccc00000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000003333000099999900cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
033cc330033333300099999900cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
033cc330033333300099999900cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
033cc330033333300099999900cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
033cc330033333300099999900cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
033cc330033333300099999900cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000003333000099999900cccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
33333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333333
__sfx__
010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000006e0668036603660363036503650365036503650365036503600365000000000000000000000000000000000000000000000000000000000000000000
0010000007050705070507050705070507050705070507050705070507050705070507050705070507050705070507050705070507050705070507050705070507
001000005a05640568055605570055005b005f00630062005e005a00560051004d0049004500410000000000000000000000000000000000000000000000000
0010000067066d066606650060005b005700530000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000003c05450552005c0060006500690065006b0062005d005800520050004d00490046004300400000000000000000000000000000000000000000000000
00100000075007050705070507050705070507050705070507050505050505050505050505050505050505050505050505050505050505050505050505050505050
0010000045054605470548054905470545054305400540053f053e053e053d053d053c053c053b053b053a053a053900590058005700570056005600550055005400
001000008d058d058d058d058d058d058d058d058d058d058d058d058d058d058d050000000000000000000000000000000000000000000000000000000000000
001000004706480649064a064b064a064906480646000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00010102 00010102 00010102 00010102
01 02000000 00000000 00000000 00000000
