# 🎵 Yazi Muse

> Lightweight audio preview plugin for [Yazi](https://github.com/sxyazi/yazi) — listen to music without leaving your file manager.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Yazi](https://img.shields.io/badge/yazi-%3E%3D26-orange.svg)](https://github.com/sxyazi/yazi)
[![mpv](https://img.shields.io/badge/requires-mpv-48bb78.svg)](https://mpv.io/)

Auto-plays audio files on hover with metadata, progress bar, and instant track switching — all inside Yazi's preview pane.

---

## ✨ Features

- 🎧 **Auto-play on hover** — cursor on an audio file → instant playback
- 🏷️ **Metadata display** — Artist, Title, Album, Duration via `ffprobe` (cached)
- 📊 **Animated progress bar** — real-time playback progress in the preview pane
- ⚡ **Instant stop** — move away from the file → music cuts off immediately
- ⌨️ **No key hijacking** — mpv ignores terminal input, Yazi stays in control
- 🪶 **Zero heavy deps** — just `mpv` + `ffmpeg`

---

## 📦 Requirements

| Tool | Purpose | Install |
|---|---|---|
| [Yazi](https://yazi-rs.github.io) ≥ 26 | File manager | [Install guide](https://yazi-rs.github.io/docs/installation/) |
| [mpv](https://mpv.io/) | Audio playback | See below |
| [ffmpeg](https://ffmpeg.org/) | Metadata extraction via `ffprobe` | See below |

### Install dependencies

```bash
# Fedora
sudo dnf install mpv ffmpeg

# Ubuntu / Debian
sudo apt install mpv ffmpeg

# Arch Linux
sudo pacman -S mpv ffmpeg

# macOS
brew install mpv ffmpeg
```

---

## 🚀 Installation

### Using Yazi package manager (Recommended)

```bash
ya pack -a hash-BAY/muse.yazi
```

### Manual installation

```bash
# Clone the repository
git clone https://github.com/hash-BAY/muse.yazi ~/.config/yazi/plugins/muse.yazi
```

---

## ⚙️ Configuration

### `~/.config/yazi/yazi.toml`

Add previewers for audio formats:

```toml
[plugin]
prepend_previewers = [
    { name = "*.mp3", run = "muse" },
    { name = "*.wav", run = "muse" },
    { name = "*.flac", run = "muse" },
    { name = "*.ogg", run = "muse" },
    { name = "*.m4a", run = "muse" },
    { mime = "audio/*", run = "muse" },
]
```

### `~/.config/yazi/keymap.toml`

**No keybinding needed** — playback starts automatically on hover.

---

## 🎮 Usage

| Action | Result |
|---|---|
| Hover over an audio file | Instant playback + metadata display |
| Move to another file | Previous track stops, new one starts |
| Leave the music folder | Playback stops |

---

## 🖥️ Preview

```
🎵 Nightcity.mp3
  📌 Title: Nightcity
  🎤 Artist: The Midnight
  💿 Album: Endless Summer
  ⏱ Duration: 04:28

 ▶ PLAYING
   01:15 / 04:28
 ████████████░░░░░░░░░░░░░░░░░░░░ 26%
```

---

## 🐛 Troubleshooting

### No sound?

- Make sure `mpv` is installed and plays audio from the terminal

### Plugin not loading?

- Verify the directory is `~/.config/yazi/plugins/muse.yazi/` (must end in `.yazi`)
- Verify the file is `main.lua` (not `init.lua`)
- Check `yazi.toml` uses `run = "muse"` (not `muse.yazi`)

### Debug

```bash
YAZI_LOG=debug yazi
cat ~/.local/state/yazi/yazi.log | grep -i muse
```

---

## 🚧 Roadmap

- [ ] Album art extraction via `ffprobe`
- [ ] Real-time progress from `mpv` IPC socket
- [ ] Playlist support (`.m3u`, `.cue`)
- [ ] Keybindings: seek ±10s, volume control
- [ ] Color scheme from user's `theme.toml`
- [ ] Auto-stop via DDS when leaving the folder

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.
