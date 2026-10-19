import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RuleBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existingRule: RoutingRule?
    let onSave: (RoutingRule) -> Void

    @ViewState private var name: String = ""
    @ViewState private var type: RouteType = .web
    @ViewState private var selectedSourceApp: SourceAppInfo? = nil
    @ViewState private var field: MatchField = .domain
    @ViewState private var matchOperator: MatchOperator = .contains
    @ViewState private var value: String = ""

    @ViewState private var availableApps: [AppTarget] = []
    @ViewState private var selectedAppBundleID: String = ""
    @ViewState private var availableProfiles: [BrowserProfile] = []
    @ViewState private var selectedProfile: BrowserProfile? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingRule == nil ? "Create Routing Rule" : "Edit Routing Rule")
                    .font(.title3.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // STEP 1: Link Type & Name
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("1. Choose Link Type & Name", systemImage: "1.circle.fill")
                                .font(.headline)

                            Picker("Link Type", selection: $type) {
                                ForEach(RouteType.allCases) { routeType in
                                    Label(routeType.rawValue, systemImage: routeType.icon).tag(routeType)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: type) { _, newType in
                                if !MatchField.fields(for: newType).contains(field) {
                                    field = MatchField.fields(for: newType).first ?? .domain
                                }
                                reloadInstalledApps(for: newType)
                            }

                            TextField("Rule Name (e.g. Work GitHub, Company Emails)", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(8)
                    }

                    // STEP 2: Condition Builder
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("2. When a link matches this condition", systemImage: "2.circle.fill")
                                .font(.headline)

                            SourceAppPickerRow(selectedSourceApp: $selectedSourceApp)

                            Divider()

                            HStack(spacing: 10) {
                                Picker("", selection: $field) {
                                    ForEach(MatchField.fields(for: type)) { f in
                                        Text(f.rawValue).tag(f)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 210)

                                Picker("", selection: $matchOperator) {
                                    ForEach(MatchOperator.allCases) { op in
                                        Text(op.rawValue).tag(op)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 170)

                                TextField(field.placeholder, text: $value)
                                    .textFieldStyle(.roundedBorder)
                            }

                            // Plain-English preview
                            let cleanVal = value.trimmingCharacters(in: .whitespaces)
                            if !cleanVal.isEmpty || selectedSourceApp != nil {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.bubble.fill")
                                        .foregroundStyle(.blue)
                                    Text(previewMarkdown(cleanValue: cleanVal))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .padding(8)
                    }

                    // STEP 3: Target App & Profile
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("3. Open automatically in", systemImage: "3.circle.fill")
                                .font(.headline)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                                ForEach(availableApps, id: \.bundleID) { app in
                                    let isSelected = (app.bundleID == selectedAppBundleID)
                                    Button {
                                        selectApp(app.bundleID)
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(nsImage: app.icon)
                                                .resizable()
                                                .frame(width: 40, height: 40)
                                            Text(app.name)
                                                .font(.caption.weight(.medium))
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(
                                                    isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                                                    lineWidth: isSelected ? 2 : 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Profile / Space Picker (if the selected browser has profiles)
                            if !availableProfiles.isEmpty {
                                Divider().padding(.vertical, 4)
                                HStack {
                                    Label("Browser Profile / Space:", systemImage: "person.crop.circle.badge.checkmark")
                                        .font(.subheadline.weight(.medium))

                                    Picker("", selection: $selectedProfile) {
                                        Text("Default / Last Active Window").tag(BrowserProfile?.none)
                                        ForEach(availableProfiles) { profile in
                                            Text(profile.displayName).tag(BrowserProfile?.some(profile))
                                        }
                                    }
                                    .frame(maxWidth: 260)
                                }
                            }
                        }
                        .padding(8)
                    }
                }
                .padding(20)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Save Rule") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled((value.trimmingCharacters(in: .whitespaces).isEmpty && selectedSourceApp == nil) || selectedAppBundleID.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 620, height: 580)
        .onAppear {
            setupInitialState()
        }
    }

    private func previewMarkdown(cleanValue: String) -> LocalizedStringKey {
        if let src = selectedSourceApp, !cleanValue.isEmpty {
            return "Will trigger when clicked in **\(src.name)** and **\(field.rawValue.lowercased())** \(matchOperator.rawValue) **“\(cleanValue)”**"
        } else if let src = selectedSourceApp {
            return "Will trigger for any **\(type.rawValue.lowercased())** link clicked inside **\(src.name)**"
        } else {
            return "Will trigger when **\(field.rawValue.lowercased())** \(matchOperator.rawValue) **“\(cleanValue)”**"
        }
    }

    private func setupInitialState() {
        if let rule = existingRule {
            name = rule.name
            type = rule.type
            selectedSourceApp = rule.sourceApp
            field = rule.field
            matchOperator = rule.matchOperator
            value = rule.value
            reloadInstalledApps(for: rule.type)
            selectApp(rule.targetAppBundleID)
            selectedProfile = rule.targetProfile
        } else {
            reloadInstalledApps(for: .web)
        }
    }

    private func reloadInstalledApps(for routeType: RouteType) {
        let scheme = (routeType == .mail) ? "mailto" : "https"
        availableApps = AppDiscoveryService.shared.getAvailableHandlers(for: scheme)
        if !availableApps.contains(where: { $0.bundleID == selectedAppBundleID }),
           let first = availableApps.first {
            selectApp(first.bundleID)
        }
    }

    private func selectApp(_ bundleID: String) {
        selectedAppBundleID = bundleID
        selectedProfile = nil
        if bundleID == "com.apple.Safari" {
            availableProfiles = ProfileDiscoveryService.shared.fetchSafariProfiles()
        } else {
            availableProfiles = ProfileDiscoveryService.shared.profiles(for: bundleID)
        }
    }

    private func save() {
        let appName = availableApps.first(where: { $0.bundleID == selectedAppBundleID })?.name ?? "App"
        let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let sourceOrValue = cleanValue.isEmpty ? (selectedSourceApp?.name ?? "Link") : cleanValue
        let finalName = name.trimmingCharacters(in: .whitespaces).isEmpty
            ? "\(sourceOrValue) → \(appName)"
            : name

        let rule = RoutingRule(
            id: existingRule?.id ?? UUID(),
            name: finalName,
            type: type,
            sourceApp: selectedSourceApp,
            field: field,
            matchOperator: matchOperator,
            value: cleanValue,
            targetAppBundleID: selectedAppBundleID,
            targetAppName: appName,
            targetProfile: selectedProfile,
            isEnabled: existingRule?.isEnabled ?? true
        )
        onSave(rule)
        dismiss()
    }
}

struct SourceAppPickerRow: View {
    @Binding var selectedSourceApp: SourceAppInfo?

    // Common apps people click links in, plus currently running apps
    private var suggestedApps: [SourceAppInfo] {
        let myBundleID = Bundle.main.bundleIdentifier ?? "com.maxguspicker1824.app"
        let running = NSWorkspace.shared.runningApplications.compactMap { app -> SourceAppInfo? in
            guard app.activationPolicy == .regular,
                  let bundleID = app.bundleIdentifier,
                  bundleID != myBundleID,
                  bundleID != "com.maxguspicker1824.app",
                  let name = app.localizedName else { return nil }
            return SourceAppInfo(bundleID: bundleID, name: name)
        }
        return Array(Set(running)).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        HStack {
            Label("Clicked inside App:", systemImage: "macwindow.on.rectangle")
                .font(.subheadline.weight(.medium))

            Menu {
                Button("Any Application (No Filter)") {
                    selectedSourceApp = nil
                }
                Divider()
                ForEach(suggestedApps, id: \.bundleID) { app in
                    Button {
                        selectedSourceApp = app
                    } label: {
                        Text(app.name)
                    }
                }
                Divider()
                Button("Browse Applications...") {
                    pickAppFromFinder()
                }
            } label: {
                HStack(spacing: 6) {
                    if let source = selectedSourceApp,
                       let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleID) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(source.name)
                    } else {
                        Text("Any Application")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 240)

            Spacer()
        }
    }

    private func pickAppFromFinder() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK,
           let appURL = panel.url,
           let bundle = Bundle(url: appURL),
           let bundleID = bundle.bundleIdentifier {
            let rawName = FileManager.default.displayName(atPath: appURL.path)
            let name = rawName.hasSuffix(".app") ? String(rawName.dropLast(4)) : rawName
            selectedSourceApp = SourceAppInfo(bundleID: bundleID, name: name)
        }
    }
}
