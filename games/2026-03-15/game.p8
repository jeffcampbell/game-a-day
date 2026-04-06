pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- pixel climb
-- a vertical platformer

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

function test_input(b)
 if testmode and test_input_idx<#test_inputs then
  test_input_idx+=1
  return test_inputs[test_input_idx] or 0
 end
 return btn()
end

function test_inputp(b)
 if testmode and test_input_idx<#test_inputs then
  return test_inputs[test_input_idx] or 0
 end
 return btnp()
end

-- globals
state="menu"
level=1
max_level=6
lives=3
score=0
coins_got=0
coins_total=0
diff=2 -- 1=easy,2=normal,3=hard
cam_y=0
target_cam=0
shk=0
particles={}
popup=""
popup_t=0
has_shield=false
has_djump=false
djump_used=false
spd_boost=0
hi_scores={{0,"---"},{0,"---"},{0,"---"}}
unlocked=1
achv={} -- achievements
name_chars={"a","a","a"}
name_sel=1
lvl_time=0 -- frames spent in level
pause_sel=1 -- pause menu selection
pause_mus=-1 -- music track saved on pause
stars={} -- background stars
-- challenge modifiers
mods={rev=false,fast=false,dark=false}
mod_sel=1
mod_names={"reverse","2x speed","dark mode"}
mod_keys={"rev","fast","dark"}
mod_descs={"l/r controls swapped","everything moves 2x","limited visibility"}
cur_mus=-1

-- boss system
boss=nil -- active boss entity
boss_lvls={[3]=1,[6]=2} -- level->boss type
boss_t=0 -- boss timer (frames)
bosses_beaten={} -- track which bosses defeated

-- platform/entity tables
plats={}
enemies={}
coin_list={}
powerups={}
spikes={}
bullets={} -- enemy projectiles

-- player
px=60
py=120
pvx=0
pvy=0
on_ground=false
inv_t=0 -- invincibility frames
p_flip=false
wall_side=0 -- -1=left wall, 1=right wall, 0=none
wall_time=0
wj_cd=0 -- wall jump cooldown
dash_cd=0 -- dash cooldown (45 frames)
dash_used=false -- one dash per airtime
dash_t=0 -- dash active frames remaining
-- combo system
combo=0
combo_mult=1
combo_popups={} -- {x,y,txt,t,c}

-- difficulty settings
-- {plat_w,enemy_spd,spike_count,safe_margin}
diff_cfg={
 {18,0.3,0,18},
 {13,0.5,2,12},
 {9,0.7,3,8}
}
dnames={"easy","normal","hard"}
dcols={11,10,8}

function make_particle(x,y,c,n)
 for i=1,n do
  add(particles,{x=x,y=y,
   vx=rnd(2)-1,vy=-rnd(2),
   life=15+rnd(10),c=c})
 end
end

function add_shk(n)
 shk=max(shk,n)
end

function show_popup(msg)
 popup=msg popup_t=60
end

function play_mus(n)
 if cur_mus!=n then
  cur_mus=n
  if n<0 then music(-1,500) else music(n,500) end
  _log("music:"..n)
 end
end

function gen_stars()
 stars={}
 for i=1,40 do
  add(stars,{x=rnd(128),y=rnd(512),
   c=rnd(1)<0.3 and 7 or rnd(1)<0.5 and 6 or 1,
   spd=0.2+rnd(0.3)})
 end
end

