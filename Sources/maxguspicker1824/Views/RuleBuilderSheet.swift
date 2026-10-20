import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RuleBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store = RulesStore.shared

    let existingRule: RoutingRule?
    var templateRule: RoutingRule? = nil
    let onSave: (RoutingRule) -> Void

    @ViewState private var name: String = ""
    @ViewState private var type: RouteType = .web
    @ViewState private var selectedSourceApp: SourceAppInfo? = nil
    @ViewState private var field: MatchField = .domain
    @ViewState private var matchOperator: MatchOperator = .contains
    @ViewState private var value: String = ""

    // Schedule state
    @ViewState private var scheduleEnabled: Bool = false
    @ViewState private var scheduleDays: Set<Int> = [2, 3, 4, 5, 6]
    @ViewState private var scheduleStartHour: Int = 9
    @ViewState private var scheduleEndHour: Int = 18

    // Destination state
    @ViewState private var availableApps: [AppTarget] = []
    @ViewState private var selectedAppBundleID: String = ""
    @ViewState private var availableProfiles: [BrowserProfile] = []
    @ViewState private var selectedProfile: BrowserProfile? = nil
    @ViewState private var openInPrivateMode: Bool = false

    private let orderedWeekdays: [(id: Int, label: String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text(existingRule == nil ? "Create Routing Rule" : "Edit Routing Rule")
                    .font(.title3.bold())

                Spacer()

                // Quick Fill from Presets
                Menu {
                    ForEach(RuleTemplatePreset.builtInPresets) { preset in
                        Button {
                            applyRuleTemplate(preset.toRoutingRule(defaultApp: availableApps.first))
                        } label: {
                            Label(preset.title, systemImage: preset.icon)
                        }
                    }
                } label: {
                    Label("Templates", systemImage: "sparkles.rectangle.stack")
                }
                .menuStyle(.borderedButton)
                .controlSize(.regular)
                .fixedSize()

                // Quick Fill from History Menu
                if !store.recentActivity.isEmpty {
                    Menu {
                        ForEach(store.recentActivity) { record in
                            Button {
                                applyRuleTemplate(record.toRoutingRule())
                            } label: {
                                Text(record.displaySummary)
                            }
                        }
                    } label: {
                        Label("Fill from History", systemImage: "clock.arrow.circlepath")
                    }
                    .menuStyle(.borderedButton)
                    .controlSize(.regular)
                    .fixedSize()
                }

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

                    // STEP 2: Condition Builder + Schedule
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

                            Divider()

                            // Optional Work Hours / Schedule Filter
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(isOn: $scheduleEnabled) {
                                    Label("Only active during specific days & hours (Work Hours / Schedule)", systemImage: "clock.badge.checkmark")
                                        .font(.subheadline.weight(.medium))
                                }
                                .toggleStyle(.checkbox)

                                if scheduleEnabled {
                                    HStack(spacing: 6) {
                                        ForEach(orderedWeekdays, id: \.id) { day in
                                            let isSelected = scheduleDays.contains(day.id)
                                            Button {
                                                if isSelected && scheduleDays.count > 1 {
                                                    scheduleDays.remove(day.id)
                                                } else {
                                                    scheduleDays.insert(day.id)
                                                }
                                            } label: {
                                                Text(day.label)
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule()
                                                            .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
                                                    )
                                                    .foregroundStyle(isSelected ? .white : .primary)
                                            }
                                            .buttonStyle(.plain)
                                        }

                                        Spacer()

                                        Picker("From", selection: $scheduleStartHour) {
                                            ForEach(0..<24, id: \.self) { hour in
                                                Text(String(format: "%02d:00", hour)).tag(hour)
                                            }
                                        }
                                        .frame(width: 110)

                                        Picker("To", selection: $scheduleEndHour) {
                                            ForEach(0..<24, id: \.self) { hour in
                                                Text(String(format: "%02d:00", hour)).tag(hour)
                                            }
                                        }
                                        .frame(width: 100)
                                    }
                                }
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

                    // STEP 3: Target App, Profile & Private Mode
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

                            // Profile / Space Picker & Private / Incognito Mode
                            if !availableProfiles.isEmpty || type == .web {
                                Divider().padding(.vertical, 4)
                                HStack(spacing: 16) {
                                    if !availableProfiles.isEmpty {
                                        Label("Profile / Space:", systemImage: "person.crop.circle.badge.checkmark")
                                            .font(.subheadline.weight(.medium))

                                        Picker("", selection: $selectedProfile) {
                                            Text("Default / Last Active Window").tag(BrowserProfile?.none)
                                            ForEach(availableProfiles) { profile in
                                                Text(profile.displayName).tag(BrowserProfile?.some(profile))
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(maxWidth: 220)
                                    }

                                    if type == .web {
                                        Toggle(isOn: $openInPrivateMode) {
                                            Label("Open in Private / Incognito Window", systemImage: "eyeglasses")
                                                .font(.subheadline)
                                        }
                                        .toggleStyle(.checkbox)
                                    }

                                    Spacer()
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
        .frame(width: 660, height: 730)
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
        if let rule = existingRule ?? templateRule {
            applyRuleTemplate(rule)
        } else {
            reloadInstalledApps(for: .web)
        }
    }

    private func applyRuleTemplate(_ rule: RoutingRule) {
        name = rule.name
        type = rule.type
        selectedSourceApp = rule.sourceApp
        field = rule.field
        matchOperator = rule.matchOperator
        value = rule.value
        openInPrivateMode = rule.openInPrivateMode
        if let sched = rule.schedule {
            scheduleEnabled = sched.isEnabled
            scheduleDays = sched.daysOfWeek
            scheduleStartHour = sched.startHour
            scheduleEndHour = sched.endHour
        } else {
            scheduleEnabled = false
        }
        reloadInstalledApps(for: rule.type)
        selectApp(rule.targetAppBundleID)
        selectedProfile = rule.targetProfile
    }

    private func reloadInstalledApps(for routeType: RouteType) {
        let scheme = (routeType == .mail) ? "mailto" : "https"
        availableApps = AppDiscoveryService.shared.getAvailableHandlers(for: scheme, sortRunningFirst: false)
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

        let schedule: RuleSchedule? = scheduleEnabled
            ? RuleSchedule(
                isEnabled: true,
                daysOfWeek: scheduleDays,
                startHour: scheduleStartHour,
                startMinute: 0,
                endHour: scheduleEndHour,
                endMinute: 0
            )
            : nil

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
            openInPrivateMode: openInPrivateMode,
            schedule: schedule,
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
