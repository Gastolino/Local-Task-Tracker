import SwiftUI

/// Sheet that appears when a work app (Photoshop, Teams, etc.) is detected.
/// Asks the user whether they want to start/continue a recording session.
struct AppLaunchPromptView: View {

    let appName: String
    let onDismiss: (_ shouldStart: Bool) -> Void

    @State private var appear = false

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentColor)
            }
            .scaleEffect(appear ? 1 : 0.6)
            .opacity(appear ? 1 : 0)

            // Message
            VStack(spacing: 8) {
                Text("\(appName) is open")
                    .font(.title3.bold())

                Text("Are you starting a work session? Local Task Tracker can record your time and take periodic screenshots.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .opacity(appear ? 1 : 0)

            // Buttons
            HStack(spacing: 12) {
                Button("Not Now") {
                    onDismiss(false)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.escape)

                Button("Start Recording") {
                    onDismiss(true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
            }
            .opacity(appear ? 1 : 0)
        }
        .padding(36)
        .frame(minWidth: 420)
        .onAppear {
            withAnimation(.spring(duration: 0.4)) { appear = true }
        }
    }
}
