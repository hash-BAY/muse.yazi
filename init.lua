-- Yazi Muse — Простая версия: мгновенный старт/стоп
-- mpv НЕ перехватывает клавиши + авто-стоп при уходе
local M = {}

-- ============================================================
-- Хранилище состояния
-- ============================================================
local state = ya.sync(function(st)
	if st.cache == nil then st.cache = {} end
	return {
		url = st.url,
		start = st.start,
		cache = st.cache,
	}
end)

local set_playing = ya.sync(function(st, url, start)
	st.url = url
	st.start = start
end)

local clear_state = ya.sync(function(st)
	st.url = nil
	st.start = nil
end)

-- ============================================================
local function fmt_time(sec)
	if not sec or sec < 0 then return "--:--" end
	local m = math.floor(sec / 60)
	local s = math.floor(sec % 60)
	return string.format("%02d:%02d", m, s)
end

-- Мгновенное убийство (SIGKILL)
local function kill_mpv()
	Command("pkill"):arg({ "-9", "-f", "yazi-muse-mpv" }):output()
end

-- ============================================================
-- Отрисовка UI
-- ============================================================
local function build_ui(job, file_name, meta, playing, elapsed, duration)
	local area = job.area
	local lines = {
		ui.Line({ ui.Span("🎵 "):fg("yellow"), ui.Span(file_name):bold() }),
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
		if meta.duration then
			table.insert(lines, ui.Line({ ui.Span("  ⏱ Duration: "):fg("cyan"), ui.Span(fmt_time(meta.duration)) }))
		end
	end

	table.insert(lines, ui.Line({ ui.Span("") }))

	if playing then
		local current_time = math.min(elapsed or 0, duration or 0)

		table.insert(lines, ui.Line({
			ui.Span(" ▶ "):fg("green"):bold(),
			ui.Span("PLAYING"):fg("green"):bold(),
		}))
		table.insert(lines, ui.Line({
			ui.Span(" "):fg("black"), -- пробел
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

local function render_widget(job, widget)
	if ya.preview_widgets then
		ya.preview_widgets(job, { widget })
	else
		ya.preview_widget(job, widget)
	end
end

-- ============================================================
-- Peek — мгновенная реакция, mpv НЕ перехватывает клавиши
-- ============================================================
function M:peek(job)
	local file_url = tostring(job.file.url)
	local file_name = tostring(job.file.name or "Unknown")

	local st = state()

	-- === МГНОВЕННЫЙ СТОП при уходе с играющего файла ===
	if st.url and st.url ~= file_url then
		kill_mpv()
		clear_state()
		st = state()
	end

	-- === МГНОВЕННЫЙ СТАРТ для нового файла ===
	if not st.url or st.url ~= file_url then
		kill_mpv()
		-- --no-input-terminal: mpv НЕ читает клавиши с терминала
		os.execute("mpv --no-video --really-quiet --no-input-terminal --force-media-title=yazi-muse-mpv '" .. file_url .. "' &")
		set_playing(file_url, os.time())
		st = state()
	end

	-- Проверяем кэш метаданных
	local meta = st.cache[file_url]
	if not meta then
		local output = Command("ffprobe"):arg({
			"-v", "quiet",
			"-show_format",
			"-print_format", "json",
			file_url,
		}):output()

		if output and output.status and output.status.success then
			local ok, json = pcall(ya.json_decode, output.stdout)
			if ok and json and json.format then
				meta = {
					title = json.format.tags and json.format.tags.title,
					artist = json.format.tags and json.format.tags.artist,
					album = json.format.tags and json.format.tags.album,
					duration = tonumber(json.format.duration),
				}
				st.cache[file_url] = meta
			end
		end
	end

	-- Рендер первого кадра
	local playing = (st.url == file_url)
	local elapsed = st.start and (os.time() - st.start) or 0
	local duration = meta and meta.duration or 0
	local widget = build_ui(job, file_name, meta, playing, elapsed, duration)
	render_widget(job, widget)

	-- Анимация прогресса
	if playing then
		while true do
			local st2 = state()
			if st2.url ~= file_url then break end

			local elapsed2 = st2.start and (os.time() - st2.start) or 0
			local w = build_ui(job, file_name, meta, true, elapsed2, duration)
			render_widget(job, w)

			ya.sleep(0.5)
		end
	end
end

function M:seek(job) end
function M:entry() end

return M
