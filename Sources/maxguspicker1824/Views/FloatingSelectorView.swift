import AppKit
import SwiftUI

typealias ViewState<Value> = SwiftUI.State<Value>

struct FloatingSelectorView: View {
    let url: URL
    var sourceApp: SourceAppInfo? = nil
    let apps: [AppTarget]
    let onSelect: (AppTarget, Bool) -> Void
    var onClose: (() -> Void)? = nil

    @ViewState private var alwaysUseForHost = false

    private var displayHeader: String {
        if url.scheme?.lowercased() == "mailto" {
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?.path ?? url.absoluteString
        }
        return url.host ?? url.absoluteString
    }

    var body: some View {
        VStack(spacing: 10) {
            // Top Drag Handle + Header Bar
            HStack(spacing: 8) {
                // URL / Email Preview Pill
                HStack(spacing: 6) {
                    Image(systemName: url.scheme?.lowercased() == "mailto" ? "envelope.fill" : "link")
                        .foregroundStyle(.secondary)
                    Text(displayHeader)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let src = sourceApp {
                        Text("• \(src.name)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.5), in: Capsule())

                Spacer(minLength: 4)

                // Subtle Drag Grip Indicator
                Capsule()
                    .fill(.tertiary)
                    .frame(width: 28, height: 4)
                    .help("Drag anywhere on the panel to move")

                Spacer(minLength: 4)

                if let onClose = onClose {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close (Esc)")
                }
            }
            .contentShape(Rectangle())
            .background(WindowDragHandler())

            // App Icons Row
            if apps.isEmpty {
                Text("No compatible applications found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(apps) { app in
                            AppSelectorTile(app: app) { targetWithOptionalProfile in
                                onSelect(targetWithOptionalProfile, alwaysUseForHost)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            Divider()

            // One-Click Rule Creation Checkbox
            HStack {
                Toggle(isOn: $alwaysUseForHost) {
                    Text("Always open **\(displayHeader)** with chosen app")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                WindowDragHandler()
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.2), lineWidth: 1)
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
    let onPick: (AppTarget) -> Void

    private var profiles: [BrowserProfile] {
        if app.bundleID == "com.apple.Safari" {
            return ProfileDiscoveryService.shared.fetchSafariProfiles()
        }
        return ProfileDiscoveryService.shared.profiles(for: app.bundleID)
    }

    var body: some View {
        VStack(spacing: 5) {
            Button {
                onPick(app)
            } label: {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 46, height: 46)
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
                    .font(.caption2)
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
                    HStack(spacing: 2) {
                        Text(app.name)
                            .font(.caption2)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }
}
