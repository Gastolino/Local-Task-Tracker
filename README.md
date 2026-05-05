# Local Task Tracker

A private, encrypted macOS activity tracker for freelancers.  Logs which apps
you use and for how long, captures low-res screenshots, and presents everything
in a calendar UI — all without a network connection and behind a password you
set yourself.

---

## Architecture

```
Python daemon  ─────────────────────────────────────────────────────────────
  Polls active app every 5 s via osascript / IOKit.
  Detects work-app launches (Photoshop, Teams, etc.) and writes events.
  Writes to tracker.db (SQLite, WAL mode — safe across lid-close sleep).
  Screenshots: disabled (handled by Swift app so they can be encrypted).

Swift UI app   ─────────────────────────────────────────────────────────────
  Password lock screen  – PBKDF2-SHA256 (100 k rounds) + AES-256-GCM.
  Menu bar icon         – start / stop / open tracker.
  Calendar view         – month heatmap + day timeline + screenshot strip.
  Work-app prompt       – sheet when Photoshop / Teams / etc. opens.
  Screenshots           – captured, encrypted, never hit disk as plain JPEG.
  Network               – zero. App Sandbox with no network entitlements.
```

---

## Requirements

| | Requirement |
|---|---|
| **macOS** | 13 Ventura or later |
| **Python** | 3.10 or later (stdlib only) |
| **Xcode** | 15 or later (to build the Swift UI app) |

---

## Quick start

### 1 — Run the Python daemon

```bash
git clone https://github.com/gastolino/local-task-tracker.git
cd local-task-tracker
bash scripts/install.sh        # installs as a LaunchAgent (starts at login)
```

The daemon immediately starts tracking app usage. No UI yet.

### 2 — Build the Swift UI app in Xcode

```
File → Open → select Package.swift in the repo root
```

Then in Xcode:

1. Select the **LocalTaskTracker** scheme.
2. **Signing & Capabilities** → set your Team and Bundle ID.
3. Add the entitlements file:
   - Click **+ Capability** → **App Sandbox**.
   - Set *Entitlements File* to `LocalTaskTracker.entitlements`.
4. **Build Settings → Info.plist File** → set to
   `Sources/LocalTaskTracker/Info.plist`.
5. **Product → Run** (or `⌘R`).

Grant the two permissions macOS will ask for:

| Permission | Where to grant |
|---|---|
| **Accessibility** | System Settings → Privacy & Security → Accessibility |
| **Screen Recording** | System Settings → Privacy & Security → Screen Recording |

### 3 — First launch

A password setup screen appears.  Choose a strong password (≥ 8 chars).
This password:
- Is **never stored** — only a PBKDF2 verifier hash lives in the Keychain.
- Derives the AES-256-GCM key used to encrypt every screenshot.
- **Cannot be recovered** if forgotten (data is then inaccessible by design).

---

## Daily use

The app lives in your **menu bar**.  Click the clock icon to:

| Action | Effect |
|---|---|
| **Pause / Resume Recording** | Stop / restart screenshot capture |
| **Open Tracker** | Opens the calendar window |
| **Lock & Quit** | Wipes the in-memory key, closes app |

### Work-app prompts

When you open PowerPoint, Photoshop, Illustrator, Teams, Figma, or any other
configured work app, a sheet appears asking whether to start recording.  Hit
**Start Recording** and the session begins immediately.

---

## Calendar UI

```
┌──────────────────────────────────────────────────────────────────┐
│  ← May 2025 →                                                    │
│  Sun   Mon   Tue   Wed   Thu   Fri   Sat                         │
│                          1     2     3                           │
│                          ████  ███                               │
│  4     5     6     7     8     9     10                          │
│  ██   ████   ███   ─    ████   ██    ─                           │
├──────────────────────────────────────────────────────────────────┤
│  Wednesday, 7 May 2025  ·  Active 5h 22m  ·  Idle 48m           │
│                                                                  │
│  App Usage                                                       │
│  ● Xcode         ████████████████████████  2h 14m               │
│  ● Safari        ████████████████          1h 03m               │
│  ● Figma         ████████████              55m                   │
│                                                                  │
│  Screenshots  (18)                                               │
│  [09:15] [09:45] [10:15] [10:45] …   ← click to view full-size  │
│                                                                  │
│  Timeline                                                        │
│  09:00  │ Xcode  2h 14m                                          │
│  11:14  │ Safari  1h 03m                                          │
│  …                                                               │
└──────────────────────────────────────────────────────────────────┘
```

- **Heatmap cells** — greener = more active time that day.
- **Screenshot thumbnails** — decrypted in memory for display; the `.jpg.enc`
  files on disk are never readable without your password.
- **Click any thumbnail** to open a full-size decrypted preview.

---

## Security model

| Layer | Mechanism |
|---|---|
| **Password** | PBKDF2-SHA256, 100 000 rounds; only a verifier hash stored in Keychain |
| **Encryption key** | AES-256-GCM key derived at unlock, held in process memory only |
| **Screenshots** | Encrypted before `write()` is called — raw JPEG never touches disk |
| **Database** | Plain SQLite (macOS login + file permissions protect it); future: SQLCipher |
| **Network** | App Sandbox with no `network.client` or `network.server` entitlement |
| **Keychain items** | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` — not in iCloud Keychain |
| **Lock** | In-memory key is nilled; app reverts to full-screen lock screen |

> FileVault (enabled by default on Apple Silicon Macs) encrypts the entire disk,
> providing the base layer.  The password gate and screenshot encryption add a
> second, app-specific layer on top.

---

## Configuration

### Python daemon — `tracker/config.py`

| Setting | Default | Description |
|---|---|---|
| `POLL_INTERVAL` | `5` s | App-name poll frequency |
| `IDLE_THRESHOLD` | `120` s | Input silence before marking idle |
| `SCREENSHOT_ENABLED` | `False` | Enable only if not using the Swift UI |
| `WORK_APPS` | (set) | Apps that trigger the recording prompt |

### Swift app — `ScreenshotService.swift`

| Property | Default | Description |
|---|---|---|
| `interval` | `30` s | Screenshot frequency |
| Max dimension | `480` px | Longest edge of saved screenshots |
| JPEG quality | `0.3` | 30 % quality ≈ ~15 KB per frame |

At 30 s intervals over an 8-hour day: **~60 MB** of encrypted screenshots.

---

## Uninstall daemon

```bash
bash scripts/uninstall.sh
```

Data lives at `~/Library/Application Support/LocalTaskTracker/`.
Delete that directory to remove everything.

---

## Adding work apps

Edit the `WORK_APPS` set in `tracker/config.py` **and** the same set in
`Sources/LocalTaskTracker/Services/AppMonitorService.swift`, then rebuild.

---

## Privacy

No telemetry. No network calls. No external dependencies beyond macOS system
frameworks and the Python standard library.  Everything stays on your machine.
