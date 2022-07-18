




local function create(name)
  local source=love.audio.newSource("waveforms/"..name..".wav","static")
  source:setLooping(true)
  source:setVolume(0)
  source:play()
  return source
end

local sources={
  create("sine"),
  create("square"),
  create("sawtooth"),
  create("noise")
}

function updatesound()
  for l,source in pairs(sources) do
    local adr=mem_map.sound_start+mem[mem_map.sound_pointer]*4+l-1
    source:setPitch( math.min(bit.band(mem[adr],15)/15+0.0001,1))
    source:setVolume(math.min(bit.band(bit.rshift(mem[adr],4),15)/15+0.0001,1))
  end
end