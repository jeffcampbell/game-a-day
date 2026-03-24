pico-8 cartridge // http://www.pico-8.com
version 42
__lua__testmode = false test_log = {}
test_inputs = {} test_input_idx = 0
function _log(msg)
  if testmode then add(test_log, msg) end
end
function _capture()
  if testmode then add(test_log, "SCREEN:"..tostr(stat(0))) end
end
function test_input(b)
  if testmode and test_input_idx < #test_inputs then
    test_input_idx += 1 return test_inputs[test_input_idx] or 0
  end
  return btn()
end
state="menu" score=0 lives=3 level=1 ml=8 gw=false mpl=-1 cc=0 cw=0
pa={} mp=32 si=0 st=0 fc=-1 ft=0
ls={} ll={} hsr=-1 lat=0 mo=1
tam=false tal=1 lt=0 tat={} tsl=1 tmo=1
slu=false pl={x=64,y=100,w=8,h=8,vx=0,vy=0,j=false,cf=0}
g=0.2 jp=5 mf=4 mc=6 ms=1.5 plat={}
en={} col={}
b=nil
function load_leaderboard()
  ls = {} ll = {}
  for i=0,4 do
    local s_low = dget(i*2) local s_high = dget(i*2+1)
    local s = s_low + s_high * 256 local l_low = dget(20 + i*2)
    local l_high = dget(20 + i*2+1) local l = l_low + l_high * 256
    if s > 0 then
      add(ls, s) add(ll, l)
    end
  end
  _log("leaderboard:loaded")
end
function save_score(sc, lvl)
  hsr = -1
  for i=1,#ls do
    if sc > ls[i] then
      hsr = i
      if #ls < 5 then
  add(ls, 0) add(ll, 0)
      end
      for j=#ls,i+1,-1 do
  ls[j] = ls[j-1] ll[j] = ll[j-1]
      end
      ls[i] = sc ll[i] = lvl
      if #ls > 5 then
  del(ls, ls[6]) del(ll, ll[6])
      end
      break
    end
  end
  if #ls < 5 and hsr == -1 then
    add(ls, sc) add(ll, lvl)
    hsr = #ls
  end
  for i=0,4 do
    if i < #ls then
      local sv = ls[i+1] local lv = ll[i+1]
      dset(i*2, sv % 256) dset(i*2+1, flr(sv / 256))
      dset(20 + i*2, lv % 256) dset(20 + i*2+1, flr(lv / 256))
    else
      dset(i*2, 0) dset(i*2+1, 0)
      dset(20 + i*2, 0) dset(20 + i*2+1, 0)
    end
  end
  _log("score:saved:"..sc)
end
function clear_leaderboard()
  ls = {} ll = {}
  hsr = -1
  for i=0,29 do
    if i<10 or i>=20 then dset(i, 0) end
  end
  _log("leaderboard:cleared")
end
function load_time_attack_times()
  tat = {}
  for lvl=1,10 do
    tat[lvl] = {}
    for rank=1,3 do
      local slot = 30 + (lvl-1)*6 + (rank-1)*2 local lo = dget(slot)
      local hi = dget(slot+1) local time_val = lo + hi * 256
      if time_val > 0 then
  add(tat[lvl], time_val)
      end
    end
  end
  slu = (dget(102) > 0) _log("time_attack:loaded")
end
function save_time_attack(lvl, time_frames)
  if not tat[lvl] then
    tat[lvl] = {}
  end
  local times = tat[lvl] local insert_pos = #times + 1
  for i=1,#times do
    if time_frames < times[i] then
      insert_pos = i break
    end
  end
  if insert_pos <= 3 then
    if #times < 3 then
      add(times, 0)
    end
    for i=#times,insert_pos+1,-1 do
      times[i] = times[i-1]
    end
    times[insert_pos] = time_frames
    if #times > 3 then
      del(times, times[4])
    end
  end
  for rank=1,3 do
    local slot = 30 + (lvl-1)*6 + (rank-1)*2
    if rank <= #times then
      local t = times[rank] dset(slot, t % 256)
      dset(slot+1, flr(t / 256))
    else
      dset(slot, 0) dset(slot+1, 0)
    end
  end
  _log("time_attack:saved:"..lvl..":"..time_frames)
