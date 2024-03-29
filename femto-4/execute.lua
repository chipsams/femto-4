local s={}

function s.quit()
  mem=ffi.cast("uint8_t*", base_mem:getFFIPointer())
  memsigned=ffi.cast("int8_t*", base_mem:getFFIPointer())
  memdouble=ffi.cast("double*", base_mem:getFFIPointer())
  mem[mem_map.hirez]=confstate.settings.editor_settings.display.hires and 1 or 0
  for l=0,3 do
    mem[mem_map.screen_pal+l]=confstate.settings.editor_settings.display.editor_pal[l+1]  --init screen pallete
    mem[mem_map.draw_pal+l]=l  --init draw pallete
    mem[mem_map.transparency_pal+l]=1  --init transparency pallete
  end
  
  currentscene=s.returnscene or termstate
end

local pow2={}
for l=0,64 do pow2[l]=2^l-1 end

function bitsplit(b1,b2,splitsizes)
  local totalbit=bit.bor(bit.lshift(b1,8),b2)
  local returns={}
  for l=#splitsizes,1,-1 do
    
    table.insert(returns,1,bit.band(totalbit,pow2[splitsizes[l]]))
    totalbit=bit.rshift(totalbit,splitsizes[l])
  end
  return unpack(returns)
end

function bitpack(splitsizes,...)
  local v=0
  local vals={...}
  local bitcount=0
  for l=1,#splitsizes do
    bitcount=bitcount+splitsizes[l]
    v=bit.bor(bit.lshift(v,splitsizes[l]),bit.band(vals[l],pow2[splitsizes[l]]))
  end
  --print(bitcount)
  local bytes={}
  for l=1,bitcount,8 do
    table.insert(bytes,1,bit.band(v,255))
    v=bit.rshift(v,8)
  end
  return bytes
end

