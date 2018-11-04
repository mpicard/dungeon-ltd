pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- dungeon ltd

--[[
 -background
 -sprites
 -sfx more
 -particles
]]

game={
 actors={},
 menu={t=0},
 game={t=0},
 gameover={t=0}
}

function _init()
 printh("~~ new game ~~")
 init_blending(6)
 init_palettes(16)
 shake=0
 fade=1
 debug=""
 state="menu"
 music(0)
end

function _update()
 game[state]:update()
 if p1 then
 debug=p1.state.."\n"
  ..e1.state.."\n"
  --..e2.state.."\n"
  ..state
 end
end

function start_game()
 music(1)
 shake=0
 fade=1
 debug=""
 state="game"
 torch=light:new({
  pos=v(59,51),
  bri=2
 })
 p1=player:new({
  health=10,
  name="player",
  pos=v(44,50)
 })
 e1=enemy:new({
  name="enemy1",
  pos=v(70,30)
 })
 -- e2=enemy:new({
 --  name="enemy2",
 --  pos=v(100,30)
 -- })
 game.t=0
 -- game.actors={p1,e1,e2}
 game.actors={p1,e1}
 game:next_turn()
end

function _draw()
 cls()
 pal()
 game[state]:draw()

 if fade!=0 then
  fade_pal()
 end
 if debug!="" then
  print(debug,0,0,7)
 end
end

function fade_in()
 if fade!=0 then
  fade-=0.05
  if fade<0 then fade=0 end
 end
end

function fade_pal()
 local kmax,col,j,k
 local p=flr(mid(0,fade,0.999)*100)
 local dpal={0,1,1,2,1,13,6,4,4,9,3,12,1,13,14}
 for j=1,15 do
  col=j
  kmax=(p+(j*1.46))/22
  for k=1,kmax do
   col=dpal[col]
  end
  pal(j,col,1)
 end
end

function fade_out()
 if fade!=0 then
  fade-=0.05
  if fade<0 then
   fade=0
  end
 end
end

function shake_screen()
 local x=shake*(rnd(4)-2)
 local y=shake*(rnd(4)-2)
 camera(x,y)
 shake*=0.8
 if shake<0.05 then
  shake=0
 end
end

-->8
-- utils

function assign(obj,props)
 obj=obj or {}
 for k,v in pairs(props) do
  obj[k]=v
 end
 return obj
end

vector={}
function vector.__add(a,b)
 return v(a.x+b.x,a.y+b.y)
end
function vector.__sub(a,b)
 return v(a.x-b.x,a.y-b.y)
end
function vector.__mul(a,a)
 return v(a.x*a,a.y*a)
end
function vector.__div(a,a)
 return v(a.x/a,a.y/a)
end
function vector:flr()
 return v(flr(self.x),flr(self.y))
end
vector.__index=vector
-- new vector
function v(x,y)
 local vec={x=x,y=y}
 setmetatable(vec,vector)
 return vec
end

-- class
function kind(obj)
 obj=obj or {}
 setmetatable(obj,{__index=obj.extends})
 obj.new=function(self,o)
  o=assign(o,{kind=obj})
  setmetatable(o,{__index=obj})
  if (obj.create) o:create()
  return o
 end
 return obj
end

function crect(x1,y1,x2,y2,fn)
 x1,x2=max(x1,0),mid(x2,127)
 y1,y2=max(y1,0),min(y2,127)
 if (x2<x1 or y2<y1) return
 for y=y1,y2 do
  fn(x1,x2,y)
 end
end

function zspr(n,w,h,dx,dy,dz)
 sx = shl(band(n,0x0f),3)
 sy = shr(band(n,0xf0),1)
 sw = shl(w,3)
 sh = shl(h,3)
 dw = sw * dz
 dh = sh * dz
 sspr(sx,sy,sw,sh,dx,dy,dw,dh)
end
-->8
-- entity system

entities={}
entities_with={}
components={"draw","enemy"}

entity=kind({
 state="s_default",t=0
})

e_id=1
function entity:create()
 if not self.name then
  self.name="e"..e_id
  e_id+=1
 end
 entities[self.name]=self
 update_with(self,add)
end

function update_with(e,fn)
 for _,c in pairs(components) do
  if e[c] then
   local a=entities_with[c] or {}
   fn(a,e)
   entities_with[c]=a
  end
 end
