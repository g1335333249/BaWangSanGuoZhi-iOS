import SwiftUI

@main
struct BawangApp: App {
    @StateObject private var game = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingDisplaySettings = false
    @State private var showingSnapshots = false
    @AppStorage("BawangPartialMenuDeGlitch") private var partialMenuGuard = true
    @AppStorage("BawangMapBlackTileRepair") private var blackTileGuard = true
    @AppStorage("BawangGameLanguage") private var gameLanguage = "traditional"
    @AppStorage("BawangVideoFilter") private var videoFilter = 0

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                if game.running {
                    GameMetalView(session: game).ignoresSafeArea()
                    VirtualPad(session: game)
                } else if game.restoring {
                    VStack(spacing: 16) {
                        Text("正在恢复历史游戏现场").font(.title3).bold()
                        ProgressView(value: game.restoreProgress)
                            .frame(maxWidth: 300)
                        Text("\(Int(game.restoreProgress * 100))%  ·  正在校验完整游戏状态")
                        Button("取消恢复") { game.cancelRestore() }
                    }.foregroundColor(.white)
                } else {
                    VStack(spacing: 18) {
                        Text("霸王三国志").font(.title).bold()
                        Text(game.message.isEmpty ? "选择进度或开始游戏" : game.message)
                            .multilineTextAlignment(.center)
                        Button("选择游戏进度") { showingSnapshots = true }
                            .buttonStyle(.borderedProminent)
                        Button("开始新游戏") { game.startNewGame() }
                    }.foregroundColor(.white).padding()
                }
            }
            .overlay(alignment: .topLeading) {
                if game.running {
                    Button {
                        game.setPaused(true)
                        showingSnapshots = true
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                            .padding(12).background(.black.opacity(0.55), in: Circle())
                    }
                    .tint(.white).padding(8)
                    .accessibilityLabel("一键保存和读取快照")
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    if game.running { game.setPaused(true) }
                    showingDisplaySettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .padding(12).background(.black.opacity(0.55), in: Circle())
                }
                .tint(.white).padding(8)
            }
            .sheet(isPresented: $showingSnapshots, onDismiss: {
                if game.running && game.paused { game.setPaused(false) }
            }) {
                SnapshotBrowser(game: game, presented: $showingSnapshots)
            }
            .sheet(isPresented: $showingDisplaySettings, onDismiss: {
                if game.running && game.paused { game.setPaused(false) }
            }) {
                NavigationView {
                    Form {
                        Picker("画面画质", selection: $videoFilter) {
                            Text("原版像素").tag(0)
                            Text("柔和平滑").tag(1)
                            Text("边缘保护增强").tag(2)
                        }
                        Text("滤镜只改变显示，不改变原版 320×224 / 256×224 分辨率；平滑模式可能使文字略微变软。")
                            .font(.footnote).foregroundColor(.secondary)
                        Toggle("隐藏章节菜单短暂乱码", isOn: $partialMenuGuard)
                        Toggle("保护彩色旗帜（实验性）", isOn: $blackTileGuard)
                        Picker("游戏文字", selection: $gameLanguage) {
                            Text("繁体原版").tag("traditional")
                            Text("简体字库").tag("simplified")
                        }.pickerStyle(.segmented)
                        Text("触摸操作：主菜单顶部四项可以直接点选；其他区域轻点=确认，滑动=方向。地图城市／武将精准点击仍需逐场景适配。")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    .navigationTitle("游戏设置")
                    .navigationBarItems(trailing: Button("完成") { showingDisplaySettings = false })
                }
            }
            .onChange(of: gameLanguage) { newLanguage in
                game.setSimplifiedLanguage(newLanguage == "simplified")
            }
            .onChange(of: scenePhase) { phase in
                game.setPaused(phase != .active)
            }
        }
    }
}