end
function create_level(lvl)
  plat = {} en = {}
  col = {} b = nil
  if lvl == 1 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=10, y=105, w=30, h=8})
    add(plat, {x=50, y=90, w=30, h=8})
    add(plat, {x=85, y=75, w=35, h=8})
    add(plat, {x=20, y=60, w=35, h=8, moving=true, vy=-0.5, ymin=50, ymax=70})
    add(plat, {x=70, y=45, w=40, h=8})
    add(plat, {x=15, y=30, w=40, h=8})
    add(plat, {x=60, y=15, w=50, h=8})
    add(en,{x=50, y=85, w=8, h=8, vx=0.8, xmin=40, xmax=70, type="patrol"})
    add(en,{x=80, y=70, w=8, h=8, vx=-0.8, xmin=75, xmax=100, type="patrol"})
    add(en,{x=30, y=55, w=8, h=8, vx=0.8, xmin=20, xmax=50, type="patrol"}) add(col,{x=35, y=95})
    add(col,{x=75, y=40}) add(col,{x=40, y=20})
  elseif lvl == 2 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=5, y=108, w=25, h=8})
    add(plat, {x=50, y=95, w=25, h=8, moving=true, vy=0.5, ymin=88, ymax=102})
    add(plat, {x=90, y=82, w=30, h=8})
    add(plat, {x=15, y=70, w=30, h=8})
    add(plat, {x=70, y=57, w=35, h=8, moving=true, vy=-0.4, ymin=48, ymax=65})
    add(plat, {x=25, y=42, w=35, h=8})
    add(plat, {x=75, y=28, w=40, h=8})
    add(plat, {x=20, y=12, w=35, h=8})
    add(en,{x=45, y=90, w=8, h=8, vx=1.2, xmin=35, xmax=60, type="patrol"})
    add(en,{x=85, y=77, w=8, h=8, vx=-1.2, xmin=70, xmax=100, type="patrol"})
    add(en,{x=25, y=65, w=8, h=8, vx=1.2, xmin=15, xmax=45, type="patrol"})
    add(en,{x=60, y=50, w=8, h=8, vy=0.6, ymin=42, ymax=65, type="vertical"}) add(col,{x=30, y=100})
    add(col,{x=70, y=87}) add(col,{x=35, y=62})
    add(col,{x=80, y=37})
  elseif lvl == 3 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=8, y=110, w=20, h=8})
    add(plat, {x=45, y=100, w=20, h=8, moving=true, vy=-0.6, ymin=90, ymax=108})
    add(plat, {x=85, y=90, w=28, h=8})
    add(plat, {x=10, y=78, w=25, h=8})
    add(plat, {x=55, y=68, w=30, h=8})
    add(plat, {x=25, y=55, w=25, h=8})
    add(plat, {x=70, y=42, w=35, h=8})
    add(plat, {x=15, y=28, w=30, h=8})
    add(plat, {x=65, y=15, w=40, h=8})
    add(en,{x=50, y=95, w=8, h=8, vx=2.5, xmin=40, xmax=65, type="patrol"})
    add(en,{x=85, y=85, w=8, h=8, vx=-2.5, xmin=70, xmax=100, type="patrol"})
    add(en,{x=20, y=73, w=8, h=8, vx=1.5, xmin=10, xmax=35, type="jumping", jump_freq=40, ground_y=73})
    add(en,{x=65, y=63, w=8, h=8, vx=-1.5, xmin=50, xmax=80, type="patrol"})
    add(en,{x=35, y=50, w=8, h=8, vx=2.5, xmin=25, xmax=45, type="patrol"}) add(col,{x=30, y=102})
    add(col,{x=75, y=92}) add(col,{x=25, y=70})
    add(col,{x=65, y=60}) add(col,{x=35, y=37})
  elseif lvl == 4 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=12, y=108, w=18, h=8, moving=true, vx=0.8, xmin=5, xmax=25})
    add(plat, {x=50, y=98, w=18, h=8})
    add(plat, {x=88, y=88, w=26, h=8, moving=true, vy=-0.7, ymin=78, ymax=95})
    add(plat, {x=8, y=76, w=22, h=8})
    add(plat, {x=58, y=64, w=28, h=8, moving=true, vx=-0.9, xmin=45, xmax=70})
    add(plat, {x=28, y=50, w=20, h=8})
    add(plat, {x=75, y=38, w=30, h=8})
    add(plat, {x=18, y=24, w=25, h=8})
    add(plat, {x=70, y=10, w=35, h=8})
    add(en,{x=48, y=93, w=8, h=8, vx=2.8, xmin=38, xmax=62, type="patrol"})
    add(en,{x=88, y=83, w=8, h=8, vx=-2.8, xmin=72, xmax=102, type="patrol"})
    add(en,{x=15, y=71, w=8, h=8, vx=1.8, xmin=5, xmax=35, type="jumping", jump_freq=35, ground_y=71})
    add(en,{x=70, y=59, w=8, h=8, vy=-0.8, ymin=50, ymax=68, type="vertical"})
    add(en,{x=35, y=45, w=8, h=8, vx=2.8, xmin=25, xmax=50, type="jumping", jump_freq=45, ground_y=45})
    add(en,{x=80, y=33, w=8, h=8, vx=-2.5, xmin=65, xmax=95, type="patrol"}) add(col,{x=32, y=100})
    add(col,{x=72, y=90}) add(col,{x=20, y=68})
    add(col,{x=65, y=56}) add(col,{x=40, y=42})
    add(col,{x=28, y=16})
  elseif lvl == 5 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=10, y=110, w=16, h=8})
    add(plat, {x=42, y=100, w=18, h=8})
    add(plat, {x=78, y=90, w=16, h=8, moving=true, vy=-0.7, ymin=80, ymax=98})
    add(plat, {x=15, y=78, w=18, h=8})
    add(plat, {x=55, y=66, w=16, h=8})
    add(plat, {x=88, y=54, w=20, h=8, moving=true, vx=-1.0, xmin=75, xmax=95})
    add(plat, {x=25, y=42, w=16, h=8})
    add(plat, {x=68, y=30, w=18, h=8})
    add(plat, {x=12, y=18, w=20, h=8, moving=true, vy=-0.7, ymin=8, ymax=25})
    add(en,{x=50, y=95, w=8, h=8, vx=2.8, xmin=40, xmax=65, type="patrol"})
    add(en,{x=85, y=85, w=8, h=8, vy=-0.9, ymin=75, ymax=95, type="vertical"})
    add(en,{x=25, y=73, w=8, h=8, vx=2.2, xmin=15, xmax=40, type="jumping", jump_freq=38, ground_y=73})
    add(en,{x=70, y=61, w=8, h=8, vy=0.9, ymin=52, ymax=70, type="vertical"})
    add(en,{x=35, y=50, w=8, h=8, vx=-2.8, xmin=20, xmax=50, type="patrol"})
    add(en,{x=80, y=37, w=8, h=8, vy=-1.0, ymin=27, ymax=45, type="vertical"})
    add(col,{x=28, y=102}) add(col,{x=60, y=92})
    add(col,{x=92, y=82}) add(col,{x=32, y=70})
    add(col,{x=70, y=58}) add(col,{x=40, y=44})
    add(col,{x=75, y=32})
  elseif lvl == 6 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=8, y=108, w=16, h=8, moving=true, vx=0.9, xmin=5, xmax=25})
    add(plat, {x=48, y=96, w=16, h=8})
    add(plat, {x=80, y=84, w=16, h=8, moving=true, vx=-0.9, xmin=65, xmax=90})
    add(plat, {x=20, y=72, w=16, h=8})
    add(plat, {x=65, y=60, w=16, h=8, moving=true, vy=-0.8, ymin=50, ymax=68})
    add(plat, {x=35, y=48, w=16, h=8})
    add(plat, {x=75, y=36, w=16, h=8, moving=true, vx=1.0, xmin=60, xmax=85})
    add(plat, {x=15, y=24, w=16, h=8})
    add(plat, {x=55, y=12, w=18, h=8, moving=true, vy=-0.9, ymin=2, ymax=20})
    add(en,{x=45, y=91, w=8, h=8, vx=3.0, xmin=35, xmax=60, type="patrol"})
    add(en,{x=85, y=79, w=8, h=8, vx=-3.0, xmin=70, xmax=95, type="patrol"})
    add(en,{x=25, y=67, w=8, h=8, vx=2.5, xmin=15, xmax=40, type="jumping", jump_freq=36, ground_y=67})
    add(en,{x=70, y=55, w=8, h=8, vy=-1.1, ymin=45, ymax=65, type="vertical"})
    add(en,{x=40, y=43, w=8, h=8, vx=-2.8, xmin=25, xmax=55, type="patrol"})
    add(en,{x=80, y=31, w=8, h=8, vy=1.1, ymin=21, ymax=40, type="vertical"})
    add(en,{x=30, y=37, w=8, h=8, vx=2.8, xmin=20, xmax=45, type="jumping", jump_freq=35, ground_y=37})
    add(col,{x=24, y=100}) add(col,{x=58, y=88})
    add(col,{x=88, y=76}) add(col,{x=38, y=64})
    add(col,{x=78, y=52}) add(col,{x=45, y=40})
    add(col,{x=25, y=28})
  elseif lvl == 7 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=5, y=110, w=18, h=8})
    add(plat, {x=50, y=100, w=18, h=8, moving=true, vy=0.6, ymin=92, ymax=106})
    add(plat, {x=85, y=90, w=16, h=8})
    add(plat, {x=20, y=78, w=18, h=8})
    add(plat, {x=60, y=66, w=16, h=8, moving=true, vx=-1.0, xmin=45, xmax=68})
    add(plat, {x=35, y=54, w=18, h=8})
    add(plat, {x=75, y=42, w=18, h=8, moving=true, vx=1.0, xmin=62, xmax=85})
    add(plat, {x=12, y=30, w=16, h=8})
    add(plat, {x=55, y=18, w=18, h=8}) add(plat, {x=28, y=6, w=16, h=8})
    add(en,{x=48, y=95, w=8, h=8, vx=3.2, xmin=38, xmax=62, type="patrol"})
    add(en,{x=88, y=85, w=8, h=8, vx=-3.2, xmin=72, xmax=100, type="patrol"})
    add(en,{x=25, y=73, w=8, h=8, vx=2.8, xmin=15, xmax=40, type="jumping", jump_freq=33, ground_y=73})
    add(en,{x=68, y=61, w=8, h=8, vy=-1.2, ymin=51, ymax=70, type="vertical"})
    add(en,{x=40, y=49, w=8, h=8, vx=-3.0, xmin=25, xmax=55, type="patrol"})
    add(en,{x=80, y=37, w=8, h=8, vy=1.2, ymin=27, ymax=47, type="vertical"})
    add(en,{x=32, y=47, w=8, h=8, vx=2.8, xmin=22, xmax=48, type="jumping", jump_freq=34, ground_y=47})
    add(en,{x=62, y=25, w=8, h=8, vx=-2.8, xmin=47, xmax=77, type="patrol"}) add(col,{x=28, y=102})
    add(col,{x=62, y=92}) add(col,{x=92, y=82})
    add(col,{x=40, y=70}) add(col,{x=75, y=58})
    add(col,{x=50, y=44}) add(col,{x=30, y=22})
  elseif lvl == 8 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=8, y=108, w=14, h=8, moving=true, vx=1.2, xmin=4, xmax=24})
    add(plat, {x=45, y=98, w=12, h=8})
    add(plat, {x=82, y=86, w=14, h=8, moving=true, vx=-1.2, xmin=67, xmax=88})
    add(plat, {x=22, y=74, w=12, h=8})
    add(plat, {x=62, y=62, w=12, h=8, moving=true, vy=-1.0, ymin=52, ymax=70})
    add(plat, {x=38, y=50, w=12, h=8})
    add(plat, {x=75, y=38, w=12, h=8, moving=true, vx=1.3, xmin=60, xmax=85})
    add(plat, {x=18, y=26, w=12, h=8})
    add(plat, {x=55, y=14, w=14, h=8, moving=true, vy=-1.1, ymin=4, ymax=22})
    add(plat, {x=32, y=6, w=10, h=8})
    add(en,{x=50, y=93, w=8, h=8, vx=3.8, xmin=40, xmax=65, type="patrol"})
    add(en,{x=85, y=81, w=8, h=8, vx=-3.8, xmin=70, xmax=100, type="patrol"})
    add(en,{x=28, y=69, w=8, h=8, vx=3.2, xmin=18, xmax=42, type="jumping", jump_freq=28, ground_y=69})
    add(en,{x=70, y=57, w=8, h=8, vy=-1.5, ymin=47, ymax=67, type="vertical"})
    add(en,{x=42, y=45, w=8, h=8, vx=-3.5, xmin=27, xmax=57, type="patrol"})
    add(en,{x=82, y=33, w=8, h=8, vy=1.5, ymin=23, ymax=43, type="vertical"})
    add(en,{x=35, y=57, w=8, h=8, vx=3.2, xmin=25, xmax=50, type="jumping", jump_freq=26, ground_y=57})
    add(en,{x=62, y=21, w=8, h=8, vx=-3.5, xmin=47, xmax=77, type="patrol"})
    add(en,{x=48, y=73, w=8, h=8, vx=3.0, xmin=38, xmax=63, type="patrol"}) b = {
      x=60, y=40,      health=3, mh=3, phase=1,
      wave_time=0, type="boss"
    } _log("boss:spawned")
    add(col,{x=26, y=100}) add(col,{x=60, y=90})
    add(col,{x=88, y=78}) add(col,{x=45, y=66})
    add(col,{x=75, y=54}) add(col,{x=28, y=32})
  elseif lvl == 9 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=10, y=95, w=35, h=8})
    add(plat, {x=70, y=70, w=35, h=8})
    add(plat, {x=15, y=45, w=35, h=8})
    add(plat, {x=65, y=20, w=40, h=8})
    add(en,{x=45, y=90, w=8, h=8, vx=3.0, xmin=35, xmax=65, type="patrol"})
    add(en,{x=80, y=65, w=8, h=8, vx=-3.0, xmin=65, xmax=95, type="patrol"}) add(col,{x=32, y=87})
  elseif lvl == 10 then
    add(plat, {x=0, y=120, w=128, h=8})
    add(plat, {x=20, y=100, w=80, h=8})
    add(plat, {x=30, y=75, w=70, h=8})
    add(plat, {x=15, y=50, w=90, h=8})
    add(plat, {x=35, y=25, w=60, h=8})
    add(en,{x=64, y=95, w=8, h=8, vy=-1.5, ymin=85, ymax=105, type="vertical"})
    add(en,{x=64, y=70, w=8, h=8, vy=1.5, ymin=60, ymax=80, type="vertical"}) add(col,{x=64, y=92})
  end
