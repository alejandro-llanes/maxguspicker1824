import AppKit
import Combine
import SwiftUI

typealias ViewState<Value> = SwiftUI.State<Value>

final class PickerSelectionModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    let apps: [AppTarget]

    init(apps: [AppTarget]) {
        self.apps = apps
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
        VStack(spacing: 14) {
            // Top Drag Handle + Header Bar
            HStack(spacing: 8) {
                // URL / Email Preview Pill
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
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.quaternary.opacity(0.5), in: Capsule())

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

            // App Icons Row with Keyboard Selection Highlight
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
                                        onSelect(targetWithOptionalProfile)
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
            HStack(spacing: 16) {
                Label("← → Select", systemImage: "arrow.left.arrow.right")
                Label("⏎ Open", systemImage: "return")
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
            Button {
                onPick(app)
            } label: {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: iconSize, height: iconSize)
            }
            .buttonStyle(.plain)
            .contextMenu {
                if !profiles.isEmpty {
                    Button("Default Window") { onPick(app) }
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

            if profiles.isEmpty {
                Text(app.name)
                    .font(.caption.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            } else {
                // Dropdown menu for profiles right under the browser icon
                Menu {
                    Button("Default Window") { onPick(app) }
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
