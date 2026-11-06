return function(before, nativeTimers)
    local e=setmetatable({}, {__index=_G}); e._G=e
    e.clock,e.queue,e.created,e.executed=0,{},0,0
    e.WOW_PROJECT_MISTS_CLASSIC,e.WOW_PROJECT_ID=19,19
    e.GetTime=function() return e.clock end
    e.GetServerTime=function() return 1000+e.clock end
    e.SlashCmdList={}
    e.CreateFrame=function()
        local f={RegisterEvent=function() end,SetScript=function(self,k,v) self[k]=v end}
        e.frame=f; return f
    end
    local function Schedule(delay, fn)
        local timer={at=e.clock+delay,fn=fn,Cancel=function(self) self.cancelled=true end}
        e.queue[#e.queue+1]=timer; e.created=e.created+1; return timer
    end
    e.C_Timer={After=Schedule}
    if nativeTimers then e.C_Timer.NewTimer=Schedule end
    function e.advance(to)
        local n=0
        while true do
            table.sort(e.queue,function(a,b) return a.at<b.at end)
            if not e.queue[1] or e.queue[1].at>to+1e-9 then e.clock=to; return end
            local timer=table.remove(e.queue,1); e.clock=timer.at
            if not timer.cancelled then
                n=n+1; assert(n<1000,'unbounded callback chain')
                e.executed=e.executed+1; timer.fn()
            end
        end
    end
    function e.pending()
        local n=0; for _,v in ipairs(e.queue) do if not v.cancelled then n=n+1 end end; return n
    end
    function e.load(path,...)
        if before then
            local frozen='_NonRelease/OtherPluginsFix20261030/Before/'..path
            local f=io.open(frozen); if f then f:close(); path=frozen end
        end
        setfenv(assert(loadfile(path)),e)(...)
    end
    return e
end
