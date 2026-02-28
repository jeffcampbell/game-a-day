pico-8 cartridge // http://www.pico-8.com
version 42
__lua__

testmode = false
test_log = {}
test_inputs = {}
test_input_idx = 0
test_inputsp = {}
test_inputp_idx = 0

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

function test_inputp(b)
  if testmode and test_inputp_idx < #test_inputsp then
    test_inputp_idx += 1
    return test_inputsp[test_inputp_idx] or 0
  end
  return btnp(b)
end

state = "menu"
score = 0
hsc = 0
wave = 0
combo = 0
ekl = 0
tsv = 0
st = 0
pause_time = 0
shf = 0
shi = 0

df = "normal"
dfc = 2
gm = "normal"
msc = 1
bd = 0

bks = 0
bco = 0
bcs = 0
lms = 0
mts = {}
flt = 0
sft = 0
tas = 0  -- time attack spawn timer

as = {}
sas = {}
pcs = {}
qkf = false

-- leaderboards (top 3 per mode/difficulty)
lbs = {
  easy = {0,0,0},
  normal = {0,0,0},
  hard = {0,0,0},
  boss_rush = {0,0,0},
  time_attack = {0,0,0}
}

-- lifetime stats
ekl_tot = 0 -- total enemies killed
gp_cnt = 0 -- games played
nr = false -- new record flag

ads = {
  {id=1, name="first blood", desc="defeat first enemy", check=function() return ekl >= 1 end},
  {id=2, name="slinger", desc="reach wave 5", check=function() return wave >= 5 end},
  {id=3, name="wave veteran", desc="reach wave 10", check=function() return wave >= 10 end},
  {id=4, name="endurance", desc="survive 60s", check=function() return tsv >= 60 end},
  {id=5, name="sharpshooter", desc="kill 50 es", check=function() return ekl >= 50 end},
  {id=6, name="demolition", desc="kill 100 es", check=function() return ekl >= 100 end},
  {id=7, name="combo king", desc="25-hit combo", check=function() return combo >= 25 end},
  {id=8, name="unstoppable", desc="50-hit combo", check=function() return combo >= 50 end},
  {id=9, name="boss slayer", desc="defeat a boss", check=function() return bks >= 1 end},
  {id=10, name="quick kill", desc="kill boss in phase 1", check=function() return qkf end},
  {id=11, name="time master", desc="survive 180s", check=function() return tsv >= 180 end},
  {id=12, name="arsenal master", desc="collect all 4 power-ups", check=function()
    return pcs["RR"] and pcs["BS"] and pcs["SH"] and pcs["2X"]
  end},
  {id=13, name="boss extreme", desc="defeat 5 bosses in boss rush", check=function()
    return gm == "boss_rush" and bd >= 5
  end},
  {id=14, name="speed demon", desc="reach 500+ in time attack", check=function()
    return gm == "time_attack" and score >= 500
  end}
}

p = {}
es = {}
ps = {}
pups = {}
pts = {}
sqe = {}

rft = 0
bst = 0
smt = 0

dirs = {
  {1,0},
  {0.7,0.7},
  {0,1},
  {-0.7,0.7},
  {-1,0},
  {-0.7,-0.7},
  {0,-1},
  {0.7,-0.7}
}

function wim()

  return 1.0 + flr(wave / 5) * 0.15
end

function sdf()

  return max(0.5, 1 - 0.2 * flr(wave / 3))
end

function pdf()

  return 1.0 + flr(wave / 5) * 0.1
end

function bsh()

  if wave < 5 then
    return 0
  elseif wave < 10 then
    return 0.1
  elseif wave < 15 then
    return 0.2
  else
    return 0.3
  end
end

function _init()
  _log("init")
  cartdata("neon-slinger-v1")
  lda()
  inm()
end

function lda()
  local a = {dget(3) or 0, dget(4) or 0, dget(5) or 0, dget(24) or 0}
  as = {}
  for i=1,14 do
    local s = flr((i-1)/4)+1
    if a[s] & (1 << ((i-1) % 4)) > 0 then as[i] = true end
  end

  -- load leaderboards
  ldlb()

  -- load lifetime stats
  ekl_tot = dget(19) or 0
  gp_cnt = dget(20) or 0
  _log("loaded_stats:ekl="..ekl_tot..",gp="..gp_cnt)
end

function ldlb()
  local modes = {"easy","normal","hard","boss_rush","time_attack"}
  local slots = {{6,10,11},{7,12,13},{8,14,15},{16,17,18},{21,22,23}}
  for i=1,5 do
    lbs[modes[i]] = {dget(slots[i][1]) or 0, dget(slots[i][2]) or 0, dget(slots[i][3]) or 0}
  end
end

function sva()
  local a = {0,0,0,0}
  for i=1,14 do
    if as[i] then
      local s = flr((i-1)/4)+1
      a[s] = a[s] | (1 << ((i-1) % 4))
    end
  end
  dset(3,a[1]) dset(4,a[2]) dset(5,a[3]) dset(24,a[4])
end

function svlb()
  local modes = {"easy","normal","hard","boss_rush","time_attack"}
  local slots = {{6,10,11},{7,12,13},{8,14,15},{16,17,18},{21,22,23}}
  for i=1,5 do
    for j=1,3 do dset(slots[i][j], lbs[modes[i]][j]) end
  end
end

function inslb(mode, score)
  -- insert score into leaderboard, return rank (1-3) or 0
  local lb = lbs[mode]
  if not lb then return 0 end

  local rank = 0
  if score > lb[1] then
    lb[3] = lb[2]
    lb[2] = lb[1]
    lb[1] = score
    rank = 1
  elseif score > lb[2] then
    lb[3] = lb[2]
    lb[2] = score
    rank = 2
  elseif score > lb[3] then
    lb[3] = score
    rank = 3
  end

  if rank > 0 then
    svlb()
    _log("leaderboard:"..mode..",rank:"..rank..",score:"..score)
  end

  return rank
end

function cka()
  for _, def in pairs(ads) do
    if not as[def.id] and def.check() then
      una(def.id)
    end
  end
end

function una(id)
  as[id] = true
  sas[id] = true
  _log("achievement:"..id)


  sva()


  sfx(6)
  shf = 2
  shi = 0.5


  add(mts, {
    text = "achievement!",
    y = 50,
    life = 40,
    initial_life = 40,
    col = 12
  })
end

function cna()
  local count = 0
  for i=1,14 do
    if as[i] then count += 1 end
  end
  return count
end

function csa()
  local count = 0
  for i=1,14 do
    if sas[i] then count += 1 end
  end
  return count
end

function _update()
  if state == "menu" then
    upm()
  elseif state == "mode_select" then
    ums()
  elseif state == "difficulty_select" then
    uds()
  elseif state == "play" then
    upp()
  elseif state == "pause" then
    upau()
  elseif state == "gameover" then
    ugo()
  elseif state == "leaderboard_view" then
    ulv()
  end
end

function _draw()
  cls(0)
  if state == "menu" then
    drm()
  elseif state == "mode_select" then
    dms()
  elseif state == "difficulty_select" then
    dds()
  elseif state == "leaderboard_view" then
    dlv()
  elseif state == "play" then
    drp()
  elseif state == "pause" then
    drpau()
  elseif state == "gameover" then
    dgo()
  end
end

function inm()
  state = "menu"
  _log("state:menu")


  local last_diff = dget(9) or 2
  dfc = last_diff
  df = ({"easy","normal","hard"})[dfc]


  local diff_slot = 5 + dfc -- 6=easy, 7=normal, 8=hard
  hsc = dget(diff_slot) or 0

  bks = dget(1)
  bco = dget(2)
  music(0)
  _log("music:menu")
end

function upm()
  local input = test_input()
  if input & 16 > 0 then
    ims()
  end
  if test_inputp(5) then
    ilv()
  end
end

function ilv()
  state = "leaderboard_view"
  _log("state:leaderboard_view")
end

function drm()

  print("neon-slinger", 32, 40, 11)
  print("press o to start", 24, 60, 7)


  local diff_col = df == "easy" and 12 or (df == "hard" and 8 or 10)
  print("high: "..hsc.." ("..df..")", 20, 80, diff_col)

  -- as
  local ach_count = cna()
  print("as: "..ach_count.."/14", 20, 90, 12)

  -- controls
  print("l/r: rotate", 32, 100, 6)
  print("o: shoot", 36, 108, 6)
  print("x: leaderboard", 26, 116, 10)
end

function ims()
  state = "mode_select"
  _log("state:mode_select")
  music(-1)
end

