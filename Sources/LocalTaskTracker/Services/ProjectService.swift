import Foundation
import SQLite3

private let __SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// All project / session / note CRUD and time-stat queries.
/// Opens its own WAL-mode connection to the shared DB — safe alongside
/// DatabaseService because SQLite WAL allows concurrent readers.
final class ProjectService {

    static let shared = ProjectService()
    private init() { open() }

    private var db: OpaquePointer?

    // MARK: - Schema

    private static let schema = """
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
        CREATE INDEX IF NOT EXISTS idx_sessions_project  ON sessions(project_id);
        CREATE INDEX IF NOT EXISTS idx_sessions_started  ON sessions(started_at);

        CREATE TABLE IF NOT EXISTS project_notes (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id  INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
            content     TEXT    NOT NULL,
            created_at  TEXT    NOT NULL,
            updated_at  TEXT    NOT NULL
        );
        CREATE INDEX IF NOT EXISTS idx_notes_project ON project_notes(project_id);
        """

    // MARK: - Connection

    private func open() {
        guard sqlite3_open(AppPaths.dbPath, &db) == SQLITE_OK else { return }
        exec("PRAGMA journal_mode=WAL")
        exec("PRAGMA synchronous=NORMAL")
        exec("PRAGMA foreign_keys=ON")
        exec(Self.schema)
    }

    deinit { sqlite3_close(db) }

    // MARK: - Projects

