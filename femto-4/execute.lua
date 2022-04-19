local s={}


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
  for l=1,#splitsizes do
    v=bit.bor(bit.lshift(v,splitsizes[l]),bit.band(vals[l],pow2[splitsizes[l]]))
  end
  return bit.band(bit.rshift(v,8),255),bit.band(v,255)
end

local ops={
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
}

function tokenize(st)
  local tokens={}
  local k=1
  while k<=#st do
    local ch=st:sub(k,k)
    if st:find("%d",k)==k then
      local start=k
      k=st:find("%D",k+1) or #st+1
      table.insert(tokens,st:sub(start,k-1))

    elseif ch:find("[%a_]") then
      local start=k
      k=st:find("[^%a%d_]",k+1) or #st+1
      table.insert(tokens,st:sub(start,k-1))
    else
      for _,op in pairs(ops) do
        if st:find(op,k,true)==k then
          table.insert(tokens,op)
          k=k+#op-1
          break
        end
      end
    end
    k=k+1
  end
  return tokens
end




local function get_regs(reg,...)
  if reg then
    --print("register:",reg,reg and s.registers[(reg)%8+1] and "exists" or "not real")
    return s.registers[(reg)%8+1],get_regs(...)
  end
  return
end




local reg_names={
  "a","b","c",
  "x","y",
  "t",
  "rnd",
  "stk"
}


