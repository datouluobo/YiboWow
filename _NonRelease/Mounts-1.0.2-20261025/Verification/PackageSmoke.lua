local original = loadfile
loadfile = function(path)
 if path:find('/_NonRelease/Tests/', 1, true) then return original(path) end
 local suffix = path:sub(#arg[1] + 1)
 return original(arg[2] .. suffix)
end
dofile(arg[1] .. '/_NonRelease/Tests/RunLuaSmokeTests.lua')