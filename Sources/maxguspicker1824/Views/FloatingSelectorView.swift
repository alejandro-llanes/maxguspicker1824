import AppKit
import Combine
import SwiftUI

typealias ViewState<Value> = SwiftUI.State<Value>

final class PickerSelectionModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var isURLPreviewExpanded: Bool = false
    @Published var didCopyURL: Bool = false
    @Published var isPrivateModePreview: Bool = false
    let apps: [AppTarget]
    let url: URL

    init(apps: [AppTarget], url: URL) {
        self.apps = apps
        self.url = url
        self.selectedIndex = 0
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

    func copyURLToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let stringToCopy: String
        if url.scheme?.lowercased() == "mailto" {
            stringToCopy = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? url.absoluteString
        } else {
            stringToCopy = url.absoluteString
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
    let iconSize: CGFloat
    let tileWidth: CGFloat
    let onSelect: (AppTarget) -> Void
    var onClose: (() -> Void)? = nil

    private var displayHeader: String {
        if url.scheme?.lowercased() == "mailto" {
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? url.absoluteString
        }
        return url.host ?? url.absoluteString
    }

    var body: some View {
        VStack(spacing: 12) {
            // Top Drag Handle + Header Bar
            HStack(spacing: 8) {
                // URL / Email Preview Pill (click or press Space to expand full URL)
                Button {
                    selectionModel.toggleURLPreview()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: url.scheme?.lowercased() == "mailto" ? "envelope.fill" : "link")
                            .foregroundStyle(.secondary)
                        Text(displayHeader)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if let src = sourceApp {
                            Text("• \(src.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Image(systemName: selectionModel.isURLPreviewExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.5), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("\(url.absoluteString) (Click or press Space to toggle full URL)")

                // Quick Copy URL Button (⌘C)
                Button {
                    selectionModel.copyURLToPasteboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: selectionModel.didCopyURL ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
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

                if selectionModel.isPrivateModePreview {
                    HStack(spacing: 4) {
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 10, weight: .bold))
                        Text("Private Mode")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.18))
                            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.45), lineWidth: 1))
                    )
                }

                Spacer(minLength: 4)

                // Subtle Drag Grip Indicator
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 34, height: 4)
                    .help("Drag anywhere on the panel to move")

                Spacer(minLength: 4)

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

            // Optional Expanded Full URL Preview Banner (toggled via Space or clicking domain pill)
            if selectionModel.isURLPreviewExpanded {
                HStack {
                    Text(url.absoluteString)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            // App Icons Row with Keyboard Selection Highlight & Number Badges
            if selectionModel.apps.isEmpty {
                Text("No compatible applications found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(Array(selectionModel.apps.enumerated()), id: \.element.id) { index, app in
                                AppSelectorTile(
                                    app: app,
                                    shortcutNumber: index < 9 ? (index + 1) : nil,
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
                                        if NSEvent.modifierFlags.contains(.shift) {
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

            // Subtle Keyboard Navigation Hint Bar
            HStack(spacing: 14) {
                Label("← → / 1–9 Select", systemImage: "keyboard")
                Label("⏎ Open", systemImage: "return")
                Label("⇧⏎ Private", systemImage: "eyeglasses")
                Label("⌘C Copy", systemImage: "doc.on.doc")
                Label("Esc Dismiss", systemImage: "escape")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(18)
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
    let isSelected: Bool
    let iconSize: CGFloat
    let tileWidth: CGFloat
    let onHoverChange: (Bool) -> Void
    let onPick: (AppTarget) -> Void

    private var profiles: [BrowserProfile] {
        if app.bundleID == "com.apple.Safari" {
            return ProfileDiscoveryService.shared.fetchSafariProfiles()
        }
        return ProfileDiscoveryService.shared.profiles(for: app.bundleID)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Button {
                    onPick(app)
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: iconSize, height: iconSize)

                        // Green dot indicator when the application is currently running
                        if app.isRunning {
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
                    Button("Open in Default Window") { onPick(app) }
                    Button("Open in Private / Incognito Window") {
                        var privateTarget = app
                        privateTarget.openInPrivateMode = true
                        onPick(privateTarget)
                    }
                    if !profiles.isEmpty {
                        Divider()
                        ForEach(profiles) { profile in
                            Button(profile.displayName) {
                                var modified = app
                                modified.profile = profile
                                onPick(modified)
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
            } else if profiles.isEmpty {
                Text(app.name)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            } else {
                // Dropdown menu for profiles right under the browser icon
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
