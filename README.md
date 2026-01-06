# waybar-syncthing-toggle

A feature-rich Waybar module to manage Syncthing with visual sync status, error detection, and quick actions.

## Features

- **Toggle service** on/off with a single click
- **Real-time sync progress** indicator with percentage display
- **Connection status** showing number of connected devices
- **Error detection** with visual alerts (red blinking icon)
- **Sync animation** when files are being transferred
- **Quick actions**:
  - Left-click: Start/stop Syncthing
  - Middle-click: Open Web UI in browser
  - Right-click: Force rescan all folders
- **Desktop notifications** on state changes
- **Catppuccin-themed** colors (easily customizable)

## Requirements

- Waybar
- Syncthing (running as a user service: `syncthing.service`)
- `libnotify` (for notifications)
- `curl` (for API queries)
- `bc` (for percentage calculations, optional)

## Installation

```bash
./install.sh
omarchy-restart-waybar
```

## Uninstallation

```bash
./uninstall.sh
omarchy-restart-waybar
```

## Usage

### Mouse Actions
| Action | Result |
|--------|--------|
| Left-click | Toggle Syncthing service on/off |
| Middle-click | Open Syncthing Web UI |
| Right-click | Force rescan all folders |

### Status Icons
| Icon | Color | Meaning |
|------|-------|---------|
| 󰓦 | Green | Syncthing running, in sync |
| 󰓦 | Blue (pulsing) | Actively syncing with progress % |
| 󰓨 | Red (blinking) | Errors detected |
| 󰓨 | Gray (dimmed) | Syncthing stopped |

### Instant Update
Send signal 9 to immediately update the module:
```bash
pkill -SIGRTMIN+9 waybar
```

## What gets installed

- `~/.config/waybar/scripts/waybar-syncthing-toggle.sh` - main script
- `~/.config/waybar/waybar-syncthing-toggle.jsonc` - module config
- `~/.config/waybar/waybar-syncthing-toggle.css` - styles with animations

Config edits (automatically managed):
- Adds to existing `"include": [...]` array
- Inserts `"custom/syncthing"` after `"group/tray-expander"` in `modules-right`
- Adds `@import "waybar-syncthing-toggle.css";` to `style.css`

## Requirements for install

Your waybar config must have:
- An existing `"include": [` array
- `"group/tray-expander",` in `modules-right`

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `WAYBAR_CONFIG_DIR` | `~/.config/waybar` | Waybar config directory |
| `SYNCTHING_API_KEY` | (auto-detected) | Syncthing REST API key |
| `SYNCTHING_URL` | `http://127.0.0.1:8384` | Syncthing API URL |
| `SYNCTHING_NOTIFY` | `true` | Enable/disable notifications |

### Examples

```bash
# Custom waybar config location
WAYBAR_CONFIG_DIR=/path/to/waybar ./install.sh

# Custom Syncthing URL (for remote instance)
export SYNCTHING_URL="http://192.168.1.100:8384"

# Disable notifications
export SYNCTHING_NOTIFY=false
```

### Customizing Colors

Edit the CSS file to match your theme. Current defaults use Catppuccin Mocha:
- Active: `#a6e3a1` (green)
- Syncing: `#89b4fa` (blue)
- Error: `#f38ba8` (red)
- Stopped: `#6c7086` (overlay)

## Troubleshooting

**API features not working?**
- The script auto-detects the API key from `~/.config/syncthing/config.xml` or `~/.local/state/syncthing/config.xml`
- You can manually set `SYNCTHING_API_KEY` if auto-detection fails

**Slow updates?**
- Default interval is 3 seconds; edit the jsonc file to adjust
- Use `pkill -SIGRTMIN+9 waybar` to force immediate refresh

## License

MIT
