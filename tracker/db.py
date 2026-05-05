import sqlite3
import contextlib

from .config import DB_PATH

_SCHEMA = """
CREATE TABLE IF NOT EXISTS activity (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ts              TEXT    NOT NULL,
    app_name        TEXT,
    window_title    TEXT,
    idle_secs       REAL    NOT NULL DEFAULT 0,
    is_idle         INTEGER NOT NULL DEFAULT 0,
    screenshot_path TEXT
);
CREATE INDEX IF NOT EXISTS idx_activity_ts ON activity(ts);
"""


def init_db() -> None:
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    with _connect() as conn:
        conn.executescript(_SCHEMA)


@contextlib.contextmanager
def _connect():
    conn = sqlite3.connect(str(DB_PATH), timeout=10)
    conn.row_factory = sqlite3.Row
    # WAL mode: readers never block writers; safe across sudden sleep.
    conn.execute("PRAGMA journal_mode=WAL")
    # NORMAL: durable enough for sleep events without fsync on every write.
    conn.execute("PRAGMA synchronous=NORMAL")
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def insert_activity(
    ts: str,
    app_name: str | None,
    window_title: str | None,
    idle_secs: float,
    is_idle: bool,
    screenshot_path: str | None,
) -> None:
    with _connect() as conn:
        conn.execute(
            """
            INSERT INTO activity
                (ts, app_name, window_title, idle_secs, is_idle, screenshot_path)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (ts, app_name, window_title, idle_secs, int(is_idle), screenshot_path),
        )


def query(sql: str, params: tuple = ()) -> list[sqlite3.Row]:
    with _connect() as conn:
        return conn.execute(sql, params).fetchall()
