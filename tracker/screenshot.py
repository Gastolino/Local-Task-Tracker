"""
Low-resource screenshot capture using only macOS built-ins.

screencapture → /tmp staging file
sips          → resize + re-compress in-place
shutil.move   → atomic rename to final path

No Python imaging library required.
"""

import shutil
import subprocess
import tempfile
from datetime import datetime
from pathlib import Path

from .config import SCREENSHOT_MAX_DIM, SCREENSHOT_QUALITY, SCREENSHOTS_DIR


def capture(ts: datetime) -> str | None:
    """
    Capture a screenshot and save it as a small JPEG.

    Returns a path string relative to SCREENSHOTS_DIR.parent (DATA_DIR) so it
    stays valid if DATA_DIR is ever moved, or None if anything fails.

    Requires Screen Recording permission for the calling process.
    """
    SCREENSHOTS_DIR.mkdir(parents=True, exist_ok=True)

    date_dir = SCREENSHOTS_DIR / ts.strftime("%Y-%m-%d")
    date_dir.mkdir(exist_ok=True)

    out_path = date_dir / ts.strftime("%H-%M-%S.jpg")

    tmp_fd, tmp_path = tempfile.mkstemp(suffix=".jpg")
    try:
        # -x  suppress the camera shutter sound
        # -t  output format
        subprocess.run(
            ["screencapture", "-x", "-t", "jpg", tmp_path],
            check=True,
            timeout=5,
            capture_output=True,
        )

        # Resize and recompress without any third-party library.
        # sips -Z <n>  scales so the longest edge is at most n pixels.
        # --setProperty formatOptions <q>  sets JPEG quality (0-100).
        subprocess.run(
            [
                "sips",
                "-Z", str(SCREENSHOT_MAX_DIM),
                "--setProperty", "formatOptions", str(SCREENSHOT_QUALITY),
                tmp_path,
            ],
            check=True,
            timeout=10,
            capture_output=True,
        )

        shutil.move(tmp_path, out_path)
        return str(out_path.relative_to(SCREENSHOTS_DIR.parent))

    except Exception:
        Path(tmp_path).unlink(missing_ok=True)
        return None
    finally:
        # The fd is already closed by screencapture writing to the path, but
        # close it defensively to avoid a leak on the error paths above.
        try:
            import os
            os.close(tmp_fd)
        except OSError:
            pass
