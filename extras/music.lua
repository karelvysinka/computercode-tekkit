-- Optional upstream demo: external music service must be selected explicitly.
local api_base_url = (...)
if type(api_base_url) ~= "string" or not api_base_url:match("^https?://") then
    print("Optional demo; not part of the Tekkit agent. Requires compatible audio API.")
    print("Usage: music https://YOUR-MUSIC-SERVICE/")
    return
end
api_base_url = api_base_url:gsub("/*$", "/")
local version = "2.1"

local width, height = term.getSize()
local tab = 1

local waiting_for_input = false
local last_search = nil
local last_search_url = nil
local search_results = nil
local search_error = false
local in_search_result = false
local clicked_result = nil

local playing = false
local queue = {}
local now_playing = nil
local looping = 0
local volume = 1.5

local playing_id = nil
local last_download_url = nil
local playing_status = 0
local is_loading = false
local is_error = false;

local player_handle = nil
local start = nil
local pcm = nil
local size = nil
local decoder = require "cc.audio.dfpwm".make_decoder()
local needs_next_chunk = 0
local buffer

local speakers = { peripheral.find("speaker") }
if #speakers == 0 then
	error("No speakers attached. You need to connect a speaker to this computer. If this is an Advanced Noisy Pocket Computer, then this is a bug, and you should try restarting your Minecraft game.", 0)
end

-- ---------------------------------------------------------------------------
-- Monitor visualizer (top side preferred, falls back to any attached monitor).
-- Frequency-reactive concentric circles driven by the decoded PCM buffer.
-- ---------------------------------------------------------------------------

local function findVizMonitor()
	for _, side in ipairs({ "top", "bottom", "left", "right", "front", "back" }) do
		if peripheral.getType(side) == "monitor" then
			return peripheral.wrap(side)
		end
	end
	return peripheral.find("monitor")
end

local viz_monitor = findVizMonitor()
local viz_w, viz_h = 0, 0
if viz_monitor then
	pcall(viz_monitor.setTextScale, 0.5)
	viz_w, viz_h = viz_monitor.getSize()
	viz_monitor.setBackgroundColor(colors.black)
	viz_monitor.clear()
end

local viz_tick = 0
local viz_song_start = nil

-- Frequency-band reactive values in 0..1.  `target` is the latest reading
-- from the audio buffer; `display` decays toward target each tick so the
-- visual has a smooth attack/release instead of jumping.
local bands_target  = { bass = 0, mid = 0, treble = 0, volume = 0 }
local bands_display = { bass = 0, mid = 0, treble = 0, volume = 0 }
local viz_flash = 0

local function analyzeBuffer(buf)
	-- Rough time-domain frequency split, no FFT.  The mean of |s[i] - s[i-1]|
	-- measures high-frequency energy (treble).  The mean of |s[i]| is total
	-- loudness.  Bass is approximated as the peak of a sliding low-pass window.
	if type(buf) ~= "table" then return end
	local n = #buf
	if n < 64 then return end

	local abs_sum  = 0
	local diff_sum = 0
	local low_win  = 0
	local win      = 32
	local low_peak = 0
	local prev = buf[1] or 0

	for i = 1, n do
		local v = buf[i] or 0
		local a = v < 0 and -v or v
		abs_sum = abs_sum + a

		local d = v - prev
		if d < 0 then d = -d end
		diff_sum = diff_sum + d
		prev = v

		low_win = low_win + v
		if i > win then low_win = low_win - (buf[i - win] or 0) end
		if i >= win then
			local avg = low_win / win
			if avg < 0 then avg = -avg end
			if avg > low_peak then low_peak = avg end
		end
	end

	local vol    = abs_sum  / n / 90
	local treble = diff_sum / n / 50
	local bass   = low_peak / 80

	local mid = vol - (bass * 0.5) - (treble * 0.5)
	if mid < 0 then mid = 0 end

	local function clamp01(x) return x < 0 and 0 or (x > 1 and 1 or x) end
	bands_target.volume = clamp01(vol)
	bands_target.bass   = clamp01(bass)
	bands_target.treble = clamp01(treble)
	bands_target.mid    = clamp01(mid * 1.5)

	if bands_target.volume > bands_display.volume + 0.25 then
		viz_flash = 1
	end
end

