pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- tower defense 2026-04-03

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
gold = 200
lives = 3
wave = 0
max_waves = 5
selected_tower = 1
grid_x, grid_y = 2, 2

-- towers: id, x, y, type, cooldown
towers = {}

-- enemies: x, y, hp, path_idx
enemies = {}

-- projectiles: x, y, dx, dy, dmg, from_type
projectiles = {}

-- tower types: cost, fire_range, damage, cooldown, effect
tower_types = {
  {name="basic", cost=50, range=24, dmg=10, cd=15},
  {name="cannon", cost=100, range=40, dmg=30, cd=20},
  {name="stun", cost=75, range=30, dmg=0, cd=25},
  {name="multi", cost=80, range=28, dmg=8, cd=18}
}

-- enemy path (clockwise around border)
enemy_path = {
  {8,8},{16,8},{24,8},{32,8},{40,8},{48,8},{56,8},{64,8},{72,8},{80,8},{88,8},{96,8},{104,8},{112,8},{120,8},
  {120,16},{120,24},{120,32},{120,40},{120,48},{120,56},{120,64},{120,72},{120,80},{120,88},{120,96},{120,104},{120,112},{120,120},
  {112,120},{104,120},{96,120},{88,120},{80,120},{72,120},{64,120},{56,120},{48,120},{40,120},{32,120},{24,120},{16,120},{8,120},
  {8,112},{8,104},{8,96},{8,88},{8,80},{8,72},{8,64},{8,56},{8,48},{8,40},{8,32},{8,24},{8,16}
}

-- wave definitions
waves = {
  {cnt=3, hp=10, spd=0.8, gld=20},
  {cnt=4, hp=15, spd=1.0, gld=25},
  {cnt=5, hp=20, spd=1.2, gld=30},
  {cnt=6, hp=25, spd=1.4, gld=35},
  {cnt=8, hp=30, spd=1.6, gld=40}
}

function _init()
  _log("state:menu")
end

function _update()
  if state == "menu" then update_menu()
  elseif state == "tower_placement" then update_placement()
  elseif state == "wave_in_progress" then update_wave()
  elseif state == "gameover" then update_gameover()
  end
end

function _draw()
  cls(0)
  if state == "menu" then draw_menu()
  elseif state == "tower_placement" then draw_placement()
  elseif state == "wave_in_progress" then draw_wave()
  elseif state == "gameover" then draw_gameover()
  end
end

-- menu state
function update_menu()
  if btnp(4) then
    state = "tower_placement"
    wave = 1
    _log("state:tower_placement")
  end
end

function draw_menu()
  print("tower defense", 35, 20, 7)
  print("place towers to stop", 20, 35, 7)
  print("enemy waves", 40, 43, 7)
  print("earn gold from kills", 20, 55, 7)
  print("survive 5 waves!", 35, 63, 7)
  print("z: start", 50, 85, 11)
end

-- tower placement state
function update_placement()
  -- cursor movement
  if btnp(0) then grid_x = max(1, grid_x-1) end
  if btnp(1) then grid_x = min(14, grid_x+1) end
  if btnp(2) then grid_y = max(1, grid_y-1) end
  if btnp(3) then grid_y = min(14, grid_y+1) end

  -- tower selection
  if btnp(4) then
    -- place/remove tower
    local found = false
    for i, t in ipairs(towers) do
      if t.x == grid_x and t.y == grid_y then
        gold += tower_types[t.type].cost / 2  -- refund half
        del(towers, t)
        found = true
        break
      end
    end
    if not found and gold >= tower_types[selected_tower].cost then
      add(towers, {x=grid_x, y=grid_y, type=selected_tower, cd=0, hp=tower_types[selected_tower].cd})
      gold -= tower_types[selected_tower].cost
      _log("tower_placed:type"..selected_tower)
    end
  end
  if btnp(5) then
    selected_tower = selected_tower % 4 + 1
  end

  -- start wave
  if btn(2) then
    state = "wave_in_progress"
    _log("state:wave_in_progress:wave"..wave)
    enemies = {}
    for t in all(towers) do t.cd = 0 end
  end
end

function draw_placement()
  -- draw grid
  for x = 0, 13 do
    for y = 0, 13 do
      local px, py = x * 8 + 8, y * 8 + 8
      print(".", px, py, 1)
    end
  end

  -- draw towers
  for t in all(towers) do
    local px, py = (t.x-1) * 8 + 8, (t.y-1) * 8 + 8
    local col = 2 + t.type
    circfill(px+2, py+2, 3, col)
  end

  -- draw cursor
  local cx, cy = (grid_x-1) * 8 + 8, (grid_y-1) * 8 + 8
  rect(cx, cy, cx+7, cy+7, 7)

  -- draw ui
  print("wave "..wave.." setup", 10, 118, 7)
  print("gold:"..gold.." sel:"..selected_tower, 10, 125, 7)
end

