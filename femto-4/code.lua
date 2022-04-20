local s={}
s.code=code or {}

local function refresh_bounds()
  s.editing_row=mid(0,s.editing_row,#s.code[s.editing_line])
end

function cursorpos(line,row)
  local colon=s.code[line]:find(":",nil,true) or 0
  return row*4+15-colon*4
end

code_length=0

local function recalc_length()
  s.code_length=#s.code-1
  for l=1,#s.code do s.code_length=s.code_length+#s.code[l] end

end

local ctrlheld=false
local shiftheld=false

local function resetselect()
  if not shiftheld and selecting then
    print("deselected",shiftheld)
    selecting=false
  end
end

local function remove_selected(replace)
  local l_lect_line,l_lect_row=s.select_line,s.select_row
  local l_editing_line,l_editing_row=s.editing_line,s.editing_row
  if s.editing_line<s.select_line or (s.editing_line==s.select_line and s.editing_row<s.select_row) then
    
    l_lect_line,l_lect_row=s.editing_line,s.editing_row
    l_editing_line,l_editing_row=s.select_line,s.select_row
  end
  local firstpart=s.code[l_lect_line]:sub(1,l_lect_row)
  local lastpart=s.code[l_editing_line]:sub(l_editing_row+1,-1)
  for l=l_lect_line+1,l_editing_line do
    table.remove(s.code,l_lect_line)
  end
  selecting=false
  s.code[l_lect_line]=firstpart..replace..lastpart
  s.editing_line=l_lect_line
  s.editing_row=#firstpart+#replace
end

function get_selected()
  local l_select_line,l_select_row=s.select_line,s.select_row
  local l_editing_line,l_editing_row=s.editing_line,s.editing_row
  if s.editing_line<s.select_line or (s.editing_line==s.select_line and s.editing_row<s.select_row) then
    
    l_select_line,l_select_row=s.editing_line,s.editing_row
    l_editing_line,l_editing_row=s.select_line,s.select_row
  end
  local firstpart=s.code[l_select_line]:sub(l_select_row+1,-1)
  local lastpart=s.code[l_editing_line]:sub(1,l_editing_row)
  if l_editing_line~=l_select_line then
    local txt=""
    for l=l_select_line+1,l_editing_line-1 do
      txt=txt..s.code[l].."\n"
    end
    return firstpart.."\n"..txt..lastpart
  else
    return s.code[l_editing_line]:sub(l_select_row+1,l_editing_row)
  end
end


s.editing_line=1
s.editing_row=0

s.select_line=1
s.select_row=0

s.code_scrollpos=0

s.changed=true

local mouseselect=false

local function loadcode()
  if s.changed then
    s.changed=false
    execstate.writeinstructions(s.code)
  end
  execstate.init()
  currentscene=execstate
end

function s.update()
  if love.mouse.isDown(1) and mouse.onscreen then
    local new_line=flr((mouse.y-2+s.code_scrollpos*4)/4)
    if not shiftheld then selecting=false end
    if s.code[new_line] then
      local new_row=flr((mouse.x-cursorpos(new_line,0)+1)/4)
      s.editing_line=new_line
      s.editing_row=mid(0,new_row,#s.code[s.editing_line])
      if mouseselect then
        selecting=true
        mouseselect=false
        s.select_line,s.select_row=s.editing_line,s.editing_row
      end
    end
    if mouse.y<=4 then loadcode() end
  end
end

function s.mousedown()
  if shiftheld then
    mouseselect=true
  end
end

function s.draw()
    local yoffset=s.code_scrollpos*4
    cls(0)
    i=math.floor(t*30)%4
    --mem[0x346+i]=(mem[0x346+i]+1)%16
    local showcursor=t-math.floor(t)>.5
    for i,line in ipairs(s.code) do
      local colon=line:find(":",nil,true) or 0
      local displayline=line
      if colon then displayline=line:sub(colon+1,-1) end

      local index=pad(tostring(i),3," ")
      --selection background
      if (sign(i-s.select_line) ~= sign(i-s.editing_line) or i==s.select_line) and t%0.5>.25 and selecting then
        local x1,x2=-1,64
        local l_lect_line,l_lect_row=s.select_line,s.select_row
        local l_editing_line,l_editing_row=s.editing_line,s.editing_row
        if s.editing_line<s.select_line or (s.editing_line==s.select_line and s.editing_row<s.select_row) then
        
          l_lect_line,l_lect_row=s.editing_line,s.editing_row
          l_editing_line,l_editing_row=s.select_line,s.select_row
        end
        if i==l_lect_line then
          x1=cursorpos(l_lect_line,l_lect_row)+1
        end
        if i==l_editing_line then
          x2=cursorpos(l_editing_line,l_editing_row)+1
        end
        if not(s.editing_line==s.select_line and s.editing_row==s.select_row) then rect(x1,i*4+1-yoffset,x2,i*4+5-yoffset,3) end
      end
      if colon>0 then
        sc_write(pad(line:sub(1,colon),4," "),1,i*4+2-yoffset,2)
      else
        sc_write(index,1,i*4+2-yoffset,3)
        sc_write(":",nil,nil,3)
      end
      sc_write(displayline,17,i*4+2-yoffset,2)
      if i==s.editing_line and showcursor then sc_write("|",cursorpos(s.editing_line,s.editing_row),i*4+2-yoffset,1) end
    end
    rectfill(0,0,63,4,1)
    rectfill(0,42,63,47,1)
    rectfill(0,42,63,47,1)
    sc_write("code",1,1,0)
    
    plot_imgdata(cursor,mouse.x,mouse.y,5)
end

local lastkey=""
function s.textinput(key)
  if ctrlheld then return end
  s.changed=true
  lastkey=key

  if #key==1 then
    local cur_line=s.code[s.editing_line]
    if selecting then
      remove_selected(key)
    else
      s.code[s.editing_line]=insert_char(cur_line,s.editing_row,key) s.editing_row=s.editing_row+1
    end
  end
end


function s.keypressed(key)
  s.changed=true
  local lastline=s.editing_line
  local cur_line=s.code[s.editing_line]
  refresh_bounds()
  if     key=="down"  then s.editing_line=s.editing_line+1 resetselect()
  elseif key=="up"    then s.editing_line=s.editing_line-1 resetselect()
  elseif key=="left"  then
    s.editing_row = s.editing_row-1 
    if s.editing_row==-1 and s.editing_line>1 then
      s.editing_line=s.editing_line-1
      if s.code[s.editing_line] then s.editing_row=#s.code[s.editing_line] end
    end
    resetselect()
  elseif key=="right" then
    s.editing_row = s.editing_row+1
    if s.editing_row>#s.code[s.editing_line] and s.editing_line<#s.code then
      s.editing_line=s.editing_line+1
      if s.code[s.editing_line] then s.editing_row=0 end
    end
    resetselect()
  elseif key=="backspace" then
    if selecting then
      remove_selected("")
    else
      if s.editing_row==0 and s.editing_line>1 then
        s.code[s.editing_line-1],s.editing_row=s.code[s.editing_line-1]..code[s.editing_line],#s.code[s.editing_line-1]
        table.remove(s.code,s.editing_line)
        s.editing_line=s.editing_line-1
      else
        s.code[s.editing_line]=del_char(cur_line,s.editing_row) s.editing_row=s.editing_row-1
      end
    end
  elseif key=="return" then
    if selecting then
      s.keypressed("backspace")
      s.keypressed("return")
    else
      table.insert(s.code,s.editing_line+1,cur_line:sub(s.editing_row+1,-1))
      s.code[s.editing_line]=cur_line:sub(1,s.editing_row) s.editing_line=s.editing_line+1 s.editing_row=0
    end
  elseif key=="lshift" then
    if not selecting then
      s.select_line,s.select_row=s.editing_line,s.editing_row
    end
    selecting=true
    shiftheld=true
  elseif key=="lctrl" then ctrlheld=true
  elseif key=="space" then s.keypressed(" ")
  elseif key=="c" and ctrlheld then
    if selecting and ctrlheld then
      local txt=get_selected()
      love.system.setClipboardText(txt)
    end
  elseif key=="v" and ctrlheld then
    if selecting then remove_selected("") end
    local add_txt=love.system.getClipboardText()
    local _,newlines=add_txt:gsub("\n","")
    local l=0
    for st in add_txt:gmatch("[^\n]+") do
      l=l+1
      code[s.editing_line]=insert_char(code[s.editing_line],s.editing_row,st)
      s.editing_row=s.editing_row+#st
      if l<=newlines then
        s.keypressed("return")
      end
    end
  elseif key=="a" and ctrlheld then
    s.select_line=1
    s.select_row=0
    s.editing_line=#s.code
    s.editing_row=#(s.code[#s.code])
    selecting=true
  elseif key=="x" and ctrlheld then
    local txt=get_selected()
    love.system.setClipboardText(txt)
    remove_selected("")
  elseif key=="r" and ctrlheld then
    loadcode()
  end
  if s.editing_line~=lastline and s.code[s.editing_line] and s.code[lastline] then
    local lastcolon=s.code[lastline]:find(":",nil,true) or 0
    local colon=s.code[s.editing_line]:find(":",nil,true) or 0
    s.editing_row=s.editing_row-lastcolon+colon
    while s.editing_line<s.code_scrollpos+2 and s.code_scrollpos>0 do s.code_scrollpos=s.code_scrollpos-.5 end
    while s.editing_line>s.code_scrollpos+7.5 do s.code_scrollpos=s.code_scrollpos+.5 end

  end
  s.editing_line=mid(1,s.editing_line,#s.code)
  refresh_bounds()
  recalc_length()
end

function s.keyreleased(key)
  if key=="lshift" then
    shiftheld=false
  elseif key=="lctrl" then
    ctrlheld=false
  end
end

function s.wheelmoved(_,y)
  s.code_scrollpos=s.code_scrollpos-y
  s.code_scrollpos=math.min(s.code_scrollpos,#s.code-7.5)
  s.code_scrollpos=math.max(0,s.code_scrollpos)
end

return s