"""
CLI report generator.

Each row in the activity table represents one POLL_INTERVAL-second window.
Total time = row_count * POLL_INTERVAL.  We read POLL_INTERVAL from config
so the arithmetic is always correct even if someone changes the constant.
"""

from datetime import date, timedelta

from .config import POLL_INTERVAL
from .db import query

_SEP = "─" * 60


def _fmt(seconds: float) -> str:
    s = int(seconds)
    h, rem = divmod(s, 3600)
    m, sec = divmod(rem, 60)
    if h:
        return f"{h}h {m:02d}m"
    if m:
        return f"{m}m {sec:02d}s"
    return f"{sec}s"


def report_day(target: date | None = None) -> None:
    target = target or date.today()
    prefix = target.isoformat()

    total = _count(f"SELECT COUNT(*) FROM activity WHERE ts LIKE '{prefix}%'")
    active = _count(
        f"SELECT COUNT(*) FROM activity WHERE ts LIKE '{prefix}%' AND is_idle=0"
    )
    idle = total - active

    rows = query(
        """
        SELECT app_name, COUNT(*) AS polls
        FROM   activity
        WHERE  ts LIKE ? AND is_idle=0 AND app_name IS NOT NULL
        GROUP  BY app_name
        ORDER  BY polls DESC
        """,
        (f"{prefix}%",),
    )

    print(f"\n{_SEP}")
    print(f"  {target.strftime('%A, %d %B %Y')}")
    print(_SEP)
    print(f"  Tracked  {_fmt(total * POLL_INTERVAL):<12}"
          f"  Active {_fmt(active * POLL_INTERVAL):<12}"
          f"  Idle {_fmt(idle * POLL_INTERVAL)}")

    if rows:
        print(f"\n  {'Application':<38} {'Time':>8}")
        print(f"  {'─'*38} {'─'*8}")
        for row in rows:
            name = (row["app_name"] or "Unknown")[:38]
            dur = _fmt(row["polls"] * POLL_INTERVAL)
            print(f"  {name:<38} {dur:>8}")

    print()


def report_week(end: date | None = None) -> None:
    end = end or date.today()
    start = end - timedelta(days=6)
    print(f"\n{'═'*60}")
    print(f"  Weekly summary  {start}  →  {end}")
    print(f"{'═'*60}")
    for i in range(7):
        report_day(start + timedelta(days=i))


def _count(sql: str) -> int:
    rows = query(sql)
    return rows[0][0] if rows else 0
