

local bit = require 'bit' 
local ffi = require 'ffi'

--   0 - 33f : general purpouse
-- 340 - 35f : poke flags/memory map stuff (e.g. button state)
-- 340-343: button bitmasks (341-343 likely unused for a while, multiple controlers sounds annoying to implement)
-- 344,345: print cursor
-- 346-349: screen pallete
-- 34a-34e: draw pallete
-- 34f: draw colour
-- 360 - 3ff : stack
-- 400 - 7ff : sprites [2 bpp, 4x4] = 192 sprites
-- 800 - aff : screen [2bpp] = 64x48 screen
-- b00 - fff : code, each operation is 2 bytes (although some may take more, e.g. string, which reads bytes until it hits 0, writing each bit to the specified position in gp memory.)

function love.load()
  love.graphics.setDefaultFilter( "nearest" )
  screenpos=0x800
  spritepos=0x400
  base_mem = love.data.newByteData(2 ^ 12)
  mem=ffi.cast("uint8_t*", base_mem:getFFIPointer())
  --the mem is initialized to zeros anyway!
  --[[
    for l=0,0xfff do -- 4096 byte array
      mem[l]=0
    end
  ]]
  --[[
    for l=0x800,0xaff do -- init screen
      local v=0
      mem[l]=v
    end
  ]]

  love.window.setMode(64,48,{resizable=true})
  

  require"graphics"
  print("graphics loaded")
  screen={
    x=0,
    y=0,
    scale=1,
  }

  love.mouse.setVisible(false)
  cursor=love.image.newImageData("assets/cursor.png")
  pal=love.image.newImageData("assets/pallete.png")
  for l=0,3 do
    mem[0x346+l]=l  --init screen pallete
    mem[0x34a+l]=l  --init draw pallete
  end

  mem[0x346]=0
  
  font=love.image.newImageData("assets/font.png")
  
  renderdata=love.image.newImageData(64,48)
  renderscreen=love.graphics.newImage(renderdata)
  
  execstate=require"execute"
  codestate=require"code"
  drawstate=require"draw"

  --change this to change the starting state
  currentscene=codestate
end

t=0


code={}

([[
lop:adc a +1
plt a a a
jmp lop
]]):gsub("[^\n]+",function(v)
  table.insert(code,v)
end)




mouse={
  x=0,
  y=0,
  onscreen=false
}

function love.resize(w,h)
  screen.scale=math.min(w*0.75,h)/48
  screen.x=w/2-screen.scale*32
  screen.y=h/2-screen.scale*24
end

function love.update(dt)
  --screenpos=love.mouse.isDown(1) and 0x800 or 0x400
  t=t+dt
  local mx,my=love.mouse.getPosition()
  mx=math.floor((mx-screen.x)/screen.scale)
  my=math.floor((my-screen.y)/screen.scale)
  mouse.lb=love.mouse.isDown(1)
  mouse.rb=love.mouse.isDown(2)
  mouse.mb=love.mouse.isDown(3)
  mouse.x,mouse.y=mx,my
  if my==boundscreen_y(my) and mx==boundscreen_x(mx) then mouse.onscreen=true end
  if currentscene.update then currentscene.update(dt) end
  if currentscene.draw then currentscene.draw(t) end
end

function love.draw()
  --sy=64+math.sin(t)*8
  love.graphics.clear()
  local r={}
  local g={}
  local b={}
  
  for l=0,3 do
    local palindex=mem[0x346+l]
    r[l],g[l],b[l]=pal:getPixel(palindex%4,math.floor(palindex/4))
  end
  renderdata:mapPixel(function(x,y)
    local v=bit.rshift(mem[math.floor(x/4+y*16)+screenpos],x%4*2)%4
    --return v,v,v
    return r[v],g[v],b[v]
  end)
  renderscreen:replacePixels(renderdata)
  love.graphics.clear(0,0,0)
  love.graphics.draw(renderscreen,screen.x,screen.y,0,screen.scale,screen.scale)

  love.graphics.print(love.timer.getFPS(),1,1)
end

function love.keypressed(key)
  if key=="escape" then
    love.event.quit()
  end
  if currentscene.keypressed then currentscene.keypressed(key) end
end

function love.keyreleased(key)
  if currentscene.keyreleased then currentscene.keyreleased(key) end
end


function love.textinput(key)
  if currentscene.textinput then currentscene.textinput(key) end
end

function love.wheelmoved(x,y)
  if currentscene.wheelmoved then currentscene.wheelmoved(x,y) end
end