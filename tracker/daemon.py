"""
Main polling loop.

Design goals:
- One DB write per poll; WAL mode keeps it fast.
- Screenshots taken at SCREENSHOT_INTERVAL, not every poll, to save storage.
- Signal-safe shutdown so the last poll is always committed before exit.
- Elapsed-time correction keeps the real period close to POLL_INTERVAL even
  when osascript or screencapture take a moment.
"""

import logging
import signal
import time
from datetime import datetime, timezone

from .config import IDLE_THRESHOLD, POLL_INTERVAL, SCREENSHOT_INTERVAL
from .db import init_db, insert_activity
from .macos import get_active_app, get_idle_seconds
from .screenshot import capture

logger = logging.getLogger(__name__)

_running = True


def _handle_signal(signum, _frame):
    global _running
    logger.info("Signal %d received — stopping after current poll", signum)
    _running = False


def run() -> None:
    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    init_db()
    logger.info(
        "Tracker started (poll=%ds, screenshot every %ds, idle threshold=%ds)",
        POLL_INTERVAL,
        SCREENSHOT_INTERVAL,
        IDLE_THRESHOLD,
    )

    last_screenshot_ts: float = 0.0

    while _running:
        tick_start = time.monotonic()

        try:
            last_screenshot_ts = _poll(last_screenshot_ts)
        except Exception:
            logger.exception("Unhandled error in poll — continuing")

        elapsed = time.monotonic() - tick_start
        time.sleep(max(0.0, POLL_INTERVAL - elapsed))

    logger.info("Tracker stopped cleanly")


def _poll(last_screenshot_ts: float) -> float:
    now = datetime.now(timezone.utc)
    ts_str = now.isoformat()

    idle_secs = get_idle_seconds()
    is_idle = idle_secs >= IDLE_THRESHOLD

    if is_idle:
        insert_activity(ts_str, None, None, idle_secs, True, None)
        logger.debug("Idle (%.0fs)", idle_secs)
        return last_screenshot_ts

    app_name, window_title = get_active_app()

    screenshot_path: str | None = None
    now_mono = time.monotonic()
    if now_mono - last_screenshot_ts >= SCREENSHOT_INTERVAL:
        screenshot_path = capture(now)
        if screenshot_path:
            last_screenshot_ts = now_mono
            logger.debug("Screenshot → %s", screenshot_path)

    insert_activity(
        ts_str,
        app_name or None,
        window_title or None,
        idle_secs,
        False,
        screenshot_path,
    )
    logger.debug("Active: %s | %s", app_name, window_title)

    return last_screenshot_ts
