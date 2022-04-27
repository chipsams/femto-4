local s={}

local toml=require("toml_lua/toml")
s.settings_default={
  editor_pal={0,1,2,3},
  hires=false
}

if love.filesystem.getInfo("config.toml") then
  local data=love.filesystem.read("config.toml")
  print("data:",data)
  s.settings=toml.parse(data,{})
  deep_print({set=s.settings})
  print(s.settings.editor_pal)
  deep_default(s.settings,s.settings_default)
else
  s.settings=deep_clone(s.settings_default)
end

print("completed load")

local function savesettings()
  love.filesystem.write("config.toml",toml.encode(deep_clone(s.settings)))
end


function s.mousedown()
  
  for _,v in pairs(s.display) do
    if v.type=="text" and mouse.x>=v.x and mouse.x<=v.x+#v.txt*4 and mouse.y>=v.y and mouse.y<=v.y+3 then
      if v.click then v.click() end
    end
  end
  s.display={}
  calctab(s.settings_layout,1,6)
  buttons.mousedown()
end

s.settings_layout={
  {
    type="tab",
    open=true,
    name="pallete",
    contents={
      {type="number",name="col 0",min=0,max=255,target={s.settings.editor_pal,1}},
      {type="number",name="col 1",min=0,max=255,target={s.settings.editor_pal,2}},
      {type="number",name="col 2",min=0,max=255,target={s.settings.editor_pal,3}},
      {type="number",name="col 3",min=0,max=255,target={s.settings.editor_pal,4}},
    },
  },
  {type="toggle",name="hi res",target={s.settings,"hires"}}
}

s.display={}
function calctab(contents,dx,dy)
  for k,v in pairs(contents) do
    --sc_write(v.type,s.dx,s.dy,3)
    if v.type=="tab" then
      local function togglev()
        v.open=not v.open
      end
      sc_write(v.name,dx,dy,2)
      table.insert(s.display,{type="text",txt=v.name,x=dx,y=dy,c=2,click=togglev})
      table.insert(s.display,{type="text",txt=v.open and "v" or ">",x=dx+#v.name*4+1,y=dy,c=3,click=togglev})
      local pdy=dy
      if v.open then
        dy=calctab(v.contents,dx+4,dy+4)
        table.insert(s.display,{type="line",x1=dx+2,y1=pdy+4,x2=dx+2,y2=dy-2,c=3})
      else
        dy=dy+4
      end
    elseif v.type=="number" then
      table.insert(s.display,{type="text",txt=v.name..":"..v.target[1][v.target[2]],x=dx,y=dy,c=1,click=function()
        print(mouse.lb)
        local inc=mouse.lb and 1 or -1
        v.target[1][v.target[2]]=(v.target[1][v.target[2]]+inc-v.min)%(v.max-v.min+1)+v.min
        savesettings()
      end})
      dy=dy+4
    elseif v.type=="toggle" then
      table.insert(s.display,{type="text",txt=v.name..":"..(v.target[1][v.target[2]] and "O" or "."),x=dx,y=dy,c=1,click=function()
        v.target[1][v.target[2]]=not v.target[1][v.target[2]]
        savesettings()
      end})
      dy=dy+4
    end
  end
  return dy
end


calctab(s.settings_layout,1,6)
function s.draw()
  cls(0)
  for _,v in pairs(s.display) do
    if v.type=="text" then
      sc_write(v.txt,v.x,v.y,v.c)
    elseif v.type=="line" then
      line(v.x1,v.y1,v.x2,v.y2,v.c)
    end
  end
  rectfill(0,0,127,4,1)
  rectfill(0,42,127,47,1)
  rectfill(0,42,127,47,1)
  buttons.draw()
  sc_write("settings",1,1,0)
  plot_imgdata(cursor,mouse.x,mouse.y)
end


return s