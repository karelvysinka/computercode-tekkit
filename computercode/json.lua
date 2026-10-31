-- Strict JSON encoder: avoids the options-table overload introduced in CC 1.106.
-- Preserves UTF-8 received from APIs. Invalid high bytes use U+00XX escapes.
local M = {}
local function quote(s)
    local out, i = {'"'}, 1
    local escapes = { [8]='\\b', [9]='\\t', [10]='\\n', [12]='\\f', [13]='\\r', [34]='\\"', [92]='\\\\' }
    while i <= #s do
        local b = s:byte(i)
        if escapes[b] then out[#out+1]=escapes[b]; i=i+1
        elseif b < 32 then out[#out+1]=string.format('\\u%04x', b); i=i+1
        elseif b < 128 then out[#out+1]=s:sub(i,i); i=i+1
        else
            local n = b>=194 and b<=223 and 2 or b>=224 and b<=239 and 3 or b>=240 and b<=244 and 4 or 0
            local valid = n>0 and i+n-1<=#s
            for j=1,n-1 do local c=s:byte(i+j); if not c or c<128 or c>191 then valid=false end end
            local b2=s:byte(i+1) or 0
            if (b==224 and b2<160) or (b==237 and b2>159) or (b==240 and b2<144) or (b==244 and b2>143) then valid=false end
            if valid then out[#out+1]=s:sub(i,i+n-1); i=i+n
            else out[#out+1]=string.format('\\u%04x',b); i=i+1 end
        end
    end
    out[#out+1]='"'; return table.concat(out)
end
function M.encode(value)
    local active={}
    local function encode(v)
        if textutils.json_null and v==textutils.json_null then return 'null' end
        if textutils.empty_json_array and v==textutils.empty_json_array then return '[]' end
        local t=type(v)
        if t=='nil' then return 'null'
        elseif t=='boolean' then return v and 'true' or 'false'
        elseif t=='number' then
            assert(v==v and v~=math.huge and v~=-math.huge,'Non-finite JSON number')
            return string.format('%.17g',v)
        elseif t=='string' then return quote(v)
        elseif t~='table' then error('Cannot encode '..t) end
        assert(not active[v],'Recursive JSON table'); active[v]=true
        local count,max,array=0,0,true
        for k in pairs(v) do
            count=count+1
            if type(k)~='number' or k<1 or k%1~=0 then array=false else max=math.max(max,k) end
        end
        array=array and count>0 and max==count
        local out={}
        if array then for i=1,count do out[i]=encode(v[i]) end
        else
            local keys={}; for k in pairs(v) do assert(type(k)=='string','JSON object key must be string'); keys[#keys+1]=k end
            table.sort(keys)
            for _,k in ipairs(keys) do out[#out+1]=quote(k)..':'..encode(v[k]) end
        end
        active[v]=nil
        return (array and '[' or '{')..table.concat(out,',')..(array and ']' or '}')
    end
    return encode(value)
end
function M.decode(s)
    -- parse_null exists since 1.87; do not pass parse_empty_array (1.100.6).
    return textutils.unserializeJSON(s, {parse_null=true})
end
return M
