local s={}

local bytes={}

function s.draw()
  for y=0,47 do
    memset(screenpos+y*16,16,bit.rol(0x1010101,math.floor(t*8)*2))
  end
end

return s