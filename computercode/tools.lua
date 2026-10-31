local compat = require("computercode.compat")
compat.apply()
-- Tool registry: JSON schemas for OpenRouter + Lua handlers.

local docs = require("computercode.docs")

local M = {}

local MAX_FILE_BYTES = 16 * 1024
local MAX_RUN_OUTPUT_BYTES = 4 * 1024

local function isTurtle()
    return turtle ~= nil
end

local function isPocket()
    return pocket ~= nil
end

-- textutils.serializeJSON encodes an empty Lua table as {} (a JSON object),
-- so an empty result list reads as "matches":{} and models can misparse it.
-- This sentinel forces [] instead.
local function jsonArray(t)
    if next(t) == nil then return textutils.empty_json_array end
    return t
end

local function safePath(path)
    if type(path) ~= "string" or path == "" then return nil, "missing path" end
    -- Disallow leaving the disk root via .. tricks; fs.combine resolves them.
    local resolved = fs.combine("", path)
    if resolved == "" or resolved == "." then return nil, "empty path" end
    return resolved
end

-- ----------------------------------------------------------------------------
-- Handlers (return string or table; agent stringifies to JSON for the model).
-- ----------------------------------------------------------------------------

local handlers = {}

function handlers.list_peripherals(_args)
    local out = {}
    for _, name in ipairs(peripheral.getNames()) do
        local pType = peripheral.getType(name) or "unknown"
        local methods = peripheral.getMethods(name) or {}
        out[#out + 1] = { side = name, type = pType, methods = methods }
    end
    return jsonArray(out)
end

function handlers.get_computer_info(_args)
    local w, h = term.getSize()
    local info = {
        id = os.getComputerID(),
        label = os.getComputerLabel(),
        isTurtle = isTurtle(),
        isPocket = isPocket(),
        isAdvanced = term.isColor and term.isColor() or false,
        isColor = term.isColor and term.isColor() or false,
        termSize = { width = w, height = h },
        version = os.version and os.version() or nil,
        host = _HOST, luaVersion = _VERSION,
    }
    if isTurtle() then
        info.fuelLevel = turtle.getFuelLevel()
        info.fuelLimit = turtle.getFuelLimit()
    end
    return info
end

function handlers.list_docs(_args)
    return docs.indexText()
end

function handlers.read_doc(args)
    local content, err = docs.read(args and args.topic)
    if not content then return nil, err end
    return content
end

function handlers.list_files(args)
    local rawPath = (args and args.path) or "."
    if type(rawPath) ~= "string" then return nil, "path must be a string" end
    -- Accept ".", "", "/" and any directory path.  safePath's "no dot" rule
    -- was meant for read_file, not for a directory listing.
    local target = rawPath
    if target == "" or target == "." then target = "." end
    if not fs.exists(target) then
        return nil, "no such path: " .. rawPath
    end
    if not fs.isDir(target) then
        return nil, "not a directory: " .. rawPath .. " (use read_file to read a file)"
    end
    local entries = fs.list(target)
    local out = {}
    for _, name in ipairs(entries) do
        local full = fs.combine(target, name)
        local isDir = fs.isDir(full)
        out[#out + 1] = {
            name = name,
            isDir = isDir,
            size = isDir and 0 or fs.getSize(full),
        }
    end
    return { path = target, entries = jsonArray(out) }
end

function handlers.read_file(args)
    -- Models sometimes aim a write at this tool (observed: read_file with a
    -- 'content' arg).  Silently ignoring that looks like a successful write,
    -- so fail loudly and point at the right tool instead.
    if args and (args.content ~= nil or args.new_string ~= nil or args.old_string ~= nil) then
        return nil, "read_file only READS - nothing was written. To create/overwrite a file use " ..
            "write_file({path, content}); to change part of one use edit_file({path, old_string, new_string})."
    end
    local rawPath = args and args.path
    if type(rawPath) ~= "string" or rawPath == "" then
        return nil, "missing 'path'. To list a directory call list_files. To read a specific file, pass its path (e.g. 'park.lua' or 'docs/turtle.md')."
    end
    local path = fs.combine("", rawPath)
    if path == "" or path == "." then
        return nil, "'" .. rawPath .. "' is the current directory, not a file. Call list_files({}) to see what's here, then read_file with a specific file name."
    end
    if not fs.exists(path) then
        local parent = fs.getDir(path)
        local hint = ""
        if parent and parent ~= "" and fs.isDir(parent) then
            hint = "  Files in '" .. parent .. "': "
            local entries = {}
            for _, n in ipairs(fs.list(parent)) do entries[#entries + 1] = n end
            hint = hint .. table.concat(entries, ", ")
        end
        return nil, "no such file: " .. path .. hint
    end
    if fs.isDir(path) then
        return nil, "'" .. path .. "' is a directory, not a file. Use list_files({path='" .. path .. "'}) to list its contents."
    end
    local f = fs.open(path, "r")
    if not f then return nil, "cannot open " .. path end
    local content = f.readAll() or ""
    f.close()
    local total = #content
    local offset = math.floor(tonumber(args and args.offset) or 0)
    if offset < 0 then offset = 0 end
    if offset > 0 then content = content:sub(offset + 1) end
    local truncated = false
    if #content > MAX_FILE_BYTES then
        content = content:sub(1, MAX_FILE_BYTES)
        truncated = true
    end
    local res = { path = path, content = content, truncated = truncated, size = total }
    if offset > 0 then res.offset = offset end
    if truncated then
        res.next_offset = offset + MAX_FILE_BYTES
        res.hint = "file continues: call read_file again with offset=" .. res.next_offset .. " to read the rest"
    end
    return res
end

function handlers.write_file(args)
    local path, err = safePath(args and args.path)
    if not path then return nil, err end
    local content = args and args.content
    if type(content) ~= "string" then return nil, "missing content" end
    local parent = fs.getDir(path)
    if parent and parent ~= "" and not fs.exists(parent) then
        fs.makeDir(parent)
    end
    local f = fs.open(path, "w")
    if not f then return nil, "cannot open for write: " .. path end
    f.write(content)
    f.close()
    return { path = path, bytes_written = #content }
end

function handlers.edit_file(args)
    local path, err = safePath(args and args.path)
    if not path then return nil, err end
    local oldStr = args and args.old_string
    local newStr = args and args.new_string
    local replaceAll = args and args.replace_all
    if type(oldStr) ~= "string" or oldStr == "" then
        return nil, "missing old_string"
    end
    if type(newStr) ~= "string" then
        return nil, "missing new_string"
    end
    if not fs.exists(path) then return nil, "no such file: " .. path end
    local f = fs.open(path, "r"); local content = f.readAll(); f.close()

    -- Count occurrences (literal, not pattern).
    local function countLiteral(s, sub)
        local n, i = 0, 1
        while true do
            local s2, e2 = s:find(sub, i, true)
            if not s2 then break end
            n = n + 1
            i = e2 + 1
        end
        return n
    end

    local count = countLiteral(content, oldStr)
    if count == 0 then return nil, "old_string not found" end
    if count > 1 and not replaceAll then
        return nil, "old_string is not unique (" .. count .. " matches); add more context or set replace_all=true"
    end

    local replaced
    if replaceAll then
        local out = {}; local i = 1
        while true do
            local s2, e2 = content:find(oldStr, i, true)
            if not s2 then out[#out + 1] = content:sub(i); break end
            out[#out + 1] = content:sub(i, s2 - 1)
            out[#out + 1] = newStr
            i = e2 + 1
        end
        replaced = table.concat(out)
    else
        local s2, e2 = content:find(oldStr, 1, true)
        replaced = content:sub(1, s2 - 1) .. newStr .. content:sub(e2 + 1)
    end

    local g = fs.open(path, "w"); g.write(replaced); g.close()
    return { path = path, replacements = count, bytes = #replaced }
end

function handlers.delete_file(args)
    local path, err = safePath(args and args.path)
    if not path then return nil, err end
    if not fs.exists(path) then return nil, "no such path: " .. path end
    fs.delete(path)
    return { path = path, ok = true }
end

-- propose_plan and ask_user are "interactive" tools - they write a special
-- entry to state and pause the agent until the user responds.  They both
-- receive a second argument (the state) and return a third value (pause=true).

function handlers.propose_plan(args, state)
    if not state then return nil, "state unavailable" end
    if type(args) ~= "table" then args = {} end
    local plan = {
        title          = type(args.title)   == "string" and args.title   or "Plan",
        summary        = type(args.summary) == "string" and args.summary or "",
        steps          = type(args.steps)   == "table"  and args.steps   or {},
        files_to_create = type(args.files_to_create) == "table" and args.files_to_create or {},
        files_to_edit   = type(args.files_to_edit)   == "table" and args.files_to_edit   or {},
    }
    state:pushEntry({ kind = "plan", plan = plan })
    return {
        status = "plan shown to user",
        note   = "Stop here and wait for the user's next message.  They will reply with approve/reject or feedback.  Do NOT write any code yet.",
    }, true  -- pause
end

function handlers.ask_user(args, state)
    if not state then return nil, "state unavailable" end
    if type(args) ~= "table" or type(args.questions) ~= "table" or #args.questions == 0 then
        return nil, "questions array required (1..4 items)"
    end
    if #args.questions > 4 then
        return nil, "at most 4 questions per ask_user call"
    end
    local normalized = {}
    for i, q in ipairs(args.questions) do
        if type(q) ~= "table" or type(q.question) ~= "string" then
            return nil, "question #" .. i .. " missing 'question' string"
        end
        local opts = {}
        if type(q.options) == "table" then
            for _, opt in ipairs(q.options) do
                if type(opt) == "table" and type(opt.label) == "string" then
                    opts[#opts + 1] = { label = opt.label, description = opt.description or "" }
                elseif type(opt) == "string" then
                    opts[#opts + 1] = { label = opt, description = "" }
                end
            end
        end
        if #opts < 2 then
            return nil, "question #" .. i .. " needs 2..4 options"
        end
        if #opts > 4 then
            return nil, "question #" .. i .. " has too many options (max 4)"
        end
        normalized[i] = { question = q.question, options = opts }
    end
    state:pushEntry({ kind = "question", questions = normalized })
    return {
        status = "questions shown to user",
        note   = "Stop here and wait for the user's next message.  They will reply with choices like '1a 2c' or a free-form answer.  Do NOT proceed without their response.",
    }, true  -- pause
end

function handlers.check_syntax(args)
    local path, err = safePath(args and args.path)
    if not path then return nil, err end
    if not fs.exists(path) then return nil, "no such file: " .. path end
    if fs.isDir(path) then return nil, "is a directory" end
    local fn, loadErr = loadfile(path)
    if not fn then
        return { path = path, ok = false, error = tostring(loadErr) }
    end
    return { path = path, ok = true, note = "parses cleanly; this does NOT guarantee runtime correctness" }
end

function handlers.run_script(args)
    local cmd = args and args.command
    if type(cmd) ~= "string" or cmd == "" then return nil, "missing command" end
    local timeoutSec = args and args.timeout_seconds
    if type(timeoutSec) ~= "number" or timeoutSec <= 0 then timeoutSec = 10 end
    if timeoutSec > 60 then timeoutSec = 60 end

    -- Normalize common mistakes.  The CC shell runs `.lua` files directly -
    -- invoking `lua` launches the interactive REPL which just prints its
    -- banner and then blocks reading stdin.  We silently strip a leading
    -- `lua ` and refuse a bare `lua` to save the agent a wasted turn.
    cmd = cmd:gsub("^%s+", ""):gsub("%s+$", "")
    local stripped = cmd:match("^lua%s+(.+)$")
    if stripped then cmd = stripped end
    if cmd == "lua" then
        return nil, "refusing to run the 'lua' REPL - it would block on stdin. Pass the program name directly, e.g. command='hello' to run hello.lua."
    end

    -- Capture output by redirecting term to an in-memory window.
    local w, h = term.getSize()
    local buf = window.create(term.current(), 1, 1, w, math.max(h, 24), false)
    local prev = term.redirect(buf)

    local finished = false
    local runOk, runErr
    local okParallel, perr = pcall(parallel.waitForAny,
        function()
            local ok, e = pcall(shell.run, cmd)
            runOk = ok and e ~= false; runErr = (not ok and e) or (e == false and "shell.run returned false") or nil; finished = true
        end,
        function() sleep(timeoutSec) end
    )

    -- Always restore term, even if parallel itself errored.
    term.redirect(prev)

    if not okParallel then
        if tostring(perr):find("Terminated") then
            return { command = cmd, ok = false, cancelled = true,
                error = "the USER pressed Ctrl+T to abort this run. Stop and ask them how to proceed." }
        end
        return { command = cmd, ok = false, error = "harness error: " .. tostring(perr) }
    end

    -- Gather output from the capture window.
    local _, bh = buf.getSize()
    local lines = {}
    for y = 1, bh do
        local text = buf.getLine(y)
        if text then lines[#lines + 1] = text:gsub("%s+$", "") end
    end
    while #lines > 0 and lines[#lines] == "" do lines[#lines] = nil end
    local output = table.concat(lines, "\n")
    if #output > MAX_RUN_OUTPUT_BYTES then
        output = output:sub(1, MAX_RUN_OUTPUT_BYTES) .. "\n[... output truncated ...]"
    end

    if not finished then
        return {
            command   = cmd,
            ok        = false,
            timed_out = true,
            error     = "timed out after " .. timeoutSec .. "s - the script did not exit. " ..
                        "If this is a UI app (PixelUI, etc.) use check_syntax instead of run_script, " ..
                        "or ask the user to run it manually.",
            output    = output,
        }
    end

    return {
        command = cmd,
        ok = runOk and true or false,
        error = (not runOk) and tostring(runErr) or nil,
        output = output,
    }
end

function handlers.lua(args)
    local code = args and args.code
    if type(code) ~= "string" or code == "" then return nil, "missing code" end
    local timeoutSec = tonumber(args and args.timeout_seconds) or 10
    if timeoutSec <= 0 then timeoutSec = 10 end
    if timeoutSec > 60 then timeoutSec = 60 end

    -- Capture print()/write() output into a buffer; everything else falls
    -- through to the real globals so peripherals, turtle, fs, etc. all work.
    local outBuf = {}
    local env = setmetatable({
        print = function(...)
            local parts = {}
            for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
            outBuf[#outBuf + 1] = table.concat(parts, "\t")
        end,
        write = function(s) outBuf[#outBuf + 1] = tostring(s) end,
    }, { __index = _G })

    -- Try as an expression first so `2+2` or `turtle.getFuelLevel()` just work,
    -- then fall back to a statement chunk.
    local fn = compat.compile("return " .. code, "=lua", env)
    if not fn then
        local loadErr
        fn, loadErr = compat.compile(code, "=lua", env)
        if not fn then return nil, "syntax error: " .. tostring(loadErr) end
    end

    local finished = false
    local callOk, callErr
    local values = {}
    local okParallel, perr = pcall(parallel.waitForAny,
        function()
            local packed = table.pack(pcall(fn))
            callOk = packed[1]
            if callOk then
                for i = 2, packed.n do
                    local v = packed[i]
                    local rendered
                    if type(v) == "table" then
                        local okS, s = pcall(textutils.serialize, v, { compact = true })
                        rendered = okS and s or tostring(v)
                    else
                        rendered = tostring(v)
                    end
                    values[#values + 1] = rendered
                end
            else
                callErr = tostring(packed[2])
            end
            finished = true
        end,
        function() sleep(timeoutSec) end
    )

    if not okParallel then
        if tostring(perr):find("Terminated") then
            return { ok = false, cancelled = true,
                error = "the USER pressed Ctrl+T to abort this code. Stop and ask them how to proceed." }
        end
        return { ok = false, error = "harness error: " .. tostring(perr) }
    end

    local output = table.concat(outBuf, "\n")
    if #output > MAX_RUN_OUTPUT_BYTES then
        output = output:sub(1, MAX_RUN_OUTPUT_BYTES) .. "\n[... output truncated ...]"
    end

    if not finished then
        return {
            ok = false, timed_out = true, output = output,
            error = "timed out after " .. timeoutSec .. "s - the code did not finish. " ..
                    "Avoid blocking loops / os.pullEvent here; for long programs write a file instead.",
        }
    end
    if not callOk then
        return { ok = false, error = callErr, output = output }
    end
    return { ok = true, values = jsonArray(values), output = output }
end

-- Iterative directory walk used by search_files/find_files.  Skips rom/ (OS
-- files) and .computercode/ (session logs) unless the walk starts inside them.
local function walkFiles(root, maxFiles, cb)
    local stack = { root }
    local scanned = 0
    while #stack > 0 do
        local dir = table.remove(stack)
        local okList, names = pcall(fs.list, dir)
        if okList then
            for _, name in ipairs(names) do
                local full = fs.combine(dir, name)
                if fs.isDir(full) then
                    if full ~= "rom" and full ~= ".computercode" then
                        stack[#stack + 1] = full
                    end
                else
                    scanned = scanned + 1
                    if scanned > maxFiles then return true end
                    cb(full)
                end
            end
        end
    end
    return false
end

function handlers.search_files(args)
    local query = args and args.query
    if type(query) ~= "string" or query == "" then return nil, "missing query" end
    local root = (args and args.path) or ""
    root = fs.combine("", root)
    if root ~= "" and not fs.exists(root) then return nil, "no such path: " .. root end
    local caseSensitive = args and args.case_sensitive or false
    local needle = caseSensitive and query or query:lower()

    local matches = {}
    local MAX_MATCHES = 40
    local truncated = walkFiles(root == "" and "." or root, 400, function(full)
        if #matches >= MAX_MATCHES then return end
        if fs.getSize(full) > 128 * 1024 then return end
        local f = fs.open(full, "r")
        if not f then return end
        local content = f.readAll() or ""
        f.close()
        local lineNo = 0
        for line in (content .. "\n"):gmatch("([^\n]*)\n") do
            lineNo = lineNo + 1
            local hay = caseSensitive and line or line:lower()
            if hay:find(needle, 1, true) then
                local text = line:gsub("^%s+", "")
                if #text > 100 then text = text:sub(1, 97) .. "..." end
                matches[#matches + 1] = { file = full, line = lineNo, text = text }
                if #matches >= MAX_MATCHES then break end
            end
        end
    end)
    return {
        query = query,
        count = #matches,
        matches = jsonArray(matches),
        truncated = truncated or #matches >= MAX_MATCHES,
    }
end

function handlers.find_files(args)
    local pattern = args and args.pattern
    if type(pattern) ~= "string" or pattern == "" then return nil, "missing pattern" end
    local root = (args and args.path) or ""
    root = fs.combine("", root)
    if root ~= "" and not fs.exists(root) then return nil, "no such path: " .. root end

    -- Glob -> Lua pattern: escape magic chars, then * -> .*, ? -> .
    local luaPat = pattern:lower()
        :gsub("[%%%^%$%(%)%.%[%]%+%-]", "%%%1")
        :gsub("%*", ".*")
        :gsub("%?", ".")

    local files = {}
    local MAX_RESULTS = 100
    local truncated = walkFiles(root == "" and "." or root, 600, function(full)
        if #files >= MAX_RESULTS then return end
        if full:lower():find(luaPat) then
            files[#files + 1] = { path = full, size = fs.getSize(full) }
        end
    end)
    return { pattern = pattern, count = #files, files = jsonArray(files), truncated = truncated or #files >= MAX_RESULTS }
end

-- ----------------------------------------------------------------------------
-- JSON schemas for OpenRouter (OpenAI-compatible function-calling format).
-- ----------------------------------------------------------------------------

local function tool(name, description, parameters)
    return {
        type = "function",
        ["function"] = {
            name = name,
            description = description,
            parameters = parameters,
        },
    }
end

local function obj(props, required)
    -- CC's textutils.serializeJSON encodes empty Lua tables as "[]" (arrays),
    -- which OpenRouter rejects in JSON-Schema slots.  Omit empty fields so the
    -- emitted JSON only contains object-shaped values.
    local out = { type = "object" }
    local hasProps = false
    for _ in pairs(props or {}) do hasProps = true; break end
    if hasProps then
        out.properties = props
        out.additionalProperties = false
    end
    if required and #required > 0 then
        out.required = required
    end
    return out
end

local function str(description) return { type = "string", description = description } end
local function bool(description) return { type = "boolean", description = description } end

local function arr(itemSchema, description)
    return { type = "array", items = itemSchema, description = description }
end

M.schemas = {
    tool("propose_plan",
        "Present a structured implementation plan to the user and WAIT for approval. " ..
        "Call this BEFORE writing any code for a non-trivial task (anything touching multiple files, designing a new app, or requiring decisions). " ..
        "After this returns, STOP and do NOT call other tools - the user's next message will be their response.",
        obj({
            title    = str("Short title for the plan (e.g., 'Build a turtle mining script')."),
            summary  = str("1-3 sentence overview of the approach."),
            steps    = arr(str("Single step, imperative."), "Ordered list of implementation steps."),
            files_to_create = arr(str("Path."), "Files you plan to create."),
            files_to_edit   = arr(str("Path."), "Existing files you plan to modify."),
        }, { "title", "summary", "steps" })),
    tool("ask_user",
        "Ask the user 1-4 multiple-choice questions when you need a decision to proceed. " ..
        "Each option will be listed and the user can pick by number/letter OR reply freely to discuss. " ..
        "After this returns, STOP and WAIT for the user's next message.",
        obj({
            questions = arr(
                obj({
                    question = str("The question."),
                    options  = arr(
                        obj({
                            label       = str("Short option label."),
                            description = str("Optional longer explanation."),
                        }, { "label" }),
                        "2-4 options."),
                }, { "question", "options" }),
                "1-4 questions."),
        }, { "questions" })),
    tool("list_peripherals", "List all attached peripherals (sides, modem-attached) with their types and methods.", obj({})),
    tool("get_computer_info", "Get information about this computer: id, label, isTurtle, isPocket, isAdvanced, terminal size, fuel level if a turtle.", obj({})),
    tool("list_docs",
        "List available documentation topics. Call this FIRST if you aren't sure what topics exist.",
        obj({})),
    tool("read_doc",
        "Read one specific documentation topic by name. " ..
        "Do NOT pass '.', '/', a file path, or an empty string - pass a short topic name like 'turtle', 'pixelui-widgets', 'fs'. " ..
        "If unsure, call list_docs first.",
        obj({
            topic = str("Short topic name (e.g. 'turtle', 'pixelui', 'pixelui-widgets', 'fs'). NOT a path or a filename."),
        }, { "topic" })),
    tool("list_files",
        "List files and subdirectories in a directory. Call this FIRST to see what files exist before trying to read_file. Defaults to the current directory.",
        obj({
            path = str("Path to a directory. Defaults to '.'. Do not pass a file path here."),
        })),
    tool("read_file",
        "Read the contents of ONE SPECIFIC FILE as text (16 KB per call). " ..
        "If the result has truncated=true, call again with offset=next_offset to read the rest. " ..
        "READ ONLY - to modify a file use write_file or edit_file, never this. " ..
        "Do NOT call with '.', '/', or any directory path - use list_files for that.",
        obj({
            path = str("Path to a specific file (e.g. 'park.lua', 'docs/pixelui.md'). NOT a directory."),
            offset = { type = "number", description = "Byte offset to start reading from (default 0). Use next_offset from a truncated result to continue reading a big file." },
        }, { "path" })),
    tool("write_file", "Write or overwrite a file with the given content. Creates parent directories.", obj({
        path = str("Path to the file."),
        content = str("Full file content to write."),
    }, { "path", "content" })),
    tool("edit_file", "Replace a unique substring in a file. Errors if old_string is not unique unless replace_all=true.", obj({
        path = str("Path to the file."),
        old_string = str("Exact substring to find. Must be unique unless replace_all=true."),
        new_string = str("Replacement text."),
        replace_all = bool("Replace every occurrence instead of erroring on multiple matches."),
    }, { "path", "old_string", "new_string" })),
    tool("delete_file", "Delete a file or directory (recursive).", obj({
        path = str("Path to delete."),
    }, { "path" })),
    tool("run_script",
        "Run a CC shell command and capture up to 4 KB of its output. " ..
        "Pass the program NAME ONLY (optionally with args), NOT 'lua <name>' - the CC shell runs .lua files directly. " ..
        "GOOD: 'hello', 'hello 3', 'turtle/mine 5'. " ..
        "BAD: 'lua hello.lua' (would launch the Lua REPL and time out). " ..
        "Has a timeout (default 10s, max 60s). " ..
        "DO NOT use for PixelUI apps or anything with a blocking event loop (games, computercode, infopad, etc.) - use check_syntax for those instead.",
        obj({
            command = str("Program name + optional args (e.g. 'hello', 'mine 3'). Not a `lua ...` invocation, not for UI apps."),
            timeout_seconds = { type = "number", description = "Seconds before aborting (default 10, max 60). Bump this if you expect a legitimately longer run." },
        }, { "command" })),
    tool("check_syntax",
        "Parse a Lua file without executing it.  Reports syntax errors cleanly. " ..
        "Use this after writing PixelUI apps or any blocking/UI script where run_script would hang.",
        obj({
            path = str("Path to the .lua file to check."),
        }, { "path" })),
    tool("lua",
        "Execute Lua code DIRECTLY on this computer and get back printed output + returned values. " ..
        "This is the fastest way to do one-off operations: call a peripheral method, move the turtle, " ..
        "read redstone, compute something, probe an API, test a snippet.  Full access to all CC globals " ..
        "(peripheral, turtle, redstone, fs, os, textutils, http, ...). " ..
        "Accepts an expression ('2+2', 'turtle.getFuelLevel()') or statements ('for i=1,3 do turtle.forward() end print(\"done\")'). " ..
        "NEVER write a temporary script file just to run one operation - use this instead. " ..
        "Do NOT run blocking event loops / UI apps here (default 10s timeout, max 60).",
        obj({
            code = str("Lua source to execute. Expression or statements. Use print() for progress output."),
            timeout_seconds = { type = "number", description = "Seconds before aborting (default 10, max 60)." },
        }, { "code" })),
    tool("search_files",
        "Search file CONTENTS for a literal text string (like grep). Returns file, line number, and the matching line. " ..
        "Use this to find where a function/variable/string is used before editing.",
        obj({
            query = str("Literal text to search for (not a pattern)."),
            path = str("Directory to search under. Defaults to the root."),
            case_sensitive = bool("Match case exactly (default false)."),
        }, { "query" })),
    tool("find_files",
        "Find files by NAME using glob-style wildcards (like glob). '*' matches anything, '?' one char. " ..
        "Matched against the full path, case-insensitive. Examples: '*.lua', 'docs/*', '*turtle*'.",
        obj({
            pattern = str("Glob pattern, e.g. '*.lua' or '*mine*'."),
            path = str("Directory to search under. Defaults to the root."),
        }, { "pattern" })),
}

-- ----------------------------------------------------------------------------
-- Dispatch
-- ----------------------------------------------------------------------------

---@param name string
---@param argsTable table?
---@param state table?  -- optional, only needed for interactive tools
---@return boolean ok, any result, boolean? pauseAgent
function M.dispatch(name, argsTable, state)
    local fn = handlers[name]
    if not fn then return false, "unknown tool: " .. tostring(name) end
    local ok, result, err = pcall(fn, argsTable, state)
    if not ok then return false, "tool error: " .. tostring(result) end
    if result == nil and err then return false, err end
    -- The second return value of interactive handlers is the pause flag.
    -- For non-interactive handlers err == nil so this resolves to nil.
    local pause = (type(err) == "boolean") and err or nil
    return true, result, pause
end

-- Used by the UI for the "tool: <name>(arg=...)" preview line.
function M.summarizeArgs(argsTable)
    if type(argsTable) ~= "table" then return "" end
    local parts = {}
    for k, v in pairs(argsTable) do
        local s
        if type(v) == "string" then
            s = v
            if #s > 40 then s = s:sub(1, 37) .. "..." end
            s = '"' .. s .. '"'
        elseif type(v) == "table" then
            s = "{...}"
        else
            s = tostring(v)
        end
        parts[#parts + 1] = k .. "=" .. s
        if #parts >= 3 then parts[#parts + 1] = "..."; break end
    end
    return table.concat(parts, ", ")
end

return M