local function decayBands()
	local ATTACK, RELEASE = 0.55, 0.18
	for k, t in pairs(bands_target) do
		local d = bands_display[k] or 0
		if t > d then
			bands_display[k] = d + (t - d) * ATTACK
		else
			bands_display[k] = d + (t - d) * RELEASE
		end
	end
	viz_flash = viz_flash * 0.72
	if viz_flash < 0.02 then viz_flash = 0 end
end

local function writeAt(x, y, text, fg, bg)
	if not viz_monitor then return end
	if y < 1 or y > viz_h then return end
	if x < 1 then text = text:sub(2 - x); x = 1 end
	if x > viz_w then return end
	if x + #text - 1 > viz_w then text = text:sub(1, viz_w - x + 1) end
	viz_monitor.setCursorPos(x, y)
	viz_monitor.setBackgroundColor(bg or colors.black)
	viz_monitor.setTextColor(fg or colors.white)
	viz_monitor.write(text)
end

local function fillLine(y, color)
	if not viz_monitor then return end
	viz_monitor.setCursorPos(1, y)
	viz_monitor.setBackgroundColor(color)
	viz_monitor.write(string.rep(" ", viz_w))
end

local function formatSeconds(s)
	if not s or s < 0 then s = 0 end
	local m = math.floor(s / 60)
	local r = math.floor(s) % 60
	return string.format("%d:%02d", m, r)
end

