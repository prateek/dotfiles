// ABOUTME: Starter root view for __APP_NAME__.
// ABOUTME: Gives the scaffolded app a compileable SwiftUI surface that teams can replace incrementally.

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(systemName: "film.stack")
                    .font(.system(size: 40))
                Text("__APP_NAME__")
                    .font(.title2.weight(.semibold))
                Text("Replace this starter surface with your product UI.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .navigationTitle("__APP_NAME__")
        }
    }
}

#Preview {
    ContentView()
}
