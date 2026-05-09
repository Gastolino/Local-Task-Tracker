import Foundation
import SQLite3

/// Reads from the SQLite database written by the Python daemon.
/// The Swift app also writes to the `screenshots` table.
/// Project/session/note tables are created here so they exist before
/// ProjectService opens its own connection.
final class DatabaseService {

    static let shared = DatabaseService()
    private init() { open() }

    private var db: OpaquePointer?

    // MARK: - Connection

    private func open() {
        guard sqlite3_open(AppPaths.dbPath, &db) == SQLITE_OK else { return }
        sqlite3_exec(db, "PRAGMA journal_mode=WAL",   nil, nil, nil)
        sqlite3_exec(db, "PRAGMA synchronous=NORMAL", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA foreign_keys=ON",    nil, nil, nil)
        createTablesIfNeeded()
    }

    private func createTablesIfNeeded() {
        sqlite3_exec(db, """
            CREATE TABLE IF NOT EXISTS screenshots (
                id   INTEGER PRIMARY KEY AUTOINCREMENT,
                ts   TEXT NOT NULL,
                path TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_screenshot_ts ON screenshots(ts);

            CREATE TABLE IF NOT EXISTS projects (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                name        TEXT    NOT NULL,
                color       TEXT    NOT NULL DEFAULT '#5856D6',
                description TEXT,
                created_at  TEXT    NOT NULL,
                archived    INTEGER NOT NULL DEFAULT 0
            );

            CREATE TABLE IF NOT EXISTS sessions (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id  INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                label       TEXT,
                started_at  TEXT    NOT NULL,
                ended_at    TEXT,
                notes       TEXT,
                created_at  TEXT    NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_sessions_project ON sessions(project_id);
            CREATE INDEX IF NOT EXISTS idx_sessions_started ON sessions(started_at);

            CREATE TABLE IF NOT EXISTS project_notes (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id  INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
                content     TEXT    NOT NULL,
                created_at  TEXT    NOT NULL,
                updated_at  TEXT    NOT NULL
            );
            CREATE INDEX IF NOT EXISTS idx_notes_project ON project_notes(project_id);
            """,
            nil, nil, nil
        )
    }

    deinit { sqlite3_close(db) }

    // MARK: - Activity queries

    func activities(for date: Date) -> [ActivityRecord] {
        let key = localDateKey(date)
        return queryActivities(
            "SELECT id,ts,app_name,window_title,idle_secs,is_idle,screenshot_path " +
            "FROM activity WHERE date(ts,'localtime')='\(key)' ORDER BY ts"
        )
    }

    func monthActivities(year: Int, month: Int) -> [DayActivity] {
        let y = String(format: "%04d", year)
        let m = String(format: "%02d", month)
        let sql = """
            SELECT
                date(ts,'localtime') AS day,
                SUM(CASE WHEN is_idle=0 THEN 1 ELSE 0 END) AS active,
                SUM(CASE WHEN is_idle=1 THEN 1 ELSE 0 END) AS idle,
                GROUP_CONCAT(DISTINCT app_name)             AS apps
            FROM activity
            WHERE strftime('%Y',ts,'localtime')='\(y)'
              AND strftime('%m',ts,'localtime')='\(m)'
            GROUP BY day
            ORDER BY day
            """
        var results: [DayActivity] = []
        withStatement(sql) { stmt in
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            fmt.timeZone = .current
            while sqlite3_step(stmt) == SQLITE_ROW {
                guard let day = string(stmt, 0) else { continue }
                let active     = Int(sqlite3_column_int64(stmt, 1))
                let idle       = Int(sqlite3_column_int64(stmt, 2))
                let appsRaw    = string(stmt, 3) ?? ""
                guard let date = fmt.date(from: day) else { continue }
                let apps = appsRaw.split(separator: ",")
                    .map(String.init).filter { !$0.isEmpty }.prefix(3)
                results.append(DayActivity(
                    id: day, date: date,
                    activePolls: active, idlePolls: idle,
                    topApps: Array(apps)
                ))
            }
        }
        return results
    }

    func screenshots(for date: Date) -> [ScreenshotRecord] {
        let key = localDateKey(date)
        let sql = "SELECT id,ts,path FROM screenshots " +
                  "WHERE date(ts,'localtime')='\(key)' ORDER BY ts"
        var results: [ScreenshotRecord] = []
        withStatement(sql) { stmt in
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(ScreenshotRecord(
                    id:   Int(sqlite3_column_int64(stmt, 0)),
                    ts:   isoDate(string(stmt, 1) ?? "") ?? Date(),
                    path: string(stmt, 2) ?? ""
                ))
            }
        }
        return results
    }

    func pendingLaunchEvents() -> [(id: Int, appName: String)] {
        let sql = "SELECT id,app_name FROM app_launch_events WHERE prompted=0 ORDER BY ts"
        var results: [(Int, String)] = []
        withStatement(sql) { stmt in
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append((Int(sqlite3_column_int64(stmt, 0)), string(stmt, 1) ?? ""))
            }
        }
        return results
    }

    func markLaunchEventPrompted(_ id: Int) {
        withStatement("UPDATE app_launch_events SET prompted=1 WHERE id=\(id)") { stmt in
            sqlite3_step(stmt)
        }
    }

    func todaySummary() -> (activeSeconds: TimeInterval, appCount: Int) {
        let key = localDateKey(Date())
        let sql = """
            SELECT
                SUM(CASE WHEN is_idle=0 THEN 1 ELSE 0 END),
                COUNT(DISTINCT CASE WHEN is_idle=0 THEN app_name END)
            FROM activity WHERE date(ts,'localtime')='\(key)'
            """
        var active = 0; var count = 0
        withStatement(sql) { stmt in
            if sqlite3_step(stmt) == SQLITE_ROW {
                active = Int(sqlite3_column_int64(stmt, 0))
                count  = Int(sqlite3_column_int64(stmt, 1))
            }
        }
        return (Double(active) * 5, count)
    }

    // MARK: - Screenshot writes

    func insertScreenshot(ts: Date, path: String) {
        let tsStr = isoFormatter.string(from: ts)
        withStatement(
            "INSERT INTO screenshots (ts,path) VALUES ('\(tsStr)','\(path)')"
        ) { stmt in sqlite3_step(stmt) }
    }

    // MARK: - Helpers

    private func queryActivities(_ sql: String) -> [ActivityRecord] {
        var results: [ActivityRecord] = []
        withStatement(sql) { stmt in
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(ActivityRecord(
                    id:             Int(sqlite3_column_int64(stmt, 0)),
                    ts:             isoDate(string(stmt, 1) ?? "") ?? Date(),
                    appName:        string(stmt, 2),
                    windowTitle:    string(stmt, 3),
                    idleSecs:       sqlite3_column_double(stmt, 4),
                    isIdle:         sqlite3_column_int64(stmt, 5) != 0,
                    screenshotPath: string(stmt, 6)
                ))
            }
        }
        return results
    }

    private func withStatement(_ sql: String, block: (OpaquePointer?) -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        block(stmt)
    }

    private func string(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        sqlite3_column_text(stmt, col).map { String(cString: $0) }
    }

    private func localDateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.string(from: date)
    }

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func isoDate(_ s: String) -> Date? {
        isoFormatter.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }
}
