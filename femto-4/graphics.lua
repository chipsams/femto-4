require"utils"

local function docolour(c)
  c=c or 0
  c=bit.band(c,3)
  return mem[mem_map.draw_pal+c]
end

--- plots a pixel, atomic operation for most graphics
---@param x number
---@param y number
---@param c number
function pset(x,y,c)
  c=docolour(c)
  x,y,c=flr(x,y,c)
  if mem[mem_map.hirez]==1 then
    if x>=0 and x<=127 and y>=0 and y<=47 then
      local i=bit.rshift(x,3)+bit.lshift(y,4)
      mem[i+mem_map.screen] = bit.bor(bit.band(mem[i+mem_map.screen],bit.bnot(bit.lshift(1,bit.band(x,7)))),bit.lshift(bit.band(c,1),bit.band(x,7)))
    end
  else
    if x>=0 and x<=63 and y>=0 and y<=47 then
      local i=bit.rshift(x,2)+bit.lshift(y,4)
      mem[i+mem_map.screen] = bit.bor(bit.band(mem[i+mem_map.screen],bit.bnot(bit.lshift(3,bit.lshift(bit.band(x,3),1)))),bit.lshift(bit.band(c),bit.lshift(bit.band(x,3),1)))
    end
  end
end

function pget(x,y)
  if mem[mem_map.hirez]==1 then
    if x>=0 and x<=127 and y>=0 and y<=47 then
      local i=bit.rshift(x,3)+bit.lshift(y,4)
      return bit.band(bit.rshift(mem[i+mem_map.screen],x%8),1)  
    end
  else
    if x>=0 and x<=63 and y>=0 and y<=47 then
      local i=bit.rshift(x,2)+bit.lshift(y,4)
      return bit.band(bit.rshift(mem[i+mem_map.screen],x%4*2),3)
    end
  end
  return 0
end


function plotLineLow(x0, y0, x1, y1, c)
  local dx = x1 - x0
  local dy = y1 - y0
  local yi = 1
  if dy < 0 then
    yi = -1
    dy = -dy
  end
  local D = (2 * dy) - dx
  local y = y0

  for x = x0,x1 do
    pset(x, y, c)
    if D > 0 then
      y = y + yi
      D = D + (2 * (dy - dx))
    else
      D = D + 2*dy
    end
  end
end
function plotLineHigh(x0, y0, x1, y1, c)
  local dx = x1 - x0
  local dy = y1 - y0
  local xi = 1
  if dx < 0 then
    xi = -1
    dx = -dx
  end
  local D = (2 * dx) - dy
  local x = x0

  for y = y0,y1 do
    pset(x, y, c)
    if D > 0 then
      x = x + xi
      D = D + (2 * (dx - dy))
    else
      D = D + 2*dx
    end
  end
end

--- plots a line between two points
---@param x0 number
---@param y0 number
---@param x1 number
---@param y1 number
---@param c number
function line(x0, y0, x1, y1, c)
  c=c or 0
  x0, y0, x1, y1, c=flr(x0, y0, x1, y1, c)
  if math.abs(y1 - y0) < math.abs(x1 - x0) then
    if x0 > x1 then
      plotLineLow(x1, y1, x0, y0, c)
    else
      plotLineLow(x0, y0, x1, y1, c)
    end
  else
    if y0 > y1 then
      plotLineHigh(x1, y1, x0, y0, c)
    else
      plotLineHigh(x0, y0, x1, y1, c)
    end
  end
end

function cls(c)
  c=c or 0
  c=c%4
  c=docolour(c)
  local byte=0
  for _bit=0,3 do byte=byte+bit.lshift(c,_bit*2) end
  for l=mem_map.screen,mem_map.screen+mem_map.screen_length do
    mem[l]=byte
  end
end

--- plots a string to the femto screen
---@param st string
---@param x number
---@param y number
---@param c number
function sc_write(st,x,y,c,pset_override)
  local pset=pset_override or pset
  c=c or 0
  local linestart=x or 1
  if not (c or y) then c,x=x,nil end
  x=x or memsigned[mem_map.print_cursor_x]
  y=y or memsigned[mem_map.print_cursor_y]
  x,y,c=flr(x,y,c)

  st=tostring(st == nil and "" or st)
  for i=1,#st do
    local ch=st:sub(i,i)
    local charcode=string.byte(ch)
    --pset(x-1,y-1,c)
    for lx=0,3 do
      for ly=0,3 do
        local r=font:getPixel(charcode%16*4+lx,math.floor(charcode/16)*4+ly)
        if r>0 then pset(x+lx,y+ly,c) end
      end
    end
    x=x+4
    if ch=="\n" then
      x=linestart
      y=y+4
    end
  end
  memsigned[mem_map.print_cursor_x]=x
  memsigned[mem_map.print_cursor_y]=y