end

function update_entities()
 for i,e in pairs(entities) do
  local fn=e[e.state]
  local r=fn and fn(e,e.t) or nil

  if r then
   if r==true then
    entities[i]=nil
    update_with(e,del)
   else
    assign(e,{state=r,t=0})
   end
  else
   e.t+=1
  end
 end
end

function draw_entities()
 ysort={}
 for e in all(entities_with.draw) do
  local y=e.pos and flr(e.pos.y) or 130
  ysort[y]=ysort[y] or {}
  add(ysort[y],e)
 end
 for y=clipbox.y1,clipbox.y2 do
  for e in all(ysort[y]) do
   reset_palette()
   e:draw(e.t)
  end
  reset_palette()
 end
end
-->8
-- cards

card=kind({
 extends=entity,
 size=v(28,30),
 selected=false,
 col=7,
 target=nil
})

c_attack=kind({
 extends=card,
 card="attack",
 col=8
})

c_torch=kind({
 extends=card,
 card="torch"
})

c_heal=kind({
 extends=card,
 card="heal",
 col=3
})

c_snub=kind({
 extends=card,
 card="snub"
})

cards={c_attack,c_torch,c_heal}
player_cards={c_attack,c_torch,c_heal}
enemy_cards={c_attack,c_heal,c_snub}

function card:s_discard()
 return true
end

function card:reduce_torch()
 if self.parent.torch then
  self.parent.torch=max(self.parent.torch-1,0)
 end
end

function c_attack:s_exec()
 local p,t=self.parent,self.target
 local to=p.torch or t.torch
 local dmg=0.1*rnd(to)+1
 if p.name=="player" then
  dmg*=2
  shake+=2
 end
 if dmg>=5 then
  -- crit!
 end
 dmg=flr(dmg)
 t.health-=dmg
 t.health=mid(0,t.health,10)
 if t.health<=0 then
  t.state="s_dead"
 end
 self:reduce_torch()
 sfx(0)
 game:check_is_over()
 self.state="s_discard"
end

function c_torch:s_exec()
 -- printh("torch-- "..self.parent.name)
 torch.bri=mid(0,torch.bri+1,10)
 self.state="s_discard"
end

function c_heal:s_exec()
 -- printh("heal++ "..self.parent.name)
 local dmg=max(1,rnd(4))
 self.parent.health=min(self.parent.health+flr(dmg),10)
 self:reduce_torch()
 self.state="s_discard"
end

function c_snub:s_exec()
 -- printh("snub "..self.parent.name..">"..self.target.name)
 local dmg=flr(max(1,rnd(4)))
 torch.bri=mid(0,torch.bri-dmg,10)
 self.state="s_discard"
end

