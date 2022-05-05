
local ffi

print(love.system.getOS())
if love.system.getOS()=="Web" then
  bit=(require"bitreplace").bit
else
  bit = require 'bit'
  ffi = require 'ffi'
end

memsize=2^14
mem_map={
  code=0x0,   --to fff
  code_length=0xfff-0x0,

  -- large gap, general purpouse.

  hirez=0x1a00,
  print_cursor_x=0x1a01,
  print_cursor_y=0x1a02,
  last_draw_x=0x1a03,
  last_draw_y=0x1a04,
  --gap

  screen_pal=0x1a10,--to 1b13
  draw_pal=0x1a14,--to 1a17 
  transparency_pal=0x1a18,--to 1a1b

  stack_pointer_a=0x1e00,
  stack_start_a=0x1e01,--to 1eff
  stack_pointer_b=0x1f00,
  stack_start_b=0x1f01,--to 1fff

  sprites=0x2000,--to 22ff
  
  screen=0x2300,--to 25ff

  screen_length=0x25ff-0x2300,

}


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
local function updatemouse()
  local mx,my=love.mouse.getPosition()
  mx=math.floor((mx-screen.x)/screen.scale*(mem[mem_map.hirez]==1 and 2 or 1))
  my=math.floor((my-screen.y)/screen.scale)
  mouse.p_lb=mouse.lb
  mouse.p_rb=mouse.rb
  mouse.p_mb=mouse.mb
  mouse.p_x=mouse.x
  mouse.p_y=mouse.y
  mouse.p_onscreen=mouse.onscreen

  mouse.lb=love.mouse.isDown(1)
  mouse.rb=love.mouse.isDown(2)
  mouse.mb=love.mouse.isDown(3)
  mouse.x,mouse.y=mx,my
  mouse.onscreen = my==boundscreen_y(my) and mx==boundscreen_x(mx)
end

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

  --these point to the same data, but one sets/gets in the range 0 to 255 and the other sets/gets in the range -128 to 127.
  if ffi then
    base_mem = love.data.newByteData(memsize)
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

  love.window.setIcon(love.image.newImageData("assets/logo.png"))
  love.window.setTitle("femto-4")

  font=love.image.newImageData("assets/font.png")
  
  renderdata=love.image.newImageData(64,48)
  renderscreen=love.graphics.newImage(renderdata)
  
  renderdata_double_width=love.image.newImageData(128,48)
  renderscreen_double_width=love.graphics.newImage(renderdata_double_width)

  local pows={}
  for l=0,7 do pows[l]=2^l end
  --[[
    local byte_img_pre=love.image.newImageData(1,256)
    byte_w=1
    byte_img_pre:mapPixel(function(x,y)
      local v=(y+1)/256
      return v,v,v
    end)
  --]]
  ---[[
    local byte_img_pre=love.image.newImageData(4,256)
    byte_w=4
    byte_img_pre:mapPixel(function(x,y)
      x=bit.band(x,bit.bnot(0x1))
      local v=bit.band(bit.rshift(y,pows[x]),0x3)/3
      return v,v,v
    end)
  --]]
  --[[
    local byte_img_pre=love.image.newImageData(8,256)
    byte_w=8
    byte_img_pre:mapPixel(function(x,y)
      local v=bit.band(y,pows[x])>0 and 1 or 0
      return v,v,v
    end)
  --]]
  byte_img=love.graphics.newImage(byte_img_pre)
  byte_sprite_batch = love.graphics.newSpriteBatch(byte_img)
  byte_quads={}
  for l=0,255 do
    byte_quads[l]=love.graphics.newQuad(0,l,byte_w,1,byte_img:getDimensions())
  end
  
  cart_manip=require"cart_manip"
  
  confstate=require"settings"
  execstate=require"execute"
  codestate=require"code"
  drawstate=require"draw"
  teststate=require"test" --test state isn't to be shown to the user, really
  buttons  =require"editorbuttons"

  --change this to change the starting state
  --at the moment should be codestate!
  currentscene=codestate
 
  mem[mem_map.hirez]=confstate.settings.editor_settings.display.hires and 1 or 0
  for l=0,3 do
    mem[mem_map.screen_pal+l]=confstate.settings.editor_settings.display.editor_pal[l+1]  --init screen pallete
    mem[mem_map.draw_pal+l]=l  --init draw pallete
    mem[mem_map.transparency_pal+l]=1  --init transparency pallete
  end
