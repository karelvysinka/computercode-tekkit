-- ComputerCode Tekkit 1.89.2: download only from this fork, at one commit.
local REPOSITORY = "karelvysinka/computercode-tekkit"
local args={...}
local ref=args[1] or 'main'
if not ref:match('^[%w_.%-]+$') then error('Expected a branch, tag or commit SHA',0) end
if not http then error('HTTP API disabled',0) end
local function fetch(url)
 local h,err,errorHandle=http.get(url)
 if not h then
  if errorHandle then errorHandle.close() end
  return nil,tostring(err)
 end
 local code=h.getResponseCode and h.getResponseCode() or 200
 local data=h.readAll();h.close()
 if code~=200 then return nil,'HTTP '..code end
 return data
end
-- Resolve main once; every file below uses the same immutable commit SHA.
local commit=ref
if not (#ref==40 and ref:match('^%x+$')) then
 local raw,err=fetch('https://api.github.com/repos/'..REPOSITORY..'/commits/'..ref)
 if not raw then error('Cannot resolve version: '..tostring(err)..'. No files changed.',0) end
 local info=textutils.unserializeJSON(raw)
 commit=info and info.sha
end
if type(commit)~='string' or #commit~=40 or not commit:match('^%x+$') then error('Invalid commit SHA. No files changed.',0) end
local base='https://raw.githubusercontent.com/'..REPOSITORY..'/'..commit
print('Installing '..REPOSITORY)
print('Commit: '..commit)
local files={
 "computercode.lua",
 "pixelui.lua",
 "shrekbox.lua",
 "check-tekkit.lua",
 "computercode/agent.lua",
 "computercode/api.lua",
 "computercode/compat.lua",
 "computercode/docs.lua",
 "computercode/json.lua",
 "computercode/models.lua",
 "computercode/monitor.lua",
 "computercode/session.lua",
 "computercode/state.lua",
 "computercode/tools.lua",
 "computercode/ui.lua",
 "docs/colors.md",
 "docs/disk.md",
 "docs/fs.md",
 "docs/gps.md",
 "docs/http.md",
 "docs/index.md",
 "docs/keys.md",
 "docs/modem.md",
 "docs/monitor.md",
 "docs/multishell.md",
 "docs/os.md",
 "docs/paintutils.md",
 "docs/parallel.md",
 "docs/peripheral.md",
 "docs/pixelui-freedraw.md",
 "docs/pixelui-widgets.md",
 "docs/pixelui.md",
 "docs/rednet.md",
 "docs/redstone.md",
 "docs/settings.md",
 "docs/shell.md",
 "docs/speaker.md",
 "docs/term.md",
 "docs/textutils.md",
 "docs/turtle.md",
 "docs/vector.md",
 "docs/window.md",
 "install.lua",
 "install-tekkit.lua"
}
local failed=0
for _,path in ipairs(files) do
 local data,err=fetch(base..'/'..path)
 if data and path:match('%.lua$') then
  local compiler=loadstring or load
  local fn,syntax=compiler(data,'@'..path)
  if not fn then data=nil;err='Invalid Lua: '..tostring(syntax) end
 end
 if not data then
  print('FAIL '..path..': '..tostring(err));failed=failed+1
 else
  local parent=fs.getDir(path)
  if parent~='' and not fs.exists(parent) then fs.makeDir(parent) end
  local ok,why=pcall(function()
   local h,e=fs.open(path,'w');if not h then error(e or 'Cannot open file') end
   local written,werr=pcall(h.write,data);h.close();if not written then error(werr) end
  end)
  if not ok then print('FAIL '..path..': '..tostring(why));failed=failed+1
  else print('OK '..path) end
 end
end
if failed>0 then error(tostring(failed)..' files failed. Do not start the app. Rerun this installer with commit '..commit,0) end
local f=fs.open('.computercode-version','w');if f then f.write(commit);f.close() end
print('Installed. Run: check-tekkit, then computercode')
