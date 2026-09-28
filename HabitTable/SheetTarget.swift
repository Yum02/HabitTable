import SwiftUI
import SwiftData

/// 시트에 무엇을 띄울지 (추가 / 수정할 모델)
enum EditorTarget<Model: PersistentModel>: Identifiable {
    case new
    case edit(Model)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let model): return "edit-\(model.persistentModelID.hashValue)"
        }
    }

    var model: Model? {
        if case .edit(let model) = self { return model }
        return nil
    }
}

/// 목록이 비어 있을 때 보여주는 카드: 제목 + 설명 + 추가 버튼
struct EmptyStateCard: View {
    let title: String
    let message: String
    let buttonLabel: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.spoqa(17, .bold, relativeTo: .headline))
                .foregroundStyle(Theme.soil)
            Text(message)
                .font(.spoqa(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(Theme.stem)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: action) {
                Label(buttonLabel, systemImage: "plus")
                    .font(.spoqa(15, .bold, relativeTo: .body))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Theme.grass4))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.card))
    }
}
