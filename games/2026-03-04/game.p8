pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- meteor dodge
-- dodge falling meteors!

-- test infrastructure
testmode=false
test_log={}
test_inputs={}
test_input_idx=0

function _log(msg)
 if testmode then add(test_log,msg) end
end

function _capture()
 if testmode then add(test_log,"SCREEN:"..tostr(stat(0))) end
end

function test_input()
 if testmode and test_input_idx<#test_inputs then
  test_input_idx+=1
  return test_inputs[test_input_idx] or 0
 end
 return btn()
end

-- helpers
function dk(v,d)
 return v>0 and v-(d or 1) or 0
end
function upd_stars(m)
 for s in all(stars) do
  s.y+=s.spd*m
  if s.y>128 then s.y=0 s.x=rnd(128) end
 end
end
function lbp(i)
 if is_endless then return "" end
 if lb_gflag[i] then return "[g]" end
 if lb_mflag[i] then return "[m]" end
 return ""
end

-- game state
state="menu"
score=0
hiscore=0
time_alive=0
go_timer=0
ship_x=60
ship_y=116
ship_w=7
meteors={}
particles={}
stars={}
shake=0
flash=0
anim_t=0
-- difficulty
spawn_timer=0
spawn_rate=40
meteor_speed=1.0
diff_timer=0
diff_level=1
-- difficulty selection
diff_sel=2 -- 1=easy,2=normal,3=hard
diff_names={"easy","normal","hard"}
score_mult=1.0
-- near-miss system
near_miss_dist=12
nm_flash=0
nm_streak=0
nm_best=0
nm_last_bonus=0
-- power-up system
powerups={}
shield_count=0
slowmo_timer=0
dblscore_timer=0
pu_flash=0
pu_flash_txt=""
pu_collected=0
-- boss meteor wave system
boss_active=false
boss_timer=0
boss_flash=0
last_boss_score=0
boss_atk=1 -- 1=burst,2=spiral,3=ring,4=aimed
tele_timer=0
tele_dur=0
tele_x=64
boss_vuln=0
-- dodge combo system
dodge_combo=0
dodge_best=0
combo_flash=0
combo_flash_txt=""
-- achievement system
achv={}
achv_flash=0
achv_flash_txt=""
achv_names={
 "first blood","dodgemaster",
 "close call","collector",
 "boss slayer","survivor",
 "hard mode","precision",
 "speed demon","legendary",
 "time master","flawless 90s",
 "rad dodger","ice rider",
 "magnet ace","chaos surfer",
 "glt master","hz scientist","glt victor",
 "end survivor","end climber","untouchable"
}
boss_waves=0
-- boss death fanfare
bd_flash=0
bd_flash_txt=""
bd_x=64
bd_y=40
nm_count=0
run_achv=0 -- achievements this run
-- hazard meteor system
-- 0=normal,1=radioactive,2=ice,3=magnetic,4=corrupted
ice_slow=0
hz_rd=0 hz_md=0 hz_cd=0 hz_inm=0
-- time attack mode
is_ta=false
ta_time=0
ta_nodmg=true
mode_sel=1
-- gauntlet mode
is_gauntlet=false
g_round=0
g_timer=0
g_trans=0
g_nodmg=true
g_won=false
g_rnames={"radioactive","ice","magnetic","corrupted"}
g_rdesc={"fuel drain","rot. slow","attract pull","fast move"}
g_rcols={9,12,8,3}
-- endless mode
is_endless=false
e_timer=0
e_nodmg=true
-- modifier system
mod_defs={
 {"no powerups","pu disabled",8,1},
 {"2x speed","1.5x meteors",9,2},
 {"tiny rocks","smaller size",11,4},
 {"mirror","l/r flipped",12,8},
 {"fast spawn","1.5x freq",10,16},
 {"hard hazard","stronger fx",14,32},
 {"quick start","begin at lv3",13,64}
}
mod_offer={}
mod_active=0
mod_sel=1
mod_count=0
-- leaderboard (top 5)
lb_scores={}
lb_names={}
lb_gflag={}
lb_mflag={}
-- endless leaderboard (top 5)
elb_scores={}
elb_names={}
-- name entry state
ne_pos=1
ne_chars={1,1,1}
ne_rank=0
ne_timer=0

function pack_name(c)
 return c[1]*676+c[2]*26+c[3]
end
function unpack_name(n)
 local c1=flr(n/676)
 local c2=flr((n-c1*676)/26)
 local c3=n-c1*676-c2*26
 return chr(65+c1)..chr(65+c2)..chr(65+c3)
end
function load_lb()
 lb_scores={}
 lb_names={}
 lb_gflag={}
 lb_mflag={}
 local gf=flr(dget(29))
 local mf=flr(dget(41))
 for i=1,5 do
  local s=dget(11+i*2)
  local n=dget(12+i*2)
  if s>0 then
   add(lb_scores,s)
   add(lb_names,unpack_name(n))
  else
   add(lb_scores,0)
   add(lb_names,"---")
  end
  add(lb_gflag,band(gf,shl(1,i-1))>0)
  add(lb_mflag,band(mf,shl(1,i-1))>0)
 end
end
function save_lb()
 local gf,mf=0,0
 for i=1,5 do
  dset(11+i*2,lb_scores[i])
  dset(12+i*2,lb_names[i]=="---" and 0 or pack_name({
   ord(sub(lb_names[i],1,1))-65,
   ord(sub(lb_names[i],2,2))-65,
   ord(sub(lb_names[i],3,3))-65
  }))
  if lb_gflag[i] then gf=bor(gf,shl(1,i-1)) end
  if lb_mflag[i] then mf=bor(mf,shl(1,i-1)) end
 end
 dset(29,gf)
 dset(41,mf)
end
function any_rank(s,ls)
 for i=1,5 do
  if s>ls[i] then return i end
 end
 return 0
end
function load_elb()
 elb_scores={} elb_names={}
 for i=1,5 do
  local s=dget(29+i)
  local n=dget(34+i)
  add(elb_scores,s>0 and s or 0)
  add(elb_names,s>0 and unpack_name(n) or "---")
 end
end
function save_elb()
 for i=1,5 do
  dset(29+i,elb_scores[i])
  dset(34+i,elb_names[i]=="---" and 0 or pack_name({
   ord(sub(elb_names[i],1,1))-65,
   ord(sub(elb_names[i],2,2))-65,
   ord(sub(elb_names[i],3,3))-65
  }))
 end
end
function _init()
 cartdata(1)
 hiscore=dget(0)
 for i=1,16 do
  achv[i]=dget(i)>0
 end
 for i=17,22 do
  achv[i]=dget(i+6)>0
 end
 load_lb()
 load_elb()
 for i=1,40 do
  add(stars,{
   x=rnd(128),
   y=rnd(128),
   spd=0.2+rnd(0.8),
   col=rnd()>0.5 and 6 or 5
  })
 end
 _log("state:menu")
end

