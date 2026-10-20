import AppKit
import Combine
import SwiftUI

typealias ViewState<Value> = SwiftUI.State<Value>

final class PickerSelectionModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var isURLPreviewExpanded: Bool = false
    @Published var didCopyURL: Bool = false
    @Published var isPrivateModePreview: Bool = false
    @Published var rememberDomainForRule: Bool = false
    @Published var expandedShortlinkURL: URL? = nil
    @Published var isExpandingShortlink: Bool = false

    let apps: [AppTarget]
    let url: URL

    init(apps: [AppTarget], url: URL) {
        self.apps = apps
        self.url = url
        self.selectedIndex = 0
    }

    var effectiveURL: URL {
        expandedShortlinkURL ?? url
    }

    var selectedApp: AppTarget? {
        guard !apps.isEmpty, apps.indices.contains(selectedIndex) else { return nil }
        return apps[selectedIndex]
    }

    func moveLeft() {
        guard !apps.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + apps.count) % apps.count
    }

    func moveRight() {
        guard !apps.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % apps.count
    }

    func toggleURLPreview() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isURLPreviewExpanded.toggle()
        }
    }

    func toggleRememberDomain() {
        withAnimation(.easeInOut(duration: 0.15)) {
            rememberDomainForRule.toggle()
        }
    }

    func togglePrivateMode() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isPrivateModePreview.toggle()
        }
    }

    func copyURLToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let targetURL = effectiveURL
        let stringToCopy: String
        if targetURL.scheme?.lowercased() == "mailto" {
            stringToCopy = URLComponents(url: targetURL, resolvingAgainstBaseURL: false)?.path ?? targetURL.absoluteString
        } else {
            stringToCopy = targetURL.absoluteString
        }
        pasteboard.setString(stringToCopy, forType: .string)
        withAnimation(.easeInOut(duration: 0.15)) {
            didCopyURL = true
        }
    }
}

struct FloatingSelectorView: View {
    let url: URL
    var sourceApp: SourceAppInfo? = nil
    @ObservedObject var selectionModel: PickerSelectionModel
    @ObservedObject var store = RulesStore.shared
    let iconSize: CGFloat
    let tileWidth: CGFloat
    let onSelect: (AppTarget) -> Void
    var onOpenSettings: (() -> Void)? = nil
    var onClose: (() -> Void)? = nil

    private var displayHeader: String {
        let current = selectionModel.effectiveURL
        if current.scheme?.lowercased() == "mailto" {
            return URLComponents(url: current, resolvingAgainstBaseURL: false)?.path ?? current.absoluteString
        }
        if let expanded = selectionModel.expandedShortlinkURL,
           let origHost = url.host,
           let destHost = expanded.host,
           origHost.caseInsensitiveCompare(destHost) != .orderedSame {
            return "\(origHost) → \(destHost)"
        }
        return current.host ?? current.absoluteString
    }

