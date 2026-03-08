pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- gem match: match-3 puzzle arcade
-- 2026-03-05

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
 return btnp()
end

-- constants
gw,gh=8,8 -- grid width/height
gs=14 -- gem size in pixels
gox,goy=2,18 -- grid offset x,y
colors={8,9,10,11,12,13,14,15}


-- game state
state="menu"
score,combo,level=0,0,1
target=1000
diff=2 -- 1=easy,2=normal,3=hard
gmode=1 -- 1=normal, 2=time attack, 3=endless
timer=0 -- frames remaining (time attack)
tbonus=0 -- time bonus score
ncols=7 -- number of gem colors
grid={}
cx,cy=1,1 -- cursor position
sel=nil -- selected gem {x,y}
swapping=false
swap_t=0
swap_from=nil
swap_to=nil
fall_t=0
falling=false
checking=false
no_moves=false
paused=false
particles={}
float_texts={}
shake=0
combo_timer=0
hiscore=0
-- cascade tracking
casc=0 -- current cascade count
casc_max=0 -- max cascade this game
casc_total=0 -- total cascades this game
casc_ms=0 -- milestone flags (bitmask: 1=3+,2=5+,4=10+,8=15+)
casc_big=0 -- count of 3+ cascades this game
e_bg=1 -- endless bg color
pups_made=0 -- power-ups created this game
-- leaderboard
lb={}
name_buf=""
name_idx=1
name_chars="abcdefghijklmnopqrstuvwxyz "

-- challenge modifiers (bitfield)
mods=0 -- active modifier bitmask
mod_cur=1 -- cursor in mod select menu
-- mod defs: {name, short, desc}
-- bit 0=no powerups,1=mono,2=speed,3=limited,4=bomb heavy,5=score pen,6=perfect
mod_defs={
 {n="no powerups",s="nopw",d="no power-up gems"},
 {n="monochrome",s="mono",d="only 2 gem colors"},
 {n="speed run",s="fast",d="30% faster animations"},
 {n="limited colors",s="ltd3",d="start with 3 colors"},
 {n="bomb heavy",s="bomb",d="1.5x power-up freq"},
 {n="score penalty",s="x0.7",d="scores x0.7"},
 {n="perfect scorer",s="perf",d="combo resets if <3"},
}

function has_mod(n)
 return band(mods,shl(1,n-1))>0
end

function mod_count()
 local c=0
 for i=1,7 do if has_mod(i) then c+=1 end end
 return c
end

-- achievements
-- {name, desc, threshold, slot(dget/dset offset from 31)}
ach_defs={
 {n="unstoppable",d="5+ combo",th=5,t="combo"},
 {n="rampage",d="10+ combo",th=10,t="combo"},
 {n="master",d="15+ combo",th=15,t="combo"},
 {n="crusher",d="clear 100 gems",th=100,t="gems"},
 {n="annihilator",d="clear 500 gems",th=500,t="gems"},
 {n="gem lord",d="clear 1000 gems",th=1000,t="gems"},
 {n="explosive",d="5 bombs activated",th=5,t="bombs"},
 {n="striped",d="5 stripes activated",th=5,t="stripes"},
 {n="colorful",d="5 color bombs used",th=5,t="cbombs"},
 {n="speed runner",d="time atk under 45s",th=1,t="speed"},
 {n="pioneer",d="reach lvl 3 normal",th=3,t="level"},
 {n="conqueror",d="500+ on hard",th=500,t="hardscore"},
 {n="big spender",d="score 5000+ pts",th=5000,t="score"},
 {n="marathon",d="endless lvl 10",th=10,t="endless"},
 {n="chain react",d="2+ cascade",th=2,t="casc"},
 {n="unstop casc",d="4+ cascade",th=4,t="casc"},
 {n="casc master",d="10 cascades/game",th=10,t="cascg"},
 {n="casc expert",d="15+ cascade",th=15,t="casc"},
 {n="casc pro",d="3+ big casc/game",th=3,t="cascbig"},
}
ach_unlocked={}
ach_popup=nil -- {name,timer}
-- persistent stats
total_gems=0
total_bombs=0
total_stripes=0
total_cbombs=0
max_combo_ever=0

-- init
function _init()
 -- load hiscore
 hiscore=dget(0)
 for i=0,9 do
  local base=i*3+1
  local s=dget(base)
  local nv=dget(base+1)
  local md=dget(base+2)
  local n=""
  -- decode name from number
  if s>0 then
   for j=0,2 do
    local c=flr(nv/(27^(2-j)))%27
    n=n..sub(name_chars,c+1,c+1)
   end
   add(lb,{score=s,name=n,mode=md>0 and md or 1})
  end
 end
 -- load achievements + persistent stats
 for i=1,#ach_defs do
  ach_unlocked[i]=dget(30+i)>0
 end
 total_gems=dget(50)
 total_bombs=dget(51)
 total_stripes=dget(52)
 total_cbombs=dget(53)
 max_combo_ever=dget(54)
 _log("state:menu")
end

function save_ach()
 for i=1,#ach_defs do
  dset(30+i,ach_unlocked[i] and 1 or 0)
 end
 dset(50,total_gems)
 dset(51,total_bombs)
 dset(52,total_stripes)
 dset(53,total_cbombs)
 dset(54,max_combo_ever)
end

function try_ach(idx)
 if not ach_unlocked[idx] then
  ach_unlocked[idx]=true
  ach_popup={n=ach_defs[idx].n,t=90}
  shake=5
  sfx(4)
  save_ach()
  _log("ach_unlock:"..ach_defs[idx].n)
 end
end

