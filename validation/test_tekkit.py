from pathlib import Path
from lupa.lua51 import LuaRuntime
import json
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime(unpack_returned_tuples=True)
compile_lua=lua.eval('function(s,n) local f,e=loadstring(s,n); return f~=nil,e end')
files=list(root.rglob('*.lua'))
for p in files:
 ok,err=compile_lua(p.read_text(),str(p)); assert ok,(p,err)
print('Lua 5.1 syntax:',len(files),'files OK')
lua.execute('package.path = '+json.dumps(str(root/'?.lua')+';'+str(root/'?/init.lua')+';')+'..package.path')
lua.execute('''
colors={}; colours=colors; textutils={empty_json_array={},json_null={}}
require('computercode.compat').apply()
assert(colors.toBlit(1)=='0' and colors.toBlit(32768)=='f')
assert(not pcall(colors.toBlit,3))
local c=require('computercode.compat')
local f=assert(c.compile('return x+1','=test',{x=41})); assert(f()==42)
assert(not c.compile('local =','=bad',{}))
assert(table.pack(1,nil,3).n==3)
''')
encode=lua.eval("require('computercode.json').encode")
for expr,expected in [('{}',{}),('textutils.empty_json_array',[]),('textutils.json_null',None),('{a=true,b={1,2},empty={}}',{'a':True,'b':[1,2],'empty':{}}),('{content="Příliš žluťoučký kůň 👋",quote="a\\\"b\\n"}',{'content':'Příliš žluťoučký kůň 👋','quote':'a"b\n'})]:
 assert json.loads(encode(lua.eval(expr)))==expected
lua.execute('local j=require("computercode.json"); local t={};t.self=t;assert(not pcall(j.encode,t));assert(not pcall(j.encode,0/0))')
print('Compatibility and strict JSON tests OK')
# Stub only external CC interfaces; exercise actual module load and UI creation.
lua.execute('''
for i,n in ipairs({'white','orange','magenta','lightBlue','yellow','lime','pink','gray','lightGray','cyan','purple','blue','brown','green','red','black'}) do colors[n]=2^(i-1) end
package.preload['cc.expect']=function() return {expect=function(i,v,...) for j=1,select('#',...) do if type(v)==select(j,...) then return v end end error('bad argument '..i) end} end
os.epoch=function() return 100000 end; os.pullEvent=function() return 'terminate' end
local t={}
function t.getSize() return 51,19 end
function t.getPaletteColor() return 0.5,0.5,0.5 end
function t.getTextColor() return 1 end
function t.getBackgroundColor() return 32768 end
function t.getCursorPos() return 1,1 end
function t.isColor() return true end
function t.current() return t end
for _,k in ipairs({'blit','write','setCursorPos','setCursorBlink','setBackgroundColor','setTextColor','clear','clearLine'}) do t[k]=function() end end
term=t;window={create=function() return t end};keys={}
fs={combine=function(a,b) return a..'/'..b end,exists=function() return false end,isDir=function() return false end}
peripheral={getNames=function() return {} end};os.getComputerID=function() return 1 end;os.getComputerLabel=function() end;os.version=function() return 'CraftOS 1.8' end
''')
for name in ['shrekbox','pixelui','computercode.state','computercode.docs','computercode.models','computercode.api','computercode.tools','computercode.session','computercode.agent','computercode.ui','computercode.monitor']:
 lua.eval('require')(name)
 print('Module load OK:',name)
# API: real JSON encoding, HTTP success and third-return error handles.
lua.execute('''
local status, raw, failure=200,'success',false
http={post=function(opts)
 assert(type(opts)=='table' and opts.headers.Authorization=='Bearer TEST')
 assert(opts.body:find('"model":"test/model"',1,true))
 local h={readAll=function() return raw end,getResponseCode=function() return status end,close=function() end}
 if failure then return nil,'HTTP error',h end
 return h
end}
textutils.unserializeJSON=function(s,opts)
 assert(opts.parse_null)
 if s=='success' then return {choices={{message={role='assistant',content='OK'}}}} end
 return nil,'invalid JSON'
end
parallel={waitForAny=function(fn) fn() end}
sleep=function() end
local api=require('computercode.api')
local opts={apiKey='TEST',model='test/model',messages={{role='user',content='Hi'}}}
assert(api.chat(opts).content=='OK')
status=401;raw='unauthorized';failure=true
local msg,err=api.chat(opts);assert(not msg and err:find('openrouter 401',1,true))
''')
print('API HTTP success and error-response handle OK')
