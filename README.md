# maxguspicker1824

> **A native macOS Link & Mail Router with Multi-Browser Profile Support, Source-App Detection, and a Visual Rule Engine.**

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B%20(Sonoma%2B)-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B%20%7C%206.x-F05138?logo=swift&logoColor=white)
![UI](https://img.shields.io/badge/UI-AppKit%20%2B%20SwiftUI-0A84FF)
![License](https://img.shields.io/badge/license-MIT-green)

**maxguspicker1824** is a lightweight, menu-bar macOS utility inspired by Bumpr, Choosy, and Velja. When set as your default web browser and default email reader, it intercepts every `http`, `https`, and `mailto` link you click across macOS:

- **Matches a Rule?** Automatically forwards the link to your configured browser (and specific browser profile/space) or mail client in the background.
- **No Rule Match?** Spawns a sleek, draggable, cursor-positioned floating picker right on your active Space (including Full Screen apps) so you can pick the app or profile on the fly—or create a routing rule with a single click.

---

## 📸 Screenshots

| Floating App Selector | Menu Bar Control Center |
| :---: | :---: |
| <img src="docs/screenshots/floating-selector.png" alt="Floating App Selector" width="340" /> | <img src="docs/screenshots/menubar-menu.png" alt="Menu Bar Control Center" width="340" /> |
| *Draggable cursor-positioned floating selector with one-click rule creation* | *Menu bar status icon with pause toggle, rule counter & recent activity* |

### Visual 3-Step Rule Builder & Routing Rules Editor

<p align="center">
  <img src="docs/screenshots/rule-builder.png" alt="Visual 3-Step Rule Builder" width="760" />
</p>

---

## ✨ Features

### 1. Cursor-Positioned Floating App & Profile Selector
- **Appears Right at Your Cursor & Over Full-Screen Apps**: Spawns a borderless, non-activating `NSPanel` with `.ultraThinMaterial` blur centered at your mouse pointer on your active Space (including over full-screen applications).
- **Freely Draggable**: Grab the top handle or anywhere on the panel background to reposition the floating selector on screen.
- **Instant Profile Selection**: Left-click an app icon to open in its default window, or click the profile chevron (`▾`) / right-click the icon to pick a specific browser profile or workspace directly from the popup.
- **One-Click Quick Rules**: Check **"Always open `<domain/recipient>` with chosen app"** before clicking an icon to save a permanent routing rule on the spot.
- **Effortless Dismissal**: Click the `×` button, click anywhere outside the popup, or press `Esc` to dismiss.
- **Modifier Key Override (`Option ⌥`)**: Hold **Option (`⌥`)** while clicking any link to bypass all automatic routing rules and force the floating selector to appear.

### 2. Deep Browser Profile & Workspace Discovery
Automatically detects and launches links into specific profiles or spaces without spawning duplicate Dock instances:

| Browser | Profile Discovery Source | Launch Mechanism |
| :--- | :--- | :--- |
| **Google Chrome** | `~/Library/Application Support/Google/Chrome/Local State` | Direct binary invocation with `--profile-directory="<Dir>"` |
| **Brave Browser** | `~/Library/Application Support/BraveSoftware/Brave-Browser/Local State` | Direct binary invocation with `--profile-directory="<Dir>"` |
| **Microsoft Edge / Vivaldi** | Chromium `Local State` (`profile.info_cache`) | Direct binary invocation with `--profile-directory="<Dir>"` |
| **Firefox** | `~/Library/Application Support/Firefox/profiles.ini` | Direct binary invocation with `-P "<ProfileName>"` |
| **Arc** | Live AppleScript query of front window Spaces | AppleScript targeting `space "<SpaceName>"` |
| **Safari (macOS 14+)** | `System Events` inspection of `File → New Window` profile items | Reuses open `<Profile> —` window or triggers `New <Profile> Window` |
| **Mail Clients** | LaunchServices `mailto:` handler discovery | Standard `NSWorkspace` activation & URL handoff |

### 3. Context-Aware Source Application Routing
- Detects **which application originated the click** (e.g., Slack, Notion, Linear, Terminal, Apple Mail) via the incoming `kAEGetURL` AppleEvent sender PID (`keyAddressAttr`) with fallback to `NSWorkspace.shared.frontmostApplication`.
- Build rules that route **all links clicked inside a specific app** (e.g., *"Clicked in Slack • any website link → Google Chrome (Work)"*) or combine source app + URL conditions.

### 4. Human-Friendly Visual Rule Engine (No Regex Required)
- **Sentence-Style Rules**: Build rules using plain-English fields and operators instead of raw regular expressions:
  - **Web Fields**: `Website Domain`, `Full Web Address`, `URL Path`
  - **Email Fields**: `Recipient Email`, `Email Domain (@company.com)`, `Email Subject`
  - **Operators**: `contains`, `is exactly` (automatically normalizes leading `www.`), `starts with`, `ends with`, and `matches regex (advanced)`
- **Drag-and-Drop Priority**: Reorder rules in the Graphical Rules Manager to control evaluation priority immediately.
- **Live Rule Tester Sandbox**: Paste any URL or email address into the bottom tester bar (`wand.and.stars`) to see in real time which rule card lights up in green—or if the floating app selector will be shown.

### 5. Menu Bar Control Center & 3-Step Onboarding Wizard
- **Menu Bar Status Item (`MenuBarExtra`)**:
  - Live warning banner if **maxguspicker1824** is not currently set as the default browser.
  - **Pause Rules** toggle (`pause.circle`) to temporarily force the floating picker for all links.
  - **Recent Activity** submenu showing the last 5 routed links, their source app, and target destination.
  - Quick access to **Routing Rules (`⌘,`)** and the **Setup & Permissions Wizard**.
- **Interactive Onboarding Wizard**:
  - Automatically opens on first launch with live-polling green checkmarks for configuring **Default Web Browser**, **Default Email Reader**, and **Accessibility Permission** (for Safari/Arc automation).

---

## 🧭 Architecture & Routing Flow

```mermaid
flowchart TD
    A["Incoming Link (http / https / mailto)"] --> B["AppDelegate: application(_:open:)"]
    B --> C["SourceAppDetector: Identify Sender App"]
    C --> D{"Option (⌥) Held or Rules Paused?"}
    D -- "Yes" --> G["Show FloatingSelectorView at Cursor"]
    D -- "No" --> E["RulesStore: Evaluate Enabled Rules in Priority Order"]
    E --> F{"Rule Matched?"}
    F -- "Yes" --> H["AppDiscoveryService: Open in Target App & Profile/Space"]
    F -- "No" --> G
    G --> I["User Selects App / Profile"]
    I --> J{"Remember Domain Checked?"}
    J -- "Yes" --> K["Save Quick Rule to RulesStore"]
    J -- "No" --> H
    K --> H
    H --> L["Log Entry in Recent Activity"]
```

---

## 📂 Project Structure

```text
maxguspicker1824/
├── Package.swift                                      # SwiftPM manifest (macOS 14+)
├── Makefile                                           # Build, bundle, install, run, test, and clean targets
├── LICENSE                                            # MIT License
├── TODO.md                                            # Phased implementation tracker
├── docs/screenshots/                                  # Cropped UI screenshots for documentation
│   ├── floating-selector.png
│   ├── menubar-menu.png
│   └── rule-builder.png
├── Resources/
│   ├── Info.plist                                     # LSUIElement + http/https/mailto URL schemes
│   └── maxguspicker1824.entitlements                  # Sandbox disabled + AppleEvents entitlement
├── scripts/
│   └── bundle_app.sh                                  # Compiles, assembles, signs & registers .app bundle
├── Sources/maxguspicker1824/
│   ├── App/
│   │   ├── maxguspicker1824App.swift                  # @main entry point & MenuBarExtra scene
│   │   └── AppDelegate.swift                          # URL interception, FloatingPanel & window management
│   ├── Models/
│   │   ├── AppTarget.swift                            # BrowserEngine, BrowserProfile, AppTarget, SourceAppInfo
│   │   └── RoutingRule.swift                          # RouteType, MatchField, MatchOperator, RoutingRule
│   ├── Services/
│   │   ├── AppDiscoveryService.swift                  # Handler discovery & browser/profile launching
│   │   ├── ProfileDiscoveryService.swift              # Chrome, Brave, Edge, Vivaldi, Firefox, Arc & Safari profiles
│   │   ├── RulesStore.swift                           # Rule evaluation engine, persistence & activity log
│   │   ├── SourceAppDetector.swift                    # AppleEvent PID & frontmost app detection
│   │   └── SystemIntegrationService.swift             # Default browser/mail & Accessibility status manager
│   └── Views/
│       ├── FloatingSelectorView.swift                 # Draggable cursor-positioned floating picker UI
│       ├── OnboardingWizardView.swift                 # 3-step setup & permissions wizard
│       ├── RuleBuilderSheet.swift                     # 3-step visual rule creation/editing sheet
│       └── RulesManagerView.swift                     # Graphical rules list, cards & live rule tester bar
└── Tests/maxguspicker1824Tests/
    └── RulesStoreTests.swift                          # Unit test suite for routing rules & persistence
```

---

## 🛠️ How to Build, Install, Run, and Test

### Prerequisites
- **macOS 14.0 (Sonoma)** or later
- **Apple Command Line Tools** or **Xcode** (`swift` 5.9+ / 6.x)

### 1. Build, Install to `/Applications`, and Launch
To compile the release binary, package and sign `maxguspicker1824.app`, copy it into `/Applications`, register it with LaunchServices, and launch it in one step:

```bash
make install
```

### 2. Build Only (into `build/maxguspicker1824.app`)
```bash
make app
```
*(Or run `./scripts/bundle_app.sh release` directly.)*

### 3. Test Link & Mail Routing from the Terminal
You can simulate clicking web links or `mailto:` links at any time using `open`:

```bash
# Test a web link
open "https://github.com/alejandro-llanes"

# Or target the application explicitly
open -a /Applications/maxguspicker1824.app "https://github.com/alejandro-llanes"

# Test an email link with subject
open -a /Applications/maxguspicker1824.app "mailto:billing@acme.com?subject=Monthly%20Invoice"
```

### 4. Run the Automated Unit Tests
```bash
make test
```

### 5. Clean Build Artifacts
```bash
make clean
```

---

## ⌨️ Shortcuts & Tips

| Shortcut / Action | Behavior |
| :--- | :--- |
| **`Option (⌥)` + Click Link** | Bypass all routing rules and force the floating app selector at the cursor |
| **Drag Panel Background / Top Bar** | Reposition the floating app selector anywhere on screen |
| **`Esc`, `×`, or Click Outside** | Dismiss the floating app selector without opening any application |
| **Click `▾` or Right-Click Icon** | Choose a specific browser Profile or Arc Space in the floating selector |
| **`⌘ ,` (in Menu Bar)** | Open the **Routing Rules** graphical editor |
| **`⌘ Q` (in Menu Bar)** | Quit **maxguspicker1824** |

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
