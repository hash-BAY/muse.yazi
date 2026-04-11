-- Yazi Muse — Auto-play with DDS auto-stop
-- DDS hooks catch cursor leaving audio file
-- Unique tags prevent race conditions
local M = {}

-- ============================================================
-- State store with unique tag
-- ============================================================
local state = ya.sync(function(st)
	if st.cache == nil then st.cache = {} end
	if st.counter == nil then st.counter = 0 end
	return {
		url = st.url,
		start = st.start,
		cache = st.cache,
		tag = st.tag,
		counter = st.counter,
	}
end)

local set_playing = ya.sync(function(st, url, start, tag)
	st.url = url
	st.start = start
	st.tag = tag
	st.counter = st.counter + 1
end)

local clear_state = ya.sync(function(st)
	st.url = nil
	st.start = nil
	st.tag = nil
end)

-- ============================================================
local function fmt_time(sec)
	if not sec or sec < 0 then return "--:--" end
	local m = math.floor(sec / 60)
	local s = math.floor(sec % 60)
	return string.format("%02d:%02d", m, s)
end

-- Check if file is audio
local function is_audio(url_str, mime)
	mime = mime or ""
	if mime:find("^audio/") then return true end
	local ext = url_str:lower():match("%.([^.]+)$")
	local audio_ext = {
		mp3=true, wav=true, flac=true, ogg=true, m4a=true,
		aac=true, wma=true, opus=true, aiff=true, alac=true,
	}
	return audio_ext[ext] or false
end

-- Kill specific tag (sync context, os.execute only)
local function kill_tag_sync(tag)
	if tag then
		os.execute("pkill -9 -f '" .. tag .. "' >/dev/null 2>&1 &")
	end
end

-- ============================================================
-- DDS Setup: global cursor tracking
-- Called from ~/.config/yazi/init.lua
-- ============================================================
function M:setup()
	local function stop_if_left_audio()
		local st = state()
		if not st.tag then return end -- Nothing playing

		-- Check current file under cursor
		local h = cx.active.current.hovered
		local file_url = h and tostring(h.url) or ""
		-- h.mime() crashes in sync context; check extension only
		local file_mime = ""

		if is_audio(file_url, file_mime) then
			-- On audio — maybe different track
			if st.url and st.url ~= file_url then
				kill_tag_sync(st.tag)
				clear_state()
			end
		else
			-- Not audio — kill
			kill_tag_sync(st.tag)
			clear_state()
		end
	end

	-- Subscribe to navigation events
	ps.sub("hover", stop_if_left_audio)
	ps.sub("cd", stop_if_left_audio)
end

-- ============================================================
-- Kill from peek (async context, uses Command)
-- ============================================================
local function kill_current_mpv()
	local st = state()
	if st.tag then
		Command("pkill"):arg({ "-9", "-f", st.tag }):output()
		clear_state()
	end
end

-- ============================================================
-- UI Rendering
-- ============================================================
local function build_ui(job, file_name, meta, playing, elapsed, duration)
	local area = job.area
	local lines = {
		ui.Line({ ui.Span(" 🎵 "):fg("yellow"), ui.Span(file_name):bold() }),
		ui.Line({ ui.Span("") }),
	}

	if meta then
		if meta.title then
			table.insert(lines, ui.Line({ ui.Span("  📌 Title: "):fg("cyan"), ui.Span(meta.title) }))
		end
		if meta.artist then
			table.insert(lines, ui.Line({ ui.Span("  🎤 Artist: "):fg("cyan"), ui.Span(meta.artist) }))
		end
		if meta.album then
			table.insert(lines, ui.Line({ ui.Span("  💿 Album: "):fg("cyan"), ui.Span(meta.album) }))
		end
		if meta.track_num then
			local track_str = meta.track_num
			if meta.track_total then
				track_str = track_str .. "/" .. meta.track_total
			end
			table.insert(lines, ui.Line({ ui.Span("  🔢 Track: "):fg("cyan"), ui.Span(track_str) }))
		end
		if meta.duration then
			table.insert(lines, ui.Line({ ui.Span("  ⏱ Duration: "):fg("cyan"), ui.Span(fmt_time(meta.duration)) }))
		end
	end

	table.insert(lines, ui.Line({ ui.Span("") }))

	-- Technical details (from streams)
	if meta.codec or meta.bitrate or meta.sample_rate or meta.channels or meta.bit_depth then
		local spans = { ui.Span(" ") }
		if meta.codec then
			table.insert(spans, ui.Span("🎛️ "):fg("green"))
			table.insert(spans, ui.Span(meta.codec .. " "):fg("gray"))
		end
		if meta.bitrate then
			table.insert(spans, ui.Span("📶 "):fg("green"))
			table.insert(spans, ui.Span(meta.bitrate .. " "):fg("gray"))
		end
		if meta.sample_rate then
			table.insert(spans, ui.Span("📊 "):fg("green"))
			table.insert(spans, ui.Span(meta.sample_rate .. " "):fg("gray"))
		end
		if meta.bit_depth then
			table.insert(spans, ui.Span("🔢 "):fg("green"))
			table.insert(spans, ui.Span(meta.bit_depth .. " "):fg("gray"))
		end
		if meta.channels then
			table.insert(spans, ui.Span("🔊 "):fg("green"))
			table.insert(spans, ui.Span(meta.channels):fg("gray"))
		end
		table.insert(lines, ui.Line(spans))
	end

	table.insert(lines, ui.Line({ ui.Span("") }))

	if playing then
		local current_time = math.min(elapsed or 0, duration or 0)

		table.insert(lines, ui.Line({
			ui.Span(" ▶ "):fg("green"):bold(),
			ui.Span("PLAYING"):fg("green"):bold(),
		}))
		table.insert(lines, ui.Line({
			ui.Span(" "):fg("black"),
			ui.Span(fmt_time(current_time)):fg("white"),
			ui.Span(" / "):fg("darkgray"),
			ui.Span(fmt_time(duration or 0)):fg("white"),
		}))

		if duration and duration > 0 then
			local pct = math.min(current_time / duration, 1.0)
			local bar_width = math.max(10, area.w - 2)
			local filled = math.floor(pct * bar_width)
			local empty = bar_width - filled
			table.insert(lines, ui.Line({
				ui.Span(" " .. string.rep("█", filled) .. string.rep("░", empty) .. " "):fg("green"),
			}))
		end
	else
		table.insert(lines, ui.Line({ ui.Span(" ⏸ STOPPED"):fg("yellow") }))
	end

	return ui.Text(lines):area(area)
