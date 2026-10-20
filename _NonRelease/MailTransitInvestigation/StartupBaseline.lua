local original = dofile
function dofile(path)
    if path == "YiboMail/Bootstrap.lua" then
        local pipe = assert(io.popen("git show b370c21:YiboMail/Bootstrap.lua"))
        local source = pipe:read("*a"); pipe:close()
        return assert(loadstring(source, "@HEAD/YiboMail/Bootstrap.lua"))()
    end
    return original(path)
end
dofile("YiboMail/_NonRelease/Tests/InboxReleaseSpec.lua")