end
function init_game(mode)
  tam = (mode == "time_attack")
  if tam then
    level = tsl lives = 1
  else
    level = 1 lives = 3
  end
  score = 0 gw = false
  lt = 0 start_level(level)
end
function start_level(lvl)
  pl.x = 64 pl.y = 100
  pl.vx = 0 pl.vy = 0
  pl.j = false pl.cf = 0
  create_level(lvl) _log("level:"..lvl)
  state = "play" local music_pat = (lvl == 1 and 1 or (lvl <= 3 and 2 or 3))
  music(music_pat) mpl = music_pat
  _log("music:level"..lvl) sfx(5)
end
function update_menu()
  if #ls == 0 then load_leaderboard() load_time_attack_times() end
  if mpl ~= 0 then music(0) mpl = 0 _log("music:menu") end
  if btnp(2) then mo = max(1, mo-1) end
  if btnp(3) then mo = min(4, mo+1) end
  if btnp(4) or btnp(5) then
    if mo == 1 then
      _log("action:start_game") init_game("normal")
    elseif mo == 2 then
      _log("action:view_leaderboard") state = "leaderboard"
    elseif mo == 3 then
      _log("action:clear_leaderboard") clear_leaderboard()
      mo = 1
    elseif mo == 4 then
      _log("action:time_attack") state = "ta_select"
      tsl = 1
    end
  end