    var body: some View {
        VStack(spacing: 10) {
            // MARK: - Top Header Bar (Domain Pill + Drag Grip + Quick Action Pills)
            HStack(spacing: 6) {
                // URL / Email Preview Pill (click or press Space to expand full URL)
                Button {
                    selectionModel.toggleURLPreview()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: url.scheme?.lowercased() == "mailto" ? "envelope.fill" : "link")
                            .foregroundStyle(selectionModel.expandedShortlinkURL != nil ? .green : .secondary)
                        Text(displayHeader)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if selectionModel.isExpandingShortlink {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        if let src = sourceApp {
                            Text("• \(src.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if store.featureSettings.enableContextModeFiltering && store.activeContext != .all {
                            Text("• \(store.activeContext.rawValue)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                        Image(systemName: selectionModel.isURLPreviewExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.5), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("\(selectionModel.effectiveURL.absoluteString) (Click or press Space to inspect full URL)")

                // Quick Copy URL Button (⌘C)
                Button {
                    selectionModel.copyURLToPasteboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectionModel.didCopyURL ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .semibold))
                        if selectionModel.didCopyURL {
                            Text("Copied")
                                .font(.caption2.weight(.semibold))
                        }
                    }
                    .foregroundStyle(selectionModel.didCopyURL ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.4), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Copy clean URL to clipboard (⌘C)")

                Spacer(minLength: 4)

                // Subtle Drag Grip Indicator
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 28, height: 4)
                    .help("Drag anywhere on the panel to move")

                Spacer(minLength: 4)

                // Interactive "Remember Domain" Quick-Rule Toggle Pill (⌘R)
                if store.featureSettings.showRememberDomainInChooser {
                    Button {
                        selectionModel.toggleRememberDomain()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: selectionModel.rememberDomainForRule ? "pin.fill" : "pin")
                                .font(.system(size: 10, weight: .semibold))
                            Text("Remember")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(selectionModel.rememberDomainForRule ? .blue : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(selectionModel.rememberDomainForRule ? Color.blue.opacity(0.18) : Color.secondary.opacity(0.12))
                                .overlay(
                                    Capsule().strokeBorder(
                                        selectionModel.rememberDomainForRule ? Color.blue.opacity(0.5) : Color.clear,
                                        lineWidth: 1
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Save a routing rule for this domain when you pick an app (⌘R)")
                }

                // Interactive Private / Incognito Toggle Pill (Shift or Click)
                if store.featureSettings.showPrivateModeInChooser && url.scheme?.lowercased() != "mailto" {
                    Button {
                        selectionModel.togglePrivateMode()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "eyeglasses")
                                .font(.system(size: 10, weight: .bold))
                            Text("Private")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(selectionModel.isPrivateModePreview ? .orange : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(selectionModel.isPrivateModePreview ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.12))
                                .overlay(
                                    Capsule().strokeBorder(
                                        selectionModel.isPrivateModePreview ? Color.orange.opacity(0.45) : Color.clear,
                                        lineWidth: 1
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Open in Private / Incognito window (Click or hold ⇧ Shift)")
                }

                // Quick Chooser UX Settings Button
                if let onOpenSettings = onOpenSettings {
                    Button {
                        onOpenSettings()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(5)
                            .background(.quaternary.opacity(0.35), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Customize Chooser Features & UX Settings")
                }

                if let onClose = onClose {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close (Esc)")
                }
            }
            .contentShape(Rectangle())
            .background(WindowDragHandler())

            // MARK: - Optional Expanded Full URL / Shortlink Inspector
            if selectionModel.isURLPreviewExpanded {
                VStack(alignment: .leading, spacing: 3) {
                    if let expanded = selectionModel.expandedShortlinkURL,
                       expanded.absoluteString != url.absoluteString {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("Unfurled destination: \(expanded.absoluteString)")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.green)
                                .lineLimit(2)
                                .truncationMode(.middle)
                        }
                    } else {
                        Text(selectionModel.effectiveURL.absoluteString)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // MARK: - App & Identity Tiles Row
            if selectionModel.apps.isEmpty {
                Text("No compatible applications found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(Array(selectionModel.apps.enumerated()), id: \.element.id) { index, app in
                                AppSelectorTile(
                                    app: app,
                                    shortcutNumber: (store.featureSettings.showNumberShortcutsInChooser && index < 9) ? (index + 1) : nil,
                                    showRunningDot: store.featureSettings.showRunningIndicatorInChooser,
                                    isSelected: selectionModel.selectedIndex == index,
                                    iconSize: iconSize,
                                    tileWidth: tileWidth,
                                    onHoverChange: { hovering in
                                        if hovering {
                                            selectionModel.selectedIndex = index
                                        }
                                    },
                                    onPick: { targetWithOptionalProfile in
                                        selectionModel.selectedIndex = index
                                        var chosen = targetWithOptionalProfile
                                        if selectionModel.isPrivateModePreview || NSEvent.modifierFlags.contains(.shift) {
                                            chosen.openInPrivateMode = true
                                        }
                                        onSelect(chosen)
                                    }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectionModel.selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }

            // MARK: - Optional Clean Keyboard Navigation Hint Bar
            if store.featureSettings.showKeyboardHintsInChooser {
                HStack(spacing: 14) {
                    Label(
                        store.featureSettings.showNumberShortcutsInChooser ? "← → / 1–9 Select" : "← → Select",
                        systemImage: "keyboard"
                    )
                    Label("⏎ Open", systemImage: "return")
                    if store.featureSettings.showPrivateModeInChooser {
                        Label("⇧ Private", systemImage: "eyeglasses")
                    }
                    if store.featureSettings.showRememberDomainInChooser {
                        Label("⌘R Remember", systemImage: "pin")
                    }
                    Label("Space URL", systemImage: "text.magnifyingglass")
                    Label("Esc Close", systemImage: "escape")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                WindowDragHandler()
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        )
    }
}

/// Transparent AppKit view that initiates native window dragging on mouse-down/drag.
private struct WindowDragHandler: NSViewRepresentable {
    func makeNSView(context: Context) -> DraggableNSView {
        DraggableNSView()
    }

    func updateNSView(_ nsView: DraggableNSView, context: Context) {}

    final class DraggableNSView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

struct AppSelectorTile: View {
    let app: AppTarget
    let shortcutNumber: Int?
    let showRunningDot: Bool
    let isSelected: Bool
    let iconSize: CGFloat
    let tileWidth: CGFloat
    let onHoverChange: (Bool) -> Void
    let onPick: (AppTarget) -> Void

    @ObservedObject private var store = RulesStore.shared

    private var profiles: [BrowserProfile] {
        if app.bundleID == "com.apple.Safari" {
            return ProfileDiscoveryService.shared.fetchSafariProfiles()
        }
        return ProfileDiscoveryService.shared.profiles(for: app.bundleID)
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topLeading) {
                Button {
                    onPick(app)
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: iconSize, height: iconSize)

                        // Pinned Profile Badge Overlay
                        if let pinnedProfile = app.profile {
                            Text(pinnedProfile.displayName)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                                )
                                .offset(y: 4)
                        } else if showRunningDot && app.isRunning {
                            // Green dot indicator when the application is currently running
                            Circle()
                                .fill(Color.green)
                                .frame(width: 10, height: 10)
                                .overlay(
                                    Circle()
                                        .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1.5)
                                )
                                .offset(x: 2, y: 2)
                                .help("\(app.name) is currently running")
                        }
                    }
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Open in \(app.displayTitle)") { onPick(app) }
                    Button("Open in Private / Incognito Window") {
                        var privateTarget = app
                        privateTarget.openInPrivateMode = true
                        onPick(privateTarget)
                    }
                    if let currentProfile = app.profile {
                        Divider()
                        Button("Unpin “\(currentProfile.displayName)” from Chooser") {
                            store.togglePinProfile(bundleID: app.bundleID, appName: app.name, profile: currentProfile)
                        }
                    } else if !profiles.isEmpty {
                        Divider()
                        ForEach(profiles) { profile in
                            Button("Open in Profile: \(profile.displayName)") {
                                var modified = app
                                modified.profile = profile
                                onPick(modified)
                            }
                        }
                        Divider()
                        Menu("Pin Profile as Top-Level Chooser Tile") {
                            ForEach(profiles) { profile in
                                let isPinned = store.isProfilePinned(bundleID: app.bundleID, profileID: profile.id)
                                Button {
                                    store.togglePinProfile(bundleID: app.bundleID, appName: app.name, profile: profile)
                                } label: {
                                    Label(
                                        isPinned ? "Unpin \(profile.displayName)" : "Pin \(profile.displayName)",
                                        systemImage: isPinned ? "pin.slash" : "pin.fill"
                                    )
                                }
                            }
                        }
                    }
                }

                // Number Shortcut Badge (1-9)
                if let num = shortcutNumber {
                    Text("\(num)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.22))
                        )
                        .offset(x: -8, y: -4)
                }
            }

            // Label & Optional Profile Selector
            if app.isNativeAppHandoff {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.forward.app.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue)
                    Text(app.name)
                        .font(.caption.weight(isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                }
            } else if let pinnedProfile = app.profile {
                VStack(spacing: 1) {
                    Text(app.name)
                        .font(.caption.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .lineLimit(1)
                    Text(pinnedProfile.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                }
            } else if profiles.isEmpty {
                Text(app.name)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            } else {
                Menu {
                    Button("Default Window") { onPick(app) }
                    Button("Private / Incognito Window") {
                        var privateTarget = app
                        privateTarget.openInPrivateMode = true
                        onPick(privateTarget)
                    }
                    Divider()
                    ForEach(profiles) { profile in
                        Button(profile.displayName) {
                            var modified = app
                            modified.profile = profile
                            onPick(modified)
                        }
                    }
                    Divider()
                    Menu("Pin Identity to Chooser...") {
                        ForEach(profiles) { profile in
                            let isPinned = store.isProfilePinned(bundleID: app.bundleID, profileID: profile.id)
                            Button {
                                store.togglePinProfile(bundleID: app.bundleID, appName: app.name, profile: profile)
                            } label: {
                                Label(
                                    isPinned ? "Unpin \(profile.displayName)" : "Pin \(profile.displayName)",
                                    systemImage: isPinned ? "pin.slash" : "pin.fill"
                                )
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(app.name)
                            .font(.caption.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .frame(width: tileWidth)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: isSelected ? 2.5 : 1
                )
        )
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .onHover { hovering in
            onHoverChange(hovering)
        }
    }
}
