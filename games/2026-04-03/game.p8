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
  return btn(b)
end

-- game state
state = "menu"
gold = 200
lives = 3
wave = 0
max_waves = 9
selected_tower = 1
grid_x, grid_y = 2, 2
is_boss_wave = false

-- towers: id, x, y, type, cooldown
towers = {}

-- enemies: x, y, hp, path_idx
enemies = {}

-- projectiles: x, y, dx, dy, dmg, from_type
projectiles = {}

-- tower types: cost, fire_range, damage, cooldown, effect
tower_types = {
  {name="basic", cost=50, range=24, dmg=10, cd=15, desc="fast:attack"},
  {name="cannon", cost=100, range=40, dmg=30, cd=20, desc="high:damage"},
  {name="stun", cost=75, range=30, dmg=0, cd=25, desc="stun:slow"},
  {name="multi", cost=80, range=28, dmg=8, cd=18, desc="spread:shots"},
  {name="splash", cost=90, range=32, dmg=12, cd=22, desc="aoe:damage"},
  {name="slow", cost=70, range=28, dmg=2, cd=16, desc="crowd:control"},
  {name="laser", cost=120, range=50, dmg=25, cd=25, desc="line:attack"}
}

-- enemy types: speed_mult, hp_mult, gold_mult, color
enemy_types = {
  normal = {name="normal", spd_m=1.0, hp_m=1.0, gld_m=1.0, col=3},
  scout = {name="scout", spd_m=2.0, hp_m=0.5, gld_m=1.0, col=1},
  tank = {name="tank", spd_m=0.5, hp_m=2.0, gld_m=1.5, col=8},
  swarm = {name="swarm", spd_m=1.0, hp_m=0.6, gld_m=1.0, col=10}
}

-- enemy path (clockwise around border)
enemy_path = {
  {8,8},{16,8},{24,8},{32,8},{40,8},{48,8},{56,8},{64,8},{72,8},{80,8},{88,8},{96,8},{104,8},{112,8},{120,8},
  {120,16},{120,24},{120,32},{120,40},{120,48},{120,56},{120,64},{120,72},{120,80},{120,88},{120,96},{120,104},{120,112},{120,120},
  {112,120},{104,120},{96,120},{88,120},{80,120},{72,120},{64,120},{56,120},{48,120},{40,120},{32,120},{24,120},{16,120},{8,120},
  {8,112},{8,104},{8,96},{8,88},{8,80},{8,72},{8,64},{8,56},{8,48},{8,40},{8,32},{8,24},{8,16}
}

-- wave definitions: cnt, hp, spd, gld, boss, etype
waves = {
  {cnt=3, hp=10, spd=0.8, gld=20, boss=false, etype="normal"},
  {cnt=4, hp=12, spd=0.9, gld=25, boss=false, etype="scout"},
  {cnt=5, hp=8, spd=0.8, gld=15, boss=false, etype="swarm"},
  {cnt=5, hp=18, spd=1.1, gld=35, boss=false, etype="normal"},
  {cnt=2, hp=35, spd=1.3, gld=50, boss=true, etype="normal"},
  {cnt=3, hp=40, spd=1.0, gld=60, boss=false, etype="tank"},
  {cnt=8, hp=6, spd=1.4, gld=12, boss=false, etype="swarm"},
  {cnt=2, hp=45, spd=1.5, gld=60, boss=true, etype="normal"},
  {cnt=6, hp=30, spd=1.6, gld=55, boss=false, etype="normal"}
}

function _init()
  music(0)  -- start menu music
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
  if test_input(4) then
    sfx(6)  -- ui selection sound
    music(-1)  -- stop menu music
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
  print("survive 9 waves!", 35, 63, 7)
  print("z: start", 50, 85, 11)
end

