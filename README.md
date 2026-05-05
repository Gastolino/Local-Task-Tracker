# Local Task Tracker

Lightweight macOS daemon that tracks which applications you use and for how
long — no cloud, no subscription, just a local SQLite database and low-res
screenshots.

Built for freelancers who want accurate time records without manually starting
and stopping timers.

---

## How it works

Every **5 seconds** the tracker:

1. Reads the idle time from IOKit — if you haven't touched the keyboard or
   mouse for 2 minutes the interval is logged as _idle_ and skipped.
2. Asks System Events (via `osascript`) for the frontmost application name
   and window title.
3. Every **30 seconds** (not every poll) it captures a low-res JPEG screenshot
   using `screencapture` + `sips` — no third-party libraries.
4. Writes one row to a local SQLite database with WAL mode, so data is safe
   even if you close the lid mid-session.

All data lives in `~/Library/Application Support/LocalTaskTracker/`.

---

## Requirements

| Requirement | Notes |
|---|---|
| macOS 12 Monterey or later | Uses `screencapture`, `sips`, `ioreg`, `osascript` |
| Python 3.10 or later | Standard library only — no `pip install` needed |

---

## Installation

```bash
git clone https://github.com/gastolino/local-task-tracker.git
cd local-task-tracker
bash scripts/install.sh
```

The install script:
- Locates your `python3` binary
- Fills in the LaunchAgent plist with the correct paths
- Loads it so the tracker starts immediately and at every future login

### Permissions

macOS requires two Privacy permissions for whichever app runs the script
(usually **Terminal** or **iTerm2**).  Grant them in:

**System Settings → Privacy & Security**

| Permission | What it enables |
|---|---|
| **Accessibility** | Reading the active application name and window title |
| **Screen Recording** | Capturing screenshots |

On first run macOS will show a permission prompt automatically.

---

## Usage

### Reports

```bash
# Today
python3 main.py report

# Specific date
python3 main.py report --date 2025-05-01

# Last 7 days
python3 main.py report --week
```

Example output:

```
────────────────────────────────────────────────────────────
  Monday, 05 May 2025
────────────────────────────────────────────────────────────
  Tracked  6h 10m       Active 5h 22m       Idle 48m

  Application                            Time
  ────────────────────────────────────── ────────
  Xcode                                  2h 14m
  Safari                                 1h 03m
  Figma                                  55m 30s
  Terminal                               42m 10s
  Slack                                  27m 45s
```

### Run manually (foreground)

```bash
python3 main.py start
```

Press `Ctrl-C` to stop cleanly.

### Uninstall

```bash
bash scripts/uninstall.sh
```

Your data is kept — delete `~/Library/Application Support/LocalTaskTracker/`
manually if you no longer need it.

---

## Configuration

Edit `tracker/config.py` and then restart the agent
(`bash scripts/uninstall.sh && bash scripts/install.sh`).

| Setting | Default | Description |
|---|---|---|
| `POLL_INTERVAL` | `5` s | How often to check the active app |
| `IDLE_THRESHOLD` | `120` s | No input for this long → logged as idle |
| `SCREENSHOT_INTERVAL` | `30` s | Minimum gap between screenshots |
| `SCREENSHOT_MAX_DIM` | `480` px | Longest edge of saved screenshots |
| `SCREENSHOT_QUALITY` | `30` | JPEG quality (0–100; lower = smaller) |

At the defaults a full 8-hour workday produces roughly **30–50 MB** of
screenshots and a few KB of database.

---

## Data layout

```
~/Library/Application Support/LocalTaskTracker/
├── tracker.db          SQLite database (WAL mode)
├── tracker.log         Daemon log
└── screenshots/
    └── YYYY-MM-DD/
        └── HH-MM-SS.jpg
```

### Database schema

```sql
CREATE TABLE activity (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ts              TEXT    NOT NULL,   -- ISO-8601 UTC timestamp
    app_name        TEXT,               -- NULL when idle
    window_title    TEXT,               -- NULL when idle or unavailable
    idle_secs       REAL    NOT NULL,
    is_idle         INTEGER NOT NULL,   -- 1 = idle, 0 = active
    screenshot_path TEXT                -- relative to LocalTaskTracker/, NULL when idle
);
```

You can query it directly with any SQLite tool:

```bash
sqlite3 ~/Library/Application\ Support/LocalTaskTracker/tracker.db \
  "SELECT app_name, COUNT(*)*5/60.0 AS minutes
   FROM activity
   WHERE date(ts)=date('now','localtime') AND is_idle=0
   GROUP BY app_name ORDER BY minutes DESC;"
```

---

## Privacy

All data stays on your machine.  No analytics, no network calls, no external
dependencies beyond what ships with macOS.
