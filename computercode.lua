-- ComputerCode - Claude-Code-style chat agent for ComputerCraft.
-- Run from the shell: `computercode`
--
-- First run: prompts for an OpenRouter API key and model, saves to .computercode/config.json.
-- Subsequent runs: loads config and opens the chat window.
-- If a monitor is attached, the chat is mirrored to it in real time.

local CONFIG_DIR  = ".computercode"
local CONFIG_PATH = CONFIG_DIR .. "/config.json"

-- One-time courtesy: if an old .aigen/config.json from the previous name
-- exists, migrate it.
if not fs.exists(CONFIG_PATH) and fs.exists(".aigen/config.json") then
    fs.makeDir(CONFIG_DIR)
    fs.move(".aigen/config.json", CONFIG_PATH)
    if fs.isDir(".aigen") and #fs.list(".aigen") == 0 then fs.delete(".aigen") end
end

-- Make `computercode/*.lua` requireable no matter what shell.dir() is when
-- launched.  We anchor the package path to the directory that contains
-- computercode.lua itself.
do
    local invokedAs  = shell and shell.getRunningProgram and shell.getRunningProgram() or "computercode.lua"
    local scriptDir  = fs.getDir(invokedAs)
    if scriptDir == "" then scriptDir = "/" end
    if scriptDir:sub(1, 1) ~= "/" then scriptDir = "/" .. scriptDir end
    package.path = ("%s/?.lua;%s/?/init.lua;"):format(scriptDir, scriptDir) .. package.path
    _G.__computercode_root = scriptDir
end

require("computercode.compat").apply()
local json = require("computercode.json")

local stateModule = require("computercode.state")
local agentMod    = require("computercode.agent")
local uiMod       = require("computercode.ui")
local monitorMod  = require("computercode.monitor")
local models      = require("computercode.models")
local docs        = require("computercode.docs")
local sessionMod  = require("computercode.session")

-- Point the doc loader at this repo's docs/ directory so read_doc works
-- regardless of what shell.dir() is when computercode is launched.
if _G.__computercode_root then
    docs.setRoot(_G.__computercode_root)
end

-- ----------------------------------------------------------------------------
-- Config IO
-- ----------------------------------------------------------------------------

local function loadConfig()
    if not fs.exists(CONFIG_PATH) then return nil end
    local f = fs.open(CONFIG_PATH, "r")
    local raw = f.readAll(); f.close()
    return json.decode(raw)
end

local function saveConfig(cfg)
    if not fs.exists(CONFIG_DIR) then fs.makeDir(CONFIG_DIR) end
    local f = fs.open(CONFIG_PATH, "w")
    f.write(json.encode(cfg))
    f.close()
end

local function setupFlow()
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear(); term.setCursorPos(1, 1)
    print("ComputerCode first-run setup")
    print("---------------------")
    print("")
    write("OpenRouter API key (sk-or-...): ")
    local key = read("*")
    while not key or key == "" do
        write("required: ")
        key = read("*")
    end
    print("")
    print("Pick a model:")
    print("")
    for i, p in ipairs(models.presets) do
        term.setTextColor(colors.yellow); write(string.format("%2d.  ", i))
        term.setTextColor(colors.white);  write(p.label)
        term.setTextColor(colors.lightGray); print("  -  " .. p.note)
        term.setTextColor(colors.gray); print("     " .. p.id)
    end
    term.setTextColor(colors.white)
    print("")
    write("Number from above OR a custom 'vendor/name' [" .. models.DEFAULT .. "]: ")
    local pick = read()
    local model
    if not pick or pick == "" then
        model = models.DEFAULT
    else
        local id, err = models.resolve(pick)
        if not id then
            print("warning: " .. err .. ", using default")
            model = models.DEFAULT
        else
            model = id
        end
    end

    local cfg = { apiKey = key, model = model }
    saveConfig(cfg)
    print("")
    term.setTextColor(colors.lime); print("Saved to " .. CONFIG_PATH .. " (" .. model .. ")")
    term.setTextColor(colors.white)
    sleep(0.6)
    return cfg
end

-- ----------------------------------------------------------------------------
-- Main
-- ----------------------------------------------------------------------------

local function main(args)
    if args[1] == "--setup" or args[1] == "setup" then
        setupFlow()
        return
    end

    local cfg = loadConfig()
    if not cfg or not cfg.apiKey then
        cfg = setupFlow()
    end

    local state = stateModule.new()
    state.model = cfg.model

    -- Persistence: by default, pick up where the last session left off - even
    -- across a computer restart.  `computercode new` forces a fresh session.
    local resumed = nil
    local wantNew = args[1] == "new" or args[1] == "--new"
    if not wantNew then
        local latest = sessionMod.latestId()
        if latest then
            local ok, data = pcall(sessionMod.load, state, latest)
            if ok and data then resumed = data end
        end
    end
    if not state.sessionId then
        sessionMod.start(state)
    end

    local ui  -- forward declaration so /quit can stop it
    local agent = agentMod.new(state, {
        apiKey = cfg.apiKey,
        model  = cfg.model,
        onQuit = function() if ui then ui.stop() end end,
    })

    -- Autosave from here on: every new entry persists the session to
    -- .computercode/sessions/ so a reboot never loses context.
    sessionMod.attach(state)

    -- Attach monitor mirror BEFORE creating the UI so the monitor sees the
    -- initial empty state and any setup-time events.
    local mirror = monitorMod.attach(state, { textScale = 0.5 })

    ui = uiMod.new(state, agent)

    -- Friendly opening message in the transcript so it doesn't start blank.
    if resumed then
        state:pushEntry({
            kind = "assistant",
            text = "Resumed session: " .. (resumed.title or state.sessionId) ..
                   "  (" .. #state.transcript .. " entries).\n" ..
                   "/new = fresh chat   /sessions = list   /resume <n> = switch" ..
                   (mirror.active and ("\nMonitor mirror on " .. (mirror.side or "?") .. ".") or ""),
        })
    else
        state:pushEntry({
            kind = "assistant",
            text = "Hi! I'm ComputerCode. Tell me what to build and I'll write it. " ..
                   "I can run Lua directly, read/search files, check docs, write/edit files, and test scripts.\n" ..
                   "Enter sends - Ctrl+Enter for a newline.\n" ..
                   "Slash commands: /help  /new  /sessions  /resume  /clear  /model  /quit  /setup\n" ..
                   (mirror.active and ("Monitor mirror active on the " .. (mirror.side or "?") .. " side.") or ""),
        })
    end

    -- Session saves need free space (plus .tmp headroom); warn before the
    -- user finds out via a failing autosave mid-conversation.
    local free = fs.getFreeSpace("/")
    if free < 150 * 1024 then
        state:pushError(("low disk: only %d KB free - session saves need headroom. " ..
            "Free space (delete old files, /delete old sessions) or raise " ..
            "computer_space_limit in the CC:Tweaked server config."):format(math.floor(free / 1024)))
    end

    local ok, err = pcall(function() ui.run() end)

    -- Cleanup
    if mirror.active and mirror.monitor then
        mirror.monitor.setBackgroundColor(colors.black)
        mirror.monitor.clear()
    end
    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear(); term.setCursorPos(1, 1)
    print("ComputerCode exited.")
    if not ok then printError(err) end
end

main({ ... })
