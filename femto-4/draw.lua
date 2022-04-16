
local s={}

local rdown=false

s.sprite=0
s.spritepagex=0
s.spritepagey=0
s.colour=1
s.spritescale=2

s.clickmode=nil
local function canclick(bool,mode)
  local can=(not s.clickmode and bool) or s.clickmode==mode
  if can then s.clickmode=mode end
  return can and bool
end

local scale=8
local colourpickscale=5

function s.update()
  screenpos=0x400
  if not (mouse.lb or mouse.mb or mouse.rb) then s.clickmode=nil end
  local cx,cy=convertpos(mouse.x,mouse.y,2,7,scale/s.spritescale)
  local sx,sy=s.sprite%16*4,math.floor(s.sprite/16)*4
  local onspr=cx>=0 and cx<=s.spritescale*4-1 and cy>=0 and cy<=s.spritescale*4-1
  if mouse.lb and canclick(onspr,"draw") then
    pset(sx+cx,sy+cy,s.colour)
  end
  if mouse.rb and canclick(onspr,"draw") then
    s.colour=sget(sx+cx,sy+cy)
  end
  local palx,paly=convertpos(mouse.x,mouse.y,62-(colourpickscale+1)*4,8,colourpickscale+1)
  if mouse.lb and canclick(paly==0 and palx>=0 and palx<=3,"pal") then s.colour=mid(0,palx,3) end

  local pagex,pagey=convertpos(mouse.x,mouse.y,38,18,4)
  local onpage=pagex>=0 and pagex<=3 and pagey>=0 and pagey<=3
  if mouse.lb and canclick(onpage,"page") then s.sprite=s.spritepagex+s.spritepagey*16+pagex+pagey*16 end
  

  screenpos=0x800
end

function s.draw()
  cls(0)
  
  --top and bottom red bars
  rectfill(0,0,63,4,1)
  rectfill(0,42,63,47,1)

  --sprite drawing border
  rect(2,7,35,40,3)
  rectfill(1,6,34,39,0)
  rect(1,6,34,39,2)

  --draw the actual sprite
  sspr(s.sprite,2,7,s.spritescale,s.spritescale,scale/s.spritescale)

  --draw the color picker
  do
    local dx,dy=62-(3-s.colour+1)*(colourpickscale+1),8
    rect(dx-1,dy-1,dx+colourpickscale+2,dy+colourpickscale+2,3)
    rectfill(62-(colourpickscale+1)*4,8,62,colourpickscale+9,3)
    rectfill(61-(colourpickscale+1)*4,7,61,colourpickscale+8,2)
    for l=0,3 do
      local dx,dy=62-(l+1)*(colourpickscale+1),8
      --rectfill(dx-1,dy-1,dx+colourpickscale,dy+colourpickscale,2)
      rectfill(dx,dy,dx+colourpickscale-1,dy+colourpickscale-1,3-l)
    end
    local dx,dy=62-(3-s.colour+1)*(colourpickscale+1),8
    rect(dx-1,dy-1,dx+colourpickscale,dy+colourpickscale,0)
    rect(dx-2,dy-2,dx+colourpickscale+1,dy+colourpickscale+1,2)
  end

  --draw the sprite picker
  do
    rect(38,18,55,35,3)
    rect(37,17,54,34,2)
    spr(s.spritepagex+s.spritepagey*16,38,18,4,4)
  end
  local spx,spy=s.sprite%16-s.spritepagex,math.floor(s.sprite/16)-s.spritepagey
  local w,h=s.spritescale,s.spritescale


  --selection cursor
  rect(spx*4+37,spy*4+17,spx*4+w*4+38,spy*4+h*4+18,0)
  rect(spx*4+36,spy*4+16,spx*4+w*4+39,spy*4+h*4+19,2)

  --title bar
  sc_write(s.spritescale,1,1,0)
  if rdown then
    cls()
    sspr(0,0,0,16,12,1)
  end

  plot_imgdata(cursor,mouse.x,mouse.y,5)
end

function s.keypressed(key)
  if key=="q" then
    s.sprite=s.sprite-s.spritescale
  end
  if key=="e" then
    s.sprite=s.sprite+s.spritescale
  end
  s.sprite=math.max(0,s.sprite)
  if key=="r" then
    rdown=true
  end
end

function s.keyreleased(key)
  if key=="r" then
    rdown=false
  end
end

function s.wheelmoved(_,y)
  if y>0 and s.spritescale<8 then
    s.spritescale=s.spritescale*2
  elseif y<0 and s.spritescale>1 then
    s.spritescale=s.spritescale/2
  end
end
  

return s