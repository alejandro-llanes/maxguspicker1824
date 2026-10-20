import AppKit
import SwiftUI

enum SetupWindowTab: String, CaseIterable, Identifiable {
    case permissions = "System Setup"
    case features = "Features & Chooser UX"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .permissions: return "checkmark.shield.fill"
        case .features: return "slider.horizontal.3"
        }
    }
}

struct OnboardingWizardView: View {
    @ObservedObject var systemService = SystemIntegrationService.shared
    @ObservedObject var store = RulesStore.shared
    @ViewState var selectedTab: SetupWindowTab

    init(initialTab: SetupWindowTab = .permissions) {
        _selectedTab = ViewState(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top Header & Tab Switcher
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .shadow(color: .blue.opacity(0.25), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Maxgus Picker 1824")
                        .font(.headline.bold())
                    Text("System permissions, multi-account features & Floating Chooser customization")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("", selection: $selectedTab) {
                    ForEach(SetupWindowTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 310)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(.bar)

            Divider()

            // Main Content
            if selectedTab == .permissions {
                permissionsTabContent
            } else {
                FeatureSettingsView()
            }

            Divider()

            // Bottom Status Bar
            HStack {
                if selectedTab == .permissions {
                    if systemService.isDefaultBrowser && systemService.isDefaultMailClient {
                        Label("All essential permissions configured!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Label("Set Maxgus Picker 1824 as your Default Browser to intercept links", systemImage: "info.circle.fill")
                            .foregroundStyle(systemService.isDefaultBrowser ? .green : .secondary)
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    Button("Customize Features & UX →") {
                        selectedTab = .features
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Label("Changes take effect immediately in the Floating Chooser & Rule Engine", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset Defaults") {
                        store.featureSettings = FeatureSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(.bar)
        }
        .frame(minWidth: 660, minHeight: 620)
    }

    private var permissionsTabContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                OnboardingStepCard(
                    stepNumber: 1,
                    title: "Set as Default Web Browser",
                    subtitle: "Allows Maxgus Picker 1824 to catch web links you click in any app.",
                    icon: "globe",
                    isCompleted: systemService.isDefaultBrowser,
                    buttonTitle: "Set Default Browser",
                    action: { systemService.requestDefaultBrowser() }
                )

                OnboardingStepCard(
                    stepNumber: 2,
                    title: "Set as Default Email Reader",
                    subtitle: "Allows Maxgus Picker 1824 to route mailto: links to specific mail apps.",
                    icon: "envelope.fill",
                    isCompleted: systemService.isDefaultMailClient,
                    buttonTitle: "Set Default Mail App",
                    action: { systemService.requestDefaultMailClient() }
                )

                OnboardingStepCard(
                    stepNumber: 3,
                    title: "Enable Safari & Arc Profile Automation",
                    subtitle: "Optional: Grant Accessibility access so Maxgus Picker 1824 can open specific Safari Profiles.",
                    icon: "person.2.badge.key.fill",
                    isCompleted: systemService.hasAccessibilityPermission,
                    buttonTitle: "Grant Access",
                    action: { systemService.requestAccessibilityPermission() }
                )

                OnboardingStepCard(
                    stepNumber: 4,
                    title: "Auto Start on Login",
                    subtitle: "Automatically launch Maxgus Picker 1824 in the menu bar when you sign in to macOS.",
                    icon: "power.circle.fill",
                    isCompleted: systemService.isLaunchAtLoginEnabled,
                    buttonTitle: "Enable Auto Start",
                    canToggleOff: true,
                    action: { systemService.toggleLaunchAtLogin() }
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

struct FeatureSettingsView: View {
    @ObservedObject var store = RulesStore.shared

    private var discoveredBrowserProfiles: [(app: AppTarget, profile: BrowserProfile)] {
        let browsers = AppDiscoveryService.shared.getAvailableHandlers(
            for: "https",
            sortRunningFirst: false,
            includeNativeHandoff: false,
            pinnedProfiles: []
        )
        var results: [(app: AppTarget, profile: BrowserProfile)] = []
        for browser in browsers {
            let profiles: [BrowserProfile]
            if browser.bundleID == "com.apple.Safari" {
                profiles = ProfileDiscoveryService.shared.fetchSafariProfiles()
            } else {
                profiles = ProfileDiscoveryService.shared.profiles(for: browser.bundleID)
            }
            for profile in profiles {
                results.append((browser, profile))
            }
        }
        return results
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // SECTION 1: Floating Chooser UX & Declutter
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Floating Chooser UX & Appearance", systemImage: "rectangle.on.rectangle.angled")
                                .font(.headline)
                            Spacer()
                            Text("Keep the chooser clean & focused")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        FeatureToggleRow(
                            title: "Pinned Profile Identities as Top-Level Tiles",
                            subtitle: "Show pinned Browser + Profile pairs (e.g. Chrome · Work) directly in the main chooser row.",
                            icon: "person.crop.rectangle.stack.fill",
                            color: .blue,
                            isOn: $store.featureSettings.showPinnedProfilesInChooser
                        )

                        FeatureToggleRow(
                            title: "Number Key Shortcuts (1–9)",
                            subtitle: "Display 1–9 shortcut badges on tiles and launch apps immediately with number keys.",
                            icon: "number.square.fill",
                            color: .indigo,
                            isOn: $store.featureSettings.showNumberShortcutsInChooser
                        )

                        FeatureToggleRow(
                            title: "Running Browser Status Dot (●)",
                            subtitle: "Show a green indicator dot on browsers that are currently active in macOS.",
                            icon: "circle.badge.checkmark.fill",
                            color: .green,
                            isOn: $store.featureSettings.showRunningIndicatorInChooser
                        )

                        FeatureToggleRow(
                            title: "Prioritize Running Browsers First",
                            subtitle: "Automatically sort currently running browsers to the left of the chooser.",
                            icon: "bolt.circle.fill",
                            color: .teal,
                            isOn: $store.featureSettings.prioritizeRunningBrowsers
                        )

                        FeatureToggleRow(
                            title: "Quick “Remember Domain” Button (⌘R)",
                            subtitle: "Show a 1-click Remember pill in the chooser header to save a domain rule on the fly.",
                            icon: "pin.circle.fill",
                            color: .blue,
                            isOn: $store.featureSettings.showRememberDomainInChooser
                        )

                        FeatureToggleRow(
                            title: "Private / Incognito Mode Button (⇧)",
                            subtitle: "Show the Private toggle pill in the chooser header (Shift key always works).",
                            icon: "eyeglasses",
                            color: .orange,
                            isOn: $store.featureSettings.showPrivateModeInChooser
                        )

                        FeatureToggleRow(
                            title: "Bottom Keyboard Shortcut Hint Bar",
                            subtitle: "Show subtle keyboard navigation hints at the bottom of the floating chooser.",
                            icon: "keyboard.fill",
                            color: .secondary,
                            isOn: $store.featureSettings.showKeyboardHintsInChooser
                        )
                    }
                    .padding(8)
                }

                // SECTION 2: Pinned Browser Profiles Manager
                if store.featureSettings.showPinnedProfilesInChooser {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Label("Pinned Browser Profiles (Top-Level Identities)", systemImage: "pin.fill")
                                    .font(.headline)
                                Spacer()
                                Menu {
                                    let all = discoveredBrowserProfiles
                                    if all.isEmpty {
                                        Text("No browser profiles detected")
                                    } else {
                                        ForEach(all, id: \.profile.id) { item in
                                            let isPinned = store.isProfilePinned(bundleID: item.app.bundleID, profileID: item.profile.id)
                                            Button {
                                                store.togglePinProfile(
                                                    bundleID: item.app.bundleID,
                                                    appName: item.app.name,
                                                    profile: item.profile
                                                )
                                            } label: {
                                                Label(
                                                    "\(item.app.name) — \(item.profile.displayName)",
                                                    systemImage: isPinned ? "checkmark.circle.fill" : "plus.circle"
                                                )
                                            }
                                        }
                                    }
                                } label: {
                                    Label("Pin a Profile...", systemImage: "plus")
                                }
                                .menuStyle(.borderedButton)
                                .controlSize(.small)
                                .fixedSize()
                            }

                            Text("Pin your most-used Work, Personal, or Client browser profiles so they appear as 1-key tiles in the chooser without opening submenus.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if store.pinnedProfiles.isEmpty {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                        .foregroundStyle(.secondary)
                                    Text("No profiles pinned yet. Click “Pin a Profile...” above or right-click any browser tile in the chooser.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            } else {
                                FlowLayoutPinnedProfiles(pinnedProfiles: store.pinnedProfiles) { item in
                                    store.togglePinProfile(
                                        bundleID: item.bundleID,
                                        appName: item.appName,
                                        profile: item.profile
                                    )
                                }
                            }
                        }
                        .padding(8)
                    }
                }

                // SECTION 3: Smart Routing & Multi-Account Features
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Smart Routing & Multi-Account Engine", systemImage: "cpu.fill")
                                .font(.headline)
                            Spacer()
                            Text("Enable only the advanced capabilities you need")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        FeatureToggleRow(
                            title: "Global Identity / Context Mode Switcher",
                            subtitle: "Switch between All Contexts, Work, Personal, and Client / Dev modes from the menu bar or Rules Manager.",
                            icon: "person.2.crop.square.stack.fill",
                            color: .purple,
                            isOn: $store.featureSettings.enableContextModeFiltering
                        )

                        FeatureToggleRow(
                            title: "Multi-Account URL Rewriting & Google authuser",
                            subtitle: "Allow rules to append ?authuser=email@company.com or rewrite domains/paths before opening.",
                            icon: "arrow.triangle.2.circlepath.circle.fill",
                            color: .blue,
                            isOn: $store.featureSettings.enableURLRewriteRules
                        )

                        FeatureToggleRow(
                            title: "Shortlink Unfurling (bit.ly, t.co, tinyurl, lnkd.in)",
                            subtitle: "Automatically expand shortened links in the chooser header so you see the real destination domain.",
                            icon: "link.badge.plus",
                            color: .green,
                            isOn: $store.featureSettings.expandShortlinksEnabled
                        )

                        FeatureToggleRow(
                            title: "Strip Tracking Parameters & Unwrap Redirects",
                            subtitle: "Remove utm_*, fbclid, gclid and unwrap Slack/Google/Outlook redirect wrappers.",
                            icon: "sparkles",
                            color: .mint,
                            isOn: $store.featureSettings.sanitizeURLsEnabled
                        )

                        FeatureToggleRow(
                            title: "Native Desktop App Handoff",
                            subtitle: "Show Zoom, Teams, Slack, Linear, Notion, Figma, Discord, or Spotify when a link matches.",
                            icon: "arrow.up.forward.app.fill",
                            color: .cyan,
                            isOn: $store.featureSettings.nativeAppHandoffEnabled
                        )

                        FeatureToggleRow(
                            title: "Work Hours & Day-of-Week Rule Schedules",
                            subtitle: "Allow routing rules to be restricted to specific days and hours.",
                            icon: "clock.badge.checkmark.fill",
                            color: .orange,
                            isOn: $store.featureSettings.enableTimeScheduledRules
                        )

                        HStack {
                            FeatureToggleRow(
                                title: "Rule Hit Counters & Activity Insights",
                                subtitle: "Display how many times each routing rule has matched in the Rules Manager.",
                                icon: "chart.bar.fill",
                                color: .pink,
                                isOn: $store.featureSettings.showRuleHitStats
                            )

                            if store.featureSettings.showRuleHitStats {
                                Button("Reset Counts") {
                                    store.resetAllRuleHitStats()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .padding(20)
        }
    }
}

struct FeatureToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? color : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isOn ? color.opacity(0.14) : Color.secondary.opacity(0.1))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.vertical, 3)
    }
}

struct FlowLayoutPinnedProfiles: View {
    let pinnedProfiles: [PinnedProfileIdentity]
    let onRemove: (PinnedProfileIdentity) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 185), spacing: 8)], spacing: 8) {
            ForEach(pinnedProfiles) { item in
                HStack(spacing: 6) {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("\(item.appName) • \(item.profile.displayName)")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    Button {
                        onRemove(item)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Unpin profile from chooser")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

struct OnboardingStepCard: View {
    let stepNumber: Int
    let title: String
    let subtitle: String
    let icon: String
    let isCompleted: Bool
    let buttonTitle: String
    var canToggleOff: Bool = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.12))
                    .frame(width: 40, height: 40)

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isCompleted {
                if canToggleOff {
                    Button {
                        action()
                    } label: {
                        Text("Active")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.green.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Click to disable Auto Start on Login")
                } else {
                    Text("Active")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.green.opacity(0.12), in: Capsule())
                }
            } else {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isCompleted ? Color.green.opacity(0.4) : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
    }
}