function ums()
  local input = test_input()
  if test_inputp(2) and msc > 1 then
    msc -= 1
    _log("mode_cursor:"..msc)
  end
  if test_inputp(3) and msc < 3 then
    msc += 1
    _log("mode_cursor:"..msc)
  end
  if test_inputp(4) then
    gm = ({"normal","boss_rush","time_attack"})[msc]
    _log("gm:"..gm)
    sfx(0)
    ids()
  end
end

function dms()
  print("select mode", 28, 20, 11)
  local y = 40
  local names = {"normal","boss rush","time attack"}
  local descs = {"classic waves","boss gauntlet","survive 60s"}
  for i=1,3 do
    if i == msc then print(">", 20, y, 7) end
    print(names[i], 30, y, i == 1 and 10 or (i == 2 and 8 or 12))
    print(descs[i], 8, y+8, 6)
    y += 26
  end
  print("up/down: select", 24, 108, 6)
  print("o: confirm", 32, 116, 6)
end

function ids()
  state = "difficulty_select"
  _log("state:difficulty_select")
  music(-1) -- fade music
end

function uds()
  local input = test_input()

  -- cursor navigation
  if test_inputp(2) and dfc > 1 then -- up
    dfc -= 1
    _log("diff_cursor:"..dfc)
  end
  if test_inputp(3) and dfc < 3 then -- down
    dfc += 1
    _log("diff_cursor:"..dfc)
  end

  -- confirm selection
  if test_inputp(4) then
    df = ({"easy","normal","hard"})[dfc]
    dset(9, dfc) -- save last df
    _log("df:"..df)
    sfx(0) -- transition sound
    init_play()
  end
end

function dds()

  print("select df", 24, 20, 11)

  -- df options
  local y = 45
  for i=1,3 do
    local diff_name = ({"easy","normal","hard"})[i]
    local col = i == 1 and 12 or (i == 3 and 8 or 10)

    -- cursor
    if i == dfc then
      print(">", 20, y, 7)
    end

    -- df name
    print(diff_name, 30, y, col)


    if i == 1 then -- easy
      print("fewer es, slower", 8, y+8, 6)
      print("spawn rate", 8, y+14, 6)
    elseif i == 2 then -- normal
      print("standard progression", 8, y+8, 6)
    else -- hard
      print("more es, faster", 8, y+8, 6)
      print("spawn, aggressive bosses", 8, y+14, 6)
    end

    y += 30
  end

  -- controls
  print("up/down: select", 24, 108, 6)
  print("o: confirm", 32, 116, 6)
end

function ulv()
  if test_inputp(5) then
    inm()
  end
end

function dlv()
  print("leaderboards", 28, 4, 11)

  -- normal mode leaderboards
  print("normal", 10, 14, 10)
  print("easy", 6, 20, 12)
  for i=1,3 do
    local s = lbs.easy[i]
    if s > 0 then
      print(i.."."..s, 8, 20 + i*6, 7)
    end
  end

  print("norm", 44, 20, 10)
  for i=1,3 do
    local s = lbs.normal[i]
    if s > 0 then
      print(i.."."..s, 46, 20 + i*6, 7)
    end
  end

  print("hard", 82, 20, 8)
  for i=1,3 do
    local s = lbs.hard[i]
    if s > 0 then
      print(i.."."..s, 84, 20 + i*6, 7)
    end
  end

  -- boss rush
  print("boss rush", 36, 50, 8)
  for i=1,3 do
    local s = lbs.boss_rush[i]
    if s > 0 then
      print(i.."."..s, 48, 56 + i*6, 7)
    end
  end

  -- lifetime stats
  print("lifetime stats", 26, 80, 11)
  print("kills: "..ekl_tot, 32, 88, 7)
  print("bosses: "..bks, 28, 94, 7)
  print("games: "..gp_cnt, 30, 100, 7)
  print("best combo: "..bco, 20, 106, 12)

  print("x: back", 44, 118, 6)
end

function init_play()
  state = "play"
  _log("state:play")

  score = 0
  wave = 0
  combo = 0
  ekl = 0
  st = time()
  bd = 0

  -- reset achievement tracking
  bcs = 0
  lms = 0
  mts = {}
  flt = 0
  sas = {}
  pcs = {}
  qkf = false

  -- increment games played
  gp_cnt += 1
  dset(20, gp_cnt)
  nr = false
  _log("games_played:"..gp_cnt)

  -- reset collections
  es = {}
  ps = {}
  pups = {}
  pts = {}
  sqe = {}

  -- reset power-ups
  rft = 0
  bst = 0
  smt = 0
  tas = 0  -- time attack spawn timer


  p = {
    x = 64,
    y = 64,
    rot = 0, -- 0-7
    lives = 3,
    dash_cd = 0,
    invuln = 0,
    shoot_cd = 0,
    has_shield = false,
    flash = 0,
    flash_red = 0
  }

  music(1) -- gameplay theme
  _log("music:gameplay")
  spw()
end

function upp()

  if test_inputp(5) then
    inp()
    return
  end

  local input = test_input()


  tsv = flr(time() - st)

  if gm == "time_attack" then
    if tsv >= 60 then igo() return end
    if (tas -= 1) <= 0 then
      tas = df == "easy" and 90 or (df == "hard" and 45 or 60)
      for i=1,flr(rnd(2))+2 do
        queue_spawn(tsv>30 and rnd(100)<20 and "speedy" or (tsv>20 and rnd(100)<30 and "shooter" or "minion"))
      end
    end
  end


  if shf > 0 then
    shf -= 1
  else
    -- add baseline screen shake that scales with wave
    shi = bsh()
  end


  if rft > 0 then rft -= 1 end
  if bst > 0 then bst -= 1 end
  if smt > 0 then smt -= 1 end


  update_spawn_queue()

  -- p input
  if p.invuln > 0 then
    p.invuln -= 1
  end

  if p.dash_cd > 0 then
    p.dash_cd -= 1
  end

  if p.shoot_cd > 0 then
    p.shoot_cd -= 1
  end

  -- rotation
  if input & 1 > 0 then -- left
    p.rot = (p.rot - 1) % 8
    _log("rot:"..p.rot)
  end
  if input & 2 > 0 then -- right
    p.rot = (p.rot + 1) % 8
    _log("rot:"..p.rot)
  end

  -- shoot
  if input & 16 > 0 and p.shoot_cd == 0 then
    local fire_rate = rft > 0 and 4 or 8
    p.shoot_cd = fire_rate
    shp()
  end

  -- dash
  if input & 32 > 0 and p.dash_cd == 0 then
    p.dash_cd = 60 -- 1 second cooldown
    p.invuln = 10 -- brief invuln
    dap()
  end


  for e in all(es) do
    upe(e)
  end


  for p in all(ps) do
    upr(p)
  end


  for pu in all(pups) do
    pu.y += 0.3
    if dist(p.x, p.y, pu.x, pu.y) < 6 then
      cpu(pu)
      del(pups, pu)
    end
    if pu.y > 140 then
      del(pups, pu)
    end
  end


  for pt in all(pts) do
    pt.x += pt.vx
    pt.y += pt.vy
    pt.life -= 1
    if pt.life <= 0 then
      del(pts, pt)
    end
  end


  if flt > 0 then
    flt -= 1
  end

  for mt in all(mts) do
    mt.y -= 0.5
    mt.life -= 1
    if mt.life <= 0 then
      del(mts, mt)
    end
  end


  if #es == 0 and ekl > 0 and gm != "time_attack" then
    asc(100)
    _log("wave_complete:"..wave)
    shf = 2
    shi = 1
    spw()
  end


  cka()


  if p.lives <= 0 then
    igo()
  end
end

function shp()
  _log("shoot")
  sfx(0)

  local dir = dirs[p.rot + 1]
  local size = bst > 0 and 2 or 1

  add(ps, {
    x = p.x + dir[1] * 8,
    y = p.y + dir[2] * 8,
    vx = dir[1] * 3,
    vy = dir[2] * 3,
    owner = "p",
    size = size,
    dmg = bst > 0 and 2 or 1,
    col = 10 -- p ps are yellow
  })
end

function dap()
  _log("dash")
  sfx(3)

  local dir = dirs[p.rot + 1]
  p.x += dir[1] * 15
  p.y += dir[2] * 15


  p.x = mid(8, p.x, 120)
  p.y = mid(8, p.y, 120)


  for e in all(es) do
    if dist(p.x, p.y, e.x, e.y) < 12 then
      dme(e, 1)
    end
  end
end