end

-- ============================================================
-- Peek
-- ============================================================
function M:peek(job)
	local file_url = tostring(job.file.url)
	local file_name = tostring(job.file.name or "Unknown")

	local st = state()

	-- File changed to different audio — stop old
	if st.url and st.url ~= file_url then
		kill_current_mpv()
		st = state()
	end

	-- Launch new audio
	if not st.url or st.url ~= file_url then
		-- Unique tag per track — no race condition
		local new_tag = "yazi-muse-mpv-" .. tostring(st.counter + 1)

		os.execute("mpv --no-video --really-quiet --no-input-terminal --force-media-title='" .. new_tag .. "' '" .. file_url .. "' &")

		set_playing(file_url, os.time(), new_tag)
		st = state()
	end

	-- Check metadata cache
	local meta = st.cache[file_url]
	if not meta then
		local output = Command("ffprobe"):arg({
			"-v", "quiet",
			"-show_format",
			"-show_streams",
			"-print_format", "json",
			file_url,
		}):output()

		if output and output.status and output.status.success then
			local ok, json = pcall(ya.json_decode, output.stdout)
			if ok and json and json.format then
				local format = json.format
				local stream = json.streams and json.streams[1] or {}

				-- Parse track number: "4", "4/12", "04"
				local track_raw = format.tags and format.tags.track
				local track_num, track_total = nil, nil
				if track_raw then
					track_num, track_total = track_raw:match("^(%d+)/(%d+)$")
					if not track_num then
						track_num = track_raw:match("^(%d+)$")
					end
				end

				-- Format: tags and duration
				meta = {
					title = format.tags and format.tags.title,
					artist = format.tags and format.tags.artist,
					album = format.tags and format.tags.album,
					duration = tonumber(format.duration),
					track_num = track_num,
					track_total = track_total,
				}

				-- Stream: technical details
				if stream.codec_name then
					meta.codec = stream.codec_name
				end
				if stream.bit_rate then
					local br = tonumber(stream.bit_rate)
					if br then meta.bitrate = math.floor(br / 1000) .. "kbps" end
				elseif format.bit_rate then
					local br = tonumber(format.bit_rate)
					if br then meta.bitrate = math.floor(br / 1000) .. "kbps" end
				end
				if stream.sample_rate then
					local sr = tonumber(stream.sample_rate)
					if sr then
						if sr >= 1000 then
							meta.sample_rate = string.format("%.1fkHz", sr / 1000)
						else
							meta.sample_rate = sr .. "Hz"
						end
					end
				end
				if stream.channels then
					local ch = stream.channels
					if ch == 1 then meta.channels = "mono"
					elseif ch == 2 then meta.channels = "stereo"
					else meta.channels = ch .. "ch" end
				elseif stream.channel_layout then
					meta.channels = stream.channel_layout
				end
				if stream.bits_per_sample and stream.bits_per_sample > 0 then
					meta.bit_depth = stream.bits_per_sample .. "-bit"
				end

				st.cache[file_url] = meta
			end
		end
	end

	-- Render first frame
	local playing = (st.url == file_url)
	local elapsed = st.start and (os.time() - st.start) or 0
	local duration = meta and meta.duration or 0
	local widget = build_ui(job, file_name, meta, playing, elapsed, duration)

	if ya.preview_widgets then
		ya.preview_widgets(job, { widget })
	else
		ya.preview_widget(job, widget)
	end

	-- Progress animation
	if playing then
		while true do
			local st2 = state()
			if st2.url ~= file_url then break end

			local elapsed2 = st2.start and (os.time() - st2.start) or 0
			local w = build_ui(job, file_name, meta, true, elapsed2, duration)

			if ya.preview_widgets then
				ya.preview_widgets(job, { w })
			else
				ya.preview_widget(job, w)
			end

			ya.sleep(0.5)
		end
	end
end

function M:seek(job) end
function M:entry() end

return M
