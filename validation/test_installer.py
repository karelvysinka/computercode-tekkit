from pathlib import Path
from lupa.lua51 import LuaRuntime
root=Path(__file__).resolve().parents[1]
source=(root/'install.lua').read_text()
assert source==(root/'install-tekkit.lua').read_text()
assert 'REALEncryptal' not in source and 'pastebin' not in source
for mode in ['success','resolve-failure','file-failure','pinned']:
 lua=LuaRuntime(unpack_returned_tuples=True)
 lua.globals().MODE=mode
 lua.execute('''
 calls={}; writes={};sha=string.rep('a',40)
 print=function() end
 http={get=function(url)
  calls[#calls+1]=url
  if url:find('api.github.com',1,true) then
   if MODE=='resolve-failure' then return nil,'offline' end
   return {readAll=function() return 'commit-response' end,close=function() end,getResponseCode=function() return 200 end}
  end
  assert(url:find('https://raw.githubusercontent.com/karelvysinka/computercode-tekkit/'..sha..'/',1,true)==1)
  if MODE=='file-failure' and url:find('/pixelui.lua',1,true) then return nil,'404' end
  return {readAll=function() return '-- mocked valid file' end,close=function() end,getResponseCode=function() return 200 end}
 end}
 textutils={unserializeJSON=function(raw) assert(raw=='commit-response');return {sha=sha} end}
 fs={getDir=function(p) return p:match('^(.*)/') or '' end,exists=function() return true end,makeDir=function() end,
 open=function(p) return {write=function(s) writes[p]=s end,close=function() end} end}
 ''')
 fn=lua.eval('loadstring')(source)
 try:
  fn(*(['a'*40] if mode=='pinned' else []));ok=True
 except Exception:ok=False
 writes=lua.globals().writes
 if mode=='resolve-failure':assert not ok and len(list(writes.items()))==0
 elif mode=='file-failure':assert not ok and writes['pixelui.lua'] is None and writes['.computercode-version'] is None
 else:assert ok and writes['computercode.lua'] and writes['install.lua'] and writes['.computercode-version']=='a'*40
 if mode=='pinned':assert all('api.github.com' not in v for _,v in lua.globals().calls.items())
 print(mode,'OK')
print('Installer source policy and immutable downloads OK')
