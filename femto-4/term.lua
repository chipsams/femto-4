local s={}

s.lines={"","",""}

s.default_filename="untitled.f4"

function term_print(st)
  local w=mem[mem_map.hirez]==1 and 32 or 16
  st:gsub("[^\n]+",function(st)
    for l=1,#st,w do
      table.insert(s.lines,st:sub(l,l+15))
    end
  end)
end

s.inputstring=""
s.scrollrow=0

s.commands={
  {
    name="echo",
    fn=function(...)
      local args={...}
      for l, arg in pairs(args) do args[l]=process_string(arg) end
      table.insert(s.lines,table.concat(args," "))
    end,
    helpmsg="echoes it's arguments back to the console",
  },{
    name="quit",
    fn=function(...)
      love.event.quit()
      
    end,
    helpmsg="quits femto.",
  },
  {
    name="help",
    fn=function(command)
      if s.commands[command] then
        term_print(s.commands[command].helpmsg)
      elseif command=="commands" then
        for _,command in ipairs(s.commands) do
          term_print(command.name)
        end
      else
        term_print("help commands:")
        term_print(" get a command")
        term_print(" list.")
      end
    end,
    helpmsg="displays help",
  },
  {
    name="save",
    fn=function(unpro_filename,...)
      unpro_filename=unpro_filename or s.default_filename
      local filename=process_string(unpro_filename)
      if filename==unpro_filename then
        filename=table.concat({unpro_filename,...},"")
      end
      s.default_filename=filename
      if filename:match("%.f4%.png") then
        cart_manip.saveimg("carts/"..filename)
        term_print("wrote to\n"..filename)
      else
        if not filename:match("%.f4$") then filename=filename..".f4" end
        love.filesystem.write("carts/"..filename,cart_manip.tostring())
        term_print("wrote to\n"..filename)
      end
    end,
    helptxt="saves a file. if it ends in .f4.png then the file is saved in the png format."
  },
  {
    name="load",
    fn=function(unpro_filename,...)
      unpro_filename=unpro_filename or s.default_filename
      local filename=process_string(unpro_filename)
      if filename==unpro_filename then
        filename=table.concat({unpro_filename,...},"")
      end
      s.default_filename=filename
      if love.filesystem.getInfo("carts/"..filename) then
        term_print("opening file")
        cart_manip.openfile(love.filesystem.newFile("carts/"..filename),"command line")
      else
        term_print("couldn't find it")
      end
    end,
    helptxt="load"
  }
}

for _,command in pairs(s.commands) do
  s.commands[command.name]=command
end


function s.draw(t)
  cls(0)
  plot_imgdata(top_of_term,0,-s.scrollrow*4)
  sc_write("",1,1-(s.scrollrow-math.floor(s.scrollrow))*4,0)
  for l=math.floor(s.scrollrow+1),s.scrollrow+14 do
    if s.lines[l] then
      sc_write(s.lines[l].."\n",nil,nil,2)
    end
  end
  sc_write("> ",nil,nil,3)
  local x=mem[mem_map.print_cursor_x]
  sc_write(s.inputstring,nil,nil,2)
  if t%1>.5 then sc_write("_",nil,nil,2) end
  local st=tostring(s.scrollrow)
  sc_write(st,63-#st*4,43,1)
end

function s.wheelmoved(x,y)
  s.scrollrow=s.scrollrow-y/2
  s.scrollrow=mid(0,s.scrollrow,#s.lines)
end


local ctrldown

function s.textinput(key)
  if not ctrldown then
    s.inputstring=s.inputstring..key
  end
end

function s.keypressed(key,isrepeat)
  if key=="escape" then
    currentscene=lasteditorstate
  elseif key=="lctrl" then
    ctrldown=true
  elseif key=="r" and ctrldown then
    ctrldown=false
    loadcode()
  elseif key=="backspace" then
    s.inputstring=s.inputstring:sub(0,-2)
  elseif key=="return" then
    term_print("> "..s.inputstring)
    local command=s.inputstring:match("^%s*(%l+)")
    if s.commands[command] then
      local args=tokenize(s.inputstring)
      table.remove(args,1)
      s.commands[command].fn(unpack(args))
      s.scrollrow=math.max(0,#s.lines-9)
    else
      term_print("not a valid command!")
      
      s.scrollrow=math.max(0,#s.lines-9)
    end
    s.inputstring=""
  end
end

function s.keyreleased(key)
  if key=="lctrl" then
    ctrldown=false
  end
end

return s