function upe(e)
  -- apply knockback velocity
  e.x += e.vx
  e.y += e.vy

  -- dampen velocity over time
  e.vx *= 0.85
  e.vy *= 0.85


  e.x = mid(4, e.x, 124)
  e.y = mid(4, e.y, 124)


  if e.type == "heavy" then
    uba(e)
  elseif e.type == "seeker" then
    update_seeker_attacks(e)
  elseif e.type == "summoner" then
    update_summoner_attacks(e)
  end


  if e.dashing then
    e.dash_timer -= 1
    if e.dash_timer <= 0 then
      e.dashing = false
      e.speed = 0.3 -- restore normal speed
      _log("boss_dash_end")
    else
      -- continue dash movement
      local dx = e.dash_target_x - e.x
      local dy = e.dash_target_y - e.y
      local d = sqrt(dx*dx + dy*dy)
      if d > 0 then
        e.x += (dx / d) * e.speed
        e.y += (dy / d) * e.speed
      end
    end
  else
    -- normal movement toward p
    local dx = p.x - e.x
    local dy = p.y - e.y
    local d = sqrt(dx*dx + dy*dy)

    if d > 0 then
      local speed = e.speed or 0.5
      e.x += (dx / d) * speed
      e.y += (dy / d) * speed
    end
  end

  -- shooter behavior
  if e.type == "shooter" then
    e.shoot_timer = (e.shoot_timer or 0) + 1
    local cooldown = (e.attack_pattern == "burst") and 40 or 90
    local spread_cooldown = (e.attack_pattern == "spread") and 60 or cooldown
    local final_cooldown = (e.attack_pattern == "spread") and spread_cooldown or cooldown

    if e.shoot_timer >= final_cooldown then
      e.shoot_timer = 0
      enemy_shoot(e)
      -- for burst, schedule second shot
      if e.attack_pattern == "burst" then
        e.burst_pending = true
      end
    end


    if e.burst_pending and e.shoot_timer == 5 then
      enemy_shoot(e)
      e.burst_pending = false
    end
  end

  -- collision with p
  if p.invuln == 0 and dist(p.x, p.y, e.x, e.y) < 6 then
    -- extra damage during dash
    -- df scaling: hard mode increases dash damage
    local dmg = 1
    if e.dashing and (e.type == "heavy" or e.type == "seeker" or e.type == "summoner") then
      if df == "hard" then
        dmg = e.phase2 and 4 or 3  -- hard: 3x (phase1), 4x (phase2/3)
      else
        dmg = e.phase2 and 3 or 2  -- easy/normal: 2x (phase1), 3x (phase2/3)
      end
      _log("dash_dmg:"..dmg)
    end
    hit_player(dmg)
    if not e.dashing then
      del(es, e)
    end
  end
end

function enemy_shoot(e)
  local dx = p.x - e.x
  local dy = p.y - e.y
  local d = sqrt(dx*dx + dy*dy)

  if d == 0 then return end

  local pattern = e.attack_pattern or "single"

  if pattern == "single" then

    add(ps, {
      x = e.x,
      y = e.y,
      vx = (dx / d) * 1.5,
      vy = (dy / d) * 1.5,
      owner = "enemy",
      size = 1,
      dmg = 1,
      col = 9
    })
    _log("shoot:single")
  elseif pattern == "spread" then
    -- 3 ps in spread pattern (yellow)

    local base_angle = atan2(dy, dx)
    for i = -1, 1 do
      local angle = base_angle + (i * 0.06) -- ~22 degrees spread
      add(ps, {
        x = e.x,
        y = e.y,
        vx = cos(angle) * 1.5,
        vy = sin(angle) * 1.5,
        owner = "enemy",
        size = 1,
        dmg = 1,
        col = 10
      })
    end
    _log("shoot:spread")
  elseif pattern == "aimed" then

    add(ps, {
      x = e.x,
      y = e.y,
      vx = (dx / d) * 1.2,
      vy = (dy / d) * 1.2,
      owner = "enemy",
      size = 1,
      dmg = 1,
      col = 12
    })
    _log("shoot:aimed")
  elseif pattern == "burst" then

    add(ps, {
      x = e.x,
      y = e.y,
      vx = (dx / d) * 1.5,
      vy = (dy / d) * 1.5,
      owner = "enemy",
      size = 1,
      dmg = 1,
      col = 7
    })
    _log("shoot:burst")
  end
end

function spm(x, y)

  local offset_x = rnd(30) - 15
  local offset_y = rnd(30) - 15
  spe("minion", x + offset_x, y + offset_y)
  _log("spawn:minion")
end

function uba(e)

  if not e.spawn_time then
    e.spawn_time = time()
    e.burst_cd = 0
    e.dash_cd = 0
    e.burst_used = false
  end


  if e.burst_cd > 0 then e.burst_cd -= 1 end
  if e.dash_cd > 0 then e.dash_cd -= 1 end
  if e.flt and e.flt > 0 then e.flt -= 1 end
  if e.spin_timer and e.spin_timer > 0 then
    e.spin_timer -= 1
    if e.spin_timer == 0 then _log("spin_end") end
  end
  if e.spawn_flash and e.spawn_flash > 0 then e.spawn_flash -= 1 end

  if e.glow_t then
    local glow_speed = e.phase3 and 2 or 1
    e.glow_t = (e.glow_t + glow_speed) % 12
  end
  if e.spawn_timer and e.spawn_timer > 0 then e.spawn_timer -= 1 end


  if e.pulse_timer and e.pulse_timer > 0 then
    e.pulse_timer -= 1
    e.pulse_radius = (20 - e.pulse_timer) * 0.7
  end


  if e.dash_warn and e.dash_warn > 0 then
    e.dash_warn -= 1

    if e.dash_warn % 8 == 0 then
      sfx(12)
      _log("sfx:dash_warn_tick")
    end
    if e.dash_warn == 0 then

      _log("boss_dash")
      sfx(3)
      e.dashing = true
      e.dash_timer = 60
      e.speed = 0.6
    end
  end


  if e.aim_warn and e.aim_warn > 0 then
    e.aim_warn -= 1

  end

  local elapsed = time() - e.spawn_time
  local hp_pct = e.hp / e.max_hp


  -- df-based cooldowns: easy (slower), normal (baseline), hard (faster)
  local burst_base = df == "easy" and 180 or (df == "hard" and 90 or 120)
  local dash_base = df == "easy" and 270 or (df == "hard" and 135 or 180)


  local burst_cooldown = e.phase3 and flr(burst_base / 3) or (e.phase2 and flr(burst_base * 0.6) or burst_base)
  local dash_cooldown = e.phase3 and flr(dash_base / 3) or (e.phase2 and flr(dash_base * 0.53) or dash_base)


  if (not e.burst_used and (hp_pct <= 0.5 or elapsed >= 5) and e.burst_cd == 0) or (e.phase2 and e.burst_cd == 0) then
    bba(e)
    e.burst_used = true
    e.burst_cd = burst_cooldown
  end

  -- dash attack (when p in range)
  local d = dist(p.x, p.y, e.x, e.y)
  if not e.dashing and not e.dash_warn and d < 60 and d > 10 and e.dash_cd == 0 then
    bda(e, dash_cooldown)
  end
end

