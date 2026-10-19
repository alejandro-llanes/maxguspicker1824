import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RulesManagerView: View {
    @ObservedObject var store = RulesStore.shared
    @ViewState private var selectedFilter: RouteType? = nil // nil = All
    @ViewState private var editingRule: RoutingRule? = nil
    @ViewState private var isShowingNewRuleSheet = false
    @ViewState private var testInput: String = ""

    var filteredRules: [RoutingRule] {
        guard let filter = selectedFilter else { return store.rules }
        return store.rules.filter { $0.type == filter }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Header & Filter Bar
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Routing Rules")
                        .font(.title2.bold())
                    Text("Links matching a rule open automatically. Everything else shows the floating picker.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Filter", selection: $selectedFilter) {
                    Text("All Rules").tag(RouteType?.none)
                    ForEach(RouteType.allCases) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(RouteType?.some(type))
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                // Templates Menu
                Menu {
                    Section("Starter Rule Templates:") {
                        ForEach(RuleTemplatePreset.builtInPresets) { preset in
                            Button {
                                let defaultApp = AppDiscoveryService.shared.getAvailableHandlers(for: "https").first
                                store.draftRuleFromHistory = preset.toRoutingRule(defaultApp: defaultApp)
                            } label: {
                                Label(preset.title, systemImage: preset.icon)
                            }
                        }
                    }
                } label: {
                    Label("Templates", systemImage: "sparkles.rectangle.stack")
                }
                .menuStyle(.borderedButton)
                .controlSize(.large)
                .fixedSize()

                // Create Rule from History Menu
                Menu {
                    if store.recentActivity.isEmpty {
                        Text("No previously opened links yet")
                    } else {
                        Section("Select a previously opened link to create a rule:") {
                            ForEach(store.recentActivity) { record in
                                Button {
                                    store.draftRuleFromHistory = record.toRoutingRule()
                                } label: {
                                    Text(record.displaySummary)
                                }
                            }
                        }
                        Divider()
                        Button("Clear History", role: .destructive) {
                            store.clearHistory()
                        }
                    }
                } label: {
                    Label("From History", systemImage: "clock.arrow.circlepath")
                }
                .menuStyle(.borderedButton)
                .controlSize(.large)
                .fixedSize()

                // Export / Import Rules Menu
                Menu {
                    Button {
                        exportRulesToFile()
                    } label: {
                        Label("Export Rules to JSON...", systemImage: "square.and.arrow.up")
                    }
                    .disabled(store.rules.isEmpty)

                    Button {
                        importRulesFromFile()
                    } label: {
                        Label("Import Rules from JSON...", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderedButton)
                .controlSize(.large)
                .fixedSize()
                .help("Export or Import Routing Rules (JSON)")

                Button {
                    isShowingNewRuleSheet = true
                } label: {
                    Label("New Rule", systemImage: "plus")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
            .background(.bar)

            Divider()

            // MARK: - Rules List or Empty State
            if filteredRules.isEmpty {
                ContentUnavailableView {
                    Label("No Routing Rules Yet", systemImage: "arrow.triangle.branch")
                } description: {
                    Text("Create a rule manually, from a starter template, or from your history of previously opened links.")
                } actions: {
                    HStack(spacing: 12) {
                        Button("Create Your First Rule") {
                            isShowingNewRuleSheet = true
                        }
                        .buttonStyle(.borderedProminent)

                        Menu {
                            ForEach(RuleTemplatePreset.builtInPresets) { preset in
                                Button {
                                    let defaultApp = AppDiscoveryService.shared.getAvailableHandlers(for: "https").first
                                    store.draftRuleFromHistory = preset.toRoutingRule(defaultApp: defaultApp)
                                } label: {
                                    Label(preset.title, systemImage: preset.icon)
                                }
                            }
                        } label: {
                            Label("Use a Template", systemImage: "sparkles.rectangle.stack")
                        }
                        .menuStyle(.borderedButton)
                        .fixedSize()

                        if !store.recentActivity.isEmpty {
                            Menu {
                                ForEach(store.recentActivity) { record in
                                    Button {
                                        store.draftRuleFromHistory = record.toRoutingRule()
                                    } label: {
                                        Text(record.displaySummary)
                                    }
                                }
                            } label: {
                                Label("From History", systemImage: "clock.arrow.circlepath")
                            }
                            .menuStyle(.borderedButton)
                            .fixedSize()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredRules) { rule in
                        RuleRowCard(
                            rule: rule,
                            isHighlightedByTester: isRuleMatchedByTester(rule),
                            onToggle: { isEnabled in
                                if let idx = store.rules.firstIndex(where: { $0.id == rule.id }) {
                                    store.rules[idx].isEnabled = isEnabled
                                }
                            },
                            onEdit: { editingRule = rule },
                            onDelete: {
                                store.rules.removeAll { $0.id == rule.id }
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onMove { source, destination in
                        if selectedFilter == nil {
                            store.rules.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()

            // MARK: - Bottom Live Rule Tester Bar
            LiveRuleTesterBar(testInput: $testInput, matchedRule: currentTestedRule)
        }
        .frame(minWidth: 880, minHeight: 560)
        .sheet(isPresented: $isShowingNewRuleSheet) {
            RuleBuilderSheet(existingRule: nil) { newRule in
                store.rules.append(newRule)
            }
        }
        .sheet(item: $store.draftRuleFromHistory) { templateRule in
            RuleBuilderSheet(existingRule: nil, templateRule: templateRule) { newRule in
                store.rules.append(newRule)
            }
        }
        .sheet(item: $editingRule) { ruleToEdit in
            RuleBuilderSheet(existingRule: ruleToEdit) { updatedRule in
                if let idx = store.rules.firstIndex(where: { $0.id == updatedRule.id }) {
                    store.rules[idx] = updatedRule
                }
            }
        }
    }

    // MARK: - Export & Import Handlers

    private func exportRulesToFile() {
        guard let data = try? store.exportRulesData() else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "maxguspicker1824-rules.json"
        savePanel.title = "Export Routing Rules"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func importRulesFromFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.title = "Import Routing Rules"
        if openPanel.runModal() == .OK,
           let url = openPanel.url,
           let data = try? Data(contentsOf: url) {
            _ = try? store.importRules(from: data, merge: true)
        }
    }

    // MARK: - Live Tester Helpers
    private var currentTestedRule: RoutingRule? {
        guard let url = normalizedTestURL(from: testInput) else { return nil }
        let evaluatedURL = store.sanitizeURLsEnabled ? URLSanitizerService.shared.sanitize(url) : url
        return store.findMatchingRule(for: evaluatedURL, sourceApp: nil)
    }

    private func isRuleMatchedByTester(_ rule: RoutingRule) -> Bool {
        guard !testInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return currentTestedRule?.id == rule.id
    }

    private func normalizedTestURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("mailto:") {
            return URL(string: trimmed)
        }
        if trimmed.contains("@") && !trimmed.contains("://") && !trimmed.contains("/") {
            return URL(string: "mailto:\(trimmed)")
        }
        if !trimmed.contains("://") {
            return URL(string: "https://\(trimmed)")
        }
        return URL(string: trimmed)
    }
}

struct RuleRowCard: View {
    let rule: RoutingRule
    let isHighlightedByTester: Bool
    let onToggle: (Bool) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var appIcon: NSImage {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.targetAppBundleID) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help("Drag to reorder priority")

            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { onToggle($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()

            // Left: Rule Name & Condition Badge
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: rule.type.icon)
                        .foregroundStyle(rule.type == .web ? .blue : .orange)
                    Text(rule.name)
                        .font(.headline)
                        .strikethrough(!rule.isEnabled)
                }

                Text(rule.summarySentence)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "arrow.right")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)

            // Right: Target Application, Profile & Private Pill
            HStack(spacing: 8) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(rule.targetAppName)
                            .font(.subheadline.weight(.medium))
                        if rule.openInPrivateMode {
                            Image(systemName: "eyeglasses")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                                .help("Opens in Private / Incognito Window")
                        }
                    }
                    if let profile = rule.targetProfile {
                        Text(profile.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            // Actions
            Menu {
                Button("Edit Rule...", systemImage: "pencil", action: onEdit)
                Divider()
                Button("Delete Rule", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    isHighlightedByTester ? Color.green : Color.primary.opacity(0.08),
                    lineWidth: isHighlightedByTester ? 2 : 1
                )
        )
        .opacity(rule.isEnabled ? 1.0 : 0.55)
    }
}

struct LiveRuleTesterBar: View {
    @Binding var testInput: String
    let matchedRule: RoutingRule?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.purple)

            TextField("Test a link or email (e.g. github.com/apple or billing@company.com)...", text: $testInput)
                .textFieldStyle(.roundedBorder)

            if !testInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let matched = matchedRule {
                    Label(
                        "Opens in \(matched.targetAppName)\(matched.targetProfile.map { " (\($0.displayName))" } ?? "")",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.green.opacity(0.12), in: Capsule())
                } else {
                    Label("No rule match → Shows Floating App Selector", systemImage: "hand.tap.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.orange.opacity(0.12), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}
