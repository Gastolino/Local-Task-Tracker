import SwiftUI

/// Projects overview: list of all projects with time summaries,
/// plus a navigation push to ProjectDetailView.
struct ProjectsView: View {

    @State private var projects:       [Project] = []
    @State private var selected:       Project?
    @State private var showNewProject  = false
    @State private var statsByID:      [Int: ProjectStats] = [:]

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let proj = selected {
                ProjectDetailView(project: proj) { updated in
                    if let idx = projects.firstIndex(where: { $0.id == updated.id }) {
                        projects[idx] = updated
                    }
                }
                .navigationTitle(proj.name)
            } else {
                emptyDetail
            }
        }
        .onAppear { reload() }
        .sheet(isPresented: $showNewProject, onDismiss: reload) {
            NewProjectView { project in
                projects.append(project)
                selected = project
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selected) {
            ForEach(projects) { project in
                ProjectRow(project: project, stats: statsByID[project.id])
                    .tag(project)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            ProjectService.shared.deleteProject(project.id)
                            reload()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showNewProject = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - Empty detail state

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 52))
                .foregroundStyle(.tertiary)
            Text("Select a project")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("New Project") { showNewProject = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func reload() {
        projects = ProjectService.shared.allProjects()
        statsByID = Dictionary(
            uniqueKeysWithValues: projects.map { ($0.id, ProjectService.shared.stats(forProject: $0.id)) }
        )
        // Keep selection valid after reload.
        if let sel = selected, !projects.contains(where: { $0.id == sel.id }) {
            selected = projects.first
        }
    }
}

// MARK: - ProjectRow

struct ProjectRow: View {
    let project: Project
    let stats: ProjectStats?

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: project.color))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let s = stats {
                    Text(summary(s))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let s = stats, s.todaySeconds > 0 {
                Text(fmt(s.todaySeconds))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func summary(_ s: ProjectStats) -> String {
        "\(s.sessionCount) session\(s.sessionCount == 1 ? "" : "s")  ·  \(fmt(s.totalSeconds)) total"
    }

    private func fmt(_ t: TimeInterval) -> String {
        let s = Int(t); let h = s / 3600; let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        return "\(m)m"
    }
}

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var val: UInt64 = 0
        Scanner(string: h).scanHexInt64(&val)
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >>  8) & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
