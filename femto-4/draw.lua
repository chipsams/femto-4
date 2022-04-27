
local s={}

local rdown=false
local ctrlheld=false

s.sprite=0
s.spritepagex=0
s.spritepagey=0
s.colour=1
s.spritescale=1

local openx=59-32 
local closedx=59

s.visual_tabs={}

local tabs={
  "page",
  "test",
  "test2"
}

local tabi={}

for l=1,#tabs do s.visual_tabs[l]={x=0,h=0} tabi[tabs[l]]=l end

s.tab=""

s.clickmode=nil
local function canclick(bool,mode)
  local can=(not s.clickmode and bool) or s.clickmode==mode
  if can then s.clickmode=mode end
  return can and bool
end

local scale=8
local colourpickscale=5

function s.update()
  if not (mouse.lb or mouse.mb or mouse.rb) then s.clickmode=nil end

  local x,tab=convertpos(mouse.x,mouse.y,59,17,6,6)
  if mouse.lb and canclick(x==0,"opentab") and tabs[tab+1] then s.tab=tabs[tab+1] end

  local x,tab=convertpos(mouse.x,mouse.y,openx,17,6,6)
  if mouse.lb and canclick(s.tab~="" and x==0,"closetab") then s.tab="" end

  if mouse.lb and canclick(s.tab~="" and x>=0 and tab>=0 and tab<=#tabs,"clicktab") then
    if s.tab=="page" then
      local x,y=convertpos(mouse.x,mouse.y,32,18,5)
      if x>=0 and x<=3 and y>=0 and y<=2 then
        s.spritepagex=x*4
        s.spritepagey=y*4
      end
    end
  end

  local cx,cy=convertpos(mouse.x,mouse.y,2,7,scale/s.spritescale)
  local sx,sy=s.sprite%16*4,math.floor(s.sprite/16)*4
  local onspr=cx>=0 and cx<=s.spritescale*4-1 and cy>=0 and cy<=s.spritescale*4-1
  if mouse.lb and canclick(onspr and not ctrlheld,"draw") then
    sset(sx+cx,sy+cy,s.colour)
  end
  if mouse.lb and canclick(onspr and ctrlheld,"fill") then
    local c=pget(sx+cx,sy+cy)
    for lx=0,4*s.spritescale-1 do
      for ly=0,4*s.spritescale-1 do
        if pget(sx+lx,sy+ly)==c then
          pset(sx+lx,sy+ly,s.colour)
        end
      end
    end
  end
  if mouse.rb and canclick(onspr,"draw") then
    s.colour=sget(sx+cx,sy+cy)
  end
  local palx,paly=convertpos(mouse.x,mouse.y,62-(colourpickscale+1)*4,8,colourpickscale+1)
  if mouse.lb and canclick(paly==0 and palx>=0 and palx<=3,"pal") then s.colour=mid(0,palx,3) end

  local pagex,pagey=convertpos(mouse.x,mouse.y,38,18,4)
  local onpage=pagex>=0 and pagex<=3 and pagey>=0 and pagey<=3
  if mouse.lb and canclick(onpage,"page") then s.sprite=s.spritepagex+s.spritepagey*16+pagex+pagey*16 end
end

function s.draw()
  cls(0)
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
    sspr(s.spritepagex+s.spritepagey*16,38,18,4,4,1)
  end
  local spx,spy=s.sprite%16-s.spritepagex,math.floor(s.sprite/16)-s.spritepagey
  local w,h=s.spritescale,s.spritescale


  --selection cursor
  rect(spx*4+37,spy*4+17,spx*4+w*4+38,spy*4+h*4+18,0)
  rect(spx*4+36,spy*4+16,spx*4+w*4+39,spy*4+h*4+19,2)
  
  for i,tab in pairs(tabs) do
    local targetval=(tab==s.tab and openx or closedx)+0.5
    s.visual_tabs[i].x=lerp(s.visual_tabs[i].x,targetval,0.4)
    s.visual_tabs[i].h=lerp(s.visual_tabs[i].h,tab==s.tab and 17.5 or 2.5,tab==s.tab and 0.5 or 0.8)
  end

  local function get_tab_draw_positions(i,tab)
    local x1,y,x2=s.visual_tabs[i].x,17+i*6-4,64
    local ty=y-2
    local y1=math.max(y-s.visual_tabs[i].h+.75,17)
    local y2=math.min(y+s.visual_tabs[i].h,34)
    rectfill(x1,y1,x2,y2,2)
    return x1,y1,x2,y2,ty
  end

  local function drawtab_bg(i,tab)
    local x1,y1,x2,y2,ty=get_tab_draw_positions(i,tab)
    rect(x1-1,y1-1,x2+1,y2+1,0)
    rect(x1,y2+2,x2+1,y2+2,0)
  end

  local function drawtab_fg(i,tab)
    local x1,y1,x2,y2,ty=get_tab_draw_positions(i,tab)
    rectfill(x1+1,y1+1,x2+1,y2+1,3)
    rectfill(x1,y1,x2,y2,2)
    --rect(x1,y1,x2,y2,3)
    sc_write(tab==s.tab and ">" or "<",x1+1,ty+1,0)
  end

  
  for i,tab in pairs(tabs) do if tab==s.tab then drawtab_bg(i,tab) end end
  for i,tab in pairs(tabs) do if tab==s.tab then drawtab_fg(i,tab) end end
  for i,tab in pairs(tabs) do if tab~=s.tab then drawtab_bg(i,tab) end end
  for i,tab in pairs(tabs) do if tab~=s.tab then drawtab_fg(i,tab) end end
  if s.tab=="page" then
    rect(s.visual_tabs[tabi.page].x+7,19,53,33,0)
    rectfill(s.visual_tabs[tabi.page].x+6,18,52,32,0)
    for lx=0,3 do
      for ly=0,2 do
        local dx,dy=s.visual_tabs[tabi.page].x+6+lx*5,18+ly*5
        if (lx+ly)%2==0 then rectfill(dx,dy,dx+4,dy+4,3) end
      end
    end
    local dx,dy=s.visual_tabs[tabi.page].x+6+s.spritepagex*1.25,18+s.spritepagey*1.25
    plot_imgdata_1col(page_select_cursor_png,dx,dy,1)
  end
  
  
  --top and bottom red bars
  rectfill(0,0,127,4,1)
  rectfill(0,42,127,47,1)
  
  --title bar
  buttons.draw()
  sc_write("draw",1,1,0)
  sc_write(s.sprite,1,43,0)

  plot_imgdata(cursor,mouse.x,mouse.y,5)
end

function s.keypressed(key)
  if key=="q" then
    s.sprite=s.sprite-s.spritescale
  elseif key=="e" then
    s.sprite=s.sprite+s.spritescale
  elseif key=="s" and ctrlheld then
    local txt=cart_manip.tostring()
    love.system.setClipboardText(txt)
  elseif key=="o" and ctrlheld then
    local txt=love.system.getClipboardText()
    cart_manip.fromstring(txt)
  end
  s.sprite=math.max(0,s.sprite)
  if key=="r" and ctrlheld then
    ctrlheld=false
    loadcode()
  end
  local sx,sy=s.sprite%16*4,math.floor(s.sprite/16)*4
  if key=="left" then
    for ly=0,s.spritescale*4-1 do
      local savepix=sget(sx,sy+ly)
      for lx=0,s.spritescale*4-2 do
        sset(sx+lx,sy+ly,sget(sx+lx+1,sy+ly))
      end
      sset(sx+s.spritescale*4-1,sy+ly,savepix)
    end
  end
  if key=="right" then
    for ly=0,s.spritescale*4-1 do
      local savepix=sget(sx+s.spritescale*4-1,sy+ly)
      for lx=s.spritescale*4-1,1,-1 do
        sset(sx+lx,sy+ly,sget(sx+lx-1,sy+ly))
      end
      sset(sx,sy+ly,savepix)
    end
  end
  if key=="up" then
    for lx=0,s.spritescale*4-1 do
      local savepix=sget(sx+lx,sy)
      for ly=0,s.spritescale*4-2 do
        sset(sx+lx,sy+ly,sget(sx+lx,sy+ly+1))
      end
      sset(sx+lx,sy+s.spritescale*4-1,savepix)
    end
  end
  if key=="down" then
    for lx=0,s.spritescale*4-1 do
      local savepix=sget(sx+lx,sy+s.spritescale*4-1)
      for ly=s.spritescale*4-1,1,-1 do
        sset(sx+lx,sy+ly,sget(sx+lx,sy+ly-1))
      end
      sset(sx+lx,sy,savepix)
    end
  end
  if key=="lctrl" then
    ctrlheld=true
  end
end

function s.keyreleased(key)
  if key=="r" then
    rdown=false
  end
  if key=="lctrl" then
    ctrlheld=false
  end
end

function s.wheelmoved(_,y)
  if y>0 and s.spritescale<8 then
    s.spritescale=s.spritescale*2
  elseif y<0 and s.spritescale>1 then
    s.spritescale=s.spritescale/2
  end
end
  
function s.mousedown()
  buttons.mousedown()
end

return s