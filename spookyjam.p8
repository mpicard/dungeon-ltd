pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- dungeon ltd
--[[(working title)

todo
-battles
 -init decks
 -turns
 -cards
  -attack
  -torch
  -heal
-music
-art
]]
turn={}
function start_game()
 add(turn,player)
 add(turn,enemy1)
 add(turn,enemy2)
 card_cursor=0
 next_actor()
end

function _init()
 printh("~~ new game ~~")
 card_cursor=0
 start_game()
end

function _update()
 update_entities()

 debug="p  "
  ..player.state.."\ne1 "
  ..enemy1.state.."\ne2 "
  ..enemy2.state.."\nt  "
  ..turn[1].name
end

debug=""
function _draw()
 cls(1)
 draw_entities()

 --temp draw torch
 print("torch "..player.torch,24,62,7)

 if debug!="" then
  print(debug,0,0,7)
 end
end

function next_actor()
 local a=turn[1]
 del(turn,a)
 add(turn,a)
 a.state="s_startturn"
 return a
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
vector.__index=vector
-- new vector
function v(x,y)
 local vec={x=x,y=y}
 setmetatable(vec,vector)
 return vec
end

--sprite
function s(s,e,spd)
 return {frm=s,e=e,spd=spd}
end

--label
function l(l,o,c)
 return {label=l,o=o,c=c}
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
 for _,e in pairs(entities_with.draw) do
  e:draw()
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

function card:reduce_torch()
local t=self.parent.torch
 if t then
  t=max(t-1,0)
 end
end

function c_attack:s_exec()
 printh("attack "..self.parent.name..">"..self.target.name)
 self.target.health=max(self.target.health-1,0)
 self:reduce_torch()
 sfx(0)
 return true
end

function c_torch:s_exec()
 printh("torch-- "..self.parent.name)
 self.parent.torch=min(self.parent.torch+1,10)
 return true
end

function c_heal:s_exec()
 printh("heal++ "..self.parent.name)
 self.parent.health=min(self.parent.health+1,10)
 self:reduce_torch()
 return true
end

function c_snub:s_exec()
 printh("snub "..self.parent.name..">"..self.target.name)
 self.target.torch=max(self.target.torch-1,0)
 self:reduce_torch()
 return true
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

function actor:draw()
 local p,c=self.pos,self.col
 rectfill(p.x,p.y,p.x+20,p.y+20,c)
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

-- player
player=actor:new({
 name="player",
 pos=v(30,40),
 torch=10,
 hand={}
})

function player:s_startturn()
 repeat
  add(self.hand,pick_card(cards))
 until #self.hand>=3

 for i,c in pairs(self.hand) do
  c.pos=v(i*31-28,90)
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
  end
  return "s_endturn"
 elseif btnp(❎) then
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
  return "s_endturn"
 end
end

function player:s_endturn()
 self.card.state="s_exec"
 del(self.hand,self.card)
 assert(#self.hand==2)
 self.card=nil
 next_actor()
 --deselect enemies
 local ee=entities_with.enemy
 for i=1,#ee do
  ee[i].selected=false
 end
 return "s_default"
end

-->8
-- enemy

enemy=kind({
 extends=actor,
 enemy=true,
 pos=v(0,0),
 s=16,
 hand={},
 sleep=40
})
function enemy:s_startturn()
 for i=#self.hand+1,3 do
  --todo more enemy cards
  local c=enemy_cards[flr(rnd(#enemy_cards)+1)]
  add(self.hand,c:new())
 end
 for i=1,#self.hand do
  self.hand[i].parent=self
 end
 return "s_selectcard"
end

function enemy:s_selectcard()
 if self.t>self.sleep then
  --todo strategically pick card
  local i=flr(rnd(#self.hand)+1)
  local c=self.hand[i]
  c.parent=self
  c.target=player
  self.card=c
  return "s_endturn"
 end
end

function enemy:s_endturn()
 self.card.state="s_exec"
 del(self.hand,self.card)
 assert(#self.hand==2)
 self.card=nil
 next_actor()
 return "s_default"
end

function enemy:draw()
 local p=self.pos
 local offset=v(-4,8)
 if self.selected then
  p+=offset
 end
 zspr(self.s,1,1,p.x,p.y,3)
 p+=v(2,-4)
 rectfill(p.x,p.y,p.x+9,p.y+1,8)
 if self.health>0 then
  rectfill(p.x,p.y,p.x+self.health-1,p.y+1,11)
 end
 --debugging
 p+=v(0,-6)
 print(self.health,p.x,p.y,11)
 p+=v(-2,36)
 print(self.name,p.x,p.y,7)
end

-- enemy
enemy1=enemy:new({
 name="enemy1",
 pos=v(80,20)
})

enemy2=enemy:new({
 name="enemy2",
 pos=v(104,24)
})
__gfx__
00000000000800000000008000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000080000000800080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000888880008888800088880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000770000008aa800008aa800008aa80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000004588000045880000458800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700004550000045500000455000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000045500000455000004550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000450000004500000045000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a0a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00aaa800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
009a9800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00444400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00888800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00800800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88000088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
88000088000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28088082000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
28088082000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08888880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08222280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
08000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0002000013350103400d3300b310243002230021300203001e3001d30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
