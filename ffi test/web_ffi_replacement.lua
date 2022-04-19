
if ffi then
  base_mem = love.data.newByteData(2 ^ 12)
  --these point to the same data, but one sets/gets in the range 0 to 255 and the other sets/gets in the range -128 to 127.
  mem=ffi.cast("uint8_t*", base_mem:getFFIPointer())
  memsigned=ffi.cast("int8_t*", base_mem:getFFIPointer())
else
  base_mem={}
  for l=1,2^12 do base_mem[l]=0 end
  mem={} setmetatable(mem,{
    __index=function(_,i) return base_mem[i] end,
    __newindex=function(_,i,v) base_mem[i]=math.floor(v)%256 end
  })
  signed_mem={} setmetatable(signed_mem,{
    __index=function(_,i) local v=base_mem[i] return v>127 and v-256 or v end,
    __newindex=function(_,i,v) v=math.floor(v)%256 end
  })
end