-- wave play state
function update_wave()
  -- spawn enemies at start
  if #enemies == 0 and wave > 0 then
    local w = waves[wave]
    if w then
      for i = 1, w.cnt do
        add(enemies, {x=8, y=8, hp=w.hp, idx=1, dmg=0, spd=w.spd, gld=w.gld})
      end
      _log("wave_start:"..wave)
    end
  end

  -- update enemies
  for e in all(enemies) do
    e.dmg = max(0, e.dmg - 0.1)
    local next_idx = min(e.idx + e.spd * 0.016, #enemy_path)
    e.idx = next_idx
    if next_idx >= #enemy_path then
      _log("enemy_reached_goal")
      lives -= 1
      del(enemies, e)
    else
      local p = enemy_path[flr(e.idx)]
      e.x = p[1]
      e.y = p[2]
    end
  end

  -- tower shooting
  for t in all(towers) do
    t.cd = max(0, t.cd - 1)
    if t.cd <= 0 then
      local tx, ty = (t.x-1)*8+12, (t.y-1)*8+12
      local tgt = nil
      local min_dist = t.hp

      for e in all(enemies) do
        local d = dist(tx, ty, e.x, e.y)
        if d < min_dist then
          min_dist = d
          tgt = e
        end
      end

      if tgt then
        t.cd = tower_types[t.type].cd
        if t.type == 1 or t.type == 2 then
          -- basic or cannon
          local dx, dy = tgt.x - tx, tgt.y - ty
          local len = sqrt(dx*dx + dy*dy)
          if len > 0 then
            dx, dy = dx/len, dy/len
            add(projectiles, {x=tx, y=ty, dx=dx, dy=dy, dmg=tower_types[t.type].dmg, type=t.type})
          end
        elseif t.type == 3 then
          -- stun
          tgt.dmg = 10
        elseif t.type == 4 then
          -- multi
          for a = -0.3, 0.3, 0.3 do
            local dx, dy = tgt.x - tx, tgt.y - ty
            local len = sqrt(dx*dx + dy*dy)
            if len > 0 then
              local ang = atan2(dy, dx) + a
              dx, dy = cos(ang), sin(ang)
              add(projectiles, {x=tx, y=ty, dx=dx, dy=dy, dmg=tower_types[t.type].dmg, type=t.type})
            end
          end
        end
      end
    end
  end

  -- update projectiles
  for p in all(projectiles) do
    p.x += p.dx * 2
    p.y += p.dy * 2
    local hit = false

    for e in all(enemies) do
      if dist(p.x, p.y, e.x, e.y) < 6 then
        e.hp -= p.dmg
        hit = true
        if e.hp <= 0 then
          _log("enemy_defeated")
          gold += e.gld
          del(enemies, e)
        end
        break
      end
    end

    if hit or p.x < 0 or p.x > 128 or p.y < 0 or p.y > 128 then
      del(projectiles, p)
    end
  end

  -- check wave end
  if #enemies == 0 and wave < max_waves then
    wave += 1
    _log("wave_complete:"..wave-1)
    state = "tower_placement"
    _log("state:tower_placement")
  elseif #enemies == 0 and wave == max_waves then
    state = "gameover"
    _log("gameover:win")
  end

  -- check lose
  if lives <= 0 then
    state = "gameover"
    _log("gameover:lose")
  end
end

function draw_wave()
  -- draw path
  for p in all(enemy_path) do
    pset(p[1], p[2], 1)
  end

  -- draw towers
  for t in all(towers) do
    local px, py = (t.x-1)*8+12, (t.y-1)*8+12
    local col = 2 + t.type
    circfill(px, py, 3, col)
  end

  -- draw enemies
  for e in all(enemies) do
    local c = 8
    if e.dmg > 0 then c = 7 end
    circfill(e.x, e.y, 2, c)
  end

  -- draw projectiles
  for p in all(projectiles) do
    pset(flr(p.x), flr(p.y), 10)
  end

  -- draw ui
  print("wave:"..wave, 6, 118, 7)
  print("gold:"..gold, 40, 118, 7)
  print("lives:"..lives, 80, 118, 7)
end

-- gameover state
function update_gameover()
  if btnp(4) then
    state = "menu"
    gold = 200
    lives = 3
    wave = 0
    towers = {}
    enemies = {}
    projectiles = {}
    _log("state:menu")
  end
end

function draw_gameover()
  if wave == max_waves + 1 or (lives > 0 and wave == max_waves) then
    print("victory!", 45, 40, 11)
    print("all waves defeated!", 25, 50, 7)
  else
    print("defeat!", 45, 40, 8)
    print("enemies breached!", 30, 50, 7)
  end
  print("z: menu", 50, 90, 7)
end

-- helpers
function dist(x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  return sqrt(dx*dx + dy*dy)
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
__label__
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff0ffff0ffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff0ffff0ffff0ffff
ffff0ffff0ffff000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000ff000ffff0ffff0ffff0ffff
ffff0ffff0ffff000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000ff000ffff0ffff0ffff0ffff
ffff0ffff0ffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff0ffff0ffff0ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffff0ffff0ffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff0ffff0ffff0ffff
ffff0ffff0ffff000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000ff000ffff0ffff0ffff0ffff
ffff0ffff0ffff000ff00000000000000000000000000000000000000000000000000000000000000000000000000000000ff000ffff0ffff0ffff0ffff
ffff0ffff0ffff0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff0ffff0ffff0ffff
ffff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
