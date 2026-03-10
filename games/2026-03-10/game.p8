pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- tower guardian - turn-based tower defense - 2026-03-10

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

-- game state
state = "menu"
gold = 100
wave = 1
lives = 3
enemies_killed = 0
cursor = {x=1, y=1}
tower_type = 1
towers = {}
enemies = {}
beams = {}
bursts = {}
particles = {}
wave_timer = 0
selected_tower = nil -- for selling
difficulty = 2 -- 1=easy, 2=normal, 3=hard
difficulty_cursor = 2 -- cursor for difficulty selection
screen_shake = 0 -- screen shake intensity/timer

-- difficulty settings
diff_max_waves = {3, 5, 7}
diff_spawn = {{1, 0.6}, {2, 0.8}, {3, 1.0}} -- {base, scale}
diff_speed = {{0.15, 0.03}, {0.2, 0.04}, {0.25, 0.05}} -- {base, scale}
diff_gold = {125, 100, 75}
diff_names = {"easy", "normal", "hard"}

-- tower types: 1=basic(cost:10), 2=spread(cost:20), 3=slow(cost:15)
t_cost = {10, 20, 15}
t_range = {2, 3, 2}
t_damage = {1, 1, 1}
t_names = {"basic", "spread", "slow"}

function _update()
  if state == "menu" then update_menu()
  elseif state == "difficulty_select" then update_difficulty_select()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end

function update_menu()
  if btnp(4) or btnp(5) then
    state = "difficulty_select"
    difficulty_cursor = 2
    _log("state:difficulty_select")
  end
end

function update_difficulty_select()
  -- cursor movement
  if btnp(2) then difficulty_cursor = max(1, difficulty_cursor-1) end
  if btnp(3) then difficulty_cursor = min(3, difficulty_cursor+1) end

  -- confirm
  if btnp(4) or btnp(5) then
    difficulty = difficulty_cursor
    _log("difficulty:"..diff_names[difficulty])
    state = "play"
    wave = 1
    gold = diff_gold[difficulty]
    lives = 3
    enemies_killed = 0
    towers = {}
    enemies = {}
    beams = {}
    bursts = {}
    particles = {}
    wave_timer = 0
    screen_shake = 0
    _log("state:play")
    music(1)
    spawn_wave()
  end
end

function spawn_wave()
  -- difficulty-based spawn settings
  local base = diff_spawn[difficulty][1]
  local scale = diff_spawn[difficulty][2]
  local count = base + flr(wave * scale)
  local speed_base = diff_speed[difficulty][1]
  local speed_scale = diff_speed[difficulty][2]
  local base_speed = speed_base + wave * speed_scale
  for i=1, count do
    add(enemies, {x=-i*8, y=rnd(16), speed=base_speed, hp=1, age=0, hit_flash=0})
  end
  _log("wave:"..wave)
end

function create_particles(cx, cy, count)
  -- create radiating particles from impact point
  for i=1, count do
    local angle = (i / count) * 1 -- angle in turns (0-1)
    local speed = 0.3 + rnd(0.2)
    local vx = cos(angle) * speed
    local vy = sin(angle) * speed
    add(particles, {x=cx, y=cy, vx=vx, vy=vy, age=0, ttl=4})
  end
end

