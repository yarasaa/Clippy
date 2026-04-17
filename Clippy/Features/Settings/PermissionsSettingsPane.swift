import SwiftUI

// MARK: - PermissionsSettingsPane
// A single place users can see the state of every permission Clippy needs,
// (re)grant them, and — critically — reset macOS's TCC cache so a stale
// permission entry from an older build doesn't break the new install.

struct PermissionsSettingsPane: View {
    @StateObject private var permissions = PermissionManager.shared
    @Environment(\.colorScheme) private var scheme
    @State private var showResetConfirm: Bool = false

    var body: some View {
        SettingsPane(
            title: "Privacy & Permissions",
            subtitle: "Grant only what you need. Reset if a reinstall left stale entries."
        ) {
            SettingsGroup("System Access") {
                ForEach(Array(ClippyPermission.allCases.enumerated()), id: \.element.id) { index, permission in
                    permissionRow(permission)
                    if index < ClippyPermission.allCases.count - 1 {
                        Divider().opacity(0.18)
                    }
                }
            }

            troubleshootingCard
        }
        .onAppear { permissions.refreshAll() }
        .alert("Reset all Clippy permissions?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                permissions.resetAllPermissions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("macOS will forget every permission you granted to Clippy. You'll be prompted again as needed.")
        }
    }

    // MARK: Permission row

    private func permissionRow(_ permission: ClippyPermission) -> some View {
        let status = permissions.statuses[permission] ?? .notDetermined

        return HStack(alignment: .top, spacing: Ember.Space.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(statusTint(status).opacity(0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: permission.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(statusTint(status))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(permission.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Ember.primaryText(scheme))

                    statusBadge(status)

                    if permission.isRequired {
                        Text("REQUIRED")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Ember.Palette.amber)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Ember.Palette.amberSoft))
                    }
                }

                Text(permission.rationale)
                    .font(Ember.Font.caption)
                    .foregroundColor(Ember.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                if status == .granted {
                    Button {
                        permissions.openSystemSettings(for: permission)
                    } label: {
                        Text("Manage")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                } else {
                    Button {
                        permissions.request(permission)
                    } label: {
                        Text(status == .denied ? "Open Settings" : "Grant")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        permissions.refreshAll()
                    } label: {
                        Text("Re-check")
                            .font(.system(size: 10))
                            .foregroundColor(Ember.secondaryText(scheme))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, Ember.Space.sm)
    }

    // MARK: Troubleshooting card

    private var troubleshootingCard: some View {
        VStack(alignment: .leading, spacing: Ember.Space.sm) {
            HStack(spacing: 6) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 11))
                    .foregroundColor(Ember.Palette.amber)
                Text("TROUBLESHOOTING")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(Ember.tertiaryText(scheme))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Reinstalled Clippy and permissions are stuck?")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Ember.primaryText(scheme))

                Text("macOS caches permissions per code-signing identity. A fresh build may be treated as a different app, leaving an orphaned entry. Reset clears Clippy's TCC record so every permission prompt starts fresh.")
                    .font(Ember.Font.caption)
                    .foregroundColor(Ember.secondaryText(scheme))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Ember.Space.sm) {
                    Button {
                        showResetConfirm = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset All Clippy Permissions")
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button {
                        openPrivacyRoot()
                    } label: {
                        Text("Open Privacy Settings")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                .padding(.top, 2)
            }
            .padding(Ember.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Ember.Radius.lg)
                    .fill(Ember.cardBackground(scheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Ember.Radius.lg)
                    .strokeBorder(Color.white.opacity(scheme == .dark ? 0.06 : 0.5), lineWidth: 0.5)
            )
        }
    }

    private func openPrivacyRoot() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Helpers

    private func statusTint(_ status: PermissionStatus) -> Color {
        switch status {
        case .granted:       return Ember.Palette.moss
        case .denied:        return Ember.Palette.rust
        case .notDetermined: return Ember.Palette.amber
        }
    }

    private func statusBadge(_ status: PermissionStatus) -> some View {
        Text(status.label)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(statusTint(status))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(statusTint(status).opacity(0.14)))
    }
}
