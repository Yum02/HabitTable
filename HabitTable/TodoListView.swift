import SwiftUI
import SwiftData

/// 할 일 탭: 미완료가 위, 완료(줄그음)가 아래
struct TodoListView: View {
    @Environment(\.modelContext) private var context
    @Query private var todos: [TodoItem]

    @State private var editorTarget: TodoEditorTarget?

    private var sortedTodos: [TodoItem] {
        TodoProgress.sorted(todos)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if todos.isEmpty {
                emptyCard
                    .padding(.horizontal, 16)
                Spacer(minLength: 0)
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorTarget = .new
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("할 일 추가")
            }
        }
        .sheet(item: $editorTarget) { target in
            TodoEditorView(todo: target.todo)
        }
    }

    // MARK: - 머리글

    private var header: some View {
        Text("할 일")
            .font(.spoqa(26, .bold, relativeTo: .largeTitle))
            .foregroundStyle(Theme.soil)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
    }

    // MARK: - 목록

    private var list: some View {
        List {
            ForEach(sortedTodos) { todo in
                row(todo)
                    .listRowBackground(Theme.card)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button("수정") { editorTarget = .edit(todo) }
                            .tint(Theme.grass3)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("삭제", role: .destructive) {
                            withAnimation(.snappy(duration: 0.25)) { context.delete(todo) }
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private func row(_ todo: TodoItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { todo.isDone.toggle() }
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(todo.isDone ? Theme.grass3 : Theme.grass2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isDone ? "완료 취소" : "완료로 표시")

            Text(todo.title)
                .font(.spoqa(16, .medium, relativeTo: .body))
                .foregroundStyle(todo.isDone ? Theme.stem : Theme.soil)
                .strikethrough(todo.isDone, color: Theme.stem)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }

    // MARK: - 할 일이 없을 때

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("첫 할 일을 추가해 보세요")
                .font(.spoqa(17, .bold, relativeTo: .headline))
                .foregroundStyle(Theme.soil)
            Text("병원 예약, 택배 찾기처럼 하루짜리 일을 적어 두면 끝낼 때까지 남아 있어요.")
                .font(.spoqa(14, .regular, relativeTo: .subheadline))
                .foregroundStyle(Theme.stem)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                editorTarget = .new
            } label: {
                Label("할 일 추가", systemImage: "plus")
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

/// 시트에 무엇을 띄울지
enum TodoEditorTarget: Identifiable {
    case new
    case edit(TodoItem)

    var id: String {
        switch self {
        case .new: return "new"
        case .edit(let todo): return "edit-\(todo.persistentModelID.hashValue)"
        }
    }

    var todo: TodoItem? {
        if case .edit(let todo) = self { return todo }
        return nil
    }
}

#Preview {
    NavigationStack {
        TodoListView()
    }
    .modelContainer(todoPreviewContainer)
    .preferredColorScheme(.light)
}

@MainActor
private let todoPreviewContainer: ModelContainer = {
    FontRegistrar.registerBundledFonts()
    let container = try! ModelContainer(for: TodoItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let now = Date.now
    container.mainContext.insert(TodoItem(title: "병원 예약 전화하기", createdAt: now))
    container.mainContext.insert(TodoItem(title: "택배 찾기", isDone: true, createdAt: now.addingTimeInterval(60)))
    return container
}()
