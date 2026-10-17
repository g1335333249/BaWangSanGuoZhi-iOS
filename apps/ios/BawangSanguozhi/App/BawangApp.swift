import SwiftUI

@main
struct BawangApp: App {
    @StateObject private var game = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingDisplaySettings = false
    @AppStorage("BawangPartialMenuDeGlitch") private var partialMenuGuard = true
    @AppStorage("BawangMapBlackTileRepair") private var blackTileGuard = true
    @AppStorage("BawangGameLanguage") private var gameLanguage = "traditional"
    @AppStorage("BawangTextLocalizationLastHits") private var lastLocalizationHits = 0

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
                        Text(game.message.hasPrefix("导入")
                             ? "本版本仅使用内置 ROM，请安装包含游戏资源的 IPA。"
                             : game.message)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .padding()
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { showingDisplaySettings = true } label: {
                    Image(systemName: "gearshape")
                        .padding(10).background(.black.opacity(0.55), in: Circle())
                }
                .tint(.white).padding(8)
            }
            .sheet(isPresented: $showingDisplaySettings) {
                NavigationView {
                    Form {
                        Toggle("隐藏章节菜单短暂乱码", isOn: $partialMenuGuard)
                        Toggle("修补地图小面积黑块（试验性）", isOn: $blackTileGuard)
                        Picker("游戏文字", selection: $gameLanguage) {
                            Text("繁体原版").tag("traditional")
                            Text("简体 · 刘备测试").tag("simplified")
                        }
                        .pickerStyle(.segmented)
                        HStack {
                            Text("文字示例")
                            Spacer()
                            Text(gameLanguage == "simplified" ? "刘备" : "劉備")
                        }
                        Text("最近一次游戏画面识别：\(lastLocalizationHits > 0 ? "找到劉備" : "未识别到劉備")")
                            .font(.footnote).foregroundColor(.secondary)
                        Text("简体测试仅尝试识别并替换‘劉備’；需要文字清晰、背景单色。若识别失败则保留原样，不改变 ROM 字库。")
                            .font(.footnote).foregroundColor(.secondary)
                        Text("这些是显示层补偿，不修改 ROM、SRAM 或游戏逻辑。地图黑块如果出现误判，可以在这里关闭。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    .navigationTitle("显示设置")
                    .navigationBarItems(trailing: Button("完成") { showingDisplaySettings = false })
                }
            }
            .onChange(of: scenePhase) { phase in
                game.setPaused(phase != .active)
            }
        }
    }
}