for k,v in ipairs(reg_names) do reg_names[v]=k-1 end
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
  {"stk_size",function() return mem[0x35f] end},
  {"stk_peek",function() if mem[0x35f]>0 then return mem[0x360+mem[0x35f]-1] else return 0 end end},
  {"last_x",function() return memsigned[0x350] end},
  {"last_y",function() return memsigned[0x351] end},
  {"print_x",function() return memsigned[0x344] end},
  {"print_y",function() return memsigned[0x345] end},
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
    return 0,0
  end},
  {{"add","sub"},function(b1,b2)--add
    local _,r1,r2,r3,negate_r2,absolute=bitsplit(b1,b2,{5,3,3,3,1,1})
    r1,r2,r3=get_regs(r1,r2,r3)
    local result=r1()+r2()*(negate_r2==1 and -1 or 1)
    --print(r1(),"+",r2(),"=",result)
    r3(result)
  end,function(id,line)
    local opname,r1,r2,r3=unpack(tokenize(line))
    r1,r2,r3=get_reg_names(r1,r2,r3)
    if not (r1 and r2 and r3) then return false end
    local b1,b2=bitpack({5,3,3,3,1,1},id,r1,r2,r3,opname=="sub" and 1 or 0,0)
    return true,b1,b2
  end},
  {"adc",function(b1,b2)--add constant
    local _,t1,negative,value=bitsplit(b1,b2,{5,3,1,7})
    local r1=get_regs(t1)
    local result=r1()+value*(negative==1 and -1 or 1)
    --print("r"..t1,"("..r1()..")",negative==1 and "-" or "+",value,"=",result)
    r1(result)
  end,function(id,line)
    local _,r1,sign,value=unpack(tokenize(line))
    --print('"'..(tonumber(value) or "?")..'"')
    if not (sign=="-" or sign=="+") then print"no sign" return false end
    if not reg_names[r1] then print"no reg" return false end
    if not tonumber(value) then print"not a number" return false end
    local b1,b2=bitpack({5,3,1,7},id,reg_names[r1],sign=="-" and 1 or 0,tonumber(value))
    return true,b1,b2
  end},
  {"plt",function(b1,b2)--pset
    local _,r1,r2,or3,_,literal=bitsplit(b1,b2,{5,3,3,3,1,1})
    local r1,r2,r3=get_regs(r1,r2,or3)
    pset(r1(),r2(),literal and or3 or r3())
  end,function(id,line)
    local _,r1,r2,or3=unpack(tokenize(line))
    local r1,r2,r3=get_reg_names(r1,r2,or3)
    print(tonumber(or3) and "is number" or "not number")
    if not (r1 and r2) then return false end
    if not r3 and not tonumber(or3) then return false end
    if tonumber(or3) then
      return true,bitpack({5,3,3,3,1,1},id,r1,r2,tonumber(or3),0,1)
    else
      return true,bitpack({5,3,3,3,1,1},id,r1,r2,r3,0,0)
    end
  end},
  --line, rect, filled rect
  {{"lne","rct","frc"},function(b1,b2)
    local _,r1,r2,op,reset,col=bitsplit(b1,b2,{5,3,3,2,1,2})
    local r1,r2=get_regs(r1,r2)
    local lx=memsigned[0x350]
    local ly=memsigned[0x351]
    --print(lx,ly,r1(),r2())
    local w=math.abs(lx-r1())+1
    local h=math.abs(ly-r2())+1
    if reset==0 then
      if op==0 then
        s.cpubudget=s.cpubudget-w*h/64
        line(lx,ly,r1(),r2(),col)
      elseif op==1  then
        s.cpubudget=s.cpubudget-(w+h)
        rect(lx,ly,r1(),r2(),col)
      elseif op==2  then
        s.cpubudget=s.cpubudget-w*h/16
        rectfill(lx,ly,r1(),r2(),col)
      end
    end
    memsigned[0x350]=r1()
    memsigned[0x351]=r2()
  end,function(id,line)
    --lne x y 2 first
    local opname,r1,r2,colour,first=unpack(tokenize(line))
    local r1,r2=get_reg_names(r1,r2)
    if not(r1 and r2) then return false end
    if not tonumber(colour) then return false end
    return true,bitpack({5,3,3,2,1,2},id,r1,r2,({lne=0,rct=1,frc=2})[opname],(first=="reset" or first=="start") and 1 or 0,tonumber(colour))
  end},
  {"cls",function(b1,b2)
    s.cpubudget=s.cpubudget-100
    local _,r1,override_col,override=bitsplit(b1,b2,{5,3,2,1,5})
    cls(override and override_col or regs[r1]())
  end,function(id,line)
    local _,v=tokenize(line)
    if not v then return false end
    if reg_names[v] then return true,bitpack({5,3,8},id,reg_names[v],0) end
    if tonumber(v)  then return true,bitpack({5,3,2,1,5},id,0,tonumber(v),1,0) end
    return false
  end},
  {{"jmp","cjp"},function(b1,b2)
    s.cpubudget=s.cpubudget+0.5 --now this op only costs half a cycle!
    local op,cond,callstack,jumpadr=bitsplit(b1,b2,{5,1,1,9})
    local t=get_regs(reg_names.t)
    if cond==0 or t()>0 then
      s.pc=0xb00+jumpadr*2-2
    end
  end,function(id,line,stage)
    print("jmp",line,stage)
    local op,label=unpack(tokenize(line))
    if stage==1 then
      return true,0,0
    end
    if not label then return false end
    label=label..":"
    if not s.labels[label] then return false end
    return true,bitpack({5,1,1,9},id,op=="cjp" and 1 or 0,0,s.labels[label])
  end},
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
    local _,inv,r1,op,r2=unpack(tokenize(line))
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
  end},
  {"deb",function(b1,b2)
      local _,reg_i=bitsplit(b1,b2,{5,3,8})
      local reg=get_regs(reg_i)
      print("debug:",reg_names[reg_i+1],reg())
  end,function(id,line)
    local _,reg=unpack(tokenize(line))
    reg=get_reg_names(reg)
    if not reg then return false end
    return true,bitpack({5,3,8},id,reg,0)
  end},
  {{"stt","stat","get"},function(b1,b2)
    s.cpubudget=s.cpubudget-9
    local _,reg_mode,stat,t_reg=bitsplit(b1,b2,{5,1,7,3})
    t_reg=get_regs(t_reg)
    t_reg(stat_funcs[stat]())
  end,function(id,line)
    local _,stat,reg = unpack(tokenize(line))
    if not reg or not get_reg_names(reg) then return false end
    if not stat_names[stat] then return false end
    return true,bitpack({5,1,7,3},id,0,stat_names[stat],get_reg_names(reg))
  end},
  {"flp",function()
    s.cpubudget=0
  end,function(id,line)
    return true,bitpack({5,11},id,0)
  end
  }
}
local ops={}
local op_parse={}
local op_names={}
for i,op in pairs(ops_definition) do
  ops[i]=op[2]
  op_parse[i]=op[3]
  local name=op[1]
  if type(name)=="string" then
    op_names[op[1]]=i
  else
    for _,v in pairs(name) do
      op_names[v]=i
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
    ops[i](b1,b2)
  end
  
