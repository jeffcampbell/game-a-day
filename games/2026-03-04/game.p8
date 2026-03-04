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
function ap(x,y,dx,dy,l,c)
 add(particles,{x=x,y=y,dx=dx,dy=dy,life=l,col=c})
end
function ds(e,n,h) return diff_sel==1 and e or (diff_sel==3 and h or n) end
function fmt_t(f)
 local s=flr(f/30)
 local m=flr(s/60)
 s=s%60
 return m..":"..( s<10 and "0" or "")..s
end

-- game state
state="menu"
score=0
hiscore=0
time_alive=0
go_timer=0
ship_x=60
ship_y=116
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
score_mult=1.0
-- near-miss system
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
inv_timer=0
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
-- boss type variety: inferno(1),void(2),crystal(3)
boss_type=1
bt_cols={{8,10},{2,9},{11,12}} -- {main,accent} per type
bt_spd={1.0,1.2,0.8} -- speed mult
bt_sz={0,0,3} -- size bonus
-- dodge combo system
dodge_combo=0
dodge_best=0
combo_flash=0
combo_flash_txt=""
-- achievement system
achv={}
achv_flash=0
achv_flash_txt=""
boss_waves=0
boss_tier=0 boss_n=0
-- boss death fanfare
dbl_atk=false
bd_flash=0
bd_flash_txt=""
bd_x=64
nm_count=0
-- hazard meteor system
-- 0=normal,1=radioactive,2=ice,3=magnetic,4=corrupted,5=splitter,6=phantom
ice_slow=0
hz_ct={0,0,0,0,0} sp_frag=0
ph_dodged=0
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
g_rnames={"rad","ice","mag","corrupt"}
g_rcols={9,12,8,3}
-- endless mode
is_endless=false
e_timer=0
e_nodmg=true
-- modifier system
mod_defs={
 {"no pu","pu off",8,1},
 {"2x spd","fast met",9,2},
 {"tiny","smaller",11,4},
 {"mirror","l/r flip",12,8},
 {"fast sp","1.5x freq",10,16},
 {"hard hz","strong fx",14,32},
 {"quick","start lv3",13,64}
}
mod_offer={}
mod_active=0
mod_sel=1
mod_count=0
-- leaderboard (top 5 per difficulty)
lb_scores={}
lb_names={}
lb_bs={42,13,52,30}
lb_vd=2
elb_scores={}
elb_names={}
-- name entry state
ne_pos=1
ne_chars={1,1,1}
ne_rank=0

function pkn(n)
 return (ord(sub(n,1,1))-65)*676+(ord(sub(n,2,2))-65)*26+ord(sub(n,3,3))-65
end
function unpack_name(n)
 local c1=flr(n/676)
 local c2=flr((n-c1*676)/26)
 local c3=n-c1*676-c2*26
 return chr(65+c1)..chr(65+c2)..chr(65+c3)
end
function lb_load(b,ss,sn)
 for i=1,5 do
  local s=dget(b+i-1)
  ss[i]=s>0 and s or 0
  sn[i]=s>0 and unpack_name(dget(b+4+i)) or "---"
 end
end
function lb_save(b,ss,sn)
 for i=1,5 do
  dset(b+i-1,ss[i])
  dset(b+4+i,sn[i]=="---" and 0 or pkn(sn[i]))
 end
end
function load_dlb(d)
 lb_scores={} lb_names={}
 lb_load(lb_bs[d],lb_scores,lb_names)
end
function load_elb()
 elb_scores={} elb_names={}
 lb_load(lb_bs[4],elb_scores,elb_names)
end
function g_ls() return is_endless and elb_scores or lb_scores end
function g_ln() return is_endless and elb_names or lb_names end
function _init()
 cartdata(1)
 hiscore=dget(0)
 for i=1,16 do
  achv[i]=dget(i)>0
 end
 for i=17,23 do
  achv[i]=dget(i+6)>0
 end
 load_dlb(diff_sel)
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
 end
 if inp&8>0 then
  state="help"
 end
 if inp&4>0 then
  lb_vd=diff_sel
  load_dlb(lb_vd)
  state="lb_view"
  _log("state:lb_view")
 end
end

