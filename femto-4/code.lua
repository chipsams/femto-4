local s={}
s.code={""}

s.errors={}
for l=1,#s.code do
  s.errors[l]={}
end

function match(token,pattern)
  for k,v in ipairs(pattern) do
    if v=="n" and better_tonumber(token) then return true,"number"
    elseif v=="r" and reg_names[token] then return true,"register"
    elseif v=="l" and not token:find("[^%l%d_]") then return true,"label"
    elseif v=="." then return true,"any"
    elseif v:sub(1,1)=="'" and token:match(v:sub(2,-1)) then return true,"pattern"
    end
  end
  return false,pattern.err_message
end

function match_tokens(matchline,pattern)
  local tokens,token_ranges=tokenize(matchline)
  --print(unpack(tokens))
  local errors={}
  local pattern_parts={}
  pattern:gsub("%S+",function(v)
    local pattern_part={}
    pattern_part.original=v
    local err_message="error (unspecified)"
    if v:sub(-1,-1)=="?" then pattern_part.optional=true v=v:sub(1,-2) end
    v=v:gsub("(.*)£(.*)",function(other,message)
      err_message=message
      return other
    end)
    v:gsub("[^|]+",function(v)
      table.insert(pattern_part,v)
    end)
    pattern_part.err_message=err_message
    table.insert(pattern_parts,pattern_part)
  end)
  local tok_i=1
  while tok_i<=#tokens do
    if #pattern_parts==0 then table.insert(errors,{c=1,token="",range={#matchline,#matchline-1},error="too many tokens!"}) return errors end
    local token=tokens[tok_i]
    --print(pattern_parts[1].optional and "?" or "",unpack(pattern_parts[1]))
    local success,err=match(token,pattern_parts[1])
    --print(pattern_parts[1].original,success and "accepted" or "rejected",token,matchline:sub(token_ranges[tok_i][1],token_ranges[tok_i][2]))
    if pattern_parts[1].optional and not success then
      table.remove(pattern_parts,1)
    else
      if not success then
        table.insert(errors,{c=1,token=token,range=token_ranges[tok_i] or {#matchline,#matchline-1},error=err})
      else
        --table.insert(errors,{c=3,token=token,range=token_ranges[tok_i] or {#matchline,#matchline-1},error=err})
      end
      table.remove(pattern_parts,1)
      tok_i=tok_i+1
    end
  end
  while #pattern_parts>0 do
    if pattern_parts[1].optional then table.remove(pattern_parts,1) else break end
  end
  if #pattern_parts>0 then table.insert(errors,{c=1,token="",range={#matchline,#matchline-1},error="not enough tokens!"}) return errors end
  return errors
end

function s.errorcheck(linenum)
  --print(("\n"):rep(10))
  local o_chkline=s.code[linenum]
  
  local chkline=o_chkline:gsub("~.*$","")
  s.errors[linenum]={}
  local colon=o_chkline:find(":")
  if colon then chkline=o_chkline:sub(colon+1,-1) end
  local name=chkline:match("([a-z]+)(.*)")
  local errors={}
  if op_errorcheck[name] then
    errors=match_tokens(chkline,op_errorcheck[name])
  else
    if name then errors={{c=1,range={1,#name},error="not a valid op"}} end
  end
  if colon then
    for _,error in pairs(errors) do
      error.range[1]=error.range[1]+colon
      error.range[2]=error.range[2]+colon
    end
  end
  --for _,error in pairs(errors) do print(error.error,o_chkline:sub(error.range[1],error.range[2])) end
  s.errors[linenum]=errors
end

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

local function recalc_screen()
  while s.editing_line<s.code_scrollpos+2 and s.code_scrollpos>0 do s.code_scrollpos=s.code_scrollpos-.5 end
  while s.editing_line>s.code_scrollpos+7.5 do s.code_scrollpos=s.code_scrollpos+.5 end
  while math.floor(cursorpos(s.editing_line,1)/4)+s.editing_row<s.code_scrollrow+2 do s.code_scrollrow=s.code_scrollrow-.5 end
  while math.floor(cursorpos(s.editing_line,1)/4)+s.editing_row>s.code_scrollrow+(mem[mem_map.hirez]==1 and 29.5 or 14.5) do s.code_scrollrow=s.code_scrollrow+.5 end
end

local ctrlheld=false
local shiftheld=false

local function resetselect()
  if not shiftheld and selecting then
    --print("deselected",shiftheld)
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
    table.remove(s.errors,l_lect_line)
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
s.code_scrollrow=0

s.changed=true

local mouseselect=false

function loadcode()
  if s.changed then
    s.changed=false
    execstate.writeinstructions(s.code)
  end
  execstate.init()
  execstate.returnscene=currentscene
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
    --if mouse.y<=4 then loadcode() end
  end
end

function s.mousedown()
  if shiftheld then
    mouseselect=true
  end
  recalc_screen()
  buttons.mousedown()
end

function s.draw()
    local yoffset=s.code_scrollpos*4
    local xoffset=s.code_scrollrow*4
    cls(0)
    i=math.floor(t*30)%4
    local showcursor=t-math.floor(t)>.5

    for i=math.floor(s.code_scrollpos),s.code_scrollpos+10 do
      local code_line=s.code[i]
      if not code_line then goto continue end
      local colon=code_line:find(":",nil,true) or 0
      local displayline=code_line
      if colon then displayline=code_line:sub(colon+1,-1) end

      local index=pad(tostring(i),3," ")
      --selection background
      if (sign(i-s.select_line) ~= sign(i-s.editing_line) or i==s.select_line) and t%0.5>.25 and selecting then
        local x1,x2=-1,128
        local l_lect_line,l_lect_row=s.select_line,s.select_row
        local l_editing_line,l_editing_row=s.editing_line,s.editing_row
        if s.editing_line<s.select_line or (s.editing_line==s.select_line and s.editing_row<s.select_row) then
        
          l_lect_line,l_lect_row=s.editing_line,s.editing_row
          l_editing_line,l_editing_row=s.select_line,s.select_row
        end
        if i==l_lect_line then
          x1=cursorpos(l_lect_line,l_lect_row)+1-xoffset
        end
        if i==l_editing_line then
          x2=cursorpos(l_editing_line,l_editing_row)+1-xoffset
        end
        if not(s.editing_line==s.select_line and s.editing_row==s.select_row) then rect(x1,i*4+1-yoffset,x2,i*4+5-yoffset,3) end
      end
      if colon>0 then
        sc_write(code_line:sub(1,colon),1-colon*4+16-xoffset,i*4+2-yoffset,mem[mem_map.hirez]==1 and 3 or 2)
      else
        sc_write(index,1-xoffset,i*4+2-yoffset,3)
        sc_write(":",nil,nil,3)
      end
      sc_write(displayline,17-xoffset,i*4+2-yoffset,mem[mem_map.hirez]==1 and 3 or 2)
      if i==s.editing_line and showcursor then sc_write("|",cursorpos(s.editing_line,s.editing_row)-xoffset,i*4+2-yoffset,1) end
      for _,error in pairs(s.errors[i]) do
        local x1,x2=cursorpos(i,error.range[1])-3-xoffset,cursorpos(i,error.range[2])+1-xoffset
        local y=i*4-yoffset+5
        if x2<=x1 then
          rect(x1,y-1,x1+2,y+1,error.c)
        else
          line(x1,y,x2,y,error.c)
        end
        if mouse.x>x1-2 and mouse.x<x2+2 and mouse.y>=y-1 and mouse.y<=y+1 then
          sc_write(error.error,x1-xoffset,y+2,1)
        end
      end
      ::continue::
    end
    rectfill(0,0,127,4,1)
    rectfill(0,42,127,47,1)
    rectfill(0,42,127,47,1)
    sc_write("code",1,1,0)
    buttons.draw()

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
    recalc_screen()
  end
  
  s.errorcheck(s.editing_line)
end


function s.keypressed(key,isrepeat)
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
        s.code[s.editing_line-1],s.editing_row=s.code[s.editing_line-1]..s.code[s.editing_line],#s.code[s.editing_line-1]
        table.remove(s.code,s.editing_line)
        table.remove(s.errors,s.editing_line)
        s.editing_line=s.editing_line-1
      else
        s.code[s.editing_line]=del_char(cur_line,s.editing_row) s.editing_row=s.editing_row-1
      end
    end
    recalc_screen()
  elseif key=="return" then
    if selecting then
      s.keypressed("backspace")
      s.keypressed("return")
    else
      table.insert(s.code,s.editing_line+1,cur_line:sub(s.editing_row+1,-1))
      table.insert(s.errors,s.editing_line+1,{})
      s.code[s.editing_line]=cur_line:sub(1,s.editing_row) s.editing_line=s.editing_line+1 s.editing_row=0
      s.errorcheck(s.editing_line)
      s.errorcheck(s.editing_line-1)
    end
  elseif key=="lshift" then
    if not selecting then
      s.select_line,s.select_row=s.editing_line,s.editing_row
    end
    selecting=true
    shiftheld=true
  elseif key=="lctrl" then ctrlheld=true
  elseif key=="space" then s.keypressed(" ")
  elseif key=="s" and ctrlheld and not isrepeat then
    local txt=cart_manip.tostring()
    love.system.setClipboardText(txt)
  elseif key=="o" and ctrlheld and not isrepeat then
    local txt=love.system.getClipboardText()
    cart_manip.fromstring(txt)
  elseif key=="c" and ctrlheld and not isrepeat then
    if selecting and ctrlheld then
      local txt=get_selected()
      love.system.setClipboardText(txt)
    end
  elseif key=="v" and ctrlheld and not isrepeat then
    if selecting then remove_selected("") end
    local add_txt=love.system.getClipboardText()
    local _,newlines=add_txt:gsub("\n","")
    local l=0
    for st in add_txt:gmatch("[^\n]+") do
      l=l+1
      s.code[s.editing_line]=insert_char(s.code[s.editing_line],s.editing_row,st)
      s.errorcheck(s.editing_line)
      s.editing_row=s.editing_row+#st
      if l<=newlines then
        s.keypressed("return")
        s.errorcheck(s.editing_line)
      end
    end
  elseif key=="a" and ctrlheld and not isrepeat then
    s.select_line=1
    s.select_row=0
    s.editing_line=#s.code
    s.editing_row=#(s.code[#s.code])
    selecting=true
  elseif key=="x" and ctrlheld and not isrepeat then
    local txt=get_selected()
    love.system.setClipboardText(txt)
    remove_selected("")
  elseif key=="e" and ctrlheld and not isrepeat then
    s.errorcheck(s.editing_line)
  elseif key=="r" and ctrlheld and not isrepeat then
    ctrlheld=false
    loadcode()
  end
  s.editing_line=mid(1,s.editing_line,#s.code)
  refresh_bounds()
  recalc_length()
  if s.editing_line~=lastline and key~="left" and key~="right" then
    if s.code[s.editing_line] and s.code[lastline] then
      local lastcolon=s.code[lastline]:find(":",nil,true) or 0
      local colon=s.code[s.editing_line]:find(":",nil,true) or 0
      s.editing_row=s.editing_row-lastcolon+colon
    end
  end
  recalc_screen()
  refresh_bounds()
  recalc_length()
  s.errorcheck(s.editing_line)
  --s.code_scrollrow=math.max(s.code_scrollrow,0)
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