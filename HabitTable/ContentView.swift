import SwiftUI
import SwiftData

struct ContentView: View {
    enum Tab: Hashable {
        case habits, todos
    }

    /// 스크린샷 확인용: "-startTodoTab" 인자로 실행하면 할 일 탭에서 시작한다
    @State private var tab: Tab =
        ProcessInfo.processInfo.arguments.contains("-startTodoTab") ? .todos : .habits

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HabitBoardView()
            }
            .tabItem { Label("습관", systemImage: "checkmark.square") }
            .tag(Tab.habits)

            NavigationStack {
                TodoListView()
            }
            .tabItem { Label("할 일", systemImage: "list.bullet") }
            .tag(Tab.todos)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Habit.self, TodoItem.self], inMemory: true)
}
