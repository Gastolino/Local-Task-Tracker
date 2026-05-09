import SwiftUI

struct DayDetailView: View {

    let date: Date

    @EnvironmentObject var appState: AppState
    @State private var activities:   [ActivityRecord]   = []
    @State private var screenshots:  [ScreenshotRecord] = []
    @State private var daySessions:  [Session]          = []
    @State private var selectedShot: ScreenshotRecord?
    @State private var showNewSession = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if activities.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        appBars
                        if !daySessions.isEmpty { sessionsSection }
                        timeline
                    }
                    .padding(20)
                }
            }
        }
        .onAppear { load() }
        .onChange(of: date) { _ in load() }
        .sheet(item: $selectedShot) { shot in
            ScreenshotViewer(record: shot).environmentObject(appState)
        }
        .sheet(isPresented: $showNewSession, onDismiss: { daySessions = ProjectService.shared.sessions(forDate: date) }) {
            SessionEditorView(
                startHint: Calendar.current.startOfDay(for: date),
                endHint:   Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))!
            ) { _ in }
            .environmentObject(appState)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(.title2.bold())
                if !activities.isEmpty {
                    Text("Active \(fmt(activeSeconds))  ·  Idle \(fmt(idleSeconds))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                showNewSession = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(20)
    }

    // MARK: - App bar chart

    private var appBars: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("APPS")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(appTotals) { total in
                HStack(spacing: 10) {
                    Circle().fill(total.appName.trackingColor)
                        .frame(width: 8, height: 8)
                    Text(total.appName)
                        .font(.subheadline).frame(width: 160, alignment: .leading).lineLimit(1)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(total.appName.trackingColor.opacity(0.2))
                            .overlay(alignment: .leading) {
                                let frac = total.duration / max(appTotals.first?.duration ?? 1, 1)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(total.appName.trackingColor)
                                    .frame(width: geo.size.width * frac)
                            }
                    }
                    .frame(height: 10)
                    Text(fmt(total.duration))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Sessions for the day

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SESSIONS")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(daySessions) { session in
                HStack(spacing: 10) {
                    Circle().fill(Color(hex: session.projectColor)).frame(width: 8, height: 8)
                    Text(session.projectName).font(.subheadline.weight(.medium)).lineLimit(1)
                    if let lbl = session.label, !lbl.isEmpty {
                        Text("· \(lbl)").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Text(fmt(session.duration))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TIMELINE")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(appBlocks) { block in
                timelineRow(block)
            }
        }
    }

    private func timelineRow(_ block: AppBlock) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(block.start, format: .dateTime.hour().minute())
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
                .padding(.top, 2)

            RoundedRectangle(cornerRadius: 2)
                .fill(block.appName.trackingColor)
                .frame(width: 3, height: 22)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(block.appName).font(.subheadline).lineLimit(1)
                    Spacer()
                    Text(fmt(block.duration))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                let blockShots = shots(in: block)
                if !blockShots.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(blockShots) { shot in
                                ScreenshotThumbnail(record: shot)
                                    .environmentObject(appState)
                                    .onTapGesture { selectedShot = shot }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func shots(in block: AppBlock) -> [ScreenshotRecord] {
        screenshots.filter { $0.ts >= block.start && $0.ts <= block.end }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz").font(.system(size: 40)).foregroundStyle(.tertiary)
            Text("No activity recorded for this day.").foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, 60)
    }

    // MARK: - Data

    private func load() {
        activities  = DatabaseService.shared.activities(for: date)
        screenshots = DatabaseService.shared.screenshots(for: date)
        daySessions = ProjectService.shared.sessions(forDate: date)
    }

    private var activeSeconds: TimeInterval { Double(activities.filter { !$0.isIdle }.count) * 5 }
    private var idleSeconds:   TimeInterval { Double(activities.filter {  $0.isIdle }.count) * 5 }

    private var appTotals: [AppTotal] {
        var counts: [String: Int] = [:]
        for a in activities where !a.isIdle {
            guard let app = a.appName else { continue }
            counts[app, default: 0] += 1
        }
        return counts.map { AppTotal(id: $0.key, appName: $0.key, duration: Double($0.value) * 5) }
            .sorted { $0.duration > $1.duration }
    }

    private var appBlocks: [AppBlock] {
        var blocks: [AppBlock] = []
        var current = ""; var start = Date.distantPast
        for a in activities where !a.isIdle {
            guard let app = a.appName else { continue }
            if app != current {
                if !current.isEmpty { blocks.append(AppBlock(appName: current, start: start, end: a.ts)) }
                current = app; start = a.ts
            } else if !blocks.isEmpty { blocks[blocks.count - 1].end = a.ts }
        }
        if !current.isEmpty, let last = activities.last {
            blocks.append(AppBlock(appName: current, start: start, end: last.ts))
        }
        return blocks
    }

    private func fmt(_ s: TimeInterval) -> String {
        let t = Int(s); let h = t / 3600; let m = (t % 3600) / 60; let sec = t % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, sec) }
        return String(format: "%ds", sec)
    }
}

// MARK: - Screenshot thumbnail

struct ScreenshotThumbnail: View {
    let record: ScreenshotRecord
    @EnvironmentObject var appState: AppState
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(Color.gray.opacity(0.12)).frame(width: 96, height: 62)
                if let img = image {
                    Image(nsImage: img).resizable().scaledToFill()
                        .frame(width: 96, height: 62).clipped().cornerRadius(5)
                } else { ProgressView().scaleEffect(0.5) }
            }
            Text(record.ts, format: .dateTime.hour().minute())
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .task { await load() }
    }

    private func load() async {
        guard let key = appState.encryptionKey else { return }
        let url = AppPaths.dataDir.appendingPathComponent(record.path)
        guard let enc  = try? Data(contentsOf: url),
              let data = CryptoService.shared.decrypt(enc, using: key)
        else { return }
        image = NSImage(data: data)
    }
}

// MARK: - Full-size screenshot viewer

struct ScreenshotViewer: View {
    let record: ScreenshotRecord
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(record.ts, format: .dateTime.weekday().month().day().hour().minute())
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding([.horizontal, .top])
            if let img = image {
                Image(nsImage: img).resizable().scaledToFit().padding()
            } else {
                ProgressView("Decrypting…").frame(width: 400, height: 300)
            }
        }
        .frame(minWidth: 500, minHeight: 360)
        .task {
            guard let key = appState.encryptionKey else { return }
            let url = AppPaths.dataDir.appendingPathComponent(record.path)
            guard let enc  = try? Data(contentsOf: url),
                  let data = CryptoService.shared.decrypt(enc, using: key)
            else { return }
            image = NSImage(data: data)
        }
    }
}

// MARK: - Colour helper

private extension String {
    var trackingColor: Color {
        let palette: [Color] = [.blue, .green, .orange, .purple, .red, .teal, .pink, .indigo, .cyan, .mint, .yellow]
        return palette[abs(hashValue) % palette.count]
    }
}