    func allProjects(includeArchived: Bool = false) -> [Project] {
        let filter = includeArchived ? "" : "WHERE archived=0"
        let sql = "SELECT id,name,color,description,created_at,archived " +
                  "FROM projects \(filter) ORDER BY name COLLATE NOCASE"
        var results: [Project] = []
        withStatement(sql) { stmt in
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(projectFromRow(stmt))
            }
        }
        return results
    }

    @discardableResult
    func createProject(name: String, color: String, description: String?) -> Project? {
        let now = iso(Date())
        let sql = "INSERT INTO projects (name,color,description,created_at) VALUES (?,?,?,?)"
        guard exec(sql, name, color, description ?? NSNull(), now),
              let id = lastInsertID()
        else { return nil }
        return Project(
            id: Int(id), name: name, color: color,
            description: description, createdAt: Date(), isArchived: false
        )
    }

    func updateProject(_ project: Project) {
        exec(
            "UPDATE projects SET name=?,color=?,description=?,archived=? WHERE id=?",
            project.name, project.color,
            project.description ?? NSNull(),
            project.isArchived ? 1 : 0,
            project.id
        )
    }

    func deleteProject(_ id: Int) {
        exec("DELETE FROM projects WHERE id=?", id)
    }

    // MARK: - Sessions

    func sessions(forProject projectID: Int) -> [Session] {
        let sql = """
            SELECT s.id, s.project_id, p.name, p.color,
                   s.label, s.started_at, s.ended_at, s.notes, s.created_at
            FROM sessions s JOIN projects p ON p.id=s.project_id
            WHERE s.project_id=?
            ORDER BY s.started_at DESC
            """
        return querySessions(sql, projectID)
    }

    func sessions(forDate date: Date) -> [Session] {
        let key = localDate(date)
        let sql = """
            SELECT s.id, s.project_id, p.name, p.color,
                   s.label, s.started_at, s.ended_at, s.notes, s.created_at
            FROM sessions s JOIN projects p ON p.id=s.project_id
            WHERE date(s.started_at,'localtime')='\(key)'
               OR date(s.ended_at,'localtime')='\(key)'
               OR (s.started_at <= datetime('\(key)','23:59:59')
                   AND (s.ended_at IS NULL OR s.ended_at >= datetime('\(key)')))
            ORDER BY s.started_at
            """
        return querySessions(sql)
    }

    @discardableResult
    func createSession(
        projectID: Int,
        label: String?,
        startedAt: Date,
        endedAt: Date?,
        notes: String?
    ) -> Session? {
        let now = iso(Date())
        let sql = """
            INSERT INTO sessions (project_id,label,started_at,ended_at,notes,created_at)
            VALUES (?,?,?,?,?,?)
            """
        guard exec(sql,
                   projectID,
                   label ?? NSNull(),
                   iso(startedAt),
                   endedAt.map { iso($0) } ?? NSNull(),
                   notes ?? NSNull(),
                   now),
              let id = lastInsertID()
        else { return nil }

        // Fetch the joined row so we have the project name/color.
        let rows = querySessions(
            "SELECT s.id,s.project_id,p.name,p.color,s.label,s.started_at,s.ended_at,s.notes,s.created_at " +
            "FROM sessions s JOIN projects p ON p.id=s.project_id WHERE s.id=\(id)"
        )
        return rows.first
    }

    func updateSession(_ session: Session) {
        exec(
            "UPDATE sessions SET label=?,started_at=?,ended_at=?,notes=? WHERE id=?",
            session.label ?? NSNull(),
            iso(session.startedAt),
            session.endedAt.map { iso($0) } ?? NSNull(),
            session.notes ?? NSNull(),
            session.id
        )
    }

    func endSession(id: Int) {
        exec("UPDATE sessions SET ended_at=? WHERE id=?", iso(Date()), id)
    }

    func deleteSession(_ id: Int) {
        exec("DELETE FROM sessions WHERE id=?", id)
    }

    // MARK: - Project notes

    func notes(forProject projectID: Int) -> [ProjectNote] {
        let sql = "SELECT id,project_id,content,created_at,updated_at " +
                  "FROM project_notes WHERE project_id=? ORDER BY updated_at DESC"
        var results: [ProjectNote] = []
        withStatement(sql, projectID) { stmt in
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(ProjectNote(
                    id:        Int(sqlite3_column_int64(stmt, 0)),
                    projectID: Int(sqlite3_column_int64(stmt, 1)),
                    content:   str(stmt, 2) ?? "",
                    createdAt: isoDate(str(stmt, 3) ?? "") ?? Date(),
                    updatedAt: isoDate(str(stmt, 4) ?? "") ?? Date()
                ))
            }
        }
        return results
    }

    @discardableResult
    func addNote(content: String, projectID: Int) -> ProjectNote? {
        let now = iso(Date())
        guard exec(
            "INSERT INTO project_notes (project_id,content,created_at,updated_at) VALUES (?,?,?,?)",
            projectID, content, now, now
        ), let id = lastInsertID() else { return nil }
        return ProjectNote(
            id: Int(id), projectID: projectID, content: content,
            createdAt: Date(), updatedAt: Date()
        )
    }

    func updateNote(_ note: ProjectNote) {
        exec(
            "UPDATE project_notes SET content=?,updated_at=? WHERE id=?",
            note.content, iso(Date()), note.id
        )
    }

    func deleteNote(_ id: Int) {
        exec("DELETE FROM project_notes WHERE id=?", id)
    }

    // MARK: - Stats

    func stats(forProject projectID: Int) -> ProjectStats {
        let weekStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        )!
        let todayStart = Calendar.current.startOfDay(for: Date())

        func sumSeconds(_ sql: String) -> TimeInterval {
            var t: Double = 0
            withStatement(sql, projectID) { stmt in
                if sqlite3_step(stmt) == SQLITE_ROW { t = sqlite3_column_double(stmt, 0) }
            }
            return t
        }

        let total = sumSeconds("""
            SELECT COALESCE(SUM(
                strftime('%s', COALESCE(ended_at, datetime('now'))) -
                strftime('%s', started_at)
            ), 0) FROM sessions WHERE project_id=? AND ended_at IS NOT NULL
            """)

        let week = sumSeconds("""
            SELECT COALESCE(SUM(
                strftime('%s', COALESCE(ended_at, datetime('now'))) -
                strftime('%s', started_at)
            ), 0) FROM sessions
            WHERE project_id=? AND started_at >= '\(iso(weekStart))'
            """)

        let today = sumSeconds("""
            SELECT COALESCE(SUM(
                strftime('%s', COALESCE(ended_at, datetime('now'))) -
                strftime('%s', started_at)
            ), 0) FROM sessions
            WHERE project_id=? AND started_at >= '\(iso(todayStart))'
            """)

        var count = 0
        withStatement("SELECT COUNT(*) FROM sessions WHERE project_id=?", projectID) { stmt in
            if sqlite3_step(stmt) == SQLITE_ROW { count = Int(sqlite3_column_int64(stmt, 0)) }
        }

        return ProjectStats(
            totalSeconds: total,
            thisWeekSeconds: week,
            todaySeconds: today,
            sessionCount: count
        )
    }

    // MARK: - Raw helpers

    @discardableResult
    private func exec(_ sql: String, _ args: Any?...) -> Bool {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        for (i, arg) in args.enumerated() {
            let col = Int32(i + 1)
            switch arg {
            case let s as String:   sqlite3_bind_text(stmt, col, s, -1, _SQLITE_TRANSIENT)
            case let n as Int:      sqlite3_bind_int64(stmt, col, Int64(n))
            case let d as Double:   sqlite3_bind_double(stmt, col, d)
            case is NSNull:         sqlite3_bind_null(stmt, col)
            default:                break
            }
        }
        return sqlite3_step(stmt) == SQLITE_DONE
    }

    private func withStatement(_ sql: String, _ arg: Any? = nil, block: (OpaquePointer?) -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        if let a = arg {
            switch a {
            case let n as Int: sqlite3_bind_int64(stmt, 1, Int64(n))
            case let s as String: sqlite3_bind_text(stmt, 1, s, -1, _SQLITE_TRANSIENT)
            default: break
            }
        }
        block(stmt)
    }

    private func lastInsertID() -> Int64? {
        let id = sqlite3_last_insert_rowid(db)
        return id > 0 ? id : nil
    }

    private func str(_ stmt: OpaquePointer?, _ col: Int32) -> String? {
        sqlite3_column_text(stmt, col).map { String(cString: $0) }
    }

    private func querySessions(_ sql: String, _ arg: Any? = nil) -> [Session] {
        var results: [Session] = []
        withStatement(sql, arg) { stmt in
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(Session(
                    id:           Int(sqlite3_column_int64(stmt, 0)),
                    projectID:    Int(sqlite3_column_int64(stmt, 1)),
                    projectName:  str(stmt, 2) ?? "",
                    projectColor: str(stmt, 3) ?? "#5856D6",
                    label:        str(stmt, 4),
                    startedAt:    isoDate(str(stmt, 5) ?? "") ?? Date(),
                    endedAt:      str(stmt, 6).flatMap { isoDate($0) },
                    notes:        str(stmt, 7),
                    createdAt:    isoDate(str(stmt, 8) ?? "") ?? Date()
                ))
            }
        }
        return results
    }

    private func projectFromRow(_ stmt: OpaquePointer?) -> Project {
        Project(
            id:          Int(sqlite3_column_int64(stmt, 0)),
            name:        str(stmt, 1) ?? "",
            color:       str(stmt, 2) ?? "#5856D6",
            description: str(stmt, 3),
            createdAt:   isoDate(str(stmt, 4) ?? "") ?? Date(),
            isArchived:  sqlite3_column_int64(stmt, 5) != 0
        )
    }

    // MARK: - Date helpers

    private let _iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func iso(_ d: Date) -> String { _iso.string(from: d) }

    private func isoDate(_ s: String) -> Date? {
        _iso.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    private func localDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current
        return f.string(from: date)
    }
}
