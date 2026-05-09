import SwiftUI

/// Sheet for creating a new project.
struct NewProjectView: View {

    var onCreated: (Project) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var name               = ""
    @State private var description        = ""
    @State private var color              = Project.presetColors[0]
    @State private var deadlineEnabled    = false
    @State private var deadline           = Date().addingTimeInterval(30 * 86400)
    @State private var allocatedHoursText = ""
    @State private var iconType           = IconPickerType.letter
    @State private var iconEmoji          = ""
    @State private var iconColor          = Project.presetColors[0]
    @State private var iconImagePath:     String? = nil
    @State private var showImagePicker    = false
    @State private var error              = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            Text("New Project").font(.title2.bold())

            // Preview + Name row
            HStack(spacing: 14) {
                iconPreview
                VStack(alignment: .leading, spacing: 6) {
                    label("Project name")
                    TextField("e.g. Client X Website", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Description
            VStack(alignment: .leading, spacing: 6) {
                label("Description (optional)")
                TextField("What is this project about?", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder).lineLimit(3, reservesSpace: true)
            }

            // Project colour
            VStack(alignment: .leading, spacing: 8) {
                label("Project colour")
                colorSwatches(selected: $color)
            }

            // Icon
            VStack(alignment: .leading, spacing: 10) {
                label("Icon")
                iconPicker
            }

            // Scope
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    label("Allocated Hours")
                    TextField("e.g. 40", text: $allocatedHoursText)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Set Deadline", isOn: $deadlineEnabled)
                        .font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
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
                Button("Cancel") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.escape)
                Spacer()
                Button("Create Project") { create() }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .keyboardShortcut(.return)
            }
        }
        .padding(28)
        .frame(width: 460, height: 560)
        .fileImporter(isPresented: $showImagePicker,
                      allowedContentTypes: [.image]) { result in
            if case .success(let url) = result {
                iconImagePath = copyIconImage(url)
            }
        }
    }

    // MARK: - Icon sub-views

    private var iconPreview: some View {
        iconPreviewView(
            name: name, color: color,
            iconType: iconType, iconEmoji: iconEmoji,
            iconColor: iconColor, iconImagePath: iconImagePath,
            size: 52
        )
    }

    @ViewBuilder
    private var iconPicker: some View {
        Picker("Icon", selection: $iconType) {
            Text("Letter").tag(IconPickerType.letter)
            Text("Emoji").tag(IconPickerType.emoji)
            Text("Image").tag(IconPickerType.image)
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 260)

        switch iconType {
        case .letter:
            EmptyView()

        case .emoji:
            HStack(spacing: 12) {
                TextField("Emoji", text: $iconEmoji)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 58)
                    .onChange(of: iconEmoji) { v in
                        // Keep only the first grapheme cluster (one emoji/char)
                        if v.count > 1 { iconEmoji = String(v.prefix(1)) }
                    }
                colorSwatches(selected: $iconColor)
            }

        case .image:
            HStack(spacing: 10) {
                if let path = iconImagePath {
                    Text(URL(fileURLWithPath: path).lastPathComponent)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Button("Remove") { iconImagePath = nil }
                        .buttonStyle(.borderless).controlSize(.small).foregroundStyle(.red)
                } else {
                    Button("Choose Image…") { showImagePicker = true }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }

    // MARK: - Actions

    private func create() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { error = "Name is required."; return }
        let emoji     = iconType == .emoji  ? (iconEmoji.isEmpty ? nil : iconEmoji) : nil
        let iColor    = iconType == .emoji  ? iconColor : nil
        let imagePath = iconType == .image  ? iconImagePath : nil
        guard let project = ProjectService.shared.createProject(
            name: trimmed, color: color,
            description: description.isEmpty ? nil : description,
            deadline: deadlineEnabled ? deadline : nil,
            allocatedHours: Double(allocatedHoursText.trimmingCharacters(in: .whitespaces)),
            iconEmoji: emoji, iconColor: iColor, iconImagePath: imagePath
        ) else { error = "Failed to save — try a different name."; return }
        onCreated(project)
        dismiss()
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
    }
}

// MARK: - Shared icon helpers (used by New + Edit views)

enum IconPickerType: Hashable { case letter, emoji, image }

func colorSwatches(selected: Binding<String>) -> some View {
    HStack(spacing: 8) {
        ForEach(Project.presetColors, id: \.self) { hex in
            Circle().fill(Color(hex: hex)).frame(width: 22, height: 22)
                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1))
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .opacity(selected.wrappedValue == hex ? 1 : 0)
                )
                .onTapGesture { selected.wrappedValue = hex }
        }
    }
}

func iconPreviewView(
    name: String, color: String,
    iconType: IconPickerType, iconEmoji: String,
    iconColor: String, iconImagePath: String?,
    size: CGFloat
) -> some View {
    ZStack {
        let bg = iconType == .emoji ? iconColor : color
        Circle().fill(Color(hex: bg))

        if iconType == .image, let path = iconImagePath,
           let img = NSImage(contentsOfFile: path) {
            Image(nsImage: img).resizable().scaledToFill()
                .frame(width: size, height: size).clipShape(Circle())
        } else if iconType == .emoji, !iconEmoji.isEmpty {
            Text(iconEmoji).font(.system(size: size * 0.52))
        } else {
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
}

func copyIconImage(_ url: URL) -> String? {
    let dir = AppPaths.dataDir.appendingPathComponent("project-icons")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let ext  = url.pathExtension
    let dest = dir.appendingPathComponent(UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)"))
    try? FileManager.default.copyItem(at: url, to: dest)
    return FileManager.default.fileExists(atPath: dest.path) ? dest.path : nil
}