-- level generation
function gen_level(lv)
 plats={}
 enemies={}
 coin_list={}
 powerups={}
 spikes={}
 bullets={}
 coins_got=0
 coins_total=0

 local dc=diff_cfg[diff]
 local pw=dc[1]
 local espd=dc[2]
 local nspk=dc[3]
 local safe=dc[4]

 -- ground platform
 add(plats,{x=0,y=128,w=128,mv=0,mx=0,my=0,spd=0})

 -- generate platforms going up
 local ny=14+lv*2 -- more platforms for higher levels
 local height=ny*18
 for i=1,ny do
  local py_pos=128-i*flr(height/ny)
  local px_pos=rnd(128-pw)
  local mv=0
  local spd=0.3+lv*0.05
  if rnd(1)<0.2+lv*0.06 then
   mv=flr(rnd(2))+1 -- 1=horiz,2=vert
  end
  add(plats,{x=px_pos,y=py_pos,w=pw,
   mv=mv,mx=px_pos,my=py_pos,spd=spd,
   range=10+rnd(20),t=rnd(1)})
  -- coins on some platforms
  if rnd(1)<0.6 then
   add(coin_list,{x=px_pos+pw/2,y=py_pos-6,
    got=false,t=rnd(1)})
   coins_total+=1
  end
 end

 -- top goal platform
 local top_y=128-height-20
 add(plats,{x=40,y=top_y,w=48,mv=0,
  mx=40,my=top_y,spd=0,goal=true})

 -- enemies on some platforms (not ground/goal)
 -- types: 1=normal,2=bouncer,3=flyer,4=charger,5=spitter
 for i=2,#plats-1 do
  if rnd(1)<0.15+lv*0.07 then
   local p=plats[i]
   -- pick enemy type based on level
   local etype=1
   local r=rnd(1)
   if lv>=5 and r<0.12 then etype=5
   elseif lv>=4 and r<0.2 then etype=4
   elseif lv>=3 and r<0.35 then etype=3
   elseif lv>=2 and r<0.45 then etype=2
   end
   local hp=etype==4 and 2 or 1
   add(enemies,{x=p.x+4,y=p.y-6,
    w=6,h=6,dir=1,spd=espd,
    px=p.x,pw=p.w,alive=true,
    etype=etype,hp=hp,
    -- bouncer: vertical bounce state
    by=p.y-6,bvy=-1,
    -- flyer: sine wave
    fy=p.y-16,ft=rnd(1),
    -- charger: charge state
    charging=false,charge_cd=0,
    -- spitter: shoot timer
    shoot_t=60+flr(rnd(60))})
   _log("enemy_spawn type:"..etype)
  end
 end

 -- spikes on walls
 for i=1,nspk+lv do
  local sy=rnd(height)+20
  local sx=rnd(1)<0.5 and 0 or 122
  add(spikes,{x=sx,y=128-sy,side=sx<64 and 1 or -1})
 end

 -- power-ups (1-2 per level)
 local npow=2+flr(rnd(2))
 for i=1,npow do
  local pi=2+flr(rnd(#plats-2))
  local p=plats[pi]
  local typ=flr(rnd(3))+1 -- 1=shield,2=djump,3=speed
  add(powerups,{x=p.x+p.w/2,y=p.y-8,
   typ=typ,got=false,t=rnd(1)})
 end

 -- reset player
 px=60 py=120 pvx=0 pvy=0
 on_ground=false inv_t=0
 has_shield=false has_djump=false
 djump_used=false spd_boost=0
 wall_side=0 wall_time=0 wj_cd=0
 dash_cd=0 dash_used=false dash_t=0
 combo=0 combo_mult=1 combo_popups={}
 cam_y=0 target_cam=0
 lvl_time=0
 gen_stars()
end

-- persistence (cartdata called once in _init)
function save_data()
 for i=1,3 do
  local s=hi_scores[i]
  dset((i-1)*5,s[1])
  for j=1,3 do
   dset((i-1)*5+j,ord(sub(s[2],j,j)))
  end
 end
 dset(15,unlocked)
 local ab=0
 if achv.speedrun then ab+=1 end
 if achv.nodmg then ab+=2 end
 if achv.coinmaster then ab+=4 end
 if achv.boss_slayer then ab+=8 end
 if achv.boss_sr then ab+=16 end
 if achv.combo_master then ab+=32 end
 dset(16,ab)
end

function load_data()
 for i=1,3 do
  local sc=dget((i-1)*5)
  local nm=""
  for j=1,3 do
   local c=dget((i-1)*5+j)
   nm=nm..(c>0 and chr(c) or "-")
  end
  if sc>0 then hi_scores[i]={sc,nm} end
 end
 unlocked=max(1,dget(15))
 local ab=dget(16)
 achv.speedrun=ab%2>=1
 achv.nodmg=flr(ab/2)%2>=1
 achv.coinmaster=flr(ab/4)%2>=1
 achv.boss_slayer=flr(ab/8)%2>=1
 achv.boss_sr=flr(ab/16)%2>=1
 achv.combo_master=flr(ab/32)%2>=1
end

-- collision helpers
function box_hit(ax,ay,aw,ah,bx,by,bw,bh)
 return ax<bx+bw and ax+aw>bx and
        ay<by+bh and ay+ah>by
end

function plat_check(x,y,w,h,vy)
 for p in all(plats) do
  local px2=p.x
  if p.mv==1 then
   px2=p.mx+sin(p.t)*p.range
  end
  local py2=p.y
  if p.mv==2 then
   py2=p.my+sin(p.t)*p.range*0.5
  end
  p.dx=px2 p.dy=py2
  if x+w>px2 and x<px2+p.w and
     y+h>=py2 and y+h<=py2+4 and vy>=0 then
   return p
  end
 end
 return nil
end

-- update functions
function update_menu()
 local inp=test_inputp()
 play_mus(0)
 if inp&16>0 then -- O button
  sfx(10)
  _log("state:diff_select")
  state="diff_select"
 end
 if inp&32>0 then state="help" _log("state:help") end
end

function update_diff_select()
 local inp=test_inputp()
 if inp&4>0 then diff=max(1,diff-1) sfx(9) end
 if inp&8>0 then diff=min(3,diff+1) sfx(9) end
 if inp&16>0 then
  sfx(10)
  _log("state:mod_select diff:"..diff)
  state="mod_select"
  mod_sel=1
 end
end

function update_mod_select()
 local inp=test_inputp()
 if inp&4>0 then mod_sel=max(1,mod_sel-1) sfx(9) end
 if inp&8>0 then mod_sel=min(3,mod_sel+1) sfx(9) end
 if inp&1>0 or inp&2>0 then
  local k=mod_keys[mod_sel]
  mods[k]=not mods[k]
  sfx(10)
  _log("mod_toggle:"..k.." "..tostr(mods[k]))
 end
 if inp&16>0 then
  _log("state:play mods:rev="..tostr(mods.rev).." fast="..tostr(mods.fast).." dark="..tostr(mods.dark))
  level=1 score=0 lives=3
  gen_level(level)
  state="play"
  play_mus(1)
  _log("level:"..level)
 end
end

function update_pause()
 local inp=test_inputp()
 if inp&8>0 then
  pause_sel=mid(1,pause_sel+1,3)
  sfx(11)
 elseif inp&4>0 then
  pause_sel=mid(1,pause_sel-1,3)
  sfx(11)
 end
 if inp&16>0 then
  if pause_sel==1 then
   -- resume
   state="play"
   cur_mus=-1 play_mus(pause_mus)
   _log("state:play (resumed)")
  elseif pause_sel==2 then
   -- retry level
   _log("pause:retry")
   gen_level(level)
   px=60 py=120 pvx=0 pvy=0
   cam_y=0 target_cam=0
   on_ground=false
   has_shield=false has_djump=false
   djump_used=false spd_boost=0
   inv_t=0 wall_side=0 wall_time=0 wj_cd=0
   dash_cd=0 dash_used=false dash_t=0
   lvl_time=0 particles={}
   state="play"
   play_mus(1)
   _log("state:play")
  elseif pause_sel==3 then
   -- quit to menu
   _log("pause:quit")
   state="menu"
   mods={rev=false,fast=false,dark=false}
   play_mus(0)
   _log("state:menu")
  end
 end
 -- X button also resumes
 if inp&32>0 then
  state="play"
  cur_mus=-1 play_mus(pause_mus)
  _log("state:play (resumed)")
 end
end

function update_play()
 -- pause check (X button)
 local pinp=test_inputp()
 if pinp&32>0 then
  state="pause"
  pause_sel=1
  pause_mus=cur_mus
  music(-1,300)
  cur_mus=-1
  _log("state:pause")
  return
 end
 local inp=test_input()
 -- reverse controls modifier
 if mods.rev then
  local l=inp&1 local r=inp&2
  inp=band(inp,0xfffc)+shr(r,1)+shl(l,1)
 end
 local dc=diff_cfg[diff]
 local spd=1.2
 local spdm=mods.fast and 2 or 1
 if spd_boost>0 then
  spd=1.8
  spd_boost-=1
 end
 spd*=spdm

 -- horizontal movement
 if inp&1>0 then pvx=-spd p_flip=true
 elseif inp&2>0 then pvx=spd p_flip=false
 else pvx*=0.7 end

 -- wall jump cooldown
 if wj_cd>0 then wj_cd-=1 end

 -- jumping (ground, wall, or double)
 if inp&4>0 and on_ground then
  pvy=-3.2*spdm
  on_ground=false
  djump_used=false
  wall_side=0 wall_time=0
  make_particle(px+3,py+6,7,3)
  sfx(0)
  _log("jump")
 elseif inp&4>0 and wall_side!=0 and wj_cd<=0 then
  -- wall jump: launch away from wall
  local wdir=mods.rev and wall_side or -wall_side
  pvx=wdir*1.8*spdm
  pvy=-2.4*spdm
  wj_cd=6
  wall_side=0 wall_time=0
  djump_used=false
  p_flip=wdir<0
  make_particle(px+(wdir<0 and 6 or 0),py+4,11,5)
  sfx(12)
  _log("wall_jump")
 elseif inp&4>0 and has_djump and not djump_used and pvy>0 then
  pvy=-2.8
  djump_used=true
  make_particle(px+3,py+6,12,4)
  sfx(12)
  _log("djump")
 end

 -- dash ability (O button, airborne only)
 if pinp&16>0 and not on_ground and dash_cd<=0 and not dash_used then
  dash_t=6
  dash_used=true
  dash_cd=mods.fast and 90 or 45
  -- dash direction: follow current movement or facing
  local ddir=0
  if inp&1>0 then ddir=-1
  elseif inp&2>0 then ddir=1
  else ddir=p_flip and -1 or 1 end
  pvx=ddir*3.5*spdm
  pvy*=0.3 -- reduce vertical velocity during dash
  make_particle(px+3,py+4,9,6)
  add_shk(2)
  sfx(21)
  _log("dash")
 end

 -- dash active: boost speed and trail
 if dash_t>0 then
  dash_t-=1
  -- particle trail during dash
  local dc=dash_t%2==0 and 9 or 10
  make_particle(px+3,py+4,dc,2)
 end

 -- dash cooldown
 if dash_cd>0 then dash_cd-=1 end

 -- reset dash_used on landing
 if on_ground then dash_used=false end

 -- gravity
 pvy+=0.15*spdm
 pvy=min(pvy,3*spdm)

 -- move x
 px+=pvx
 if px<0 then px=0 pvx=0 end
 if px>122 then px=122 pvx=0 end

 -- wall slide detection
 if not on_ground and pvy>0 then
  if px<=0 then
   wall_side=-1
   wall_time+=1
   pvy=min(pvy,0.5*spdm) -- slow descent
   if wall_time%3==0 then make_particle(1,py+rnd(8),11,1) end
   p_flip=true
  elseif px>=122 then
   wall_side=1
   wall_time+=1
   pvy=min(pvy,0.5*spdm)
   if wall_time%3==0 then make_particle(px+5,py+rnd(8),11,1) end
   p_flip=false
  else
   wall_side=0 wall_time=0
  end
 else
  if on_ground then wall_side=0 wall_time=0 end
 end

 -- move y + platform collision
 py+=pvy
 local old_vy=pvy
 local hit=plat_check(px,py,6,8,pvy)
 if hit then
  py=hit.dy-8
  pvy=0
  on_ground=true
  -- landing shake from high fall
  if old_vy>2.5 then add_shk(3) sfx(6) end
  if hit.goal then
   _log("level_complete:"..level)
   -- check achievements
   if coins_got==coins_total and coins_total>0 then
    achv.coinmaster=true
    show_popup("coin master!")
    sfx(8)
    _log("achv:coinmaster")
   end
   if lives==3 then
    achv.nodmg=true
    show_popup("no damage!")
    sfx(8)
    _log("achv:nodmg")
   end
   -- speedrun: complete level in under 20 seconds (1200 frames)
   if lvl_time<1200 then
    achv.speedrun=true
    show_popup("speedrun!")
    sfx(8)
    _log("achv:speedrun")
   end
   -- boss encounter on levels 3 and 6
   if boss_lvls[level] then
    spawn_boss(boss_lvls[level])
    return
   end
   play_mus(-1)
   sfx(4)
   state="level_complete"
   score+=100*level
   _log("score:"..score)
   if level>=unlocked then
    unlocked=min(max_level,level+1)
   end
   save_data()
   return
  end
 else
  on_ground=false
 end

 -- fall off screen
 if py>cam_y+140 then
  take_damage()
  if lives>0 then
   px=60 py=cam_y+100 pvy=0 pvx=0
  end
 end

 -- camera
 target_cam=min(0,-(py-80))
 cam_y+=(target_cam-cam_y)*0.1

 -- update platforms
 for p in all(plats) do
  if p.mv>0 then p.t+=0.005*p.spd*(mods.fast and 2 or 1) end
 end

 -- enemy type particle colors
 local epcols={8,12,9,10,11}
 -- enemies
 local spdm2=mods.fast and 2 or 1
 for e in all(enemies) do
  -- knockback animation for dead enemies
  if not e.alive and e.kb_t then
   e.kb_t-=1
   e.x+=e.kvx e.y+=e.kvy
   e.kvy+=0.1 e.kvx*=0.92
   -- trailing particles during knockback
   if e.kb_t%4==0 then
    make_particle(e.x+3,e.y+3,epcols[e.etype or 1],1)
   end
   if e.kb_t<=0 then
    make_particle(e.x+3,e.y+3,epcols[e.etype or 1],6)
    del(enemies,e)
   end
  end
  if e.alive then
   local et=e.etype or 1
   if et==1 then
    -- normal: patrol left/right
    e.x+=e.dir*e.spd*spdm2
    if e.x<=e.px or e.x>=e.px+e.pw-e.w then e.dir*=-1 end
   elseif et==2 then
    -- bouncer: patrol + vertical bounce
    e.x+=e.dir*e.spd*0.5*spdm2
    if e.x<=e.px or e.x>=e.px+e.pw-e.w then e.dir*=-1 end
    e.bvy+=0.08*spdm2
    e.by+=e.bvy
    if e.bvy>0 and e.by>=e.y then
     e.by=e.y e.bvy=-2*spdm2
    end
   elseif et==3 then
    -- flyer: sine wave left/right at mid-height
    e.ft+=0.015*spdm2
    e.x=e.px+sin(e.ft)*e.pw*0.8
    e.y=e.fy+sin(e.ft*2.3)*10
   elseif et==4 then
    -- charger: patrol, then charge at player
    if e.charging then
     local dx=px-e.x local dy=py-e.y
     local d=max(1,sqrt(dx*dx+dy*dy))
     e.x+=dx/d*2*spdm2
     e.y+=dy/d*2*spdm2
     e.charge_cd-=1
     if e.charge_cd<=0 then e.charging=false e.charge_cd=90 end
    else
     e.x+=e.dir*e.spd*spdm2
     if e.x<=e.px or e.x>=e.px+e.pw-e.w then e.dir*=-1 end
     e.charge_cd-=1
     -- charge when player is close
     local dx=px-e.x local dy=py-e.y
     if e.charge_cd<=0 and dx*dx+dy*dy<35*35 then
      e.charging=true e.charge_cd=50
      _log("charger_charge")
     end
    end
   elseif et==5 then
    -- spitter: stationary, shoots at player
    e.shoot_t-=1
    if e.shoot_t<=0 then
     e.shoot_t=80+flr(rnd(60))
     local dx=px-e.x local dy=py-e.y
     local d=max(1,sqrt(dx*dx+dy*dy))
     add(bullets,{x=e.x+3,y=e.y+3,
      vx=dx/d*1.5*spdm2,vy=dy/d*1.5*spdm2,
      life=90})
     sfx(11)
     _log("spitter_shoot")
    end
   end
   -- collision with player
   local ey=et==2 and e.by or e.y
   if inv_t<=0 and box_hit(px,py,6,8,e.x,ey,e.w,e.h) then
    if pvy>0 and py+8<ey+4 then
     e.hp-=1
     local ec=epcols[et]
     if e.hp<=0 then
      e.alive=false
      -- combo scoring
      combo+=1
      combo_mult=combo<3 and 1 or combo<7 and 1.5 or combo<12 and 2 or 3
      local pts=flr((et==4 and 50 or 25)*combo_mult)
      score+=pts
      -- combo popup
      local ct=combo>=5 and 10 or 7
      add(combo_popups,{x=e.x,y=ey-4,txt=pts.."x"..combo,t=40,c=ct})
      _log("combo:"..combo.." mult:"..combo_mult)
      -- knockback: fly away from stomp
      local kdir=px<e.x and 1 or -1
      e.kvx=kdir*2.5 e.kvy=-2 e.kb_t=20
      make_particle(e.x+3,ey+3,ec,7)
      -- shake scales with combo milestones
      local sk=combo>=12 and 5 or combo>=7 and 4 or combo>=3 and 3 or 2
      add_shk(sk)
      sfx(2)
      -- combo achievement
      if combo>=15 and not achv.combo_master then
       achv.combo_master=true
       show_popup("combo master!")
       sfx(8)
       _log("achv:combo_master")
      end
      _log("enemy_kill type:"..et.." score:"..score)
     else
      pvy=-2
      add_shk(2)
      make_particle(e.x+3,ey+3,ec,4)
      sfx(6)
      _log("enemy_hit type:"..et.." hp:"..e.hp)
     end
     pvy=-2
    else
     take_damage()
    end
   end
  end
 end

 -- enemy bullets
 for i=#bullets,1,-1 do
  local b=bullets[i]
  b.x+=b.vx b.y+=b.vy
  b.life-=1
  if b.life<=0 then deli(bullets,i)
  elseif inv_t<=0 and box_hit(px,py,6,8,b.x-2,b.y-2,4,4) then
   take_damage()
   deli(bullets,i)
  end
 end

 -- coins
 for c in all(coin_list) do
  if not c.got then
   c.t+=0.02
   if box_hit(px,py,6,8,c.x-3,c.y-3,6,6) then
    c.got=true
    coins_got+=1
    score+=10
    make_particle(c.x,c.y,10,4)
    sfx(1)
    _log("coin score:"..score)
   end
  end
 end

 -- power-ups
 for pu in all(powerups) do
  if not pu.got then
   pu.t+=0.02
   if box_hit(px,py,6,8,pu.x-3,pu.y-3,6,6) then
    pu.got=true
    if pu.typ==1 then
     has_shield=true
     show_popup("shield!")
     _log("powerup:shield")
    elseif pu.typ==2 then
     has_djump=true
     show_popup("double jump!")
     _log("powerup:djump")
    else
     spd_boost=240
     show_popup("speed boost!")
     sfx(13)
     _log("powerup:speed")
    end
    make_particle(pu.x,pu.y,pu.typ==1 and 12 or pu.typ==2 and 9 or 11,5)
    sfx(3)
   end
  end
 end

 -- spikes
 if inv_t<=0 then
  for sp in all(spikes) do
   if box_hit(px,py,6,8,sp.x,sp.y,6,6) then
    sfx(11)
    take_damage()
    break
   end
  end
 end

 -- invincibility timer
 if inv_t>0 then inv_t-=1 end

 -- particles
 update_particles()
 update_boss_fx()

 -- combo popups
 for i=#combo_popups,1,-1 do
  local cp=combo_popups[i]
  cp.y-=0.5 cp.t-=1
  if cp.t<=0 then deli(combo_popups,i) end
 end

 -- popup timer
 if popup_t>0 then popup_t-=1 end

 -- shake decay
 if shk>0 then shk-=1 end
 -- level timer
 lvl_time+=1
end

function take_damage()
 if has_shield then
  has_shield=false
  inv_t=30
  if combo>0 then _log("combo_reset:"..combo) end
  combo=0 combo_mult=1
  add_shk(3)
  make_particle(px+3,py+4,12,6)
  sfx(7)
  _log("shield_break")
  return
 end
 lives-=1
 inv_t=75
 if combo>0 then
  _log("combo_reset:"..combo)
 end
 combo=0 combo_mult=1
 add_shk(5)
 make_particle(px+3,py+4,8,8)
 sfx(5)
 _log("damage lives:"..lives)
 if lives<=0 then
  play_mus(3)
  _log("state:gameover")
  if score>hi_scores[diff][1] then
   state="name_entry"
   name_chars={"a","a","a"}
   name_sel=1
   _log("state:name_entry")
  else
   state="gameover"
  end
 end
end

function update_level_complete()
 update_boss_fx()
 update_particles()
 if shk>0 then shk-=1 end
 local inp=test_inputp()
 if inp&16>0 then
  if level<max_level then
   level+=1
   gen_level(level)
   state="play"
   play_mus(1)
   _log("state:play level:"..level)
  else
   _log("state:gameover:win")
   play_mus(3)
   if score>hi_scores[diff][1] then
    state="name_entry"
    name_chars={"a","a","a"}
    name_sel=1
   else
    state="gameover"
   end
  end
 end
end

function update_name_entry()
 local inp=test_inputp()
 if inp&4>0 then
  local c=ord(name_chars[name_sel])
  c+=1 if c>ord("z") then c=ord("a") end
  name_chars[name_sel]=chr(c)
 end
 if inp&8>0 then
  local c=ord(name_chars[name_sel])
  c-=1 if c<ord("a") then c=ord("z") end
  name_chars[name_sel]=chr(c)
 end
 if inp&2>0 then name_sel=min(3,name_sel+1) end
 if inp&1>0 then name_sel=max(1,name_sel-1) end
 if inp&16>0 then
  local nm=name_chars[1]..name_chars[2]..name_chars[3]
  hi_scores[diff]={score,nm}
  save_data()
  _log("hiscore:"..score.." name:"..nm)
  state="gameover"
  _log("state:gameover")
 end
end

function update_gameover()
 local inp=test_inputp()
 if inp&16>0 then
  _log("state:menu")
  mods={rev=false,fast=false,dark=false}
  state="menu"
  play_mus(0)
 end
end

-- boss system
function spawn_boss(btype)
 -- clear normal enemies/bullets for arena
 enemies={}
 bullets={}
 boss_t=0
 -- set camera to goal area
 local arena_y=cam_y-10
 local bhp=diff+1 -- easy=2,normal=3,hard=4
 local bsz=10+diff*2 -- easy=12,normal=14,hard=16
 boss={
  typ=btype,hp=bhp,max_hp=bhp,
  x=64,y=arena_y+20,
  vx=0,vy=0,
  w=bsz,h=bsz,
  phase=0,atk_t=0,
  bounce_ct=0,alive=true
 }
 state="boss"
 play_mus(2) -- boss music
 sfx(18)
 add_shk(4)
 _log("boss_spawn type:"..btype.." level:"..level.." hp:"..bhp.." diff:"..diff)
end

function update_boss()
 if not boss or not boss.alive then return end
 local b=boss
 local spdm=mods.fast and 2 or 1
 boss_t+=1
 b.atk_t+=1

 if b.typ==1 then
  -- bouncer boss: arc bounces + projectiles
  b.vy+=0.12*spdm
  b.y+=b.vy
  b.x+=b.vx
  -- bounce off floor (relative to arena)
  if b.vy>0 and b.y>cam_y+90 then
   b.y=cam_y+90
   b.vy=-3.5*spdm
   b.vx=(px>b.x) and 1.2 or -1.2
   b.bounce_ct+=1
   add_shk(2)
   sfx(6)
   -- fire projectiles (harder=more frequent+more bullets)
   if b.bounce_ct%(7-diff)==0 then
    for i=1,diff do
     add(bullets,{x=b.x+6,y=b.y+12,
      vx=(i-(diff+1)/2)*0.5*spdm,vy=1.0*spdm,life=100})
    end
    sfx(11)
    _log("boss_attack:projectiles diff:"..diff)
   end
   -- progression: ring attack (delayed on easier diffs)
   if boss_t>480-diff*40 and b.bounce_ct%(7-diff)==0 then
    for a=0,diff+1 do
     add(bullets,{x=b.x+6,y=b.y+6,
      vx=cos(a/(diff+2))*spdm,vy=sin(a/(diff+2))*spdm,life=90})
    end
    _log("boss_attack:ring")
   end
  end
  -- bounce off walls
  if b.x<4 then b.x=4 b.vx=abs(b.vx) end
  if b.x>112 then b.x=112 b.vx=-abs(b.vx) end
 elseif b.typ==2 then
  -- charger boss: difficulty-scaled charges + projectiles
  local tele=40-diff*10 -- easy=30,normal=20,hard=10 (telegraph frames before charge)
  local cspd=(2+diff)*spdm -- easy=3,normal=4,hard=5
  if b.phase==0 then
   if b.atk_t<tele then
    b.vx=0
   elseif b.atk_t<tele+16 then
    local dir=px>b.x and 1 or -1
    b.vx=dir*cspd
    b.x+=b.vx
   else
    b.vx=0
    b.phase=1
    b.atk_t=0
    local dx=px-b.x local dy=py-b.y
    local d=max(1,sqrt(dx*dx+dy*dy))
    for i=0,diff-1 do
     add(bullets,{x=b.x+6+i*4,y=b.y,
      vx=dx/d*(1+i*0.3)*spdm,
      vy=dy/d*(1+i*0.3)*spdm,life=100})
    end
    sfx(11)
    _log("boss_attack:charge_shoot diff:"..diff)
   end
  else
   -- wait phase (shorter on hard)
   if b.atk_t>50-diff*8 then
    b.phase=0
    b.atk_t=0
   end
  end
  -- progression: spread burst after 6s
  if boss_t>420 and boss_t%120==0 then
   for a=0,diff+1 do
    local ang=atan2(px-b.x,py-b.y)+0.05*(a-diff/2)
    add(bullets,{x=b.x+6,y=b.y+6,
     vx=cos(ang)*1.5*spdm,vy=sin(ang)*1.5*spdm,life=80})
   end
   _log("boss_attack:spread")
  end
  -- keep on platform
  if b.x<4 then b.x=4 end
  if b.x>112 then b.x=112 end
  b.y=cam_y+70 -- stay on ground level
 end

 -- player collision with boss
 if inv_t<=0 and box_hit(px,py,6,8,b.x,b.y,b.w,b.h) then
  if pvy>0 and py+8<b.y+6 then
   -- stomp the boss - combo counts
   b.hp-=1
   combo+=1
   combo_mult=combo<3 and 1 or combo<7 and 1.5 or combo<12 and 2 or 3
   _log("combo:"..combo.." mult:"..combo_mult)
   pvy=-3
   -- shake scales with damage (lower hp = harder shake)
   local shk_n=4+(b.max_hp-b.hp)*2
   add_shk(shk_n)
   -- large multi-color particle burst
   make_particle(b.x+6,b.y+6,7,12)
   make_particle(b.x+6,b.y,10,4)
   sfx(18)
   _log("boss_hit hp:"..b.hp)
   if b.hp<=0 then
    boss_defeat()
    return
   end
  else
   take_damage()
  end
 end

 -- player input (reuse play controls for movement)
 local pinp=test_inputp()
 local inp=test_input()
 if mods.rev then
  local l=inp&1 local r=inp&2
  inp=band(inp,0xfffc)+shr(r,1)+shl(l,1)
 end
 local spd=1.2
 if spd_boost>0 then spd=1.8 spd_boost-=1 end
 spd*=spdm

 if inp&1>0 then pvx=-spd p_flip=true
 elseif inp&2>0 then pvx=spd p_flip=false
 else pvx*=0.7 end

 if wj_cd>0 then wj_cd-=1 end
 if inp&4>0 and on_ground then
  pvy=-3.2*spdm on_ground=false
  djump_used=false wall_side=0 wall_time=0
  make_particle(px+3,py+6,7,3) sfx(0)
 elseif inp&4>0 and wall_side!=0 and wj_cd<=0 then
  local wdir=mods.rev and wall_side or -wall_side
  pvx=wdir*1.8*spdm pvy=-2.4*spdm
  wj_cd=6 wall_side=0 wall_time=0 djump_used=false
  p_flip=wdir<0
  make_particle(px+(wdir<0 and 6 or 0),py+4,11,5) sfx(12)
 elseif inp&4>0 and has_djump and not djump_used and pvy>0 then
  pvy=-2.8 djump_used=true
  make_particle(px+3,py+6,12,4) sfx(12)
 end

 -- dash
 if pinp&16>0 and not on_ground and dash_cd<=0 and not dash_used then
  dash_t=6 dash_used=true
  dash_cd=mods.fast and 90 or 45
  local ddir=0
  if inp&1>0 then ddir=-1
  elseif inp&2>0 then ddir=1
  else ddir=p_flip and -1 or 1 end
  pvx=ddir*3.5*spdm pvy*=0.3
  make_particle(px+3,py+4,9,6) add_shk(2) sfx(21)
 end
 if dash_t>0 then
  dash_t-=1
  if dash_t%2==0 then make_particle(px+3,py+4,9,2) end
 end
 if dash_cd>0 then dash_cd-=1 end
 if on_ground then dash_used=false end

 -- gravity + movement
 pvy+=0.15*spdm pvy=min(pvy,3*spdm)
 px+=pvx py+=pvy
 if px<0 then px=0 pvx=0 end
 if px>122 then px=122 pvx=0 end

 -- wall slide
 if not on_ground and pvy>0 then
  if px<=0 then wall_side=-1 wall_time+=1 pvy=min(pvy,0.5*spdm)
  elseif px>=122 then wall_side=1 wall_time+=1 pvy=min(pvy,0.5*spdm)
  else wall_side=0 wall_time=0 end
 else
  if on_ground then wall_side=0 wall_time=0 end
 end

 -- platform collision in boss arena
 local hit=plat_check(px,py,6,8,pvy)
 if hit then
  py=hit.dy-8 pvy=0 on_ground=true
 else
  on_ground=false
 end

 -- fall off screen
 if py>cam_y+140 then
  take_damage()
  if lives>0 then px=60 py=cam_y+50 pvy=0 pvx=0 end
 end

 -- boss bullets
 for i=#bullets,1,-1 do
  local bl=bullets[i]
  bl.x+=bl.vx bl.y+=bl.vy bl.life-=1
  if bl.life<=0 then deli(bullets,i)
  elseif inv_t<=0 and box_hit(px,py,6,8,bl.x-2,bl.y-2,4,4) then
   take_damage() deli(bullets,i)
  end
 end

 if inv_t>0 then inv_t-=1 end
 update_particles()
 update_boss_fx()
 for i=#combo_popups,1,-1 do
  local cp=combo_popups[i]
  cp.y-=0.5 cp.t-=1
  if cp.t<=0 then deli(combo_popups,i) end
 end
 if popup_t>0 then popup_t-=1 end
 if shk>0 then shk-=1 end
end

-- boss defeat fanfare particles (delayed bursts)
boss_fx={} -- {x,y,t,c,n} delayed particle bursts
function update_boss_fx()
 for i=#boss_fx,1,-1 do
  local f=boss_fx[i]
  f.t-=1
  if f.t<=0 then
   make_particle(f.x,f.y,f.c,f.n)
   add_shk(f.s or 2)
   deli(boss_fx,i)
  end
 end
end

function boss_defeat()
 boss.alive=false
 score+=flr(200*combo_mult)
 -- immediate burst
 make_particle(boss.x+6,boss.y+6,10,15)
 make_particle(boss.x+6,boss.y+6,9,10)
 make_particle(boss.x+6,boss.y+6,7,8)
 add_shk(4)
 sfx(18)
 -- delayed escalating bursts
 local bx,by=boss.x+6,boss.y+6
 add(boss_fx,{x=bx-4,y=by,t=8,c=8,n=10,s=6})
 add(boss_fx,{x=bx+4,y=by,t=16,c=10,n=12,s=8})
 add(boss_fx,{x=bx,y=by-4,t=24,c=7,n=8,s=4})
 bosses_beaten[boss.typ]=true
 _log("boss_defeated level:"..level.." type:"..boss.typ)
 _log("score:"..score)
 -- check boss_slayer achievement
 if bosses_beaten[1] and bosses_beaten[2] then
  achv.boss_slayer=true
  show_popup("boss slayer!")
  _log("achv:boss_slayer")
 end
 -- speedrun achievement: level 3 boss beaten <45s (1350 frames)
 if level==3 and lvl_time<1350 then
  achv.boss_sr=true
  show_popup("boss speedrun!")
  _log("achv:boss_speedrun")
 end
 -- transition to level_complete after short delay
 play_mus(-1) sfx(4)
 state="level_complete"
 score+=100*level
 if level>=unlocked then
  unlocked=min(max_level,level+1)
 end
 save_data()
end

function draw_boss()
 -- reuse draw_play for background
 draw_play()
 -- draw boss on top (already in camera space from draw_play)
 if boss and boss.alive then
  camera(shk>0 and rnd(shk)-shk/2 or 0,cam_y+(shk>0 and rnd(shk)-shk/2 or 0))
  local b=boss
  -- phase colors
  local cols
  if b.typ==1 then
   cols={8,9,10} -- red->orange->yellow
  else
   cols={2,8,9} -- darkred->red->orange
  end
  local ci=mid(1,b.max_hp+1-b.hp,3)
  local bc=cols[ci] or 8
  -- draw boss body (16x12 rect)
  rectfill(b.x,b.y,b.x+b.w,b.y+b.h,bc)
  -- eyes
  pset(b.x+3,b.y+3,7) pset(b.x+9,b.y+3,7)
  -- mouth/detail
  line(b.x+3,b.y+8,b.x+9,b.y+8,7)
  -- border flash on low hp
  if b.hp<=1 and boss_t%8<4 then
   rect(b.x-1,b.y-1,b.x+b.w+1,b.y+b.h+1,10)
  end
  -- charger telegraph flash
  if b.typ==2 and b.phase==0 and b.atk_t<(36-diff*12) and b.atk_t%6<3 then
   rect(b.x-2,b.y-2,b.x+b.w+2,b.y+b.h+2,8)
  end
 end

 -- boss HUD (health bar)
 camera(0,0)
 if boss then
  local bw=40
  local bx=44
  rectfill(bx-1,17,bx+bw+1,22,0)
  rect(bx-1,17,bx+bw+1,22,7)
  local hw=flr(bw*boss.hp/boss.max_hp)
  local hc=boss.hp>=3 and 11 or boss.hp==2 and 9 or 8
  if hw>0 then rectfill(bx,18,bx+hw,21,hc) end
  local bn=boss.typ==1 and "bouncer" or "charger"
  print(bn,48,12,7)
 end
end

function update_particles()
 for i=#particles,1,-1 do
  local p=particles[i]
  p.x+=p.vx p.y+=p.vy
  p.vy+=0.05
  p.life-=1
  if p.life<=0 then deli(particles,i) end
 end
end

-- draw functions
function draw_menu()
 cls(1)
 print("pixel climb",34,30,7)
 print("a vertical platformer",18,40,6)
 print("\x8e start  \x97 help",16,70,10)
 -- hi scores
 print("-- high scores --",24,86,6)
 for i=1,3 do
  local s=hi_scores[i]
  print(dnames[i]..": "..s[1].." "..s[2],24,92+i*7,5+i)
 end
 -- achievements
 local ay=120
 for a in all({{"speedrun","\x96spd",2},{"nodmg","\x96dmg",28},{"coinmaster","\x96cn",52},{"boss_slayer","\x96bs",74},{"boss_sr","\x96br",96},{"combo_master","\x96cb",116}}) do
  if achv[a[1]] then print(a[2],a[3],ay,11) end
 end
end

function draw_diff_select()
 cls(1)
 print("select difficulty",22,20,7)
 for i=1,3 do
  if i==diff then
   rectfill(30,38+i*14,98,50+i*14,dcols[i])
   print("> "..dnames[i].." <",36,42+i*14,0)
  else
   print(dnames[i],44,42+i*14,dcols[i])
  end
 end
 local dd={"wide plats, no spikes\nslow enemies, big zones","medium plats, 2 spikes\nfaster enemies, tight","thin plats, 4 spikes\nfast enemies, minimal"}
 print(dd[diff],10,96,5)
 print("\x8b\x91 select  \x8e confirm",14,114,6)
end

function draw_mod_select()
 cls(1)
 print("challenge modifiers",18,10,7)
 print("(optional - stack for difficulty)",2,20,6)
 for i=1,3 do
  local y=32+i*16
  local k=mod_keys[i]
  local on=mods[k]
  local c=i==mod_sel and 7 or 5
  if i==mod_sel then
   rectfill(4,y-2,124,y+10,on and 3 or 2)
  end
  local icon=on and "\x91" or "\x90"
  print(icon.." "..mod_names[i],8,y,on and 11 or c)
  print(mod_descs[i],16,y+8,on and 10 or 5)
 end
 print("\x8b\x91 select  \x8e\x8f toggle",10,96,6)
 print("\x8e start",46,106,11)
end

function draw_pause()
 -- draw gameplay behind pause overlay
 draw_play()
 -- dim overlay
 for y=0,127 do
  for x=0,127 do
   if (x+y)%2==0 then pset(x,y,0) end
  end
 end
 -- pause menu box
 rectfill(24,40,104,92,0)
 rect(24,40,104,92,7)
 rect(25,41,103,91,5)
 print("paused",48,44,7)
 local opts={"resume","retry level","quit to menu"}
 for i=1,3 do
  local c=5
  if i==pause_sel then
   rectfill(28,52+i*10,100,60+i*10,1)
   c=11
   print(">",28,54+i*10,c)
  end
  print(opts[i],36,54+i*10,c)
 end
end

function draw_play()
 local sx=shk>0 and rnd(shk)-shk/2 or 0
 local sy=shk>0 and rnd(shk)-shk/2 or 0
 camera(sx,cam_y+sy)
 cls(0)

 -- background stars (parallax)
 for s in all(stars) do
  local sy2=s.y+cam_y*s.spd
  pset(s.x,sy2%512-256,s.c)
 end

 -- platforms
 for p in all(plats) do
  local dx=p.x
  if p.mv==1 then dx=p.mx+sin(p.t)*p.range end
  local dy=p.y
  if p.mv==2 then dy=p.my+sin(p.t)*p.range*0.5 end
  p.dx=dx p.dy=dy
  if p.goal then
   rectfill(dx,dy,dx+p.w,dy+2,11)
   print("goal",dx+16,dy-8,11)
  else
   rectfill(dx,dy,dx+p.w,dy+2,5)
   rectfill(dx+1,dy,dx+p.w-1,dy+1,6)
  end
 end

 -- spikes
 for sp in all(spikes) do
  local sx2=sp.x
  for i=0,1 do
   local bx=sx2+i*3
   line(bx+1,sp.y,bx,sp.y+5,8)
   line(bx+1,sp.y,bx+2,sp.y+5,8)
  end
 end

 -- coins
 for c in all(coin_list) do
  if not c.got then
   local cy=c.y+sin(c.t)*2
   circfill(c.x,cy,2,10)
   pset(c.x-1,cy-1,7)
  end
 end

 -- power-ups
 local pcols={12,9,11}
 for pu in all(powerups) do
  if not pu.got then
   local py2=pu.y+sin(pu.t)*2
   local c=pcols[pu.typ]
   rectfill(pu.x-2,py2-2,pu.x+2,py2+2,c)
   rect(pu.x-3,py2-3,pu.x+3,py2+3,c)
  end
 end

 -- enemies
 -- type colors: 1=red,2=cyan,3=yellow,4=darkred,5=magenta
 local ecols={8,12,10,2,13}
 for e in all(enemies) do
  -- draw knockback enemies (fading)
  if not e.alive and e.kb_t then
   local ec=ecols[e.etype or 1]
   rectfill(e.x,e.y,e.x+e.w,e.y+e.h,ec)
  end
  if e.alive then
   local et=e.etype or 1
   local ec=ecols[et]
   local ey=et==2 and e.by or e.y
   rectfill(e.x,ey,e.x+e.w,ey+e.h,ec)
   pset(e.x+1,ey+1,7)
   pset(e.x+e.w-1,ey+1,7)
   -- charger charge indicator
   if et==4 and e.charging then
    rect(e.x-1,ey-1,e.x+e.w+1,ey+e.h+1,8)
   end
   -- spitter aiming dot
   if et==5 then
    circfill(e.x+3,ey-2,1,13)
   end
  end
 end

 -- enemy bullets
 for b in all(bullets) do
  circfill(b.x,b.y,2,13)
  pset(b.x,b.y,7)
 end

 -- player
 if inv_t<=0 or inv_t%4<2 then
  rectfill(px,py,px+5,py+7,has_shield and 12 or 7)
  -- eyes
  pset(px+1,py+2,0)
  pset(px+4,py+2,0)
  -- feet
  if on_ground then
   pset(px+1,py+7,5)
   pset(px+4,py+7,5)
  end
  if has_shield then
   rect(px-1,py-1,px+6,py+8,12)
  end
  -- dash flash
  if dash_t>0 then
   rect(px-1,py-1,px+6,py+8,9)
  end
  -- wall slide visual: streaks on wall side
  if wall_side!=0 then
   local wx=wall_side<0 and px or px+5
   line(wx,py+1,wx,py+6,11)
  end
 end

 -- particles
 for p in all(particles) do
  pset(p.x,p.y,p.c)
 end

 -- combo popups (in world space)
 for cp in all(combo_popups) do
  print(cp.txt,cp.x,cp.y,cp.c)
 end

 -- HUD (fixed position)
 camera(0,0)
 -- dark mode: black out edges
 if mods.dark then
  clip()
  local vr=30 -- visible radius
  local cx=px+3
  local cy=py+4+cam_y
  -- draw dark border using filled rects
  rectfill(0,0,cx-vr,127,0)
  rectfill(cx+vr,0,127,127,0)
  rectfill(cx-vr,0,cx+vr,cy-vr,0)
  rectfill(cx-vr,cy+vr,cx+vr,127,0)
  -- soft edge circles
  for a=0,1,0.05 do
   local ex=cx+cos(a)*vr
   local ey=cy+sin(a)*vr
   circfill(ex,ey,3,0)
  end
 end
 print("lv"..level,2,2,7)
 print("\x96"..lives,24,2,8)
 print("$"..score,50,2,10)
 print(coins_got.."/"..coins_total,100,2,10)
 local secs=flr(lvl_time/30)
 print(secs.."s",2,10,secs<20 and 11 or 6)
 if has_shield then print("sh",20,10,12) end
 if has_djump then print("dj",34,10,9) end
 if spd_boost>0 then print("sp",48,10,11) end
 print("da",62,10,dash_cd<=0 and 9 or 5)
 -- combo display
 if combo>0 then
  print(combo.."x"..combo_mult.."x",78,10,combo>=10 and 10 or 7)
 end
 if mods.rev then print("rev",2,18,8) end
 if mods.fast then print("2x",18,18,9) end
 if mods.dark then print("drk",32,18,5) end

 -- popup
 if popup_t>0 then
  local pw=#popup*4
  print(popup,64-pw/2,20,11)
 end
end

function draw_level_complete()
 cls(1)
 print("level "..level.." complete!",22,30,11)
 print("score: "..score,38,50,7)
 print("coins: "..coins_got.."/"..coins_total,34,60,10)
 if level<max_level then
  print("\x8e next level",36,90,6)
 else
  print("you win! final score: "..score,8,80,11)
  print("\x8e continue",38,90,6)
 end
end

function draw_name_entry()
 cls(1)
 print("new high score!",26,20,11)
 print(score,54,32,7)
 print("enter name:",34,50,6)
 for i=1,3 do
  local c=i==name_sel and 11 or 6
  local nx=48+(i-1)*12
  print(name_chars[i],nx,62,c)
  if i==name_sel then
   print("\x83",nx,56,c)
   print("\x84",nx,70,c)
  end
 end
 print("\x8e confirm",40,86,6)
end

function draw_gameover()
 cls(1)
 if level>max_level-1 and lives>0 then
  print("congratulations!",22,24,11)
  print("all levels cleared!",18,34,10)
 else
  print("game over",38,30,8)
 end
 print("score: "..score,40,50,7)
 print("level: "..level,40,60,6)
 print("best: "..hi_scores[diff][1].." "..hi_scores[diff][2],24,76,5)
 print("\x8e menu",46,100,6)
end

function update_help()
 if test_inputp()&48>0 then
  state="menu"
  _log("state:menu")
 end
end

function draw_help()
 cls(1)
 print("-- enemies --",24,4,7)
 print("\x83 normal: walks l/r",4,16,8)
 print("\x83 bouncer: bounces",4,28,12)
 print("\x83 flyer: sine wave",4,40,10)
 print("\x83 charger: charges!",4,52,2)
 print("\x83 spitter: shoots",4,64,13)
 print("powerups: shield djump speed",4,78,11)
 print("\x8e/\x97 back",46,120,6)
end

function _init()
 cartdata("pixclimb1")
 load_data()
 _log("state:menu")
 play_mus(0)
end

function _update()
 if state=="menu" then update_menu()
 elseif state=="help" then update_help()
 elseif state=="diff_select" then update_diff_select()
 elseif state=="mod_select" then update_mod_select()
 elseif state=="play" then update_play()
 elseif state=="boss" then update_boss()
 elseif state=="pause" then update_pause()
 elseif state=="level_complete" then update_level_complete()
 elseif state=="name_entry" then update_name_entry()
 elseif state=="gameover" then update_gameover()
 end
end

function _draw()
 if state=="menu" then draw_menu()
 elseif state=="help" then draw_help()
 elseif state=="diff_select" then draw_diff_select()
 elseif state=="mod_select" then draw_mod_select()
 elseif state=="play" then draw_play()
 elseif state=="boss" then draw_boss()
 elseif state=="pause" then draw_pause()
 elseif state=="level_complete" then draw_level_complete()
 elseif state=="name_entry" then draw_name_entry()
 elseif state=="gameover" then draw_gameover()
 end
end
__sfx__
000200001805018050240502405030050300500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002405024050300503005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000c0500c050180501805024050240500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001805024050300503005030050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800001805024050300503605036050360500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000060500605006050060500c0500c050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000106500c640086300462000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300003066028660206501865010640086300462000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00060000180501c0501f05024050280502b0503005030055000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200002435028350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300002035024350283502c35000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002000018660186600c6600c66006650066500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000240502b050300500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000c7501075114751187511c751207512475128750000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100000180501c0501f050240501f0501c0501805013050180501c0501f0502405028050240501f05018050180501c0501f050240501f0501c0501805013050180501c0501f0502405028050240501f05018050
001000000c3400c34011340113400c3400c3400b3400b3400c3400c340113401134013340133400c3400c3400c3400c34011340113400c3400c3400b3400b3400c3400c340113401134013340133400c3400c340
000c000018050000001c050000001f0501c050180500000024050000001f050000001c05018050150500000018050000001c050000001f05024050280500000024050000001f050000001c0501f0501805000000
000c00000c3400c3400c3400c34011340113401134011340133401334013340133400c3400c3400c3400c3400c3400c3400c3400c34011340113401134011340103401034010340103400c3400c3400c3400c340
00080000180501c0501f05024050280502b0503005030050300503004530035300250000000000000000000000000000000000000000000000000000000000000000
001400001c0501a0501805017050180500000000000000001c0501a0501805015050180500000000000000001c0501a0501805017050180500000000000000001c0501a050180501505018050000000000000000
001400000c3400c3400c3400c3400934009340093400934005340053400534005340c3400c3400c3400c3400c3400c3400c3400c34009340093400934009340053400534005340053400c3400c3400c3400c340
000200003005028050240501c0501005008050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
03 0e0f4141
03 10114141
04 12414141
03 13144141
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111111111111111111111111111111bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111188888881111111111111111111111111111111111111111111
111111111111111111111111111111aaa11111111111111111111111111111111111111111111188888881111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111188888881111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111188888881111111111111111111111111111111111111111111
11111111111111111111555555555555555555555555511111111111111111111111115555555555555555555555555111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111aaa111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111115555555555555555555555555111111111111111111111111155555555555555555555555551111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111aaa111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111115555555555555555555555555111111111111111111111111155555555555555555555555551111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111177777711111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111177777711111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111177777711111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111177777711111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111177777711111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111177777711111111111111111111111111111111111111111111111111111111111111
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
44444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444
