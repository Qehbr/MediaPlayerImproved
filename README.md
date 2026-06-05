# Media Player Improved

An enhanced media player widget for KDE Plasma 6, based on the default media player. Adds an audio visualizer, scrolling text for long track names, a wider and more customizable layout, and extensive settings to tailor the widget to your setup.

Works with any MPRIS2-compatible media player (Spotify, VLC, Firefox, MPV, Rhythmbox, etc.).

---

## Features

### Audio Visualizer
- Animated frequency bars that react to playback state
- Visible in both the compact (panel) and expanded (popup) views
- Four position options in compact mode: **Bottom**, **Left**, **Right**, or **Behind** text
- Configurable bar count (5–50) and height (10–100 px)
- Full color picker for the bars (or theme default)
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
- Customizable placeholder icon shown when a track has no album art
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
- Optional on-widget playback controls — **Previous / Play-Pause / Next**, each individually toggleable, with configurable icon size
- Optional read-only **progress bar** with configurable height and color
- Fully arrangeable extras: position them **left / right / above / below** the track, lay the buttons out as a **row or a vertical stack**, and put the progress bar **above or below** the buttons
- Optionally **hide the widget entirely** when nothing is playing
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
1. Open the [KDE Store page](https://store.kde.org/p/2350283) and download the `.plasmoid` file, **or**
2. Right-click your panel → **Add or Manage Widgets** → **Get New Widgets** → **Download New Plasma Widgets** → search for **Media Player Improved**

Then install it with:
```bash
kpackagetool6 --install MediaPlayerImproved.plasmoid --type Plasma/Applet
```

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
| Hide when idle | Disabled | Hide the widget entirely when nothing is playing |
| No-artwork icon | `applications-multimedia` | Icon shown when a track has no album art |

### Compact Representation
| Setting | Default | Description |
|---------|---------|-------------|
| Maximum width | 20 | Max widget width in grid units (5–100) |
| Scrolling text | Enabled | Marquee animation for long text |
| Scroll speed | 50 px/s | Text scroll speed (10–200) |
| Playback controls | Disabled | Show Previous / Play-Pause / Next buttons |
| Previous / Play-Pause / Next | Enabled | Toggle each button individually |
| Button icon size | 22 px | Control button icon size (12–64) |
| Progress bar | Disabled | Show a read-only track progress bar |
| Progress bar height | 6 px | Progress bar thickness (2–24) |
| Progress bar color | Theme default | Full color picker or theme default |
| Controls position | Automatic | Auto / Left / Right / Above / Below the track |
| Button layout | Horizontal | Buttons in a row or a vertical stack |
| Block order | Progress above | Progress bar above or below the controls |

### Audio Visualizer
| Setting | Default | Description |
|---------|---------|-------------|
| Enable visualizer | Enabled | Master on/off toggle |
| Show in compact view | Enabled | Visualizer in the panel widget |
| Position (compact) | Bottom | Bottom / Left / Right / Behind |
| Show in expanded view | Enabled | Visualizer in the popup |
| Height | 30 px | Bar height in pixels (10–100) |
| Number of bars | 20 | Bar count (5–50) |
| Bar color | Theme default | Full color picker or theme default |
| Behind opacity | 0.3 | Opacity when using "Behind" position (0.1–1.0) |

---

## License

GPL-2.0-or-later — see [https://www.gnu.org/licenses/old-licenses/gpl-2.0.html](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)

---

## Credits

Based on the default KDE Plasma media player widget.
Author: [Yuriy Rusanov](https://github.com/Qehbr)