-- menu state
function update_menu()
 local inp=test_input()
 if inp&16>0 or inp&32>0 then
  state="difficulty_select"
  _log("state:difficulty_select")
 end
 if inp&8>0 then
  state="help"
  _log("state:help")
 end
end

function draw_menu()
 cls(0)
 draw_stars()
 local ty=20+sin(t()*0.3)*3
 print("\135 meteor dodge \135",16,ty,10)
 print("dodge the falling meteors!",10,40,7)
 for i=0,3 do
  local mx=20+i*28
  local my=60+sin(t()*0.5+i*0.25)*8
  draw_meteor(mx,my,flr(t()*4+i)%2)
 end
 print("\139\145 move left/right",28,80,6)
 print("collect power-ups!",28,90,12)
 if flr(t()*2)%2==0 then
  print("press \142/\151 to start",22,100,7)
 end
 print("\140 hazard help",36,108,5)
 -- mini leaderboard on menu
 if lb_scores[1]>0 then
  local mp=lbp(1)
  print(mp..lb_names[1].." "..lb_scores[1],36,118,9)
 elseif hiscore>0 then
  print("hi-score: "..hiscore,34,118,9)
 end
end

-- help/encyclopedia state
function update_help()
 if btnp(4) or btnp(5) then
  state="menu"
  _log("state:menu")
 end
end

function draw_help()
 cls(0)
 draw_stars()
 print("hazard encyclopedia",14,4,10)
 local hd={
  {"normal",8,10,"dodge meteors, earn pts"},
  {"radioactive",9,10,"shield costs 2x"},
  {"ice",12,7,"slows move, -25% nm dist"},
  {"magnetic",8,2,"pulls ship toward it"},
  {"corrupted",3,11,"bounces, 2x nm bonus"}
 }
 for i=1,5 do
  local h=hd[i]
  local y=16+(i-1)*20
  draw_meteor(6,y+2,flr(t()*3)%2,7,h[2],h[3])
  print(h[1],18,y,h[2])
  print(h[4],18,y+8,6)
 end
 print("\142/\151 back to menu",18,118,6)
end

-- difficulty select state
function update_difsel()
 if btnp(2) then diff_sel=max(1,diff_sel-1) end
 if btnp(3) then diff_sel=min(3,diff_sel+1) end
 if btnp(4) then
  _log("difficulty:"..diff_names[diff_sel])
  state="mode_select"
  mode_sel=1
  _log("state:mode_select")
 end
 if btnp(5) then
  state="menu"
  _log("state:menu")
 end
end

function draw_difsel()
 cls(0)
 draw_stars()
 print("select difficulty",22,16,10)
 local opts={
  {"easy","slower meteors, relaxed",11},
  {"normal","default challenge",7},
  {"hard","fast & brutal! 1.5x",8}
 }
 for i=1,3 do
  local y=36+(i-1)*24
  local sel=i==diff_sel
  local col=sel and opts[i][3] or 5
  if sel then
   rectfill(10,y-2,117,y+14,1)
   print("\139",4,y+2,col)
  end
  print(opts[i][1],18,y,col)
  print(opts[i][2],18,y+8,sel and 6 or 1)
 end
 print("\142 select  \151 back",22,112,6)
end

-- mode select state
function update_modesel()
 if btnp(2) then mode_sel=max(1,mode_sel-1) end
 if btnp(3) then mode_sel=min(4,mode_sel+1) end
 if btnp(4) then
  is_ta=mode_sel==2
  is_endless=mode_sel==3
  is_gauntlet=mode_sel==4
  local mn={"normal","time_attack","endless","gauntlet"}
  _log("mode:"..mn[mode_sel])
  -- set up modifier selection
  state="mod_select"
  mod_offer={}
  mod_active=0
  mod_sel=1
  mod_count=0
  local pool={1,2,3,4,5,6,7}
  for i=7,2,-1 do
   local j=1+flr(rnd(i))
   pool[i],pool[j]=pool[j],pool[i]
  end
  for i=1,4 do add(mod_offer,pool[i]) end
  _log("state:mod_select")
 end
 if btnp(5) then
  state="difficulty_select"
  _log("state:difficulty_select")
 end
end

function draw_modesel()
 cls(0)
 draw_stars()
 print("select mode",32,16,10)
 local opts={
  {"normal","classic survival",7},
  {"time attack","90s challenge! 1.5x",9},
  {"endless","infinite scaling!",12},
  {"hazard gauntlet","4 rounds+boss! 1.3x",8}
 }
 for i=1,4 do
  local y=26+(i-1)*18
  local sel=i==mode_sel
  local col=sel and opts[i][3] or 5
  if sel then
   rectfill(10,y-2,117,y+12,1)
   print("\139",4,y+1,col)
  end
  print(opts[i][1],18,y,col)
  print(opts[i][2],18,y+7,sel and 6 or 1)
 end
 print("["..diff_names[diff_sel].."]",44,102,5)
 print("\142 select  \151 back",22,114,6)
end