function check_achs()
 -- combo achievements
 if combo>=5 then try_ach(1) end
 if combo>=10 then try_ach(2) end
 if combo>=15 then try_ach(3) end
 if max_combo_ever<combo then max_combo_ever=combo end
 -- gem clearing (persistent)
 if total_gems>=100 then try_ach(4) end
 if total_gems>=500 then try_ach(5) end
 if total_gems>=1000 then try_ach(6) end
 -- power-up usage (persistent)
 if total_bombs>=5 then try_ach(7) end
 if total_stripes>=5 then try_ach(8) end
 if total_cbombs>=5 then try_ach(9) end
 -- speed runner: 500+ pts in time atk with 45+s left
 if gmode==2 and score>=500 and timer>45*30 then try_ach(10) end
 -- score achievement
 if score>=5000 then try_ach(13) end
 -- level achievement (normal mode)
 if gmode==1 and level>=3 then try_ach(11) end
 -- hard mode score
 if diff==3 and score>=500 then try_ach(12) end
 -- marathon runner: endless lvl 10
 if gmode==3 and level>=10 then try_ach(14) end
 -- cascade achievements
 if casc>=2 then try_ach(15) end
 if casc>=4 then try_ach(16) end
 if casc_total>=10 then try_ach(17) end
 if casc>=15 then try_ach(18) end
 if casc_big>=3 then try_ach(19) end
end

function make_grid()
 grid={}
 for x=1,gw do
  grid[x]={}
  for y=1,gh do
   grid[x][y]=new_gem(x,y)
  end
 end
 -- remove initial matches
 for pass=1,10 do
  local found=false
  for x=1,gw do
   for y=1,gh do
    while has_match_at(x,y) do
     grid[x][y].c=flr(rnd(ncols))+1
     found=true
    end
   end
  end
  if not found then break end
 end
end

function new_gem(x,y)
 return {c=flr(rnd(ncols))+1,x=x,y=y,
  dx=0,dy=0,falling=false,ft=0,
  clearing=false,ct=0,pt=nil}
 -- pt: nil=normal, 1=bomb, 2=stripe, 3=color bomb
end

function has_match_at(x,y)
 local c=grid[x][y].c
 if c==0 then return false end
 -- horizontal
 local cnt=1
 for i=x-1,1,-1 do
  if grid[i][y].c==c then cnt+=1 else break end
 end
 for i=x+1,gw do
  if grid[i][y].c==c then cnt+=1 else break end
 end
 if cnt>=3 then return true end
 -- vertical
 cnt=1
 for i=y-1,1,-1 do
  if grid[x][i].c==c then cnt+=1 else break end
 end
 for i=y+1,gh do
  if grid[x][i].c==c then cnt+=1 else break end
 end
 return cnt>=3
end

-- check for any valid move
function has_valid_move()
 for x=1,gw do
  for y=1,gh do
   -- try swap right
   if x<gw then
    swap_cells(x,y,x+1,y)
    if has_match_at(x,y) or has_match_at(x+1,y) then
     swap_cells(x,y,x+1,y)
     return true
    end
    swap_cells(x,y,x+1,y)
   end
   -- try swap down
   if y<gh then
    swap_cells(x,y,x,y+1)
    if has_match_at(x,y) or has_match_at(x,y+1) then
     swap_cells(x,y,x,y+1)
     return true
    end
    swap_cells(x,y,x,y+1)
   end
  end
 end
 return false
end

function swap_cells(x1,y1,x2,y2)
 local t=grid[x1][y1]
 grid[x1][y1]=grid[x2][y2]
 grid[x2][y2]=t
 grid[x1][y1].x=x1
 grid[x1][y1].y=y1
 grid[x2][y2].x=x2
 grid[x2][y2].y=y2
end

-- find and mark matches, returns matched set, count, and groups for power-ups
function find_matches()
 local matched={}
 local count=0
 local groups={} -- {len,cx,cy,dir} for power-up spawning
 -- horizontal
 for y=1,gh do
  local run=1
  for x=2,gw do
   if grid[x][y].c==grid[x-1][y].c and grid[x][y].c>0 then
    run+=1
   else
    if run>=3 then
     for i=x-run,x-1 do
      matched[i..","..y]=true
      count+=1
     end
     add(groups,{len=run,cx=flr(x-run/2),cy=y,dir="h"})
    end
    run=1
   end
  end
  if run>=3 then
   for i=gw-run+1,gw do
    matched[i..","..y]=true
    count+=1
   end
   add(groups,{len=run,cx=flr(gw-run/2+1),cy=y,dir="h"})
  end
 end
 -- vertical
 for x=1,gw do
  local run=1
  for y=2,gh do
   if grid[x][y].c==grid[x][y-1].c and grid[x][y].c>0 then
    run+=1
   else
    if run>=3 then
     for i=y-run,y-1 do
      matched[x..","..i]=true
      count+=1
     end
     add(groups,{len=run,cx=x,cy=flr(y-run/2),dir="v"})
    end
    run=1
   end
  end
  if run>=3 then
   for i=gh-run+1,gh do
    matched[x..","..i]=true
    count+=1
   end
   add(groups,{len=run,cx=x,cy=flr(gh-run/2+1),dir="v"})
  end
 end
 return matched,count,groups
end

function clear_matches(matched,groups)
 local pup_spawns={} -- track power-up spawn positions
 -- determine power-up spawns from groups
 if groups and not has_mod(1) then
  -- bomb-heavy: lower thresholds by 1
  local bh=has_mod(5) and 1 or 0
  for g in all(groups) do
   if g.len>=6-bh then
    add(pup_spawns,{x=g.cx,y=g.cy,pt=3})
   elseif g.len>=5-bh then
    add(pup_spawns,{x=g.cx,y=g.cy,pt=2})
   elseif g.len>=4-bh then
    add(pup_spawns,{x=g.cx,y=g.cy,pt=1})
   end
  end
 end
 -- build spawn lookup
 local spawn_at={}
 for s in all(pup_spawns) do
  spawn_at[s.x..","..s.y]=s.pt
 end
 local had_pup=false
 for k,_ in pairs(matched) do
  local parts=split(k,",")
  local x=tonum(parts[1])
  local y=tonum(parts[2])
  if x and y and grid[x] and grid[x][y] then
   -- check if power-up gem being cleared (activate it)
   if grid[x][y].pt then
    activate_powerup(x,y)
    had_pup=true
   end
   -- spawn particles
   local gc=grid[x][y].c
   local px=gox+(x-1)*gs+gs/2
   local py=goy+(y-1)*gs+gs/2
   for i=1,3 do
    add(particles,{x=px,y=py,
     dx=rnd(4)-2,dy=rnd(4)-2,
     life=15+rnd(10),
     c=colors[gc] or 7})
   end
   -- spawn power-up or clear
   if spawn_at[k] then
    local gc2=grid[x][y].c
    grid[x][y].c=gc2
    grid[x][y].pt=spawn_at[k]
    celebrate_pup(x,y,spawn_at[k])
    spawn_at[k]=nil -- only spawn once
   else
    grid[x][y].c=0
    grid[x][y].pt=nil
   end
  end
 end
 return had_pup