function update_play()
  -- cursor
  if btnp(0) then cursor.x = max(0, cursor.x-1) end
  if btnp(1) then cursor.x = min(15, cursor.x+1) end
  if btnp(2) then cursor.y = max(0, cursor.y-1) end
  if btnp(3) then cursor.y = min(15, cursor.y+1) end

  -- cycle tower type (x button)
  if btnp(5) then
    tower_type += 1
    if tower_type > 3 then tower_type = 1 end
    _log("tower_selected:"..t_names[tower_type])
  end

  -- place tower (z button) or sell tower
  if btnp(4) then
    -- check if cursor is on existing tower
    local tower_at_cursor = nil
    for t in all(towers) do
      if t.x == cursor.x and t.y == cursor.y then
        tower_at_cursor = t
        break
      end
    end

    if tower_at_cursor then
      -- sell tower for 50% refund
      gold += flr(t_cost[tower_at_cursor.type] * 0.5)
      del(towers, tower_at_cursor)
      sfx(2)
      _log("tower_sold")
    elseif gold >= t_cost[tower_type] then
      -- place new tower
      add(towers, {x=cursor.x, y=cursor.y, type=tower_type})
      gold -= t_cost[tower_type]
      sfx(tower_type - 1)
      _log("tower_placed:"..t_names[tower_type])
    end
  end

  -- move enemies
  for e in all(enemies) do
    e.age += 1
    e.x += e.speed
    e.hit_flash -= 1

    -- lost
    if e.x > 15 then
      del(enemies, e)
      lives -= 1
      _log("enemy_reached_goal")
      if lives <= 0 then
        state = "gameover"
        _log("gameover:lose")
        sfx(6)
        music(-1)
        return
      end
    end
  end

  -- towers shoot
  for t in all(towers) do
    -- find target
    local target = nil
    local min_x = 999
    for e in all(enemies) do
      local d = abs(e.x - t.x) + abs(e.y - t.y)
      if d <= t_range[t.type] and e.x < min_x then
        target = e
        min_x = e.x
      end
    end

    if target then
      -- check if close range for screen shake
      local close = abs(target.x - t.x) < 4
      if close then screen_shake = 3 end

      if t.type == 2 then
        -- spread: hit multiple
        _log("tower_attack:spread")
        for e in all(enemies) do
          local d = abs(e.x - target.x) + abs(e.y - target.y)
          if d <= 2 then
            e.hp -= 0.5
            e.hit_flash = 3
            -- create beam from tower to this enemy
            add(beams, {x0=t.x*8+4, y0=t.y*8+4, x1=flr(e.x)*8+4, y1=e.y*8+4, age=0, duration=3, type=2})
            -- create burst at enemy with particles
            add(bursts, {x=flr(e.x)*8+4, y=e.y*8+4, age=0, type=2})
            create_particles(flr(e.x)*8+4, e.y*8+4, 10)
          end
        end
      elseif t.type == 3 then
        -- slow: deals damage and slows
        _log("tower_attack:slow")
        target.hp -= 1
        target.hit_flash = 3
        target.speed = 0.05
        -- create beam from tower to target
        add(beams, {x0=t.x*8+4, y0=t.y*8+4, x1=flr(target.x)*8+4, y1=target.y*8+4, age=0, duration=3, type=3})
        -- create burst at target with particles
        add(bursts, {x=flr(target.x)*8+4, y=target.y*8+4, age=0, type=3})
        create_particles(flr(target.x)*8+4, target.y*8+4, 8)
      else
        -- basic
        _log("tower_attack:basic")
        target.hp -= 1
        target.hit_flash = 3
        -- create beam from tower to target
        add(beams, {x0=t.x*8+4, y0=t.y*8+4, x1=flr(target.x)*8+4, y1=target.y*8+4, age=0, duration=3, type=1})
        -- create burst at target with particles
        add(bursts, {x=flr(target.x)*8+4, y=target.y*8+4, age=0, type=1})
        create_particles(flr(target.x)*8+4, target.y*8+4, 9)
      end
    end
  end

  -- remove dead enemies
  for e in all(enemies) do
    if e.hp <= 0 then
      del(enemies, e)
      gold += 10
      enemies_killed += 1
      sfx(3)
      _log("enemy_killed")
    end
  end

  -- update beams (age and remove expired ones)
  for b in all(beams) do
    b.age += 1
    if b.age > b.duration then
      del(beams, b)
    end
  end

  -- update bursts (age and remove expired ones)
  for b in all(bursts) do
    b.age += 1
    if b.age > 2 then
      del(bursts, b)
    end
  end

  -- update particles
  for p in all(particles) do
    p.x += p.vx
    p.y += p.vy
    p.age += 1
    if p.age > p.ttl then
      del(particles, p)
    end
  end

  -- decay screen shake
  if screen_shake > 0 then
    screen_shake -= 1
  end

  -- wave progress
  wave_timer += 1
  if #enemies == 0 and wave_timer > 30 then
    if wave >= diff_max_waves[difficulty] then
      state = "gameover"
      _log("gameover:win")
      sfx(5)
      music(-1)
    else
      sfx(4)
      wave += 1
      wave_timer = 0
      spawn_wave()
    end
  end