end
function update_leaderboard()
  if btnp(4) or btnp(5) then
    _log("state:menu") mo = 1
    state = "menu"
  end
end
function update_ta_select()
  local max_lvl = 8
  if slu then max_lvl = 10 end
  if btnp(2) then
    tsl = max(1, tsl - 1)
  end
  if btnp(3) then
    tsl = min(max_lvl, tsl + 1)
  end
  if btnp(4) then
    _log("ta:selected_level:"..tsl) init_game("time_attack")
  elseif btnp(5) then
    _log("ta:view_times:"..tsl) state = "ta_leaderboard"
  end
end
function update_ta_leaderboard()
  local m=8+(slu and 2 or 0)
  if btnp(2) then tsl = max(1, tsl-1)
  elseif btnp(3) then tsl = min(m, tsl+1)
  elseif btnp(4) or btnp(5) then _log("state:ta_select") state = "ta_select" end
end
function update_play()
  if tam then lt += 1 end
  update_particles() update_shake() update_flash()
  if cw > 0 then cw -= 1 else cc = 0 end
  if not pl.j and pl.cf > 0 then pl.cf -= 1 end
  if test_input(0) then pl.vx = -ms
  elseif test_input(1) then pl.vx = ms
  else pl.vx = 0 end
  if test_input(4) and (not pl.j or pl.cf > 0) then
    pl.vy = -jp pl.j = true
    pl.cf = 0 sfx(0)
    _log("action:jump")
  end
  pl.vy = min(pl.vy+g, mf) pl.x += pl.vx pl.y += pl.vy
  if pl.x < 0 then pl.x = 0 elseif pl.x+pl.w > 128 then pl.x = 128-pl.w end
  for p in all(plat) do
    if p.moving then
      if p.vy then
  p.y += p.vy
  if p.y < p.ymin or p.y > p.ymax then p.vy *= -1 end
      elseif p.vx then
  p.x += p.vx
  if p.x < p.xmin or p.x > p.xmax then p.vx *= -1 end
      end
    end
  end
  local w=pl.j
  for p in all(plat) do
    if collide_rect(pl.x, pl.y+pl.h, pl.w, 1,
  p.x, p.y, p.w, p.h) and pl.vy >= 0 then pl.y = p.y - pl.h
      pl.vy = 0 pl.j = false
      pl.cf = mc
      if w then apply_shake(1, 4) _log("action:land") end
      if p.moving then
  if p.vy then pl.y += p.vy end
  if p.vx then pl.x += p.vx end
      end
    end
  end
  for e in all(en) do
    if collide_rect(pl.x, pl.y, pl.w, pl.h,
  e.x, e.y, 8, 8) then lives -= 1 cc = 0 cw = 0
      _log("action:hit_enemy") hit_effect(pl.x, pl.y, 2, 8, 8, 6, 3, 1.5)
      if lives <= 0 then _log("gameover:lose") state = "gameover"
      else pl.x = 64 pl.y = 100 pl.vy = 0 pl.cf = mc end
    end
  end
  if b and collide_rect(pl.x, pl.y, pl.w, pl.h,
  b.x, b.y, 8, 8) then b.health -= 1 _log("action:hit_boss:"..b.health)
    hit_effect(b.x, b.y, 3, 9, 10, 8, 4, 1.8) pl.x -= 3 pl.vy = -4
    if b.health <= 0 then
      local m=min(cc+1, 5) score += 50*m cc = m cw = 300
      _log("action:boss_defeated:combo:"..m.."x")
      b = nil sfx(3) sfx(0) apply_shake(2, 12) set_flash(11, 25) spawn_particles(64, 50, 20, 9, 2.5)
    end
  end
  for x in all(col) do
    if not x.collected and collide_rect(pl.x, pl.y, pl.w, pl.h,
  x.x, x.y, 8, 8) then x.collected = true score += 10
      sfx(1) spawn_particles(x.x+4, x.y+4, 10, 11, 1.5) set_flash(11, 3) _log("action:collect")
    end
  end
  for e in all(en) do
    if e.type == "vertical" then
      e.y += e.vy
      if e.y < e.ymin or e.y > e.ymax then
  e.vy *= -1
      end
    elseif e.type == "jumping" then
      e.x += e.vx
      if e.x < e.xmin or e.x > e.xmax then
  e.vx *= -1
      end
      e.jump_timer = (e.jump_timer or 0) + 1
      if e.jump_timer > e.jump_freq then
  e.y -= 3 e.jump_timer = 0
  _log("action:enemy_jump")
      else
  e.y = min(e.y + 0.15, e.ground_y)
      end
    else
      e.x += e.vx
      if e.x < e.xmin or e.x > e.xmax then
  e.vx *= -1
      end
    end
  end
  if b then
    b.wave_time += 1
    if b.health <= b.mh * 0.5 then
      b.phase = 2 b.x += cos(b.wave_time/25)*2.2 b.y += sin(b.wave_time/20)*1.5
      b.x = max(20, min(b.x, 100)) b.y = max(20, min(b.y, 80))
    else
      b.phase = 1 b.x = 40 + sin(b.wave_time/40)*25 b.y = 45 + cos(b.wave_time/50)*10
    end
  end
  if pl.y < 5 or (level == 8 and not b) then
    sfx(3) apply_shake(1, 8) set_flash(11, 20) spawn_particles(64, 32, 12, 11, 2.5)
    if tam then save_time_attack(level, lt) end
    if level >= ml then
      gw = true slu = true dset(102, 1)
      sfx(8) music(-1) mpl = -1 _log("gameover:win") state = "gameover"
    else
      if not tam then
  level += 1 _log("action:level_complete")
  start_level(level)
      else
  _log("ta:level_complete:"..lt) state = "gameover"
      end
    end
  end
  if pl.y > 128 then
    lives -= 1 _log("action:fell_off")
    if lives <= 0 then
      _log("gameover:lose") state = "gameover"
    else
      pl.x = 64 pl.y = 100
      pl.vy = 0
    end
  end
