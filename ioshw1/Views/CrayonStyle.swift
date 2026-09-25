import SwiftUI

/// 跟素材對齊的視覺語言：再生紙底、蠟筆深棕線稿、奶油色貼紙面板。
/// 所有 UI 元件都走這一套，不要再用系統預設的樣式。
extension Color {
    /// 線稿與主要文字。
    static let crayonInk = Color(red: 0.33, green: 0.20, blue: 0.11)
    /// 次要文字。在棕色紙紋上比系統的 .secondary 清楚得多。
    static let crayonInkSoft = Color(red: 0.46, green: 0.33, blue: 0.22)
    /// 貼紙與面板的奶油底。
    static let crayonPaper = Color(red: 0.97, green: 0.93, blue: 0.85)
    /// 貼紙外圈的牛皮紙色。
    static let crayonTan = Color(red: 0.80, green: 0.64, blue: 0.43)
}

extension Font {
    /// 圓體配蠟筆插畫比系統預設的字型合適。
    static func crayon(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - 面板

/// 奶油色紙面板，帶蠟筆味的粗棕邊。
struct PaperPanel: ViewModifier {
    var cornerRadius: CGFloat = 22
    var fill: Color = .crayonPaper

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.crayonInk.opacity(0.62), lineWidth: 3)
            }
            .shadow(color: .crayonInk.opacity(0.22), radius: 6, y: 3)
    }
}

extension View {
    func paperPanel(cornerRadius: CGFloat = 22, fill: Color = .crayonPaper) -> some View {
        modifier(PaperPanel(cornerRadius: cornerRadius, fill: fill))
    }
}

// MARK: - 按鈕

/// 貼紙按鈕：奶油底、粗棕邊、按下去會縮一下。
struct StickerButtonStyle: ButtonStyle {
    var fill: Color = .crayonPaper
    var textColor: Color = .crayonInk
    var size: CGFloat = 19

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.crayon(size))
            .foregroundStyle(textColor)
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(fill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.crayonInk.opacity(0.65), lineWidth: 3)
            }
            .shadow(
                color: .crayonInk.opacity(0.28),
                radius: configuration.isPressed ? 1 : 4,
                y: configuration.isPressed ? 1 : 3
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

/// HUD 上的圓形小按鈕（暫停、剋制表）。
struct CrayonIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.crayonInk)
                .frame(width: 38, height: 38)
                .background(Color.crayonPaper, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.crayonInk.opacity(0.6), lineWidth: 2.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - 進度條

/// 手繪感的進度條，取代系統 ProgressView。
struct CrayonBar: View {
    let value: Double
    let tint: Color
    var width: CGFloat = 92
    var height: CGFloat = 13

    var body: some View {
        Capsule()
            .fill(Color.crayonInk.opacity(0.14))
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, value)) * width)
            }
            .overlay {
                Capsule().strokeBorder(Color.crayonInk.opacity(0.45), lineWidth: 2)
            }
            .frame(width: width, height: height)
            .clipShape(Capsule())
    }
}
