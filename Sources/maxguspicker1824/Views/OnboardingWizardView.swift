import AppKit
import SwiftUI

struct OnboardingWizardView: View {
    @ObservedObject var systemService = SystemIntegrationService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Hero Header
            VStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)

                Text("Maxgus Picker 1824")
                    .font(.title.bold())

                Text("Complete these quick steps so Maxgus Picker 1824 can intercept links and route them to your favorite apps & profiles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            Divider()

            // Interactive Setup Steps
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
            .padding(.vertical, 18)

            Spacer(minLength: 0)

            Divider()

            // Centered Bottom Status Bar (no "Start Using" button needed)
            HStack {
                Spacer()
                if systemService.isDefaultBrowser && systemService.isDefaultMailClient {
                    Label("All essential permissions configured!", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline.weight(.semibold))
                } else {
                    Label("All essential permissions configured!", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(systemService.isDefaultBrowser ? .green : .secondary)
                        .font(.subheadline.weight(.medium))
                }
                Spacer()
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(.bar)
        }
        .frame(width: 580, height: 590)
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