end
function update_gameover()
  if lat == 0 then
    if not tam then save_score(score, level) end
    lat = 1
  end
  if btnp(4) or btnp(5) then
    _log("state:menu") music(0) mpl = 0 state = (tam and "ta_select" or "menu")
    if not tam then mo = 1 end
    hsr = -1 lat = 0
  end
end
function _update()
  if state == "menu" then update_menu()
  elseif state == "leaderboard" then update_leaderboard()
  elseif state == "ta_select" then update_ta_select()
  elseif state == "ta_leaderboard" then update_ta_leaderboard()
  elseif state == "play" then update_play()
  elseif state == "gameover" then update_gameover()
  end
end
function collide_rect(x1, y1, w1, h1, x2, y2, w2, h2)
  return x1 < x2 + w2 and x1 + w1 > x2 and
  y1 < y2 + h2 and y1 + h1 > y2
end
function spawn_particles(x, y, count, color, speed)
  if #pa >= mp then return end
  for i=1,count do
    if #pa < mp then
      local angle = rnd(1) local vel = speed * (0.5 + rnd(0.5))
      add(pa, { x = x + rnd(4) - 2,
  y = y + rnd(4) - 2, vx = cos(angle) * vel,
  vy = sin(angle) * vel,
  life = 30,
  max_life = 30,
  color = color })
    end
  end
