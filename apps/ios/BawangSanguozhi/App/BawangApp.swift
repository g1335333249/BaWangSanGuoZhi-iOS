import SwiftUI

@main
struct BawangApp: App {
    @StateObject private var game = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingDisplaySettings = false
    @State private var showingWordCalibration = false
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
                        Toggle("保护地图已显示的彩色旗帜（试验性）", isOn: $blackTileGuard)
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
                        Text(GameWordTemplateStore.shared.isCalibrated ? "已保存『劉備』原版字形" : "尚未校准『劉備』字形")
                            .font(.footnote).foregroundColor(.secondary)
                        Button("从当前游戏画面校准『劉備』字形") {
                            showingDisplaySettings = false
                            gameLanguage = "traditional" // capture the unmodified ROM glyph
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                showingWordCalibration = true
                            }
                        }
                        Button("清除字形校准") {
                            GameWordTemplateStore.shared.clear()
                        }.foregroundColor(.secondary)
                        Text("简体测试只替换与标定字形一致的‘劉備’；首次需框选原版游戏里的两个字。OCR 失败时不再完全依赖它。不改变游戏 ROM 或存档。")
                            .font(.footnote).foregroundColor(.secondary)
                        Text("地图旗帜保护只恢复先前正常显示过、后来异常发黑的色块。如旗帜第一次出现就已经黑，仍需修复 VDP 根因。可随时关闭。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    .navigationTitle("显示设置")
                    .navigationBarItems(trailing: Button("完成") { showingDisplaySettings = false })
                }
            }
            .sheet(isPresented: $showingWordCalibration) {
                GameWordCalibrationView(onSaved: { gameLanguage = "simplified" })
            }
            .onChange(of: scenePhase) { phase in
                game.setPaused(phase != .active)
            }
        }
    }
}
