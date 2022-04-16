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
    --_print("register:",reg,reg and s.registers[(reg)%8+1] and "exists" or "not real")
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
    reg_names[k]=nil
  end
end
local function get_reg_names(reg,...)
  if reg then
    --_print("register:",reg,reg and s.registers[(reg)%8+1] and "exists" or "not real")
    return reg_names[reg],get_reg_names(...)
  end
  return
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
    s.running=false
  end,function()
    return 0,0
  end},
  [1]={{"add","sub"},function(b1,b2)--add
    local _,r1,r2,r3,negate_r2,absolute=bitsplit(b1,b2,{5,3,3,3,1,1})
    r1,r2,r3=get_regs(r1,r2,r3)
    local result=r1()+r2()*(negate_r2==1 and -1 or 1)
    _print(r1(),"+",r2(),"=",result)
    r3(result)
  end,function(id,line)
    local opname,r1,r2,r3=unpack(tokenize(line))
    r1,r2,r3=get_reg_names(r1,r2,r3)
    if not (r1 and r2 and r3) then return false end
    local b1,b2=bitpack({5,3,3,3,1,1},id,r1,r2,r3,opname=="sub" and 1 or 0,0)
    return true,b1,b2
  end},
  [2]={"adc",function(b1,b2)--increment
    local _,t1,negative,value=bitsplit(b1,b2,{5,3,1,7})
    local r1=get_regs(t1)
    local result=r1()+value*(negative==1 and -1 or 1)
    --_print("r"..t1,"("..r1()..")",negative==1 and "-" or "+",value,"=",result)
    r1(result)
  end,function(id,line)
    local _,r1,sign,value=unpack(tokenize(line))
    --_print('"'..(tonumber(value) or "?")..'"')
    if not (sign=="-" or sign=="+") then _print"no sign" return false end
    if not reg_names[r1] then _print"no reg" return false end
    if not tonumber(value) then _print"not a number" return false end
    local b1,b2=bitpack({5,3,1,7},id,reg_names[r1],sign=="-" and 1 or 0,tonumber(value))
    return true,b1,b2
  end},
  [3]={"plt",function(b1,b2)--pset
    local _,r1,r2,r3=bitsplit(b1,b2,{5,3,3,3,2})
    local r1,r2,r3=get_regs(r1,r2,r3)
    pset(r1(),r2(),r3())
  end,function(id,line)
    local _,r1,r2,r3=unpack(tokenize(line))
    r1,r2,r3=get_reg_names(r1,r2,r3)
    if not (r1 and r2 and r3) then return false end
    local b1,b2=bitpack({5,3,3,3,2},id,r1,r2,r3,0)
    return true,b1,b2
  end},
  [4]={{"jmp","cjp"},function(b1,b2)
    local op,cond,callstack,jumpadr=bitsplit(b1,b2,{5,1,1,9})
    local t=get_regs(reg_names.t)
    _print(cond,t())
    if cond==0 or t()>0 then
      s.pc=0xb00+jumpadr*2-2
    end
  end,function(id,line,stage)
    _print("jmp",line,stage)
    local op,label=unpack(tokenize(line))
    _print(label)
    if stage==1 then
      return true,0,0
    end
    if not label then return false end
    label=label..":"
    if not s.labels[label] then return false end
    return true,bitpack({5,1,1,9},id,op=="cjp" and 1 or 0,0,s.labels[label])
  end},
  [5]={"tst",function(b1,b2)
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
  end}
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
  _print(basen(bit.bor(bit.lshift(b1,8)+b2),2),"=",unpack(rets))
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
  fn=fn and load(fn,nil,nil,{v=v,math=math}) or function(w)
    local pv=v
    if w then v=w end
    return pv
  end
  return fn
end

function s.init()
  
  s.registers={
    reg(0),reg(0),reg(0), -- a-c (gp)
    reg(0),reg(0), -- x-y (gp)
    reg(0), --t (for conditions)
    reg(0,[[
      return math.random(0,255)      
    ]]), --r
    reg(0,[[function(w)
      
    end]])
  }
  s.running=true
  s.pc=0xb00
  s.labels={}
end
s.init()

function s.update()
  if s.running then
    i=(s.pc-0xb00)/2
    rectfill(31,31,64,31+4*2,3)
    --_print("pc:",i)
    print(tostring(i).."\n",32,32,2)
    print(tostring(s.registers[1]()))
    parsecommand(mem[s.pc],mem[s.pc+1])
    s.pc=s.pc+2
  end
end

function s.keypressed(key)
  if key=="backspace" then currentscene=codestate end
end

function s.writeinstruction(line)
  line=line:gsub("[%a_]*:","")
  local op=line:gsub("^[%A]*(%a+).*","%1")
  --_print(op)
  local valid,b1,b2=false,0,0
  if op_parse[op_names[op]] then
    --_print("parsing: ",op)
    valid,b1,b2=op_parse[op_names[op]](op_names[op],line)
  end
  --_print(line,valid,b1,b2)
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
     if isvalid(code[l],1) then table.insert(strippedcode,code[l]) end
  end
  --2: work out where all the labels are, now that non-functional lines have been excised from the code.
  s.labels={}
  --_print(#code,"->",#strippedcode)
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