end
function update_particles()
  for p in all(pa) do
    p.x += p.vx p.y += p.vy
    p.vy += 0.15
    p.life -= 1
    if p.life <= 0 then
      del(pa, p)
    end
  end
end
function draw_particles()
  for p in all(pa) do
    local brightness = flr(p.life / p.max_life * 3)
    if brightness > 0 then
      pset(flr(p.x), flr(p.y), p.color)
    end
  end
end
function apply_shake(intensity, duration)
  si = max(si, intensity) st = max(st, duration)
end
function update_shake()
  if st > 0 then
    st -= 1
  else
    si = 0
  end
end
function set_flash(color, duration)
  fc = color ft = duration
end
function update_flash()
  if ft > 0 then
    ft -= 1
  else
    fc = -1
  end
end
function get_camera_offset()
  if si > 0 then
    return rnd(si * 2) - si,
  rnd(si * 2) - si
  end
  return 0, 0
end
function hit_effect(x,y,s,c,p,sd,fd,ps)
  sfx(2) sfx(6) apply_shake(s,sd) spawn_particles(x+4,y+4,p,c,ps) set_flash(c,fd)
end
function draw_menu()
  cls(1)
  print("platformer", 50, 40, 7)
  print("8 levels!", 38, 50, 3) local o={40,38,38,40}
  local t={"start game","leaderboard","clear scores","time attack"}
  for i=1,4 do
    local c=(mo==i and 11 or 3) print(t[i], o[i], 55+i*10, c)
  end
  print("up/down: select, z: pick", 15, 110, 6)
