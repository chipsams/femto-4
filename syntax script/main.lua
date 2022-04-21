
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
}

function tokenize(st)
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
      k=st:find("[^0123]",k+2)
      add_token(start)
    elseif st:find("0b[01]",k)==k then
      local start=k
      k=st:find("[^01]",k+2)
      add_token(start)
    elseif st:find("0x[%dabcdef]",k)==k then
      local start=k
      k=st:find("[^%dabcdef]",k+2)
      add_token(start)
    elseif st:find("%d",k)==k then
      local start=k
      k=st:find("%D",k+1) or #st+1
      add_token(start,k-1)
      
    elseif ch:find("[%a_]") then
      local start=k
      k=st:find("[^%a%d_]",k+1) or #st+1
      add_token(start,k-1)
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
  return tokens,token_areas
end
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

regs={a=1,b=1,c=1,x=1,y=1,rnd=1,stk=1}
labels={}

function match(token,pattern)
  for k,v in ipairs(pattern) do
    if v=="n" and better_tonumber(token) then return true,"number"
    elseif v=="r" and regs[token] then return true,"register"
    elseif v=="l" and labels[token] then return true,"label"
    elseif v:sub(1,1)=="'" and token:match(v:sub(2,-1)) then return true,"pattern"
    end
  end
  return false,pattern.err_message
end

function match_tokens(line,pattern)
  local tokens,token_ranges=tokenize(line)
  local errors={}
  local pattern_parts={}
  pattern:gsub("%S+",function(v)
    local pattern_part={}
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
    if #pattern_parts==0 then table.insert(errors,{token="",range={#line,#line},error="too many tokens!"}) return errors end
    local token=tokens[tok_i]
    local success,err=match(token,pattern_parts[1])
    if pattern_parts[1].optional and not success then
      table.remove(pattern_parts,1)
    else
      if not success then
        table.insert(errors,{token=token,range=token_ranges[tok_i],error=err})
      end
      table.remove(pattern_parts,1)
      tok_i=tok_i+1
    end
  end
  while #pattern_parts>0 do
    if pattern_parts[1].optional then table.remove(pattern_parts,1) else break end
  end
  if #pattern_parts>0 then table.insert(errors,{token="",range={#line,#line},error="not enough tokens!"}) return errors end
  return errors
end

local errors=match_tokens([[1 - 1]],"r|n '[+%-] n")
print(#errors)
for i,error in ipairs(errors) do
  print(error.error,error.token,error.range[1].."-"..error.range[2])
end

function love.keypressed(key)
  if key=="escape" then
    love.event.quit()
  end
end