import SwiftUI

/// Full-screen lock / first-run setup view.
struct LockView: View {

    @EnvironmentObject var appState: AppState

    @State private var password = ""
    @State private var confirm  = ""
    @State private var error    = ""
    @State private var isSetup  = false     // true = first-run password creation
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            // Dark background — nothing behind is visible.
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.9))
                    .symbolRenderingMode(.hierarchical)

                // Title
                Text(isSetup ? "Set Your Password" : "Local Task Tracker")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text(isSetup
                     ? "This password encrypts your screenshots and gates all access to the app. It cannot be recovered if lost."
                     : "Enter your password to unlock.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                // Fields
                VStack(spacing: 12) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                        .focused($focused)
                        .onSubmit { isSetup ? attemptSetup() : attemptUnlock() }

                    if isSetup {
                        SecureField("Confirm password", text: $confirm)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                            .onSubmit { attemptSetup() }
                    }
                }
                .frame(maxWidth: 320)

                // Error
                if !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.85))
                        .transition(.opacity)
                }

                // Action button
                Button(action: isSetup ? attemptSetup : attemptUnlock) {
                    Text(isSetup ? "Create Password & Start" : "Unlock")
                        .font(.headline)
                        .frame(maxWidth: 320)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.indigo)

                Spacer()
            }
            .padding(40)
        }
        .onAppear {
            isSetup = !appState.isPasswordConfigured
            focused = true
        }
        .animation(.easeInOut(duration: 0.2), value: error)
    }

    // MARK: - Actions

    private func attemptUnlock() {
        error = ""
        guard !password.isEmpty else { error = "Enter your password."; return }
        if appState.unlock(password: password) {
            password = ""
        } else {
            error = "Incorrect password."
            password = ""
        }
    }

    private func attemptSetup() {
        error = ""
        guard password.count >= 8 else {
            error = "Password must be at least 8 characters."
            return
        }
        guard password == confirm else {
            error = "Passwords don't match."
            confirm = ""
            return
        }
        if !appState.configurePassword(password) {
            error = "Failed to save password. Check Keychain access."
        }
        password = ""
        confirm  = ""
    }
}
