--this fi
local s={}

local bytes={}

function s.draw(t)
  cls(0)
  circfill(32,24,math.sin(t)*8+8,2)
end

return s