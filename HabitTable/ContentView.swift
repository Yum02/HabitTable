import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HabitBoardView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Habit.self, inMemory: true)
}
