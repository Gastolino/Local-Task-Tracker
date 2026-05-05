import os
from pathlib import Path

# How often to poll for the active application (seconds).
POLL_INTERVAL = 5

# Seconds of no keyboard/mouse input before a stretch is marked as idle.
IDLE_THRESHOLD = 120

# Take a screenshot at most once every N seconds (decoupled from poll rate).
SCREENSHOT_INTERVAL = 30

# Maximum width or height of captured screenshots in pixels.
SCREENSHOT_MAX_DIM = 480

# JPEG quality for screenshots (0-100; lower = smaller files).
SCREENSHOT_QUALITY = 30

# Root data directory — sits inside ~/Library/Application Support so it is
# included in Time Machine backups but excluded from iCloud sync.
DATA_DIR = Path(os.path.expanduser(
    "~/Library/Application Support/LocalTaskTracker"
))

DB_PATH = DATA_DIR / "tracker.db"
SCREENSHOTS_DIR = DATA_DIR / "screenshots"
LOG_PATH = DATA_DIR / "tracker.log"
