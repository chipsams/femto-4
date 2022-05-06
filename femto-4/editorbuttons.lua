local s={}
local st="hi"

s.buttons={
  {"s",confstate},
  {"c",codestate},
  {"d",drawstate},
  {"r",execstate},
}


function s.draw()
  for l,button in pairs(s.buttons) do
    sc_write(button[1],(mem[mem_map.hirez]==1 and 127 or 63)-3-#s.buttons*5+l*5,1,button[2]==currentscene and (mem[mem_map.hirez]==1 and (t%1>0.5 and 3 or 0 ) or 3) or 0)
  end
end

function s.mousedown()
  local bx,by=convertpos(mouse.x,mouse.y,(mem[mem_map.hirez]==1 and 127 or 63)-4-#s.buttons*5,0,5,5)
  if s.buttons[bx] and by==0 then
    if s.buttons[bx][2]==execstate then
      loadcode()
    else
      lasteditorstate=s.buttons[bx][2]
      currentscene=s.buttons[bx][2]
    end
  end
end

return s