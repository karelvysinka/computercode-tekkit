-- Doc loader: lists docs/*.md and reads them by topic name.
-- DOCS_DIR is set by the entry script (computercode.lua) to an absolute path
-- so the docs work regardless of the shell's current directory.

local M = {}

local DOCS_DIR = "docs"
local MAX_BYTES = 16 * 1024

function M.setRoot(rootDir)
    if type(rootDir) ~= "string" or rootDir == "" then return end
    DOCS_DIR = fs.combine(rootDir, "docs")
end

function M.getRoot()
    return DOCS_DIR
end

local function safeName(topic)
    if type(topic) ~= "string" then return nil end
    -- Strip path traversal and any extension the model might have added.
    topic = topic:gsub("%.md$", "")
    if topic:find("[^%w%-_]") then return nil end
    return topic
end

function M.list()
    if not fs.isDir(DOCS_DIR) then return {} end
    local out = {}
    for _, name in ipairs(fs.list(DOCS_DIR)) do
        if name:sub(-3) == ".md" then
            out[#out + 1] = name:sub(1, -4)
        end
    end
    table.sort(out)
    return out
end

function M.indexText()
    local indexPath = fs.combine(DOCS_DIR, "index.md")
    if fs.exists(indexPath) then
        local f = fs.open(indexPath, "r"); local s = f.readAll(); f.close()
        return s
    end
    -- Fall back: synthesize a list.
    local lines = { "# Available docs", "" }
    for _, t in ipairs(M.list()) do
        lines[#lines + 1] = "- " .. t
    end
    return table.concat(lines, "\n")
end

local function topicList()
    local names = {}
    for _, n in ipairs(M.list()) do names[#names + 1] = n end
    return table.concat(names, ", ")
end

function M.read(topic)
    if type(topic) ~= "string" or topic == "" then
        return nil, "missing 'topic' name. Available topics: " .. topicList()
    end
    local clean = safeName(topic)
    if not clean then
        return nil, "'" .. tostring(topic) .. "' is not a valid topic name. Use a short name like 'turtle', 'pixelui', 'fs'. Available: " .. topicList()
    end
    local path = fs.combine(DOCS_DIR, clean .. ".md")
    if not fs.exists(path) then
        return nil, "no doc '" .. clean .. "'. Available topics: " .. topicList()
    end
    local f = fs.open(path, "r")
    if not f then return nil, "could not open " .. path end
    local content = f.readAll()
    f.close()
    if #content > MAX_BYTES then
        content = content:sub(1, MAX_BYTES) .. "\n\n[truncated at " .. MAX_BYTES .. " bytes]"
    end
    return "TARGET: CC 1.89.2 / Lua 5.1 / Minecraft 1.12.2. This upstream reference may describe newer features. Verify availability and peripheral methods before use.\n\n" .. content
end

return M
