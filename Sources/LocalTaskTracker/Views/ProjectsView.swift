import SwiftUI

/// Projects overview: sidebar list + detail panel.
struct ProjectsView: View {

    @State private var projects:      [Project] = []
    @State private var selected:      Project?
    @State private var showNew        = false
    @State private var statsByID:     [Int: ProjectStats] = [:]
    @State private var editProject:   Project?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            if let proj = selected {
                ProjectDetailView(project: proj) { updated in
                    if let idx = projects.firstIndex(where: { $0.id == updated.id }) {
                        projects[idx] = updated
                        selected = updated
                    }
                }
                .navigationTitle(proj.name)
            } else {
                emptyDetail
            }
        }
        .onAppear { reload() }
        .sheet(isPresented: $showNew, onDismiss: reload) {
            NewProjectView { project in
                projects.append(project)
                selected = project
            }
        }
        .sheet(item: $editProject, onDismiss: reload) { proj in
            EditProjectView(project: proj) { updated in
                if let idx = projects.firstIndex(where: { $0.id == updated.id }) {
                    projects[idx] = updated
                    if selected?.id == updated.id { selected = updated }
                }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selected) {
            ForEach(projects) { project in
                ProjectRow(project: project, stats: statsByID[project.id])
                    .tag(project)
                    .contextMenu {
                        Button("Edit Project") { editProject = project }
                        Divider()
                        Button("Delete Project", role: .destructive) {
                            delete(project)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { delete(project) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { editProject = project } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { showNew = true } label: { Image(systemName: "plus") }
            }
        }
    }

    // MARK: - Empty detail

    private var emptyDetail: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 52)).foregroundStyle(.tertiary)
            Text("Select a project").font(.title3).foregroundStyle(.secondary)
            Button("New Project") { showNew = true }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func delete(_ project: Project) {
        ProjectService.shared.deleteProject(project.id)
        if selected?.id == project.id { selected = nil }
        reload()
    }

    private func reload() {
        projects = ProjectService.shared.allProjects()
        statsByID = Dictionary(
            uniqueKeysWithValues: projects.map {
                ($0.id, ProjectService.shared.stats(forProject: $0.id))
            }
        )
        if let sel = selected, !projects.contains(where: { $0.id == sel.id }) {
            selected = projects.first
        }
    }
}

// MARK: - ProjectIconView

struct ProjectIconView: View {
    let project: Project
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: project.iconColor ?? project.color))

            if let path = project.iconImagePath,
               let img  = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable().scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if let emoji = project.iconEmoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size * 0.52))
            } else {
                Text(String(project.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - ProjectRow

struct ProjectRow: View {
    let project: Project
    let stats: ProjectStats?

    var body: some View {
        HStack(spacing: 10) {
            ProjectIconView(project: project, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                if let s = stats {
                    Text(summary(s))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let s = stats, s.todaySeconds > 0 {
                Text(fmt(s.todaySeconds))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
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
