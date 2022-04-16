ffi=require'ffi'


function love.load()
  base_mem = love.data.newByteData(2 ^ 8)
  mem=ffi.cast("uint8_t*", base_mem:getFFIPointer())
  for l=0,255 do
    --mem[l]=math.random(0,512)
  end
  for l=0,255 do
    print(mem[l])
  end

end