end

-- activate a power-up gem's special ability
function activate_powerup(x,y)
 local pt=grid[x][y].pt
 local gc=grid[x][y].c
 _log("powerup_activate:"..pt.." at:"..x..","..y)
 if pt==1 then total_bombs+=1
 elseif pt==2 then total_stripes+=1
 elseif pt==3 then total_cbombs+=1
 end
 if pt==1 then
  -- bomb: clear 3x3 area
  for dx=-1,1 do
   for dy=-1,1 do
    local nx,ny=x+dx,y+dy
    if nx>=1 and nx<=gw and ny>=1 and ny<=gh then
     spawn_clear_fx(nx,ny)
     if grid[nx][ny].pt then
      -- chain: activate neighboring power-ups
      local pt2=grid[nx][ny].pt
      grid[nx][ny].pt=nil
      grid[nx][ny].c=0
      -- delayed chain handled by cascade
     end
     grid[nx][ny].c=0
     grid[nx][ny].pt=nil
    end
   end
  end
  shake=6
  sfx(4)
 elseif pt==2 then
  -- stripe: clear row + column
  for i=1,gw do
   spawn_clear_fx(i,y)
   grid[i][y].c=0
   grid[i][y].pt=nil
  end
  for i=1,gh do
   spawn_clear_fx(x,i)
   grid[x][i].c=0
   grid[x][i].pt=nil
  end
  shake=6
  sfx(4)
 elseif pt==3 then
  -- color bomb: clear all gems of matched color
  -- find adjacent gem color to target
  local tc=0
  for dx=-1,1 do
   for dy=-1,1 do
    if not(dx==0 and dy==0) then
     local nx,ny=x+dx,y+dy
     if nx>=1 and nx<=gw and ny>=1 and ny<=gh and grid[nx][ny].c>0 then
      tc=grid[nx][ny].c
      break
     end
    end
    if tc>0 then break end
   end
   if tc>0 then break end
  end
  if tc>0 then
   for gx=1,gw do
    for gy=1,gh do
     if grid[gx][gy].c==tc then
      spawn_clear_fx(gx,gy)
      grid[gx][gy].c=0
      grid[gx][gy].pt=nil
     end
    end
   end
  end
  shake=8
  sfx(4)
 end
end

-- spawn explosion particles at grid position
function spawn_clear_fx(x,y)
 if grid[x][y].c<=0 then return end
 local px=gox+(x-1)*gs+gs/2
 local py=goy+(y-1)*gs+gs/2
 local gc=grid[x][y].c
 for i=1,4 do
  add(particles,{x=px,y=py,
   dx=rnd(6)-3,dy=rnd(6)-3,
   life=20+rnd(10),
   c=colors[gc] or 7})
 end
end

-- celebrate power-up gem creation
function celebrate_pup(x,y,pt)
 local px=gox+(x-1)*gs+gs/2
 local py=goy+(y-1)*gs+gs/2
 local names={"bomb!","stripe!","colorful!"}
 local cols={8,12,14}
 local sfxn={6,7,8}
 -- particles: 6-8 larger ones
 for i=1,7 do
  add(particles,{x=px,y=py,
   dx=rnd(6)-3,dy=rnd(6)-3,
   life=25+rnd(10),
   c=cols[pt] or 7})
 end
 -- float text
 add_float(names[pt] or "power!",px-10,py-10,cols[pt] or 14)
 -- screen shake + sfx
 shake=max(shake,3)
 sfx(sfxn[pt] or 6)
 -- score bonus
 add_score(50)
 pups_made+=1
 _log("power_up_created:"..names[pt])
end

function apply_gravity()
 local moved=false
 for x=1,gw do
  for y=gh,2,-1 do
   if grid[x][y].c==0 then
    -- find gem above
    for y2=y-1,1,-1 do
     if grid[x][y2].c>0 then
      grid[x][y].c=grid[x][y2].c
      grid[x][y].pt=grid[x][y2].pt
      grid[x][y2].c=0
      grid[x][y2].pt=nil
      moved=true
      break
     end
    end
   end
  end
  -- fill top
  for y=1,gh do
   if grid[x][y].c==0 then
    grid[x][y].c=flr(rnd(ncols))+1
    grid[x][y].pt=nil
    moved=true
   end
  end
 end
 return moved
end

function add_score(pts)
 if has_mod(6) then pts=flr(pts*0.7) end
 score+=pts
 return pts
end

function add_float(txt,x,y,c)
 add(float_texts,{txt=txt,x=x,y=y,c=c,life=40})
end

-- cascade milestone celebrations
-- milestones: 3+(bit0), 5+(bit1), 10+(bit2), 15+(bit3)
function check_casc_milestone()
 local ms={{3,1,10,100},{5,2,12,250},{10,4,7,500},{15,8,13,1000}}
 for m in all(ms) do
  local th,bit,col,bonus=m[1],m[2],m[3],m[4]
  if casc>=th and band(casc_ms,bit)==0 then
   casc_ms=bor(casc_ms,bit)
   local bpts=add_score(bonus)
   _log("cascade_milestone:"..th)
   _log("milestone_bonus:"..bpts)
   -- visual: shake scales with tier
   shake=min(4+th,15)
   -- particles: more and bigger for higher tiers
   local np=th*3
   for i=1,np do
    add(particles,{x=64,y=64,dx=rnd(10)-5,dy=rnd(10)-5,life=25+rnd(20),c=col})
   end
   add_float("cascade x"..casc.."! +"..bonus,10,20,col)
   sfx(th>=10 and 5 or 4)
  end
 end
 -- track big cascades (3+)
 if casc==3 then
  casc_big+=1
 end
