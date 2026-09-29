import SwiftUI
import UIKit
import CoreText

/// 잔디 디자인의 색과 글꼴
/// 색은 (라이트, 다크) 쌍으로 정의한다. 라이트 값은 사용자가 승인한 원래 팔레트 그대로다.
enum Theme {
    // 글자
    static let soil = Color(light: 0x1B2A1E, dark: 0xE6F0E3)      // 기본 글자
    // 보조 글자. '대비 높이기' 설정에서는 배경과의 대비 4.5:1 이상이 되도록 더 진하게 쓴다.
    static let stem = Color(light: 0x7A8A77, dark: 0x8FA08C, lightContrast: 0x566652, darkContrast: 0xA9B9A5)
    // 바탕
    static let meadow = Color(light: 0xEEF5E8, dark: 0x0F1A12)    // 화면 배경
    static let meadowGlow = Color(light: 0xD9EDC9, dark: 0x1B3A22) // 배경 아래쪽 풀빛
    static let card = Color(light: 0xFFFFFF, dark: 0x182219)
    static let segment = Color(light: 0xDDE8D5, dark: 0x243226)
    // 잔디 단계 (다크에서는 많이 달성할수록 밝다)
    static let grass0 = Color(light: 0xE3EBDC, dark: 0x2A3A2E)
    static let grass1 = Color(light: 0xBFE3A5, dark: 0x2F5A34)
    static let grass2 = Color(light: 0x7FCA6B, dark: 0x3F8B47)
    static let grass3 = Color(light: 0x3FA34D, dark: 0x58B85F)
    static let grass4 = Color(light: 0x226F35, dark: 0x8CE07F)
    static let bare = Color(light: 0xF1F5ED, dark: 0x1C271F)      // 할 습관 없는 날
    static let dash = Color(light: 0xDDE6D6, dark: 0x3E5243)      // 미래 칸 점선
    static let restMark = Color(light: 0xCDD6C6, dark: 0x4A5E4C)  // 쉬는 요일 "–"
    // 초록 채움(grass3·grass4) 위에 얹는 글자·체크 표시
    static let onGrass = Color(light: 0xFFFFFF, dark: 0x0F1A12)
    // 요일
    static let sunday = Color(light: 0xD0584A, dark: 0xFF8A7A)
    static let saturday = Color(light: 0x4A79C9, dark: 0x7FA8F0)

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

    // 잔디 칸 위 날짜 숫자 색 (라이트 값은 기존과 같다. 다크는 칸 색과 대비 4.5:1 안팎이 되게 잡았다)
    private static let numberFaint = Color(light: 0x1B2A1E, dark: 0xE6F0E3, lightAlpha: 0.45, darkAlpha: 0.55)
    private static let numberZero = Color(light: 0x1B2A1E, dark: 0xE6F0E3, lightAlpha: 0.45, darkAlpha: 0.65)
    private static let numberLow = Color(light: 0x1B2A1E, dark: 0xFFFFFF, lightAlpha: 0.45, darkAlpha: 0.9)
    private static let numberMid = Color(light: 0x1B2A1E, dark: 0xFFFFFF, lightAlpha: 0.6, darkAlpha: 1)
    private static let numberStrong = Color(light: 0xFFFFFF, dark: 0x0F1A12, lightAlpha: 0.85, darkAlpha: 0.85)

    /// 잔디 칸 위 날짜 숫자 색
    static func numberColor(for level: ProgressLevel) -> Color {
        switch level {
        case .high, .full: return numberStrong
        case .mid: return numberMid
        case .low: return numberLow
        case .zero: return numberZero
        case .none, .future: return numberFaint
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
    /// 라이트/다크에 따라 색이 바뀌는 동적 색.
    /// lightContrast/darkContrast를 주면 '대비 높이기' 설정에서 그 값을 쓴다.
    init(
        light: UInt32, dark: UInt32,
        lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1,
        lightContrast: UInt32? = nil, darkContrast: UInt32? = nil
    ) {
        self.init(uiColor: UIColor { (trait: UITraitCollection) -> UIColor in
            let isDark = trait.userInterfaceStyle == .dark
            let highContrast = trait.accessibilityContrast == .high
            let hex: UInt32
            if isDark {
                hex = highContrast ? (darkContrast ?? dark) : dark
            } else {
                hex = highContrast ? (lightContrast ?? light) : light
            }
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        })
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