function draw_menu()
 cls(0)
 draw_stars()
 local ty=20+sin(t()*0.3)*3
 print("\135 meteor dodge \135",16,ty,10)
 print("dodge the falling meteors!",10,40,7)
 draw_meteor(64,60+sin(t()*0.5)*6,flr(t()*4)%2,7,8,10)
 print("\139\145 move left/right",28,80,6)
 print("collect power-ups!",28,90,12)
 if flr(t()*2)%2==0 then
  print("press \142/\151 to start",22,100,7)
 end
 print("\131 scores  \132 help",24,108,5)
 -- mini leaderboard on menu
 if lb_scores[1]>0 then
  print(lb_names[1].." "..lb_scores[1],36,118,9)
 elseif hiscore>0 then
  print("hi-score: "..hiscore,34,118,9)
 end
end

-- help/encyclopedia state
function update_help()
 if btnp(4) or btnp(5) then
  state="menu"
 end
end

function draw_help()
 cls(0) draw_stars()
 print("hazard types",28,6,10)
 print("norm rad ice mag",10,18,7)
 print("corrupt split phantom",10,28,7)
 print("\142/\151 back",36,118,6)
end

-- difficulty select state
function update_difsel()
 if btnp(2) then diff_sel=max(1,diff_sel-1) end
 if btnp(3) then diff_sel=min(3,diff_sel+1) end
 if btnp(4) then
  state="mode_select"
  mode_sel=1
 end
 if btnp(5) then
  state="menu"
 end
end

function draw_difsel()
 cls(0) draw_stars()
 print("select difficulty",22,16,10)
 local on=split("easy,normal,hard") local od=split("slow,default,fast! 1.5x")
 local oc={11,7,8}
 for i=1,3 do
  local y=36+(i-1)*24
  local sel=i==diff_sel
  local c=sel and oc[i] or 5
  if sel then rectfill(10,y-2,117,y+14,1) print("\139",4,y+2,c) end
  print(on[i],18,y,c)
  print(od[i],18,y+8,sel and 6 or 1)
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
 end
 if btnp(5) then
  state="difficulty_select"
 end
end

function draw_modesel()
 cls(0) draw_stars()
 print("select mode",32,16,10)
 local on=split("normal,time attack,endless,hazard gauntlet")
 local od=split("classic,90s! 1.5x,infinite!,4 rnds+boss! 1.3x")
 local oc={7,9,12,8}
 for i=1,4 do
  local y=26+(i-1)*18
  local sel=i==mode_sel
  local c=sel and oc[i] or 5
  if sel then rectfill(10,y-2,117,y+12,1) print("\139",4,y+1,c) end
  print(on[i],18,y,c)
  print(od[i],18,y+7,sel and 6 or 1)
 end
 print("["..lb_dnames[diff_sel].."]",44,102,5)
 print("\142 select  \151 back",22,114,6)
end

