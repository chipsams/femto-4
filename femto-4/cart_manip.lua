
local s={}

function s.tostring()
  local txt=""
    txt=txt.."hi! this is a ◕ FEMTO-4 cart, check it (and its documentation) out here:\nhttps://github.com/chipsams/femto-4 \n__code__\n"
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
    if #codestate.code==0 then
      codestate.code={""}
      table.insert(codestate.errors,{})
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

function encode_lobits(v,i)
  return (bit.band(v*255,252)+i)/255
end

function decode_lobits(v)
  return bit.band(v*255,3)
end

base_img=love.image.newImageData("assets/cassette_blank.png")
function s.saveimg(filename)
  local img=base_img:clone()
  local width=img:getWidth()
  local v1,v2,v3,v4=0,0,0,0
  local writepos=0
  local function write(n)
    n=bit.band(n,255)
    v1=bit.band(           n   ,3)
    v2=bit.band(bit.rshift(n,2),3)
    v3=bit.band(bit.rshift(n,4),3)
    v4=bit.band(bit.rshift(n,6),3)
    local x,y=writepos%width,math.floor(writepos/width)
    local r,g,b,a=img:getPixel(x,y)
    img:setPixel(x,y,encode_lobits(r,v1),encode_lobits(g,v2),encode_lobits(b,v3),encode_lobits(a,v4))
    writepos=writepos+1
  end
  local st=s.tostring()
  st=love.data.compress("string","zlib",st)
  write(bit.rshift(#st,8))
  write(#st)
  for l=1,#st do
    local n=st:sub(l,l):byte()
    write(n)
  end
  img:encode("png",filename)
end

function s.decode_pix(r,g,b,a)
  local v1=decode_lobits(r)
  local v2=decode_lobits(g)
  local v3=decode_lobits(b)
  local v4=decode_lobits(a)
  return     v1+
  bit.lshift(v2,2)+
  bit.lshift(v3,4)+
  bit.lshift(v4,6)
end

function s.openfile(file,source)
  if file:getFilename():match(".*%.f4%.png$") then
    if source=="dropped" then
      term_print("loaded dropped file")
    else
      term_print("loaded "..file:getFilename())
    end
    local st={}
    local img=love.image.newImageData(file)
    local len=bit.lshift(s.decode_pix(img:getPixel(0,0)),8)+
    s.decode_pix(img:getPixel(1,0))
    print(len)
    img:mapPixel(function(x,y,...)
      local v=s.decode_pix(...)
      if (x>1 or y>0) and len>0 then
        st[#st+1]=string.char(v)
        len=len-1
      end
      return ...
    end)
    s.fromstring(love.data.decompress("string","zlib",table.concat(st,"")))
    print("End of file")
  elseif file:getFilename():match(".*%.f4$") then
    if source=="dropped" then
      term_print("loaded dropped file")
    else
      term_print("loaded "..file:getFilename())
    end
    file:open("r")
    s.fromstring(file:read())
    file:close()
  end
end

function love.filedropped(file)
  s.openfile(file,"dropped")
end

return s