end

-- start game
function start_game()
 score,combo,level=0,0,1
 cx,cy=1,1
 sel=nil
 swapping,falling,checking=false,false,false
 no_moves=false
 paused=false
 particles={}
 float_texts={}
 shake=0
 combo_timer=0
 -- set colors by difficulty
 if diff==1 then
  ncols=8 target=500
 elseif diff==2 then
  ncols=7 target=1000
 else
  ncols=6 target=1500
 end
 -- modifier overrides
 if has_mod(2) then ncols=2 -- monochrome
 elseif has_mod(4) then ncols=3 -- limited colors
 end
 tbonus=0
 casc,casc_max,casc_total,casc_ms,casc_big=0,0,0,0,0
 pups_made=0
 if gmode==2 then
  timer=90*30 -- 90 seconds at 30fps
 else
  timer=0
 end
 -- endless mode: progressive vars
 e_bg=1 -- background color shifts
 make_grid()
 state="play"
 _log("state:play")
 _log("difficulty:"..diff)
 _log("mods:"..mods)
 if gmode==3 then _log("mode:endless") end
end

-- update functions
function _update()
 if state=="menu" then update_menu()
 elseif state=="mode" then update_mode()
 elseif state=="diff" then update_diff()
 elseif state=="mods" then update_mods()
 elseif state=="play" then update_play()
 elseif state=="gameover" then update_gameover()
 elseif state=="name_entry" then update_name()
 elseif state=="achs" then update_achs()
 elseif state=="help" then update_help()
 end
 -- update particles
 for i=#particles,1,-1 do
  local p=particles[i]
  p.x+=p.dx p.y+=p.dy
  p.dy+=0.1
  p.life-=1
  if p.life<=0 then deli(particles,i) end
 end
 -- update achievement popup
 if ach_popup then
  ach_popup.t-=1
  if ach_popup.t<=0 then ach_popup=nil end
 end
 -- update float texts
 for i=#float_texts,1,-1 do
  local f=float_texts[i]
  f.y-=0.5
  f.life-=1
  if f.life<=0 then deli(float_texts,i) end
 end
 if shake>0 then shake-=1 end
end

function update_menu()
 local b=test_input()
 if b&16>0 then -- O button
  -- set mode_sel from gmode (inverse of mode_map)
  local rmap={[1]=1,[3]=2,[2]=3}
  mode_sel=rmap[gmode] or 1
  state="mode"
  _log("state:mode")
  sfx(0)
 end
 if b&32>0 then -- X button = achievements
  ach_scroll=0
  state="achs"
  _log("state:achs")
 end
 if b&4>0 then -- up = help
  help_scr=0
  state="help"
  _log("state:help")
 end
end

ach_scroll=0