-- modifier select state
function update_modsel()
 if btnp(2) then mod_sel=max(1,mod_sel-1) end
 if btnp(3) then mod_sel=min(#mod_offer,mod_sel+1) end
 if btnp(4) then
  -- toggle modifier
  local md=mod_defs[mod_offer[mod_sel]]
  mod_active=bxor(mod_active,md[4])
  -- recount active mods
  mod_count=0
  local v=mod_active
  while v>0 do
   if v%2==1 then mod_count+=1 end
   v=flr(v/2)
  end
  sfx(2)
  _log("mod_toggle:"..md[1])
 end
 if btnp(5) then
  _log("modifiers:"..mod_active.." count="..mod_count)
  start_game()
 end
 if btnp(0) then
  state="mode_select"
  _log("state:mode_select")
 end
end

function draw_modsel()
 cls(0)
 draw_stars()
 print("challenge modifiers",14,6,10)
 print("\142 toggle  \151 go!",20,16,6)
 for i=1,#mod_offer do
  local mi=mod_offer[i]
  local md=mod_defs[mi]
  local y=26+(i-1)*20
  local sel=i==mod_sel
  local on=band(mod_active,md[4])>0
  if sel then rectfill(6,y-1,121,y+13,1) end
  -- checkbox
  if on then
   rectfill(8,y+2,14,y+8,md[3])
  else
   rect(8,y+2,14,y+8,5)
  end
  local nc=on and md[3] or (sel and 7 or 5)
  print(md[1],18,y+1,nc)
  print(md[2],18,y+8,sel and 6 or 1)
 end
 if mod_count>0 then
  print("+"..mod_count*10 .."%score bonus!",22,108,10)
 else
  print("select or skip \151",22,108,5)
 end
 print("\139 back",1,122,5)
end

function start_game()
 state="play"
 score=0
 time_alive=0
 go_timer=0
 ship_x=60
 ship_y=116
 meteors={}
 particles={}
 spawn_timer=0
 -- apply difficulty settings
 local ds={{50,0.8,1.0},{40,1.0,1.0},{30,1.2,1.5}}
 local d=ds[diff_sel]
 spawn_rate=d[1] meteor_speed=d[2] score_mult=d[3]
 diff_timer=0
 diff_level=1
 shake=0
 flash=0
 nm_flash=0
 nm_streak=0
 nm_best=0
 nm_last_bonus=0
 -- reset power-ups
 powerups={}
 shield_count=0
 slowmo_timer=0
 dblscore_timer=0
 pu_flash=0
 pu_flash_txt=""
 pu_collected=0
 -- reset boss wave
 boss_active=false
 boss_timer=0
 boss_flash=0
 last_boss_score=0
 boss_atk=1
 tele_timer=0
 tele_dur=0
 boss_vuln=0
 -- reset dodge combo
 dodge_combo=0
 dodge_best=0
 combo_flash=0
 combo_flash_txt=""
 -- reset per-run achievement trackers
 boss_waves=0
 bd_flash=0
 bd_flash_txt=""
 nm_count=0
 run_achv=0
 achv_flash=0
 -- reset hazard trackers
 ice_slow=0
 hz_rd=0 hz_md=0 hz_cd=0 hz_inm=0
 -- time attack setup
 ta_time=is_ta and 2700 or 0
 ta_nodmg=true
 if is_ta then score_mult*=1.5 end
 -- gauntlet setup
 g_round=is_gauntlet and 1 or 0
 g_timer=0
 g_trans=0
 g_nodmg=true
 g_won=false
 g_rdur=diff_sel==1 and 2700 or (diff_sel==3 and 1800 or 2250)
 if is_gauntlet then score_mult*=1.3 end
 -- endless setup
 e_timer=0
 e_nodmg=true
 if is_endless then score_mult=1.0 end
 -- apply modifier effects
 if band(mod_active,2)>0 then meteor_speed*=1.5 end
 if band(mod_active,16)>0 then spawn_rate=flr(spawn_rate*0.67) end
 if band(mod_active,64)>0 then
  diff_level=3
  meteor_speed+=0.15
  spawn_rate=max(15,spawn_rate-8)
 end
 if mod_count>0 then score_mult+=mod_count*0.1 end
 _log("state:play")
 if is_ta then _log("time_attack:start") end
 if is_gauntlet then _log("gauntlet:start round=1") end
 if is_endless then _log("endless:start") end
 if mod_count>0 then _log("modifiers:"..mod_active.." count="..mod_count) end
end

function check_achv(id)
 if achv[id] then return end
 achv[id]=true
 local slot=id>=17 and id+6 or id
 dset(slot,1)
 achv_flash=45
 achv_flash_txt=achv_names[id]
 run_achv+=1
 sfx(4)
 _log("achievement:"..achv_names[id])
end

-- play state
function update_play()
 -- gauntlet transition pause
 if is_gauntlet and g_trans>0 then
  g_trans-=1
  update_particles()
  upd_stars(0.5)
  if g_trans<=0 then
   g_round+=1
   g_timer=0
   if g_round>=5 then
    trigger_boss_wave()
    _log("gauntlet_boss_start")
   end
   _log("gauntlet_round:"..g_round)
  end
  anim_t+=1
  return
 end
 local inp=test_input()
 -- ship movement (ice hazard slows by 50%)
 local mspd=ice_slow>0 and 1.25 or 2.5
 -- mirror mode: swap left/right
 local ml,mr=1,2
 if band(mod_active,8)>0 then ml,mr=2,1 end
 if inp&ml>0 then ship_x-=mspd end
 if inp&mr>0 then ship_x+=mspd end
 ship_x=mid(0,ship_x,121)

 -- score multiplier
 local smul=dblscore_timer>0 and 2 or 1

 -- time attack countdown
 if is_ta then
  ta_time-=1
  if ta_time<=0 then
   ta_time=0
   if score>500 then check_achv(11) end
   if ta_nodmg then check_achv(12) end
   _log("time_attack_complete:score="..score)
   game_over()
   return
  end
 end

 -- update time and score
 time_alive+=1
 if time_alive%30==0 then
  score+=flr(smul*score_mult)
  if score%10==0 then
   _log("score:"..score)
  end
 end

 -- gauntlet round timer
 if is_gauntlet and g_round>=1 and g_round<=4 then
  g_timer+=1
  if g_timer>=g_rdur then
   if g_round==2 then check_achv(18) end
   g_trans=60
   _log("gauntlet_round_done:"..g_round)
  end
 end

 -- endless multiplier: +0.1x per 2 min, cap 3.0
 if is_endless then
  e_timer+=1
  if e_timer>=3600 then
   e_timer=0
   score_mult=min(3.0,score_mult+0.1)
   _log("endless_mult:"..score_mult)
  end
 end
 -- difficulty ramp (endless: faster)
 diff_timer+=1
 local ramp_int=is_endless and 120 or 180
 if diff_timer>=ramp_int then
  diff_timer=0
  local sr_min=is_endless and 6 or 10
  if spawn_rate>sr_min then
   spawn_rate-=(is_endless and 3 or 2)
  end
  meteor_speed+=(is_endless and 0.08 or 0.05)
  local new_lv=min(flr((meteor_speed-1)*10)+1,10)
  if new_lv>diff_level then
   sfx(0)
   _log("level_up:"..new_lv)
  end
  diff_level=new_lv
 end

 -- spawn meteors
 spawn_timer+=1
 if spawn_timer>=spawn_rate then
  spawn_timer=0
  spawn_meteor()
 end

 -- extra meteor spawn at high difficulty
 if score>30 and rnd()<0.02 then
  spawn_meteor()
 end
 if score>60 and rnd()<0.03 then
  spawn_meteor()
 end

 -- spawn power-ups (after 60 frames, 2% chance)
 if time_alive>60 and rnd()<0.02 then
  spawn_powerup()
 end

 -- boss wave trigger (endless: every 50 pts)
 if not boss_active then
  local bt=is_endless and 50 or 100
  local next_boss=last_boss_score+bt
  if score>=next_boss or (diff_level>=5 and score>=last_boss_score+flr(bt/2)) then
   last_boss_score=score
   trigger_boss_wave()
  end
 end
 -- telegraph countdown
 if tele_timer>0 then
  tele_timer-=1
  if tele_timer<=0 then
   execute_boss_attack()
  end
 end
 -- decay boss timer
 if boss_timer>0 then
  boss_timer-=1
  if boss_timer<=0 then
   boss_active=false
   boss_waves+=1
   if boss_waves>=5 then check_achv(5) end
   -- boss death fanfare
   local bpts=flr(100*score_mult)
   score+=bpts
   bd_flash=30
   bd_flash_txt="+"..(bpts).." boss!"
   bd_x=tele_x bd_y=40
   shake+=8
   sfx(6)
   for i=1,10 do
    local ang=i/10
    add(particles,{
     x=tele_x,y=40,
     dx=cos(ang)*2,dy=sin(ang)*2,
     life=20,col=10
    })
   end
   _log("boss_defeated:+"..bpts)
   _log("boss_survived:"..boss_waves)
   -- gauntlet victory
   if is_gauntlet and g_round>=5 then
    check_achv(19)
    if g_nodmg then check_achv(17) end
    g_won=true
    _log("gauntlet_complete")
    game_over()
    return
   end
  end
 end
 if boss_flash>0 then boss_flash-=1 end
 if boss_vuln>0 then boss_vuln-=1 end

 -- slowmo speed factor
 local spd_mul=slowmo_timer>0 and 0.5 or 1

 -- update meteors
 local scx=ship_x+3
 local scy=ship_y+3
 local got_near=false
 for m in all(meteors) do
  if m.dx then
   m.x+=m.dx*spd_mul
   m.y+=m.dy*spd_mul
  else
   m.y+=m.spd*spd_mul
   -- corrupted: horizontal drift & edge bounce
   if m.htype==4 and m.cdx then
    m.x+=m.cdx*spd_mul
    if m.x<0 or m.x>120 then m.cdx=-m.cdx end
   end
  end
  -- magnetic: pull ship toward meteor
  if m.htype==3 and m.y>0 and m.y<128 then
   local mdx=m.x+m.sz/2-(ship_x+3)
   local mpull=band(mod_active,32)>0 and 0.5 or 0.3
   if abs(mdx)<40 then ship_x+=sgn(mdx)*mpull end
  end
  -- ice: proximity slowdown
  if m.htype==2 and m.y>0 then
   local idx=abs(m.x+m.sz/2-scx)
   local idy=abs(m.y+m.sz/2-scy)
   if idx<12 and idy<12 then ice_slow=band(mod_active,32)>0 and 90 or 60 end
  end
  m.anim+=0.15
  -- trail particles
  if rnd()<0.3 then
   add(particles,{
    x=m.x+rnd(6),
    y=m.y,
    dx=rnd(1)-0.5,
    dy=-rnd(0.5),
    life=8+rnd(8),
    col=m.col2
   })
  end
  -- near-miss detection
  if not m.scored and m.y>ship_y+6 then
   m.scored=true
   -- dodge combo tracking
   dodge_combo+=1
   if dodge_combo>dodge_best then dodge_best=dodge_combo end
   check_combo_milestone()
   -- boss meteors: 5x dodge bonus (2x during vulnerability)
   if m.boss then
    local vmul=boss_vuln>0 and 2 or 1
    local bpts=flr(5*smul*score_mult*vmul)
    score+=bpts
    _log("boss_dodge:+"..bpts)
   end
   local dx=abs((m.x+m.sz/2)-scx)
   local dy=abs((m.y-m.spd*spd_mul)-scy)
   local dist=sqrt(dx*dx+dy*dy)
   -- ice reduces near-miss distance, others give bonus multipliers
   local nm_d=m.htype==2 and near_miss_dist*0.75 or near_miss_dist
   local hzmul=1
   if m.htype==1 then hzmul=1.2
   elseif m.htype==3 then hzmul=1.5
   elseif m.htype==4 then hzmul=2 end
   if dist<nm_d then
    got_near=true
    local bvmul=(m.boss and boss_vuln>0) and 2 or 1
    local bonus=max(1,flr((nm_d-dist)/3*hzmul))*smul*score_mult*bvmul
    nm_last_bonus=bonus
    score+=bonus
    nm_streak+=1
    -- hazard achievement tracking
    if m.htype==1 then hz_rd+=1 if hz_rd>=10 then check_achv(13) end end
    if m.htype==2 then hz_inm+=1 if hz_inm>=3 then check_achv(14) end end
    if m.htype==3 then hz_md+=1 if hz_md>=5 then check_achv(15) end end
    if m.htype==4 then hz_cd+=1 if hz_cd>=15 then check_achv(16) end end
    if nm_streak>nm_best then nm_best=nm_streak end
    nm_count+=1
    nm_flash=10
    sfx(nm_streak>=3 and 3 or 2)
    if nm_streak>=10 then check_achv(3) end
    if nm_count>=5 then check_achv(8) end
    for i=1,4 do
     add(particles,{
      x=scx,y=scy-4,
      dx=rnd(2)-1,dy=-1-rnd(1),
      life=12,col=10
     })
    end
    if nm_streak>=3 then
     _log("near_miss_streak:"..nm_streak)
    end
   end
  end
 end
 if not got_near and nm_flash<=0 then
  nm_streak=0
  hz_inm=0
 end

 -- remove off-screen meteors
 for i=#meteors,1,-1 do
  local mi=meteors[i]
  if mi.y>140 or mi.x<-20 or mi.x>148 then
   deli(meteors,i)
  end
 end

 -- update and collect power-ups (before collision)
 update_powerups()

 -- collision check
 for m in all(meteors) do
  if check_col(ship_x,ship_y,ship_w,6,
   m.x,m.y,m.sz,m.sz) then
   if shield_count>0 then
    -- shield absorbs hit (radioactive costs 2)
    local scost=m.htype==1 and 2 or 1
    shield_count=max(0,shield_count-scost)
    del(meteors,m)
    shake=3
    sfx(4)
    dodge_combo=0
    ta_nodmg=false
    g_nodmg=false
    e_nodmg=false
    _log("shield_absorb:remaining="..shield_count)
    _log("combo_reset:shield")
    for i=1,8 do
     add(particles,{
      x=ship_x+3,y=ship_y+3,
      dx=rnd(2)-1,dy=rnd(2)-1,
      life=12,col=12
     })
    end
   else
    game_over()
    return
   end
  end
 end

 update_particles()
 upd_stars(0.5)

 -- decay timers
 shake=dk(shake,0.5)
 flash=dk(flash)
 nm_flash=dk(nm_flash)
 slowmo_timer=dk(slowmo_timer)
 ice_slow=dk(ice_slow)
 dblscore_timer=dk(dblscore_timer)
 pu_flash=dk(pu_flash)
 combo_flash=dk(combo_flash)
 achv_flash=dk(achv_flash)
 bd_flash=dk(bd_flash)

 -- achievement checks
 if dodge_combo>=5 then check_achv(1) end
 if dodge_combo>=20 then check_achv(2) end
 if time_alive>=1800 then check_achv(6) end
 if diff_level>=8 then check_achv(9) end
 if score>=500 then check_achv(10) end
 if diff_sel==3 and score>=100 then check_achv(7) end
 -- endless achievements
 if is_endless then
  if time_alive>=9000 then check_achv(20) end
  if time_alive>=18000 then check_achv(21) end
 end

 anim_t+=1
end

-- power-up functions
function spawn_powerup()
 if band(mod_active,1)>0 then return end
 -- types: 1=shield(12), 2=slowmo(11), 3=dblpts(10), 4=rapid shield(13)
 local typs={
  {name="shield",col=12},
  {name="slow-mo",col=11},
  {name="2x pts",col=10},
  {name="2x shld",col=13}
 }
 -- weighted: shield 35%, slowmo 25%, dblpts 25%, rapid 15%
 local r=rnd()
 local ti=r<0.35 and 1 or (r<0.6 and 2 or (r<0.85 and 3 or 4))
 local tp=typs[ti]
 add(powerups,{
  x=rnd(120),y=-8,
  spd=0.5+rnd(0.3),
  typ=ti,col=tp.col,
  name=tp.name,anim=rnd(1)
 })
 _log("powerup_spawn:"..tp.name)
end

function update_powerups()
 for i=#powerups,1,-1 do
  local p=powerups[i]
  p.y+=p.spd
  p.anim+=0.05
  -- collect check (slightly larger hitbox for easier pickup)
  if check_col(ship_x,ship_y,ship_w,6,p.x-1,p.y-1,10,10) then
   collect_powerup(p)
   deli(powerups,i)
  elseif p.y>140 then
   deli(powerups,i)
  end
 end
end

function collect_powerup(p)
 if p.typ==1 then
  shield_count+=1
 elseif p.typ==2 then
  slowmo_timer=180
 elseif p.typ==3 then
  dblscore_timer=120
 elseif p.typ==4 then
  shield_count+=2
 end
 pu_flash=25
 pu_flash_txt="+"..p.name
 pu_collected+=1
 sfx(4)
 if dodge_combo>0 then
  _log("combo_reset:powerup")
 end
 dodge_combo=0
 _log("powerup_collect:"..p.name)
 if pu_collected>=10 then check_achv(4) end
 -- particle burst
 for i=1,6 do
  add(particles,{
   x=p.x+4,y=p.y+4,
   dx=rnd(2)-1,dy=-1-rnd(1),
   life=15,col=p.col
  })
 end
end

function spawn_meteor()
 local sz=6+flr(rnd(4))
 if band(mod_active,4)>0 then sz=max(3,sz-3) end
 -- hazard type selection based on difficulty
 local ht=0
 -- gauntlet: force hazard type per round
 if is_gauntlet and g_round>=1 and g_round<=4 then
  ht=g_round
 elseif diff_level>=2 then
  local r=rnd()
  if diff_level>=5 and r<0.15 then ht=4
  elseif diff_level>=4 and r<0.22 then ht=3
  elseif diff_level>=3 and r<0.28 then ht=2
  elseif r<0.33 then ht=1
  end
 end
 -- hazard colors: radio=9, ice=12, mag=8, corrupt=3
 local c1,c2=rnd()>0.5 and 8 or 9,rnd()>0.5 and 10 or 4
 if ht==1 then c1=9 c2=10
 elseif ht==2 then c1=12 c2=7
 elseif ht==3 then c1=8 c2=2
 elseif ht==4 then c1=3 c2=11 end
 add(meteors,{
  x=rnd(120),y=-sz,
  spd=meteor_speed+rnd(0.5)*(ht==4 and 1.3 or 1),
  sz=sz,anim=rnd(1),
  col=c1,col2=c2,
  scored=false,boss=false,htype=ht,
  cdx=ht==4 and rnd(1)-0.5 or nil
 })
end

-- spawn directional boss meteor
function spawn_boss_dir(x,y,dx,dy)
 local sz=10+flr(rnd(4))
 add(meteors,{
  x=x,y=y,dx=dx,dy=dy,
  spd=0,sz=sz,anim=rnd(1),
  col=2,col2=9,
  scored=y>ship_y,boss=true,htype=0
 })
end

-- trigger boss wave: start telegraph phase
function trigger_boss_wave()
 boss_active=true
 tele_dur=diff_sel==1 and 30 or (diff_sel==3 and 15 or 20)
 tele_timer=tele_dur
 tele_x=boss_atk==3 and 64 or 20+rnd(88)
 boss_flash=tele_dur
 sfx(5)
 _log("boss_telegraph:type="..boss_atk)
end

-- execute attack when telegraph completes
function execute_boss_attack()
 boss_timer=90
 shake=4
 flash=2
 local atk=boss_atk
 if atk==1 then
  -- burst: 8 meteors radiating from point
  for i=0,7 do
   local ang=i/8
   spawn_boss_dir(tele_x,0,cos(ang)*1.2,abs(sin(ang))*0.8+0.5)
  end
 elseif atk==2 then
  -- spiral: 6 meteors staggered across top
  for i=0,5 do
   local ang=i/6
   spawn_boss_dir(20+i*18,-8-i*6,cos(ang)*0.5,meteor_speed*0.8)
  end
 elseif atk==3 then
  -- ring: 8 meteors from edges toward center
  for i=0,7 do
   local ang=i/8
   local ox=64+cos(ang)*72
   local oy=64+sin(ang)*72
   spawn_boss_dir(ox,oy,(64-ox)*0.025,(64-oy)*0.025)
  end
 else
  -- aimed: 4 meteors toward player
  for i=0,3 do
   local sx=rnd(128)
   local dx=ship_x+3-sx
   local dy=ship_y+10
   local d=max(sqrt(dx*dx+dy*dy),1)
   spawn_boss_dir(sx,-10,dx/d*1.2,dy/d*1.2)
  end
 end
 boss_atk=boss_atk%4+1
 boss_vuln=10
 sfx(5)
 _log("boss_attack:"..atk)
 _log("boss:vulnerable")
end

-- combo milestones: 5x,10x,15x,20x
function check_combo_milestone()
 local dm={5,10,15,20}
 local db={10,25,50,100}
 local dc={10,9,8,14}
 for i=1,4 do
  if dodge_combo==dm[i] then
   local diff_m=diff_sel==3 and 1.2 or 1.0
   local pts=flr(db[i]*diff_m*score_mult)
   score+=pts
   combo_flash=30
   combo_flash_txt=dm[i].."x combo! +"..pts
   shake=i
   flash=i>=3 and i-1 or 0
   sfx(i>=3 and 5 or 3)
   -- particle burst
   for j=1,4+i*2 do
    local ang=rnd(1)
    add(particles,{
     x=ship_x+3,y=ship_y-4,
     dx=cos(ang)*1.5,dy=sin(ang)*1.5-1,
     life=15+i*3,col=dc[i]
    })
   end
   _log("combo_milestone:"..dm[i].."x pts="..pts)
  end
 end
end

function check_col(x1,y1,w1,h1,x2,y2,w2,h2)
 return x1+1<x2+w2-1 and x1+w1-1>x2+1
    and y1+1<y2+h2-1 and y1+h1-1>y2+1
end

function game_over()
 if is_gauntlet and not g_won then
  _log("gauntlet_failed:round="..g_round)
 end
 if is_endless and e_nodmg and time_alive>=9000 then
  check_achv(22)
 end
 _log("final_score:"..score)

 if score>hiscore then
  hiscore=score
  dset(0,hiscore)
  _log("new_hiscore:"..hiscore)
 end

 for i=1,30 do
  local ang=rnd(1)
  local spd=1+rnd(3)
  add(particles,{
   x=ship_x+3,
   y=ship_y+3,
   dx=cos(ang)*spd,
   dy=sin(ang)*spd,
   life=20+rnd(20),
   col=rnd()>0.5 and 10 or (rnd()>0.5 and 9 or 7)
  })
 end

 shake=8
 flash=4
 sfx(1)

 -- check leaderboard qualification
 ne_rank=any_rank(score,is_endless and elb_scores or lb_scores)
 go_timer=0
 if ne_rank>0 then
  state="name_entry"
  ne_pos=1
  ne_chars={1,1,1}
  ne_timer=0
  _log("state:name_entry rank="..ne_rank)
 else
  state="gameover"
  _log("state:gameover")
 end
end

function draw_play()
 local sx,sy=0,0
 if shake>0 then
  sx=rnd(shake)-shake/2
  sy=rnd(shake)-shake/2
 end
 camera(sx,sy)

 if flash>0 then
  cls(7)
 else
  cls(0)
 end

 draw_stars()

 -- draw meteors
 for m in all(meteors) do
  local cx,cy=m.x+m.sz\2,m.y+m.sz\2
  -- boss glow effect
  if m.boss then
   local gr=m.sz\2+2+sin(anim_t*0.03)*2
   circ(cx,cy,gr,boss_vuln>0 and 10 or 9)
   if boss_vuln>0 then
    circfill(cx,cy,m.sz\2+1,10)
   end
  end
  -- hazard aura effects
  if m.htype==1 then
   -- radioactive: pulsing glow
   circ(cx,cy,m.sz\2+1+sin(anim_t*0.04)*2,9)
  elseif m.htype==2 then
   -- ice: cold shimmer
   if anim_t%6<3 then circ(cx,cy,m.sz\2+1,12) end
  elseif m.htype==3 then
   -- magnetic: attraction rings
   circ(cx,cy,m.sz\2+3+sin(anim_t*0.05)*3,8)
  elseif m.htype==4 then
   -- corrupted: erratic flicker
   if rnd()<0.4 then circ(cx,cy,m.sz\2+rnd(3),3) end
  end
  draw_meteor(m.x,m.y,flr(m.anim)%2,m.sz,m.col,m.col2)
 end

 -- boss telegraph effect
 if tele_timer>0 then
  local prog=1-tele_timer/tele_dur
  local pc=flr(anim_t/2)%2==0 and 8 or 10
  if boss_atk==1 then
   -- burst: expanding cross at origin
   circ(tele_x,4,prog*20,pc)
   line(tele_x-prog*12,4,tele_x+prog*12,4,9)
   line(tele_x,4-prog*8,tele_x,4+prog*12,9)
  elseif boss_atk==2 then
   -- spiral: pulsing dots across top
   for i=0,5 do
    circ(20+i*18,-8+prog*12,2+prog*3,pc)
   end
  elseif boss_atk==3 then
   -- ring: expanding ring from center
   circ(64,64,10+prog*55,pc)
   circ(64,64,12+prog*55,9)
  else
   -- aimed: target reticle on player
   local r=6+sin(anim_t*0.08)*3
   circ(ship_x+3,ship_y,r,pc)
   line(ship_x+3,0,ship_x+3,ship_y-r,8)
  end
 end

 -- draw power-ups
 draw_powerups()

 -- draw particles
 draw_particles()

 -- draw ship
 if state=="play" then
  -- shield glow around ship
  if shield_count>0 then
   local gr=5+sin(anim_t*0.02)*2
   circ(ship_x+3,ship_y+3,gr,12)
   if shield_count>=2 then
    circ(ship_x+3,ship_y+3,gr+1,13)
   end
  end
  draw_ship(ship_x,ship_y)
 end

 -- slowmo border effect
 if slowmo_timer>0 then
  rect(0,0,127,127,11)
 end
 -- ice slow border effect
 if ice_slow>0 then
  rect(1,1,126,126,12)
 end

 camera(0,0)

 -- hud
 local hcol=is_endless and 12 or 7
 print("score:"..score,1,1,hcol)
 -- endless timer + multiplier
 if is_endless then
  local es=flr(time_alive/30)
  local em=flr(es/60)
  local ess=es%60
  local etstr=em..":"
  if ess<10 then etstr=etstr.."0" end
  etstr=etstr..ess
  print(etstr,90,1,12)
  -- show current multiplier
  local mtxt=score_mult.."x"
  print(mtxt,104,1,score_mult>=2 and 11 or 12)
 elseif is_ta then
  local secs=flr(ta_time/30)
  local mm=flr(secs/60)
  local ss=secs%60
  local tstr=mm..":"
  if ss<10 then tstr=tstr.."0" end
  tstr=tstr..ss
  local tc=secs>30 and 11 or (secs>10 and 10 or 8)
  print(tstr,104,1,tc)
  -- flash warning under 10s
  if secs<=10 and anim_t%4<2 then
   rect(0,0,127,127,8)
  end
 else
  print("hi:"..hiscore,90,1,6)
 end
 local dc=diff_sel==1 and 11 or (diff_sel==3 and 8 or 5)
 print(sub(diff_names[diff_sel],1,1),50,1,dc)
 print("lv"..diff_level,56,1,diff_level>=7 and 8 or 5)
 local spd_bar=min((meteor_speed-1)*20,30)
 rectfill(72,1,72+spd_bar,4,diff_level>=7 and 8 or 13)

 -- shield indicator
 if shield_count>0 then
  for i=1,min(shield_count,4) do
   circfill(1+i*6,9,2,12)
  end
 end

 -- modifier indicator
 if mod_count>0 then
  local mx=126
  for i=1,7 do
   if band(mod_active,mod_defs[i][4])>0 then
    pset(mx,9,mod_defs[i][3])
    pset(mx,10,mod_defs[i][3])
    mx-=2
   end
  end
 end

 -- boss wave indicator
 if boss_active or boss_flash>0 then
  if boss_vuln>0 then
   local vc=flr(anim_t/2)%2==0 and 10 or 7
   print("weak!",50,9,vc)
  else
   local bc=is_endless and (flr(anim_t/3)%2==0 and 12 or 6) or (flr(anim_t/3)%2==0 and 8 or 2)
   print("boss!",50,9,bc)
  end
 end

 -- active effect timers
 local ty=14
 if slowmo_timer>0 then
  local bw=flr(slowmo_timer/180*28)
  rectfill(1,ty,1+bw,ty+2,11)
  print("slow",31,ty,11)
  ty+=5
 end
 if dblscore_timer>0 then
  local bw=flr(dblscore_timer/120*28)
  rectfill(1,ty,1+bw,ty+2,10)
  print("2x",31,ty,10)
 end

 -- gauntlet round indicator
 if is_gauntlet then
  local rn=g_round<=4 and g_round or 5
  local rtxt=rn<=4 and "r"..rn..":"..g_rnames[rn] or "boss!"
  local rc=rn<=4 and g_rcols[rn] or 8
  print(rtxt,1,122,rc)
  if rn<=4 then
   local pct=min(g_timer/g_rdur,1)
   rectfill(1,118,1+pct*40,120,rc)
   rect(1,118,41,120,5)
  end
 end

 -- near-miss feedback
 if nm_flash>0 then
  local col=nm_streak>=3 and 10 or 9
  print("close! +"..nm_last_bonus,
   ship_x-6,ship_y-12,col)
  if nm_streak>=3 then
   print("x"..nm_streak.." streak!",
    ship_x-10,ship_y-20,10)
  end
 end

 -- power-up collection notification (centered top)
 if pu_flash>0 then
  local px=64-#pu_flash_txt*2
  local py=24+flr((25-pu_flash)/3)
  local c=pu_flash>15 and 7 or 6
  print(pu_flash_txt,px,py,c)
 end

 -- dodge combo counter (bottom-left)
 if dodge_combo>=3 then
  local cc=dodge_combo>=20 and 14 or
   (dodge_combo>=15 and 8 or
   (dodge_combo>=10 and 9 or
   (dodge_combo>=5 and 10 or 7)))
  print(dodge_combo.."x",1,121,cc)
  -- pulsing glow at milestones
  if dodge_combo>=5 and anim_t%8<4 then
   print(dodge_combo.."x",2,121,cc)
  end
 end

 -- combo milestone notification
 if combo_flash>0 then
  local cx=64-#combo_flash_txt*2
  local cy=40+flr((30-combo_flash)/3)
  local cc=combo_flash>20 and 10 or
   (combo_flash>10 and 9 or 5)
  print(combo_flash_txt,cx,cy,cc)
 end

 -- boss death fanfare popup
 if bd_flash>0 then
  local bx=bd_x-#bd_flash_txt*2
  local by=bd_y-flr((30-bd_flash)/2)
  local bc=bd_flash>20 and 10 or
   (bd_flash>10 and 9 or 5)
  print(bd_flash_txt,bx,by,bc)
 end

 -- achievement unlock notification
 if achv_flash>0 then
  local ay=32+flr((45-achv_flash)/4)
  local ac=achv_flash>30 and 10 or
   (achv_flash>15 and 9 or 5)
  rectfill(8,ay-1,119,ay+7,0)
  rect(8,ay-1,119,ay+7,ac)
  print("\135 "..achv_flash_txt.." \135",
   64-#achv_flash_txt*2-4,ay,ac)
 end

 -- gauntlet transition overlay
 if is_gauntlet and g_trans>0 then
  rectfill(10,30,117,98,0)
  rect(10,30,117,98,5)
  if g_round<4 then
   local nr=g_round+1
   print("round "..nr,44,38,7)
   print(g_rnames[nr],44,50,g_rcols[nr])
   print(g_rdesc[nr],36,62,6)
   print("get ready!",40,78,
    anim_t%8<4 and 7 or 5)
  else
   print("final boss!",36,46,8)
   print("survive the onslaught!",14,62,9)
   if anim_t%6<3 then
    rect(12,32,115,96,8)
   end
  end
 end
end

-- draw power-up items
function draw_powerups()
 for p in all(powerups) do
  local cx,cy=p.x+4,p.y+4
  local r=3+sin(p.anim)*0.5
  circfill(cx,cy,r,p.col)
  pset(cx-1,cy-1,7)
  -- pulsing glow ring
  if sin(p.anim*2)>0 then
   circ(cx,cy,r+1,7)
  end
 end
end

-- name entry state
function update_nameentry()
 ne_timer+=1
 if btnp(0) then ne_pos=max(1,ne_pos-1) end
 if btnp(1) then ne_pos=min(3,ne_pos+1) end
 if btnp(2) then
  ne_chars[ne_pos]=(ne_chars[ne_pos])%26+1
 end
 if btnp(3) then
  ne_chars[ne_pos]=(ne_chars[ne_pos]-2)%26+1
 end
 if btnp(5) then
  -- backspace: clear current char and move left
  ne_chars[ne_pos]=1
  ne_pos=max(1,ne_pos-1)
 end
 if btnp(4) then
  -- confirm name
  local name=chr(64+ne_chars[1])..chr(64+ne_chars[2])..chr(64+ne_chars[3])
  -- insert into leaderboard at rank
  local ls=is_endless and elb_scores or lb_scores
  local ln=is_endless and elb_names or lb_names
  for i=5,ne_rank+1,-1 do
   ls[i]=ls[i-1]
   ln[i]=ln[i-1]
   if not is_endless then
    lb_gflag[i]=lb_gflag[i-1]
    lb_mflag[i]=lb_mflag[i-1]
   end
  end
  ls[ne_rank]=score+10
  ln[ne_rank]=name
  if not is_endless then
   lb_gflag[ne_rank]=is_gauntlet
   lb_mflag[ne_rank]=mod_active>0
  end
  score+=10
  if score>hiscore then
   hiscore=score
   dset(0,hiscore)
  end
  if is_endless then save_elb() else save_lb() end
  sfx(4)
  _log("name_entered:"..name.." rank="..ne_rank)
  state="gameover"
  go_timer=0
  _log("state:gameover")
 end
 update_particles()
 shake=dk(shake,0.5)
 flash=dk(flash)
 upd_stars(0.2)
end

function draw_nameentry()
 cls(0)
 draw_stars()
 draw_particles()

 print("new high score!",26,10,10)
 print("score: "..score,42,20,7)
 print("rank #"..ne_rank,46,28,9)

 print("enter your name:",24,40,6)
 -- draw 3 letter boxes
 for i=1,3 do
  local bx=40+(i-1)*18
  local by=50
  local sel=i==ne_pos
  local c=sel and 7 or 5
  rect(bx,by,bx+12,by+12,c)
  if sel then
   print("\131",bx+3,by-7,10)
   print("\132",bx+3,by+14,10)
   if ne_timer%20<14 then
    rectfill(bx+1,by+1,bx+11,by+11,1)
   end
  end
  local ch=chr(64+ne_chars[i])
  print(ch,bx+3,by+3,sel and 10 or 7)
 end

 print("\142 confirm  \151 back",18,72,6)
 print("+10 bonus pts!",28,82,11)

 -- top 3 leaderboard preview
 local lbs=is_endless and elb_scores or lb_scores
 local lbn=is_endless and elb_names or lb_names
 if is_endless then print("[endless]",42,90,12) end
 local ly=94
 for i=1,3 do
  local c=lbs[i]>0 and 6 or 1
  print(i..". "..lbp(i)..lbn[i].." "..lbs[i],28,ly,c)
  ly+=7
 end
 print("\139\145 select  \131\132 letter",10,120,5)
end

-- gameover state
function update_gameover()
 go_timer+=1
 local inp=test_input()
 if go_timer>45 then
  if inp&16>0 then
   start_game()
  elseif inp&32>0 then
   state="mode_select"
   _log("state:mode_select")
  end
 end
 update_particles()
 shake=dk(shake,0.5)
 flash=dk(flash)
 achv_flash=dk(achv_flash)

 for m in all(meteors) do
  m.y+=0.2
 end

 upd_stars(0.2)
end

function draw_gameover()
 local sx,sy=0,0
 if shake>0 then
  sx=rnd(shake)-shake/2
  sy=rnd(shake)-shake/2
 end
 camera(sx,sy)

 cls(0)
 draw_stars()

 for m in all(meteors) do
  draw_meteor(m.x,m.y,flr(m.anim)%2,m.sz,m.col,m.col2)
 end

 draw_particles()

 camera(0,0)

 if is_ta then
  print("time attack",36,17,9)
 elseif is_endless then
  print("endless mode",34,17,12)
 elseif is_gauntlet then
  if g_won then
   print("gauntlet complete!",18,17,11)
  else
   local rtxt=g_round<=4 and "round "..g_round or "boss"
   print("fell at "..rtxt,30,17,8)
  end
 end
 print(g_won and "victory!" or "game over",
  g_won and 42 or 40,24,g_won and 11 or 8)
 print("score: "..score,42,36,7)
 print("hi-score: "..hiscore,34,44,
  score>=hiscore and 10 or 6)

 if score>=hiscore and score>0 then
  if flr(t()*3)%2==0 then
   print("new hi-score!",34,52,10)
  end
 end

 -- stats
 local dtxt="["..diff_names[diff_sel].."]"
 if is_ta then dtxt=dtxt.." ta"
 elseif is_endless then dtxt=dtxt.." end "..score_mult.."x"
 elseif is_gauntlet then dtxt=dtxt.." glt" end
 print(dtxt,is_endless and 28 or 44,52,is_endless and 12 or 5)
 local secs=flr(time_alive/30)
 print("survived:"..secs.."s lv:"..diff_level,22,59,5)
 local sy=66
 if nm_best>0 then
  print("streak:"..nm_best.."x",34,sy,9)
  sy+=7
 end
 if dodge_best>0 then
  print("combo:"..dodge_best.."x",34,sy,10)
  sy+=7
 end
 if pu_collected>0 then
  print("power-ups:"..pu_collected,34,sy,12)
  sy+=7
 end
 if mod_count>0 then
  print(mod_count.." mod(s) +"..(mod_count*10).."%",28,sy,14)
  sy+=7
 end

 -- leaderboard
 local lbs=is_endless and elb_scores or lb_scores
 local lbn=is_endless and elb_names or lb_names
 local ly=max(sy+2,86)
 local lbl=is_endless and "-- endless lb --" or "-- leaderboard --"
 print(lbl,22,ly,is_endless and 12 or 6)
 ly+=7
 for i=1,5 do
  if lbs[i]>0 then
   local c=ne_rank==i and 10 or 6
   print(i..". "..lbp(i)..lbn[i].." "..lbs[i],28,ly,c)
  else
   print(i..". ---",32,ly,1)
  end
  ly+=7
 end

 if go_timer>45 then
  if flr(t()*2)%2==0 then
   print("\142 retry  \151 change mode",10,120,7)
  end
 end
end

-- drawing helpers
function draw_ship(x,y)
 rectfill(x+2,y+1,x+4,y+5,12)
 pset(x+3,y,12)
 line(x,y+4,x+2,y+2,1)
 line(x+4,y+2,x+6,y+4,1)
 rectfill(x,y+4,x+1,y+5,1)
 rectfill(x+5,y+4,x+6,y+5,1)
 pset(x+3,y+2,10)
 if anim_t%4<2 then
  pset(x+2,y+6,9)
  pset(x+3,y+6,10)
  pset(x+4,y+6,9)
 else
  pset(x+3,y+6,8)
 end
end

function draw_meteor(x,y,frame,sz,col,col2)
 sz=sz or 7
 col=col or 8
 col2=col2 or 10
 local r=sz\2
 if frame==0 then
  circfill(x+r,y+r,r,col)
  pset(x+r-1,y+r-1,col2)
  pset(x+r+1,y+r+1,5)
 else
  circfill(x+r,y+r,r,col)
  pset(x+r+1,y+r-1,col2)
  pset(x+r-1,y+r+1,5)
  pset(x+r,y+r-1,col2)
 end
 pset(x+r-1,y+1,7)
end

function draw_stars()
 for s in all(stars) do
  pset(s.x,s.y,s.col)
 end
end

function update_particles()
 for i=#particles,1,-1 do
  local p=particles[i]
  p.x+=p.dx
  p.y+=p.dy
  p.life-=1
  if p.life<=0 then
   deli(particles,i)
  end
 end
end

function draw_particles()
 for p in all(particles) do
  if p.life>5 then
   pset(p.x,p.y,p.col)
  elseif p.life>2 then
   pset(p.x,p.y,5)
  else
   pset(p.x,p.y,1)
  end
 end
end

-- main loops
function _update()
 if state=="menu" then update_menu()
 elseif state=="help" then update_help()
 elseif state=="difficulty_select" then update_difsel()
 elseif state=="mode_select" then update_modesel()
 elseif state=="mod_select" then update_modsel()
 elseif state=="play" then update_play()
 elseif state=="name_entry" then update_nameentry()
 elseif state=="gameover" then update_gameover()
 end
end

function _draw()
 if state=="menu" then draw_menu()
 elseif state=="help" then draw_help()
 elseif state=="difficulty_select" then draw_difsel()
 elseif state=="mode_select" then draw_modesel()
 elseif state=="mod_select" then draw_modsel()
 elseif state=="play" then draw_play()
 elseif state=="name_entry" then draw_nameentry()
 elseif state=="gameover" then draw_gameover()
 end
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000aaaa00000aaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000aa0000000aa000aaa0000aaa000aa00aaa000aaa0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000a0a000000a0a00a0000000a00a00aa00a0a00a0000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000a0a00aaa0a0a00aaa00000a00a00a000a0a00a0aa0000000000000000000080000000000000000000000000000000000000000000
00000000000000000000000a0a00000a0a00a0a00000a0a000a000a0a00a00a0000000000000000000089000000000000000000000000000000000000000000
000000000000000000000000aa0000aa0a00aaa00000aaa00aaa00aaa000aaa0000000000000000000088a00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000a5000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
00000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000050000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000089a0
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008850
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008a70
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
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000cc000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c0ca0000000c0000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001c00c0000001100c000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110011000001110011a0
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001110011000001110011a0
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a00a0000000000000a0
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

__sfx__
000200001505015050150401503015020150101500015000150001500015000150001500015000150001500015000150001500015000150001500015000150001500015000150001500015000150001500015000150000
001000002a6502a6402a6302a6202a6102a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a6002a600
000400002965029640296202960029600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001d0501d0401d0301d0201d010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c0501e050200502204024030260202801028000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500001505018050200502405028050240502005018050150500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800001505018050200502405028050300503405038050340503005028050240502005018050150500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
