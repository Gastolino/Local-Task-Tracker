import SwiftUI

/// Shows a full breakdown of one day: per-app bar chart + screenshot strip.
struct DayDetailView: View {

    let date: Date

    @EnvironmentObject var appState: AppState
    @State private var activities:   [ActivityRecord]   = []
    @State private var screenshots:  [ScreenshotRecord] = []
    @State private var selectedShot: ScreenshotRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if activities.isEmpty {
                        emptyState
                    } else {
                        appBars
                        if !screenshots.isEmpty {
                            screenshotStrip
                        }
                        timeline
                    }
                }
                .padding(20)
            }
        }
        .onAppear { load() }
        .onChange(of: date) { _ in load() }
        .sheet(item: $selectedShot) { shot in
            ScreenshotViewer(record: shot)
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
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if !activities.isEmpty {
                Text("\(appTotals.count) apps")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
    }

    // MARK: - App bar chart

    private var appBars: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("App Usage")
                .font(.headline)

            ForEach(appTotals) { total in
                HStack(spacing: 10) {
                    Circle()
                        .fill(total.appName.trackingColor)
                        .frame(width: 8, height: 8)

                    Text(total.appName)
                        .font(.subheadline)
                        .frame(width: 160, alignment: .leading)
                        .lineLimit(1)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(total.appName.trackingColor.opacity(0.25))
                            .overlay(alignment: .leading) {
                                let frac = total.duration / (appTotals.first?.duration ?? 1)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(total.appName.trackingColor)
                                    .frame(width: geo.size.width * frac)
                            }
                    }
                    .frame(height: 10)

                    Text(fmt(total.duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Screenshot strip

    private var screenshotStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Screenshots  (\(screenshots.count))")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(screenshots) { shot in
                        ScreenshotThumbnail(record: shot)
                            .environmentObject(appState)
                            .onTapGesture { selectedShot = shot }
                    }
                }
            }
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Timeline")
                .font(.headline)

            ForEach(appBlocks) { block in
                HStack(spacing: 10) {
                    // Time label
                    Text(block.start, format: .dateTime.hour().minute())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 48, alignment: .trailing)

                    // Colour chip
                    RoundedRectangle(cornerRadius: 4)
                        .fill(block.appName.trackingColor)
                        .frame(width: 4)
                        .frame(height: max(20, CGFloat(block.duration / 5) * 3))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(block.appName)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(fmt(block.duration))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No activity recorded for this day.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Data helpers

    private func load() {
        activities  = DatabaseService.shared.activities(for: date)
        screenshots = DatabaseService.shared.screenshots(for: date)
    }

    private var activeSeconds: TimeInterval {
        Double(activities.filter { !$0.isIdle }.count) * 5
    }
    private var idleSeconds: TimeInterval {
        Double(activities.filter { $0.isIdle }.count) * 5
    }

    private var appTotals: [AppTotal] {
        var counts: [String: Int] = [:]
        for a in activities where !a.isIdle, let app = a.appName {
            counts[app, default: 0] += 1
        }
        return counts
            .map { AppTotal(id: $0.key, appName: $0.key, duration: Double($0.value) * 5) }
            .sorted { $0.duration > $1.duration }
    }

    private var appBlocks: [AppBlock] {
        var blocks: [AppBlock] = []
        var currentName = ""
        var blockStart  = Date.distantPast

        for a in activities where !a.isIdle {
            guard let app = a.appName else { continue }
            if app != currentName {
                if !currentName.isEmpty {
                    blocks.append(AppBlock(appName: currentName, start: blockStart, end: a.ts))
                }
                currentName = app
                blockStart  = a.ts
            } else {
                // Extend the last block.
                if !blocks.isEmpty { blocks[blocks.count - 1].end = a.ts }
            }
        }
        if !currentName.isEmpty, let last = activities.last {
            blocks.append(AppBlock(appName: currentName, start: blockStart, end: last.ts))
        }
        return blocks
    }

    private func fmt(_ s: TimeInterval) -> String {
        let t = Int(s)
        let h = t / 3600; let m = (t % 3600) / 60; let sec = t % 60
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
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 120, height: 78)

                if let img = image {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 78)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    ProgressView().scaleEffect(0.6)
                }
            }
            Text(record.ts, format: .dateTime.hour().minute())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .task { await load() }
    }

    private func load() async {
        guard let key = appState.encryptionKey else { return }
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("LocalTaskTracker")
        let url  = base.appendingPathComponent(record.path)
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
    @State private var image: NSImage?
    @Environment(\.dismiss) var dismiss

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
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                ProgressView("Decrypting…")
                    .frame(width: 400, height: 300)
            }
        }
        .frame(minWidth: 500, minHeight: 360)
        .task {
            guard let key = appState.encryptionKey else { return }
            let base = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first!.appendingPathComponent("LocalTaskTracker")
            let url  = base.appendingPathComponent(record.path)
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
        let palette: [Color] = [
            .blue, .green, .orange, .purple, .red,
            .teal, .pink, .indigo, .cyan, .mint, .yellow,
        ]
        return palette[abs(hashValue) % palette.count]
    }
}
