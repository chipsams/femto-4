local s={}
local st="hi"

s.buttons={
  {"c",codestate},
  {"d",drawstate},
  {"r",execstate}
}


function s.draw()
  for l,button in pairs(s.buttons) do
    sc_write(button[1],60-#s.buttons*5+l*5,1,button[2]==currentscene and 3 or 0)
  end
end

function s.mousedown()
  local bx,by=convertpos(mouse.x,mouse.y,59-#s.buttons*5,0,5,5)
  if s.buttons[bx] and by==0 then
    if s.buttons[bx][2]==execstate then
      loadcode()
    else
      currentscene=s.buttons[bx][2]
    end
  end
end

return s