end

t=0

function love.resize(w,h)
  screen.scale=math.min(w*0.75,h)/48
  --screen.scale=math.min(w,h)/64
  screen.x=w/2-screen.scale*32
  screen.y=h/2-screen.scale*24
end

local repeatfn
local repeatkey
local repeattimer=0
local keysource

escape_timer=0
function love.update(dt)
  if repeatkey then
    repeattimer=repeattimer+dt
    if repeattimer>confstate.settings.editor_settings.keyboard.delay then
      repeattimer=repeattimer-confstate.settings.editor_settings.keyboard["repeat"]
      if repeatfn then repeatfn(repeatkey,true) end
    end
  end
  if love.keyboard.isDown("escape") then
    escape_timer=escape_timer+dt
    if escape_timer>=.75 then love.event.quit() end
  else
    escape_timer=0
  end
  
  t=t+dt
  if currentscene.update then currentscene.update(dt) end
  updatemouse()
  if currentscene.draw then currentscene.draw(t) end
end

function love.draw()
  --sy=64+math.sin(t)*8

  love.graphics.clear()
  local r={}
  local g={}
  local b={}
  

  for l=0,3 do
    local palindex=mem[mem_map.screen_pal+l]
    r[l],g[l],b[l]=pal:getPixel(palindex%16,math.floor(palindex/16))
  end
  local render_mode=mem[mem_map.hirez]
  local renderdata=renderdata
  local renderscreen=renderscreen
  local xmult,ymult=1,1
  if render_mode==1 then
    xmult=0.5
    renderdata=renderdata_double_width
    renderscreen=renderscreen_double_width
    renderdata:mapPixel(function(x,y)
      -- mem[x+y*16+screen]>>x&7
      local v=bit.band(bit.rshift(mem[bit.rshift(x,3)+bit.lshift(y,4)+mem_map.screen],bit.band(x,7)),1)
      --return v,v,v
      return r[v],g[v],b[v]
    end)
    renderscreen:replacePixels(renderdata)
  else
    renderdata:mapPixel(function(x,y)
      local v=bit.band(bit.rshift(mem[math.floor(bit.rshift(x,2)+bit.lshift(y,4))+mem_map.screen],bit.lshift(bit.band(x,3),1)),3)
      --return v,v,v
      return r[v],g[v],b[v]
    end)
  end
  renderscreen:replacePixels(renderdata)
  love.graphics.clear(0,0,0)
  love.graphics.draw(renderscreen,screen.x,screen.y,0,screen.scale*xmult,screen.scale*ymult)

  if escape_timer>0 then
    love.graphics.print("quitting"..string.rep(".",math.floor(escape_timer*4)),screen.x,screen.y,0,2,2)
  end

  --[[
    local dx,dy=screen.x+screen.scale*xmult*64+byte_w*3,0
    byte_sprite_batch:clear()
    for y=0,255 do
      byte_sprite_batch:add(byte_quads[y],dx-byte_w*3,dy+y*2,0,2,2)
      for x=0,255 do
        byte_sprite_batch:add(byte_quads[ mem[x+y*256] ],dx+x*byte_w*2,dy+y*2,0,2,2)
      end
    end
    love.graphics.draw(byte_sprite_batch)
  --]]

  love.graphics.print(love.timer.getFPS(),1,1)
end


function love.keypressed(key)
  repeatkey=key
  repeattimer=0
  repeatfn=currentscene.keypressed
  keysource="keypressed"
  if currentscene.keypressed then currentscene.keypressed(key) end
end

function love.keyreleased(key)
  repeatkey=nil
  if currentscene.keyreleased then currentscene.keyreleased(key) end
end

function love.textinput(key)
  if repeatkey==key and keysource=="textinput" then return end
  repeatkey=key
  repeattimer=0
  keysource="textinput"
  repeatfn=currentscene.textinput
  if currentscene.textinput then
    currentscene.textinput(key)
  end
end

function love.wheelmoved(x,y)
  if currentscene.wheelmoved then currentscene.wheelmoved(x,y) end
end

function love.mousepressed()
  updatemouse()
  if currentscene.mousedown then currentscene.mousedown() end
end

