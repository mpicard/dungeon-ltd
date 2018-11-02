pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
-- dungeon ltd

--[[(working title)

todo
-battles
 -turns
 -
-music
-art
]]
turn=true
player={x=20,y=40}
function player:draw()
 local s=self
 rectfill(s.x,s.y,s.x+10,s.y+10,12)
end

enemy={x=20,y=80}
function enemy:draw()
 local s=self
 rectfill(s.x,s.y,s.x+10,s.y+10,8)
end

function _update()
 if turn then
  show_ui=true
 else
  -- en turn
 end
end

function _draw()
 cls()
 player:draw()
 enemy:draw()
 if show_ui then
  draw_ui()
 end
end

function draw_ui()
 --rectfill()
end