local function drawMonitor()
	if not viz_monitor then return end
	viz_tick = viz_tick + 1
	decayBands()

	viz_monitor.setBackgroundColor(colors.black)
	viz_monitor.clear()

	-- =======================================================================
	-- Reactive frequency visualizer - owns the middle of the screen
	-- =======================================================================
	-- The visualizer is drawn FIRST so the text strips on top/bottom sit on
	-- top of it if there's any overlap.
	local topBandH = 2       -- banner + song line
	local bottomBandH = 2    -- stats + queue peek
	local vizTop    = topBandH + 1
	local vizBottom = viz_h - bottomBandH
	if vizBottom - vizTop < 4 then
		-- Tiny monitor fallback - let the visualizer cover more
		vizTop = 2; vizBottom = viz_h - 1
	end
	local vizH = vizBottom - vizTop + 1
	if vizH < 3 then vizH = 3 end

	local cx = math.floor(viz_w / 2) + 1
	local cy = math.floor((vizTop + vizBottom) / 2)
	-- ASPECT=1.5 below, so max horizontal radius is maxR*1.5 chars wide.
	local maxR = math.min(
		math.floor(vizH / 2),                  -- limit by height
		math.floor((viz_w - 2) / 3)            -- limit by width / ASPECT
	)
	if maxR < 3 then maxR = 3 end

	local bass   = bands_display.bass
	local mid    = bands_display.mid
	local treble = bands_display.treble
	local vol    = bands_display.volume
	if not playing then
		local pulse = 0.35 + 0.15 * math.sin(viz_tick * 0.08)
		bass   = pulse
		mid    = pulse * 0.6
		treble = pulse * 0.4
		vol    = pulse * 0.6
	end

	local volScale = 0.6 + vol * 0.5
	local rBass   = (0.15 + bass   * 0.55) * maxR * volScale
	local rMid    = rBass + 1 + mid    * maxR * 0.35
	local rTreble = rMid  + 0.8 + treble * maxR * 0.30
	if rTreble > maxR then
		local s = maxR / rTreble
		rBass, rMid, rTreble = rBass * s, rMid * s, maxR
	end

	local function bassColor(l)
		if l < 0.20 then return colors.blue
		elseif l < 0.45 then return colors.purple
		elseif l < 0.70 then return colors.magenta
		elseif l < 0.88 then return colors.red
		else                return colors.orange end
	end
	local function midColor(l)
		if l < 0.20 then return colors.gray
		elseif l < 0.50 then return colors.green
		elseif l < 0.80 then return colors.lime
		else                return colors.yellow end
	end
	local function trebleColor(l)
		if l < 0.20 then return colors.gray
		elseif l < 0.50 then return colors.lightBlue
		elseif l < 0.80 then return colors.cyan
		else                return colors.white end
	end

	local ASPECT = 1.5
	local function drawDisk(r, color)
		if r < 0.5 then return end
		local rx = r * ASPECT
		local ry = r
		for y = -math.ceil(ry), math.ceil(ry) do
			for x = -math.ceil(rx), math.ceil(rx) do
				local nx = x / rx
				local ny = y / ry
				if nx * nx + ny * ny <= 1 then
					local px, py = cx + x, cy + y
					if px >= 1 and px <= viz_w and py >= vizTop and py <= vizBottom then
						viz_monitor.setCursorPos(px, py)
						viz_monitor.setBackgroundColor(color)
						viz_monitor.write(" ")
					end
				end
			end
		end
	end
	local function drawRing(rOuter, rInner, color)
		if rOuter - rInner < 0.3 then return end
		local rxO, ryO = rOuter * ASPECT, rOuter
		local rxI, ryI = rInner * ASPECT, rInner
		for y = -math.ceil(ryO), math.ceil(ryO) do
			for x = -math.ceil(rxO), math.ceil(rxO) do
				local o = (x / rxO) ^ 2 + (y / ryO) ^ 2
				local i = rxI > 0.5 and ((x / rxI) ^ 2 + (y / ryI) ^ 2) or 2
				if o <= 1 and i > 1 then
					local px, py = cx + x, cy + y
					if px >= 1 and px <= viz_w and py >= vizTop and py <= vizBottom then
						viz_monitor.setCursorPos(px, py)
						viz_monitor.setBackgroundColor(color)
						viz_monitor.write(" ")
					end
				end
			end
		end
	end

	drawRing(rTreble, rMid,  trebleColor(treble))
	drawRing(rMid,   rBass,  midColor(mid))
	drawDisk(rBass,          bassColor(bass))

	if treble > 0.55 then
		local rayLen = 1 + math.floor(treble * 3)
		local rayColor = trebleColor(treble)
		local spokes = 8
		for s = 0, spokes - 1 do
			local ang = (s / spokes) * math.pi * 2 + viz_tick * 0.05
			local dx = math.cos(ang) * ASPECT
			local dy = math.sin(ang)
			for step = 0, rayLen - 1 do
				local r = rTreble + 1 + step
				local px = cx + math.floor(dx * r + 0.5)
				local py = cy + math.floor(dy * r + 0.5)
				if px >= 1 and px <= viz_w and py >= vizTop and py <= vizBottom then
					viz_monitor.setCursorPos(px, py)
					viz_monitor.setBackgroundColor(rayColor)
					viz_monitor.write(" ")
				end
			end
		end
	end

	if viz_flash > 0.15 then
		local flashColor = viz_flash < 0.4 and colors.lightGray or colors.white
		for _, corner in ipairs({
			{ 1,     vizTop },
			{ viz_w, vizTop },
			{ 1,     vizBottom },
			{ viz_w, vizBottom },
		}) do
			viz_monitor.setCursorPos(corner[1], corner[2])
			viz_monitor.setBackgroundColor(flashColor)
			viz_monitor.write(" ")
		end
	end

	-- =======================================================================
	-- Text strips on top (drawn AFTER the visualizer so they always read)
	-- =======================================================================
	-- Top banner: song name + state
	fillLine(1, colors.purple)
	local title = now_playing and (" \7 " .. (now_playing.name or "")) or " \7 Nothing playing"
	writeAt(2, 1, title, colors.white, colors.purple)
	local state = "idle"
	if is_loading then state = "loading..."
	elseif is_error then state = "error"
	elseif playing  then state = "PLAYING" end
	writeAt(viz_w - #state, 1, state, colors.yellow, colors.purple)

	-- Artist subtitle
	if now_playing and now_playing.artist then
		writeAt(2, 2, now_playing.artist, colors.lightGray, colors.black)
	end

	-- Bottom stats line
	local elapsed = (playing and viz_song_start) and (os.clock() - viz_song_start) or 0
	local stats = string.format(
		"vol %3d%%  queue %d  loop %s  elapsed %s",
		math.floor(100 * volume / 3 + 0.5),
		#queue,
		(looping == 0 and "off" or (looping == 1 and "queue" or "song")),
		formatSeconds(elapsed)
	)
	writeAt(2, viz_h - 1, stats, colors.cyan, colors.black)

	-- Bottom queue peek
	if #queue > 0 then
		local nxt = "next: " .. (queue[1].name or "")
		if #queue > 1 then nxt = nxt .. "    +" .. (#queue - 1) .. " more" end
		writeAt(2, viz_h, nxt, colors.lightGray, colors.black)
	end

	viz_monitor.setBackgroundColor(colors.black)
end

function redrawScreen()
	-- Always refresh the monitor visualizer, regardless of the terminal's
	-- input state, so play/pause/queue changes show up immediately there.
	drawMonitor()

	if waiting_for_input then
		return
	end

	term.setCursorBlink(false)
	term.setBackgroundColor(colors.black)
	term.clear()

	term.setCursorPos(1,1)
	term.setBackgroundColor(colors.gray)
	term.clearLine()

	tabs = {" Now Playing ", " Search "}

	for i=1,#tabs,1 do
		if tab == i then
			term.setTextColor(colors.black)
			term.setBackgroundColor(colors.white)
		else
			term.setTextColor(colors.white)
			term.setBackgroundColor(colors.gray)
		end

		term.setCursorPos((math.floor((width/#tabs)*(i-0.5)))-math.ceil(#tabs[i]/2)+1, 1)
		term.write(tabs[i])
	end

	if tab == 1 then
		drawNowPlaying()
	elseif tab == 2 then
		drawSearch()
	end
end

function drawNowPlaying()
	if now_playing ~= nil then
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.white)
		term.setCursorPos(2,3)
		term.write(now_playing.name)
		term.setTextColor(colors.lightGray)
		term.setCursorPos(2,4)
		term.write(now_playing.artist)
	else
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.lightGray)
		term.setCursorPos(2,3)
		term.write("Not playing")
	end

	if is_loading == true then
		term.setTextColor(colors.gray)
		term.setBackgroundColor(colors.black)
		term.setCursorPos(2,5)
		term.write("Loading...")
	elseif is_error == true then
		term.setTextColor(colors.red)
		term.setBackgroundColor(colors.black)
		term.setCursorPos(2,5)
		term.write("Network error")
	end

	term.setTextColor(colors.white)
	term.setBackgroundColor(colors.gray)

	if playing then
		term.setCursorPos(2, 6)
		term.write(" Stop ")
	else
		if now_playing ~= nil or #queue > 0 then
			term.setTextColor(colors.white)
			term.setBackgroundColor(colors.gray)
		else
			term.setTextColor(colors.lightGray)
			term.setBackgroundColor(colors.gray)
		end
		term.setCursorPos(2, 6)
		term.write(" Play ")
	end

	if now_playing ~= nil or #queue > 0 then
		term.setTextColor(colors.white)
		term.setBackgroundColor(colors.gray)
	else
		term.setTextColor(colors.lightGray)
		term.setBackgroundColor(colors.gray)
	end
	term.setCursorPos(2 + 7, 6)
	term.write(" Skip ")

	if looping ~= 0 then
		term.setTextColor(colors.black)
		term.setBackgroundColor(colors.white)
	else
		term.setTextColor(colors.white)
		term.setBackgroundColor(colors.gray)
	end
	term.setCursorPos(2 + 7 + 7, 6)
	if looping == 0 then
		term.write(" Loop Off ")
	elseif looping == 1 then
		term.write(" Loop Queue ")
	else
		term.write(" Loop Song ")
	end

	term.setCursorPos(2,8)
	paintutils.drawBox(2,8,25,8,colors.gray)
	local width = math.floor(24 * (volume / 3) + 0.5)-1
	if not (width == -1) then
		paintutils.drawBox(2,8,2+width,8,colors.white)
	end
	if volume < 0.6 then
		term.setCursorPos(2+width+2,8)
		term.setBackgroundColor(colors.gray)
		term.setTextColor(colors.white)
	else
		term.setCursorPos(2+width-3-(volume == 3 and 1 or 0),8)
		term.setBackgroundColor(colors.white)
		term.setTextColor(colors.black)
	end
	term.write(math.floor(100 * (volume / 3) + 0.5) .. "%")

	if #queue > 0 then
		term.setBackgroundColor(colors.black)
		for i=1,#queue do
			term.setTextColor(colors.white)
			term.setCursorPos(2,10 + (i-1)*2)
			term.write(queue[i].name)
			term.setTextColor(colors.lightGray)
			term.setCursorPos(2,11 + (i-1)*2)
			term.write(queue[i].artist)
		end
	end
end

function drawSearch()
	paintutils.drawFilledBox(2,3,width-1,5,colors.lightGray)
	term.setBackgroundColor(colors.lightGray)
	term.setCursorPos(3,4)
	term.setTextColor(colors.black)
	term.write(last_search or "Search...")

	if search_results ~= nil then
		term.setBackgroundColor(colors.black)
		for i=1,#search_results do
			term.setTextColor(colors.white)
			term.setCursorPos(2,7 + (i-1)*2)
			term.write(search_results[i].name)
			term.setTextColor(colors.lightGray)
			term.setCursorPos(2,8 + (i-1)*2)
			term.write(search_results[i].artist)
		end
	else
		term.setCursorPos(2,7)
		term.setBackgroundColor(colors.black)
		if search_error == true then
			term.setTextColor(colors.red)
			term.write("Network error")
		elseif last_search_url ~= nil then
			term.setTextColor(colors.lightGray)
			term.write("Searching...")
		else
			term.setCursorPos(1,7)
			term.setTextColor(colors.lightGray)
			print("Tip: You can paste YouTube video or playlist links.")
		end
	end

	if in_search_result == true then
		term.setBackgroundColor(colors.black)
		term.clear()
		term.setCursorPos(2,2)
		term.setTextColor(colors.white)
		term.write(search_results[clicked_result].name)
		term.setCursorPos(2,3)
		term.setTextColor(colors.lightGray)
		term.write(search_results[clicked_result].artist)

		term.setBackgroundColor(colors.gray)
		term.setTextColor(colors.white)

		term.setCursorPos(2,6)
		term.clearLine()
		term.write("Play now")

		term.setCursorPos(2,8)
		term.clearLine()
		term.write("Play next")

		term.setCursorPos(2,10)
		term.clearLine()
		term.write("Add to queue")

		term.setCursorPos(2,13)
		term.clearLine()
		term.write("Cancel")
	end
end

function uiLoop()
	redrawScreen()

	while true do
		if waiting_for_input then
			parallel.waitForAny(
				function()
					term.setCursorPos(3,4)
					term.setBackgroundColor(colors.white)
					term.setTextColor(colors.black)
					local input = read()

					if string.len(input) > 0 then
						last_search = input
						last_search_url = api_base_url .. "?v=" .. version .. "&search=" .. textutils.urlEncode(input)
						http.request(last_search_url)
						search_results = nil
						search_error = false
					else
						last_search = nil
						last_search_url = nil
						search_results = nil
						search_error = false
					end

					waiting_for_input = false
					os.queueEvent("redraw_screen")
				end,
				function()
					while waiting_for_input do
						local event, button, x, y = os.pullEvent("mouse_click")
						if y < 3 or y > 5 or x < 2 or x > width-1 then
							waiting_for_input = false
							os.queueEvent("redraw_screen")
							break
						end
					end
				end
			)
		else
			parallel.waitForAny(
				function()
					local event, button, x, y = os.pullEvent("mouse_click")

					if button == 1 then
						if in_search_result == false then
							if y == 1 then
								if x < width/2 then
									tab = 1
								else
									tab = 2
								end
								redrawScreen()
							end
						end

						if tab == 2 and in_search_result == false then
							if y >= 3 and y <= 5 and x >= 1 and x <= width-1 then
								paintutils.drawFilledBox(2,3,width-1,5,colors.white)
								term.setBackgroundColor(colors.white)
								waiting_for_input = true
							end

							if search_results then
								for i=1,#search_results do
									if y == 7 + (i-1)*2 or y == 8 + (i-1)*2 then
										term.setBackgroundColor(colors.white)
										term.setTextColor(colors.black)
										term.setCursorPos(2,7 + (i-1)*2)
										term.clearLine()
										term.write(search_results[i].name)
										term.setTextColor(colors.gray)
										term.setCursorPos(2,8 + (i-1)*2)
										term.clearLine()
										term.write(search_results[i].artist)
										sleep(0.2)
										in_search_result = true
										clicked_result = i
										redrawScreen()
									end
								end
							end
						elseif tab == 2 and in_search_result == true then
							term.setBackgroundColor(colors.white)
							term.setTextColor(colors.black)

							if y == 6 then
								term.setCursorPos(2,6)
								term.clearLine()
								term.write("Play now")
								sleep(0.2)
								in_search_result = false
								for _, speaker in ipairs(speakers) do
									speaker.stop()
									os.queueEvent("playback_stopped")
								end
								playing = true
								is_error = false
								playing_id = nil
								if search_results[clicked_result].type == "playlist" then
									now_playing = search_results[clicked_result].playlist_items[1]
									queue = {}
									if #search_results[clicked_result].playlist_items > 1 then
										for i=2, #search_results[clicked_result].playlist_items do
											table.insert(queue, search_results[clicked_result].playlist_items[i])
										end
									end
								else
									now_playing = search_results[clicked_result]
								end
								os.queueEvent("audio_update")
							end

							if y == 8 then
								term.setCursorPos(2,8)
								term.clearLine()
								term.write("Play next")
								sleep(0.2)
								in_search_result = false
								if search_results[clicked_result].type == "playlist" then
									for i = #search_results[clicked_result].playlist_items, 1, -1 do
										table.insert(queue, 1, search_results[clicked_result].playlist_items[i])
									end
								else
									table.insert(queue, 1, search_results[clicked_result])
								end
								os.queueEvent("audio_update")
							end

							if y == 10 then
								term.setCursorPos(2,10)
								term.clearLine()
								term.write("Add to queue")
								sleep(0.2)
								in_search_result = false
								if search_results[clicked_result].type == "playlist" then
									for i = 1, #search_results[clicked_result].playlist_items do
										table.insert(queue, search_results[clicked_result].playlist_items[i])
									end
								else
									table.insert(queue, search_results[clicked_result])
								end
								os.queueEvent("audio_update")
							end

							if y == 13 then
								term.setCursorPos(2,13)
								term.clearLine()
								term.write("Cancel")
								sleep(0.2)
								in_search_result = false
							end

							redrawScreen()
						elseif tab == 1 and in_search_result == false then
							if y == 6 then
								if x >= 2 and x < 2 + 6 then
									if playing or now_playing ~= nil or #queue > 0 then
										term.setBackgroundColor(colors.white)
										term.setTextColor(colors.black)
										term.setCursorPos(2, 6)
										if playing then
											term.write(" Stop ")
										else
											term.write(" Play ")
										end
										sleep(0.2)
									end
									if playing then
										playing = false
										for _, speaker in ipairs(speakers) do
											speaker.stop()
											os.queueEvent("playback_stopped")
										end
										playing_id = nil
										is_loading = false
										is_error = false
										os.queueEvent("audio_update")
									elseif now_playing ~= nil then
										playing_id = nil
										playing = true
										is_error = false
										os.queueEvent("audio_update")
									elseif #queue > 0 then
										now_playing = queue[1]
										table.remove(queue, 1)
										playing_id = nil
										playing = true
										is_error = false
										os.queueEvent("audio_update")
									end
								end

								if x >= 2 + 7 and x < 2 + 7 + 6 then
									if now_playing ~= nil or #queue > 0 then
										term.setBackgroundColor(colors.white)
										term.setTextColor(colors.black)
										term.setCursorPos(2 + 7, 6)
										term.write(" Skip ")
										sleep(0.2)

										is_error = false
										if playing then
											for _, speaker in ipairs(speakers) do
												speaker.stop()
												os.queueEvent("playback_stopped")
											end
										end
										if #queue > 0 then
											if looping == 1 then
												table.insert(queue, now_playing)
											end
											now_playing = queue[1]
											table.remove(queue, 1)
											playing_id = nil
										else
											now_playing = nil
											playing = false
											is_loading = false
											is_error = false
											playing_id = nil
										end
										os.queueEvent("audio_update")
									end
								end

								if x >= 2 + 7 + 7 and x < 2 + 7 + 7 + 12 then
									if looping == 0 then
										looping = 1
									elseif looping == 1 then
										looping = 2
									else
										looping = 0
									end
								end
							end

							if y == 8 then
								if x >= 1 and x < 2 + 24 then
									volume = (x - 1) / 24 * 3
								end
							end

							redrawScreen()
						end
					end
				end,
				function()
					local event, button, x, y = os.pullEvent("mouse_drag")

					if button == 1 then
						if tab == 1 and in_search_result == false then
							if y >= 7 and y <= 9 then
								if x >= 1 and x < 2 + 24 then
									volume = (x - 1) / 24 * 3
								end
							end
							redrawScreen()
						end
					end
				end,
				function()
					local event = os.pullEvent("redraw_screen")
					redrawScreen()
				end
			)
		end
	end
end

function audioLoop()
	while true do
		if playing and now_playing then
			local thisnowplayingid = now_playing.id
			if playing_id ~= thisnowplayingid then
				playing_id = thisnowplayingid
				last_download_url = api_base_url .. "?v=" .. version .. "&id=" .. textutils.urlEncode(playing_id)
				playing_status = 0
				needs_next_chunk = 1

				-- Reset visualizer state for the new song.
				bands_target  = { bass = 0, mid = 0, treble = 0, volume = 0 }
				bands_display = { bass = 0, mid = 0, treble = 0, volume = 0 }
				viz_flash = 0
				viz_song_start = nil

				http.request({url = last_download_url, binary = true})
				is_loading = true

				os.queueEvent("redraw_screen")
				os.queueEvent("audio_update")
			elseif playing_status == 1 and needs_next_chunk == 1 then

				while true do
					local chunk = player_handle.read(size)
					if not chunk then
						if looping == 2 or (looping == 1 and #queue == 0) then
							playing_id = nil
						elseif looping == 1 and #queue > 0 then
							table.insert(queue, now_playing)
							now_playing = queue[1]
							table.remove(queue, 1)
							playing_id = nil
						else
							if #queue > 0 then
								now_playing = queue[1]
								table.remove(queue, 1)
								playing_id = nil
							else
								now_playing = nil
								playing = false
								playing_id = nil
								is_loading = false
								is_error = false
							end
						end

						os.queueEvent("redraw_screen")

						player_handle.close()
						needs_next_chunk = 0
						break
					else
						if start then
							chunk, start = start .. chunk, nil
							size = size + 4
						end

						buffer = decoder(chunk)
						analyzeBuffer(buffer)
						if viz_song_start == nil then viz_song_start = os.clock() end

						local fn = {}
						for i, speaker in ipairs(speakers) do
							fn[i] = function()
								local name = peripheral.getName(speaker)
								if true then
									if speaker.playAudio(buffer, volume) then
										parallel.waitForAny(
											function()
												repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
											end,
											function()
												local event = os.pullEvent("playback_stopped")
												return
											end
										)
										if not playing or playing_id ~= thisnowplayingid then
											return
										end
									end
								else
									while not speaker.playAudio(buffer, volume) do
										parallel.waitForAny(
											function()
												repeat until select(2, os.pullEvent("speaker_audio_empty")) == name
											end,
											function()
												local event = os.pullEvent("playback_stopped")
												return
											end
										)
										if not playing or playing_id ~= thisnowplayingid then
											return
										end
									end
								end
								if not playing or playing_id ~= thisnowplayingid then
									return
								end
							end
						end

						local ok, err = pcall(parallel.waitForAll, table.unpack(fn))
						if not ok then
							needs_next_chunk = 2
							is_error = true
							break
						end

						if not playing or playing_id ~= thisnowplayingid then
							break
						end
					end
				end
				os.queueEvent("audio_update")
			end
		end

		os.pullEvent("audio_update")
	end
end

function httpLoop()
	while true do
		parallel.waitForAny(
			function()
				local event, url, handle = os.pullEvent("http_success")

				if url == last_search_url then
					search_results = textutils.unserialiseJSON(handle.readAll())
					os.queueEvent("redraw_screen")
				end
				if url == last_download_url then
					is_loading = false
					player_handle = handle
					start = handle.read(4)
					size = 16 * 1024 - 4
					playing_status = 1
					os.queueEvent("redraw_screen")
					os.queueEvent("audio_update")
				end
			end,
			function()
				local event, url = os.pullEvent("http_failure")

				if url == last_search_url then
					search_error = true
					os.queueEvent("redraw_screen")
				end
				if url == last_download_url then
					is_loading = false
					is_error = true
					playing = false
					playing_id = nil
					os.queueEvent("redraw_screen")
					os.queueEvent("audio_update")
				end
			end
		)
	end
end

-- Periodic refresh of the monitor visualizer.  audioLoop only updates the
-- viz once per decoded chunk (~every couple of seconds), but we want the
-- idle animation / clock / queue changes to tick smoothly in between.
function vizLoop()
	while true do
		drawMonitor()
		sleep(0.2)
	end
end

if viz_monitor then
	parallel.waitForAny(uiLoop, audioLoop, httpLoop, vizLoop)
else
	parallel.waitForAny(uiLoop, audioLoop, httpLoop)
end