-- tower placement state
function update_placement()
  -- cursor movement
  if test_input(0) then grid_x = max(1, grid_x-1) end
  if test_input(1) then grid_x = min(14, grid_x+1) end
  if test_input(2) then grid_y = max(1, grid_y-1) end
  if test_input(3) then grid_y = min(14, grid_y+1) end

  -- tower selection
  if test_input(4) then
    -- place/remove tower
    local found = false
    for i, t in ipairs(towers) do
      if t.x == grid_x and t.y == grid_y then
        gold += tower_types[t.type].cost / 2  -- refund half
        del(towers, t)
        sfx(7)  -- ui click sound
        found = true
        break
      end
    end
    if not found and gold >= tower_types[selected_tower].cost then
      add(towers, {x=grid_x, y=grid_y, type=selected_tower, cd=0})
      gold -= tower_types[selected_tower].cost
      sfx(0)  -- tower placement confirmation
      _log("tower_placed:type"..selected_tower)
    end
  end
  if test_input(5) then
    selected_tower = selected_tower % 7 + 1
  end

  -- start wave
  if test_input(2) then
    sfx(5)  -- wave start alert
    music(1)  -- start game music
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
    if t.type == 5 then col = 14 end  -- splash: yellow
    if t.type == 6 then col = 12 end  -- slow: blue
    if t.type == 7 then col = 9 end   -- laser: red
    circfill(px+2, py+2, 3, col)
  end

  -- draw cursor with tower selection highlight
  local cx, cy = (grid_x-1) * 8 + 8, (grid_y-1) * 8 + 8
  rect(cx-1, cy-1, cx+8, cy+8, selected_tower+1)  -- highlight border
  rect(cx, cy, cx+7, cy+7, 7)

  -- draw ui
  local w = waves[wave]
  local wave_type = "wave "..wave.." setup"
  local wave_col = 7
  if w and w.boss then
    wave_type = "* boss wave! *"
    wave_col = 9
  end
  print(wave_type, 10, 118, wave_col)

  -- draw tower selection with description
  local t = tower_types[selected_tower]
  local cost_str = t.cost.."g"
  print(selected_tower..":"..t.name, 10, 123, 3)
  print(cost_str.." "..t.desc, 10, 128, 2)

  print("gold:"..gold, 60, 123, 7)
  print("x: switch tower", 60, 128, 2)
end