end
function draw_play()
  cls(1) local shake_x, shake_y = get_camera_offset()
  camera(shake_x, shake_y)
  for p in all(plat) do
    for px = p.x, p.x + p.w - 1, 8 do
      spr(2, px, p.y)
    end
  end
  for x in all(col) do
    if not x.collected then
      spr(3, x.x, x.y)
    end
  end
  for e in all(en) do
    spr(1, e.x, e.y)
  end
  if b then
    spr(1, b.x, b.y)
  end
  spr(0, pl.x, pl.y) draw_particles()
  camera(0, 0)
  if ft > 0 then
    rectfill(0, 0, 127, 127, fc)
  end
  if tam then
    print(fmt(lt), 5, 5, 7)
  else
    print("score: "..score, 5, 5, 7)
  end
  print("lives: "..lives, 5, 12, 7) print("lvl "..level, 110, 5, 7)
end
function draw_gameover()
  cls(1)
  if tam then
    print("time attack complete!", 25, 40, 11) print("level "..level, 50, 55, 3) print("time: "..fmt(lt), 40, 70, 7)
  elseif gw then
    print("you win!", 50, 40, 11) print("victory!", 50, 55, 3)
  else
    print("game over", 45, 40, 8) print("reached level "..level, 35, 55, 7)
  end
  if not tam then
    print("score: "..score, 50, 70, 7)
    if hsr > 0 then print("#"..hsr.." high score!", 30, 80, 11) end
  end
  print("press z to menu", 35, 95, 6)
