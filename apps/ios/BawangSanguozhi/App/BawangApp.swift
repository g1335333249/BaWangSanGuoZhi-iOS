import SwiftUI
import UniformTypeIdentifiers

@main
struct BawangApp: App {
    @StateObject private var game = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var importing = false
    @State private var showingDisplaySettings = false
    @AppStorage("BawangPartialMenuDeGlitch") private var partialMenuGuard = true
    @AppStorage("BawangMapBlackTileRepair") private var blackTileGuard = true

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
                HStack(spacing: 3) {
                    Button { showingDisplaySettings = true } label: {
                        Image(systemName: "gearshape")
                            .padding(10).background(.black.opacity(0.55), in: Circle())
                    }
                    Button { importing = true } label: {
                        Image(systemName: "folder.badge.plus")
                            .padding(10).background(.black.opacity(0.55), in: Circle())
                    }
                }
                .tint(.white).padding(8)
            }
            .sheet(isPresented: $showingDisplaySettings) {
                NavigationView {
                    Form {
                        Toggle("隐藏章节菜单短暂乱码", isOn: $partialMenuGuard)
                        Toggle("修补地图小面积黑块（试验性）", isOn: $blackTileGuard)
                        Text("这些是显示层补偿，不修改 ROM、SRAM 或游戏逻辑。地图黑块如果出现误判，可以在这里关闭。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    .navigationTitle("显示设置")
                    .navigationBarItems(trailing: Button("完成") { showingDisplaySettings = false })
                }
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
