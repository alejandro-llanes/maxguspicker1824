import AppKit
import SwiftUI

@main
struct MaxgusPicker1824App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject var store = RulesStore.shared
    @ObservedObject var systemService = SystemIntegrationService.shared

    var body: some Scene {
        // Menu Bar Status Icon (Rules Editor and Onboarding windows are managed explicitly
        // by AppDelegate so SwiftUI never auto-opens them when intercepting URLs)
        MenuBarExtra {
            // Status Banner
            if !systemService.isDefaultBrowser {
                Button {
                    appDelegate.showOnboardingWindow()
                } label: {
                    Label("Not Set as Default Browser — Click to Fix", systemImage: "exclamationmark.triangle.fill")
                }
                Divider()
            }

            // Pause Toggle
            Toggle(isOn: $store.isPaused) {
                Label("Pause Rules (Always Show Picker)", systemImage: "pause.circle")
            }

            Divider()

            // Quick Rules Summary & Editor Launch
            Button {
                appDelegate.showRulesWindow()
            } label: {
                Label("Routing Rules (\(store.rules.filter(\.isEnabled).count) Active)...", systemImage: "slider.horizontal.3")
            }
            .keyboardShortcut(",", modifiers: .command)

            // Recent Routed Links Submenu (allows creating rules directly from history)
            Menu {
                if store.recentActivity.isEmpty {
                    Text("No links routed yet")
                } else {
                    ForEach(store.recentActivity) { record in
                        Menu(record.displaySummary) {
                            Button {
                                appDelegate.openRuleBuilderFromHistory(record)
                            } label: {
                                Label("Create Rule in Editor...", systemImage: "slider.horizontal.3")
                            }

                            Button {
                                store.rules.append(record.toRoutingRule())
                            } label: {
                                Label("Quick-Save Rule (\(record.hostOrRecipient) → \(record.destinationDisplayTitle))", systemImage: "plus.circle")
                            }
                        }
                    }
                    Divider()
                    Button("Clear History") {
                        store.clearHistory()
                    }
                }
            } label: {
                Label("Recent Activity", systemImage: "clock.arrow.circlepath")
            }

            Divider()

            Button {
                appDelegate.showOnboardingWindow()
            } label: {
                Label("Setup & Permissions Wizard...", systemImage: "sparkles")
            }

            Divider()

            Button("Quit maxguspicker1824") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            Image(systemName: store.isPaused ? "arrow.triangle.branch.slash" : "arrow.triangle.branch")
        }
    }
}
