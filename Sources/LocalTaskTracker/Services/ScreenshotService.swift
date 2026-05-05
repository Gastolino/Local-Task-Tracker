import AppKit
import CoreGraphics
import CryptoKit
import Foundation

/// Captures a low-resolution screenshot every `interval` seconds while the
/// app is recording.  Images are AES-256-GCM encrypted before hitting disk —
/// the raw JPEG never exists as a file.
final class ScreenshotService {

    static let shared = ScreenshotService()
    private init() {}

    private let interval: TimeInterval = 30
    private var timer: Timer?
    private weak var appState: AppState?

    private static let dataDir: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("LocalTaskTracker")
    }()

    // MARK: - Lifecycle

    func start(appState: AppState) {
        self.appState = appState
        stop()   // clear any existing timer
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.captureAndSave()
        }
        timer?.tolerance = 5   // allow OS to coalesce timers → less wake-ups
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Capture

    private func captureAndSave() {
        guard let key = appState?.encryptionKey,
              appState?.isRecording == true
        else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.doCapture(key: key)
        }
    }

    private func doCapture(key: SymmetricKey) {
        // 1. Capture the main display.
        guard let cgImage = CGDisplayCreateImage(CGMainDisplayID()) else { return }
        let original = NSImage(cgImage: cgImage, size: .zero)

        // 2. Resize to max 480 px on the longest edge.
        let resized = resize(original, maxDim: 480)

        // 3. Encode as JPEG (quality 0.3 ≈ 30 %).
        guard let jpeg = jpegData(resized, quality: 0.3) else { return }

        // 4. Encrypt — raw JPEG data never touches disk.
        guard let encrypted = CryptoService.shared.encrypt(jpeg, using: key) else { return }

        // 5. Write encrypted blob to a date-organised directory.
        let now = Date()
        let dir = Self.dataDir
            .appendingPathComponent("screenshots")
            .appendingPathComponent(ymd(now))
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let filename  = hms(now) + ".jpg.enc"
        let dest      = dir.appendingPathComponent(filename)
        let relative  = "screenshots/\(ymd(now))/\(filename)"

        guard (try? encrypted.write(to: dest)) != nil else { return }

        // 6. Record in DB so the calendar can display it.
        DispatchQueue.main.async {
            DatabaseService.shared.insertScreenshot(ts: now, path: relative)
        }
    }

    // MARK: - Image helpers

    private func resize(_ image: NSImage, maxDim: CGFloat) -> NSImage {
        let s = image.size
        let scale = min(maxDim / s.width, maxDim / s.height, 1.0)
        let newSize = NSSize(width: s.width * scale, height: s.height * scale)
        let result = NSImage(size: newSize)
        result.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: s),
            operation: .copy, fraction: 1.0
        )
        result.unlockFocus()
        return result
    }

    private func jpegData(_ image: NSImage, quality: Double) -> Data? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }

    // MARK: - Date formatting

    private let _ymd: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.timeZone = .current; return f
    }()
    private let _hms: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH-mm-ss"; f.timeZone = .current; return f
    }()
    private func ymd(_ d: Date) -> String { _ymd.string(from: d) }
    private func hms(_ d: Date) -> String { _hms.string(from: d) }
}