-- modifier select state
function update_modsel()
 if btnp(2) then mod_sel=max(1,mod_sel-1) end
 if btnp(3) then mod_sel=min(#mod_offer,mod_sel+1) end
 if btnp(4) then
  -- toggle modifier
  local md=mod_defs[mod_offer[mod_sel]]
  if band(mod_active,md[4])>0 then mod_count-=1 else mod_count+=1 end
  mod_active=bxor(mod_active,md[4])
  sfx(2)
 end
 if btnp(5) then
  start_game()
 end
 if btnp(0) then
  state="mode_select"
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
 load_dlb(diff_sel)
 state="play"
 ship_x=60
 meteors,particles,powerups={},{},{}
 score,time_alive,go_timer,spawn_timer,shake,flash,diff_timer=0,0,0,0,0,0,0
 nm_flash,nm_streak,nm_best,nm_last_bonus=0,0,0,0
 shield_count,slowmo_timer,dblscore_timer,pu_flash,pu_collected,inv_timer=0,0,0,0,0,0
 boss_timer,boss_flash,last_boss_score,tele_timer,tele_dur,boss_vuln=0,0,0,0,0,0
 dodge_combo,dodge_best,combo_flash=0,0,0
 boss_waves,boss_tier,boss_n,bd_flash,nm_count,achv_flash=0,0,0,0,0,0
 ice_slow,sp_frag,ph_dodged,g_timer,g_trans,e_timer=0,0,0,0,0,0
 boss_active,shld_burst,dbl_atk,g_won=false,false,false,false
 ta_nodmg,g_nodmg,e_nodmg=true,true,true
 pu_flash_txt,combo_flash_txt,bd_flash_txt="","",""
 boss_atk,boss_type,diff_level=1,1,1
 hz_ct={0,0,0,0,0}
 -- apply difficulty settings
 local ds={{50,0.8,1.0},{40,1.0,1.0},{30,1.2,1.5}}
 local d=ds[diff_sel]
 spawn_rate=d[1] meteor_speed=d[2] score_mult=d[3]
 -- time attack setup
 ta_time=is_ta and 1500 or 0
 if is_ta then score_mult*=1.5 end
 -- gauntlet setup
 g_round=is_gauntlet and 1 or 0
 if is_gauntlet then score_mult*=1.3 end
 -- endless setup
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
end

function check_achv(id)
 if achv[id] then return end
 achv[id]=true
 dset(id>=17 and id+6 or id,1)
 achv_flash=45
 achv_flash_txt="achv #"..id
 sfx(4)
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
   end
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
   game_over()
   return
  end
 end

 -- update time and score
 time_alive+=1
 if time_alive%30==0 then
  score+=flr(smul*score_mult)
 end

 -- gauntlet round timer
 if is_gauntlet and g_round>=1 and g_round<=4 then
  g_timer+=1
  if g_timer>=ds(1500,2250,1800) then
   if g_round==2 then check_achv(18) end
   g_trans=60
  end
 end

 -- endless multiplier: +0.1x per 2 min, cap 3.0
 if is_endless then
  e_timer+=1
  if e_timer>=3600 then
   e_timer=0
   score_mult=min(3.0,score_mult+0.1)
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

 -- boss wave trigger: every 50 pts, alternate mini/major
 if not boss_active then
  if score>=last_boss_score+50 or (diff_level>=5 and score>=last_boss_score+25) then
   last_boss_score=score
   boss_n+=1
   boss_tier=boss_n%2==1 and 1 or 2
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
   local mn=boss_tier==1
   if not mn then boss_waves+=1 if boss_waves>=5 then check_achv(5) end end
   local bp=mn and 25 or flr(100*score_mult)
   score+=bp
   bd_flash=mn and 15 or 30
   bd_flash_txt="+"..bp..(mn and " mini!" or " boss!")
   bd_x=tele_x
   shake+=mn and 3 or 8
   sfx(mn and 2 or 6)
   local bc=bt_cols[boss_type]
   local pn=mn and 5 or 10
   for i=1,pn do local a=i/pn ap(tele_x,40,cos(a)*2,sin(a)*2,20,i%2==0 and bc[1] or bc[2]) end
   -- gauntlet victory
   if is_gauntlet and g_round>=5 then
    check_achv(19)
    if g_nodmg then check_achv(17) end
    g_won=true
    game_over()
    return
   end
  end
 end
 if boss_flash>0 then boss_flash-=1 end
 if boss_vuln>0 then boss_vuln-=1 end
 if boss_vuln>0 and anim_t%2==0 then for m in all(meteors) do if m.boss then ap(m.x+rnd(m.sz),m.y+rnd(m.sz),rnd(2)-1,-rnd(1),8,10) end end end

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
   ap(m.x+rnd(6),m.y,rnd(1)-0.5,-rnd(0.5),8+rnd(8),m.col2)
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
   end
   local dx=abs((m.x+m.sz/2)-scx)
   local dy=abs((m.y-m.spd*spd_mul)-scy)
   local dist=sqrt(dx*dx+dy*dy)
   local nm_d=m.htype==2 and 9 or 12
   local hzm={1.2,1,1.5,2,1,1.3}
   local hzmul=m.htype>0 and hzm[m.htype] or 1
   if dist<nm_d then
    got_near=true
    local bvmul=(m.boss and boss_vuln>0) and 2 or 1
    local bonus=max(1,flr((nm_d-dist)/3*hzmul))*smul*score_mult*bvmul
    nm_last_bonus=bonus
    score+=bonus
    nm_streak+=1
    -- hazard achievement tracking
    if m.htype>=1 and m.htype<=5 then
     hz_ct[m.htype]+=1
     local ht={10,3,5,15,8}
     if hz_ct[m.htype]>=ht[m.htype] then check_achv(12+m.htype) end
    end
    if m.htype==6 then ph_dodged+=1 end
    -- splitter: spawn fragments on near-miss
    if m.htype==5 then
     for j=1,2+flr(rnd(2)) do
      add(meteors,{x=m.x+rnd(24)-12,y=-rnd(12),spd=meteor_speed+rnd(0.3),sz=3+flr(rnd(2)),anim=0,col=14,col2=7,scored=false,boss=false,htype=0,frag=true})
     end shake=2 sfx(3)
    end
    if m.frag then sp_frag+=1 if sp_frag>=10 then check_achv(23) end end
    if nm_streak>nm_best then nm_best=nm_streak end
    nm_count+=1
    nm_flash=10
    sfx(nm_streak>=3 and 3 or 2)
    if nm_streak>=10 then check_achv(3) end
    if nm_count>=5 then check_achv(8) end
    for i=1,4 do
     ap(scx,scy-4,rnd(2)-1,-1-rnd(1),12,10)
    end
   end
  end
 end
 if not got_near and nm_flash<=0 then
  nm_streak=0
  hz_ct[2]=0
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
  if check_col(ship_x,ship_y,7,6,
   m.x,m.y,m.sz,m.sz) then
   if inv_timer>0 then
    -- invincibility: destroy meteor, award points
    del(meteors,m)
    score+=5
    for i=1,4 do
     ap(m.x+4,m.y+4,rnd(2)-1,rnd(2)-1,10,11)
    end
   elseif shield_count>0 then
    -- shield absorbs hit (radioactive costs 2)
    local scost=(m.htype==1 or m.htype==6) and 2 or 1
    shield_count=max(0,shield_count-scost)
    -- shield burst: destroy nearby meteors (only with burst power-up)
    if shld_burst then
     shld_burst=false
     for m2 in all(meteors) do
      if m2!=m then
       local dx,dy=m2.x-m.x,m2.y-m.y
       if dx*dx+dy*dy<900 then
        del(meteors,m2)
        score+=10
        for i=1,4 do
         ap(m2.x+4,m2.y+4,rnd(2)-1,rnd(2)-1,8,14)
        end
       end
      end
     end
    end
    del(meteors,m)
    shake=3
    sfx(4)
    dodge_combo=0
    ta_nodmg=false
    g_nodmg=false
    e_nodmg=false
    for i=1,8 do
     ap(ship_x+3,ship_y+3,rnd(2)-1,rnd(2)-1,12,12)
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
 inv_timer=dk(inv_timer)
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
pu_data=split("shield,12,slow,11,2x,10,2xsh,13,inv,11,sbst,14,bomb,10")
function spawn_powerup()
 if band(mod_active,1)>0 then return end
 local wt={25,45,65,80,85,93,100}
 local r=flr(rnd(100)) local ti=1
 for i=1,7 do if r<wt[i] then ti=i break end end
 local bi=(ti-1)*2
 add(powerups,{x=rnd(120),y=-8,spd=0.5+rnd(0.3),typ=ti,col=pu_data[bi+2]+0,name=pu_data[bi+1],anim=rnd(1)})
end

function update_powerups()
 for i=#powerups,1,-1 do
  local p=powerups[i]
  p.y+=p.spd
  p.anim+=0.05
  -- collect check (slightly larger hitbox for easier pickup)
  if check_col(ship_x,ship_y,7,6,p.x-1,p.y-1,10,10) then
   collect_powerup(p)
   deli(powerups,i)
  elseif p.y>140 then
   deli(powerups,i)
  end
 end
end

function collect_powerup(p)
 local t=p.typ
 if t==1 then shield_count+=1
 elseif t==2 then slowmo_timer=180
 elseif t==3 then dblscore_timer=120
 elseif t==4 then shield_count+=2
 elseif t==5 then inv_timer=150
 elseif t==6 then shield_count=max(shield_count,1) shld_burst=true
 elseif t==7 then score+=flr(50*score_mult*ds(0.8,1,1.5))
 end
 _log("powerup:"..p.name)
 pu_flash=25 pu_flash_txt="+"..p.name
 pu_collected+=1 sfx(4) dodge_combo=0
 if pu_collected>=10 then check_achv(4) end
 for i=1,6 do ap(p.x+4,p.y+4,rnd(2)-1,-1-rnd(1),15,p.col) end
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
 -- splitter: large meteors at diff 3+
 if ht==0 and sz>=8 then
  local sp=diff_level>=5 and 0.35 or (diff_level>=3 and 0.2 or 0)
  if rnd()<sp then ht=5 end
 end
 -- phantom: diff 4+ (slower, shield-costly)
 if ht==0 and diff_level>=4 and rnd()<(diff_level>=5 and 0.18 or 0.1) then ht=6 end
 -- hazard colors
 local hc={{9,10},{12,7},{8,2},{3,11},{14,7},{2,13}}
 local c1,c2=rnd()>0.5 and 8 or 9,rnd()>0.5 and 10 or 4
 if ht>0 then c1=hc[ht][1] c2=hc[ht][2] end
 add(meteors,{
  x=rnd(120),y=-sz,
  spd=(meteor_speed+rnd(0.5)*(ht==4 and 1.3 or 1))*(ht==6 and 0.85 or 1),
  sz=sz,anim=rnd(1),
  col=c1,col2=c2,
  scored=false,boss=false,htype=ht,
  cdx=ht==4 and rnd(1)-0.5 or nil
 })
end

function spawn_boss_dir(x,y,dx,dy)
 local mn=boss_tier==1
 local bc=mn and {10,7} or bt_cols[boss_type]
 local sm=mn and 1.1 or bt_spd[boss_type]
 local sz=mn and 7+flr(rnd(3)) or 10+flr(rnd(4))+bt_sz[boss_type]
 add(meteors,{x=x,y=y,dx=dx*sm,dy=dy*sm,spd=0,sz=sz,anim=rnd(1),col=bc[1],col2=bc[2],scored=y>ship_y,boss=true,htype=0})
end

function trigger_boss_wave()
 boss_active=true
 boss_type=boss_tier==2 and flr(score/100)%3+1 or 1
 tele_dur=ds(30,20,15)
 if boss_tier==1 then tele_dur=flr(tele_dur*0.7) boss_atk=rnd()<0.6 and 1 or 4
 elseif diff_sel!=2 then
  local r=flr(rnd(4))+1
  if diff_sel==1 and r>2 and rnd()<0.5 then r=flr(rnd(2))+1
  elseif diff_sel==3 and r<3 and rnd()<0.5 then r=flr(rnd(2))+3 end
  boss_atk=r
 end
 tele_timer=tele_dur tele_x=boss_atk==3 and 64 or 20+rnd(88)
 boss_flash=tele_dur sfx(5) _log("boss")
end

function execute_boss_attack()
 local mn=boss_tier==1
 local pc=ds(0.7,1,1.5)
 boss_timer=flr((mn and 45 or 90)*ds(1.3,1,0.67))
 shake=mn and 2 or 4
 flash=2
 if boss_atk==1 then
  local n=flr((mn and 4 or 7)*pc)
  for i=0,n do local a=i/(n+1) spawn_boss_dir(tele_x,0,cos(a)*1.2,abs(sin(a))*0.8+0.5) end
 elseif boss_atk==2 then
  for i=0,5 do local a=i/6 spawn_boss_dir(20+i*18,-8-i*6,cos(a)*0.5,meteor_speed*0.8) end
 elseif boss_atk==3 then
  local n=flr(7*pc)
  for i=0,n do local a=i/(n+1) local ox,oy=64+cos(a)*72,64+sin(a)*72 spawn_boss_dir(ox,oy,(64-ox)*0.025,(64-oy)*0.025) end
 else
  local n=flr((mn and 1 or 3)*pc)
  for i=0,n do local sx=rnd(128) local dx,dy=ship_x+3-sx,ship_y+10 local d=max(sqrt(dx*dx+dy*dy),1) spawn_boss_dir(sx,-10,dx/d*1.2,dy/d*1.2) end
 end
 boss_atk=boss_atk%4+1
 boss_vuln=ds(15,10,7)
 -- hard mode double attack (30% chance)
 if diff_sel==3 and not dbl_atk and rnd()<0.3 then
  dbl_atk=true
  tele_timer=8 tele_dur=8
  tele_x=boss_atk==3 and 64 or 20+rnd(88)
  _log("boss_dbl")
 else
  dbl_atk=false
 end
 sfx(5)
end

-- combo milestones: 5x,10x,15x,20x
function check_combo_milestone()
 local cm={5,10,10, 10,25,9, 15,50,8, 20,100,14}
 for i=0,3 do
  local b=i*3
  if dodge_combo==cm[b+1] then
   local pts=flr(cm[b+2]*(diff_sel==3 and 1.2 or 1)*score_mult)
   score+=pts
   combo_flash=30
   combo_flash_txt=cm[b+1].."x combo! +"..pts
   shake=i+1
   sfx(i>=2 and 5 or 3)
   ap(ship_x+3,ship_y-4,0,-1,15,cm[b+3])
  end
 end
end

function check_col(x1,y1,w1,h1,x2,y2,w2,h2)
 return x1+1<x2+w2-1 and x1+w1-1>x2+1
    and y1+1<y2+h2-1 and y1+h1-1>y2+1
end

function game_over()
 if is_endless and e_nodmg and time_alive>=9000 then
  check_achv(22)
 end
 _log("gameover")

 if score>hiscore then
  hiscore=score
  dset(0,hiscore)
 end

 local dc={10,9,7}
 for i=1,30 do
  local a=rnd(1) local sp=1+rnd(3)
  ap(ship_x+3,ship_y+3,cos(a)*sp,sin(a)*sp,20+rnd(20),dc[1+flr(rnd(3))])
 end

 shake=8
 flash=4
 sfx(1)

 -- check leaderboard qualification
 ne_rank=0
 local _r=g_ls()
 for i=1,5 do if score>_r[i] then ne_rank=i break end end
 go_timer=0
 if ne_rank>0 then
  state="name_entry"
  ne_pos=1
  ne_chars={1,1,1}
 else
  state="gameover"
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
   circ(cx,cy,gr,boss_vuln>0 and 10 or m.col2)
   if boss_vuln>0 then
    circfill(cx,cy,m.sz\2+1,10)
    circ(cx,cy,gr+4+sin(anim_t*0.08)*3,7)
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
  elseif m.htype==5 then
   circ(cx,cy,m.sz\2+2+sin(anim_t*0.06)*2,14)
  elseif m.htype==6 then
   -- phantom: pulsing ghost effect
   if anim_t%4<2 then circ(cx,cy,m.sz\2+2,2) end
  end
  draw_meteor(m.x,m.y,flr(m.anim)%2,m.sz,m.col,m.col2)
 end

 -- boss telegraph effect (difficulty-colored)
 if tele_timer>0 then
  local pg=1-tele_timer/tele_dur
  local tc=ds(11,7,8)
  local tc2=ds(7,6,14)
  local pc=flr(anim_t/2)%2==0 and tc or tc2
  if boss_atk==1 then circ(tele_x,4,pg*20,pc) line(tele_x-pg*14,4,tele_x+pg*14,4,tc) line(tele_x,4-pg*10,tele_x,4+pg*14,tc) if pg>0.5 then circfill(tele_x,4,2+sin(anim_t*0.1)*2,pc) end
  elseif boss_atk==2 then for i=0,5 do local a=pg*0.3+i/6 circ(tele_x+cos(a)*pg*16,6,2+pg*3,pc) end
  elseif boss_atk==3 then circ(64,64,10+pg*55,pc) circ(64,64,12+pg*55,tc2) if pg>0.3 then circ(64,64,pg*30,tc) end
  else circ(ship_x+3,ship_y,6+sin(anim_t*0.08)*3,pc) line(ship_x+3,0,ship_x+3,ship_y-8,tc) if pg>0.4 then line(ship_x,ship_y-12,ship_x+3,ship_y-7,pc) line(ship_x+6,ship_y-12,ship_x+3,ship_y-7,pc) end
  end
 end

 -- draw power-ups
 for p in all(powerups) do
  local cx,cy=p.x+4,p.y+4
  circfill(cx,cy,3+sin(p.anim)*0.5,p.col)
  pset(cx-1,cy-1,7)
 end

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
  -- invincibility flash
  if inv_timer>0 and flr(anim_t)%2==0 then
   circfill(ship_x+3,ship_y+3,6,11)
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
  print(fmt_t(time_alive),90,1,12)
  -- show current multiplier
  local mtxt=score_mult.."x"
  print(mtxt,104,1,score_mult>=2 and 11 or 12)
 elseif is_ta then
  local secs=flr(ta_time/30)
  local tc=secs>30 and 11 or (secs>10 and 10 or 8)
  print(fmt_t(ta_time),104,1,tc)
  -- flash warning under 10s
  if secs<=10 and anim_t%4<2 then
   rect(0,0,127,127,8)
  end
 else
  print("hi:"..hiscore,90,1,6)
 end
 local dc=ds(11,5,8)
 print(sub(lb_dnames[diff_sel],1,1),50,1,dc)
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
  print("m",124,9,14)
 end

 -- boss wave indicator
 if boss_active or boss_flash>0 then
  if boss_vuln>0 then
   local vc=flr(anim_t/2)%2==0 and 10 or 7
   print("weak!",50,9,vc)
  else
   local btc=boss_tier==1 and {10,7} or bt_cols[boss_type]
   local bc=flr(anim_t/3)%2==0 and btc[1] or btc[2]
   print(boss_tier==1 and "mini!" or "boss!",50,9,bc)
  end
 end

 -- active effect timers
 local ty=14
 local ef={{slowmo_timer,180,"slow",11},{dblscore_timer,120,"2x",10},{inv_timer,150,"inv",11}}
 for e in all(ef) do
  if e[1]>0 then
   rectfill(1,ty,1+flr(e[1]/e[2]*28),ty+2,e[4])
   print(e[3],31,ty,e[4])
   ty+=5
  end
 end

 -- gauntlet round indicator
 if is_gauntlet then
  local rn=g_round<=4 and g_round or 5
  local rtxt=rn<=4 and "r"..rn..":"..g_rnames[rn] or "boss!"
  local rc=rn<=4 and g_rcols[rn] or 8
  print(rtxt,1,122,rc)
  if rn<=4 then
   local pct=min(g_timer/ds(1500,2250,1800),1)
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
  local by=40-flr((30-bd_flash)/2)
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
  rectfill(10,38,117,78,0) rect(10,38,117,78,5)
  if g_round<4 then
   local nr=g_round+1
   print("round "..nr,44,48,7)
   print(g_rnames[nr],44,60,g_rcols[nr])
  else
   print("final boss!",36,55,anim_t%6<3 and 8 or 5)
  end
 end
end

-- leaderboard view state
lb_dnames={"easy","normal","hard","endless"}
function update_lbview()
 local prev=lb_vd
 if btnp(0) then lb_vd=max(1,lb_vd-1) end
 if btnp(1) then lb_vd=min(4,lb_vd+1) end
 if lb_vd!=prev then
  if lb_vd<4 then load_dlb(lb_vd) else load_elb() end
  _log("lb_switch:"..lb_dnames[lb_vd])
 end
 if btnp(4) or btnp(5) then
  load_dlb(diff_sel)
  state="menu"
  _log("state:menu")
 end
end

-- shared lb list drawing
function draw_lb5(ls,ln,x,y,hr)
 for i=1,5 do
  if ls[i] and ls[i]>0 then
   local c=hr==i and 10 or 6
   print(i..". "..ln[i].." "..ls[i],x,y,c)
  else
   print(i..". ---",x,y,1)
  end
  y+=7
 end
end
lb_dcols={11,7,8,12}
function draw_lbview()
 cls(0) draw_stars()
 print("leaderboard",28,6,10)
 local dn=lb_dnames[lb_vd]
 local dc=lb_dcols[lb_vd]
 print("\139 "..dn.." \145",64-#dn*2-4,18,dc)
 local ls=lb_vd<4 and lb_scores or elb_scores
 local ln=lb_vd<4 and lb_names or elb_names
 draw_lb5(ls,ln,20,40,0)
 print("\139\145 switch  \142/\151 back",10,110,5)
end

-- name entry state
function update_nameentry()
 if btnp(0) then ne_pos=max(1,ne_pos-1) end
 if btnp(1) then ne_pos=min(3,ne_pos+1) end
 if btnp(2) then ne_chars[ne_pos]=ne_chars[ne_pos]%26+1 end
 if btnp(3) then ne_chars[ne_pos]=(ne_chars[ne_pos]-2)%26+1 end
 if btnp(5) then ne_chars[ne_pos]=1 ne_pos=max(1,ne_pos-1) end
 if btnp(4) then
  -- confirm name
  local name=chr(64+ne_chars[1])..chr(64+ne_chars[2])..chr(64+ne_chars[3])
  -- insert into leaderboard at rank
  local ls=g_ls()
  local ln=g_ln()
  for i=5,ne_rank+1,-1 do
   ls[i]=ls[i-1]
   ln[i]=ln[i-1]
  end
  ls[ne_rank]=score+10
  ln[ne_rank]=name
  score+=10
  if score>hiscore then
   hiscore=score
   dset(0,hiscore)
  end
  if is_endless then lb_save(lb_bs[4],elb_scores,elb_names) else lb_save(lb_bs[diff_sel],lb_scores,lb_names) end
  sfx(4)
  state="gameover"
  go_timer=0
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
  local sel=i==ne_pos
  rect(bx,50,bx+12,62,sel and 7 or 5)
  if sel then
   print("\131",bx+3,43,10)
   print("\132",bx+3,64,10)
   if flr(t()*2)%2==0 then rectfill(bx+1,51,bx+11,61,1) end
  end
  print(chr(64+ne_chars[i]),bx+3,53,sel and 10 or 7)
 end

 print("\142 confirm  \151 back",18,72,6)
 print("+10 bonus pts!",28,82,11)

 -- top 3 preview
 if is_endless then print("[endless]",42,90,12) end
 draw_lb5(g_ls(),g_ln(),28,94,0)
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

 if is_ta then print("time attack",36,17,9)
 elseif is_endless then print("endless",42,17,12)
 elseif is_gauntlet then print(g_won and "gauntlet win!" or "fell r"..g_round,g_won and 30 or 38,17,g_won and 11 or 8)
 end
 print(g_won and "victory!" or "game over",40,24,g_won and 11 or 8)
 print("score: "..score,42,36,7)
 print("hi-score: "..hiscore,34,44,
  score>=hiscore and 10 or 6)


 -- stats
 print("["..lb_dnames[diff_sel].."]",48,52,5)
 print(flr(time_alive/30).."s lv"..diff_level,42,59,5)
 local sy=66
 if nm_best>0 then print("streak:"..nm_best.."x",34,sy,9) sy+=7 end
 if dodge_best>0 then print("combo:"..dodge_best.."x",34,sy,10) sy+=7 end
 if pu_collected>0 then print("power-ups:"..pu_collected,34,sy,12) sy+=7 end
 if mod_count>0 then print(mod_count.." mod(s) +"..(mod_count*10).."%",28,sy,14) sy+=7 end

 -- leaderboard
 local lbs=g_ls() local lbn=g_ln()
 local ly=max(sy+2,86)
 print(is_endless and "endless" or lb_dnames[diff_sel],38,ly,is_endless and 12 or 6)
 draw_lb5(lbs,lbn,28,ly+7,ne_rank)

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
 local r=sz\2
 local d=frame==0 and -1 or 1
 circfill(x+r,y+r,r,col)
 pset(x+r-d,y+r-1,col2)
 pset(x+r+d,y+r+1,5)
 if frame==1 then pset(x+r,y+r-1,col2) end
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
  pset(p.x,p.y,p.life>5 and p.col or (p.life>2 and 5 or 1))
 end
end

-- main loops
function _update()
 if state=="menu" then update_menu()
 elseif state=="lb_view" then update_lbview()
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
 elseif state=="lb_view" then draw_lbview()
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
