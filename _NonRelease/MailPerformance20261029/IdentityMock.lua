-- Thin fixtures implement both mutable and shared read-only identity contracts.
return function(characters)
    local getCached, cached = assert(characters.GetAllCached), nil
    local fields={"id","name","realm","class","faction","level","lastSeenAt","seenOrder"}
    local function Project(rows)
        local result={}
        for _,v in ipairs(rows) do
            local row={};for _,key in ipairs(fields) do row[key]=v[key] end
            result[#result+1]=row
        end
        return result
    end
    characters.GetAll=function(self,options)
        assert(options and options.identityOnly)
        return Project(getCached(self))
    end
    characters.GetAllCached=function(self,options)
        local rows=getCached(self)
        if not (options and options.identityOnly) then return rows end
        local valid=cached and #cached==#rows
        if valid then
            for i,v in ipairs(rows) do for _,key in ipairs(fields) do if cached[i][key]~=v[key] then valid=false end end end
        end
        if not valid then cached=Project(rows) end
        return cached
    end
end