end


local function reg(initv,fn)
  local v=initv
  local fn=fn
  if fn then
    local loaded_fn,err=loadstring(fn)
    if not loaded_fn then
      print("error loading register:",err)
    else
      fn=loaded_fn()
    end
    
  end
  fn=fn or function(w)
    local pv=v
    if w then v=w end
    return pv
  end
  return fn
end

function s.init()
  s.cpubudget=0
  
  s.registers={
    reg(0),reg(0),reg(0), -- a-c (gp)
    reg(0),reg(0), -- x-y (gp)
    reg(0), --t (for conditions)
    reg(0,[=[return function(w)
      s.cpubudget=s.cpubudget-1
      return math.random(0,255)      
    end]=]), --rnd
    reg(0,[=[return function(w)
      if w then
        mem[0x360+mem[0x35f]]=w 
        mem[0x35f]=mem[0x35f]+1
      else
        if mem[0x35f]>0 then
          mem[0x35f]=mem[0x35f]-1
          return mem[0x360+mem[0x35f]]
        else
          return 0
        end
      end
    end]=])--stack
  }
  s.running=true
  s.pc=0xb00
  s.labels={}
end
s.init()

function s.update(dt)
  s.cpubudget=s.cpubudget+100000*dt
  if s.running then
    while s.cpubudget>0 do
      i=(s.pc-0xb00)/2
      --print("pc:",i)
      parsecommand(mem[s.pc],mem[s.pc+1])
      s.cpubudget=s.cpubudget-1
      s.pc=s.pc+2
    end
    rectfill(31,31,64,31+4*2,3)
    sc_write(tostring(i)..(s.running and "" or "h").."\n",32,32,2)
    sc_write(tostring(s.registers[1]()),nil,nil,nil)
  end
end

function s.keypressed(key)
  if key=="backspace" then currentscene=codestate end
end

function s.writeinstruction(line)
  line=line:gsub("[%a_]*:","")
  local op=line:gsub("^[%A]*(%a+).*","%1")
  --print(op)
  local valid,b1,b2=false,0,0
  if op_parse[op_names[op]] then
    --print("parsing: ",op)
    valid,b1,b2=op_parse[op_names[op]](op_names[op],line)
  end
  --print(line,valid,b1,b2)
  if valid then
    mem[s.writei  ]=b1
    mem[s.writei+1]=b2
    --debugbitsplit(b1,b2,{5,3,1,7})
    s.writei=s.writei+2
  else
  end
end

function isvalid(chk_line,stage)
  local line=chk_line:gsub("[%a_]*:","")
  if not chk_line:find("%S") then return false end
  local op=line:gsub("^[%A]*(%a+).*","%1")
  local valid,b1,b2=false,0,0
  if op_parse[op_names[op]] then
    valid,b1,b2=op_parse[op_names[op]](op_names[op],line,stage)
  end
  return valid
end

function s.writeinstructions(code)
  local strippedcode={}
  --1: go through, only put in instructions which are valid.
  for l=1,#code do
    if isvalid(code[l],1) then
      table.insert(strippedcode,code[l])
    else
      print("invalid:",code[l])
    end
  end
  --2: work out where all the labels are, now that non-functional lines have been excised from the code.
  s.labels={}
  --print(#code,"->",#strippedcode)
  for l=1,#strippedcode do
    local label=strippedcode[l]:gsub("([%a_]*:).*","%1")
    if #label>0 then
      s.labels[label]=l-1 
    end
  end
  --3: write then all into memory.
  for l=1,#strippedcode do
    s.writeinstruction(strippedcode[l])
  end
end


return s    