-- wave play state
function update_wave()
  -- spawn enemies at start
  if #enemies == 0 and wave > 0 then
    local w = waves[wave]
    if w then
      is_boss_wave = w.boss or false
      local et = enemy_types[w.etype or "normal"] or enemy_types.normal
      for i = 1, w.cnt do
        local hp = flr(w.hp * et.hp_m)
        local gld = flr(w.gld * et.gld_m)
        add(enemies, {x=8, y=8, hp=hp, idx=1, dmg=0, spd=w.spd*et.spd_m, gld=gld, boss=is_boss_wave, etype=w.etype or "normal", col=et.col})
      end
      if is_boss_wave then
        sfx(8)  -- boss alert sound
        _log("boss_wave:"..wave)
      else
        _log("wave_start:"..wave.." type:"..w.etype)
      end
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
      local min_dist = tower_types[t.type].range

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
          -- basic or cannon: shoot projectile
          local dx, dy = tgt.x - tx, tgt.y - ty
          local len = sqrt(dx*dx + dy*dy)
          if len > 0 then
            dx, dy = dx/len, dy/len
            add(projectiles, {x=tx, y=ty, dx=dx, dy=dy, dmg=tower_types[t.type].dmg, type=t.type})
          end
        elseif t.type == 3 then
          -- stun: apply stun effect
          tgt.dmg = 10
          _log("tower_stun")
        elseif t.type == 4 then
          -- multi: spread shots
          for a = -0.3, 0.3, 0.3 do
            local dx, dy = tgt.x - tx, tgt.y - ty
            local len = sqrt(dx*dx + dy*dy)
            if len > 0 then
              local ang = atan2(dy, dx) + a
              dx, dy = cos(ang), sin(ang)
              add(projectiles, {x=tx, y=ty, dx=dx, dy=dy, dmg=tower_types[t.type].dmg, type=t.type})
            end
          end
        elseif t.type == 5 then
          -- splash: damage area around target
          local splash_rad = 12
          local to_remove = {}
          for e in all(enemies) do
            if dist(tgt.x, tgt.y, e.x, e.y) < splash_rad then
              e.hp -= tower_types[t.type].dmg
              if e.hp <= 0 then
                sfx(1)
                _log("enemy_defeated")
                gold += e.gld
                add(to_remove, e)
              else
                e.dmg = 5
              end
            end
          end
          for e in all(to_remove) do
            del(enemies, e)
          end
          _log("tower_splash")
        elseif t.type == 6 then
          -- slow: reduce enemy speed
          tgt.spd *= 0.5
          tgt.dmg = 3
          _log("tower_slow")
        elseif t.type == 7 then
          -- laser: high damage projectile
          local dx, dy = tgt.x - tx, tgt.y - ty
          local len = sqrt(dx*dx + dy*dy)
          if len > 0 then
            dx, dy = dx/len, dy/len
            add(projectiles, {x=tx, y=ty, dx=dx, dy=dy, dmg=tower_types[t.type].dmg, type=t.type})
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
          sfx(1)  -- enemy killed sound
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
    sfx(2)  -- wave cleared sound
    _log("wave_complete:"..wave-1)
    state = "tower_placement"
    music(-1)  -- stop game music
    _log("state:tower_placement")
  elseif #enemies == 0 and wave == max_waves then
    state = "gameover"
    sfx(3)  -- victory fanfare
    music(-1)  -- stop music
    _log("gameover:win")
  end

  -- check lose
  if lives <= 0 then
    state = "gameover"
    sfx(4)  -- loss sound
    music(-1)  -- stop music
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
    if t.type == 5 then col = 14 end  -- splash: yellow
    if t.type == 6 then col = 12 end  -- slow: blue
    if t.type == 7 then col = 9 end   -- laser: red
    circfill(px, py, 3, col)
  end

  -- draw enemies
  for e in all(enemies) do
    local c = e.col or 3
    if e.dmg > 0 then c = 7 end  -- hit flash
    if e.boss then
      circfill(e.x, e.y, 4, 9)  -- boss: larger, red
      circfill(e.x, e.y, 3, c)
    else
      circfill(e.x, e.y, 2, c)
    end
  end

  -- draw projectiles
  for p in all(projectiles) do
    pset(flr(p.x), flr(p.y), 10)
  end

  -- draw ui
  local wave_display = "wave:"..wave
  local wave_col = 7
  if is_boss_wave then
    wave_display = "boss:"..wave
    wave_col = 9
  end
  print(wave_display, 6, 118, wave_col)
  print("gold:"..gold, 40, 118, 7)
  print("lives:"..lives, 80, 118, 7)
end

-- gameover state
function update_gameover()
  if test_input(4) then
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
  if lives > 0 and wave == max_waves then
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

__sfx__
000100000f7f00f6f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00050000047500575067500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600002d5502d5502d5502d5500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001100000a6f0b6f0c6f0d6f0e6f0f6f0f6f0f6f0e6f0d6f0c6f0b6f0a6f000000000000000000000000000000000000000000000000000000000000000000000000
00110000036f026f016f006f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001100000a7f0b7f0c7f0d7f0e7f0f7f0f7f0f7f0e7f0d7f0c7f0b7f0a7f000000000000000000000000000000000000000000000000000000000000000000000000
000300000f5f00f5f00f5f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d4f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00110000000f011f022f033f044f055f066f077f088f099f0aaf0bbf0ccf0ddf0eef0ff000000000000000000000000000000000000000000000000000000000000

__music__
000100000000000100020003000400050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000000000100020003000400050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

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
