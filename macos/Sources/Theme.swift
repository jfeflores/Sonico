import SwiftUI

/// Semantic Material roles translated into native SwiftUI styles.
enum XMTheme {
    static let cardRadius: CGFloat = 20
    static let gap: CGFloat = 12
    static let inset: CGFloat = 18
    static let margin: CGFloat = 20
    static let section: CGFloat = 20
}

@dynamicMemberLookup
struct SonicoColors {
    let palette: FinishPalette

    subscript(dynamicMember role: KeyPath<FinishPalette, UInt32>) -> Color {
        Color(hex: palette[keyPath: role])
    }
}

extension EnvironmentValues {
    @Entry var sonico: SonicoColors = .init(palette: .init(finish: nil, dark: false))
}

struct FinishAppearance: ViewModifier {
    let finish: HeadphoneFinish?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let colors = SonicoColors(palette: .init(finish: finish, dark: scheme == .dark,
                                                increasedContrast: contrast == .increased))
        content.environment(\.sonico, colors).tint(colors.primary)
    }
}

/// Reserve the long movement for the portrait. Utility feedback stays local and brief.
enum XMMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let selection = Animation.spring(response: 0.29, dampingFraction: 0.88)
    static let reveal = Animation.timingCurve(0.2, 0, 0, 1, duration: 0.22)
    static let navigation = Animation.easeOut(duration: 0.17)
}

struct XMPageHeading: View {
    let title: String
    let detail: String
    let symbol: String
    @Environment(\.sonico) private var colors

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(colors.primary)
                .frame(width: 38, height: 38)
                .background(colors.surfaceHigh, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.largeTitle.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text(detail).font(.callout).foregroundStyle(colors.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct XMCard<Content: View>: View {
    let title: String?
    var symbol: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder let content: Content
    @Environment(\.sonico) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                if let action {
                    Button(action: action) {
                        HStack {
                            heading(title)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }.contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Open \(title)")
                    .help("Open \(title)")
                } else { heading(title) }
            }
            content
        }
        .padding(XMTheme.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: XMTheme.cardRadius))
    }

    private func heading(_ title: String) -> some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol).foregroundStyle(colors.primary).accessibilityHidden(true) }
            Text(title).font(.headline).foregroundStyle(colors.text)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct TonalButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.sonico) private var colors

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .foregroundStyle(prominent ? colors.onPrimary : colors.primary)
            .background(prominent ? colors.primary : colors.surfaceHigh, in: Capsule())
            .opacity(!isEnabled ? 0.50 : configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : XMMotion.press, value: configuration.isPressed)
    }
}

struct StatusLine: View {
    let snapshot: HeadphoneSnapshot
    @Environment(\.sonico) private var colors
    var body: some View {
        Label(snapshot.status, systemImage: snapshot.isDemo ? "flask" : snapshot.controllable ? "checkmark.circle.fill" : "circle.dotted")
            .font(.callout)
            .foregroundStyle(snapshot.isDemo ? colors.primary : colors.secondary)
            .accessibilityLabel("Connection status: \(snapshot.status)")
    }
}
