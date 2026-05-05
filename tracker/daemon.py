"""
Main polling loop.

- One DB write per poll; WAL mode keeps it fast and crash-safe.
- Work-app launches are recorded so the Swift UI can prompt the user.
- Screenshots are disabled by default (the Swift UI handles them encrypted).
- Signal-safe shutdown so the last poll is always committed before exit.
"""

import logging
import signal
import time
from datetime import datetime, timezone

from .config import (
    IDLE_THRESHOLD,
    POLL_INTERVAL,
    SCREENSHOT_ENABLED,
    SCREENSHOT_INTERVAL,
    WORK_APPS,
)
from .db import init_db, insert_activity, insert_launch_event
from .macos import get_active_app, get_idle_seconds

logger = logging.getLogger(__name__)

_running = True
# Work apps seen since daemon start — prevents duplicate launch events per session.
_seen_work_apps: set[str] = set()


def _handle_signal(signum, _frame):
    global _running
    logger.info("Signal %d received — stopping after current poll", signum)
    _running = False


def run() -> None:
    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    init_db()
    logger.info(
        "Tracker started (poll=%ds, idle_threshold=%ds, screenshots=%s)",
        POLL_INTERVAL,
        IDLE_THRESHOLD,
        "on" if SCREENSHOT_ENABLED else "off (Swift UI)",
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

    # Detect work-app launches (once per session per app).
    if app_name and app_name not in _seen_work_apps and app_name in WORK_APPS:
        _seen_work_apps.add(app_name)
        insert_launch_event(ts_str, app_name)
        logger.info("Work app detected: %s", app_name)

    # Screenshots are handled by the Swift UI unless explicitly enabled.
    screenshot_path: str | None = None
    if SCREENSHOT_ENABLED:
        now_mono = time.monotonic()
        if now_mono - last_screenshot_ts >= SCREENSHOT_INTERVAL:
            from .screenshot import capture
            screenshot_path = capture(now)
            if screenshot_path:
                last_screenshot_ts = now_mono

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