--keep this ordered from longest (at the start) to shortest (at the end)! (order outside of that doesn't matter)
ops={
  "<=>",
  "==",
  "><",
  "!=",
  "~=",
  "<>",
  "<=",
  ">=",
  "!",
  "+",
  "-",
  "=",
  ">",
  "<",
  ".",
  '"'
}

function better_tonumber(v)
  if type(v)=="number" then return v end
  if type(v)~="string" then v=tostring(v) end
  local _,_,as_hex=v:find("0x([%dabcdef]+)")
  if as_hex then return tonumber(as_hex,16) end
  local _,_,as_bin=v:find("0b([01]+)")
  if as_bin then return tonumber(as_bin,2) end
  local _,_,as_qat=v:find("0q([0123]+)")
  if as_qat then return tonumber(as_qat,4) end
  return tonumber(v)
end

function process_string(st)
  st=tostring(st)
  if st:sub(1,1)=='"' then
    local newst=""
    local escape=false
    for l=2,#st-1 do
      local ch=st:sub(l,l)
      if escape then
        if ch=="n" then
          newst=newst.."\n"
        else
          newst=newst..ch
        end
        escape=false
      elseif ch=="\\" then
        escape=not escape
      else
        escape=false
        newst=newst..ch
      end
    end
    return newst
  end
  return st
end

function tokenize(st)
  st=st:gsub("~.*$","")
  local tokens={}
  local token_areas={}
  local k=1
  local function add_token(start,endof)
    table.insert(tokens,st:sub(start,endof or k))
    table.insert(token_areas,{start,endof or k})
  end
  while k<=#st do
    local ch=st:sub(k,k)
    if st:find("0q[0123]",k)==k then
      local start=k
      k=st:find("[^0123]",k+2) or #st+1
      add_token(start,k-1)
    elseif st:find("0b[01]",k)==k then
      local start=k
      k=st:find("[^01]",k+2) or #st+1
      add_token(start,k-1)
    elseif st:find("0x[%dabcdef]",k)==k then
      local start=k
      k=st:find("[^%dabcdef]",k+2) or #st+1
      add_token(start,k-1)
    elseif st:find("%d",k)==k then
      local start=k
      k=st:find("%D",k+1) or #st+1
      add_token(start,k-1)
      
    elseif ch:find("[%a_]") then
      local start=k
      k=st:find("[^%a%d_]",k+1) or #st+1
      add_token(start,k-1)
      k=k-1
    elseif ch=='"' then
      local escaped=false
      local start=k
      while k<#st do
        k=k+1
        local ch=st:sub(k,k)
        if ch=="\\" then
          escaped=not escaped
        elseif ch=='"' then
          if escaped then
            escaped=false
          else break
          end
        else
          escaped=false
        end
      end
      add_token(start,k)
      k=k+1
    else
      for _,op in pairs(ops) do
        if st:find(op,k,true)==k then
          add_token(k,k+#op-1)
          k=k+#op-1
          break
        end
      end
    end
    k=k+1
  end
  return tokens,token_areas
end

local function get_regs(reg,...)
  if reg then
    --print("register:",reg,reg and s.registers[(reg)%8+1] and "exists" or "not real")
    return s.registers[(reg)%8+1],get_regs(...)
  end
  return
end




reg_names={
  "a","b","c",
  "x","y",
  "t",
  {"stka","stk"},
  "stkb"
}


for k,v in ipairs(reg_names) do
  if type(v)=="string" then
    reg_names[v]=k-1
  elseif type(v)=="table" then
    for _,v in pairs(v) do
      reg_names[v]=k-1
    end
  end
end
for k,v in pairs(reg_names) do
  if type(k)=="number" then
    --reg_names[k]=nil
  end
end
local function get_reg_names(reg,...)
  if reg then
    --print("register:",reg,reg and s.registers[(reg)%8+1] and "exists" or "not real")
    return reg_names[reg],get_reg_names(...)
  end
  return
end

local stats={
  {"btn_l",function() return love.keyboard.isDown("left") and 1 or 0 end},
  {"btn_r",function() return love.keyboard.isDown("right") and 1 or 0 end},
  {"btn_u",function() return love.keyboard.isDown("up") and 1 or 0 end},
  {"btn_d",function() return love.keyboard.isDown("down") and 1 or 0 end},
  {"btn_z",function() return love.keyboard.isDown("z") and 1 or 0 end},
  {"btn_x",function() return love.keyboard.isDown("x") and 1 or 0 end},
  {"btn_c",function() return love.keyboard.isDown("c") and 1 or 0 end},
  {"mouse_x",function() return mouse.onscreen and mouse.x or -1 end},
  {"mouse_y",function() return mouse.onscreen and mouse.y or -1 end},
  {"mouse_lb",function() return mouse.lb and 1 or 0 end},
  {"mouse_mb",function() return mouse.mb and 1 or 0 end},
  {"mouse_rb",function() return mouse.rb and 1 or 0 end},
  {"cpu",function() return s.cpubudget end},
  {"stk_a_size",function() return mem[mem_map.stack_pointer_a] end},
  {"stk_a_peek",function() if mem[mem_map.stack_pointer_a]>0 then return mem[mem_map.stack_start_a+mem[mem_map.stack_pointer_a]-1] else return 0 end end},
  {"stk_b_size",function() return mem[mem_map.stack_pointer_b] end},
  {"stk_b_peek",function() if mem[mem_map.stack_pointer_b]>0 then return mem[mem_map.stack_start_b+mem[mem_map.stack_pointer_b]-1] else return 0 end end},
  {"last_x",function() return memsigned[mem_map.last_draw_x] end},
  {"last_y",function() return memsigned[mem_map.last_draw_y] end},
  {"print_x",function() return memsigned[mem_map.print_cursor_x] end},
  {"print_y",function() return memsigned[mem_map.print_cursor_y] end},
  {"rnd_byte",function() return math.random(0,255) end},
  {"rnd",function() return math.random() end},
}
local stat_names={}
local stat_funcs={}
for i,stat in pairs(stats) do
  stat_funcs[i]=stat[2]
  local name=stat[1]
  if type(name)=="string" then
    stat_names[name]=i
  else
    for _,v in pairs(name) do
      stat_names[v]=i
    end
  end
end

--[[format:
{
  name,
  execute,
  parse/isvalid (returns true,b1,b2 on success, false if not a valid instruction.)
}
]]

local ops_definition={
  [0]={"hlt",function()
    s.cpubudget=0
    s.running=false
  end,function()
    return true,{0,0}
  end,"."},
  {{"add","sub","mul","div"},function(b1,b2)--add
    local _,r1,r2,r3,op=bitsplit(b1,b2,{5,3,3,3,2})
    r1,r2,r3=get_regs(r1,r2,r3)
    if op==0 then     r3(r1()+r2())
    elseif op==1 then r3(r1()-r2())
    elseif op==2 then r3(r1()*r2())
    elseif op==3 then r3(r1()/r2()) end
  end,function(id,line,_,linenum)
    local opnames={add=0,sub=1,mul=2,div=3}
    local tokens=tokenize(line)
    local opid=0
    local opname,r1n,r2n,r3n=unpack(tokens)

    if not opid then return false end

    local r1,r2,r3=get_reg_names(r1n,r2n,r3n)
    if not (r1 and r2 and r3) then
      return false
    end
    if not opnames[opname] then return false end
    return true,bitpack({5,3,3,3,2},id,r1,r2,r3,opnames[opname])
  end,". r£r1 r£r2 r£r3"},
  {{"xor","and","shf","bor"},function(b1,b2)--bitmaths
    local _,r1,r2,r3,op=bitsplit(b1,b2,{5,3,3,3,2})
    r1,r2,r3=get_regs(r1,r2,r3)
    local v1,v2=r1(),r2()
    if op==0 then     r3(bit.bxor(v1,v2))
    elseif op==1 then r3(bit.band(v1,v2))
    elseif op==2 then r3(v2 > 0 and bit.lshift(v1,v2) or bit.rshift(v1,-v2))
    elseif op==3 then r3(bit.bor(v1,v2)) end
  end,function(id,line,_,linenum)
    local opnames={["xor"]=0,["and"]=1,["shf"]=2,["bor"]=3}
    local tokens=tokenize(line)
    local opid=0
    local opname,r1n,r2n,r3n=unpack(tokens)

    if not opid then return false end

    local r1,r2,r3=get_reg_names(r1n,r2n,r3n)
    if not (r1 and r2 and r3) then
      return false
    end
    if not opnames[opname] then return false end
    return true,bitpack({5,3,3,3,2},id,r1,r2,r3,opnames[opname])
  end,". r£r1 r£r2 r£r3"},
  {{"mov","swp"},function(b1,b2)
    local _,r1,r2,swp=bitsplit(b1,b2,{5,3,3,1,4})
    r1,r2=get_regs(r1,r2)
    if swp==1 then
      local v1,v2=r1(),r2()
      r1(v2)
      r2(v1)
    else
      r2(r1())
    end
  end,function(id,line)
    local tokens=tokenize(line)
    local name,r1n,r2n=unpack(tokens)
    local r1,r2=get_reg_names(r1n,r2n)
    if not (r1 and r2) then return false,{0,0} end
    return true,bitpack({5,3,3,1,4},id,r1,r2,name=="swp" and 1 or 0,0)
  end,". r r"},
  {"adc",function(b1,b2)--add constant
    local _,t1,negative,value=bitsplit(b1,b2,{5,3,1,7})
    local r1=get_regs(t1)
    local result=r1()+value*(negative==1 and -1 or 1)
    --print("r"..t1,"("..r1()..")",negative==1 and "-" or "+",value,"=",result)
    r1(result)
  end,function(id,line)
    local tokens=tokenize(line)
    local _,r1,sign,value=unpack(tokens)
    --print('"'..(better_tonumber(value) or "?")..'"')
    if not value and better_tonumber(sign) then sign,value="+",sign end
    if not (sign=="-" or sign=="+") then return false end
    if not reg_names[r1] then return false end
    if not better_tonumber(value) then return false end
    return true,bitpack({5,3,1,7},id,reg_names[r1],sign=="-" and 1 or 0,better_tonumber(value))
  end,". r '[+%-]? n"},
  {"ldc",function(b1,b2)
    local b3=mem[s.pc+2]
    s.pc=s.pc+1
    local _,r=bitsplit(b1,0,{5,3,8})
    r=get_regs(r)
    local negative,v=bitsplit(b2,b3,{1,15})
    r(negative==1 and -v or v)
  end,function(id,line)
    local tokens=tokenize(line)
    local _,r,sign,v=unpack(tokens)
    if not v then v,sign=sign,nil end
    r=get_reg_names(r)
    v=better_tonumber(v)
    if not r then return end
    if not v then return end
    return true,bitpack({5,3,1,15},id,r,(sign=="-") and 1 or 0,v)
  end,". r '^%-$|'^%+$? n"},--load constant
  {"plt",function(b1,b2)--pset
    local _,r1,r2,or3,_,literal=bitsplit(b1,b2,{5,3,3,3,1,1})
    local r1,r2,r3=get_regs(r1,r2,or3)
    pset(r1(),r2(),literal==1 and or3 or r3())
  end,function(id,line)
    local tokens=tokenize(line)
    local _,r1,r2,or3=unpack(tokens)
    local r1,r2,r3=get_reg_names(r1,r2,or3)
    --print(better_tonumber(or3) and "is number" or "not number")
    if not (r1 and r2) then return false end
    if not r3 and not better_tonumber(or3) then return false end
    if better_tonumber(or3) then
      return true,bitpack({5,3,3,3,1,1},id,r1,r2,better_tonumber(or3),0,1)
    else
      return true,bitpack({5,3,3,3,1,1},id,r1,r2,r3,0,0)
    end
  end,". r r r|n"},
  --reset, line, rect, filled rect
  {{"rst","lne","rct","frc"},function(b1,b2)
    local _,r1,r2,op,r3=bitsplit(b1,b2,{5,3,3,2,3})
    local r1,r2,r3=get_regs(r1,r2,r3)
    local lx=memsigned[mem_map.last_draw_x]
    local ly=memsigned[mem_map.last_draw_y]
    --print(lx,ly,r1(),r2())
    local nx,ny=r1(),r2()
    local w=math.abs(lx-nx)+1
    local h=math.abs(ly-ny)+1
    local col=r3()
    --print("col:",col)
    --print("op:",op)
    if op==0 then
      s.cpubudget=s.cpubudget-w*h/64
      line(lx,ly,nx,ny,col)
    elseif op==1  then
      s.cpubudget=s.cpubudget-(w+h)
      --rect(3,8,6,16,2)
      rect(lx,ly,nx,ny,col)
    elseif op==2  then
      s.cpubudget=s.cpubudget-w*h/16
      rectfill(lx,ly,nx,ny,col)
    end
    memsigned[mem_map.last_draw_x]=nx
    memsigned[mem_map.last_draw_y]=ny
  end,function(id,line)
    local ops={lne=0,rct=1,frc=2,rst=3}
    --lne x y 2
    local tokens=tokenize(line)
    local opname,r1,r2,r3=unpack(tokens)
    local r1,r2,r3=get_reg_names(r1,r2,r3)
    if not ops[opname] then return false end
    if not(r1 and r2 and r3) then return false end
    return true,bitpack({5,3,3,2,3},id,r1,r2,ops[opname],r3)
  end,". r r r"},
  {{"crc","fcc"},function(b1,b2)
    local b3=mem[s.pc+2]
    s.pc=s.pc+1
    --print(b1,b2,b3)
    local _,x,y,r,_=bitsplit(b1,b2,{5,3,3,3,2})
    local _,col,filled,reg_col,_=bitsplit(b2,b3,{6,3,1,1,5})
    --print(col,filled,reg_col)
    local x,y,r,c=get_regs(x,y,r,reg_col==1 and col)
    c=c and c() or col
    local args={x(),y(),r(),c}
    if filled==1 then
      s.cpubudget=s.cpubudget+r()*r()*2+20
      circfill(unpack(args))
    else
      s.cpubudget=s.cpubudget+r()*r()/8+10
      circ(unpack(args))
    end
  end,function(id,line)
    local tokens=tokenize(line)
    local op,x,y,r,col=unpack(tokens)
    local x,y,r,c=get_reg_names(x,y,r,col)
    if not(x and y and r and (c or better_tonumber(col))) then return false end
    --xxxxx xxx|xxx xxx xx|x x x .....
    --print("filled?:",op=="fcc" and 1 or 0)
    --print("register?:",c and 1 or 0)
    local bytes=bitpack({5, 3,3,3,3, 1, 1, 5},id,
    x,y,r,c or better_tonumber(col),
    op=="fcc" and 1 or 0,
    c and 1 or 0, 0)
    --for _,byte in ipairs(bytes) do print(basen(byte,2,8)) end
    return true,bytes
  end,". r r r r|n"},
  {"lob",function(b1,b2)
    local _,reg_mode,a_reg,reg_count,format,mode=bitsplit(b1,b2,{5,1,3,3,3,1})
    a_reg=get_regs(a_reg)
    local adr
    if reg_mode==1 then
      adr=a_reg()
    else
      s.pc=s.pc+2
      local b3,b4=mem[s.pc],mem[s.pc+1]
      adr=bit.bor(bit.lshift(b3,8),b4)
    end

    --print(adr)
    --print(format)
    --print(reg_count)
    --print(mode)

    local regs={}
    for l=0,reg_count/2 do
      local r1,r2=bitsplit(mem[s.pc+2],0,{4,4,8})
      table.insert(regs,r1)
      table.insert(regs,r2)
      s.pc=s.pc+1
    end
    --print(unpack(regs))
    local w=1
    if format==1 then
    elseif format==2 then
    else w=8 end

    for l=1,reg_count+1 do
      s.registers[regs[l]+1]=s.mem_reg(adr,format,mode)
      adr=adr+w
    end

  end,function(id,line)
    local tokens=tokenize(line)

    table.remove(tokens,1)
    local address=table.remove(tokens,1)
    local format =table.remove(tokens,1)

    local modes={
      ["reg"]=0,
      ["stk"]=1
    }

    local mode=0
    if modes[tokens[1]] then
      mode=modes[table.remove(tokens,1)]
    end

    local formats={
      ["n"]=0,
      ["u8"]=1,
      ["s8"]=2,
    }

    if not formats[format] then return false end

    local registers={}
    for l,register in pairs(tokens) do
      table.insert(registers,get_reg_names(register))
    end
    --print(unpack(registers))
    --print(address)
    --print(id)
    if better_tonumber(address) then
      local p_num_registers=#registers
      if #registers%2==1 then table.insert(registers,0) end
      local elemcount=gentbl(4,#registers)
      local bytes=bitpack({5,1,3,3,3,1},id, 0,0,p_num_registers-1,formats[format],mode)
      for _,v in pairs(bitpack({16},better_tonumber(address))) do table.insert(bytes,v) end
      for _,v in pairs(bitpack(elemcount,unpack(registers))) do table.insert(bytes,v) end
      --print("num bytes:",unpack(bytes))
      return true,bytes
    elseif get_reg_names(address) then
      
      local p_num_registers=#registers
      if #registers%2==1 then table.insert(registers,0) end
      local elemcount=gentbl(4,#registers)
      local bytes=bitpack({5,1,3,3,3,1},id, 1,get_reg_names(address),p_num_registers-1,formats[format],mode)
      for _,v in pairs(bitpack(elemcount,unpack(registers))) do table.insert(bytes,v) end
      --print("reg bytes:",unpack(bytes))
      return true,bytes
    end
  end,". n|r '^u8$|'^s8$|'^n$£not_a_format '^stk$|'^reg$? r r? r? r? r? r? r? r?"},
  {"spr",function(b1,b2)
    local _,r1,r2,r3,const_spr,extended_mode=bitsplit(b1,b2,{5,3,3,3,1,1})
    r1,r2,r3=get_regs(r1,r2,r3)
    local sp
    if const_spr==1 then
      sp=mem[s.pc+2]
      s.pc=s.pc+1
    else
      sp=r1()
    end
    local w,h=1,1
    local flipx,flipy=false,false
    if extended_mode==1 then
      local l_w,l_fx
      local l_h,l_fy
      _,l_w,w,l_fx,flipx=bitsplit(0,mem[s.pc+2],{8,1,3,1,3})
      s.pc=s.pc+1
      local w_r=get_regs(w)
      if l_w==0 and w_r then w=w_r() else w=w+1 end
      local flipx_r=get_regs(flipx)
      if l_fx==0 and flipx_r then flipx=flipx_r() end
      _,l_h,h,l_fy,flipy=bitsplit(0,mem[s.pc+2],{8,1,3,1,3})
      s.pc=s.pc+1
      --print(l_h,h,l_fy,flipy)
      local h_r=get_regs(h)
      if l_h==0 and h_r then h=h_r() else h=h+1 end
      local flipy_r=get_regs(flipy)
      if l_fy==0 and flipy_r then flipy=flipy_r() end
      flipx=flipx>0
      flipy=flipy>0
    end
    s.cpubudget=s.cpubudget-w*h*8-9
    sspr(sp,r2(),r3(),w,h,1,flipx,flipy)
  end,function(id,line)
    local tokens=tokenize(line)
    local _,or1,r2,r3,w,h,flipx,flipy=unpack(tokens)
    local r1,r2,r3=get_reg_names(or1,r2,r3)
    --print(r1,r2,r3)
    if not (r2 and r3) then return false end
    if not r1 and not better_tonumber(or1) then return false end
    if w and h then
      flipx=flipx or "false"
      flipy=flipy or "false"
      --extra param format:
      --1 treat w as literal
      --  111 r1 (w in sprite tiles)
      --1 treat flip as literal
      --  111 r2 (flip x)
      local flipx_r,flipy_r=get_reg_names(flipx,flipy)
      local w_r,h_r=get_reg_names(w,h)
      local bytes=bitpack({5,3,3,3,1,1, 1,3,1,3, 1,3,1,3},id, 0,r2,r3, better_tonumber(or1) and 1 or 0,1,
      w_r and 0 or 1,w_r or (better_tonumber(w) or 1)-1,flipx_r and 0 or 1,flipx_r or (flipx=="true" and 1 or 0),
      h_r and 0 or 1,h_r or (better_tonumber(h) or 1)-1,flipy_r and 0 or 1,flipy_r or (flipy=="true" and 1 or 0)
      )
      
      if better_tonumber(or1) then table.insert(bytes,3,bit.band(better_tonumber(or1),255)) end

      return true,bytes
    elseif better_tonumber(or1) then
      return true,bitpack({5,3,3,3,1,1,8},id, 0,r2,r3, 1,0,better_tonumber(or1))
    end
    return true,bitpack({5,3,3,3,1,1},id,r1,r2,r3,0,0)
  end,". r|n r r r|n? r|n? 'true|'false|r? 'true|'false|r?"},
  {"cls",function(b1,b2)
    s.cpubudget=s.cpubudget-100
    local _,r1,override_col,override=bitsplit(b1,b2,{5,3,2,1,5})
    cls(override==1 and override_col or s.registers[r1]())
  end,function(id,line)
    local tokens=tokenize(line)
    local _,v=unpack(tokens)
    if not v then return false end
    if reg_names[v] then return true,bitpack({5,3,8},id,reg_names[v],0) end
    if better_tonumber(v) then return true,bitpack({5,3,2,1,5},id,0,better_tonumber(v),1,0) end
    return false
  end,". r|n"},
  {{"jmp","cjp","fun","cfn"},function(b1,b2)
    local b3=mem[s.pc+2]
    s.pc=s.pc+1
    local op,cond,call,stack=bitsplit(b1,b2,{5,1,1,1,8})
    local jumpadr=bitsplit(b2,b3,{16})

    local t=get_regs(reg_names.t)
    local stk=get_regs(stack==1 and reg_names.stkb or reg_names.stka)
    if cond==0 or t()>0 then
      --print(basen(jumpadr,16))
      if call==1 then 
        local jb1,jb2=unpack(bitpack({16},s.pc))
        stk(jb1)
        stk(jb2)
      end
      s.pc=jumpadr-2
    end
  end,function(id,line,stage)
    --print("jmp",line,stage)
    local tokens=tokenize(line)
    local op,stk,label=unpack(tokens)
    if not(stk=="a" or stk=="b") then
      label,stk=stk,"b"
    end
    if stage==1 or stage==2 then
      return true,{0,0,0}
    end
    if not label then return false end
    label=label..":"
    if not s.labels[label] then return false end
    return true,bitpack({5,1,1,1,8+8},id,(op=="cjp" or op=="cfn") and 1 or 0,(op=="fun" or op=="cfn") and 1 or 0,stk=="b" and 1 or 0,s.labels[label])
  end,". '^[ab]$? l"},
  {"ret",function(b1,b2)
    local _,stack=bitsplit(b1,b2,{5,1,10})
    local stk=get_regs(stack==1 and reg_names.stkb or reg_names.stka)
    local jb1,jb2=stk(),stk()
    s.pc=bit.lshift(jb2,8)+jb1
  end,function(id,line)
    local tokens=tokenize(line)
    local op,stk=unpack(tokens)
    return true,bitpack({5,1,10},id,stk=="a" and 0 or 1,0)
  end,". 'a|'b?"},
  {"tst",function(b1,b2)
    s.cpubudget=s.cpubudget+0.5 --now this op only costs half a cycle!
    local _,ri1,ri2,l0,e0,g0=bitsplit(b1,b2,{5,3,3,1,1,1,2})
    local r1,r2=get_regs(ri1,ri2)
    local dif=r1()-r2()
    local test_reg=get_regs(reg_names.t)
    test_reg(0)
    if     dif <0 and l0==1 then test_reg(1)
    elseif dif==0 and e0==1 then test_reg(1)
    elseif dif >0 and g0==1 then test_reg(1) end
  end,function(id,line)
    local tokens=tokenize(line)
    local _,inv,r1,op,r2=unpack(tokens)
    local flip=false
    if inv=="not" or inv=="!" then flip=true else r1,op,r2=inv,r1,op end
    local ri1,ri2=get_reg_names(r1,r2)
    if not (ri1 and ri2) then return false end
    local op_table={
      ["><"]=0,
      [">"]=1,
      ["="]=2,
      ["=="]=2,
      [">="]=3,
      ["<"]=4,
      ["!="]=5,
      ["~="]=5,
      ["<>"]=5,
      ["<="]=6,
      ["<=>"]=7,
    }
    if not op_table[op] then return false end
    local mask=bit.bxor(op_table[op],flip and 7 or 0)
    return true,bitpack({5,3,3,3,2},id,ri1,ri2,mask,0)
  end,[[. '!|'not? r '><|'>|'=|'==|'>=|'<|'!=|'~=|'<>|'<=£not_valid r]]},
  {"deb",function(b1,b2)
      local _,reg_i=bitsplit(b1,b2,{5,3,8})
      local reg=get_regs(reg_i)
      local name=reg_names[reg_i+1]
      if type(name)=="table" then name=name[1] end
      print("debug:",name,reg())
  end,function(id,line)
    local tokens=tokenize(line)
    local _,reg=unpack(tokens)
    reg=get_reg_names(reg)
    if not reg then return false end
    return true,bitpack({5,3,8},id,reg,0)
  end,". r"},
  {{"mcpy","mset"},function(b1,b2)
    local function getnumber()
      local b1,b2=mem[s.pc+2],mem[s.pc+3]
      s.pc=s.pc+2
      return bitsplit(b1,b2,{16})
    end
    local _,cpy = bitsplit(b1,b2,{5,1,10})
    local b3=mem[s.pc+2]
    s.pc=s.pc+1
    
    if cpy==1 then
      local _,cpy,from_r,from, to_r,to = bitsplit(b1,b2,{5,1,1,3,1,3,2})
      local _,width_r,width = bitsplit(b2,b3,{6,1,3,6})
      if  from_r==1 then  from=get_regs( from)() else  from=getnumber() end
      if    to_r==1 then    to=get_regs(   to)() else    to=getnumber() end
      if width_r==1 then width=get_regs(width)() else width=getnumber() end

      memcpy(from,to,width)
      s.cpubudget=s.cpubudget-width/4
    else
      local _,cpy,to_r,to, value_r,value = bitsplit(b1,b2,{5,1,1,3,1,3,2})
      local _,width_r,width = bitsplit(b2,b3,{6,1,3,6})
      if    to_r==1 then    to=get_regs(   to)() else    to=getnumber() end
      if value_r==1 then value=get_regs(value)() else value=mem[s.pc+2] s.pc=s.pc+1 end
      if width_r==1 then width=get_regs(width)() else width=getnumber() end

      memset(to,width,value)
      s.cpubudget=s.cpubudget-width/8
    end
  end,function(id,line)
    --from, to, width
    local tokens=tokenize(line)
    if tokens[1]=="mcpy" then
      local op_name,from_t,to_t,width_t=unpack(tokens)
      local from_r,to_r,width_r=get_reg_names(from_t,to_t,width_t)
      if not (better_tonumber( from_t) or  from_r) then return end
      if not (better_tonumber(   to_t) or    to_r) then return end
      if not (better_tonumber(width_t) or width_r) then return end
      -- aaaaaaaaBBBBBBBBcccccccc
      -- -----=-===-===-===------
      local bytes=bitpack({5,1, 1,3, 1,3, 1,3, 6},id,1, from_r and 1 or 0,from_r or 0,to_r and 1 or 0,to_r or 0,width_r and 1 or 0,width_r or 0,0)
      if not from_r and better_tonumber(from_t) then
        local b1,b2=unpack(bitpack({16},better_tonumber(from_t)))
        table.insert(bytes,b1)
        table.insert(bytes,b2)
      end
      if not to_r and better_tonumber(to_t) then
        local b1,b2=unpack(bitpack({16},better_tonumber(to_t)))
        table.insert(bytes,b1)
        table.insert(bytes,b2)
      end
      if not width_r and better_tonumber(width_t) then
        local b1,b2=unpack(bitpack({16},better_tonumber(width_t)))
        table.insert(bytes,b1)
        table.insert(bytes,b2)
      end
      return true,bytes
    
    else
      local op_name,to_t,value_t,width_t=unpack(tokens)
      local to_r,value_r,width_r=get_reg_names(to_t,value_t,width_t)
      if not (better_tonumber(   to_t) or    to_r) then return end
      if not (better_tonumber(value_t) or value_r) then return end
      if not (better_tonumber(width_t) or width_r) then return end
      -- aaaaaaaaBBBBBBBBcccccccc
      -- -----=-===-===-===------
      local bytes=bitpack({5,1, 1,3, 1,3, 1,3, 6},id,0,to_r and 1 or 0,to_r or 0,value_r and 1 or 0,value_r or 0,width_r and 1 or 0,width_r or 0,0)
      if not to_r and better_tonumber(to_t) then
        local b1,b2=unpack(bitpack({16},better_tonumber(to_t)))
        table.insert(bytes,b1)
        table.insert(bytes,b2)
      end
      if not value_r and better_tonumber(value_t) then
        local b=better_tonumber(value_t)%256
        table.insert(bytes,b)
      end
      if not width_r and better_tonumber(width_t) then
        local b1,b2=unpack(bitpack({16},better_tonumber(width_t)))
        table.insert(bytes,b1)
        table.insert(bytes,b2)
      end
      return true,bytes
    end
  end,". r|n r|n r|n"},
  {{"stt","stat","get"},function(b1,b2)
    s.cpubudget=s.cpubudget-9
    local _,reg_mode,stat,t_reg=bitsplit(b1,b2,{5,1,7,3})
    t_reg=get_regs(t_reg)
    if stat_funcs[stat] then
      t_reg(stat_funcs[stat]())
    else
      t_reg(0)
    end
  end,function(id,line)
    local tokens=tokenize(line)
    local _,stat,reg = unpack(tokens)
    if not reg or not get_reg_names(reg) then return false end
    if not stat_names[stat] then return false end
    return true,bitpack({5,1,7,3},id,0,stat_names[stat],get_reg_names(reg))
  end,". . r"},
  {"flp",function()
    s.cpubudget=0
  end,function(id,line)
    return true,bitpack({5,11},id,0)
  end,"."},
  {{"pek","pok","pal","spal","tpal"},function(b1,b2)
    local _,peek,t_reg,reg_mode,a_reg,_=bitsplit(b1,b2,{5,1,3,1,3,3})
    t_reg,a_reg=get_regs(t_reg,a_reg)
    local adr
    if reg_mode==1 then
      adr=a_reg()
    else
      s.pc=s.pc+2
      local b3,b4=mem[s.pc],mem[s.pc+1]
      adr=bit.bor(bit.lshift(b3,8),b4)
    end
    if peek==1 then
      t_reg(mem[adr])
    else
      mem[adr]=t_reg()
    end
  end,function(id,line)
    --bit format: 
    --     |peek/poke|target register|register address|unused|     address
    --xxxxx|x        |xxx            |x xxx           |xxx   |xxxx xxxxxxxxxxxx
    local tokens=tokenize(line)
    local op,adr,reg_name=unpack(tokens)
    --print("adr:",adr)
    local adr_reg,reg=get_reg_names(adr,reg_name)
    local num_adr=better_tonumber(adr)
    local names={
      pal="draw_pal",
      spal="screen_pal",
      tpal="transparency_pal"
    }
    if names[op] then
      if not num_adr then return false end
      adr_reg=nil
      num_adr=num_adr%4+mem_map[names[op]]
      op="pok"
    end
    if adr_reg and reg then
      local bytes=bitpack({5,1,3,1,3, 3},id,op=="pek" and 1 or 0,reg,1,adr_reg,0)
      return true,bytes
    elseif num_adr and reg then
      local bytes=bitpack({5,1,3,1,3, 3},id,op=="pek" and 1 or 0,reg,0,0,0)
      table.insert(bytes,bit.band(bit.rshift(num_adr,8),0xff))
      table.insert(bytes,bit.band(num_adr,0xff))
      return true,bytes
    end
    return false,{0,0}
  end,". r|n r"}
}
assert(#ops<=31,"too many opcodes were defined by me! whoops, make sure to let me know.")
local ops={}
local op_parse={}
local op_names={}
op_errorcheck={}
for i,op in pairs(ops_definition) do
  ops[i]=op[2]
  op_parse[i]=op[3]
  local name=op[1]
  if type(name)=="string" then
    op_names[op[1]]=i
    op_errorcheck[op[1]]=op[4]
  else
    for _,v in pairs(name) do
      op_names[v]=i
      op_errorcheck[v]=op[4]
    end
  end
end



function debugbitsplit(b1,b2,splits)
  local rets={bitsplit(b1,b2,splits)}
  for i,ret in ipairs(rets) do rets[i]=basen(ret,2,splits[i]) end
  print(basen(bit.bor(bit.lshift(b1,8)+b2),2),"=",unpack(rets))
end

--[[
  debugbitsplit(
  love.math.random(0,255),
  love.math.random(0,255),
  {4,5,3,2,2}
  )
--]]


local function parsecommand(b1,b2)
  local i=bitsplit(b1,b2,{5,11})
  if ops[i] then
    local name=ops_definition[i][1]
    --print("parsed:",type(name)=="table" and name[1] or name)
    ops[i](b1,b2)
  end
  
end



function s.mem_reg(addr,numberformat,mode,clear)
  local addr=addr
  local tmem
      if numberformat==1 then tmem=mem
  elseif numberformat==2 then tmem=memsigned
  else                        tmem=memdouble addr=math.floor(addr/8)
  end

  if clear then tmem[addr]=0 end

  --mode zero is the default
  if mode==1 then--stack mode
    return function(w)
      if w then
        tmem[addr+tmem[addr]+1]=w 
        tmem[addr]=tmem[addr]+1
      else
        if tmem[addr]>0 then
          tmem[addr]=tmem[addr]-1
          return tmem[addr+tmem[addr]+1]
        else
          return 0
        end
      end
    end
  else
    return function(w)
      local pv=tmem[addr]
      if w then tmem[addr]=w end
      return pv
    end
  end
end

function s.init()
  if ffi then
    ffi.copy(temp_mem:getFFIPointer(),base_mem:getFFIPointer(),memsize)
  else
    for k,v in ipairs(base_mem) do
      temp_mem[k]=v
    end
  end
  mem=ffi.cast("uint8_t*", temp_mem:getFFIPointer())
  memsigned=ffi.cast("int8_t*", temp_mem:getFFIPointer())
  memdouble=ffi.cast("double*", temp_mem:getFFIPointer())
  s.cpubudget=0
  mem[mem_map.stack_pointer_a]=0
  mem[mem_map.stack_pointer_b]=0

  for l=0,3 do
    mem[mem_map.screen_pal+l]=l  --init screen pallete
    mem[mem_map.draw_pal+l]=l  --init draw pallete
    mem[mem_map.transparency_pal+l]=1  --init transparency pallete
  end
  mem[mem_map.transparency_pal]=0
  
  s.registers={
    s.mem_reg(mem_map.regs_start   ,0,0,true), -- a (gp)
    s.mem_reg(mem_map.regs_start+ 8,0,0,true), -- b (gp)
    s.mem_reg(mem_map.regs_start+16,0,0,true), -- c (gp)
    s.mem_reg(mem_map.regs_start+24,0,0,true), -- x (gp)
    s.mem_reg(mem_map.regs_start+32,0,0,true), -- y (gp)
    s.mem_reg(mem_map.regs_start+40,0,0,true), -- t (for conditions)
    s.mem_reg(mem_map.stack_pointer_a,1,1,true),
    s.mem_reg(mem_map.stack_pointer_b,1,1,true)
  }
  s.running=true
  s.pc=mem_map.code
  s.labels={}
end
s.init()

function s.update(dt)
  s.cpubudget=s.cpubudget+100000*dt
  if s.running then
    while s.cpubudget>0 do
      --manual pc advance override
      --print(basen(s.pc,16))
      --s.pc=tonumber(io.read(),16) or 0xb00

      parsecommand(mem[s.pc],mem[s.pc+1])
      s.cpubudget=s.cpubudget-1
      s.pc=s.pc+2
    end
    --rectfill(31,31,64,31+4*2,3)
    --sc_write(tostring(i)..(s.running and "" or "h").."\n",32,32,2)
    --sc_write(tostring(s.registers[1]()),nil,nil,nil)
  end
end

function s.keypressed(key)
  if key=="escape" then s.quit() end
  if key=="backspace" then s.quit() end
end

function s.writeinstruction(write_line,stage)
  local line=write_line.line
  line=line:gsub("[%a_]*:","")
  local op=line:gsub("^[%A]*(%a+).*","%1")
  --print(op)
  local valid,bytes=false,{}
  if op_parse[op_names[op]] then
    --print("parsing: ",op)
    valid,bytes=op_parse[op_names[op]](op_names[op],line,stage,write_line.line_num)
    bytes=bytes or {}
  end
  --print(line,valid,b1,b2)
  --print(line)
  --print("bytecount:",#bytes)
  if valid then
    for l=1,#bytes do
      mem[s.writei+l-1]=bytes[l]
    end
    s.writei=s.writei+#bytes
    --debugbitsplit(b1,b2,{5,3,1,7})
  else
  end
end

function isvalid(chk_line,stage,linenumber)
  local line=chk_line:gsub("[%a_]*:","")
  if not chk_line:find("%S") then return false end
  local op=line:gsub("^[%A]*(%a+).*","%1")
  local valid,bytes=false,{}
  if op_parse[op_names[op]] then
    valid,bytes=op_parse[op_names[op]](op_names[op],line,stage,linenumber)
  end
  return valid
end

function s.writeinstructions(code)
  memset(mem_map.code,mem_map.code_length,0)
  s.writei=mem_map.code
  local strippedcode={}
  --1: go through, only put in instructions which are valid.
  for l=1,#code do
    if isvalid(code[l],1,l) then
      table.insert(strippedcode,{line_num=l,line=code[l]})
    else
      print("invalid:",code[l])
    end
  end
  --2: work out where all the labels are, now that non-functional lines have been excised from the code.
  s.labels={}
  --print(#code,"->",#strippedcode)
  for l=1,#strippedcode do
    local label,occurences=strippedcode[l].line:gsub("[^%a_]*([%a_]*:).*","%1")
    
    --print("instruction "..l..":",basen(s.writei,16))
    if occurences>0 then
      s.labels[label]=s.writei
      --print("label "..label..":",basen(s.writei,16))
    end
    s.writeinstruction(strippedcode[l],2)
  end
  --3: write then all into memory.
  s.writei=mem_map.code
  for l=1,#strippedcode do
    s.writeinstruction(strippedcode[l],3)
  end
end


return s    