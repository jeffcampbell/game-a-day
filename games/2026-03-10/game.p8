pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- beat blast: rhythm game
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

-- game state machine
state = "menu"
difficulty = 1  -- 1=easy, 2=normal, 3=hard
score = 0
combo = 0
max_combo = 0
beat_idx = 0
beat_time = 0

-- difficulty settings: (bpm, target_window, multiplier)
difficulty_settings = {
  {bpm=100, window=8, mult=1.0},     -- easy
  {bpm=140, window=6, mult=1.5},     -- normal
  {bpm=180, window=4, mult=2.0}      -- hard
}

-- beat sequence: each beat is (lane, timing_offset)
-- lanes: 1=left, 2=down, 3=up, 4=right (o and x buttons)
beats = {
  {lane=1, time=1},   -- left
  {lane=3, time=1},   -- up
  {lane=2, time=1},   -- down
  {lane=4, time=1},   -- right
  {lane=1, time=1},   -- left
  {lane=4, time=1},   -- right
  {lane=3, time=1},   -- up
  {lane=2, time=1},   -- down
  {lane=1, time=2},   -- left
  {lane=3, time=1},   -- up
  {lane=1, time=1},   -- left
  {lane=4, time=2},   -- right
  {lane=2, time=1},   -- down
  {lane=3, time=1},   -- up
  {lane=1, time=1},   -- left
  {lane=4, time=1},   -- right
  {lane=2, time=1},   -- down
  {lane=3, time=1},   -- up
  {lane=1, time=2},   -- left
  {lane=2, time=2}    -- down (final)
}

-- falling notes
notes = {}

function _update()
  if state == "menu" then
    update_menu()
  elseif state == "play" then
    update_play()
  elseif state == "results" then
    update_results()
  elseif state == "gameover" then
    update_gameover()
  end
end

function _draw()
  cls(1)
  if state == "menu" then
    draw_menu()
  elseif state == "play" then
    draw_play()
  elseif state == "results" then
    draw_results()
  elseif state == "gameover" then
    draw_gameover()
  end
end

-- menu state: select difficulty
function update_menu()
  if btnp(0) and difficulty > 1 then
    difficulty -= 1
  end
  if btnp(1) and difficulty < 3 then
    difficulty += 1
  end
  if btnp(4) or btnp(5) then
    -- start game
    _log("state:play")
    _log("difficulty:"..difficulty)
    state = "play"
    beat_idx = 0
    beat_time = 0
    score = 0
    combo = 0
    max_combo = 0
    notes = {}
  end
end

function draw_menu()
  print("beat blast", 40, 20, 7)
  print("select difficulty:", 20, 40, 7)

  -- easy
  col = difficulty == 1 and 10 or 5
  print("> easy", 30, 55, col)

  -- normal
  col = difficulty == 2 and 10 or 5
  print("> normal", 30, 65, col)

  -- hard
  col = difficulty == 3 and 10 or 5
  print("> hard", 30, 75, col)

  print("press z/c to start", 10, 95, 6)
end

-- play state: run the game
function update_play()
  local settings = difficulty_settings[difficulty]
  local beat_duration = 60 / settings.bpm  -- frames per beat

  beat_time += 1

  -- spawn new notes
  while beat_idx < #beats and beat_time >= beat_idx * beat_duration do
    local b = beats[beat_idx + 1]
    add(notes, {
      lane = b.lane,
      spawn_time = beat_time,
      duration = beat_duration * (b.time or 1),
      y = -20,
      hit = false,
      accuracy = 0
    })
    beat_idx += 1
  end

  -- check input on each lane
  -- lane 1=left (btn 0), 2=down (btn 3), 3=up (btn 2), 4=right (btn 1)
  local lane_map = {0, 3, 2, 1}  -- btn indices for lanes 1-4
  local pressed = {}
  for i=1,4 do
    if btnp(lane_map[i]) then
      pressed[i] = true
    end
  end

  -- update notes and check hits
  local hit_this_frame = {}
  for note in all(notes) do
    note.y += 2.5

    -- check if note is in hit zone (around y=100)
    local hit_zone = 95
    local target_y = 100
    local accuracy = abs(note.y - target_y) / 20

    if note.y > hit_zone - 15 and note.y < hit_zone + 15 and not note.hit then
      if pressed[note.lane] and accuracy < 1 then
        note.hit = true
        local score_add = 10
        if accuracy < 0.3 then
          score_add = 50
          hit_this_frame.perfect = true
        elseif accuracy < 0.6 then
          score_add = 30
          hit_this_frame.good = true
        else
          score_add = 10
          hit_this_frame.ok = true
        end
        score += score_add
        combo += 1
        max_combo = max(max_combo, combo)
        _log("hit:lane"..note.lane..":score"..score_add)
      end
    end

    -- note missed (passed target zone)
    if note.y > target_y + 20 and not note.hit then
      note.hit = true
      combo = 0
      _log("miss:lane"..note.lane)
    end
  end

  -- remove off-screen notes
  local new_notes = {}
  for note in all(notes) do
    if note.y < 130 then
      add(new_notes, note)
    end
  end
  notes = new_notes

  -- check if all beats are done
  if beat_idx >= #beats and #notes == 0 then
    _log("state:results")
    _log("final_score:"..score)
    state = "results"
  end
end

function draw_play()
  local settings = difficulty_settings[difficulty]

  -- lane markers (4 lanes at x positions 30, 60, 90, 120)
  local lane_x = {30, 60, 90, 120}
  for i=1,4 do
    rect(lane_x[i]-8, 95, lane_x[i]+8, 105, 8)
  end

  -- draw falling notes
  for note in all(notes) do
    if not note.hit then
      circfill(lane_x[note.lane], note.y, 4, 11)
    end
  end

  -- ui
  print("beat blast", 5, 5, 7)
  print("score:"..score, 5, 15, 7)
  print("combo:"..combo, 60, 15, 7)
  print("diff:"..({"e","n","h"}[difficulty]), 110, 15, 3)
end

-- results state: show score
function update_results()
  if btnp(4) or btnp(5) then
    _log("state:gameover")
    state = "gameover"
  end
end

function draw_results()
  print("song complete!", 30, 30, 7)
  print("final score:"..score, 25, 50, 10)
  print("max combo:"..max_combo, 30, 70, 10)

  local target = 300
  local result = score >= target and "win!" or "try again"
  local col = score >= target and 11 or 8
  print(result, 50, 95, col)

  print("press z/c", 35, 110, 6)
end

-- gameover state
function update_gameover()
  if btnp(4) or btnp(5) then
    _log("state:menu")
    state = "menu"
    beat_idx = 0
    beat_time = 0
    score = 0
    combo = 0
    max_combo = 0
    notes = {}
  end
end

function draw_gameover()
  local won = max_combo >= 15 or score >= 300
  if won then
    print("you win!", 45, 40, 11)
  else
    print("game over", 35, 40, 8)
  end

  print("score:"..score, 40, 60, 7)
  print("combo:"..max_combo, 40, 70, 7)

  print("press z/c to menu", 15, 110, 6)
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
__sfx__
010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