end
function fmt(f)
  local s=flr(f/60) local m=flr(s/60)
  s=s%60 return m..":"..((s<10 and "0" or "")..s)
end
function draw_leaderboard()
  cls(1) print("leaderboard", 45, 10, 7)
  print("top 5 scores", 40, 20, 3)
  if #ls == 0 then
    print("no scores yet!", 35, 50, 8)
  else
    for i=1,#ls do
      local y = 35 + (i-1) * 10 print("#"..i, 20, y, 3)
      print(ls[i], 45, y, 7) print("l"..ll[i], 70, y, 6)
    end
  end
  print("z to menu", 40, 110, 6)
end
function draw_ta_select()
  cls(1) print("time attack", 45, 20, 7)
  print("level:", 45, 35, 3) local m=8+(slu and 2 or 0)
  for i=1,m do
    local c=(i==tsl and 11 or 3) local l=(i<9 and "l"..i or (i==9 and "s1" or "s2"))
    print(l, 40+((i-1)%4)*20, 50+flr((i-1)/4)*15, c)
  end
  print("z:play x:times", 30, 110, 6)
end
function draw_ta_leaderboard()
  cls(1) print("best times - level "..tsl, 20, 10, 7)
  if not tat[tsl] or
     #tat[tsl] == 0 then print("no times yet!", 50, 50, 8)
  else
    local times = tat[tsl]
    for i=1,#times do
      local y = 35 + (i-1) * 15 print("#"..i, 20, y, 3)
      print(fmt(times[i]), 50, y, 7)
    end
  end
  print("z to back", 40, 110, 6)
end
function _draw()
  if state == "menu" then draw_menu()
  elseif state == "leaderboard" then draw_leaderboard()
  elseif state == "ta_select" then draw_ta_select()
  elseif state == "ta_leaderboard" then draw_ta_leaderboard()
  elseif state == "play" then draw_play()
  elseif state == "gameover" then draw_gameover()
  end
end

__gfx__
00099900
01099910
01997190
00999900
09999990
99099999
99099999
00999900
00822800
08222280
82388288
82388288
82388288
08222280
00822800
00000000
44444444
40040040
44444444
44444444
44044044
44444444
44444444
44444444
00aaa000
0a999a00
a9999a00
a9999aa0
a9999a00
0a999a00
00aaa000
00000000
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
010a00002254325532553255302553255325532553255302553255325532553255302553255325532553255302553255325532553255302553255325532553255302553255325532553255302553255325532553255
010a00003654300034503000400000003650365036500340034003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a00001c4320432204322043220432114322043200432000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a000050050505300505053004050505300505053005050505300505053004050505300505053005050505300505053004050505300505053005050505300505053004050505300505053005050505300505053
010800004505350505505305a053505a0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010a0000365436543654365436543654300030003000300030003000300030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01080000175017501750175017500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010800004305430543054305430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010c00006a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a646a64
01040000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__music__
00 01010101
01 02030203
02 03040304
03 05060506

