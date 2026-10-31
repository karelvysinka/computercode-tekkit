-- Compatibility helpers for ComputerCraft 1.89.2 / Cobalt Lua 5.1.
local M = {}
function M.toBlit(color)
    for i = 0, 15 do
        if color == 2^i then return ('0123456789abcdef'):sub(i+1, i+1) end
    end
    error('Invalid colour: '..tostring(color), 2)
end
function M.compile(source, name, env)
    if _VERSION == 'Lua 5.1' and loadstring and setfenv then
        local fn, err = loadstring(source, name)
        if fn and env then setfenv(fn, env) end
        return fn, err
    end
    return load(source, name, 't', env or _G)
end
function M.apply()
    if not colors.toBlit then colors.toBlit = M.toBlit end
    if colours and not colours.toBlit then colours.toBlit = M.toBlit end
    table.pack = table.pack or function(...) return { n=select('#', ...), ... } end
    table.unpack = table.unpack or unpack
end
return M
