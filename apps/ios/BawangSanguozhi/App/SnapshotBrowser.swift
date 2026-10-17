import SwiftUI

struct SnapshotBrowser: View {
    @ObservedObject var game: GameSession
    @Binding var presented: Bool
    @State private var name = ""
    @State private var notice: String?
    @State private var confirmDelete: UUID?

    private var canSave: Bool { game.running && game.paused && !game.restoring }

    var body: some View {
        NavigationView {
            List {
                if canSave {
                    Section(header: Text("创建独立快照")) {
                        HStack {
                            TextField("快照名称（可选）", text: $name)
                            Button("一键保存") {
                                do {
                                    try game.saveSnapshot(named: name)
                                    name = ""
                                    notice = "新快照已保存（不会覆盖旧快照）"
                                } catch { notice = error.localizedDescription }
                            }.disabled(game.restoring)
                        }
                    }
                }
                Section(header: Text("已保存的进度（\(game.snapshots.count)）")) {
                    if game.snapshots.isEmpty {
                        Text("暂无即时快照").foregroundColor(.secondary)
                    }
                    ForEach(game.snapshots) { info in
                        HStack(spacing: 12) {
                            if let preview = ReplaySnapshotStore.thumbnail(info.id) {
                                Image(uiImage: preview)
                                    .resizable().interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 112, height: 80)
                                    .background(.black)
                                    .cornerRadius(5)
                            } else {
                                Image(systemName: "photo").frame(width: 112, height: 80)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(info.name).font(.headline)
                                Text(info.date.formatted(date: .abbreviated, time: .shortened)).font(.caption)
                                Text("约 \(info.frames / 60 / 60) 小时 \((info.frames / 60) % 60) 分钟 · \(info.appBuild)")
                                    .font(.caption2).foregroundColor(.secondary)
                                HStack {
                                    Button("恢复") {
                                        presented = false
                                        game.restoreSnapshot(info.id)
                                    }.buttonStyle(.borderedProminent)
                                    Button(role: .destructive) { confirmDelete = info.id } label: {
                                        Image(systemName: "trash")
                                    }.buttonStyle(.bordered)
                                }
                            }
                        }.padding(.vertical, 4)
                    }
                }
                Section {
                    Button("开始一局新游戏") {
                        presented = false
                        game.startNewGame()
                    }
                    Text("首次载入旧快照时会重新执行历史输入并核对游戏状态，进度越长等待可能越久。同一次运行内的快照可直接快速恢复；快照与原版 SRAM 相互独立。")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .navigationTitle("游戏快照")
            .navigationBarItems(trailing: Button("关闭") { presented = false })
            .confirmationDialog("确定删除这个快照吗？删除后无法恢复。",
                isPresented: Binding(get: { confirmDelete != nil },
                                     set: { if !$0 { confirmDelete = nil } })) {
                Button("删除快照", role: .destructive) {
                    if let id = confirmDelete { game.deleteSnapshot(id) }
                    confirmDelete = nil
                }
                Button("取消", role: .cancel) { confirmDelete = nil }
            }
            .alert("提示", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("确定", role: .cancel) { notice = nil }
            } message: { Text(notice ?? "") }
        }
    }
}
