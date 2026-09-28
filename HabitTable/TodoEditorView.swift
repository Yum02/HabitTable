import SwiftUI
import SwiftData

/// 할 일 추가·수정 시트. HabitEditorView의 축소판(이름 입력 하나).
struct TodoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// nil이면 새 할 일
    let todo: TodoItem?

    @State private var title: String
    @FocusState private var titleFocused: Bool

    init(todo: TodoItem?) {
        self.todo = todo
        _title = State(initialValue: todo?.title ?? "")
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("내용")
                    .font(.spoqa(13, .bold, relativeTo: .footnote))
                    .foregroundStyle(Theme.stem)
                    .padding(.horizontal, 4)
                TextField("예: 병원 예약 전화하기", text: $title)
                    .font(.spoqa(17, .regular, relativeTo: .body))
                    .foregroundStyle(Theme.soil)
                    .focused($titleFocused)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.meadow.ignoresSafeArea())
            .navigationTitle(todo == nil ? "새 할 일" : "할 일 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(Theme.stem)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                        .font(.spoqa(17, .bold, relativeTo: .body))
                        .disabled(!canSave)
                }
            }
            .onAppear { if todo == nil { titleFocused = true } }
        }
        .tint(Theme.grass4)
        .presentationDetents([.medium])
    }

    private func save() {
        guard canSave else { return }
        if let todo {
            todo.title = trimmedTitle
        } else {
            context.insert(TodoItem(title: trimmedTitle))
        }
        dismiss()
    }
}

#Preview {
    TodoEditorView(todo: nil)
        .modelContainer(for: TodoItem.self, inMemory: true)
}
