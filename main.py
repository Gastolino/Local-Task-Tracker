#!/usr/bin/env python3
"""
Local Task Tracker — macOS activity tracking daemon.

Commands
--------
  start                   Start the tracker (runs in foreground).
  report                  Show today's app-usage summary.
  report --date YYYY-MM-DD
  report --week           Show the last 7 days.

The tracker requires two macOS permissions granted to whichever terminal
emulator (or Python binary) is used to run it:
  • Accessibility     — to read the active application name and window title
  • Screen Recording  — to capture screenshots

Grant them in System Settings → Privacy & Security.
"""

import logging
import sys
from pathlib import Path

# Ensure the repo root is on sys.path so "tracker" resolves as a package
# regardless of how the script is invoked.
sys.path.insert(0, str(Path(__file__).resolve().parent))


def _setup_logging() -> None:
    from tracker.config import DATA_DIR, LOG_PATH

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s  %(levelname)-7s  %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
        handlers=[
            logging.FileHandler(LOG_PATH),
            logging.StreamHandler(sys.stderr),
        ],
    )


def cmd_start() -> None:
    _setup_logging()
    from tracker.daemon import run
    run()


def cmd_report(args: list[str]) -> None:
    from tracker.report import report_day, report_week
    from datetime import date

    if "--week" in args:
        report_week()
        return

    if "--date" in args:
        idx = args.index("--date")
        try:
            target = date.fromisoformat(args[idx + 1])
        except (IndexError, ValueError) as exc:
            sys.exit(f"Invalid --date value: {exc}")
        report_day(target)
        return

    report_day()


def main() -> None:
    argv = sys.argv[1:]

    if not argv or argv[0] == "start":
        cmd_start()
    elif argv[0] == "report":
        cmd_report(argv[1:])
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
