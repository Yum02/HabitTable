import SwiftUI
import CoreText

/// 잔디 디자인의 색과 글꼴
enum Theme {
    // 글자
    static let soil = Color(hex: 0x1B2A1E)      // 기본 글자
    static let stem = Color(hex: 0x7A8A77)      // 보조 글자
    // 바탕
    static let meadow = Color(hex: 0xEEF5E8)    // 화면 배경
    static let meadowGlow = Color(hex: 0xD9EDC9) // 배경 아래쪽 풀빛
    static let card = Color.white
    static let segment = Color(hex: 0xDDE8D5)
    // 잔디 단계
    static let grass0 = Color(hex: 0xE3EBDC)
    static let grass1 = Color(hex: 0xBFE3A5)
    static let grass2 = Color(hex: 0x7FCA6B)
    static let grass3 = Color(hex: 0x3FA34D)
    static let grass4 = Color(hex: 0x226F35)
    static let bare = Color(hex: 0xF1F5ED)      // 할 습관 없는 날
    static let dash = Color(hex: 0xDDE6D6)      // 미래 칸 점선
    static let restMark = Color(hex: 0xCDD6C6)  // 쉬는 요일 "–"
    // 요일
    static let sunday = Color(hex: 0xD0584A)
    static let saturday = Color(hex: 0x4A79C9)

    static func color(for level: ProgressLevel) -> Color {
        switch level {
        case .none: return bare
        case .zero: return grass0
        case .low: return grass1
        case .mid: return grass2
        case .high: return grass3
        case .full: return grass4
        case .future: return .clear
        }
    }

    /// 잔디 칸 위 날짜 숫자 색
    static func numberColor(for level: ProgressLevel) -> Color {
        switch level {
        case .high, .full: return Color.white.opacity(0.85)
        case .mid: return soil.opacity(0.6)
        default: return soil.opacity(0.45)
        }
    }

    /// 화면 배경: 연한 풀빛 + 아래쪽이 조금 더 진한 초록
    static var background: some View {
        ZStack {
            meadow
            RadialGradient(
                colors: [meadowGlow, meadowGlow.opacity(0)],
                center: UnitPoint(x: 0.5, y: 1.1),
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - 글꼴 (스포카 한 산스 Neo, SIL OFL)

enum SpoqaWeight: String {
    case regular = "SpoqaHanSansNeo-Regular"
    case medium = "SpoqaHanSansNeo-Medium"
    case bold = "SpoqaHanSansNeo-Bold"
}

extension Font {
    /// 스포카 한 산스 Neo. relativeTo로 '더 큰 텍스트' 설정도 따라간다.
    static func spoqa(_ size: CGFloat, _ weight: SpoqaWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.rawValue, size: size, relativeTo: style)
    }
}

enum FontRegistrar {
    /// 앱에 포함된 ttf를 실행 시 등록한다 (Info.plist 설정 없이 동작)
    static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
