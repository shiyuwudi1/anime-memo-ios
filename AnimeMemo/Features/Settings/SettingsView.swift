import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance = "system"
    @AppStorage("titleLanguage") private var titleLanguage = "zh"
    @State private var showPlaceholder = false
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section("显示") {
                    Picker("外观", selection: $appearance) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    }
                    .pickerStyle(.segmented)

                    Picker("标题语言", selection: $titleLanguage) {
                        Text("中文优先").tag("zh")
                        Text("原文").tag("original")
                        Text("英文").tag("en")
                    }
                }

                Section("数据") {
                    Button {
                        showPlaceholder = true
                    } label: {
                        Label("导出备份", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showPlaceholder = true
                    } label: {
                        Label("导入备份", systemImage: "square.and.arrow.down")
                    }

                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label("清空全部数据", systemImage: "trash")
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: "0.1.0")

                    Link(destination: URL(string: "https://www.themoviedb.org")!) {
                        Label("数据来源：TMDB", systemImage: "film.stack")
                    }

                    Text("This product uses the TMDB API but is not endorsed or certified by TMDB.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                #if DEBUG
                Section("开发者") {
                    LabeledContent("TMDB", value: AppConfiguration.isTMDBConfigured ? "已配置" : "未配置")

                    NavigationLink("Glass Lab") {
                        GlassLabView()
                    }
                }
                #endif
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("备份功能即将接入", isPresented: $showPlaceholder) {
                Button("好", role: .cancel) {}
            } message: {
                Text("数据层接入后会启用 JSON 导出/导入。现在先用模拟数据验证界面。")
            }
            .confirmationDialog("确定清空全部数据？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("清空", role: .destructive) {}
                Button("取消", role: .cancel) {}
            } message: {
                Text("这个操作不可撤销。")
            }
        }
    }
}
