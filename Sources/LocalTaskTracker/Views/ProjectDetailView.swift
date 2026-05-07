import SwiftUI

/// Detail view for a single project: stats header, sessions list, project notes.
struct ProjectDetailView: View {

    var project: Project
    var onProjectUpdated: (Project) -> Void

    @State private var sessions:    [Session]     = []
    @State private var notes:       [ProjectNote] = []
    @State private var stats:       ProjectStats  = .init(totalSeconds: 0, thisWeekSeconds: 0, todaySeconds: 0, sessionCount: 0)
    @State private var showSession  = false
    @State private var editSession: Session?
    @State private var newNote      = ""
    @State private var editNote:    ProjectNote?
    @State private var editProject  = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                statsHeader
                sessionsSection
                notesSection
            }
            .padding(24)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Edit") { editProject = true }
            }
        }
        .sheet(isPresented: $showSession, onDismiss: reload) {
            SessionEditorView(preselectedProjectID: project.id) { _ in reload() }
        }
        .sheet(item: $editSession, onDismiss: reload) { session in
            SessionEditorView(existing: session) { _ in reload() }
        }
        .sheet(isPresented: $editProject, onDismiss: reload) {
            EditProjectView(project: project, onSaved: { updated in
                onProjectUpdated(updated)
            })
        }
        .onAppear { reload() }
    }

    // MARK: - Stats header

    private var statsHeader: some View {
        HStack(spacing: 0) {
            statCell("Total", fmt(stats.totalSeconds))
            Divider().frame(height: 40)
            statCell("This week", fmt(stats.thisWeekSeconds))
            Divider().frame(height: 40)
            statCell("Today", fmt(stats.todaySeconds))
            Divider().frame(height: 40)
            statCell("Sessions", "\(stats.sessionCount)")
        }
        .padding(16)
        .background(Color(hex: project.color).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: project.color).opacity(0.2)))
    }

    private func statCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sessions").font(.headline)
                Spacer()
                Button {
                    showSession = true
                } label: {
                    Label("New Session", systemImage: "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }

            if sessions.isEmpty {
                Text("No sessions yet. Add one to start tracking time for this project.")
                    .font(.callout).foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(sessions) { session in
                    SessionRow(session: session,
                               onEdit: { editSession = session },
                               onDelete: { deleteSession(session) })
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes").font(.headline)

            // Inline new-note composer
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $newNote)
                    .font(.body)
                    .frame(minHeight: 60)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.25)))
                HStack {
                    Spacer()
                    Button("Add Note") { addNote() }
                        .buttonStyle(.borderedProminent)
                        .disabled(newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            ForEach(notes) { note in
                NoteRow(note: note,
                        onSave: { updated in
                            ProjectService.shared.updateNote(updated)
                            reload()
                        },
                        onDelete: {
                            ProjectService.shared.deleteNote(note.id)
                            reload()
                        })
            }
        }
    }

    // MARK: - Actions

    private func reload() {
        sessions = ProjectService.shared.sessions(forProject: project.id)
        notes    = ProjectService.shared.notes(forProject: project.id)
        stats    = ProjectService.shared.stats(forProject: project.id)
    }

    private func addNote() {
        let trimmed = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ProjectService.shared.addNote(content: trimmed, projectID: project.id)
        newNote = ""
        reload()
    }

    private func deleteSession(_ session: Session) {
        ProjectService.shared.deleteSession(session.id)
        reload()
    }

    private func fmt(_ s: TimeInterval) -> String {
        let t = Int(s); let h = t / 3600; let m = (t % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        return "\(m)m"
    }
}

// MARK: - SessionRow

struct SessionRow: View {
    let session: Session
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Date column
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.startedAt, format: .dateTime.month(.abbreviated).day())
                    .font(.caption.weight(.semibold))
                Text(session.startedAt, format: .dateTime.hour().minute())
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 52)

            // Duration bar
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: session.projectColor))
                .frame(width: 4)
                .frame(height: max(28, min(CGFloat(session.duration / 60) * 0.8, 80)))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                if let lbl = session.label, !lbl.isEmpty {
                    Text(lbl).font(.subheadline.weight(.medium))
                }
                HStack(spacing: 6) {
                    Text(fmtDuration(session.duration))
                        .font(.caption).foregroundStyle(.secondary)
                    if session.isActive {
                        Text("Active")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(.green.opacity(0.12), in: Capsule())
                    }
                }
                if let notes = session.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 4) {
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered).controlSize(.small)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }

    private func fmtDuration(_ s: TimeInterval) -> String {
        let t = Int(s); let h = t / 3600; let m = (t % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        return "\(m)m"
    }
}

// MARK: - NoteRow

struct NoteRow: View {
    let note: ProjectNote
    let onSave: (ProjectNote) -> Void
    let onDelete: () -> Void

    @State private var editing = false
    @State private var draft   = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if editing {
                TextEditor(text: $draft)
                    .font(.body)
                    .frame(minHeight: 60)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.4)))
                HStack {
                    Button("Cancel") { editing = false }
                        .buttonStyle(.bordered).controlSize(.small)
                    Spacer()
                    Button("Save") {
                        var updated = note
                        updated.content = draft
                        onSave(updated)
                        editing = false
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                }
            } else {
                HStack(alignment: .top, spacing: 8) {
                    Text(note.content)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 4) {
                        Button { draft = note.content; editing = true } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless).controlSize(.small)

                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless).controlSize(.small)
                    }
                }
                Text(note.updatedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - EditProjectView

struct EditProjectView: View {
    var project: Project
    var onSaved: (Project) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var name        = ""
    @State private var description = ""
    @State private var color       = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Edit Project").font(.title2.bold())

            TextField("Project name", text: $name).textFieldStyle(.roundedBorder)

            TextField("Description (optional)", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder).lineLimit(3, reservesSpace: true)

            HStack(spacing: 10) {
                ForEach(Project.presetColors, id: \.self) { hex in
                    Circle().fill(Color(hex: hex)).frame(width: 26, height: 26)
                        .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                        .overlay(
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .opacity(color == hex ? 1 : 0)
                        )
                        .onTapGesture { color = hex }
                }
            }

            Spacer()
            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.escape)
                Spacer()
                Button("Save") {
                    var updated = project
                    updated.name        = name
                    updated.color       = color
                    updated.description = description.isEmpty ? nil : description
                    ProjectService.shared.updateProject(updated)
                    onSaved(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(28)
        .frame(width: 380, height: 320)
        .onAppear {
            name        = project.name
            description = project.description ?? ""
            color       = project.color
        }
    }
}