function pick_card()
 local i=flr(rnd(#player_cards))+1
 return player_cards[i]:new()
end

function card:draw()
 local p,s,sl=self.pos,self.size,self.selected
 if p!=nil then
  if sl then
   p+=v(0,-4)
  end
  rectfill(p.x,p.y,p.x+s.x,p.y+s.y,self.col)
  if sl then
   print("🅾️ use",p.x+1,p.y+s.y-11,0)
   print("❎ disc",p.x+1,p.y+s.y-5,0)
  end
  --debugging
  p+=v((self.size.x-#self.card*4)/2+1,2)
  print(self.card,p.x,p.y,0)
 end
end

-->8
-- player

actor=kind({
 extends=entity,
 col=7,
 pos=v(0,0),
 hand={},
 health=10
})

function actor:s_dead()
 game:check_is_over()
 -- printh("dead!"..self.name)
 sfx(1)
 return true -- clean up entitty
end

player=kind({
 extends=actor,
 name="player",
 pos=v(30,40),
 torch=10,
 hand={}
})

function player:draw()
 local p,c=self.pos,self.col
 spr(8,p.x,p.y,2,4)
 --hp
 p+=v(2,-4)
 rectfill(p.x,p.y,p.x+9,p.y+1,8)
 if self.health>0 then
  rectfill(p.x,p.y,p.x+self.health-1,p.y+1,11)
 end
 -- debugging
 p+=v(0,-6)
 print(self.health,p.x,p.y,11)
 --
end

function player:s_dead()
 -- printh("player dead!"..self.name)
 sfx(1)
 return true -- clean up entitty
end


function player:s_startturn()
 while #self.hand<3 do
  add(self.hand,c_attack:new())
 end
 for i,c in pairs(self.hand) do
  c.pos=v(i*31-15,90)
  c.do_draw=true
  c.parent=self
 end
 self.i=0
 return "s_selectcard"
end

function player:s_selectcard()
 for i=1,#self.hand do
  self.hand[i].selected=i==self.i+1
 end
 self.card=self.hand[self.i+1]

 if btnp(⬅️) then
  self.i=(self.i-1)%#self.hand
 elseif btnp(➡️) then
  self.i=(self.i+1)%#self.hand
 elseif btnp(🅾️) then
  if self.card.card=="attack" then
   self.i=0
   return "s_selecttarget"
  else
   self.card.state="s_exec"
   return "s_endturn"
  end
 elseif btnp(❎) then
  self.card.state="s_discard"
  return "s_endturn"
 end
end

function player:s_selecttarget()
 local ee=entities_with.enemy
 for i=1,#ee do
   ee[i].selected=i==self.i+1
 end

 if btnp(⬅️) then
  self.i=(self.i-1)%#ee
 elseif btnp(➡️) then
  self.i=(self.i+1)%#ee
 elseif btnp(🅾️) then
  self.card.target=ee[self.i+1]
  self.card.state="s_exec"
  return "s_endturn"
 end
end

function player:s_endturn()
 game:check_is_over()
 del(self.hand,self.card)
 self.card=nil
 --deselect enemies
 local ee=entities_with.enemy
 for i=1,#ee do
  ee[i].selected=false
 end
 game:next_turn()
 return "s_default"
end
-->8
-- enemy

enemy=kind({
 extends=actor,
 enemy=true,
 s=10,
 hand={},
 sleep=10
})

function enemy:s_startturn()
 for i=#self.hand+1,3 do
  --todo more enemy cards
  local c=enemy_cards[flr(rnd(#enemy_cards)+1)]
  -- debugging
  -- local c=c_attack:new()
  add(self.hand,c:new())
 end
 for i=1,#self.hand do
  self.hand[i].parent=self
 end
 return "s_selectcard"
end

function enemy:get_card(c)
 for _,n in pairs(self.hand) do
  if c==n.card then
   return n
  end
 end
end

function enemy:s_selectcard()
 local card
 if self.t>self.sleep then
  -- defensive
  if self.health<4 then
   card=self:get_card("heal")
  -- aggressive
  elseif self.health>7 then
   card=self:get_card("attack")
  end

  if card==nil then
   local i=flr(rnd(#self.hand)+1)
   card=self.hand[i]
  end
  card.parent=self
  card.target=p1
  self.card=card
  return "s_endturn"
 end
end

function enemy:s_endturn()
 self.card.state="s_exec"
 del(self.hand,self.card)
 self.card=nil
 game:next_turn()
 return "s_default"
end


function enemy:draw()
 local p=self.pos
 local offset=v(-2,2)
 if self.selected then
  p+=offset
 end
 spr(self.s,p.x,p.y,4,4)
 p+=v(2,-4)
 rectfill(p.x,p.y,p.x+9,p.y+1,8)
 if self.health>0 then
  rectfill(p.x,p.y,p.x+self.health-1,p.y+1,11)
 end
 --debugging
 -- p+=v(0,-6)
 -- print(self.health,p.x,p.y,11)
 -- p+=v(-2,36)
 -- print(self.name,p.x,p.y,7)
end
-->8
-- gamestate
--  trigger warn:
--   absolute shit code
function game:next_turn()
 self:check_is_over()
 local a
 repeat
  a=self.actors[1]
  del(self.actors,a)
  -- printh("repeat>"..a.name..">"..a.state)
 until a.state!="s_dead"
 -- printh("next>"..a.name..">"..a.state)
 add(self.actors,a)
 a.state="s_startturn"
end

function game:check_is_over()
 if p1.health<=0 then
  gameover_msg="you died"
  state="gameover"
 elseif e1.health<=0 then
  gameover_msg="victory!"
  state="gameover"
 end
end

function game.menu:update()
 self.t+=1
 fade_in()
 if btnp(🅾️) then
  self.timer=0
 end
 if self.timer then
  self.timer+=1
  fade=self.timer/30
 end
 if self.timer and self.timer>=30 then
  self.t=0
  fade=1
  start_game()
 end
end

function game.game:update()
 fade_in()
 update_entities()
end

function game.gameover:update()
 self.t+=1
 for e in all(entities) do
  del(entities,e)
 end
 if btnp(🅾️) then
  self.t=0
  state="menu"
  fade=1
 end
end

function game.menu:draw()
 print("dungeon ltd",38,40,7)
 print("press 🅾️ to start",30,70,6)
end

function game.game:draw()
 -- debug=p1.state.."\n"
 --  ..e1.state.."\n"
 --  ..e2.state
 debug=p1.torch.."\n"
  ..torch.bri
 palt()
 palt(0,false)
 local x1,y1,x2,y2=torch:extents()
 clip(x1,y1,x2-x1,y2-y1+1)
 clipbox={y1=y1,y2=y2}
 shake_screen()
 if state=="game" then
  map(0,0,0,0,16,16)
 end
 draw_entities()
 torch:apply()
end

function game.gameover:draw()
 cls()
 print(gameover_msg,50,40,8)
 print("press 🅾️ to restart",35,70,7)
end

-->8
-- juice

function fl_color(c)
 return function(x1,x2,y)
  rectfill(x1,y,x2,y,c)
 end
end

function fl_none() end

function init_blending(nlevels)
 _sqrt={}
 for i=0,4096 do
  _sqrt[i]=sqrt(i)
 end

 for lv=1,nlevels do
  local addr=0x4300+lv*0x100
  local sx=lv-1
  for c1=0,15 do
   local nc=sget(sx,c1)
   local topl=shl(nc,4)
   for c2=0,15 do
    poke(addr,
     topl+sget(sx,c2))
    addr+=1
   end
  end
 end
end

function fl_blend(l)
 local lutaddr=0x4300+shl(l,8)
	return function(x1,x2,y)
	 local laddr=lutaddr
	 local yaddr=0x6000+shl(y,6)
	 local saddr,eaddr=
	  yaddr+band(shr(x1+1,1),0xffff),
	  yaddr+band(shr(x2-1,1),0xffff)
	 if band(x1,1.99995)>=1 then
	  local a=saddr-1
	  local v=peek(a)
	  poke(a,
	   band(v,0xf) +
	   band(peek(bor(laddr,v)),0xf0)
	  )
	 end
	 for addr=saddr,eaddr do
	  poke(addr,
	   peek(
	    bor(laddr,peek(addr))
	   )
	  )
	 end
	 if band(x2,1.99995)<1 then
	  local a=eaddr+1
	  local v=peek(a)
	  poke(a,
	   band(peek(bor(laddr,v)),0xf) +
	   band(v,0xf0)
	  )
	 end
	end
end

light_rng={
 10*42,18*42,
 26*42,34*42,
 42*42,
}
light_rng[0]=-1000
light_fills={
 fl_none,fl_blend(2),fl_blend(3),
 fl_blend(4),fl_blend(5),fl_color(0)
}
brkpts={}

function fl_light(lx,ly,brightness,ln)
 local brightnessf,fills=
  brightness*brightness,
  light_fills
 return function(x1,x2,y)
  local ox,oy,oe=x1-lx,y-ly,x2-lx
  -- flicker
  local mul=brightnessf*(rnd(0.05)+0.5)
  local ysq=oy*oy
  local srng,erng,slv,elv=
   ysq+ox*ox,
   ysq+oe*oe
  for lv=5,0,-1 do
   local r=band(light_rng[lv]*mul,0xffff)
   if not slv and srng>=r then
    slv=lv+1
    if (elv) break
   end
   if not elv and erng>=r then
    elv=lv+1
    if (slv) break
   end
  end

  local llv,hlv=1,max(slv,elv)
  local mind=max(x1-lx,lx-x2)
  for lv=hlv-1,1,-1 do
   local brng=band(light_rng[lv]*mul,0xffff)
   local brp=_sqrt[brng-ysq]
   brkpts[lv]=brp
   if not brp or brp<mind then
    llv=lv+1
    break
   end
  end

  local xs,xe=lx+ox
  for l=slv,llv+1,-1 do
   xe=lx-brkpts[l-1]
   fills[l](xs,xe-1,y)
   xs=xe
  end
  for l=llv,elv-1 do
   xe=lx+brkpts[l]
   fills[l](xs,xe-1,y)
   xs=xe
  end
  fills[elv](xs,x2,y)
 end
end

function init_palettes(n)
 pals={}
 for p=1,n do
  pals[p]={}
  for c=0,15 do
   pals[p][c]=sget(p,c)
  end
 end
end

function reset_palette()
 pal()
 palt(14,true)
 palt(0,false)
end

function set_palette(no)
 for c,nc in pairs(pals[no]) do
  pal(c,nc)
 end
end

light=kind({
 extends=entity,
 off=v(0,0)
})

function light:s_default()
 self.bri=mid(0.2,p1.torch*0.2,10)
end

function light:range()
 return flr(42*self.bri)
end

function light:extents()
 local p,r=self.pos:flr(),self:range()
 return p.x-r,p.y-r,p.x+r,p.y+r
end

function light:apply()
 local p=self.pos:flr()
 local light_fill=fl_light(
  p.x,p.y,self.bri,
  blend_line
 )
 local xl,yt,xr,yb=self:extents()
 crect(xl,yt,xr,yb,light_fill)
end

function light:draw()
 spr(3+self.t/10%3,self.pos.x,self.pos.y)
end

__gfx__
000000000000000000000000eee8eeeeeeeeee8eeeeee8eeeeeeeeee00000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000
111000001100000000000000eeeeeee8eeeeeee8eee8eeeeeeeeeeee00000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00000000
221100002110000000000000eee88888eee88888eee8888eeeeeeeee00000000eeeeeeeeeeeeeeeeeeeeeeeeeeeee4eeee4eeeeeeeeeeeeeeeeeeeee00000000
333110003311000000000000eee8aa8eeee8aa8eeee8aa8eeeeeeeee00000000eeeeeeeeeeeeeeeeeeeeeeeeeeeee444444eeeeeeeeeeeeeeeeeeeee00000000
422110004422100000000000ee4588eeee4588eeee4588eeeeeeeeee00000000eeeeee4444eeeeeeeeeeeeeeeeeee444444eeeeeeeeeeeeeeeeeeeee00000000
551110005511000000000000ee455eeeee455eeeee455eeeeeeeeeee00000000eeeee44444eeeeeee44eeeeeeeeeeb8b8bbeeeeeeeeeeeeeeeeeeeee00000000
66d5100066dd510000000000e455eeeee455eeeee455eeeeeeeeeeee00000000eeeee44444e44eeeee4444eeeeeeebbbbbbeeeeeeeeeeeeeeeeeeeee00000000
776d100077776d510000000045eeeeee45eeeeee45eeeeeeeeeeeeee00000000eeeee99999444eeeeeee4444bbee37337bbeeeeeeeeeeeeeeeeeeeee00000000
882210008884210000000000eeeeeeee00000000eeeeeeeeeeeeeeee00000000eee44444444eeeefeeeeee3b44433bbbbb3eeeeeeeeeeeeeeeeeeeee00000000
942210009994210000000000eeaeaeee00000000eeeeeeeeeeeeeeee00000000eeeeefffffeeeee8eeeee3bbbbb3bbbbbb344444eeeeeeeeeeeeeeee00000000
a9421000aa99421000000000eeaaa8ee00000000eeeeeeeeeeeeeeee00000000eeeeefffffeeeee8eeeee3bbbbb3bbbbb3bb444444444eeeeeeeeeee00000000
bb331000bbb3310000000000ee9a98ee00000000eeeeeeeeeeeeeeee00000000eeee9999999eee8eeeeee3bbbbbb333333bbbbb44444444eeeeeeeee00000000
ccd51000ccdd510000000000e888888e00000000eeeeeeeeeeeeeeee00000000eee88888888888eeeeeee3bbb3bbbbbbbbbbbbbbbb44444eeeeeeeee00000000
dd511000dd51100000000000ee4444ee00000000eeeeeeeeeeeeeeee00000000ee8888888888eeeeeeeee3bb33bbbbbbbbbbbbbbbbb444eeeeeeeeee00000000
ee421000ee44421000000000ee8888ee00000000eeeeeeeeeeeeeeee00000000ee8e8888888eeeeeeeeeee33ee33bbb3bbbbb33bbbbbeeeeeeeeeeee00000000
f9421000fff9421000000000ee8ee8ee00000000eeeeeeeeeeeeeeee00000000ee8e8888888eeeeeeeeeeeeeeeb33333bbbb33e3bbbbbeeeeeeeeeee00000000
0000000000000000000000008800008800000000000000000000000000000000ee8e8888888eeeeeeeeeeeeeebbbbbb333333ee33bbbbeeeeeeeeeee00000000
0000000000000000000000000800008000000000000000000000000000000000ee8e8888888eeeeeeeeeeeeebbbbbbbbbbb33eee33bbbeeeeeeeeeee00000000
0000000000000000000000008800008800000000000000000000000000000000ee8e8888888eeeeeeeeeeeeebbbbbbbbbbbb33eee3bbbeeeeeeeeeee00000000
0000000000000000000000002808808200000000000000000000000000000000eefee888888eeeeeeeeeeeebbbbbbbbbbbbbb3eee33bbeeeeeeeeeee00000000
0000000000000000000000002808808200000000000000000000000000000000ee0ee88e448eeeeeeeeeeeebbbbbbbbbbbbbb3eeee3bbeeeeeeeeeee00000000
0000000000000000000000000888888000000000000000000000000000000000ee0ee44e44eeeeeeeeeeeeebbbbbbbbbbbbbb3eeeb3bbeeeeeeeeeee00000000
0000000000000000000000000822228000000000000000000000000000000000e00ee44e44eeeeeeeeeeeeebbbbbbbbbbbbbb3eeebbbbeeeeeeeeeee00000000
0000000000000000000000000800008000000000000000000000000000000000e0eee44e44eeeeeeeeeeeee3bbbbb3bbbbbbb3eeebbbbeeeeeeeeeee00000000
0000000000000000000000000000000000000000000000000000000000000000e0eee44e44eeeeeeeeeeeee433bbbbbbbbbb33eeeeeeeeeeeeeeeeee00000000
000000000000000000000000000000000000000000000000000000000000000000eee44e44eeeeeeeeeeeeee4333bbbbbb3333eeeeeeeeeeeeeeeeee00000000
00000000000000000000000000000000000000000000000000000000000000000eeee44e44eeeeeeeeeeeeeee4433333333344eeeeeeeeeeeeeeeeee00000000
00000000000000000000000000000000000000000000000000000000000000000eeee44e44eeeeeeeeeeeeeee44444ee44444eeeeeeeeeeeeeeeeeee00000000
00000000000000000000000000000000000000000000000000000000000000000eee000e000eeeeeeeeeeeeee44444eee4444eeeeeeeeeeeeeeeeeee00000000
0000000000000000000000000000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeee333eeeee3beeeeeeeeeeeeeeeeeeee00000000
0000000000000000000000000000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeee33333eeeee3bbeeeeeeeeeeeeeeeeeee00000000
0000000000000000000000000000000000000000000000000000000000000000eeeeeeeeeeeeeeeeeeeeeee333333eeeee33bbeeeeeeeeeeeeeeeeee00000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
99999999000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
4040604040604040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4060706060604050707040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6070606070707040505040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6040604040406070405040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4060605060406070406040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7040704050607040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5060704060605040404050504040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4060606070705050405050504040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4050404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0002000013350103400d3300b310243002230021300203001e3001d30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400003075032750317502d75029750237501d750137500c7400774004730027200171003700037000370002700027000270002700017000170001700017000170000700007000070000700007000070000700
01100000107751377517775137751077513775177751377510775137751777513775107751377517775137750f7751277517775127750f7751277517775127750f7751277517775127750f775127751777512775
011000001c3601c3511c3411c331233602335123341233311e3601e3511e3411e3311f3601f3511f3411f3311b3601b3511b3411b331233602335123341233311e3601e3511e3411e3311b3601b3511b3411b331
011000002336023351233412333126360263512634126331243602435124341243312336023351233412333121360213512135121331263602635126341263312436024351243412433121360213512134121331
__music__
03 02434344
00 02434344
01 02034444
02 02030444
