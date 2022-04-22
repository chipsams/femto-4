
local ffi

print(love.system.getOS())
if love.system.getOS()=="Web" then
  bit=(require"bitreplace").bit
else
  bit = require 'bit'
  ffi = require 'ffi'
end
print(bit)

-- 000 - 0ff : aloc memory
-- 100 - 33f : general purpouse
-- 340 - 35f : poke flags/memory map stuff (e.g. button state)
-- 340-343: button bitmasks (341-343 likely unused for a while, multiple controlers sounds annoying to implement)
-- 344,345: print cursor
-- 346-349: screen pallete
-- 34a-34e: draw pallete
-- 34f: draw colour
-- 350,351: last draw x,y. used for line & rect
-- 35f: stack pointer
-- 360 - 3ff : stack
-- 400 - 7ff : sprites [2 bpp, 4x4] = 192 sprites
-- 800 - aff : screen [2bpp] = 64x48 screen
-- b00 - fff : code, each operation is 2 bytes (although some may take more, e.g. string, which reads bytes until it hits 0, writing each bit to the specified position in gp memory.)

fps_cap=31
window={
  h=320,
  w=480
}
mouse={
  x=0,
  y=0,
  onscreen=false
}

--because love.run doesn't seem to work over there?
if love.system.getOS()~="Web" then
  function love.run()
    if love.load then love.load(love.arg.parseGameArguments(arg), arg) end
    
    -- We don't want the first frame's dt to include time taken by love.load.
    if love.timer then love.timer.step() end
    
    local dt = 0
    
    -- Main loop time.
    return function()
      -- Process events.
      if love.event then
        love.event.pump()
        for name, a,b,c,d,e,f in love.event.poll() do
          if name == "quit" then
            if not love.quit or not love.quit() then
              return a or 0
            end
          end
          love.handlers[name](a,b,c,d,e,f)
        end
      end

      -- Update dt, as we'll be passing it to update
      if love.timer then dt = love.timer.step() end
      
      -- Call update and draw
      if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled

      if love.graphics and love.graphics.isActive() then
        love.graphics.origin()
        love.graphics.clear(love.graphics.getBackgroundColor())

        if love.draw then love.draw() end

        love.graphics.present()
      end

      if love.timer then love.timer.sleep(1/fps_cap) end
    end
  end
end

function love.load()
  love.graphics.setDefaultFilter( "nearest" )
  screenpos=0x800
  spritepos=0x400

  --these point to the same data, but one sets/gets in the range 0 to 255 and the other sets/gets in the range -128 to 127.
  if ffi then
    base_mem = love.data.newByteData(2 ^ 12)
    mem=ffi.cast("uint8_t*", base_mem:getFFIPointer())
    memsigned=ffi.cast("int8_t*", base_mem:getFFIPointer())
  else
    --shame this has to happen for web support :/
    base_mem={}
    for l=1,2^12 do base_mem[l]=0 end
    mem=setmetatable({},{
      __index=function(_,i) return base_mem[i] end,
      __newindex=function(_,i,v) base_mem[i]=math.floor(v)%256 end
    })
    memsigned=setmetatable({},{
      __index=function(_,i) local v=base_mem[i] return v>127 and v-256 or v end,
      __newindex=function(_,i,v) v=math.floor(v)%256 base_mem[i]=v end
    })
  end


  require"graphics"
  print("graphics loaded")
  screen={
    x=0,
    y=0,
    scale=1,
  }

  love.window.setMode(window.w,window.h,{resizable=true})
  love.resize(window.w,window.h)
  --[[
    screen.scale=math.min(window.w*0.75,window.h)/48
    screen.x=window.w/2-screen.scale*32
    screen.y=window.h/2-screen.scale*24
  --]]

  love.mouse.setVisible(false)
  page_select_cursor_png=love.image.newImageData("assets/page_select_cursor.png")
  cursor=love.image.newImageData("assets/cursor.png")
  pal=love.image.newImageData("assets/pallete.png")
  for l=0,3 do
    mem[0x346+l]=l  --init screen pallete
    mem[0x34a+l]=l  --init draw pallete
  end

  mem[0x346]=0

  love.window.setIcon(love.image.newImageData("assets/logo.png"))
  love.window.setTitle("femto-4")

  font=love.image.newImageData("assets/font.png")
  
  renderdata=love.image.newImageData(64,64)
  renderscreen=love.graphics.newImage(renderdata)
  
  execstate=require"execute"
  codestate=require"code"
  drawstate=require"draw"
  teststate=require"test" --test state isn't to be shown to the user, really
  buttons  =require"editorbuttons"

  --change this to change the starting state
  --at the moment should be codestate!
  currentscene=codestate
end

t=0


code={}

([[
cls 0
lop:adc x + 1
plt x x x
jmp lop
]]):gsub("[^\n]+",function(v)
  table.insert(code,v)
end)--pre-populate the code area.

function love.resize(w,h)
  --screen.scale=math.min(w*0.75,h)/48
  screen.scale=math.min(w,h)/64
  screen.x=w/2-screen.scale*32
  screen.y=h/2-screen.scale*32
end

escape_timer=0
function love.update(dt)
  if love.keyboard.isDown("escape") then
    escape_timer=escape_timer+dt
    if escape_timer>=.75 then love.event.quit() end
  else
    escape_timer=0
  end
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
    r[l],g[l],b[l]=pal:getPixel(palindex%16,math.floor(palindex/16))
  end
  renderdata:mapPixel(function(x,y)
    local v=bit.rshift(mem[math.floor(bit.rshift(x,2)+bit.lshift(y,4))+screenpos],x%4*2)%4
    --return v,v,v
    return r[v],g[v],b[v]
  end)
  renderscreen:replacePixels(renderdata)
  love.graphics.clear(0,0,0)
  love.graphics.draw(renderscreen,screen.x,screen.y,0,screen.scale,screen.scale)

  if escape_timer>0 then
    love.graphics.print("quitting"..string.rep(".",math.floor(escape_timer*4)),screen.x,screen.y,0,2,2)
  end

  love.graphics.print(love.timer.getFPS(),1,1)
end

function love.keypressed(key)
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

function love.mousepressed()
  if currentscene.mousedown then currentscene.mousedown() end
end