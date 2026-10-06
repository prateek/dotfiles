import AppKit
import SwiftUI
import PermissionsCore

struct PermissionTheme {
    var scale: CGFloat = 1
    var body: Font { .system(size: 13 * scale) }
    var caption: Font { .system(size: 11 * scale) }
    var label: Font { .system(size: 13 * scale, weight: .semibold) }
    var title: Font { .system(size: 18 * scale, weight: .semibold) }
}

private struct PermissionThemeKey: EnvironmentKey {
    static let defaultValue = PermissionTheme()
}

extension EnvironmentValues {
    var permissionTheme: PermissionTheme {
        get { self[PermissionThemeKey.self] }
        set { self[PermissionThemeKey.self] = newValue }
    }
}

struct PermissionPaper: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        (contrast == .increased ? (scheme == .dark ? Color.black : .white)
         : scheme == .dark ? Color(red: 0.17, green: 0.15, blue: 0.13)
         : Color(red: 0.98, green: 0.955, blue: 0.92))
    }
}

extension GrantState {
    var symbol: String {
        switch self {
        case .allowed: return "checkmark.seal.fill"
        case .stale: return "exclamationmark.triangle.fill"
        case .denied: return "minus.circle.fill"
        case .missing: return "circle.dashed"
        case .unknown: return "questionmark.circle.fill"
        case .notInstalled: return "app.dashed"
        }
    }
    var tint: Color {
        switch self {
        case .allowed: return .green
        case .stale, .unknown: return .orange
        case .missing, .denied: return .accentColor
        case .notInstalled: return .secondary
        }
    }
}

struct StatusLabel: View {
    let state: GrantState
    @Environment(\.permissionTheme) private var theme
    var body: some View {
        Label(state.title, systemImage: state.symbol)
            .font(theme.caption).foregroundStyle(.primary)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(state.tint.opacity(0.13), in: Capsule())
            .accessibilityLabel(state.title)
    }
}

struct AppIcon: View {
    let url: URL?
    let size: CGFloat
    var body: some View {
        Image(nsImage: url.map { NSWorkspace.shared.icon(forFile: $0.path) }
              ?? NSImage(named: NSImage.applicationIconName)!)
            .resizable().interpolation(.high).scaledToFit().frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
