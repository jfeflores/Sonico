import SwiftUI

/// Semantic Material roles translated into native SwiftUI styles.
enum XMTheme {
    static let background = Color(hex: 0x101313)
    static let surface = Color(hex: 0x272B2C)
    static let surfaceHigh = Color(hex: 0x363B3D)
    static let outline = Color(hex: 0x50585B)
    static let primary = Color(hex: 0xC3C2FF)
    static let onPrimary = Color(hex: 0x24234F)
    static let text = Color(hex: 0xF1F1F0)
    static let secondary = Color(hex: 0xC9CBCB)
    static let header = Color(hex: 0xE7E8E5)
    static let onHeader = Color(hex: 0x191C1C)
    static let error = Color(hex: 0xFFB4AB)
    static let cardRadius: CGFloat = 22
    static let gap: CGFloat = 12
    static let inset: CGFloat = 22
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

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(XMTheme.primary)
                .frame(width: 42, height: 42)
                .background(XMTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.largeTitle.weight(.semibold)).accessibilityAddTraits(.isHeader)
                Text(detail).font(.callout).foregroundStyle(XMTheme.secondary)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
        .background(XMTheme.surface, in: RoundedRectangle(cornerRadius: XMTheme.cardRadius))
    }

    private func heading(_ title: String) -> some View {
        HStack(spacing: 8) {
            if let symbol { Image(systemName: symbol).foregroundStyle(XMTheme.primary).accessibilityHidden(true) }
            Text(title).font(.headline).foregroundStyle(XMTheme.text)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct TonalButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .padding(.horizontal, 18).padding(.vertical, 11)
            .foregroundStyle(prominent ? XMTheme.onPrimary : XMTheme.primary)
            .background(prominent ? XMTheme.primary : XMTheme.surfaceHigh, in: Capsule())
            .opacity(!isEnabled ? 0.50 : configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : XMMotion.press, value: configuration.isPressed)
    }
}

struct StatusLine: View {
    let snapshot: HeadphoneSnapshot
    var body: some View {
        Label(snapshot.status, systemImage: snapshot.isDemo ? "flask" : snapshot.controllable ? "checkmark.circle.fill" : "circle.dotted")
            .font(.callout)
            .foregroundStyle(snapshot.isDemo ? XMTheme.primary : XMTheme.secondary)
            .accessibilityLabel("Connection status: \(snapshot.status)")
    }
}