function update_achs()
 local b=test_input()
 if b&4>0 then ach_scroll=max(0,ach_scroll-1) end
 if b&8>0 then ach_scroll=min(max(0,#ach_defs-6),ach_scroll+1) end
 if b&32>0 or b&16>0 then
  state="menu"
  _log("state:menu")
 end
end

help_scr=0

function update_help()
 local b=test_input()
 if b&4>0 then help_scr=max(0,help_scr-1) end
 if b&8>0 then help_scr=min(8,help_scr+1) end
 if b&32>0 or b&16>0 then
  state="menu"
  _log("state:menu")
 end
end

-- mode display order: 1=normal,2=endless,3=time attack
-- gmode values: 1=normal,2=time attack,3=endless
mode_sel=1
mode_map={1,3,2} -- display->gmode

function update_mode()
 local b=test_input()
 if b&4>0 then mode_sel=max(1,mode_sel-1) sfx(1) end
 if b&8>0 then mode_sel=min(3,mode_sel+1) sfx(1) end
 if b&16>0 then
  gmode=mode_map[mode_sel]
  state="diff"
  _log("state:diff")
  local mnames={"normal","timeattack","endless"}
  _log("mode:"..mnames[gmode])
  sfx(0)
 end
 if b&32>0 then
  state="menu"
  _log("state:menu")
 end
end

function update_diff()
 local b=test_input()
 if b&4>0 then diff=max(1,diff-1) sfx(1) end
 if b&8>0 then diff=min(3,diff+1) sfx(1) end
 if b&16>0 then
  mod_cur=1
  mods=0
  state="mods"
  _log("state:mods")
  sfx(0)
 end
 if b&32>0 then
  state="menu"
  _log("state:menu")
 end
end

function update_mods()
 local b=test_input()
 if b&4>0 then mod_cur=max(1,mod_cur-1) sfx(1) end
 if b&8>0 then mod_cur=min(7,mod_cur+1) sfx(1) end
 -- toggle modifier with O
 if b&16>0 then
  local bit=shl(1,mod_cur-1)
  if band(mods,bit)>0 then
   -- deactivate
   mods=bxor(mods,bit)
   sfx(1)
  elseif mod_count()<3 then
   -- activate (max 3)
   mods=bor(mods,bit)
   sfx(0)
  else
   sfx(3) -- error: max 3
  end
  _log("mods:"..mods)
 end
 -- X to confirm and start
 if b&32>0 then
  start_game()
  sfx(0)
 end
end

function update_play()
 if paused then
  local b=test_input()
  if b&32>0 then
   paused=false
   _log("unpause")
  end
  if b&16>0 then
   if gmode==3 then
    save_ach()
    state="gameover"
    _log("state:gameover")
    _log("final_score:"..score)
    sfx(5)
   else
    state="menu"
    _log("state:menu")
   end
  end
  return
 end

 -- time attack timer
 if gmode==2 and not swapping and not falling then
  timer-=1
  if timer<=0 then
   timer=0
   tbonus=0
   save_ach()
   state="gameover"
   _log("state:gameover")
   _log("time_up")
   _log("final_score:"..score)
   sfx(5)
   return
  end
 end

 -- combo decay (faster in endless at higher levels)
 local cdecay=1
 if gmode==3 then cdecay=1+level*0.05 end
 if combo_timer>0 then
  combo_timer-=cdecay
  if combo_timer<=0 then
   -- perfect scorer: penalty if combo < 3
   if has_mod(7) and combo>0 and combo<3 then
    score=max(0,score-50)
    add_float("-50!",64,40,8)
    _log("perfect_penalty")
   end
   combo=0
  end
 end

 -- handle animations
 if swapping then
  swap_t+=has_mod(3) and 2 or 1
  if swap_t>=6 then
   -- complete swap
   swap_cells(swap_from[1],swap_from[2],swap_to[1],swap_to[2])
   -- check if valid
   local m,cnt,grps=find_matches()
   if cnt==0 then
    -- swap back
    swap_cells(swap_from[1],swap_from[2],swap_to[1],swap_to[2])
    sfx(3)
   else
    -- process matches
    casc,casc_ms=0,0 -- reset cascade on new move
    combo+=1
    combo_timer=45
    local pts=cnt*10*combo
    local had_pup=clear_matches(m,grps)
    if had_pup then
     pts=flr(pts*1.5)
     _log("powerup_bonus")
    end
    pts=add_score(pts)
    total_gems+=cnt
    check_achs()
    _log("match:"..cnt.." combo:"..combo.." score:"..score)
    shake=4
    sfx(2)
    local mx=gox+(swap_from[1]-1)*gs
    local my=goy+(swap_from[2]-1)*gs
    add_float(pts.."",mx,my,had_pup and 14 or 10)
    if combo>=2 then
     add_float(combo.."x!",64,60,
      combo>=4 and 8 or combo>=3 and 9 or 10)
    end
    if had_pup then
     add_float("power!",64,50,14)
    end
    falling=true
    fall_t=0
   end
   swapping=false
   sel=nil
  end
  return
 end

 if falling then
  fall_t+=has_mod(3) and 2 or 1
  if fall_t>=4 then
   apply_gravity()
   -- check for cascades
   local m,cnt,grps=find_matches()
   if cnt>0 then
    casc+=1
    casc_total+=1
    if casc>casc_max then casc_max=casc end
    combo+=1
    combo_timer=45
    -- cascade multiplier: 1.0 base, +0.5 per cascade level
    local cmult=1+casc*0.5
    local pts=flr((cnt*10*combo+5)*cmult)
    -- cascade bonus on top
    local cbonus=casc*100
    pts+=cbonus
    local had_pup=clear_matches(m,grps)
    if had_pup then
     pts=flr(pts*1.5)
     _log("powerup_cascade_bonus")
    end
    pts=add_score(pts)
    total_gems+=cnt
    check_achs()
    _log("cascade:"..casc)
    _log("cascade_bonus:"..cbonus)
    _log("cascade_match:"..cnt.." combo:"..combo.." score:"..score)
    -- cascade visual: scaled shake + color-coded text
    shake=min(3+casc*2,10)
    sfx(2)
    -- cascade color: white->yellow->orange->red
    local ccol=casc>=4 and 8 or casc>=3 and 9 or casc>=2 and 10 or 7
    add_float("cascade x"..casc.."!",24,30,ccol)
    add_float(pts.."",64,50,had_pup and 14 or 11)
    -- extra particles for cascades
    for i=1,casc*4 do
     add(particles,{x=64,y=64,
      dx=rnd(8)-4,dy=rnd(8)-4,
      life=20+rnd(15),c=ccol})
    end
    -- milestone celebrations
    check_casc_milestone()
    fall_t=0
   else
    falling=false
    -- check level up
    if gmode==1 and score>=target then
     level+=1
     _log("level:"..level)
     target+=500
     ncols=max(5,ncols-1)
     make_grid()
     sfx(4)
     add_float("level "..level.."!",40,60,11)
    elseif gmode==3 then
     -- endless: level = floor(score/1000)+1
     local nl=flr(score/1000)+1
     if nl>level then
      level=nl
      _log("endless_level:"..level)
      check_achs()
      -- every 3 levels: reduce combo timer, fewer colors
      if level%3==1 and level>1 then
       ncols=max(5,ncols-1)
       shake=8
       e_bg=((level\3)%5)+1
       _log("endless_difficulty_up:"..level)
      end
      sfx(4)
      add_float("level "..level.."!",40,60,11)
     end
    end
    -- check no moves
    if not has_valid_move() then
     no_moves=true
     if gmode==2 or gmode==3 then
      -- time attack & endless: reshuffle
      make_grid()
      add_float("reshuffle!",34,60,9)
      sfx(1)
     else
      save_ach()
      state="gameover"
      _log("state:gameover")
      _log("final_score:"..score)
      sfx(5)
     end
    end
   end
  end
  return
 end

 -- player input
 local b=test_input()
 if b&1>0 then cx=max(1,cx-1) end
 if b&2>0 then cx=min(gw,cx+1) end
 if b&4>0 then cy=max(1,cy-1) end
 if b&8>0 then cy=min(gh,cy+1) end

 if b&32>0 then
  paused=true
  _log("pause")
  return
 end

 if b&16>0 then
  if sel then
   -- try swap
   local dx=abs(cx-sel[1])
   local dy=abs(cy-sel[2])
   if (dx==1 and dy==0) or (dx==0 and dy==1) then
    swapping=true
    swap_t=0
    swap_from={sel[1],sel[2]}
    swap_to={cx,cy}
    _log("swap:"..sel[1]..","..sel[2].."->"..cx..","..cy)
    sfx(1)
   elseif cx==sel[1] and cy==sel[2] then
    sel=nil -- deselect
   else
    sel={cx,cy} -- reselect
   end
  else
   sel={cx,cy}
   _log("select:"..cx..","..cy)
  end
 end
end

function final_score()
 return score+tbonus
end

function update_gameover()
 local b=test_input()
 if b&16>0 then
  local fs=final_score()
  -- check leaderboard (mode-filtered)
  local mlb=get_mode_lb()
  if #mlb<5 or fs>mlb[#mlb].score then
   state="name_entry"
   name_buf="aaa"
   name_idx=1
   _log("state:name_entry")
  else
   state="menu"
   _log("state:menu")
  end
 end
end

function get_mode_lb()
 local r={}
 for e in all(lb) do
  if (e.mode or 1)==gmode then add(r,e) end
 end
 return r
end

function update_name()
 local b=test_input()
 local ch=tonum(nil)
 -- find current char index
 local cur=sub(name_buf,name_idx,name_idx)
 local ci=1
 for i=1,#name_chars do
  if sub(name_chars,i,i)==cur then ci=i break end
 end
 if b&4>0 then ci=((ci-2)%#name_chars)+1 end
 if b&8>0 then ci=(ci%#name_chars)+1 end
 -- rebuild name
 local nn=""
 for i=1,3 do
  if i==name_idx then
   nn=nn..sub(name_chars,ci,ci)
  else
   nn=nn..sub(name_buf,i,i)
  end
 end
 name_buf=nn

 if b&16>0 then
  name_idx+=1
  if name_idx>3 then
   -- save to leaderboard
   add(lb,{score=final_score(),name=name_buf,mode=gmode})
   -- sort descending
   for i=1,#lb do
    for j=i+1,#lb do
     if lb[j].score>lb[i].score then
      lb[i],lb[j]=lb[j],lb[i]
     end
    end
   end
   -- trim to 5 per mode
   local mcnt={0,0,0}
   for i=#lb,1,-1 do
    local m=lb[i].mode or 1
    mcnt[m]+=1
    if mcnt[m]>5 then deli(lb,i) end
   end
   -- persist
   save_lb()
   _log("leaderboard_saved")
   state="menu"
   _log("state:menu")
  end
 end
 if b&32>0 then
  name_idx=max(1,name_idx-1)
 end
end

function save_lb()
 dset(0,lb[1] and lb[1].score or 0)
 for i=1,min(#lb,10) do
  local base=(i-1)*3+1
  dset(base,lb[i].score)
  -- encode name as number
  local nv=0
  for j=1,3 do
   local ch=sub(lb[i].name,j,j)
   for k=1,#name_chars do
    if sub(name_chars,k,k)==ch then
     nv+=((k-1)*(27^(3-j)))
     break
    end
   end
  end
  dset(base+1,nv)
  dset(base+2,lb[i].mode or 1)
 end
 -- clear unused slots
 for i=#lb+1,10 do
  local base=(i-1)*3+1
  dset(base,0)
 end
end

-- draw functions
function _draw()
 local sx,sy=0,0
 if shake>0 then sx=rnd(3)-1 sy=rnd(3)-1 end
 camera(sx,sy)
 local bgc=1
 if gmode==3 and state=="play" then bgc=e_bg end
 cls(bgc)
 if state=="menu" then draw_menu()
 elseif state=="mode" then draw_mode()
 elseif state=="diff" then draw_diff()
 elseif state=="mods" then draw_mods()
 elseif state=="play" then draw_play()
 elseif state=="gameover" then draw_gameover()
 elseif state=="name_entry" then draw_name()
 elseif state=="achs" then draw_achs()
 elseif state=="help" then draw_help()
 end
 -- draw particles
 for p in all(particles) do
  pset(p.x,p.y,p.c)
 end
 -- draw float texts
 for f in all(float_texts) do
  if f.life%4<3 then
   print(f.txt,f.x,f.y,f.c)
  end
 end
 camera(0,0)
end

function draw_menu()
 print("gem match",38,20,10)
 print("match-3 puzzle",30,32,7)
 rectfill(30,50,98,62,5)
 print("press \x97 to start",32,54,10)
 -- count unlocked achievements
 local ac=0
 for i=1,#ach_defs do if ach_unlocked[i] then ac+=1 end end
 print("\x83 help/tutorial",36,68,11)
 print("\x8e achievements ("..ac.."/"..#ach_defs..")",10,76,6)
 -- leaderboard (show current mode)
 local mlb=get_mode_lb()
 if #mlb>0 then
  local mns={"normal","time atk","endless"}
  local mn=mns[gmode] or "normal"
  print("-- "..mn.." scores --",18,86,6)
  for i=1,min(3,#mlb) do
   print(i..". "..mlb[i].name.." "..mlb[i].score,30,94+i*8,7)
  end
 end
end

function draw_achs()
 print("achievements",30,4,10)
 local ac=0
 for i=1,#ach_defs do if ach_unlocked[i] then ac+=1 end end
 print(ac.."/"..#ach_defs.." unlocked",34,14,6)
 for i=1,min(7,#ach_defs-ach_scroll) do
  local idx=i+ach_scroll
  local a=ach_defs[idx]
  local y=22+(i-1)*14
  local unlocked=ach_unlocked[idx]
  local nc=unlocked and 10 or 5
  local dc=unlocked and 7 or 5
  local ic=unlocked and "\x96" or "\x97"
  rectfill(4,y,124,y+12,unlocked and 1 or 0)
  rect(4,y,124,y+12,nc)
  print(ic.." "..a.n,8,y+2,nc)
  print(a.d,60,y+2,dc)
 end
 if ach_scroll>0 then print("\x83",60,20,6) end
 if ach_scroll<#ach_defs-7 then print("\x84",60,122,6) end
 print("\x8e/\x97 back",44,122,6)
end

function draw_help()
 -- help content as scrollable pages
 local pages={
  {t="how to play",c=10,lines={
   "select a gem with \x97",
   "select adjacent gem to swap",
   "match 3+ same-color gems",
   "matched gems clear for pts",
   "combos: chain matches fast",
   "for 2x, 3x multipliers!"}},
  {t="power-ups",c=11,lines={
   "match 4: \x96bomb\x96 3x3 blast",
   "match 5: \x96stripe\x96 row+col",
   "match 6: \x96color bomb\x96",
   "clears all gems of a color",
   "power-ups chain together!"}},
  {t="cascades",c=9,lines={
   "when gems fall after a clear",
   "new matches form auto!",
   "each cascade = bonus pts",
   "+0.5x multiplier per level",
   "+100 bonus per cascade!"}},
  {t="game modes",c=12,lines={
   "normal: reach score targets",
   "endless: survive forever!",
   "  levels up every 1000pts",
   "time atk: 90s score rush"}},
  {t="difficulty",c=14,lines={
   "easy: 8 colors, 500 target",
   "normal: 7 colors, 1000 tgt",
   "hard: 6 colors, 1500 tgt",
   "fewer colors = harder!"}},
  {t="modifiers (1/2)",c=8,lines={
   "up to 3 optional mods:",
   "no powerups: no pup gems",
   "monochrome: only 2 colors",
   "speed run: 30% faster anim",
   "limited: start w/ 3 colors"}},
  {t="modifiers (2/2)",c=8,lines={
   "bomb heavy: 1.5x pup freq",
   "score pen: scores x0.7",
   "perfect: combo resets if<3",
   "mods stack for challenge!"}},
  {t="tips",c=10,lines={
   "plan swaps for cascades",
   "keep combos alive!",
   "power-ups = massive pts",
   "x to pause during play",
   "good luck!"}},
 }
 -- clamp scroll
 local pg=mid(1,help_scr+1,#pages)
 local p=pages[pg]
 -- header
 print("-- help ("..pg.."/"..#pages..") --",20,2,6)
 rectfill(4,10,124,12,p.c)
 print(p.t,64-#p.t*2,16,p.c)
 -- content
 for i,ln in ipairs(p.lines) do
  print(ln,6,28+(i-1)*12,7)
 end
 -- nav
 if pg>1 then print("\x83 prev",4,120,6) end
 if pg<#pages then print("next \x84",90,120,6) end
 print("\x97/\x8e back",40,120,6)
end

function draw_mode()
 print("game mode",38,20,10)
 local modes={"normal","endless","time attack"}
 local descs={"reach target scores","survive forever!","90 second score rush"}
 for i=1,3 do
  local c=6
  if i==mode_sel then c=10 end
  print(modes[i],42,32+i*14,c)
  print(descs[i],22,40+i*14,5)
 end
 print("\x83/\x84 select  \x97 confirm",14,110,6)
end

function draw_diff()
 print("difficulty",34,20,10)
 local names={"easy","normal","hard"}
 local descs={"8 colors, 500 pts","7 colors, 1000 pts","6 colors, 1500 pts"}
 for i=1,3 do
  local c=6
  if i==diff then c=10 end
  print(names[i],50,40+i*14,c)
  print(descs[i],26,48+i*14,5)
 end
 print("\x83/\x84 select  \x97 confirm",14,110,6)
end

function draw_mods()
 print("challenge modifiers",18,4,10)
 print("select up to 3 (optional)",8,14,6)
 for i=1,7 do
  local y=22+(i-1)*14
  local on=has_mod(i)
  local c=6
  if i==mod_cur then c=10 end
  local icon=on and "\x96" or "\x97"
  rectfill(4,y,124,y+12,on and 1 or 0)
  if i==mod_cur then rect(4,y,124,y+12,10) end
  print(icon.." "..mod_defs[i].n,8,y+2,c)
  print(mod_defs[i].d,60,y+2,on and 11 or 5)
 end
 print(mod_count().."/3 active  \x97 toggle  \x8e start",4,122,mod_count()>=3 and 8 or 6)
end

function draw_play()
 -- ui bar
 rectfill(0,0,127,15,0)
 print("score:"..score,2,2,7)
 if gmode==2 then
  -- time attack: show timer
  local secs=flr(timer/30)
  local m=flr(secs/60)
  local s=secs%60
  local ts=tostr(m)..":"..( s<10 and "0"..tostr(s) or tostr(s))
  local tc=7
  if secs<=10 then tc=8 end
  if secs<=5 then tc=flr(t()*4)%2==0 and 8 or 7 end
  print(ts,90,2,tc)
  print("time attack",34,9,9)
 elseif gmode==3 then
  print("level "..level,86,2,11)
  print("endless",44,9,12)
 else
  print("lvl:"..level,90,2,7)
  print("goal:"..target,2,9,6)
 end
 if combo>1 then
  print(combo.."x",58,2,10)
 end
 if casc>0 then
  local ccol=casc>=4 and 8 or casc>=3 and 9 or casc>=2 and 10 or 7
  print("casc:"..casc,90,9,ccol)
 end
 -- active modifiers display
 if mods>0 then
  local mx=2
  for i=1,7 do
   if has_mod(i) then
    print(mod_defs[i].s,mx,128-6,8)
    mx+=#mod_defs[i].s*4+4
   end
  end
 end

 -- draw grid bg
 rectfill(gox-1,goy-1,gox+gw*gs,goy+gh*gs,0)

 -- draw gems
 for x=1,gw do
  for y=1,gh do
   local g=grid[x][y]
   if g.c>0 then
    local px=gox+(x-1)*gs
    local py=goy+(y-1)*gs
    local col=colors[g.c] or 7
    -- gem body
    rectfill(px+1,py+1,px+gs-2,py+gs-2,col)
    -- gem highlight
    rectfill(px+2,py+2,px+4,py+3,7)
    -- gem border
    rect(px+1,py+1,px+gs-2,py+gs-2,col-1>0 and col-1 or 5)
    -- power-up visuals
    if g.pt==1 then
     -- bomb: x pattern
     local cx2=px+gs/2-1
     local cy2=py+gs/2-1
     line(px+2,py+2,px+gs-3,py+gs-3,0)
     line(px+gs-3,py+2,px+2,py+gs-3,0)
     pset(cx2,cy2,7)
    elseif g.pt==2 then
     -- stripe: horizontal lines
     line(px+2,py+3,px+gs-3,py+3,0)
     line(px+2,py+gs-4,px+gs-3,py+gs-4,0)
    elseif g.pt==3 then
     -- color bomb: sparkle/diamond
     local cx2=px+gs/2-1
     local cy2=py+gs/2-1
     local fl=flr(t()*6)%3
     pset(cx2,py+1,7+fl)
     pset(cx2,py+gs-2,7+fl)
     pset(px+1,cy2,7+fl)
     pset(px+gs-2,cy2,7+fl)
     pset(cx2,cy2,7)
    end
   end
  end
 end

 -- draw cursor
 local cpx=gox+(cx-1)*gs
 local cpy=goy+(cy-1)*gs
 local ct=t()*4
 local cb=sin(ct)*2
 rect(cpx-1+cb,cpy-1+cb,cpx+gs-1-cb,cpy+gs-1-cb,7)

 -- draw selection
 if sel then
  local spx=gox+(sel[1]-1)*gs
  local spy=goy+(sel[2]-1)*gs
  rect(spx,spy,spx+gs-1,spy+gs-1,10)
  rect(spx-1,spy-1,spx+gs,spy+gs,10)
 end

 -- pause overlay
 if paused then
  rectfill(20,45,108,85,0)
  rect(20,45,108,85,7)
  print("paused",48,52,7)
  print("\x8e resume",40,64,6)
  print("\x97 quit",44,74,6)
 end
 -- achievement popup
 if ach_popup then
  local ay=2
  if ach_popup.t>80 then ay=2-(ach_popup.t-80)*2
  elseif ach_popup.t<10 then ay=2-(10-ach_popup.t)*2
  end
  rectfill(8,ay,120,ay+14,0)
  rect(8,ay,120,ay+14,10)
  print("\x96 "..ach_popup.n.." \x96",14,ay+2,10)
  print("achievement unlocked!",14,ay+9,6)
 end
end

function draw_gameover()
 rectfill(15,20,113,110,0)
 rect(15,20,113,110,7)
 if gmode==2 then
  print("time's up!",36,26,8)
  print("score: "..score,38,38,10)
  print("time bonus: +"..tbonus,26,48,9)
  print("final: "..(score+tbonus),34,58,10)
  print("combo max: "..combo,30,68,11)
 elseif gmode==3 then
  print("endless over!",30,26,12)
  print("survived "..level.." levels",22,38,11)
  print("score: "..score,38,48,10)
  print("combo max: "..combo,30,58,11)
 else
  if no_moves then
   print("no moves left!",28,26,8)
  else
   print("game over",38,26,8)
  end
  print("score: "..score,38,38,10)
  print("level: "..level,38,48,7)
  print("combo max: "..combo,30,58,11)
 end
 -- cascade stats
 local cy2=gmode==2 and 78 or 68
 if casc_max>0 or casc_total>0 then
  print("max cascade: "..casc_max,26,cy2,9)
  print("total cascades: "..casc_total,20,cy2+10,9)
 end
 -- show active modifiers
 if mods>0 then
  local ms=""
  for i=1,7 do
   if has_mod(i) then
    if #ms>0 then ms=ms.." " end
    ms=ms..mod_defs[i].s
   end
  end
  print("mods: "..ms,18,cy2+22,8)
 end
 print("press \x97",46,100,6)
end

function draw_name()
 rectfill(15,30,113,98,0)
 rect(15,30,113,98,7)
 print("new high score!",26,36,10)
 print("score: "..final_score(),38,48,7)
 print("enter name:",32,60,6)
 for i=1,3 do
  local ch=sub(name_buf,i,i)
  local x=48+(i-1)*12
  local c=6
  if i==name_idx then c=10 end
  print(ch,x,72,c)
  if i==name_idx then
   print("\x83",x,65,c)
   print("\x84",x,79,c)
  end
 end
 print("\x97 next  \x8e back",28,90,6)
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
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
111111111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa11111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111177777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777711111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
11111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111111111111
111111111111111111110bbbbbbbbbbb0ccccccccccc0ddddddddddd0888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0cccc1111111111111111111
111111111111111111110bbbbbbbbbbb0ccccccccccc0ddddddddddd0888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0cccc1111111111111111111
111111111111111111110bbbbbbbbbbb0ccccccccccc0ddddddddddd0888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0cccc1111111111111111111
111111111111111111110bbbbbbbbbbb0ccccccccccc0ddddddddddd0888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0cccc1111111111111111111
111111111111111111110bbbbbbbbbbb0ccccccccccc0ddddddddddd0888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0cccc1111111111111111111
111111111111111111110bbbbbbbbbbb0ccccccccccc0ddddddddddd0888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0cccc1111111111111111111
111111111111111111110bbbbbbbbbbb0ccccccccccc0ddddddddddd0888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0cccc1111111111111111111
111111111111111111110bbbbbbbbbbb0ccccccccccc0ddddddddddd0888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0cccc1111111111111111111
111111111111111111110bbbbbbbbbbb0ccccccccccc0ddddddddddd0888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0cccc1111111111111111111
11111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
111111111111111111110888888888880999999999990aaaaaaaaaaa0bbbbbbbbbbb0ccccccccccc0ddddddddddd088888888888099991111111111111111111
11111111111111111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001111111111111111111
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
__sfx__
000200001805018050180002400024000240000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001c0501c050200502405028050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300002405024050280502c0503005030050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001505012050100500e0500c0500a050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500001c0502005024050280502c050300503405038050000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500002405020050180501005008050060500405003050000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001c0502005024050280502c0502c0500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300002405028050300503405038050380500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002c050300503405038050380503c050380503405030050000000000000000000000000000000000000000000000000000000000000000000000000000000000
