
s={}

function s.tostring()
  local txt=""
    txt=txt.."hi\n__code__\n"
    txt=txt..table.concat(codestate.code,"\n"):gsub("\n(__[%l%d_]+__)","\n~%1")
    txt=txt.."\n__gfx__\n"
  local addlines={}
  local zerospan=0
  for l=mem_map.sprites,mem_map.sprites+16*48-1,16 do
    local addline={}
    local allzeros=true
    for k=0,15 do
      allzeros=mem[l+k]==0 and allzeros
      table.insert(addline,basen(mem[l+k],4,4):reverse())
    end
    if allzeros then
      zerospan=zerospan+1
    else
      if zerospan>0 then
        addlines[#addlines+1]=("/"):rep(zerospan)
        zerospan=0
      end
      addlines[#addlines+1]=table.concat(addline,"")
    end
  end
  if zerospan>0 then
    addlines[#addlines+1]=("/"):rep(zerospan)
  end
  txt=txt..table.concat(addlines,"\n")
  return txt
end

function s.fromstring(st)
  local blocks=parsecart(st)
  if blocks.code then
    codestate.code={}
    codestate.errors={}
    for row in blocks.code:gmatch("[^\n]+") do
      table.insert(codestate.code,row)
      table.insert(codestate.errors,{})
      codestate.errorcheck(#codestate.code)
    end
    codestate.selecting=false
    codestate.editing_line=#codestate.code
    codestate.editing_row=#codestate.code[#codestate.code]
  end
  if blocks.gfx then
    local writepos=mem_map.sprites
    for row in blocks.gfx:gmatch("[^\n]+") do
      if row:find("/") then
        memset(writepos,(#row-1)*16-1,0)
        writepos=writepos+(#row-1)*16
      else
        for l=1,#row-1,4 do
          mem[writepos]=tonumber(row:sub(l,l+3):reverse(),4)
          writepos=writepos+1
        end
      end
    end
  end
end

return s