end

--- fills a horizontal line with one color
---@param x1 number
---@param x2 number
---@param y number
---@param c number
function setline(x1,x2,y,c)
  x1,x2,y=flr(x1,x2,y)
  if math.abs(x1-x2)<4 then for l=x1,x2 do pset(l,y,c) end return end
  if y<0 or y>47 then return end
  if x2<x1 then return setline(x2,x1,y,c) end
  local dx1=boundscreen_x(x1)
  local dx2=boundscreen_x(x2)
  c=c%4
  if sign(dx1-x1)==sign(dx2-x2) and dx2-x2~=0 then return end
  local byte=0
  if mem[mem_map.hirez]==1 then
    for _bit=0,7 do byte=byte+bit.lshift(docolour(c)%2,_bit) end
    memset(mem_map.screen+math.ceil(dx1/8)+y*16,math.floor(dx2/8)-math.floor((dx1)/8),byte)
    for l=dx1,bit.lshift(bit.rshift(dx1+7,3),3) do
      pset(l,y,c)
    end
    if dx1<=60 then
      for l=bit.lshift(bit.rshift(dx2,3),3),dx2 do
        pset(l,y,c)
      end
    end
  else
    for _bit=0,3 do byte=byte+bit.lshift(docolour(c),_bit*2) end
    memset(mem_map.screen+math.ceil(dx1/4)+y*16,math.floor(dx2/4)-math.floor((dx1+3)/4),byte)
    for l=dx1,bit.lshift(bit.rshift(dx1+3,2),2) do
      pset(l,y,c)
    end
    if dx1<=60 then
      for l=bit.lshift(bit.rshift(dx2,2),2),dx2 do
        pset(l,y,c)
      end
    end
  end
end

--- sets a pixel in the spritesheet
---@param x number
---@param y number
---@param c number

function sset(x,y,c)
  x,y,c=flr(x,y,c)
  if mem[mem_map.hirez]==1 then
    if x>=0 and x<=127 and y>=0 and y<=47 then
      local i=bit.rshift(x,3)+bit.lshift(y,4)
      mem[i+mem_map.sprites] = bit.bor(bit.band(mem[i+mem_map.sprites],bit.bnot(bit.lshift(1,bit.band(x,7)))),bit.lshift(c%2,bit.band(x,7)))
    end
  else
    if x>=0 and x<=63 and y>=0 and y<=47 then
      local i=bit.rshift(x,2)+bit.lshift(y,4)
      mem[i+mem_map.sprites] = bit.bor(bit.band(mem[i+mem_map.sprites],bit.bnot(bit.lshift(3,x%4*2))),bit.lshift(c%4,x%4*2))
    end
  end
end

function sget(x,y)
  if mem[mem_map.hirez]==1 then
    if x>=0 and x<=127 and y>=0 and y<=47 then
      local i=bit.rshift(x,3)+bit.lshift(y,4)
      return bit.band(bit.rshift(mem[i+mem_map.sprites],x%8),1)  
    end
  else
    if x>=0 and x<=63 and y>=0 and y<=47 then
      local i=bit.rshift(x,2)+bit.lshift(y,4)
      return bit.band(bit.rshift(mem[i+mem_map.sprites],x%4*2),3)
    end
  end
  return 0
end

--[[
  function sset(x,y,c)
    if x>=0 and x<=63 and y>=0 and y<=47 then
      local i=math.floor(x/4+y*16)
      mem[i+mem_map.sprites] = bit.bor(bit.band(mem[i+mem_map.sprites],bit.bnot(bit.lshift(3,x%4*2))),bit.lshift(c%4,x%4*2))
    end
  end
  function sget(x,y)
    if x>=0 and x<=63 and y>=0 and y<=47 then
      local i=math.floor(x/4+y*16)
      return bit.band(bit.rshift(mem[i+mem_map.sprites],x%4*2),3)
    end
    return 0
  end
--]]

--- plots from the spritesheet to the screen.
---@param sp number
---@param x number
---@param y number
---@param w number (1)
---@param h number (1)
---@param scale number (1)
function sspr(sp,x,y,w,h,scale,flipx,flipy)
  local w=w or 1
  local h=h or 1
  local scale=scale or 1
  local sx=sp%16*4
  local sy=math.floor(sp/16)*4
  for lx=0,w*4-1 do
    for ly=0,h*4-1 do
      local dx,dy=x+(flipx and w*4-1-lx or lx)*scale,y+(flipy and h*4-1-ly or ly)*scale
      local c=sget(sx+lx,sy+ly)
      if mem[mem_map.transparency_pal+c]>0 then rectfill(dx,dy,dx+scale-1,dy+scale-1,c) end
    end
  end  
