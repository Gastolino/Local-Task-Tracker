import os
from pathlib import Path

# How often to poll for the active application (seconds).
POLL_INTERVAL = 5

# Seconds of no keyboard/mouse input before a stretch is marked as idle.
IDLE_THRESHOLD = 120

# Screenshot capture is handled by the Swift UI app (which encrypts them).
# Set to True only if running the Python daemon standalone without the Swift app.
SCREENSHOT_ENABLED = False

# Only used when SCREENSHOT_ENABLED = True.
SCREENSHOT_INTERVAL = 30
SCREENSHOT_MAX_DIM = 480
SCREENSHOT_QUALITY = 30

# Applications that trigger a "Are you working?" prompt in the Swift UI.
WORK_APPS: frozenset[str] = frozenset({
    "Microsoft PowerPoint",
    "Microsoft Word",
    "Microsoft Excel",
    "Microsoft Teams",
    "Adobe Photoshop 2025",
    "Adobe Photoshop 2024",
    "Adobe Photoshop",
    "Adobe Illustrator 2025",
    "Adobe Illustrator 2024",
    "Adobe Illustrator",
    "Adobe InDesign 2025",
    "Adobe InDesign 2024",
    "Adobe InDesign",
    "Adobe Premiere Pro 2025",
    "Adobe Premiere Pro 2024",
    "Adobe Premiere Pro",
    "Adobe After Effects 2025",
    "Adobe After Effects 2024",
    "Adobe After Effects",
    "Adobe Lightroom Classic",
    "Figma",
    "Sketch",
    "Keynote",
    "Pages",
    "Numbers",
    "Final Cut Pro",
    "Logic Pro",
    "Xcode",
    "Visual Studio Code",
    "DaVinci Resolve",
    "Blender",
    "Cinema 4D",
})

# Root data directory.
DATA_DIR = Path(os.path.expanduser(
    "~/Library/Application Support/LocalTaskTracker"
))

DB_PATH = DATA_DIR / "tracker.db"
SCREENSHOTS_DIR = DATA_DIR / "screenshots"
LOG_PATH = DATA_DIR / "tracker.log"
