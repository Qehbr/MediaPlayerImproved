# Media Player Improved

An enhanced media player widget for KDE Plasma 6, based on the default media player. Adds an audio visualizer, scrolling text for long track names, a wider and more customizable layout, and extensive settings to tailor the widget to your setup.

Works with any MPRIS2-compatible media player (Spotify, VLC, Firefox, MPV, Rhythmbox, etc.).

---

## Features

### Audio Visualizer
- Animated frequency bars that react to playback state
- Visible in both the compact (panel) and expanded (popup) views
- Four position options in compact mode: **Bottom**, **Left**, **Right**, or **Behind** text
- Configurable bar count (5–50), height (10–100 px), and color
- 7 color presets plus theme default: Red, Green, Blue, Purple, Orange, Yellow
- "Behind" mode renders bars beneath the text with adjustable opacity for a subtle depth effect
- Bars fade when paused and animate smoothly when playing

### Scrolling Text
- Long track titles and artist names scroll horizontally (marquee style)
- Only activates when the text overflows the available space
- Configurable scroll speed (10–200 px/s)
- Can be disabled in settings

### Wider & Customizable Layout
- Configurable maximum width for the compact panel widget (5–100 grid units)
- Album art with smooth transitions between tracks
- Blurred album art background in the expanded view
- Responsive layout that adapts to horizontal panels, vertical panels, and desktop placement

### Expanded View (Popup)
- Full album art with blurred background
- Track title, artist, and album
- Seek slider with elapsed/remaining time
- Playback rate selector (0.25×–2.0×)
- Shuffle and repeat controls
- Multi-player tab bar when more than one MPRIS2 player is active
- Keyboard shortcuts and touch/swipe gestures

### Compact View (Panel)
- Album art + title/artist side by side
- Back and forward track buttons
- Middle-click to play/pause
- Scroll wheel to adjust volume
- Mouse back/forward buttons for track navigation

### Keyboard Shortcuts (Expanded View)
| Key | Action |
|-----|--------|
| `Space` / `K` | Play / Pause |
| `P` | Previous track |
| `N` | Next track |
| `S` | Stop |
| `J` | Seek back 5 s |
| `L` | Seek forward 5 s |
| `Home` | Go to start |
| `End` | Go to end |
| `0`–`9` | Jump to 0%–90% |
| `Ctrl+Tab` | Switch player |

---

## Requirements

- KDE Plasma **6.0** or later
- Qt 6 with QtQuick, QtQuick.Layouts, QtQuick.Controls, Qt5Compat.GraphicalEffects
- An MPRIS2-compatible media player

---

## Installation

### From KDE Store (recommended)
1. Right-click your panel → **Add or Manage Widgets**
2. Click **Get New Widgets** → **Download New Plasma Widgets**
3. Search for **Media Player Improved** and install

### Manual installation
```bash
git clone https://github.com/Qehbr/MediaPlayerImproved.git
cd MediaPlayerImproved
kpackagetool6 --install . --type Plasma/Applet
```

To update an existing installation:
```bash
kpackagetool6 --upgrade . --type Plasma/Applet
```

To uninstall:
```bash
kpackagetool6 --remove org.forgedRice.plasma.mediacontroller.improved --type Plasma/Applet
```

After installing, add the widget to your panel:
1. Right-click your panel → **Add or Manage Widgets**
2. Search for **Media Player Improved** and drag it onto the panel

---

## Configuration

Right-click the widget → **Configure Media Player Improved** to open the settings dialog.

### General
| Setting | Default | Description |
|---------|---------|-------------|
| Volume step | 5% | How much each scroll tick changes volume (1–20%) |

### Compact Representation
| Setting | Default | Description |
|---------|---------|-------------|
| Maximum width | 20 | Max widget width in grid units (5–100) |
| Scrolling text | Enabled | Marquee animation for long text |
| Scroll speed | 50 px/s | Text scroll speed (10–200) |

### Audio Visualizer
| Setting | Default | Description |
|---------|---------|-------------|
| Enable visualizer | Enabled | Master on/off toggle |
| Show in compact view | Enabled | Visualizer in the panel widget |
| Position (compact) | Bottom | Bottom / Left / Right / Behind |
| Show in expanded view | Enabled | Visualizer in the popup |
| Height | 30 px | Bar height in pixels (10–100) |
| Number of bars | 20 | Bar count (5–50) |
| Bar color | Theme default | Hex color or one of 7 presets |
| Behind opacity | 0.3 | Opacity when using "Behind" position (0.1–1.0) |

---

## License

GPL-2.0-or-later — see [https://www.gnu.org/licenses/old-licenses/gpl-2.0.html](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)

---

## Credits

Based on the default KDE Plasma media player widget.
Author: [Yuriy Rusanov](https://github.com/Qehbr)