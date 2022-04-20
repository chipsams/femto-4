--this fi
local s={}

local bytes={}

function s.draw(t)
  cls(0)

  circ(32,24,16,1)
  for l=0,99 do
    circ(32,24,math.sin(t*math.pi*2)*8+8,2)
  end
end

return s