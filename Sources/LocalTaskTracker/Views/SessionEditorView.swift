import SwiftUI

/// Sheet for creating or editing a work session.
struct SessionEditorView: View {

    /// Pass an existing session to edit it, or nil to create a new one.
    var existing: Session?
    /// Pre-select a project when opening from a project's detail view.
    var preselectedProjectID: Int?
    /// Hints for the start/end times when creating a new session from the day detail.
    var startHint: Date?
    var endHint:   Date?
    var onSave: (Session) -> Void

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState

    @State private var projects:     [Project] = []
    @State private var projectIndex  = 0
    @State private var label         = ""
    @State private var startedAt     = Date().addingTimeInterval(-3600)
    @State private var endedAt       = Date()
    @State private var notes         = ""
    @State private var isActive      = false   // leave session open (no end time)
    @State private var error         = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {

            Text(existing == nil ? "New Session" : "Edit Session")
                .font(.title2.bold())

            // Project picker
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Project")
                if projects.isEmpty {
                    Text("No projects yet — create one in the Projects tab first.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Picker("Project", selection: $projectIndex) {
                        ForEach(projects.indices, id: \.self) { i in
                            HStack {
                                Circle()
                                    .fill(Color(hex: projects[i].color))
                                    .frame(width: 10, height: 10)
                                Text(projects[i].name)
                            }
                            .tag(i)
                        }
                    }
                    .labelsHidden()
                }
            }

            // Label
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Label (optional)")
                TextField("e.g. Design review, Bug fixing…", text: $label)
                    .textFieldStyle(.roundedBorder)
            }

            // Times
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Time")
                DatePicker("Start", selection: $startedAt)
                    .labelsHidden()
                if !isActive {
                    DatePicker("End", selection: $endedAt, in: startedAt...)
                        .labelsHidden()
                }
                Toggle("Still in progress", isOn: $isActive)
                    .font(.subheadline)
            }

            // Notes
            VStack(alignment: .leading, spacing: 6) {
                sectionLabel("Session notes (optional)")
                TextEditor(text: $notes)
                    .font(.body)
                    .frame(height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
            }

            if !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.escape)
                Spacer()
                Button(existing == nil ? "Save Session" : "Update Session") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(projects.isEmpty)
                    .keyboardShortcut(.return)
            }
        }
        .padding(28)
        .frame(width: 440, height: 500)
        .onAppear { populate() }
    }

    // MARK: - Setup

    private func populate() {
        projects = ProjectService.shared.allProjects()

        if let ex = existing {
            // Edit mode — fill from existing session.
            projectIndex = projects.firstIndex { $0.id == ex.projectID } ?? 0
            label        = ex.label ?? ""
            startedAt    = ex.startedAt
            endedAt      = ex.endedAt ?? Date()
            isActive     = ex.endedAt == nil
            notes        = ex.notes ?? ""
        } else {
            // Create mode — pre-select project if specified.
            if let pid = preselectedProjectID,
               let idx = projects.firstIndex(where: { $0.id == pid }) {
                projectIndex = idx
            }
            // Apply time hints from the calling view.
            if let s = startHint { startedAt = s }
            if let e = endHint   { endedAt   = e }
        }
    }

    // MARK: - Save

    private func save() {
        guard !projects.isEmpty else { return }
        let project = projects[projectIndex]

        if let ex = existing {
            var updated = ex
            updated.label     = label.isEmpty ? nil : label
            updated.startedAt = startedAt
            updated.endedAt   = isActive ? nil : endedAt
            updated.notes     = notes.isEmpty ? nil : notes
            ProjectService.shared.updateSession(updated)
            onSave(updated)
        } else {
            guard let session = ProjectService.shared.createSession(
                projectID: project.id,
                label:     label.isEmpty ? nil : label,
                startedAt: startedAt,
                endedAt:   isActive ? nil : endedAt,
                notes:     notes.isEmpty ? nil : notes
            ) else { error = "Failed to save session."; return }
            onSave(session)
        }
        dismiss()
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
    }
}