end

function plot_imgdata(img,x,y,w)
  for lx=0,img:getWidth()-1 do
    for ly=0,img:getHeight()-1 do
      local r,g,b,a=img:getPixel(lx,ly)
      if a>0 then pset(x+lx,y+ly,math.floor(r + g*2 +.5)) end
    end
  end
end

function plot_imgdata_1col(img,x,y,c)
  for lx=0,img:getWidth()-1 do
    for ly=0,img:getHeight()-1 do
      local r,g,b,a=img:getPixel(lx,ly)
      if a>0 then pset(x+lx,y+ly,c) end
    end
  end
end

--- draws the outline of a rectangle
---@param x1 number
---@param x2 number
---@param y1 number
---@param y2 number
---@param c number
function rect(x1,y1,x2,y2,c)
  x1,y1,x2,y2,c=flr(x1,y1,x2,y2,c)
  if x2<x1 then return rect(x2,y1,x1,y2,c) end
  if y2<y1 then return rect(x1,y2,x2,y1,c) end
  local dx1=boundscreen_x(x1)
  local dx2=boundscreen_x(x2)
  local dy1=boundscreen_y(y1)
  local dy2=boundscreen_y(y2)
  c=c%4
  local byte=0
  local onscreen_vert =dy1==y1 or dy2==y2
  local onscreen_horiz=dx1==x1 or dx2==x2
  if dx1==x1 and onscreen_vert then for y=dy1,dy2 do pset(dx1,y,c) end end
  if dx2==x2 and onscreen_vert then for y=dy1,dy2 do pset(dx2,y,c) end end
  if dy1==y1 then setline(x1,x2,dy1,c) end
  if dy2==y2 then setline(x1,x2,dy2,c) end
end

--- draws a filled rectangle
---@param x1 number
---@param x2 number
---@param y1 number
---@param y2 number
---@param c number
function rectfill(x1,y1,x2,y2,c)
  x1,y1,x2,y2,c=flr(x1,y1,x2,y2,c)
  if x2<x1 then return rectfill(x2,y1,x1,y2,c) end
  if y2<y1 then return rectfill(x1,y2,x2,y1,c) end
  local dy1=boundscreen_y(y1)
  local dy2=boundscreen_y(y2)
  c=c%4
  local byte=0
  if sign(dy1-y1)==sign(dy2-y2) and dy2-y2~=0 then return end
  for y=dy1,dy2 do setline(x1,x2,y,c) end
end

--- sets a span of memory
---@param addr number
---@param span number
---@param value number
function memset(addr,span,value)
  for l=0,span-1 do
    mem[addr+l]=value
  end
end
function memcpy(addr1,addr2,span)
  local tmpdata={}
  for l=0,span-1 do
    tmpdata[l]=mem[addr1+l]
  end
  for l=0,span-1 do
    mem[addr2+l]=tmpdata[l]
  end
end

function circ(x,y,r,c)
  x,y=math.floor(x)+.5,math.floor(y)+.5
  r=math.floor(r+.5)
  local dx, dy, err = r, 0, 1-r
  while dx >= dy do
    pset(x+dx, y+dy, c)
    pset(x-dx, y+dy, c)
    pset(x+dx, y-dy, c)
    pset(x-dx, y-dy, c)
    pset(x+dy, y+dx, c)
    pset(x-dy, y+dx, c)
    pset(x+dy, y-dx, c)
    pset(x-dy, y-dx, c)
    dy = dy + 1
    if err < 0 then
      err = err + 2 * dy + 1
    else
      dx, err = dx-1, err + 2 * (dy - dx) + 1
    end
  end
end

function circfill(x,y,r,c)
  x,y=math.floor(x)+.5,math.floor(y)+.5
  r=math.floor(r+.5)
  local dx, dy, err = r, 0, 1-r
  while dx >= dy do
    setline(x-dx,x+dx,y+dy,c)
    setline(x-dy,x+dy,y+dx,c)
    setline(x-dy,x+dy,y-dx,c)
    setline(x-dx,x+dx,y-dy,c)
    dy = dy + 1
    if err < 0 then
      err = err + 2 * dy + 1
    else
      dx, err = dx-1, err + 2 * (dy - dx) + 1
    end
  end
end