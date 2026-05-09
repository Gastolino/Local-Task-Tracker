import SwiftUI

/// Sheet for creating a new project.
struct NewProjectView: View {

    var onCreated: (Project) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var name             = ""
    @State private var description      = ""
    @State private var color            = Project.presetColors[0]
    @State private var deadlineEnabled  = false
    @State private var deadline         = Date().addingTimeInterval(30 * 86400)
    @State private var allocatedHoursText = ""
    @State private var error            = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {

            Text("New Project")
                .font(.title2.bold())

            // Name
            VStack(alignment: .leading, spacing: 6) {
                label("Project name")
                TextField("e.g. Client X Website", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            // Description
            VStack(alignment: .leading, spacing: 6) {
                label("Description (optional)")
                TextField("What is this project about?", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3, reservesSpace: true)
            }

            // Color picker
            VStack(alignment: .leading, spacing: 10) {
                label("Colour")
                HStack(spacing: 10) {
                    ForEach(Project.presetColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .opacity(color == hex ? 1 : 0)
                            )
                            .onTapGesture { color = hex }
                    }
                }
            }

            // Scope fields
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    label("Allocated Hours")
                    TextField("e.g. 40", text: $allocatedHoursText)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Set Deadline", isOn: $deadlineEnabled)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    if deadlineEnabled {
                        DatePicker("", selection: $deadline, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }

            if !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape)
                Spacer()
                Button("Create Project") { create() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return)
            }
        }
        .padding(28)
        .frame(width: 420, height: 440)
    }

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { error = "Name is required."; return }
        guard let project = ProjectService.shared.createProject(
            name: trimmed,
            color: color,
            description: description.isEmpty ? nil : description,
            deadline: deadlineEnabled ? deadline : nil,
            allocatedHours: Double(allocatedHoursText.trimmingCharacters(in: .whitespaces))
        ) else {
            error = "Failed to save — try a different name."
            return
        }
        onCreated(project)
        dismiss()
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
    }
}