function bba(e)
  -- randomly select attack pattern based on phase
  local patterns
  if e.phase2 then
    patterns = {"burst", "spiral", "ring", "aimed"}
  else

    patterns = {"burst", "ring"}
  end

  local pattern = patterns[flr(rnd(#patterns)) + 1]

  if pattern == "burst" then
    boss_burst_pattern(e)
  elseif pattern == "spiral" then
    boss_spiral_pattern(e)
  elseif pattern == "ring" then
    boss_ring_attack(e)
  elseif pattern == "aimed" then
    boss_aimed_burst_attack(e)
  end
end

function boss_burst_pattern(e)
  _log("boss_burst")
  _log("spin_start:30")
  sfx(6)
  _log("sfx:burst")
  e.flt = 10
  e.spin_timer = 30

  -- df-based bullet count: 6-way (easy), 8-way (normal), 12-way (hard)
  local bullet_count = df == "easy" and 6 or (df == "hard" and 12 or 8)
  _log("burst_bullets:"..bullet_count)

  for i=0,bullet_count-1 do
    local angle = i / bullet_count
    local vx = cos(angle) * e.speed * 3
    local vy = sin(angle) * e.speed * 3
    add(ps, {
      x = e.x,
      y = e.y,
      vx = vx,
      vy = vy,
      owner = "enemy",
      size = 1,
      dmg = 1,
      col = 8
    })
  end
end

function boss_spiral_pattern(e)
  _log("boss_spiral")
  _log("spin_start:30")
  sfx(6, -1, 4)  -- pitch variation for spiral
  _log("sfx:spiral")
  e.flt = 10
  e.spin_timer = 30
  shf = 2
  shi = 1.5  -- medium shake

  -- df scaling: easy (-4), normal (baseline), hard (+4)
  local diff_mod = df == "easy" and -4 or (df == "hard" and 4 or 0)

  local proj_count = (e.phase3 and 16 or 14) + diff_mod
  _log("spiral_bullets:"..proj_count)

  for i=0,proj_count-1 do
    local angle = i / proj_count
    local vx = cos(angle) * e.speed * 3
    local vy = sin(angle) * e.speed * 3
    add(ps, {
      x = e.x,
      y = e.y,
      vx = vx,
      vy = vy,
      owner = "enemy",
      size = 1,
      dmg = 1,
      col = 9 -- for spiral
    })
  end
end

function boss_ring_attack(e)
  _log("boss_ring")
  _log("spin_start:30")
  sfx(6, -1, 8)
  _log("sfx:ring")
  e.flt = 10
  e.spin_timer = 30
  shf = 3
  shi = 2.0  -- strongest shake

  -- df scaling: easy (-3), normal (baseline), hard (+3)
  local diff_mod = df == "easy" and -3 or (df == "hard" and 3 or 0)

  local proj_count = (e.phase3 and 14 or (e.phase2 and 12 or 10)) + diff_mod
  _log("ring_bullets:"..proj_count)

  for i=0,proj_count-1 do
    local angle = i / proj_count
    local vx = cos(angle) * e.speed * 3
    local vy = sin(angle) * e.speed * 3
    add(ps, {
      x = e.x,
      y = e.y,
      vx = vx,
      vy = vy,
      owner = "enemy",
      size = 1,
      dmg = 1,
      col = 12 -- for ring
    })
  end
end

function boss_aimed_burst_attack(e)
  _log("boss_aimed")
  sfx(9)
  _log("sfx:aimed_warn")
  e.flt = 15  -- longer warning flash
  e.aim_warn = 20  -- targeting indicator frames
  e.aim_target_x = p.x
  e.aim_target_y = p.y
  shf = 1
  shi = 1.0  -- light shake


  local dx = p.x - e.x
  local dy = p.y - e.y
  local base_angle = atan2(dy, dx)

  -- fire 5 ps: at p + 4 offset angles
  -- offsets: 0°, ±45°, ±90° in turns (1 turn = 360°)
  local offsets = {0, -0.125, 0.125, -0.25, 0.25}
  for i=1,5 do
    local angle = base_angle + offsets[i]
    local vx = cos(angle) * e.speed * 3
    local vy = sin(angle) * e.speed * 3
    add(ps, {
      x = e.x,
      y = e.y,
      vx = vx,
      vy = vy,
      owner = "enemy",
      size = 1,
      dmg = 1,
      col = 10 -- for aimed
    })
  end
end

function bda(e, cooldown)
  _log("boss_dash_warn")
  sfx(9) -- dash warning sound
  _log("sfx:dash_warn")

  e.dash_cd = cooldown or 180
  -- df scaling: easy mode gets extra warning time
  e.dash_warn = df == "easy" and 40 or 30
  _log("dash_warn_frames:"..e.dash_warn)
  e.dash_target_x = p.x
  e.dash_target_y = p.y
end

function update_seeker_attacks(e)
  if not e.spawn_time then
    e.spawn_time=time() e.charge_cd=0 e.minion_cd=0 e.charging=false e.charge_timer=0
  end
  if e.charge_cd>0 then e.charge_cd-=1 end
  if e.minion_cd>0 then e.minion_cd-=1 end
  update_boss_timers(e)

  if e.charging then
    e.charge_timer-=1
    if e.charge_timer<=0 then
      e.charging=false e.charge_cd=60 _log("seeker_pause")
    else
      local dx,dy=p.x-e.x,p.y-e.y
      local d=sqrt(dx*dx+dy*dy)
      if d>0 then
        local s=e.phase3 and 3 or(e.phase2 and 2.5 or 2)
        e.vx,e.vy=(dx/d)*s,(dy/d)*s
      end
    end
  elseif e.charge_cd==0 then
    e.charging=true e.charge_timer=90 sfx(10) _log("seeker_charge")
  end

  if e.phase2 and e.minion_cd==0 then
    local c=e.phase3 and 3 or 2
    for i=1,c do spm(e.x,e.y) end
    e.minion_cd=e.phase3 and 120 or 180
    sfx(11) _log("seeker_spawn_minions:"..c)
  end
end

function update_summoner_attacks(e)
  if not e.spawn_time then
    e.spawn_time=time() e.burst_cd=0 e.minion_cd=150
  end
  if e.burst_cd>0 then e.burst_cd-=1 end
  if e.minion_cd>0 then e.minion_cd-=1 end
  update_boss_timers(e)

  if e.burst_cd==0 then
    _log("summoner_burst") sfx(6) e.flt=5
    for i=0,7 do
      local a=i/8
      add(ps,{x=e.x,y=e.y,vx=cos(a)*1.5,vy=sin(a)*1.5,owner="enemy",size=1,dmg=1,col=14})
    end
    e.burst_cd=e.phase3 and 30 or(e.phase2 and 45 or 60)
  end

  if e.minion_cd==0 then
    local c=e.phase3 and 3 or(e.phase2 and 2 or 1)
    for i=1,c do spm(e.x,e.y) end
    e.minion_cd=e.phase3 and 90 or(e.phase2 and 120 or 150)
    sfx(11) _log("summoner_spawn_minions:"..c)
  end
end

function update_boss_timers(e)
  if e.flt and e.flt>0 then e.flt-=1 end
  if e.spawn_flash and e.spawn_flash>0 then e.spawn_flash-=1 end
  if e.glow_t then e.glow_t=(e.glow_t+(e.phase3 and 2 or 1))%12 end
  if e.spawn_timer and e.spawn_timer>0 then e.spawn_timer-=1 end
  if e.pulse_timer and e.pulse_timer>0 then
    e.pulse_timer-=1 e.pulse_radius=(20-e.pulse_timer)*0.7
  end
end

function upr(p)
  -- seeking projectile behavior
  if p.seeking then
    local dx = p.x - p.x
    local dy = p.y - p.y
    local d = sqrt(dx*dx + dy*dy)
    if d > 0 then
      -- gradually turn toward p
      local target_vx = (dx / d) * 1.2
      local target_vy = (dy / d) * 1.2
      p.vx = p.vx + (target_vx - p.vx) * p.turn_rate
      p.vy = p.vy + (target_vy - p.vy) * p.turn_rate
    end
  end

  p.x += p.vx
  p.y += p.vy

  -- bounds check
  if p.x < 0 or p.x > 128 or p.y < 0 or p.y > 128 then
    del(ps, p)
    return
  end

  if p.owner == "p" then

    for e in all(es) do
      if dist(p.x, p.y, e.x, e.y) < 5 then
        dme(e, p.dmg, p)
        del(ps, p)
        break
      end
    end
  elseif p.owner == "enemy" then

    if p.invuln == 0 and dist(p.x, p.y, p.x, p.y) < 5 then
      hit_player()
      del(ps, p)
    end
  end
end

function dme(e, dmg, proj)
  e.hp -= dmg
  sfx(1)

  -- apply knockback if hit by projectile
  if proj then
    local dx = e.x - proj.x
    local dy = e.y - proj.y
    local d = sqrt(dx*dx + dy*dy)

    if d > 0 then
      local force = 2.5


      if e.type == "heavy" or e.type == "seeker" or e.type == "summoner" then
        force = force / 3
        _log("knockback:boss:"..e.type)
      else
        _log("knockback:"..e.type)
      end

      e.vx = (dx / d) * force
      e.vy = (dy / d) * force
    end
  end


  if (e.type == "heavy" or e.type == "seeker" or e.type == "summoner") and not e.phase2 and e.hp <= 2 then
    e.phase2 = true
    _log("boss:phase2:"..e.type)

    e.flt = 15
    shf = 2
    shi = 1
    sfx(6)
  end


  if (e.type == "heavy" or e.type == "seeker" or e.type == "summoner") and not e.phase3 and e.hp <= 1 then
    e.phase3 = true
    _log("boss:phase3:"..e.type)
    -- dramatic phase 3 entrance
    e.flt = 20
    shf = 2
    shi = 2.0
    sfx(11)  -- distinct sound for phase 3
  end

  if e.hp <= 0 then
    kill_enemy(e)
  end
end

function kill_enemy(e)
  _log("enemy_kill:"..e.type)


  if e.type == "heavy" then
    sfx(10)
    _log("sfx:boss_death:heavy")

    -- track quick kill (killed before phase 2)
    if not e.phase2 then
      qkf = true
      _log("quick_kill")
    end
  elseif e.type == "seeker" then
    sfx(11)
    _log("sfx:boss_death:seeker")

    -- track quick kill (killed before phase 2)
    if not e.phase2 then
      qkf = true
      _log("quick_kill")
    end
  elseif e.type == "summoner" then
    sfx(10)  -- different pitch for summoner death
    _log("sfx:boss_death:summoner")

    -- track quick kill (killed before phase 2)
    if not e.phase2 then
      qkf = true
      _log("quick_kill")
    end
  else
    sfx(2)
  end

  -- score
  local base_score = e.score or 10
  local mult = get_score_multiplier()
  asc(flr(base_score * mult) + combo)

  combo += 1
  ekl += 1
  _log("combo:"..combo)


  local is_milestone = (combo == 10 or combo == 20 or combo == 30 or
                        (combo >= 50 and combo % 25 == 0)) and combo > lms

  if is_milestone then
    lms = combo
    _log("combo_milestone:"..combo)

    -- determine tier-based effects (gold/cyan colors per spec)
    local tier_col, tier_particles, tier_shake, tier_sfx_offset = 10, 8, 3, 0
    if combo >= 100 then
      tier_col, tier_particles, tier_shake, tier_sfx_offset = 7, 12, 4, 16
    elseif combo >= 50 then
      tier_col, tier_particles, tier_shake, tier_sfx_offset = 12, 10, 4, 12
    elseif combo >= 30 then
      tier_col, tier_particles, tier_shake, tier_sfx_offset = 9, 10, 3, 8
    elseif combo >= 20 then
      tier_col, tier_particles, tier_shake, tier_sfx_offset = 10, 8, 3, 4
    end


    flt = 3


    shf = tier_shake
    shi = tier_shake * 0.5


    add(mts, {
      text = "combo x"..combo.."!",
      y = 40,
      life = 60,
      initial_life = 60,
      col = tier_col
    })

    -- radial particle burst (8-12 pts with gold/cyan, scaled by wave)
    local scaled_particles = flr(tier_particles * pdf())
    for i=1,scaled_particles do
      local angle = i / scaled_particles
      add(pts, {
        x = 64,
        y = 64,
        vx = cos(angle) * 3,
        vy = sin(angle) * 3,
        life = 30,
        col = tier_col
      })
    end

    -- distinct fanfare sfx for each tier
    sfx(6, -1, tier_sfx_offset)
  end


  if e.type == "heavy" or e.type == "seeker" or e.type == "summoner" then
    bks += 1
    _log("boss_kill:"..e.type..":"..bks)

    -- track boss rush progress
    if gm == "boss_rush" then
      bd += 1
      _log("boss_rush_defeated:"..bd)
    end

    shf = 4
    shi = 5
    flt = 12  -- extended flash for boss victory

    local txt=e.type=="seeker" and "seeker down!" or(e.type=="summoner" and "summoner down!" or "boss down!")
    local tcol=e.type=="seeker" and 12 or(e.type=="summoner" and 14 or 10)
    add(mts,{text=txt,y=50,life=45,initial_life=45,col=tcol})
    _log("boss_fanfare:"..e.type)
    -- enhanced spiral particle burst (color matches boss type)
    local particle_col = e.type == "seeker" and 12 or (e.type == "summoner" and 14 or 8)
    local boss_particles = flr(18 * pdf())
    for i=1,boss_particles do
      local angle = i / boss_particles
      add(pts, {
        x = e.x,
        y = e.y,
        vx = cos(angle) * 2.5,  -- travel further
        vy = sin(angle) * 2.5,
        life = 32,  -- slower (live longer)
        col = particle_col + flr(rnd(2))
      })
    end
  else
    -- normal explosion pts (scaled by wave)
    local explosion_particles = flr(15 * pdf())
    for i=1,explosion_particles do
      add(pts, {
        x = e.x,
        y = e.y,
        vx = rnd(3) - 1.5,
        vy = rnd(3) - 1.5,
        life = 20,
        col = 8 + flr(rnd(4))
      })
    end
  end

  -- powerup chance (1/20)
  if rnd(20) < 1 then
    spawn_powerup(e.x, e.y)
  end

  del(es, e)
end

function hit_player(dmg)
  dmg = dmg or 1

  if p.has_shield then
    p.has_shield = false
    p.flash = 4  -- flash effect
    sft = 8  -- trigger flash animation
    shf = 6
    shi = 1.5  -- moderate shake
    sfx(5)
    _log("shield_block")

    -- shield block particle burst (scaled by wave)
    local shield_particles = flr(10 * pdf())
    for i=1,shield_particles do
      local angle = i / shield_particles
      add(pts, {
        x = p.x,
        y = p.y,
        vx = cos(angle) * 1.5,
        vy = sin(angle) * 1.5,
        life = 10,
        col = 10  -- bright cyan
      })
    end
    return
  end

  p.lives -= dmg
  p.invuln = 60


  if combo > 0 then
    p.flash_red = 6  -- red flash effect
    sfx(18)  -- low-pitched buzz/error sound
    _log("combo_reset_feedback")


    add(mts, {
      text = "combo lost!",
      y = p.y - 10,
      life = 45,
      initial_life = 45,
      col = 8  -- red
    })

    -- red particle burst
    for i=1,14 do
      local angle = i / 14
      add(pts, {
        x = p.x,
        y = p.y,
        vx = cos(angle) * 1.2,
        vy = sin(angle) * 1.2,
        life = 15,
        col = 8  -- red
      })
    end
  end

  combo = 0
  sfx(7)
  _log("hit:lives="..p.lives..",dmg="..dmg)
  _log("combo_reset")


  shf = 3 + dmg
  shi = 2 + dmg * 0.5

  -- pts
  for i=1,10 do
    add(pts, {
      x = p.x,
      y = p.y,
      vx = rnd(3) - 1.5,
      vy = rnd(3) - 1.5,
      life = 20,
      col = 8
    })
  end
end

function queue_spawn(typ, delay)

  local base_delay = delay or (60 + flr(rnd(30)))
  local spawn_delay = flr(base_delay * sdf())


  local x, y = 0, 0
  local side = flr(rnd(4))

  if side == 0 then -- top
    x = rnd(128)
    y = 0
  elseif side == 1 then -- right
    x = 128
    y = rnd(128)
  elseif side == 2 then -- bottom
    x = rnd(128)
    y = 128
  else -- left
    x = 0
    y = rnd(128)
  end

  add(sqe, {
    type = typ,
    x = x,
    y = y,
    timer = spawn_delay,
    sfx_played = false
  })

  _log("queue_spawn:"..typ..":"..x..","..y)
end

function spw()
  wave += 1
  _log("wave:"..wave)

  -- boss rush mode: spawn 1 boss per wave, no minions
  if gm == "boss_rush" then
    local boss_idx = (wave - 1) % 3
    local boss_type = "heavy"
    if boss_idx == 1 then
      boss_type = "seeker"
    elseif boss_idx == 2 then
      boss_type = "summoner"
    end
    queue_spawn(boss_type, 90)
    music(2)
    _log("music:boss")
    _log("boss_rush_boss:"..boss_type)
    return
  end

  -- log intensity scaling milestones
  local boss_interval = df == "easy" and 6 or (df == "hard" and 4 or 5)
  if wave % boss_interval == 0 then
    _log("intensity_mod:"..wim())
    _log("boss_interval:"..boss_interval)
  end
  if wave % 3 == 0 then
    _log("sdf:"..sdf())
  end

  -- df scaling
  local count_mult = df == "easy" and 0.7 or (df == "hard" and 1.3 or 1.0)
  local shooter_wave = df == "easy" and 5 or (df == "hard" and 2 or 3)
  local speedy_wave = df == "easy" and 8 or (df == "hard" and 3 or 5)


  local boss_interval = df == "easy" and 6 or (df == "hard" and 4 or 5)

  local count = flr((3 + wave) * count_mult)
  local boss_wave = wave % boss_interval == 0

  if boss_wave then

    -- cycle index: (wave / 5 - 1) % 3
    local boss_idx = flr(wave / 5 - 1) % 3
    local boss_type = "heavy"  -- default SPINNER

    if boss_idx == 1 then
      boss_type = "seeker"  -- SEEKER
    elseif boss_idx == 2 then
      boss_type = "summoner"  -- SUMMONER
    end

    queue_spawn(boss_type, 90) -- longer telegraph for boss
    count = flr(4 * count_mult)
    music(2)
    _log("music:boss")
    _log("boss_type:"..boss_type)
  else
    music(1) -- gameplay theme
    _log("music:gameplay")
  end

  for i=1,count do
    local enemy_type = "minion"

    if wave >= shooter_wave and rnd(100) < 30 then
      enemy_type = "shooter"
    elseif wave >= speedy_wave and rnd(100) < 20 then
      enemy_type = "speedy"
    end

    queue_spawn(enemy_type)
  end
end

function spe(typ, spawn_x, spawn_y)
  -- use provided position or generate random edge position
  local x, y = spawn_x, spawn_y

  if not x or not y then
    local side = flr(rnd(4))
    if side == 0 then -- top
      x = rnd(128)
      y = 0
    elseif side == 1 then -- right
      x = 128
      y = rnd(128)
    elseif side == 2 then -- bottom
      x = rnd(128)
      y = 128
    else -- left
      x = 0
      y = rnd(128)
    end
  end

  -- apply wave intensity scaling to base speed
  local base_speed = 0.5 * wim()

  local e = {
    type = typ,
    x = x,
    y = y,
    hp = 1,
    max_hp = 1,
    speed = base_speed,
    score = 10,
    col = 8,
    vx = 0,
    vy = 0
  }

  if typ == "shooter" then
    e.score = 20
    e.col = 9
    e.shoot_timer = 0
    -- assign attack pattern: 40% single, 30% spread, 15% aimed, 15% burst
    local r = rnd(100)
    if r < 40 then
      e.attack_pattern = "single"
    elseif r < 70 then
      e.attack_pattern = "spread"
    elseif r < 85 then
      e.attack_pattern = "aimed"
    else
      e.attack_pattern = "burst"
      e.burst_pending = false -- track second shot in burst
    end
    _log("spawn:shooter:"..e.attack_pattern)
  elseif typ == "speedy" then
    e.hp = 2
    e.max_hp = 2
    e.speed = 1.2 * wim()
    e.score = 25
    e.col = 10
  elseif typ == "heavy" then

    local boss_hp = df == "easy" and 2 or (df == "hard" and 4 or 3)
    e.hp = boss_hp
    e.max_hp = boss_hp
    e.speed = 0.3 * wim()
    e.score = 50
    e.col = 8
    e.glow_t = 0 -- pulsing glow timer
    e.spawn_flash = 3
    e.pulse_radius = 0 -- expanding pulse effect
    e.pulse_timer = 20 -- frames for pulse expansion
    e.spawn_timer = 60 -- entrance glow + scale animation
    e.phase2 = false
    e.phase3 = false
  elseif typ == "seeker" then
    -- seeker boss: aggressive charging + minion spawning
    e.hp = 4
    e.max_hp = 4
    e.speed = 0.4 * wim()
    e.score = 60
    e.col = 12/light blue
    e.glow_t = 0
    e.spawn_flash = 3
    e.pulse_radius = 0
    e.pulse_timer = 20
    e.spawn_timer = 60
    e.charge_cd = 0 -- charge attack cooldown
    e.charging = false -- is currently charging
    e.charge_timer = 0 -- charge duration
    e.minion_cd = 0 -- minion spawn cooldown
    e.phase2 = false
    e.phase3 = false
  elseif typ == "summoner" then
    -- summoner boss: ranged bombardment + minion army
    e.hp = 3
    e.max_hp = 3
    e.speed = 0.3 * wim()
    e.score = 60
    e.col = 14 -- magenta/pink
    e.glow_t = 0
    e.spawn_flash = 3
    e.pulse_radius = 0
    e.pulse_timer = 20
    e.spawn_timer = 60
    e.burst_cd = 0 -- projectile burst cooldown
    e.minion_cd = 0 -- minion spawn cooldown
    e.phase2 = false
    e.phase3 = false
  end

  -- boss rush scaling
  if gm == "boss_rush" and (typ == "heavy" or typ == "seeker" or typ == "summoner") then
    local hp_mult = 1.0
    if wave >= 5 then
      hp_mult = 1.5
      e.phase2 = true
      e.phase3 = true
      _log("boss_rush:enrage:wave"..wave)
    elseif wave >= 3 then
      hp_mult = 1.25
    end
    e.hp = flr(e.hp * hp_mult)
    e.max_hp = e.hp
    _log("boss_rush_scale:wave"..wave..":hp"..e.hp)
  end

  add(es, e)
  _log("spawn:"..typ)


  if typ == "heavy" or typ == "seeker" or typ == "summoner" then
    sfx(6)
    _log("sfx:boss_alert:"..typ)
    shf = 3
    shi = 1
    flt = 15

    local pc=typ=="seeker" and 12 or(typ=="summoner" and 14 or 8)
    for i=1,10 do
      local a=i/10
      add(pts,{x=e.x,y=e.y,vx=cos(a)*1.5,vy=sin(a)*1.5,life=20,col=pc+flr(rnd(2))})
    end

    local nm=typ=="seeker" and "seeker!" or(typ=="summoner" and "summoner!" or "boss wave!")
    local bc=typ=="seeker" and 12 or(typ=="summoner" and 14 or 7)
    add(mts,{text=nm,y=32,life=60,initial_life=60,col=bc})
    _log("boss_announce:"..typ)
  end
end

function update_spawn_queue()
  for sq in all(sqe) do
    sq.timer -= 1

    -- play telegraph SFX at 60 frames (1 second before spawn)
    if not sq.sfx_played and sq.timer <= 60 then
      sfx(8)
      sq.sfx_played = true
      _log("telegraph_sfx:"..sq.type)
    end


    if sq.timer <= 0 then
      spe(sq.type, sq.x, sq.y)
      del(sqe, sq)
    end
  end
end

function spawn_powerup(x, y)
  local types = {"RR", "BS", "SH", "2X"}
  local typ = types[flr(rnd(4)) + 1]

  add(pups, {
    type = typ,
    x = x,
    y = y
  })

  _log("powerup_spawn:"..typ)
end

function cpu(pu)
  _log("powerup_collect:"..pu.type)
  sfx(4)

  -- track for arsenal master achievement
  pcs[pu.type] = true

  if pu.type == "RR" then
    rft = 180 -- 3 seconds
  elseif pu.type == "BS" then
    bst = 300 -- 5 seconds
  elseif pu.type == "SH" then
    p.has_shield = true
  elseif pu.type == "2X" then
    smt = 600 -- 10 seconds
  end
end

function get_score_multiplier()
  local base = 1.0

  -- time multiplier (0.5x per 30s, max 2.0x at 120s)
  base += min(flr(tsv / 30) * 0.5, 1.0)


  if smt > 0 then
    base *= 2
  end

  return base
end

function asc(pts)
  score += pts
  _log("score:"..score)
  if score > hsc then
    hsc = score
    -- save to df-specific slot
    local diff_slot = 5 + dfc -- 6=easy, 7=normal, 8=hard
    dset(diff_slot, hsc)
    -- also save to overall high score (slot 0)
    local overall = dget(0) or 0
    if hsc > overall then
      dset(0, hsc)
    end
    _log("new_high_score:"..hsc.."("..df..")")
  end
end

function dist(x1, y1, x2, y2)
  local dx = x2 - x1
  local dy = y2 - y1
  return sqrt(dx*dx + dy*dy)
end

function draw_edge_indicators()
  -- track nearest enemy per edge for deduplication
  local nearest = {top={}, bottom={}, left={}, right={}}

  for e in all(es) do

    if e.x < 0 or e.x > 128 or e.y < 0 or e.y > 128 then

      local d_top = abs(e.y - 0)
      local d_bottom = abs(e.y - 128)
      local d_left = abs(e.x - 0)
      local d_right = abs(e.x - 128)

      -- find nearest edge
      local min_d = min(d_top, d_bottom, d_left, d_right)
      local edge = ""

      if min_d == d_top then
        edge = "top"
      elseif min_d == d_bottom then
        edge = "bottom"
      elseif min_d == d_left then
        edge = "left"
      else
        edge = "right"
      end

      -- track only nearest enemy per edge+type combo
      local key = e.type
      if not nearest[edge][key] or min_d < nearest[edge][key].dist then
        nearest[edge][key] = {e=e, dist=min_d}
      end
    end
  end


  for edge, types in pairs(nearest) do
    for typ, data in pairs(types) do
      local e = data.e
      local ix, iy = 0, 0

      if edge == "top" then
        ix = mid(8, e.x, 120)
        iy = 2
      elseif edge == "bottom" then
        ix = mid(8, e.x, 120)
        iy = 125
      elseif edge == "left" then
        ix = 2
        iy = mid(8, e.y, 120)
      else -- right
        ix = 125
        iy = mid(8, e.y, 120)
      end

      -- color matches enemy type
      local col = e.col
      if e.type == "heavy" and e.phase3 then
        col = 8 -- bright red for phase 3 heavy boss
      elseif e.type == "heavy" and e.phase2 then
        col = 9 -- for phase 2 heavy boss
      elseif e.type == "seeker" and e.phase3 then
        col = 7 -- bright white for phase 3 seeker
      elseif e.type == "seeker" and e.phase2 then
        col = 12 -- for phase 2 seeker
      elseif e.type == "summoner" and e.phase3 then
        col = 13 -- bright magenta for phase 3 summoner
      elseif e.type == "summoner" and e.phase2 then
        col = 14 -- magenta for phase 2 summoner
      end


      if e.type == "heavy" or e.type == "seeker" or e.type == "summoner" then
        circfill(ix, iy, 2, col)
        circ(ix, iy, 3, 7) outline
        -- small hp bar for boss
        if e.max_hp > 1 then
          local frac = e.hp / e.max_hp
          local w = 6
          rectfill(ix - w/2, iy - 5, ix - w/2 + w * frac, iy - 4, 11)
        end
      else
        -- regular enemy: small triangle pointing inward
        circfill(ix, iy, 1, col)
        pset(ix, iy, 7) center
      end

      _log("indicator:"..edge..":"..e.type)
    end
  end
end

function drp()
  -- apply screen shake
  if shf > 0 then
    local dx = rnd(shi * 2) - shi
    local dy = rnd(shi * 2) - shi
    camera(dx, dy)
  else
    camera(0, 0)
  end

  -- arena border
  rect(4, 4, 123, 123, 5)

  -- pts
  for pt in all(pts) do
    pset(pt.x, pt.y, pt.col)
  end

  -- pups
  for pu in all(pups) do
    rectfill(pu.x - 2, pu.y - 2, pu.x + 2, pu.y + 2, 12)
    print(pu.type, pu.x - 4, pu.y - 8, 7)
  end


  for sq in all(sqe) do
    -- only show telegraph when timer <= 60 (1 second warning)
    if sq.timer <= 60 then
      -- color based on enemy type
      local tel_col = 10 -- default yellow
      if sq.type == "shooter" then
        tel_col = 9
      elseif sq.type == "speedy" then
        tel_col = 12
      elseif sq.type == "heavy" or sq.type == "seeker" or sq.type == "summoner" then
        tel_col = 8 -- red/magenta for bosses
      end

      -- expanding circle (radius based on remaining time)
      local progress = (60 - sq.timer) / 60 -- 0 to 1
      local radius = 3 + progress * 5 -- 3 to 8 pixels

      -- pulsing effect
      local pulse = sin(sq.timer / 4) * 1
      circ(sq.x, sq.y, radius + pulse, tel_col)

      -- inner circle for visibility
      if radius > 4 then
        circ(sq.x, sq.y, radius - 2, tel_col)
      end
    end
  end

  -- es
  for e in all(es) do
    local r = e.type == "heavy" and 5 or (e.type == "seeker" and 6 or (e.type == "summoner" and 5 or (e.type == "speedy" and 2 or 3)))

    -- apply entrance scale animation (30 frame scale up)
    local draw_r = r
    if e.spawn_timer and e.spawn_timer > 30 then
      local scale = 0.5 + (60 - e.spawn_timer) / 60
      draw_r = r * scale
    end


    if e.pulse_timer and e.pulse_timer > 0 and e.pulse_radius then
      local alpha = e.pulse_timer / 20  -- fade out as pulse expands
      local pulse_col = (e.pulse_timer % 4 < 2) and 7 or 12/cyan alternate
      circ(e.x, e.y, e.pulse_radius, pulse_col)
      if e.pulse_radius > 3 then
        circ(e.x, e.y, e.pulse_radius - 1, pulse_col)
      end
    end

    if e.spawn_timer and e.spawn_timer>0 and(e.type=="heavy" or e.type=="seeker" or e.type=="summoner")then
      local gc=e.type=="seeker" and 12 or(e.type=="summoner" and 14 or 9)
      local p=sin(e.spawn_timer/8)*2
      local br=14
      circ(e.x,e.y,br+p,gc)
      circ(e.x,e.y,br+p-1,gc)
      if e.spawn_timer>40 then circ(e.x,e.y,br+p+1,gc) end
    end


    local col = e.col
    if e.spawn_flash and e.spawn_flash > 0 then
      col = (e.spawn_flash % 2 == 0) and 15 or 8
    elseif e.flt and e.flt > 0 then
      col = (e.flt % 4 < 2) and 7 or e.col
    end


    if e.type == "heavy" and e.phase3 then
      col = 8 -- bright red (phase 3 enrage)
    elseif e.type == "heavy" and e.phase2 then
      col = 9 -- (aggression color)
    elseif e.type == "seeker" and e.phase3 then
      col = 7 -- bright white for phase 3 seeker
    elseif e.type == "seeker" and e.phase2 then
      col = 12 -- for phase 2 seeker
    elseif e.type == "summoner" and e.phase3 then
      col = 13 -- bright magenta for phase 3 summoner
    elseif e.type == "summoner" and e.phase2 then
      col = 14 -- magenta for phase 2 summoner
    end

    -- wave intensity visual: shift non-boss es warmer at high waves
    if e.type ~= "heavy" and e.type ~= "seeker" and e.type ~= "summoner" and wave >= 10 then
      if wave >= 20 then
        col = 8  -- red at wave 20+
      elseif wave >= 15 then
        col = 9 -- at wave 15+
      else
        col = 10 -- at wave 10+
      end
    end

    -- dash warning indicator (purple outline)
    if e.dash_warn and e.dash_warn > 0 then
      line(e.x, e.y, e.dash_target_x, e.dash_target_y, 11)
      -- thick pulsing outline
      if e.dash_warn % 8 < 4 then
        circ(e.x, e.y, draw_r + 1, 11)
        circ(e.x, e.y, draw_r + 2, 11)
      end
    end

    -- aim warning indicator (yellow crosshair on p)
    if e.aim_warn and e.aim_warn > 0 then
      -- pulsing crosshair on targeted position
      if e.aim_warn % 6 < 3 then
        local tx = e.aim_target_x
        local ty = e.aim_target_y
        local size = 6
        line(tx - size, ty, tx + size, ty, 10) horizontal
        line(tx, ty - size, tx, ty + size, 10) vertical
        circ(tx, ty, 4, 10)  -- targeting circle
      end
    end

    circfill(e.x, e.y, draw_r, col)


    if (e.type == "heavy" or e.type == "seeker" or e.type == "summoner") and e.glow_t and not e.spawn_flash then
      local glow_col = (e.glow_t < 6) and 8 or 3

      if e.phase3 then
        if e.type == "heavy" then
          glow_col = (e.glow_t < 6) and 8 or 2  -- bright red/dark red
        else
          glow_col = (e.glow_t < 6) and 13 or 14  -- bright magenta/magenta
        end
        circ(e.x, e.y, draw_r + 2, glow_col) -- extra ring for phase 3
        circ(e.x, e.y, draw_r + 3, glow_col) -- double extra ring for phase 3

      elseif e.phase2 then
        if e.type == "heavy" then
          glow_col = (e.glow_t < 6) and 9 or 8  -- red/orange
        else
          glow_col = (e.glow_t < 6) and 14 or 12  -- magenta/cyan
        end
        circ(e.x, e.y, draw_r + 2, glow_col) -- extra ring for phase 2
      end
      circ(e.x, e.y, draw_r + 1, glow_col)
    end


    if e.spin_timer and e.spin_timer > 0 then
      local angle = (30 - e.spin_timer) * 0.1
      local orbit_r = 9

      -- 4 orbiting energy circles for dramatic spin effect
      for i=0,3 do
        local orb_angle = angle + (i / 4)
        local ox = cos(orb_angle) * orbit_r
        local oy = sin(orb_angle) * orbit_r
        local orb_col = e.phase3 and 8 or (e.phase2 and 9 or 10) -- red/orange/yellow
        circfill(e.x + ox, e.y + oy, 2, orb_col)
        circ(e.x + ox, e.y + oy, 2, 7) outline
      end

      -- crosshairs overlay for extra detail
      local len = 8
      local hx = cos(angle) * len
      local hy = sin(angle) * len
      line(e.x - hx, e.y - hy, e.x + hx, e.y + hy, 7)
      local vx = cos(angle + 0.25) * len
      local vy = sin(angle + 0.25) * len
      line(e.x - vx, e.y - vy, e.x + vx, e.y + vy, 7)
    end


    if e.dashing then
      circ(e.x, e.y, draw_r + 1, 10)
    end

    -- hp bar for multi-hp es
    if e.max_hp > 1 then
      local w = 8
      local frac = e.hp / e.max_hp
      rectfill(e.x - w/2, e.y - draw_r - 3, e.x - w/2 + w * frac, e.y - draw_r - 2, 11)
    end
  end

  -- ps
  for p in all(ps) do
    local col = p.col or (p.owner == "p" and 10 or 8)
    -- seeking ps get magenta color
    if p.seeking then
      col = 14
      -- add trail effect
      circ(p.x, p.y, 2, 13)
    end
    circfill(p.x, p.y, p.size, col)
  end

  -- p
  if p.invuln % 4 < 2 then
    -- flash effects (red for combo reset, white for shield block)
    local player_col = 11
    if p.flash_red > 0 then
      player_col = 8  -- red flash (combo reset)
      p.flash_red -= 1
    elseif p.flash > 0 then
      player_col = 7 -- flash (shield block)
      p.flash -= 1
    end
    circfill(p.x, p.y, 4, player_col)

    -- shield with pulsing glow
    if p.has_shield then
      -- pulsing animation (oscillate radius)
      local pulse = sin(t() * 2) * 1.5  -- smooth pulse
      local base_radius = 6
      local radius = base_radius + pulse

      -- alternating bright colors for visibility
      local shield_col = flr(t() * 4) % 2 == 0 and 7 or 12

      -- outer glow ring (faint)
      circ(p.x, p.y, radius + 2, 12)
      -- main shield ring (bright)
      circ(p.x, p.y, radius, shield_col)
    end

    -- shield block flash effect
    if sft > 0 then
      -- expanding white flash ring
      local flash_radius = 8 + (8 - sft) * 2
      local flash_col = sft > 4 and 7 or 6  -- fade from white to gray
      circ(p.x, p.y, flash_radius, flash_col)
      sft -= 1
    end

    -- facing indicator
    local dir = dirs[p.rot + 1]
    line(p.x, p.y,
         p.x + dir[1] * 6,
         p.y + dir[2] * 6, 7)
  end

  -- edge indicators for off-screen es
  draw_edge_indicators()

  -- ui
  print("score:"..score, 2, 2, 7)

  if gm == "time_attack" then
    local r = max(0, 60 - tsv)
    local s = r % 60
    print(flr(r/60)..":"..(s<10 and "0"..s or s), 48, 2, r < 10 and 8 or 10)
  else
    print("wave:"..wave, 48, 2, 10)
  end

  print("time:"..tsv, 90, 2, 9)
  print("combo:"..combo, 2, 120, 14)

  -- lives
  for i=1,p.lives do
    circfill(118 - i * 6, 120, 2, 8)
  end


  local py = 10
  if rft > 0 then
    print("RR", 2, py, 10)
    py += 8
  end
  if bst > 0 then
    print("BS", 2, py, 14)
    py += 8
  end
  if smt > 0 then
    print("2X", 2, py, 12)
    py += 8
  end

  -- dash cooldown
  if p.dash_cd > 0 then
    local frac = p.dash_cd / 60
    rectfill(2, 110, 2 + 20 * (1 - frac), 113, 6)
  end

  -- milestone floating text
  for mt in all(mts) do
    local fade = mt.life / (mt.initial_life or 60)
    local col = mt.col
    if fade < 0.3 then col = 5 end
    print(mt.text, 36, mt.y, col)
  end


  if flt > 0 then
    local intensity = flt / 3
    rectfill(0, 0, 127, 127, 7)
    -- fade effect by alternating pixels
    if flt == 1 then
      for i=0,127,2 do
        for j=0,127,2 do
          pset(i, j, 0)
        end
      end
    end
  end
end

function inp()
  state = "pause"
  pause_time = time()
  _log("state:pause")
  music(-1) -- stop music
  _log("music:stop")
end

function upau()
  if test_inputp(5) then -- X to resume
    st += (time() - pause_time)
    state = "play"
    _log("state:play")

    if wave % 10 == 5 or wave % 10 == 0 then
      music(2)
      _log("music:boss")
    else
      music(1) -- gameplay theme
      _log("music:gameplay")
    end
  end
  if test_inputp(4) then -- O to menu
    inm()
  end
end

function drpau()

  drp()

  -- darken overlay
  rectfill(0, 0, 127, 127, 0)
  for i=0,127,4 do
    for j=0,127,4 do
      pset(i, j, 1)
    end
  end

  -- pause text
  print("paused", 48, 50, 7)
  print("press x to resume", 20, 70, 10)
  print("press o for menu", 22, 80, 6)
end

function igo()
  state = "gameover"
  _log("state:gameover")
  _log("final_score:"..score)
  _log("waves:"..wave)
  _log("kills:"..ekl)
  _log("time:"..tsv)
  music(3) -- gameover theme
  _log("music:gameover")


  cka()

  -- track session best combo
  bcs = max(bcs, combo)
  _log("bcs:"..bcs)


  if bcs > bco then
    bco = bcs
    dset(2, bco)
    _log("new_best_combo:"..bco)
  end

  -- save boss kills
  dset(1, bks)
  _log("total_boss_kills:"..bks)

  -- update lifetime stats
  ekl_tot += ekl
  dset(19, ekl_tot)
  _log("lifetime_kills:"..ekl_tot)

  -- check leaderboard
  local mode = gm == "boss_rush" and "boss_rush" or (gm == "time_attack" and "time_attack" or df)
  local rank = inslb(mode, score)
  if rank > 0 then
    nr = true
    _log("new_record:rank="..rank)
  end

  -- save as
  sva()

  -- log session as
  local session_count = csa()
  _log("sas:"..session_count)
end

function ugo()
  local input = test_input()
  if input & 16 > 0 then -- O to restart
    init_play()
  end
  if input & 32 > 0 then -- X to menu
    inm()
  end
end

function dgo()
  print("game over", 40, 30, 8)

  print("score: "..score, 36, 42, 7)

  -- new record indicator
  if nr then
    print("new record!", 32, 50, 12)
  end

  local base_y = nr and 58 or 50

  if gm == "boss_rush" then
    print("bosses: "..bd, 34, base_y, 8)
    print("time: "..tsv.."s", 36, base_y+8, 7)
  else
    print("waves: "..wave, 38, base_y, 7)
    print("kills: "..ekl, 38, base_y+8, 7)
    print("time: "..tsv.."s", 36, base_y+16, 7)
  end

  -- df
  local diff_col = df == "easy" and 12 or (df == "hard" and 8 or 10)
  local mode_text = gm == "boss_rush" and "boss rush" or df
  local mode_y = (gm == "boss_rush" and 66 or 74) + (nr and 8 or 0)
  print("mode: "..mode_text, 30, mode_y, diff_col)


  local session_count = csa()
  local ach_y = 82 + (nr and 8 or 0)
  if session_count > 0 then
    print("new as: "..session_count, 16, ach_y, 12)
    -- show which ones
    local y = ach_y + 8
    for i=1,13 do
      if sas[i] then
        local def = ads[i]
        print("\x97 "..def.name, 8, y, 10)
        y += 6
        if y > 106 + (nr and 8 or 0) then break end -- prevent overflow
      end
    end
  else
    print("no new as", 20, ach_y, 5)
  end

  -- total as
  local total = cna()
  print("total: "..total.."/13", 42, 112 + (nr and 8 or 0), 14)

  print("o:retry x:menu", 28, 120, 6)
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
__sfx__
000100000c0500e0500f05010050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001c0501a0501705014050110500e0500b0500805000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002000020050230502505027050290502a0502a0502a0502a0502a0502a0502a0502a0502a0502a0502a050000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000180501e05024050280500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000240502405023050210501e0501b05017050130500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000140501605018050190500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800001c0502005024050280502c0502c0502c0502c0502c0502a05027050240502005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200002c0502a0502705024050200501c05018050140500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001c0501e05020050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001e0502005022050200501e0502005022050200501e0502005022050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000100501305015050180501b0501e05021050240502705029050290502a0502a0502a0502a0502a050000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c0501c0501e0501e05020050200502205022050240502405024050240502005020050200502005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000010050100500f0500f0500c0500c0500f0500f05010050100501005010050180501805018050180500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000001c0501c0501e0501e05020050200502205022050270502705027050270502005020050200502005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000008050080500a0500a0500c0500c0500a0500a050080500805008050080501005010050100501005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000240502405027050270502905029050270502705024050240502405024050270502705027050270500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000006050060500805008050090500905008050080500605006050060500605010050100501005010050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0008000020050220502405027050290502a0502a0502a05029050270502405020050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c0501a05017050140501105010050100500f0500d0500c0500a05009050080500705006050050500405000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0b0c0d0e
01 0f100809
02 00010203
03 04050607

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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

