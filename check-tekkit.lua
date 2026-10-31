-- Local check, no HTTP requests and no access to the API key.
local root=fs.getDir(shell.getRunningProgram())
package.path=fs.combine(root,'?.lua')..';'..fs.combine(root,'?/init.lua')..';'..package.path
print('Host: '..tostring(_HOST))
print('Lua: '.._VERSION)
require('computercode.compat').apply()
local count=0
local function check(name,fn)
 local ok,err=pcall(fn)
 print((ok and 'OK ' or 'FAIL ')..name..(ok and '' or ': '..tostring(err)))
 if not ok then count=count+1 end
end
check('colour conversion',function() assert(colors.toBlit(32768)=='f') end)
check('Lua compiler',function() local f=assert(require('computercode.compat').compile('return x+1','=check',{x=41})); assert(f()==42) end)
check('strict JSON',function() local j=require('computercode.json'); assert(j.encode({a=1})=='{"a":1}');assert(j.decode('{"a":1}').a==1) end)
check('window buffer',function() local w=window.create(term.current(),1,1,10,2,false); assert(type(w.getLine)=='function'); w.write('test');assert(w.getLine(1):sub(1,4)=='test') end)
for _,name in ipairs({'shrekbox','pixelui','computercode.state','computercode.tools','computercode.session','computercode.agent','computercode.ui','computercode.monitor'}) do
 check(name,function() require(name) end)
end
print('HTTP: '..(http and 'enabled' or 'disabled'))
print('Failed: '..count)