end

function update_gameover()
  if btnp(4) or btnp(5) then
    state = "menu"
    _log("state:menu")
    music(0)
  end
end

function _draw()
  cls(0)
  if state == "menu" then
    draw_menu()
  elseif state == "difficulty_select" then
    draw_difficulty_select()
  elseif state == "play" then
    draw_play()
  elseif state == "gameover" then
    draw_gameover()
  end
end

function draw_menu()
  print("tower guardian", 35, 20, 7)
  print("tower defense game", 25, 30, 7)
  print("", 0, 40, 0)
  print("place towers to stop", 20, 50, 6)
  print("enemies from reaching", 20, 58, 6)
  print("the goal on the right.", 20, 66, 6)
  print("", 0, 75, 0)
  print("arrows: move cursor", 20, 85, 12)
  print("z: place tower", 35, 93, 12)
  print("x: cycle towers", 35, 101, 12)
  print("survive 5 waves!", 35, 112, 10)
  print("press z to start", 32, 121, 10)
end

function draw_difficulty_select()
  print("select difficulty", 32, 30, 7)
  print("", 0, 40, 0)
  local y = 50
  for i=1, 3 do
    local col = 7
    local prefix = "  "
    if i == difficulty_cursor then
      col = 11
      prefix = "> "
    end
    print(prefix..diff_names[i], 40, y, col)
    y += 20
  end
  print("", 0, 100, 0)
  print("arrows: select", 35, 110, 12)
  print("z: confirm", 40, 120, 10)
end

