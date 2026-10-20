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
                    appDelegate.showOnboardingWindow(initialTab: .permissions)
                } label: {
                    Label("Not Set as Default Browser — Click to Fix", systemImage: "exclamationmark.triangle.fill")
                }
                Divider()
            }

            // Global Identity / Context Mode Switcher
            if store.featureSettings.enableContextModeFiltering {
                Menu {
                    ForEach(IdentityContext.allCases) { ctx in
                        Button {
                            store.activeContext = ctx
                        } label: {
                            Label(
                                ctx.rawValue,
                                systemImage: store.activeContext == ctx ? "checkmark.circle.fill" : ctx.icon
                            )
                        }
                    }
                } label: {
                    Label("Context Mode: \(store.activeContext.rawValue)", systemImage: store.activeContext.icon)
                }
                Divider()
            }

            // Pause & Smart Behavior Toggles
            Toggle(isOn: $store.isPaused) {
                Label("Pause Rules (Always Show Picker)", systemImage: "pause.circle")
            }

            Toggle(isOn: $store.featureSettings.sanitizeURLsEnabled) {
                Label("Strip Tracking & Unwrap Redirects", systemImage: "sparkles")
            }

            Toggle(isOn: $store.featureSettings.prioritizeRunningBrowsers) {
                Label("Prioritize Running Browsers", systemImage: "bolt.circle")
            }

            Divider()

            // Active Browser Tab Handoff & Clipboard Router
            Button {
                appDelegate.rerouteActiveBrowserTab()
            } label: {
                Label("Re-route Active Browser Tab...", systemImage: "arrow.up.right.square")
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button {
                appDelegate.routeClipboardURL()
            } label: {
                Label("Route URL from Clipboard...", systemImage: "doc.on.clipboard")
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Divider()

            // Quick Rules Summary & Editor Launch
            Button {
                appDelegate.showRulesWindow()
            } label: {
                Label("Routing Rules (\(store.rules.filter(\.isEnabled).count) Active)...", systemImage: "list.bullet.rectangle")
            }
            .keyboardShortcut(",", modifiers: .command)

            // Recent Routed Links Submenu (allows reopening URLs or creating rules directly from history)
            Menu {
                if store.recentActivity.isEmpty {
                    Text("No links routed yet")
                } else {
                    ForEach(store.recentActivity) { record in
                        Menu(record.displaySummary) {
                            Button {
                                appDelegate.reopenActivityRecord(record, showChooser: false)
                            } label: {
                                Label("Reopen URL in \(record.destinationDisplayTitle)", systemImage: "arrow.clockwise.circle")
                            }

                            Button {
                                appDelegate.reopenActivityRecord(record, showChooser: true)
                            } label: {
                                Label("Reopen URL in Floating Chooser...", systemImage: "hand.tap")
                            }

                            Button {
                                appDelegate.copyActivityRecordURL(record)
                            } label: {
                                Label("Copy URL (\(record.urlString))", systemImage: "doc.on.doc")
                            }

                            Divider()

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
                appDelegate.showOnboardingWindow(initialTab: .features)
            } label: {
                Label("Features & Chooser UX Settings...", systemImage: "slider.horizontal.3")
            }

            Button {
                appDelegate.showOnboardingWindow(initialTab: .permissions)
            } label: {
                Label("System Setup & Permissions...", systemImage: "gearshape.2")
            }

            Button {
                appDelegate.showOnboardingWindow(initialTab: .about)
            } label: {
                Label("About Maxgus Picker 1824 (\(systemService.versionBadgeText))...", systemImage: "info.circle")
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
