import SwiftUI

/// 앱 시작 0.7초. 실행 화면 그림(격자, 마지막 칸 비움)을 같은 자리·같은 크기에서 이어받아
/// 빈 칸에서 풀이 자라고, 격자가 톡 커졌다가 위로 사라지며 아래 화면이 드러난다.
/// - 누르면 바로 건너뛴다.
/// - 켜져 있던 앱으로 돌아올 때는 상태가 남아 있어 다시 재생되지 않는다.
/// - 동작 줄이기: 0.15초 뒤 0.2초 동안 흐려지며 넘어간다.
struct LaunchGate<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showOverlay = true
    @State private var contentVisible = false
    @State private var grow: CGFloat = 0     // 풀 세로 크기 0→1
    @State private var bump: CGFloat = 1     // 격자 톡 1→1.04→1
    @State private var leaving = false       // 격자 12pt 위로 + 흐려짐

    var body: some View {
        ZStack {
            content
                .opacity(contentVisible ? 1 : 0)

            if showOverlay {
                ZStack {
                    Theme.meadow  // = 실행 화면 바탕색(LaunchBackground)
                        .opacity(leaving ? 0 : 1)
                    LaunchGrid(grow: grow)
                        .scaleEffect(bump)
                        .offset(y: leaving && !reduceMotion ? -12 : 0)
                        .opacity(leaving ? 0 : 1)
                }
                .ignoresSafeArea()   // 실행 화면 그림처럼 화면 정중앙에 둔다
                .contentShape(Rectangle())
                .onTapGesture(perform: skip)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("건너뛰기")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { skip() }
            }
        }
        .task { await play() }
    }

    private func play() async {
        try? await Task.sleep(for: .milliseconds(150))   // 0–0.15초: 실행 화면 그대로
        guard showOverlay else { return }

        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) {
                leaving = true
                contentVisible = true
            }
            try? await Task.sleep(for: .milliseconds(200))
            showOverlay = false
            return
        }

        // 0.15–0.4초: 빈 칸에서 풀이 아래를 축으로 자란다 (살짝 넘치는 곡선)
        withAnimation(.timingCurve(0.2, 0.9, 0.3, 1.2, duration: 0.25)) { grow = 1 }
        try? await Task.sleep(for: .milliseconds(250))
        guard showOverlay else { return }

        // 0.4–0.6초: 격자 전체 1→1.04→1
        withAnimation(.easeOut(duration: 0.1)) { bump = 1.04 }
        try? await Task.sleep(for: .milliseconds(50))
        guard showOverlay else { return }

        // 0.45–0.7초: 격자가 위로 가며 사라지고 아래 화면이 나타난다
        withAnimation(.easeIn(duration: 0.25)) { leaving = true }
        withAnimation(.easeOut(duration: 0.25)) { contentVisible = true }
        try? await Task.sleep(for: .milliseconds(50))
        withAnimation(.easeOut(duration: 0.1)) { bump = 1 }
        try? await Task.sleep(for: .milliseconds(200))
        showOverlay = false
    }

    private func skip() {
        showOverlay = false
        contentVisible = true
    }
}

/// 실행 화면 그림(LaunchMark)과 같은 격자. 아이콘 1024 좌표(격자 156…868)를 147pt에 맞춘다.
private struct LaunchGrid: View {
    let grow: CGFloat

    /// 행별 잔디 단계(위→아래). nil = 마지막 칸(풀 자리)
    private static let levels: [[Int?]] = [[0, 1, 1, 2], [1, 1, 2, 3], [1, 2, 3, 4], [2, 3, 4, nil]]
    private static let k: CGFloat = 147.0 / 712.0
    private let colors = [Theme.grass0, Theme.grass1, Theme.grass2, Theme.grass3, Theme.grass4]

    var body: some View {
        let k = Self.k
        ZStack(alignment: .topLeading) {
            ForEach(0..<16, id: \.self) { i in
                if let level = Self.levels[i / 4][i % 4] {
                    RoundedRectangle(cornerRadius: 46 * k, style: .circular)
                        .fill(colors[level])
                        .frame(width: 160 * k, height: 160 * k)
                        .offset(x: CGFloat(i % 4) * 184 * k, y: CGFloat(i / 4) * 184 * k)
                }
            }
            // 풀: 160 박스 경로를 1.2배(192)로, 아이콘 좌표 (694, 690)에 둔다. 밑동(y 144)을 축으로 자란다.
            GrassTuft()
                .fill(Theme.grass4)
                .frame(width: 192 * k, height: 192 * k)
                .scaleEffect(x: 1, y: grow, anchor: UnitPoint(x: 0.5, y: 144.0 / 160.0))
                .offset(x: (694 - 156) * k, y: (690 - 156) * k)
        }
        .frame(width: 147, height: 147, alignment: .topLeading)
    }
}

/// 아이콘의 풀 한 포기 (160×160 박스 경로)
struct GrassTuft: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 160
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        // 가운데 잎
        path.move(to: p(64, 140))
        path.addCurve(to: p(82, 22), control1: p(62, 100), control2: p(70, 60))
        path.addCurve(to: p(96, 140), control1: p(92, 60), control2: p(98, 100))
        path.closeSubpath()
        // 왼쪽 잎
        path.move(to: p(40, 140))
        path.addCurve(to: p(8, 66), control1: p(34, 112), control2: p(24, 86))
        path.addCurve(to: p(66, 140), control1: p(34, 74), control2: p(56, 100))
        path.closeSubpath()
        // 오른쪽 잎
        path.move(to: p(94, 140))
        path.addCurve(to: p(152, 70), control1: p(104, 104), control2: p(124, 80))
        path.addCurve(to: p(120, 140), control1: p(136, 92), control2: p(124, 114))
        path.closeSubpath()
        // 밑동
        path.move(to: p(36, 136))
        path.addCurve(to: p(50, 126), control1: p(36, 128), control2: p(42, 126))
        path.addLine(to: p(110, 126))
        path.addCurve(to: p(124, 136), control1: p(118, 126), control2: p(124, 128))
        path.addCurve(to: p(114, 144), control1: p(124, 142), control2: p(120, 144))
        path.addLine(to: p(46, 144))
        path.addCurve(to: p(36, 136), control1: p(40, 144), control2: p(36, 142))
        path.closeSubpath()
        return path
    }
}
