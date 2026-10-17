import SwiftUI
import UniformTypeIdentifiers

@main
struct BawangApp: App {
    @StateObject private var game = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var importing = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                if game.running {
                    GameMetalView(session: game).ignoresSafeArea()
                    VirtualPad(session: game)
                } else {
                    VStack(spacing: 18) {
                        Text("霸王三国志").font(.title).bold()
                        Text(game.message).multilineTextAlignment(.center)
                        Button("导入 ROM") { importing = true }
                            .buttonStyle(.borderedProminent)
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { importing = true } label: {
                    Image(systemName: "folder.badge.plus")
                        .padding(10).background(.black.opacity(0.65), in: Circle())
                }
                .tint(.white).padding(8)
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data, .item]) { result in
                if case .success(let url) = result { game.importROM(url) }
                else if case .failure(let error) = result { game.message = error.localizedDescription }
            }
            .onChange(of: scenePhase) { phase in
                game.setPaused(phase != .active)
            }
        }
    }
}