function draw_play()
  -- apply screen shake
  local shake_x = 0
  local shake_y = 0
  if screen_shake > 0 then
    shake_x = (screen_shake % 2 == 0) and 1 or -1
    shake_y = (screen_shake % 2 == 1) and 1 or 0
  end
  camera(shake_x, shake_y)

  -- grid background
  for x=0, 15 do
    line(x*8, 0, x*8, 127, 1)
  end
  for y=0, 15 do
    line(0, y*8, 127, y*8, 1)
  end

  -- goal zone
  rectfill(120, 0, 127, 127, 5)

  -- towers
  for t in all(towers) do
    -- draw tower sprite (0=basic, 1=spread, 2=slow)
    spr(t.type-1, t.x*8, t.y*8)
    -- range indicator
    local col = 11
    if t.type == 2 then col = 9
    elseif t.type == 3 then col = 8
    end
    circ(t.x*8+4, t.y*8+4, t_range[t.type]*8, col)
  end

  -- cursor (improved visibility)
  local cx = cursor.x*8
  local cy = cursor.y*8
  rect(cx, cy, cx+7, cy+7, 15)
  rect(cx+1, cy+1, cx+6, cy+6, 7)

  -- draw beams (tower attack animations) with variety by tower type
  for b in all(beams) do
    local col = 11
    if b.age > b.duration - 1 then col = 7 end

    if b.type == 1 then
      -- basic: thin single line
      line(b.x0, b.y0, b.x1, b.y1, col)
    elseif b.type == 2 then
      -- spread: thick lines for more impact
      line(b.x0, b.y0, b.x1, b.y1, col)
      if b.age < 2 then
        line(b.x0+1, b.y0, b.x1+1, b.y1, col)
        line(b.x0-1, b.y0, b.x1-1, b.y1, col)
      end
    else
      -- slow: wavy line with pulsing color
      line(b.x0, b.y0, b.x1, b.y1, col)
      if b.age % 2 == 0 then
        -- pulsing glow
        local pc = col == 7 and 7 or 8
        line(b.x0+1, b.y0+1, b.x1+1, b.y1+1, pc)
      end
    end
  end

  -- draw bursts (multi-ring explosion patterns)
  for b in all(bursts) do
    local col = 9
    if b.age > 1 then col = 8 end

    if b.type == 1 then
      -- basic: 3-ring expansion
      local r1 = b.age + 1
      circ(b.x, b.y, r1, col)
    elseif b.type == 2 then
      -- spread: wider rings
      local r1 = b.age + 1
      local r2 = b.age * 1.5
      circ(b.x, b.y, r1, col)
      if b.age < 2 then circ(b.x, b.y, r2 + 1, 9) end
    else
      -- slow: slow expanding rings
      local r1 = flr(b.age * 0.8) + 1
      local r2 = flr(b.age * 1.2) + 2
      local r3 = flr(b.age * 1.6) + 3
      circ(b.x, b.y, r1, col)
      if b.age < 2 then
        circ(b.x, b.y, r2, 8)
        circ(b.x, b.y, r3, 5)
      end
    end
  end

  -- draw particles
  for p in all(particles) do
    local px = flr(p.x)
    local py = flr(p.y)
    local pcol = 11 - flr((p.age / p.ttl) * 4) -- fade from yellow to dim
    pset(px, py, pcol)
    if p.age < 2 then
      pset(px+1, py, pcol)
      pset(px, py+1, pcol)
    end
  end

  -- enemies
  for e in all(enemies) do
    local ex = flr(e.x)*8
    local ey = e.y*8
    -- draw enemy sprite (3=normal, 4=slowed)
    if e.speed < 0.1 then
      spr(4, ex, ey)
    else
      spr(3, ex, ey)
    end
    -- hit flash effect
    if e.hit_flash > 0 then
      rectfill(ex, ey, ex+7, ey+7, 7)
    end
  end

  -- reset camera
  camera(0, 0)

  -- tower selector (improved clarity)
  local sname = t_names[tower_type]
  local sel_str = sname.." ($"..t_cost[tower_type]..")"
  rectfill(2, 2, 80, 10, 1)
  print(sel_str, 5, 4, 7)

  -- difficulty display (top-right)
  print(diff_names[difficulty], 100, 4, 11)

  -- info bar at bottom
  local max_w = diff_max_waves[difficulty]
  print("wave "..wave.."/"..max_w, 3, 120, 7)
  print("gold "..gold, 40, 120, 11)
  print("lives "..lives, 75, 120, 12)
end

function draw_gameover()
  cls(0)
  if lives > 0 then
    print("victory!", 50, 30, 11)
    print("all 5 waves defeated", 20, 45, 11)
  else
    print("defeated", 45, 30, 8)
    print("enemies breached defenses", 15, 45, 8)
  end
  print("", 0, 60, 0)
  print("waves: "..wave, 45, 75, 7)
  print("enemies killed: "..enemies_killed, 30, 85, 7)
  print("gold earned: "..gold, 35, 95, 11)
  print("", 0, 105, 0)
  print("press z for menu", 35, 120, 10)
end
__gfx__
011111100999999008888880008888000055550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1bbbbbb190999909800880080888888005555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1bbbbbb199099099808080088888888855555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1bbb0bb199990999880000888888888855555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1bbbbbb199990999880000888888888855555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1bbbbbb199099099808080088888888555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1bbbbbb190999909800880080888888005555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011111100999999008888880008888000055550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000e3610e36100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000009361000000d3610d36100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000011360000001236102236100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000007360c3610c36107360000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010200000e3610e3610e3610e3610e361000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0201000011361136113611361136113611361136110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
020200001536153615361536100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 00000000
01 00010203
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

