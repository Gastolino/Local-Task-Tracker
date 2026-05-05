"""
macOS-specific helpers.

All subprocess calls have short timeouts so a frozen osascript or ioreg
never stalls the polling loop for more than a few seconds.
"""

import re
import subprocess

# AppleScript that returns "AppName|WindowTitle" (window title may be empty).
_ACTIVE_APP_SCRIPT = """\
tell application "System Events"
    set frontApp to first application process whose frontmost is true
    set appName to name of frontApp
    set winTitle to ""
    try
        set winTitle to name of first window of frontApp
    end try
    return appName & "|" & winTitle
end tell
"""


def get_idle_seconds() -> float:
    """Seconds since the last keyboard or mouse event, via IOKit."""
    try:
        result = subprocess.run(
            ["ioreg", "-c", "IOHIDSystem"],
            capture_output=True,
            text=True,
            timeout=3,
        )
        m = re.search(r'"HIDIdleTime"\s*=\s*(\d+)', result.stdout)
        if m:
            return int(m.group(1)) / 1_000_000_000  # nanoseconds → seconds
    except Exception:
        pass
    return 0.0


def get_active_app() -> tuple[str, str]:
    """
    Return (app_name, window_title).

    Requires Accessibility permission for the calling process.  Falls back to
    empty strings rather than raising so the daemon keeps running even if the
    user has not yet granted permission.
    """
    try:
        result = subprocess.run(
            ["osascript", "-e", _ACTIVE_APP_SCRIPT],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            raw = result.stdout.strip()
            parts = raw.split("|", 1)
            app_name = parts[0].strip()
            window_title = parts[1].strip() if len(parts) > 1 else ""
            return app_name, window_title
    except Exception:
        pass
    return "", ""
