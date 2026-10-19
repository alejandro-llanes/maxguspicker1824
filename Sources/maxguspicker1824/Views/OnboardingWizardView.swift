import AppKit
import SwiftUI

struct OnboardingWizardView: View {
    @ObservedObject var systemService = SystemIntegrationService.shared
    @AppStorage("HasCompletedOnboarding") private var hasCompletedOnboarding = false
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Hero Header
            VStack(spacing: 10) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)

                Text("Welcome to maxguspicker1824")
                    .font(.title.bold())

                Text("Complete these 3 quick steps so maxguspicker1824 can intercept links and route them to your favorite apps & profiles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 28)
            .padding(.bottom, 24)

            Divider()

            // 3 Interactive Steps
            VStack(spacing: 14) {
                OnboardingStepCard(
                    stepNumber: 1,
                    title: "Set as Default Web Browser",
                    subtitle: "Allows maxguspicker1824 to catch web links you click in any app.",
                    icon: "globe",
                    isCompleted: systemService.isDefaultBrowser,
                    buttonTitle: "Set Default Browser",
                    action: { systemService.requestDefaultBrowser() }
                )

                OnboardingStepCard(
                    stepNumber: 2,
                    title: "Set as Default Email Reader",
                    subtitle: "Allows maxguspicker1824 to route mailto: links to specific mail apps.",
                    icon: "envelope.fill",
                    isCompleted: systemService.isDefaultMailClient,
                    buttonTitle: "Set Default Mail App",
                    action: { systemService.requestDefaultMailClient() }
                )

                OnboardingStepCard(
                    stepNumber: 3,
                    title: "Enable Safari & Arc Profile Automation",
                    subtitle: "Optional: Grant Accessibility access so maxguspicker1824 can open specific Safari Profiles.",
                    icon: "person.2.badge.key.fill",
                    isCompleted: systemService.hasAccessibilityPermission,
                    buttonTitle: "Grant Access",
                    action: { systemService.requestAccessibilityPermission() }
                )
            }
            .padding(24)

            Divider()

            // Footer
            HStack {
                if systemService.isDefaultBrowser && systemService.isDefaultMailClient {
                    Label("All essential permissions configured!", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("You can also change these later in macOS System Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    hasCompletedOnboarding = true
                    onFinish()
                } label: {
                    Text("Start Using maxguspicker1824")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
            .background(.bar)
        }
        .frame(width: 560, height: 540)
    }
}

struct OnboardingStepCard: View {
    let stepNumber: Int
    let title: String
    let subtitle: String
    let icon: String
    let isCompleted: Bool
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green.opacity(0.15) : Color.accentColor.opacity(0.12))
                    .frame(width: 42, height: 42)

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
            }

            Spacer()

            if isCompleted {
                Text("Active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.green.opacity(0.12), in: Capsule())
            } else {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
            }
        }
        .padding(14)
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
